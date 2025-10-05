let uri_arg =
  if Array.length Sys.argv > 1 then Some Sys.argv.(1) else None

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let stdenv = (env :> Caqti_eio.stdenv) in
  Try_caqti_eio.ensure_schema ?uri:uri_arg ~sw ~stdenv ();
  Try_caqti_eio.demo_run ?uri:uri_arg ~sw ~stdenv ()
