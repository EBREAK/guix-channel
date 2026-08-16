(define-module (ebreak packages kermit)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cryptsetup)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages ncurses)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public kermit
  (package
    (name "kermit")
    (version "985e92d")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ebreak/kermit.git")
             (commit "985e92d07e6b4d43a1100fd31d5c4e83a5ba0a3f")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "07kk6264wx9lqs4cnkc5js9wwg1qin8ap6zza1kpb21n08igk7yr"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                           (string-append "DESTDIR=" #$output))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
                (mkdir-p bin)
                (install-file "kr" bin)
                (install-file "ks" bin)
                #t))))))
    (home-page "https://github.com/ebreak/kermit")
    (synopsis "Tiny Kermit file-transfer utility")
    (description
     "This package provides a tiny Kermit implementation suitable for
embedded systems and simple file transfers over serial connections.")
    (license license:expat)))

(define-public ekermit
  (package
    (name "ekermit")
    (version "1.8")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ebreak/ekermit.git")
             (commit "ecbf821ecb8c166c1c2bc506a64f61f6d238fb12")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1k0rlr8fwryrxwmdl871af8qj8wk3jmm1nrq157kxbbnrgy4cxs1"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                           "CFLAGS=-O2 -Wall"
                           "ek")
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
                (mkdir-p bin)
                (install-file "ek" bin)
                #t))))))
    (home-page "https://www.kermitproject.org/ek.html")
    (synopsis "Embedded Kermit file-transfer utility")
    (description
     "E-Kermit is a compact, embeddable implementation of the Kermit
file-transfer protocol.  It is designed for use in embedded systems where
memory and storage are limited.")
    (license license:bsd-3)))

(define-public ckermit
  (package
    (name "ckermit")
    (version "10.0-beta.12")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ebreak/ckermit.git")
             (commit "1f416a14f06e3f90c6f239d7b1e218b98cceff38")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1ssxz7xfnqlrrvwcabgwqh7hcfsgpcnz9xdpmjmvignpn13w1w1b"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags
      #~(list (string-append "CC=" #$(cc-for-target))
              "CC2=gcc"
              "LNKFLAGS="
              "LIBS=-lcrypt -lncurses -lutil"
              "linuxa")
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-before 'build 'patch-linux-target
            (lambda _
              ;; The linuxa target builds an executable named "wermit".
              ;; Rename it to "kermit" immediately after the build.
              (substitute* "makefile"
                (("xermit KTARGET") "xermit KTARGET"))
              #t))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin"))
                     (man (string-append out "/share/man/man1")))
                (mkdir-p bin)
                (install-file "wermit" bin)
                (rename-file (string-append bin "/wermit")
                             (string-append bin "/kermit"))
                (mkdir-p man)
                #t))))))
    (inputs
     (list libxcrypt ncurses))
    (home-page "https://www.kermitproject.org/ckermit.html")
    (synopsis "C-Kermit communications and file-transfer software")
    (description
     "C-Kermit is a combined serial and network communications package
that provides file transfer, terminal connection, scripting, and character-set
translation.  This package builds the command-line Kermit client for Linux.")
    (license license:bsd-3)))

(define-public kermit-protocol-manual
  (package
    (name "kermit-protocol-manual")
    (version "6")
    (source
     (origin
       (method url-fetch)
       (uri "https://www.kermitproject.org/kproto.pdf")
       (file-name "kproto.pdf")
       (sha256
        (base32
         "19yrqrvkb17n8h5cww1mxrg8h9n52b044vhkc086j515k17p3nb5"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("kproto.pdf" "share/doc/kermit-protocol-manual/"))))
    (home-page "https://www.kermitproject.org/")
    (synopsis "Kermit protocol manual, sixth edition")
    (description
      "The Kermit Protocol Manual by Frank da Cruz describes the Kermit
file-transfer protocol, including the long-packet and sliding-window
extensions.  This is the sixth edition (June 1986) published by the
Columbia University Center for Computing Activities.")
    (license
     (license:non-copyleft "https://www.kermitproject.org/kproto.pdf"
       "Permission is granted to any individual or institution to copy or
use this document, except for explicitly commercial purposes."))))

(define-public kermit-book
  (package
    (name "kermit-book")
    (version "2016")
    (source
     (origin
       (method url-fetch)
       (uri "https://www.kermitproject.org/onlinebooks/kermitbook.pdf")
       (file-name "kermitbook.pdf")
       (sha256
        (base32
         "0gizcgcf03yrp3ivl745hjmscz98s7v91y12qzvdms98sqg1qv9r"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("kermitbook.pdf" "share/doc/kermit-book/"))))
    (home-page "https://www.kermitproject.org/")
    (synopsis "Kermit, a File Transfer Protocol book")
    (description
      "Kermit, a File Transfer Protocol by Frank da Cruz is the definitive
book about the Kermit file-transfer protocol, originally published by
Digital Press in 1987 and in print until 2001.  This PDF edition was
produced in February 2016 from the original Scribe manuscript and is
distributed online by the Kermit Project.")
    (license
     (license:non-copyleft "https://www.kermitproject.org/onlinebooks/kermitbook.pdf"
       "Distributed online for free by the Kermit Project; original
copyright 1987 Digital Press."))))
