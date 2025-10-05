(lang dune 3.20)

(name try-caqti-eio)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name try-caqti-eio)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends
  ocaml
  (dune (>= 3.20))
  caqti
  caqti-eio
  caqti-driver-sqlite3
  eio
  eio_main
  uri)
 (tags
  ("add topics" "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
