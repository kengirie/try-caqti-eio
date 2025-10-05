# Using caqti-eio with SQLite3

This note sketches how to combine `caqti-eio` with the SQLite3 driver to create tables and run CRUD operations via Eio.

## Key Points from the Source

- The bare `Caqti_eio.connect` only supports the pgx driver. SQLite and other C-based drivers need the Unix helper (`Caqti_eio_unix`) which wires in the Unix-specific facilities exposed from the source tree (`caqti-eio/lib/caqti_eio.mli`, `caqti-eio/lib-unix/caqti_eio_unix.ml`).
- `Caqti_eio.System` defines the Eio-facing runtime glue: it provides the `stdenv` record, the fiber/stream instances, and maps Eio I/O errors to `Caqti_error.t` (`caqti-eio/lib/system.ml`).
- `Caqti_eio.Pool` plus `Caqti_eio_unix.connect_pool` wrap the standard connection pool implementation so you can reuse connections while running inside an `Eio.Switch` (`caqti-eio/lib/caqti_eio.mli`).
- `Caqti_eio.or_fail` converts any `('a, Caqti_error.t) result` into `'a`, re-raising as `Caqti_error.Exn` and avoiding repetitive error handling boilerplate (`caqti-eio/lib/caqti_eio.ml`).

## Minimal Runtime Harness

```ocaml
open Eio.Std

let db_uri = Uri.of_string "sqlite3://$PWD/data.sqlite3"

let run f =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let stdenv = (env :> Caqti_eio.stdenv) in
  f ~sw ~stdenv
```

- Always obtain both an `Eio.Switch.t` and the standard environment. `Caqti_eio_unix` requires them explicitly so it can offload blocking calls and schedule alarms.

## Creating the Schema

```ocaml
open Caqti_request.Infix

let create_notes =
  Caqti_request.exec Caqti_type.unit
    {|
      CREATE TABLE IF NOT EXISTS notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL
      )
    |}

let () =
  run @@ fun ~sw ~stdenv ->
  Caqti_eio_unix.connect ~sw ~stdenv db_uri
  |> Caqti_eio.or_fail
  |> fun (module Db : Caqti_eio.CONNECTION) ->
     Db.exec create_notes () |> Caqti_eio.or_fail
```

- Use `Caqti_request.exec` for statements without result rows. The driver automatically creates the database file on first use if it does not exist.

## CRUD Example

```ocaml
module Note_store = struct
  open Caqti_request.Infix

  let insert =
    Caqti_request.exec
      Caqti_type.(t2 string string)
      "INSERT INTO notes (title, body) VALUES (?, ?)"

  let get_by_id =
    Caqti_request.find_opt
      Caqti_type.int
      Caqti_type.(t3 int string string)
      "SELECT id, title, body FROM notes WHERE id = ?"

  let update_title =
    Caqti_request.exec
      Caqti_type.(t2 string int)
      "UPDATE notes SET title = ? WHERE id = ?"

  let delete =
    Caqti_request.exec
      Caqti_type.int
      "DELETE FROM notes WHERE id = ?"
end

let () =
  run @@ fun ~sw ~stdenv ->
  Caqti_eio_unix.with_connection ~sw ~stdenv db_uri @@ fun (module Db) ->
  let open Note_store in
  Db.exec insert ("hello", "Eio + Caqti") |> Caqti_eio.or_fail;
  Db.find_opt get_by_id 1 |> Caqti_eio.or_fail
  |> Option.iter (fun (id, title, body) ->
       traceln "id=%d title=%s body=%s" id title body);
  Db.exec update_title ("updated", 1) |> Caqti_eio.or_fail;
  Db.exec delete 1 |> Caqti_eio.or_fail;
  Ok ()
```

- `find_opt` returns zero or one row. For multi-row reads, switch to `collect_list`, `fold`, or `stream` helpers.
- `with_connection` manages the lifetime of the driver connection and returns `('a, Caqti_error.t) result`, so you may feed its output directly into `or_fail` when appropriate.

## Connection Pooling

```ocaml
let () =
  run @@ fun ~sw ~stdenv ->
  Caqti_eio_unix.connect_pool
    ~sw ~stdenv
    ~config:(Caqti_pool_config.create ~max_size:8 ())
    db_uri
  |> Caqti_eio.or_fail
  |> fun pool ->
     Caqti_eio.Pool.use pool @@ fun (module Db) ->
     Db.exec Note_store.insert ("pooled", "entry") |> Caqti_eio.or_fail
```

- `Caqti_eio.Pool.use` borrows a connection, runs the callback, and returns it. Adjust the pool size to your concurrency needs.

## Extras

- Add query parameters to the SQLite URI (e.g. `?mode=rwc`) to control open behavior.
- Transactions are available through `Db.with_transaction`, `Db.start`, `Db.commit`, and `Db.rollback` (see `Caqti_connection_sig.S`).
- Low-level I/O errors bubbling from Eio become `Caqti_error.Msg_io`, so pattern matching on `Caqti_error.t` preserves the original context.
