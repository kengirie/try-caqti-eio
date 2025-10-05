open Eio.Std

let default_uri = "sqlite3:./data.sqlite3"

let resolve_uri = function
  | Some uri -> Uri.of_string uri
  | None -> Uri.of_string default_uri

let with_connection ?uri ~sw ~stdenv f =
  let uri = resolve_uri uri in
  let conn =
    Caqti_eio_unix.connect ~sw ~stdenv uri |> Caqti_eio.or_fail
  in
  Fun.protect ~finally:(fun () ->
      let (module Db : Caqti_eio.CONNECTION) = conn in
      Db.disconnect ())
    (fun () -> f conn)

module Schema = struct
  open Caqti_request.Infix

  let create_notes =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          body TEXT NOT NULL
        )
      |}
end

module Notes = struct
  open Caqti_request.Infix

  type t = { id : int; title : string; body : string }
  type new_note = { title : string; body : string }

  let to_record (id, title, body) = { id; title; body }

  let insert_request =
    (Caqti_type.(t2 string string) ->. Caqti_type.unit)
      "INSERT INTO notes (title, body) VALUES (?, ?)"

  let last_insert_rowid =
    (Caqti_type.unit ->! Caqti_type.int)
      "SELECT last_insert_rowid()"

  let select_by_id =
    (Caqti_type.int ->? Caqti_type.(t3 int string string))
      "SELECT id, title, body FROM notes WHERE id = ?"

  let update_title_request =
    (Caqti_type.(t2 string int) ->. Caqti_type.unit)
      "UPDATE notes SET title = ? WHERE id = ?"

  let delete_request =
    (Caqti_type.int ->. Caqti_type.unit)
      "DELETE FROM notes WHERE id = ?"

  let insert (module Db : Caqti_eio.CONNECTION) note =
    let ( let* ) = Result.bind in
    let* () = Db.exec insert_request (note.title, note.body) in
    Db.find last_insert_rowid ()

  let insert_many (module Db : Caqti_eio.CONNECTION) notes =
    let ( let* ) = Result.bind in
    let rec loop acc = function
      | [] -> Ok (List.rev acc)
      | note :: rest ->
          let* id = insert (module Db) note in
          loop (id :: acc) rest
    in
    loop [] notes

  let get (module Db : Caqti_eio.CONNECTION) id =
    Db.find_opt select_by_id id |> Result.map (Option.map to_record)

  let update_title (module Db : Caqti_eio.CONNECTION) ~id ~title =
    Db.exec update_title_request (title, id)

  let delete (module Db : Caqti_eio.CONNECTION) id =
    Db.exec delete_request id
end

let ensure_schema ?uri ~sw ~stdenv () =
  with_connection ?uri ~sw ~stdenv @@ fun (module Db : Caqti_eio.CONNECTION) ->
  Db.exec Schema.create_notes () |> Caqti_eio.or_fail

let demo_run ?uri ~sw ~stdenv () =
  with_connection ?uri ~sw ~stdenv @@ fun (module Db : Caqti_eio.CONNECTION) ->
  (* Prepare a few sample notes to exercise multi-row insert + update. *)
  let sample_notes =
    [
      Notes.{ title = "Hello"; body = "Eio + SQLite" };
      Notes.{ title = "Bonjour"; body = "Multi-row insert" };
      Notes.{ title = "Konnichiwa"; body = "multi-row demo" };
    ]
  in
  let note_ids = Notes.insert_many (module Db) sample_notes |> Caqti_eio.or_fail in
  (* Show the freshly inserted rows so the user can verify initial content. *)
  List.iter
    (fun id ->
      Notes.get (module Db) id
      |> Caqti_eio.or_fail
      |> Option.iter (fun Notes.{ id; title; body } ->
             traceln "Inserted note: id=%d title=%s body=%s" id title body))
    note_ids;
  (* Update titles to demonstrate parameterised writes which return success only. *)
  List.iteri
    (fun idx id ->
      let title = Printf.sprintf "Updated title %d" (idx + 1) in
      Notes.update_title (module Db) ~id ~title |> Caqti_eio.or_fail)
    note_ids;
  (* Fetch the updated rows to show they persist in the database. *)
  List.iter
    (fun id ->
      Notes.get (module Db) id
      |> Caqti_eio.or_fail
      |> Option.iter (fun Notes.{ id; title; body } ->
             traceln "Updated note: id=%d title=%s body=%s" id title body))
    note_ids;
  (* Final summary: leave the data in SQLite so it can be inspected manually. *)
  traceln "Persisted note ids=%s"
    (note_ids |> List.map string_of_int |> String.concat ", ")
