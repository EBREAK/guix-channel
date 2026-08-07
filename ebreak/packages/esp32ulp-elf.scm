(define-module (ebreak packages esp32ulp-elf)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages compression)
  #:use-module ((gnu packages compiler-tools) #:select (flex))
  #:use-module (gnu packages texinfo)
)

(define-public esp32ulp-elf
  (package
    (name "esp32ulp-elf")
    (version "2.38_20240113")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/espressif/binutils-gdb/"
                           "archive/refs/tags/esp32ulp-elf-" version ".tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32 "18dqpd99fjxl147x1y2287rld0adw79x82d8kbqqhyn19an05k7i"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:out-of-source? #t
      #:configure-flags #~'("--target=esp32ulp-elf"
                            "--disable-shared"
                            "--disable-nls"
                            "--disable-werror"
                            "--disable-gdb"
                            "--disable-libdecnumber"
                            "--disable-readline"
                            "--disable-sim"
                            "--enable-install-libbfd"
                            "--enable-plugins"
                            "--enable-deterministic-archives")
      #:make-flags #~'("MAKEINFO=true")
      #:phases #~(modify-phases %standard-phases
                   (add-after 'unpack 'patch-version-string
                     (lambda _
                       ;; ESP-IDF's ULP toolchain version check parses the
                       ;; "(GNU Binutils) X.Y" string from the assembler's
                       ;; --version output and expects the Espressif release
                       ;; identifier "2.38_20240113".  Patch the generated
                       ;; configure scripts (and the bfd version macro) so the
                       ;; built binaries report the expected version.
                       (for-each
                        (lambda (file)
                          (substitute* file
                            (("VERSION='2\\.38'")
                             "VERSION='2.38_20240113'")
                            (("PACKAGE_VERSION='2\\.38'")
                             "PACKAGE_VERSION='2.38_20240113'")
                            (("PACKAGE_STRING='([^']+) 2\\.38'")
                             "PACKAGE_STRING='\\1 2.38_20240113'")))
                        (find-files "." "^configure$"))
                       (substitute* "bfd/version.m4"
                         (("2\\.38") "2.38_20240113"))
                       #t))
                   ;; The source tarball is produced by GitHub and does not
                   ;; include a generated configure script for some subdirectories.
                   ;; However, the top-level configure script is present and the
                   ;; GNU build system runs it out-of-tree.  Nothing extra needed.
                   )))
    (native-inputs (list bison flex texinfo))
    (inputs (list zlib))
    (synopsis "Binutils for the ESP32 ULP coprocessor")
    (description
     "This package provides the ESP32 Ultra-Low-Power (ULP) coprocessor
binutils: assembler, linker, and related utilities for the @code{esp32ulp-elf}
target.  It is built from the Espressif binutils-gdb source branch rather than
repackaging the upstream pre-built tarball.")
    (home-page "https://github.com/espressif/binutils-gdb")
    (license license:gpl3+)))
