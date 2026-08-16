(define-module (ebreak packages wch)
  #:use-module (gnu packages compression)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

;;; WCH download URLs are of the form
;;; https://file.wch.cn/download/file?id=N; the real file name is only
;;; revealed via the Content-Disposition header.

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
    (license
     (license:non-copyleft "https://www.wch.cn/"
       "This software and binaries may be used for microcontrollers
manufactured by Nanjing Qinheng Microelectronics (WCH)."))))
