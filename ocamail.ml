(**************************************************)
(*                    OCaMail                     *)
(**************************************************)
(* Documentation generation:                      *)
(*    ocamldoc -v -html -colorize-code -d doc/    *)
(*             ocamail.ml                         *)
(**************************************************)

(** OCaMail debug information *)
let debug str = print_endline ("OCaMail - " ^ str);;

(** Some String utilities *)
module StrUtils =
struct
    (** Returns a list containing each line in the given string *)
    let lines_of str = Str.split (Str.regexp "\n") str
    (** Return a tuple where [fst] is the key and [snd] is the value in a
     string expression like ["key: value"] *)
    let header_parts line =
        let p = Str.split (Str.regexp ":") line 
        in (List.hd p, List.nth p 1)
    (**
      trim a string by removing ["^[ \t\r\n]+"] and ["[ \t\r\n]+$"] from it.
      Example [trim "\thello\t \tworld !  \t" == "hello\t \tworld !"]
    *)
    let trim str = Str.global_replace (Str.regexp "^[ \t\r\n]+") "" (Str.global_replace (Str.regexp "[ \t\r\n]+$") "" str)
    (** Returns what is after a colon, in the given line *)
    let after_colon line = List.hd (List.rev (Str.split (Str.regexp_string ":") line))
    (** Get the String representation of a char code, even if it exceeds
     unsigned char limits. Works as C unsigned char casting. *)
    let safe_char i = String.make 1 (Char.chr (i mod 256))
end;;

(** Base 64 module supporting base64 string decoding *)
module Base64 =
struct
    (** Translation Table to decode (see: http://base64.sourceforge.net/b64.c) *)
    let cd64 = "|$$$}rstuvwxyz{$$$$$$$>?@ABCDEFGHIJKLMNOPQRSTUVW$$$$$$XYZ[\\]^_`abcdefghijklmnopq";;
    (** Return a character (safely), like C-unsigned char *)
    let safe_char i = Char.chr (i mod 256);;
    (** Translate the given character using the internal translation table *)
    let internal_char v =
        let internal_char2 v (*char*) =
            let cv = Char.code v in
            if cv < 43 or cv > 122 then Char.chr 0
            else String.get cd64 (cv - 43)
        in let vv = internal_char2 v in
        let vvv = if vv == '$' then 0
                  else (Char.code vv) - 61
        in if vvv == 0 then Char.chr 0 else Char.chr (vvv - 1)
    (** decode 4 '6-bit' characters into 3 8-bit binary bytes *)
    let decode_block s =
        let code s i = Char.code (internal_char (String.get s i)) in
        (* (in[0] << 2 | in[1] >> 4) *)
        let i0 = StrUtils.safe_char (((code s 0) lsl 2) lor ((code s 1) lsr 4)) in
        (* (in[1] << 4 | in[2] >> 2) *)
        let i1 = StrUtils.safe_char (((code s 1) lsl 4) lor ((code s 2) lsr 2)) in
        (* (((in[2] << 6) & 0xc0) | in[3]) *)
        let i2 = StrUtils.safe_char ((((code s 2) lsl 6) land 0xc0) lor (code s 3)) in
        i0 ^ i1 ^ i2
    (**
      decode a base64 encoded stream discarding padding, line breaks and noise.
      [decode_string "SGVsbG8gd29ybGQh" == "Hello world!"]
      *)
    let decode_string s =
        (* split in 4 *)
        let splits = Str.full_split (Str.regexp "....") s in
        (* keep only delims *)
        let eblocks = List.filter (fun e -> match e with Str.Delim _ -> true | Str.Text _ -> false) splits in
        (* get string out of the Str.Delim type *)
        let blocks = List.map (fun e -> match e with Str.Delim b -> b | Str.Text b -> b) eblocks in
        List.map decode_block blocks
    (** save the given base64 representing bin data to the given filename *)
    let save_b64_bin b64 filename =
        let decoded = decode_string b64 in
        let file = open_out_bin filename in
        let rec print_bin l file =
            match l with
            | [] -> print_endline "saved"
            | h::t -> output_string file h; print_bin t file
        in print_bin decoded file;
                   close_out file
end;;

(** Simple SMTP module for client requests and server responses *)
module Smtp =
struct
    (** SMTP Client Request Module *)
    module Request =
    struct
        (** SMTP Client request *)
        type request = Helo (*  HELO or EHLO *)
            | Mail of string (* MAIL FROM: .* *)
            | Rcpt of string (* RCPT TO: .* *)
            | Data (* Start of DATA *)
            | Line of string (* Anything that represents data *)
            | EndOfData (* End of Data, meaning <CRLF>.<CRLF> *)
            | Quit (* Quit *)
        (** Read a line and extract the command from it *)
        let from_string line =
            let safe_line = if String.length line < 4 then line ^ (String.make 4 ' ') else line in
            match String.uppercase (String.sub safe_line 0 4) with
                | "HELO" | "EHLO" -> Helo
                | "MAIL" -> Mail (StrUtils.after_colon line)
                | "RCPT" -> Rcpt (StrUtils.after_colon line)
                | "DATA" -> Data
                | "QUIT" -> Quit
                | str -> if StrUtils.trim(str) = "." then EndOfData else Line line
    end

    (** SMTP Response to client *)
    module Response =
    struct
        (** Respond something on the out channel *)
        let respond out str = print_endline ("Responding [" ^ str ^ "]"); output_string out (str ^ "\r\n"); flush out
        (** Transmission start, say who we are *)
        let ocamail out = respond out "220 OCaMail - Simple Fake SMTP Server - Ready"
        (** Say hi to the user requesting HELO *)
        let hi out = respond out "250 OCaMail greets you, whoever you are"
        (** Say OK *)
        let ok out = respond out "250 OK"
        (** Say to client he should start sending data *)
        let start_data out = respond out "354 Start mail input; end with <CRLF>.<CRLF>"
        (** Say good bye to client *)
        let bye out = respond out "221 OCaMail - Simple Fake SMTP Server - Service closing transmission channel"
    end

    (** Data parsing module *)
    module Data =
    struct
        (** Parse the headers and put the key,value found in the given [Hashtbl] *)
        let parse_headers headers htbl =
            let keep_until_nl l = (* keep items only before new empty line *)
                let rec internal l accu = match l with
                | h::t -> if StrUtils.trim(h) = "" then accu else h::(internal t accu)
                | [] -> accu
                in internal l []
            in
            let lines = keep_until_nl (StrUtils.lines_of headers) in (* get lines *)
            List.iter (fun e -> let p = StrUtils.header_parts e in Hashtbl.add htbl (fst p) (snd p))
                         (keep_until_nl lines)
        (** Get the headers from the given content string [content] *)
        let get_headers content =
            let htbl = Hashtbl.create 10 in
            let _ = parse_headers content htbl
            in htbl
        (** Check if the line [s] indicate a multipart/mixed content *)
        let is_multipart s = Str.string_match (Str.regexp ".*multipart/mixed.*") s 0
        (** Get the boundary from the multipart line [s] *)
        let get_boundary s =
            let _ = Str.string_match (Str.regexp ".*boundary=\"\\(.*\\)\".*") s 0
            in Str.matched_group 1 s
        (** Extract the data for the given boundary [b] from the given content [s] *)
        let get_content_for_boundary s b =
            let lines = StrUtils.lines_of s in
            let content = ref "" in
            let started = ref false in
            let _ = List.iter (fun e -> if StrUtils.trim(e) = "--" ^ b then started := true
                                        else if StrUtils.trim(e) = "--" ^ b ^ "--" then started := false
                                        else if !started then content :=
                                            !content ^ "\n" ^ e)
                              lines
            in !content
        (** Get the content file name from the [Content-Disposition] header in
         the given Hashtbl [h] *)
        let get_content_filename h =
            let cd = Hashtbl.find h "Content-Disposition" in
            try
                let _ = Str.string_match (Str.regexp ".*filename=\"\\(.*\\)\".*") cd 0
                in Str.matched_group 1 cd
            with _ -> ""
    end
end;;

open Smtp;;


(** Establish a server, then run the given function on each connection *)
let main_server server_fun =
   let host = Unix.inet_addr_of_string "0.0.0.0" in (* localhost *)
   let addr = Unix.ADDR_INET (host, 25) in
   let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
   let _ = Unix.setsockopt sock Unix.SO_REUSEADDR true in
   try
      Unix.bind sock addr ;
      Unix.listen sock 3;
      debug "Binding on 0.0.0.0:25.";
      while true do
        debug "Waiting for client.";
        let (s, caller) = Unix.accept sock
        in (
            let inchan = Unix.in_channel_of_descr s
            and outchan = Unix.out_channel_of_descr s
             in server_fun inchan outchan s;
                            close_in inchan;
                        try close_out outchan with _ -> (); (* dont care *)
        );
        debug "Finished with client."
      done
   with e -> Unix.close sock; raise e
;;


(** SMTP answer to the given request *)
let smtp_answer_request req ic oc buffer last_state =
    match req with
      | Request.Helo -> Response.hi oc
      | Request.Mail mail -> Response.ok oc
      | Request.Rcpt mail -> Response.ok oc
      | Request.Data -> Response.start_data oc
      | Request.Line line -> if line = "\r\n" && last_state = Request.EndOfData then Response.ok oc
                             else buffer := !buffer ^ line ^ "\r\n"
      | Request.EndOfData -> Response.ok oc; buffer := !buffer ^ "\r\n"
      | Request.Quit -> ()
;;

let parse_transcript headers content =
    debug (">>>> " ^ (Hashtbl.find headers "Content-Type"));
    if Data.is_multipart (Hashtbl.find headers "Content-Type") then (
        let boundary = Data.get_boundary (Hashtbl.find headers "Content-Type") in
        let _ = debug boundary in
        let data = Data.get_content_for_boundary content boundary in
        let _ = debug data in
        let data_headers = Data.get_headers data in
        let filename = Data.get_content_filename data_headers in
        debug ("Need to save attachment: " ^ filename)
    )
;;

(**
 * Save to a timestamp-named file.
 * Example: mail-20110315-172408.txt
 *)
let save_as_file str =
    let now = Unix.localtime (Unix.time()) in
    let { Unix.tm_year = y; Unix.tm_mon = m; Unix.tm_mday = d;
          Unix.tm_hour = h; Unix.tm_min = mm; Unix.tm_sec = s } = now in
    let name = Printf.sprintf "mail-%4d%02d%02d-%02d%02d%02d.txt" (y + 1900) m d h mm s in
    let headers = Data.get_headers str in
    let channel = open_out name in
        output_string channel str;
        close_out channel;
        debug ("saved something into " ^ name);
        parse_transcript headers str
;;

(** SMTP service *)
let smtp_service ic oc client =
   let content = ref "" in
   let state = ref Request.Helo in
   try
      Response.ocamail oc;
      while true do
         let s = input_line ic in
         let _ = print_endline ("> " ^ s) in (* log incoming line *)
         let request = Request.from_string s in
           match request with
             | Request.Quit -> Response.bye oc; save_as_file !content
             | _ -> smtp_answer_request request ic oc content !state;
                    state := request
      done
   with End_of_file -> debug "Reading from client finished..."
;;


(** OCaMail *)
let rec ocamail () =
   try
       Unix.handle_unix_error main_server smtp_service
   with
     | Sys_error x -> debug ("Failed with Sys_error: " ^ x); ocamail() (* try a restart *)
     | _ -> debug "OCaMail stopping. See ya !"; exit 0
;;

(* run the whole stuff *)
ocamail();;