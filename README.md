# OCamail, simple SMTP Server written in OCaml

**tldr:** Just because I can and I found the name amusing :-P. See the webpage dedicated to it on my [website](http://grison.me/ocamail).

*OCamail* is a simple SMTP Server acknowledging all requests it receives. It is written in [Objective Caml](http://caml.inria.fr/ocaml/index.fr.html) for development and learning purposes.

Attachments (non-gziped only) are supported and can be saved in a directory in order to be checked if needed.

OCamail is useful for any local development that makes uses of SMTP. But for real needs you may prefer using [smtp4dev](http://smtp4dev.codeplex.com/) which does the same, and even even more (at least on Windows) for free.

The code contains just three modules for:
* String Utilities and parsing of SMTP commands
* Base64 decoding
* SMTP handling

##Sample session

    $ ocaml ocamail.ml
    OCaMail - Binding on 0.0.0.0:25.
    OCaMail - Waiting for client.
    Responding [220 CaMail - Simple Fake SMTP Server - Ready]
    > ehlo grisonal.aris-lux.lan
    Responding [250 OCaMail greets you, whoever you are]
    > mail FROM:<foo@bar.com>
    Responding [250 OK]
    > rcpt TO:<a.grison@gmail.com>
    Responding [250 OK]
    > data
    Responding [354 Start mail input; end with <CRLF>.<CRLF>]
    > Hello world!
    > .
    Responding [250 OK]
    > mail FROM:<foo@bar.com>
    Responding [250 OK]
    > rcpt TO:<a.grison@gmail.com>
    Responding [250 OK]
    > data
    Responding [354 Start mail input; end with <CRLF>.<CRLF>]
    > Content-Type: multipart/mixed; boundary="===============1632957673=="
    > MIME-Version: 1.0
    >
    > --===============1632957673==
    > Content-Type: text/plain; charset="us-ascii"
    > MIME-Version: 1.0
    > Content-Transfer-Encoding: 7bit
    >
    > Hello
    > --===============1632957673==
    > Content-Type: application/octet-stream
    > MIME-Version: 1.0
    > Content-Transfer-Encoding: base64
    >
    > SGVsbG8gSSdtIGp1c3QgYSBzaW1wbGUgYXR0YWNobWVudCB0byB0aGF0IGVtYWlsLgpJZiBldmVy
    > eXRoaW5nIGdvZXMgd2VsbCwgeW91IHNob3VsZCByZXRyaWV2ZSBtZSBpbiB0aGUgT0NhbWFpbCBk
    > aXJlY3RvcnkuCgpIYXZlIGZ1biE=
    > --===============1632957673==--
    > .
    Responding [250 OK]
    > quit
    Responding [221 CaMail - Simple Fake SMTP Server - Service closing transmission channel]

##Compile and run

Using `ocamlfind` and `ocamlc`

    $ ocamlfind ocamlc -package unix -package str -linkpkg ocamail.ml -o ocamail
	$ ./ocamail
	OCaMail - Binding on 0.0.0.0:25.
    OCaMail - Waiting for client.
	
In case you don't have sufficient right to bind to `0.0.0.0` you might run the process with `sudo`

	$ sudo ./ocamail
	OCaMail - Binding on 0.0.0.0:25.
    OCaMail - Waiting for client.
	
Or directly using `ocaml`

    $ ocaml ocamail.ml
	OCaMail - Binding on 0.0.0.0:25.
    OCaMail - Waiting for client.
	
