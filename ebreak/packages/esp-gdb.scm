(define-module (ebreak packages esp-gdb)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages compiler-tools)
  #:use-module (gnu packages gdb)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages xml))

(define %esp-gdb-version "17.1_20260402")
(define %esp-gdb-tag (string-append "esp-gdb-v" %esp-gdb-version))

(define %binutils-gdb-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/binutils-gdb/"
                        "archive/refs/tags/" %esp-gdb-tag ".tar.gz"))
    (file-name (string-append "binutils-gdb-" %esp-gdb-tag ".tar.gz"))
    (sha256
     (base32
      "0f5gpxaivgjlc3vb4x1vzj909ah6y24wcj28yh4kjdjamx973p0b"))))

(define %xtensa-dynconfig-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/xtensa-dynconfig/"
                        "archive/905b913aa65638be53ac22029c379fa16dab31db.tar.gz"))
    (file-name "xtensa-dynconfig-905b913.tar.gz")
    (sha256
     (base32
      "1727y2vdgzxra308113w5y1y71bkvcxmkpy4jkmvkfvp4vzy6rak"))))

(define %xtensa-overlays-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/xtensa-overlays/"
                        "archive/dd1cf19f6eb327a9db51043439974a6de13f5c7f.tar.gz"))
    (file-name "xtensa-overlays-dd1cf19.tar.gz")
    (sha256
     (base32
      "0micz63bw1kjamyfl26kdxird7f1qiili3zaw95rs86468wlxx1g"))))

(define-public xtensa-esp-elf-gdb
  (package
    (name "xtensa-esp-elf-gdb")
    (version %esp-gdb-version)
    (source %binutils-gdb-source)
    (build-system gnu-build-system)
    (native-inputs
     `(("texinfo" ,texinfo)
       ("pkg-config" ,pkg-config)
       ("tar" ,tar)
       ("flex" ,flex)
       ("bison" ,bison)
       ("perl" ,perl)
       ("xtensa-dynconfig" ,%xtensa-dynconfig-source)
       ("xtensa-overlays" ,%xtensa-overlays-source)))
    (inputs
     `(("expat" ,expat)
       ("gmp" ,gmp)
       ("mpfr" ,mpfr)
       ("ncurses" ,ncurses)
       ("python" ,python)
       ("zlib" ,zlib)))
    (arguments
     (list
      #:tests? #f
      #:modules (cons* '(ice-9 ftw) %default-gnu-modules)
      #:configure-flags #~(list "--target=xtensa-esp-elf"
                               "--disable-werror"
                               "--disable-binutils"
                               "--disable-ld"
                               "--disable-gas"
                               "--disable-sim"
                               "--disable-ada"
                               "--disable-gdbserver"
                               "--disable-nls"
                               "--disable-source-highlight"
                               "--with-expat"
                               "--with-python"
                               "--with-curses"
                               "--enable-tui"
                               "--with-pkgversion=esp-gdb"
                               "--disable-threads"
                               (string-append "PYTHON="
                                              #$(this-package-input "python")
                                              "/bin/python3"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'install-xtensa-submodules
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((dynconfig-root (assoc-ref inputs "xtensa-dynconfig"))
                    (overlays-root (assoc-ref inputs "xtensa-overlays"))
                    (tar (string-append (assoc-ref inputs "tar") "/bin/tar")))
                (define (install-submodule root target)
                  (mkdir-p target)
                  (if (file-is-directory? root)
                      ;; Input was extracted by Guix; copy the top-level
                      ;; subdirectory contents into TARGET.
                      (let ((dir (car (scandir root
                                               (lambda (entry)
                                                 (and (not (member entry '("." "..")))
                                                      (file-is-directory?
                                                       (string-append root "/" entry))))))))
                        (copy-recursively (string-append root "/" dir)
                                          target
                                          #:keep-mtime? #t))
                      ;; Input is the tarball file itself; extract it.
                      (invoke tar "-xzf" root "-C" target "--strip-components=1")))
                (install-submodule dynconfig-root "xtensa-dynconfig")
                (install-submodule overlays-root "xtensa-overlays"))))
          (add-before 'configure 'build-xtensa-dynconfig
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (dynconfig-out (string-append out "/lib")))
                (with-directory-excursion "xtensa-dynconfig"
                  (invoke "make"
                          "CC=gcc"
                          (string-append "CONF_DIR=" (getcwd) "/../xtensa-overlays"))
                  (mkdir-p dynconfig-out)
                  (for-each (lambda (so)
                              (install-file so dynconfig-out))
                            (find-files "." "\\.so$"))))))
          (add-after 'install 'rename-and-wrap
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin-dir (string-append out "/bin"))
                     (pyver #$(version-major+minor (package-version python)))
                     (gdb-with-py (string-append "xtensa-esp-elf-gdb-" pyver))
                     (gdb-no-py "xtensa-esp-elf-gdb-no-python"))
                (rename-file (string-append bin-dir "/xtensa-esp-elf-gdb")
                             (string-append bin-dir "/" gdb-with-py))
                ;; Provide a no-python symlink so version checks work.
                (symlink gdb-with-py (string-append bin-dir "/" gdb-no-py))
                ;; Install chip-specific wrappers.
                (for-each
                 (lambda (chip)
                   (let ((wrapper (string-append bin-dir "/xtensa-" chip "-elf-gdb"))
                         (dynconfig-so (string-append "${libdir}/xtensa_" chip ".so")))
                     (call-with-output-file wrapper
                       (lambda (port)
                         (format port "#!/bin/sh~%")
                         (format port "bindir=$(cd \"$0\" >/dev/null 2>&1 && dirname \"$0\")~%")
                         (format port "libdir=$(cd \"$bindir/../lib\" >/dev/null 2>&1 && pwd)~%")
                         (format port "export XTENSA_GNU_CONFIG=\"~a\"~%" dynconfig-so)
                         (format port "exec_bin=\"$bindir/xtensa-esp-elf-gdb-~a\"~%" pyver)
                         (format port "if [ ! -x \"$exec_bin\" ]; then~%")
                         (format port "  exec_bin=\"$bindir/xtensa-esp-elf-gdb-no-python\"~%")
                         (format port "fi~%")
                         (format port "exec \"$exec_bin\" \"$@\"~%")))
                     (chmod wrapper #o555)))
                 '("esp32" "esp32s2" "esp32s3"))))))))
    (home-page "https://github.com/espressif/binutils-gdb")
    (synopsis "GNU GDB for Espressif Xtensa MCUs")
    (description
     "This package provides Espressif's fork of GNU GDB for debugging
ESP32, ESP32-S2 and ESP32-S3 SoCs.  It includes the Xtensa dynamic
configuration libraries and the chip-specific wrapper binaries expected
by ESP-IDF.")
    (license license:gpl3+)))

(define-public riscv32-esp-elf-gdb
  (package
    (name "riscv32-esp-elf-gdb")
    (version %esp-gdb-version)
    (source %binutils-gdb-source)
    (build-system gnu-build-system)
    (native-inputs
     `(("texinfo" ,texinfo)
       ("pkg-config" ,pkg-config)
       ("flex" ,flex)
       ("bison" ,bison)
       ("perl" ,perl)))
    (inputs
     `(("expat" ,expat)
       ("gmp" ,gmp)
       ("mpfr" ,mpfr)
       ("ncurses" ,ncurses)
       ("python" ,python)
       ("zlib" ,zlib)))
    (arguments
     (list
      #:tests? #f
      #:configure-flags #~(list "--target=riscv32-esp-elf"
                               "--disable-werror"
                               "--disable-binutils"
                               "--disable-ld"
                               "--disable-gas"
                               "--disable-sim"
                               "--disable-ada"
                               "--disable-gdbserver"
                               "--disable-nls"
                               "--disable-source-highlight"
                               "--with-expat"
                               "--with-python"
                               "--with-curses"
                               "--enable-tui"
                               "--with-pkgversion=esp-gdb"
                               "--disable-threads"
                               (string-append "PYTHON="
                                              #$(this-package-input "python")
                                              "/bin/python3"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'rename-and-wrap
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin-dir (string-append out "/bin"))
                     (pyver #$(version-major+minor (package-version python)))
                     (gdb-with-py (string-append "riscv32-esp-elf-gdb-" pyver))
                     (gdb-no-py "riscv32-esp-elf-gdb-no-python"))
                (rename-file (string-append bin-dir "/riscv32-esp-elf-gdb")
                             (string-append bin-dir "/" gdb-with-py))
                (symlink gdb-with-py (string-append bin-dir "/" gdb-no-py))
                (let ((wrapper (string-append bin-dir "/riscv32-esp-elf-gdb")))
                  (call-with-output-file wrapper
                    (lambda (port)
                      (format port "#!/bin/sh~%")
                      (format port "bindir=$(cd \"$0\" >/dev/null 2>&1 && dirname \"$0\")~%")
                      (format port "exec_bin=\"$bindir/riscv32-esp-elf-gdb-~a\"~%" pyver)
                      (format port "if [ ! -x \"$exec_bin\" ]; then~%")
                      (format port "  exec_bin=\"$bindir/riscv32-esp-elf-gdb-no-python\"~%")
                      (format port "fi~%")
                      (format port "exec \"$exec_bin\" \"$@\"~%")))
                  (chmod wrapper #o555))))))))
    (home-page "https://github.com/espressif/binutils-gdb")
    (synopsis "GNU GDB for Espressif RISC-V MCUs")
    (description
     "This package provides Espressif's fork of GNU GDB for debugging
ESP32-C2, ESP32-C3, ESP32-C5, ESP32-C6 and ESP32-H2 SoCs.")
    (license license:gpl3+)))
