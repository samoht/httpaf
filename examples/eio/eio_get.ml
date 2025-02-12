module Arg = Stdlib.Arg

open Httpaf

let handler ~on_eof response response_body =
  match response with
  | { Response.status = `OK; _ } as response ->
    Format.fprintf Format.std_formatter "%a\n%!" Response.pp_hum response;
    let rec on_read bs ~off ~len =
      Bigstringaf.substring ~off ~len bs |> print_string;
      flush stdout;
      Body.Reader.schedule_read response_body ~on_read ~on_eof
    in
    Body.Reader.schedule_read response_body ~on_read ~on_eof;
  | response ->
    Format.fprintf Format.err_formatter "%a\n%!" Response.pp_hum response;
    Stdlib.exit 124
;;

let main port host =
  Eio_main.run (fun _env ->
    Eio.Switch.run (fun sw ->
    let fd = Unix.socket ~cloexec:true Unix.PF_INET Unix.SOCK_STREAM 0 in
    let addrs =
      Eio_unix.run_in_systhread (fun () ->
          Unix.getaddrinfo
            host
            (Int.to_string port)
            [ Unix.(AI_FAMILY PF_INET) ])
    in
    Eio_unix.run_in_systhread (fun () ->
      Unix.connect fd (List.hd addrs).ai_addr);
    let socket = Eio_unix.Net.import_socket_stream ~sw ~close_unix:true fd in
    let headers = Headers.of_list [ "host", host ] in
    let connection =
      Httpaf_eio.Client.create_connection ~sw socket
    in

    let exit_cond = Eio.Condition.create () in
    let response_handler =
      handler ~on_eof:(fun () ->
        Stdlib.Format.eprintf "eof@.";
        Eio.Condition.broadcast exit_cond)
    in
    let request_body =
      Httpaf_eio.Client.request
        (* ~flush_headers_immediately:true *)
        ~error_handler:Httpaf_examples.Client.error_handler
        ~response_handler
        connection
        (Request.create ~headers `GET "/")
    in
    Body.Writer.close request_body;
    Eio.Condition.await_no_mutex exit_cond;
    Httpaf_eio.Client.shutdown connection |> Eio.Promise.await))

let () =
  let host = ref None in
  let port = ref 80 in
  Arg.parse
    ["-p", Set_int port, " Port number (80 by default)"]
    (fun host_argument -> host := Some host_argument)
    "lwt_get.exe [-p N] HOST";
  let host =
    match !host with
    | None -> failwith "No hostname provided"
    | Some host -> host
  in
  main !port host
;;
