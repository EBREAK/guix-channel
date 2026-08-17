(define-module (ebreak packages superh)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public superh-manuals
  (package
    (name "superh-manuals")
    (version "6cf492d")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/KitsunebiGames/SuperH-Manuals")
             (commit "6cf492d42b246478b3f8c56704c9b14deabdbdf1")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1hsswyb3682811wqdlwrlyngdayl25qkifc4aid5rc9swfgjs7vy"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("ISA" "share/doc/superh-manuals/ISA")
          ("ABI" "share/doc/superh-manuals/ABI")
          ("Hardware" "share/doc/superh-manuals/Hardware")
          ("README.md" "share/doc/superh-manuals/"))))
    (home-page "https://github.com/KitsunebiGames/SuperH-Manuals")
    (synopsis "Collection of SuperH architecture manuals")
    (description
      "This package provides a collection of manuals for the SuperH (SH)
architecture: ISA manuals for the SH-1/SH-2, SH3, SH-4, SH-4A and SH-5
cores, ABI documents, and hardware manuals for specific devices such as
the SH7604 and SH7750.")
    (license
     (license:non-copyleft
       "https://github.com/KitsunebiGames/SuperH-Manuals"
       "The manuals are copyrighted by Hitachi, Renesas and ST
Microelectronics; they are redistributed unchanged for documentation
purposes."))))
