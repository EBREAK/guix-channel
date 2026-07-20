(define-module (ebreak packages kermit)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cryptsetup)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages ncurses)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
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
