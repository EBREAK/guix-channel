(define-module (ebreak packages wch)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages wine)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

;;; WCH download URLs are of the form
;;; https://file.wch.cn/download/file?id=N; the real file name is only
;;; revealed via the Content-Disposition header.

(define %wch-vendor-license
  (license:license
   "WCH vendor license"
   "https://www.wch.cn/"
   "This software and binaries may be used for microcontrollers
manufactured by Nanjing Qinheng Microelectronics (WCH).  This is a
field-of-use restriction, not a free software license."))

(define wch-ch32x035-datasheet
  (origin
    (method url-fetch)
    (uri "https://file.wch.cn/download/file?id=443")
    (file-name "CH32X035DS0.PDF")
    (sha256
     (base32
      "160lhk9rqw5vq9bs23pz4k332fyz0qw973i8npvjk1vks0i0szql"))))

(define wch-ch32x035-reference-manual
  (origin
    (method url-fetch)
    (uri "https://file.wch.cn/download/file?id=445")
    (file-name "CH32X035RM.PDF")
    (sha256
     (base32
      "196sr6y8dhn1mwn193p2dgrwg7hkazq6p51g26xa233rqkm03qy7"))))

(define wch-ch32x035-evt-source
  (origin
    (method url-fetch)
    (uri "https://file.wch.cn/download/file?id=444")
    (file-name "CH32X035EVT.zip")
    (sha256
     (base32
      "05q7qm1cgwhwvpfs3r45wamqvpfxpn0fkdn8gjldrvq3wksa02bz"))))

(define-public wch-ch32x035-vendor
  (package
    (name "wch-ch32x035-vendor")
    (version "2025.10")
    (source wch-ch32x035-evt-source)
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("." "share/wch-ch32x035"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-gbk-filenames
            ;; The archive stores some file names in GBK encoding;
            ;; convert them to UTF-8 so they survive in the store.
            (lambda _
              (invoke "sh" "-c" "\
find . -depth -name '*[! -~]*' | while IFS= read -r f; do
  d=${f%/*}; b=${f##*/}
  nb=$(printf '%s' \"$b\" | iconv -f GBK -t UTF-8) || continue
  mv \"$f\" \"$d/$nb\"
done")))
          (add-after 'install 'install-manuals
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((doc (string-append (assoc-ref outputs "out")
                                        "/share/doc/wch-ch32x035-vendor")))
                (mkdir-p doc)
                (install-file #$wch-ch32x035-datasheet doc)
                (install-file #$wch-ch32x035-reference-manual doc)))))))
    (native-inputs (list unzip))
    (home-page "https://www.wch-ic.com/products/CH32X035.html")
    (synopsis "Vendor SDK and manuals for the WCH CH32X035 MCU")
    (description
      "This package provides the WCH CH32X035 EVT software package
(example programs, peripheral library sources and evaluation board
documentation) together with the CH32X035 datasheet (CH32X035DS0 V2.2)
and reference manual (CH32X035RM V1.9).  The SDK tree is installed under
@file{share/wch-ch32x035} and the manuals under
@file{share/doc/wch-ch32x035-vendor}.")
    (license %wch-vendor-license)))

(define-public wch-risc8b-toolchain
  (package
    (name "wch-risc8b-toolchain")
    (version "2025.10")
    (source wch-ch32x035-evt-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:strip-binaries? #f             ; Windows PE executables
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (lib (string-append out "/lib/wch-risc8b"))
                     (doc (string-append out "/share/doc/wch-risc8b-toolchain"))
                     (bin (string-append out "/bin"))
                     (wine #$(file-append wine "/bin/wine"))
                     (tools '(("wasm53b" . "WASM53B.EXE"))))
                (mkdir-p lib)
                (for-each (lambda (exe)
                            (install-file exe lib))
                          (find-files "EXAM/PIOC/Tool_Manual/Tool" "WASM53B\\.EXE$"))
                (mkdir-p doc)
                (for-each (lambda (pdf)
                            (install-file pdf doc))
                          (find-files "EXAM/PIOC/Tool_Manual/Manual" "\\.PDF$"))
                (mkdir-p bin)
                (for-each
                 (lambda (tool)
                   (let ((wrapper (string-append bin "/" (car tool)))
                         (exe (string-append lib "/" (cdr tool))))
                     (call-with-output-file wrapper
                       (lambda (port)
                         (format port "#!/bin/sh
# Run the original Windows tool through Wine.  Set WINE to use a
# different Wine binary, WINEDEBUG to adjust Wine diagnostics.
: \"${WINEDEBUG:=-all}\"
export WINEDEBUG
exec \"${WINE:-~a}\" \"~a\" \"$@\"
" wine exe)))
                     (chmod wrapper #o555)))
                 tools)))))))
    (native-inputs (list unzip))
    (inputs (list wine))
    (home-page "https://www.wch-ic.com/products/CH32X035.html")
    (synopsis "WCH-RISC8B assembler for the CH32X035 PIOC")
    (description
      "The CH32X035 PIOC (Programmable Protocol I/O Controller) is driven
by a small WCH-RISC8B 8-bit RISC core.  This package provides the vendor
toolchain for that core, taken from the CH32X035 EVT package: the WASM
assembler (WASM53B).  It is a 32-bit Windows console executable; the
installed @command{wasm53b} wrapper runs it through Wine.  The RISC8B
instruction set and PIOC manuals are installed under
@file{share/doc/wch-risc8b-toolchain}.")
    (license %wch-vendor-license)))
