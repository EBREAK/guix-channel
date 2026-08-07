(define-module (ebreak packages esp-toolchain-sources)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages texinfo)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

;;; Pinned source tarballs and base packages for Espressif's GCC toolchains.
;;; These are the forks used by crosstool-NG release esp-16.1.0_20260609.

(define-public %esp-gcc-version "16.1.0_20260609")
(define-public %esp-binutils-version "2.46.0_20260609")
(define-public %esp-newlib-version "4.6.0_20260609")
(define-public %esp-picolibc-version "1.8.11_20260609")

(define-public %esp-gcc-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/gcc/archive/"
                        "345fca0a988a78fd3bc05b132e3dabfdec33a96f.tar.gz"))
    (file-name (string-append "gcc-esp-" %esp-gcc-version ".tar.gz"))
    (sha256
     (base32
      "145ggwqwh3kc52fdk1r3zr2y0f68ixrczrbpy6vvbn9mvk34xz6x"))))

(define-public %esp-binutils-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/binutils-gdb/archive/"
                        "972ede94298f73a926fbea6b415cd0b054c5f836.tar.gz"))
    (file-name (string-append "binutils-gdb-esp-" %esp-binutils-version ".tar.gz"))
    (sha256
     (base32
      "11mz5z6lrsi8p48s3ghbjf7n2sbyzzayxz3xpqqiszpd4f2182c9"))))

(define-public %esp-newlib-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/newlib-esp32/archive/"
                        "d2317703d6643e0081b97652f1ce728296494d5f.tar.gz"))
    (file-name (string-append "newlib-esp32-" %esp-newlib-version ".tar.gz"))
    (sha256
     (base32
      "0w4k3jxy8vx0gaqxvzz8h0mvc3mmx0para3dbks31jrwkacf2ip7"))
    (patches (list (local-file "patches/newlib-esp32-stdatomic-gcc-atomics.patch")))))

(define-public newlib-esp-headers
  (lambda* (target xgcc xbinutils #:key (xtensa-dynconfig #f))
    "Newlib headers from Espressif's newlib-esp32 fork.
The headers are installed under <output>/<target>/include.  They are needed
by ESP-IDF alongside picolibc because Espressif's picolibc build keeps some
legacy newlib headers (e.g. reent.h) that ESP-IDF source files include
directly."
    (package
    (name (string-append target "-newlib-esp-headers"))
    (version %esp-newlib-version)
    (source %esp-newlib-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(list (string-append "--target=" #$target)
              "--prefix=/"
              "--disable-multilib"
              "--disable-libgloss"
              "--disable-newlib-supplied-syscalls"
              "--enable-newlib-nano-formatted-io"
              "--enable-newlib-nano-malloc"
              "--enable-newlib-reent-small"
              "--disable-nls")
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'set-cross-path
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "PATH"
                      (string-append (assoc-ref inputs "xgcc") "/bin:"
                                     (assoc-ref inputs "xbinutils") "/bin:"
                                     (getenv "PATH")))
              ;; The Xtensa cross compiler needs the chip-specific dynconfig
              ;; shared objects to run at all (even for configure tests).
              #$@(if xtensa-dynconfig
                     '((let ((dynconfig (assoc-ref inputs "xtensa-dynconfig")))
                         (setenv "XTENSA_GNU_CONFIG"
                                 (string-append dynconfig "/lib/"))
                         #t))
                     '())
              #t))
          ;; We only need the newlib headers; compiling the C library is slow
          ;; and, for Xtensa, requires overlay-generated headers we do not use.
          (replace 'build
            (lambda _
              #t))
          (replace 'install
            (lambda _
              (let ((stage (string-append (getcwd) "/stage"))
                    (target #$target))
                (mkdir-p stage)
                ;; The top-level configure only creates the root Makefile.
                ;; Configure the newlib subdir explicitly, then install only
                ;; the header data files (install-data also builds the .a
                ;; libraries as a side effect, but it works for both RISC-V
                ;; and Xtensa and is much faster than a full newlib build).
                (invoke "make" "configure-target-newlib")
                (invoke "make" "-C" (string-append target "/newlib")
                        "install-data" (string-append "DESTDIR=" stage))
                (let ((out #$output)
                      (inc (string-append stage "/" target "/include")))
                  (copy-recursively inc
                                    (string-append out "/" target "/include"))
                  ;; Newlib's stdatomic.h uses typedefs such as __uint_fast8_t
                  ;; that are defined in <machine/_default_types.h>.  The header
                  ;; does not include it itself, relying on other newlib headers
                  ;; having been included first.  When it is used alongside
                  ;; picolibc (which provides its own stdint.h and
                  ;; machine/_default_types.h without those typedefs), the
                  ;; typedefs are missing.  Include newlib's own
                  ;; machine/_default_types.h with a quoted include so the
                  ;; compiler finds the copy next to stdatomic.h before any
                  ;; picolibc header.  The same header also references the
                  ;; internal type ___wchar_t, which newlib normally expects to
                  ;; be provided by earlier includes; define it from __wchar_t
                  ;; now that machine/_default_types.h is available.
                  (let ((stdatomic (string-append out "/" target "/include/stdatomic.h"))
                        (default-types (string-append out "/" target "/include/machine/_default_types.h")))
                    (when (file-exists? stdatomic)
                      (substitute* stdatomic
                        (("#include <sys/_types.h>")
                         (string-append
                          "#include <sys/_types.h>\n"
                          "#include \"machine/_default_types.h\"\n"
                          "#ifndef ___wchar_t_defined\n"
                          "typedef __wchar_t ___wchar_t;\n"
                          "#define ___wchar_t_defined\n"
                          "#endif"))))
                    ;; Picolibc also installs a machine/_default_types.h with the
                    ;; same include guard.  If it is included first, newlib's copy
                    ;; is skipped and the __int_fast* types that stdatomic.h needs
                    ;; are never defined.  Use a newlib-specific guard so both
                    ;; files can be processed.
                    (when (file-exists? default-types)
                      (substitute* default-types
                        (("_MACHINE__DEFAULT_TYPES_H")
                         "_MACHINE__DEFAULT_TYPES_H_NEWLIB")))))
                #t))))))
    (native-inputs
     `(,@(if xtensa-dynconfig
            `(("xtensa-dynconfig" ,xtensa-dynconfig))
            '())
       ("xgcc" ,xgcc)
       ("xbinutils" ,xbinutils)
       ("texinfo" ,texinfo)))
    (home-page "https://github.com/espressif/newlib-esp32")
    (synopsis (string-append "Newlib headers for " target))
    (description
     "This package installs the newlib C library headers from Espressif's
newlib-esp32 fork.  It is used as a companion to picolibc because ESP-IDF
source files still include some legacy newlib headers such as reent.h.")
    (license license:gpl3+))))

(define-public %esp-picolibc-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/picolibc/archive/"
                        "b38cf745956c975b39e550c7318d9ef24f499cb7.tar.gz"))
    (file-name (string-append "picolibc-esp-" %esp-picolibc-version ".tar.gz"))
    (sha256
     (base32
      "0nanfs4pkw8wpd2ib70k89nkc0fn80ja4kaa6rhifsgb2gw57xq8"))))

(define-public %esp-llvm-version "21.1.3_20260408")

(define-public %esp-llvm-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/llvm-project/archive/"
                        "18ba62951fcf68db2d3b57ea9a9c7a34363d55f8.tar.gz"))
    (file-name (string-append "llvm-project-esp-" %esp-llvm-version ".tar.gz"))
    (sha256
     (base32
      "0m7bwn7f48sf6laa6qw91pd55zlrbyiwwy4cwy2zfp420gv5024c"))))

;;;
;;; Base packages shared by the RISC-V and Xtensa ESP-IDF toolchains.
;;;
(define-public binutils-esp
  (package
    (inherit binutils)
    (name "binutils-esp")
    (version %esp-binutils-version)
    (source %esp-binutils-source)
    (native-inputs
     (modify-inputs (package-native-inputs binutils)
       (prepend flex)
       (prepend bison)
       (prepend perl)))
    (arguments
     (substitute-keyword-arguments (package-arguments binutils)
       ((#:configure-flags flags)
        #~(append (list "--disable-gdb"
                        "--disable-gdbserver"
                        "--disable-sim")
                  #$flags))))))

(define-public gcc-16-esp
  (package
    (inherit gcc-16)
    (name "gcc-16-esp")
    (version %esp-gcc-version)
    (source %esp-gcc-source)
    (native-inputs
     (modify-inputs (package-native-inputs gcc-16)
       (prepend flex)))
    (arguments
     (substitute-keyword-arguments (package-arguments gcc-16)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'pre-generate-gengtype-lex
              (lambda _
                ;; Espressif's GCC tarball does not ship the flex-generated
                ;; gcc/gengtype-lex.cc that the upstream GNU GCC tarball
                ;; includes.  Generate it up-front so the parallel build does
                ;; not race on this file.  The GCC Makefile prepends a small
                ;; header to the flex output, so we replicate that here.
                (let ((generated "gcc/gengtype-lex.cc")
                      (tmp "gcc/gengtype-lex.cc.tmp"))
                  (invoke "flex" "-o" generated "gcc/gengtype-lex.l")
                  (call-with-output-file tmp
                    (lambda (out)
                      (display "#ifdef HOST_GENERATOR_FILE\n" out)
                      (display "#include \"config.h\"\n" out)
                      (display "#else\n" out)
                      (display "#include \"bconfig.h\"\n" out)
                      (display "#endif\n" out)
                      (display "#define FLEX_SCANNER\n" out)
                      (display "#include \"system.h\"\n" out)
                      (display "#undef FLEX_SCANNER\n" out)
                      (call-with-input-file generated
                        (lambda (in)
                          (dump-port in out)))))
                  (rename-file tmp generated))
                #t))))))))
