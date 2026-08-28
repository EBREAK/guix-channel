(define-module (ebreak packages xtensa-esp-elf-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (ebreak packages esp-toolchain-sources)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1))

(define %target "xtensa-esp-elf")

;;; The Espressif Xtensa GCC uses a hard-coded multilib configuration in
;;; gcc/config/xtensa/t-esp-multilib.  It relies on chip-specific dynamic
;;; configuration shared objects (xtensa_*.so) built from the xtensa-dynconfig
;;; and xtensa-overlays repositories.

(define %xtensa-dynconfig-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/xtensa-dynconfig/archive/"
                        "905b913aa65638be53ac22029c379fa16dab31db.tar.gz"))
    (file-name "xtensa-dynconfig-905b913.tar.gz")
    (sha256
     (base32
      "1727y2vdgzxra308113w5y1y71bkvcxmkpy4jkmvkfvp4vzy6rak"))))

(define %xtensa-overlays-source
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/xtensa-overlays/archive/"
                        "dd1cf19f6eb327a9db51043439974a6de13f5c7f.tar.gz"))
    (file-name "xtensa-overlays-dd1cf19.tar.gz")
    (sha256
     (base32
      "0micz63bw1kjamyfl26kdxird7f1qiili3zaw95rs86468wlxx1g"))))

;;;
;;; 1. Xtensa dynamic configuration libraries.
;;;
;;; These shared objects provide the per-chip configuration that the Xtensa
;;; GCC uses when compiling with -mdynconfig=xtensa_*.so.  They must be
;;; available on the build host whenever GCC builds multilib variants.
;;;
(define-public xtensa-dynconfig-esp
  (package
    (name "xtensa-dynconfig-esp")
    (version "20241011")
    (source %xtensa-dynconfig-source)
    (build-system gnu-build-system)
    (native-inputs
     `(("tar" ,tar)
       ("xtensa-overlays" ,%xtensa-overlays-source)))
    (arguments
     (list
      #:tests? #f
      #:make-flags #~(list "CC=gcc"
                           "CONF_DIR=xtensa-overlays"
                           (string-append "PREFIX=" #$output))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-after 'unpack 'install-overlays
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((overlays-root (assoc-ref inputs "xtensa-overlays"))
                    (tar (string-append (assoc-ref inputs "tar") "/bin/tar")))
                (mkdir-p "xtensa-overlays")
                (if (file-is-directory? overlays-root)
                    (let ((dir (car (scandir overlays-root
                                             (lambda (entry)
                                               (and (not (member entry '("." "..")))
                                                    (file-is-directory?
                                                     (string-append overlays-root "/" entry))))))))
                      (copy-recursively (string-append overlays-root "/" dir)
                                        "xtensa-overlays"
                                        #:keep-mtime? #t))
                    (invoke tar "-xzf" overlays-root "-C" "xtensa-overlays" "--strip-components=1"))
                #t)))
          (replace 'build
            (lambda* (#:key make-flags #:allow-other-keys)
              (apply invoke "make" "libs" make-flags)))
          (replace 'install
            (lambda* (#:key make-flags #:allow-other-keys)
              (apply invoke "make" "install" make-flags))))))
    (home-page "https://github.com/espressif/xtensa-dynconfig")
    (synopsis "Xtensa dynamic configuration libraries for Espressif SoCs")
    (description
     "This package builds the xtensa_esp32.so, xtensa_esp32s2.so,
xtensa_esp32s3.so and xtensa_esp8266.so dynamic configuration objects used by
Espressif's Xtensa GCC fork for chip-specific multilib builds.")
    (license license:gpl3+)))

;;;
;;; 2. picolibc: Espressif's fork configured for xtensa-esp-elf.
;;;
(define-public xtensa-esp-elf-picolibc
  (package
    (name "xtensa-esp-elf-picolibc")
    (version %esp-picolibc-version)
    (source %esp-picolibc-source)
    (build-system meson-build-system)
    (arguments
     (list
      #:build-type "release"
      #:configure-flags
      #~(list (string-append "--cross-file=" (getcwd) "/cross-xtensa-esp-elf.txt")
              (string-append "-Dspecsdir=" #$%target "/lib")
              "-Dmultilib-exclude=esp8266"
              "-Dtests=false"
              "-Derrno-function=auto"
              "-Dio-long-long=true"
              "-Dsysroot-install=true"
              "-Dsysroot-install-skip-checks=true"
              "-Dsemihost=false"
              "-Dpicocrt=false"
              "-Dpicocrt-lib=false"
              "-Dio-c99-formats=true"
              "-Dio-pos-args=true"
              "-Dposix-console=true"
              "-Dstdio-locking=true"
              "-Dfast-bufio=true"
              (string-append "--libdir=" #$output "/" #$%target "/lib")
              (string-append "--includedir=" #$output "/" #$%target "/include"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-nosys-stubs
            (lambda _
              ;; These nosys stubs reference headers that are not provided by
              ;; picolibc for bare-metal targets (ftw.h, sys/statvfs.h).
              (substitute* "libc/nosys/meson.build"
                (("^[ \t]*'fstatvfs.c',\n") "")
                (("^[ \t]*'statvfs.c',\n") "")
                (("^[ \t]*'ftw.c',\n") "")
                (("^[ \t]*'nftw.c',\n") ""))
              ;; sf_sqrt.c includes the chip-specific Xtensa overlay header
              ;; directly.  Picolibc ships a generic fallback in
              ;; <machine/core-isa.h>, so use that instead.
              (substitute* "libm/machine/xtensa/sf_sqrt.c"
                (("#include <xtensa/config/core-isa.h>")
                 "#include <machine/core-isa.h>"))
              #t))
          (add-before 'configure 'prepare-cross-file
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((xgcc (assoc-ref inputs "xgcc"))
                     (xbin (assoc-ref inputs "xbinutils"))
                     (dynconfig (assoc-ref inputs "xtensa-dynconfig"))
                     (target #$%target)
                     (cc (string-append xgcc "/bin/" target "-gcc"))
                     (ar (string-append xbin "/bin/" target "-ar"))
                     (as (string-append xbin "/bin/" target "-as"))
                     (ld (string-append xbin "/bin/" target "-ld"))
                     (nm (string-append xbin "/bin/" target "-nm"))
                     (objcopy (string-append xbin "/bin/" target "-objcopy"))
                     (strip (string-append xbin "/bin/" target "-strip"))
                     (dynconfig-dir (string-append dynconfig "/lib/"))
                     (cross-file (string-append (dirname (getcwd))
                                                "/cross-xtensa-esp-elf.txt")))
                (unless (file-exists? cross-file)
                  (call-with-output-file cross-file
                    (lambda (port)
                      (format port "[binaries]
                              c = '~a'
                              ar = '~a'
                              as = '~a'
                              ld = '~a'
                              nm = '~a'
                              objcopy = '~a'
                              strip = '~a'

                              [host_machine]
                              system = 'none'
                              cpu_family = 'xtensa'
                              cpu = 'xtensa'
                              endian = 'little'

                              [properties]
                              c_args = ['-g', '-mlongcalls']
                              c_link_args = ['-g', '-mlongcalls']
                              skip_sanity_check = true
                              needs_exe_wrapper = true
"
                              cc ar as ld nm objcopy strip))))
                ;; Point to the directory of chip-specific dynconfig shared
                ;; objects (trailing slash required by the loader).  Without an
                ;; explicit -mdynconfig option the compiler/assembler fall back
                ;; to the default ESP32 little-endian configuration embedded in
                ;; the toolchain, which is sufficient for building picolibc.
                (setenv "XTENSA_GNU_CONFIG" dynconfig-dir)
                #t))))))
    (native-inputs
     `(("xgcc" ,gcc-cross-sans-libc-xtensa-esp-elf)
       ("xbinutils" ,(cross-binutils %target #:binutils binutils-esp))
       ("xtensa-dynconfig" ,xtensa-dynconfig-esp)
       ("meson" ,meson)
       ("ninja" ,ninja)
       ("pkg-config" ,pkg-config)))
    (home-page "https://keithp.com/picolibc/")
    (synopsis "PicoLIBC for xtensa-esp-elf")
    (description
     "PicoLIBC built from Espressif's fork for the xtensa-esp-elf target.
It is used as the C library of the bare-metal Xtensa ESP-IDF toolchain.")
    (license (license:non-copyleft "file://COPYING"))))

;;;
;;; 3. Bootstrap cross GCC (no C library) used to build picolibc.
;;;
(define (gcc-cross-sans-libc-xtensa-esp-elf-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c"
                     "--enable-multilib"
                     "--disable-__cxa-atexit"
                     "--enable-cxx-flags=-ffunction-sections -fdata-sections -mlongcalls"
                     "--disable-libgomp"
                     "--disable-libmudflap"
                     "--disable-libmpx"
                     "--disable-libssp"
                     "--disable-libquadmath"
                     "--disable-libquadmath-support"
                     "--disable-libstdcxx-verbose"
                     "--enable-lto"
                     "--enable-target-optspace"
                     "--without-long-double-128"
                     "--enable-plugin"
                     "--disable-nls"
                     "--enable-multiarch"
                     (string-append "--with-as="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-as")
                     (string-append "--with-ld="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-ld"))
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)
                             (string-prefix? "--disable-multilib" flag)
                             (string-prefix? "--enable-multilib" flag)
                             (string-prefix? "--with-as=" flag)
                             (string-prefix? "--with-ld=" flag)))
                       #$flags)))
    ((#:make-flags flags)
     ;; The multilib subdirs add -mdynconfig=xtensa_*.so to the target
     ;; compiler flags.  Point XTENSA_GNU_CONFIG to the directory containing
     ;; the chip-specific shared objects (trailing slash required by the
     ;; dynconfig loader) so the loader can resolve the bare filenames.
     #~(list (string-append "XTENSA_GNU_CONFIG="
                            (assoc-ref %build-inputs "xtensa-dynconfig-esp")
                            "/lib/")))
    ((#:phases phases)
     #~(modify-phases #$phases
         ;; Make the dynconfig directory visible during the configure phase as
         ;; well (the multilib libgcc configure runs as a child of make, but
         ;; the top-level configure also needs it for compiler sanity checks).
         (add-after 'unpack 'set-xtensa-default-dynconfig
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((dynconfig (assoc-ref inputs "xtensa-dynconfig-esp")))
               (setenv "XTENSA_GNU_CONFIG"
                       (string-append dynconfig "/lib/"))
               #t)))))))

(define-public gcc-cross-sans-libc-xtensa-esp-elf
  (let ((base (cross-gcc %target
                         #:xgcc gcc-16-esp
                         #:xbinutils (cross-binutils %target #:binutils binutils-esp)
                         #:libc #f)))
    (package
      (inherit base)
      (name "gcc-cross-sans-libc-xtensa-esp-elf")
      (arguments (gcc-cross-sans-libc-xtensa-esp-elf-arguments base %target))
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static")
         (prepend xtensa-dynconfig-esp)
         (prepend flex)
         (prepend python-minimal)
         (prepend which))))))

;;; Newlib headers are still required by ESP-IDF source files (e.g. reent.h)
;;; even though the C library itself is picolibc.
(define-public xtensa-esp-elf-newlib-esp-headers
  (newlib-esp-headers %target
                      gcc-cross-sans-libc-xtensa-esp-elf
                      (cross-binutils %target #:binutils binutils-esp)
                      #:xtensa-dynconfig xtensa-dynconfig-esp))

;;;
;;; 4. Cross GCC using picolibc as the target C library.
;;;
(define (gcc-cross-xtensa-esp-elf-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c,c++"
                     "--enable-multilib"
                     "--disable-__cxa-atexit"
                     "--enable-cxx-flags=-ffunction-sections -fdata-sections -mlongcalls"
                     "--disable-libgomp"
                     "--disable-libmudflap"
                     "--disable-libmpx"
                     "--disable-libssp"
                     "--disable-libquadmath"
                     "--disable-libquadmath-support"
                     "--disable-libstdcxx-verbose"
                     "--enable-lto"
                     "--enable-target-optspace"
                     "--without-long-double-128"
                     "--enable-plugin"
                     "--disable-nls"
                     "--enable-multiarch"
                     "--enable-threads=posix"
                     "--enable-libstdcxx-time=yes"
                     "--disable-shared"
                     "--with-newlib"
                     "--disable-win32-utf8-manifest"
                     (string-append "--with-native-system-header-dir="
                                    (assoc-ref %build-inputs "libc")
                                    "/" #$target "/include")
                     (string-append "--with-as="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-as")
                     (string-append "--with-ld="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-ld"))
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)
                             (string-prefix? "--disable-multilib" flag)
                             (string-prefix? "--enable-multilib" flag)
                             (string-prefix? "--with-as=" flag)
                             (string-prefix? "--with-ld=" flag)))
                       #$flags)))
    ((#:make-flags flags)
     #~(list (string-append "FLAGS_FOR_TARGET=-B"
                            (assoc-ref %build-inputs "libc")
                            "/" #$target "/lib")
             ;; The multilib subdirs add -mdynconfig=xtensa_*.so to the target
             ;; compiler flags.  Point XTENSA_GNU_CONFIG to the directory of
             ;; chip-specific shared objects (trailing slash required).
             (string-append "XTENSA_GNU_CONFIG="
                            (assoc-ref %build-inputs "xtensa-dynconfig-esp")
                            "/lib/")))
    ((#:phases phases)
     #~(modify-phases #$phases
         (add-after 'unpack 'set-xtensa-default-dynconfig
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((dynconfig (assoc-ref inputs "xtensa-dynconfig-esp")))
               ;; Point to the directory (trailing slash is required so the
               ;; dynconfig loader treats it as a directory): the default
               ;; -mdynconfig selects the ESP32 little-endian config, while
               ;; multilib subdirs override it with their own chip config.
               (setenv "XTENSA_GNU_CONFIG"
                       (string-append dynconfig "/lib/"))
               #t)))
         (replace 'set-cross-path
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((libc (assoc-ref inputs "libc"))
                   (target #$target))
               ;; Build-time only: the cross compiler is patched to honour
               ;; CROSS_* paths while keeping target headers out of the host
               ;; compiler's search path.
               (setenv "CROSS_C_INCLUDE_PATH"
                       (string-append libc "/" target "/include"))
               (setenv "CROSS_CPLUS_INCLUDE_PATH"
                       (string-append libc "/" target "/include"))
               (setenv "CROSS_LIBRARY_PATH"
                       (string-append libc "/" target "/lib")))
             #t))
         (add-after 'install 'install-picolibc-files
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((libc (assoc-ref inputs "libc"))
                    (lib-output (assoc-ref outputs "lib"))
                    (target #$target)
                    (gcc (string-append (assoc-ref outputs "out")
                                        "/bin/" target "-gcc"))
                    (ar (string-append (assoc-ref inputs "binutils-cross")
                                       "/bin/" target "-ar"))
                    (include-dir (string-append lib-output "/" target "/include"))
                    (lib-dir (string-append lib-output "/" target "/lib"))
                    (empty (string-append (getcwd) "/empty.o")))
               (copy-recursively (string-append libc "/" target "/include")
                                 include-dir)
               (copy-recursively (string-append libc "/" target "/lib")
                                 lib-dir)
               (with-output-to-file "empty.c"
                 (lambda () (display "/* empty */\n")))
               (invoke gcc "-c" "empty.c" "-o" empty)
               (for-each
                (lambda (dir)
                  (let ((stub (string-append dir "/libgloss.a")))
                    (mkdir-p dir)
                    (invoke ar "rcs" stub empty)))
                (cons lib-dir
                      (map (lambda (line)
                             (let ((relative (car (string-split line #\;))))
                               (string-append lib-dir "/" relative)))
                           (string-split
                            (with-output-to-string
                              (lambda ()
                                (invoke gcc "--print-multi-lib")))
                            #\newline))))
               #t)))
           (add-after 'install-picolibc-files 'install-minimal-crt0
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((lib-output (assoc-ref outputs "lib"))
                      (target #$%target)
                      (gcc (string-append (assoc-ref outputs "out")
                                          "/bin/" target "-gcc"))
                      (lib-dir (string-append lib-output "/" target "/lib"))
                      (dynconfig-dir (string-append (assoc-ref inputs "xtensa-dynconfig-esp")
                                                    "/lib"))
                      (crt0-c (string-append (getcwd) "/crt0-minimal.c"))
                      (base-crt0 (string-append lib-dir "/crt0.o")))
                 ;; ESP-IDF uses -nostartfiles and provides its own startup,
                 ;; but CMake's compiler sanity test needs a working default
                 ;; link.  The picolibc build does not install crt0.o, so
                 ;; provide a minimal stub written in C so the compiler emits
                 ;; instructions valid for the default Xtensa configuration.
                 ;; This file is only a fallback for the compiler sanity test,
                 ;; not a real runtime startup.
                 ;; The Xtensa assembler needs a core dynconfig to recognise
                 ;; even basic instructions.  XTENSA_GNU_CONFIG must point to
                 ;; the actual shared object (not the directory) for GCC and
                 ;; binutils to load it as the default configuration.
                 (setenv "XTENSA_GNU_CONFIG"
                         (string-append dynconfig-dir "/xtensa_esp32.so"))
                 (with-output-to-file crt0-c
                   (lambda ()
                     (display "__attribute__((noreturn)) void _start(void) { while (1); }\n")))
                 (invoke gcc "-c" crt0-c "-o" base-crt0)
                 (for-each
                  (lambda (line)
                    (let ((relative (car (string-split line #\;))))
                      (unless (string=? relative ".")
                        (let ((dest (string-append lib-dir "/" relative "/crt0.o")))
                          (mkdir-p (dirname dest))
                          (copy-file base-crt0 dest)))))
                  (string-split (with-output-to-string
                                  (lambda ()
                                    (invoke gcc "--print-multi-lib")))
                                #\newline))
                 #t)))
           (add-after 'install-minimal-crt0 'remove-libstdcxx-modules-json
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((lib-output (assoc-ref outputs "lib")))
                 (for-each delete-file
                           (find-files lib-output "\\.modules\\.json$"))
                 #t)))))))

(define-public gcc-cross-xtensa-esp-elf
  (let ((base (cross-gcc %target
                         #:xgcc gcc-16-esp
                         #:xbinutils (cross-binutils %target #:binutils binutils-esp)
                         #:libc xtensa-esp-elf-picolibc)))
    (package
      (inherit base)
      (name "gcc-cross-xtensa-esp-elf")
      (arguments (gcc-cross-xtensa-esp-elf-arguments base %target))
      ;; Do not export CROSS_* search-path variables into the user's shell;
      ;; the toolchain meta-package uses wrapper scripts and specs files to
      ;; locate libraries and headers.
      (native-search-paths '())
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static")
         (prepend xtensa-dynconfig-esp)
         (prepend flex)
         (prepend python-minimal)
         (prepend which))))))

;;;
;;; 5. Meta-package: bundles binutils, GCC, picolibc and dynconfig.
;;;
(define-public xtensa-esp-elf-toolchain
  (package
    (name "xtensa-esp-elf-toolchain")
    (version (package-version gcc-cross-xtensa-esp-elf))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (gcc-real (string-append #$gcc-cross-xtensa-esp-elf
                                          "/bin/xtensa-esp-elf-gcc"))
                 (gcc-lib #$(gexp-input gcc-cross-xtensa-esp-elf "lib"))
                 (gcc-version (car (string-split #$%esp-gcc-version #\_)))
                 (bash-sh (string-append (assoc-ref %build-inputs "bash")
                                         "/bin/sh"))
                 (grep-cmd (string-append (assoc-ref %build-inputs "grep")
                                          "/bin/grep"))
                 (sed-cmd (string-append (assoc-ref %build-inputs "sed")
                                         "/bin/sed")))

            (define (gcc-cross-lib-paths lib-root target)
              "Return the library search directories for GCC's runtime and
 target C library.  These live in the 'lib' output of the cross compiler."
              (string-append lib-root "/lib/gcc/" target "/" gcc-version ":"
                             lib-root "/" target "/lib"))
            (define cross-library-path
              (string-append out "/" #$%target "/lib"
                             ":" (gcc-cross-lib-paths gcc-lib #$%target)))
            (define cross-library-flags
              (string-join (map (lambda (dir)
                                  (string-append "-B" dir))
                                (string-split cross-library-path #\:))
                           " "))

            ;; Picolibc's installed specs file uses %:getenv(GCC_EXEC_PREFIX ...)
            ;; to build relocatable include/library paths.  With Guix's split
            ;; "out"/"lib" GCC outputs and the multilib layout this produces
            ;; malformed paths for C++ and the startup files, so we generate a
            ;; fixed specs file under <out>/<target>/lib and put that directory
            ;; first on the library search path so GCC finds it before the original.
            (define (write-picolibc-specs file target gcc-lib gcc-version newlib-include)
              "Write a picolibc.specs with absolute Guix store paths.
NEWLIB-INCLUDE is added after the picolibc include directory because ESP-IDF
still includes some legacy newlib headers (e.g. reent.h)."
              (let ((picolibc-include (string-append gcc-lib "/" target "/include"))
                    (gcc-libgcc-dir (string-append gcc-lib "/lib/gcc/" target
                                                   "/" gcc-version))
                    (picolibc-lib-dir (string-append gcc-lib "/" target "/lib")))
                (mkdir-p (dirname file))
                (with-output-to-file file
                  (lambda ()
                    (format #t "%rename link picolibc_link~%")
                    (format #t "%rename link_libgcc picolibc_link_libgcc~%")
                    (format #t "%rename cpp picolibc_cpp~%")
                    (format #t "%rename cc1 picolibc_cc1~%")
                    (format #t "%rename cc1plus picolibc_cc1plus~%")
                    (format #t "~%*cpp:~%")
                    (format #t "-isystem ~a/ -isystem ~a/ %{-printf=*: -D_PICOLIBC_PRINTF='%*'} %{-scanf=*: -D_PICOLIBC_SCANF='%*'} %(picolibc_cpp)~%" picolibc-include newlib-include)
                    (format #t "~%*cc1:~%")
                    (format #t "%{!ftls-model:-ftls-model=local-exec}   %(picolibc_cc1)~%")
                    (format #t "~%*cc1plus:~%")
                    (format #t "-isystem ~a/ -isystem ~a/ %{!ftls-model:-ftls-model=local-exec}    %(picolibc_cc1plus)~%" picolibc-include newlib-include)
                    (format #t "~%*link_libgcc:~%")
                    (format #t "-L~a/%M -L~a %(picolibc_link_libgcc)~%" gcc-libgcc-dir gcc-libgcc-dir)
                    (format #t "~%*link:~%")
                    (format #t "%{DPICOLIBC_DOUBLE_PRINTF_SCANF:--defsym=vfprintf=__d_vfprintf} %{DPICOLIBC_DOUBLE_PRINTF_SCANF:--defsym=vfscanf=__d_vfscanf} %{DPICOLIBC_FLOAT_PRINTF_SCANF:--defsym=vfprintf=__f_vfprintf} %{DPICOLIBC_FLOAT_PRINTF_SCANF:--defsym=vfscanf=__f_vfscanf} %{DPICOLIBC_LONG_LONG_PRINTF_SCANF:--defsym=vfprintf=__l_vfprintf} %{DPICOLIBC_LONG_LONG_PRINTF_SCANF:--defsym=vfscanf=__l_vfscanf} %{DPICOLIBC_INTEGER_PRINTF_SCANF:--defsym=vfprintf=__i_vfprintf} %{DPICOLIBC_INTEGER_PRINTF_SCANF:--defsym=vfscanf=__i_vfscanf} %{DPICOLIBC_MINIMAL_PRINTF_SCANF:--defsym=vfprintf=__m_vfprintf} %{DPICOLIBC_MINIMAL_PRINTF_SCANF:--defsym=vfscanf=__m_vfscanf} -L~a/%M -L~a %{-printf=*:--defsym=vfprintf=__%*_vfprintf} %{-scanf=*:--defsym=vfscanf=__%*_vfscanf} %{!T:-Tpicolibc.ld}  %(picolibc_link)~%" picolibc-lib-dir picolibc-lib-dir)
                    (format #t "~%*lib:~%")
                    (format #t "--start-group %(libgcc)  -lc %{-oslib=*:-l%*} --end-group~%")
                    (format #t "~%*endfile:~%")
                    (format #t "~%")
                    (format #t "~%*startfile:~%")
                    ;; Use the top-level crt0.o for every multilib variant.  The
                    ;; minimal crt0.o is only a fallback for CMake's compiler
                    ;; sanity test; ESP-IDF builds use -nostartfiles and provide
                    ;; their own startup.
                    (format #t "~a/%{-crt0=*:crt0-%*%O; :crt0%O}~%" picolibc-lib-dir)))))
            (write-picolibc-specs (string-append out "/" #$%target "/lib/picolibc.specs")
                                  #$%target gcc-lib gcc-version
                                  (string-append #$xtensa-esp-elf-newlib-esp-headers
                                                 "/" #$%target "/include"))

            (mkdir-p (string-append out "/bin"))
            (for-each
             (lambda (input)
               (let ((bin (string-append input "/bin")))
                 (when (directory-exists? bin)
                   (for-each
                    (lambda (file)
                      (let ((linkname (string-append out "/bin/"
                                                     (basename file))))
                        (unless (file-exists? linkname)
                          (symlink file linkname))))
                    (find-files bin ".*" #:stat lstat)))))
             (list #$(cross-binutils %target #:binutils binutils-esp)
                   #$gcc-cross-xtensa-esp-elf
                   #$xtensa-esp-elf-picolibc
                   #$xtensa-dynconfig-esp))

            ;; Provide a cross-`as` under the bare name as well, so scripts that
            ;; rely on the plain assembler name find the right one on PATH.
            (let ((as-link (string-append out "/bin/as"))
                  (target-as (string-append out "/bin/" #$%target "-as")))
              (unless (file-exists? as-link)
                (symlink target-as as-link)))

            ;; The source-built GCC's --version does not include the
            ;; crosstool-NG tag that ESP-IDF's idf_tools.py expects.  Wrap the
            ;; base GCC driver so it reports the expected version string while
            ;; still delegating all real work to the compiler.
            (let ((gcc-wrapper (string-append out "/bin/xtensa-esp-elf-gcc"))
                  (gcc-exec-prefix (string-append (dirname (dirname gcc-real))
                                                  "/libexec/gcc/")))
              (when (file-exists? gcc-wrapper)
                (delete-file gcc-wrapper))
              (with-output-to-file gcc-wrapper
                (lambda ()
                  ;; Use the store bash so this wrapper can be executed directly
                  ;; in build containers where /bin/sh does not exist.
                  (format #t "#!~a~%" bash-sh)
                  ;; The cross compiler was built with a placeholder prefix; tell
                  ;; GCC where its subprograms (cc1, collect2, ...) live.
                  (format #t "export GCC_EXEC_PREFIX=~a~%" gcc-exec-prefix)
                  ;; The runtime libraries are in a separate "lib" output that
                  ;; the compiler cannot locate from argv[0]; pass their
                  ;; directories explicitly via -B prefixes.
                  (format #t "if printf '%s\\n' \"$@\" | ~a -qx -- '--version'; then~%"
                          grep-cmd)
                  (format #t "  ~a ~a \"$@\" | ~a '1{/(crosstool-NG/!s/$/ (crosstool-NG esp-~a)/}'~%"
                          gcc-real cross-library-flags sed-cmd #$%esp-gcc-version)
                  (format #t "else~%")
                  (format #t "  exec ~a ~a \"$@\"~%" gcc-real cross-library-flags)
                  (format #t "fi~%")))
              (chmod gcc-wrapper #o555))

            ;; ESP-IDF expects chip-specific compiler names such as
            ;; xtensa-esp32-elf-gcc.  The multilib xtensa-esp-elf-gcc
            ;; supports all chips via -mdynconfig, but GCC/binutils load the
            ;; dynamic config through the XTENSA_GNU_CONFIG environment
            ;; variable, which must point to the actual .so file (not the
            ;; directory).  Create small wrapper scripts for each chip that
            ;; set XTENSA_GNU_CONFIG before invoking the real tool.
            (mkdir-p (string-append out "/lib"))
            (for-each
             (lambda (chip.so)
               (let* ((chip (car chip.so))
                      (so (cdr chip.so))
                      (lib-so (string-append out "/lib/" so)))
                 (symlink (string-append #$xtensa-dynconfig-esp "/lib/" so)
                          lib-so)))
             '(("esp32" . "xtensa_esp32.so")
               ("esp32s2" . "xtensa_esp32s2.so")
               ("esp32s3" . "xtensa_esp32s3.so")
               ("esp8266" . "xtensa_esp8266.so")))
            (for-each
             (lambda (file)
               (let ((name (basename file)))
                 (when (string-prefix? "xtensa-esp-elf-" name)
                   (let ((tool (string-drop name 15)))
                     (for-each
                      (lambda (chip)
                        (let ((wrapper (string-append out "/bin/xtensa-"
                                                      chip "-elf-" tool))
                              (dynconfig (string-append out "/lib/xtensa_"
                                                        chip ".so")))
                          (unless (file-exists? wrapper)
                            (with-output-to-file wrapper
                              (lambda ()
                                ;; Use the store bash so chip wrappers can be
                                ;; executed directly in build containers.
                                (format #t "#!~a~%" bash-sh)
                                (format #t "export XTENSA_GNU_CONFIG=~a~%"
                                        dynconfig)
                                ;; GCC needs an explicit -mdynconfig option to
                                ;; select the correct multilib subdirectory for
                                ;; the chip.  Without it the compiler falls back
                                ;; to the top-level (big-endian) libgcc objects.
                                ;; The assembler and other binutils only need
                                ;; XTENSA_GNU_CONFIG and do not accept
                                ;; -mdynconfig, so only add it for the drivers.
                                ;; Use POSIX parameter expansion instead of
                                ;; dirname/readlink so the wrapper works in
                                ;; build containers where coreutils is not on
                                ;; PATH.
                                (if (member tool '("gcc" "g++" "c++"))
                                    (format #t "REAL=\"${0%/*}/xtensa-esp-elf-~a\"~%"
                                            tool)
                                    (format #t "exec \"${0%/*}/xtensa-esp-elf-~a\" \"$@\"~%"
                                            tool))
                                (when (member tool '("gcc" "g++" "c++"))
                                  ;; GCC_EXEC_PREFIX is set by the base
                                  ;; xtensa-esp-elf-gcc wrapper, so there is no
                                  ;; need to duplicate it here; only preserve
                                  ;; the library search path via -B prefixes.
                                  (format #t "exec \"$REAL\" ~a -mdynconfig=xtensa_~a.so \"$@\"~%"
                                          cross-library-flags chip))))
                            (chmod wrapper #o555))))
                      '("esp32" "esp32s2" "esp32s3" "esp8266"))))))
             (find-files (string-append out "/bin") ".*" #:stat lstat))
            #t))))
    (native-inputs
     `(;; Build-time tools used to generate the wrapper scripts.
       ("bash" ,bash)
       ("grep" ,grep)
       ("sed" ,sed)))
    (propagated-inputs
     `(("binutils-cross-xtensa-esp-elf" ,(cross-binutils %target #:binutils binutils-esp))
       ("gcc-cross-xtensa-esp-elf" ,gcc-cross-xtensa-esp-elf)
       ("xtensa-esp-elf-picolibc" ,xtensa-esp-elf-picolibc)
       ("xtensa-esp-elf-newlib-esp-headers" ,xtensa-esp-elf-newlib-esp-headers)
       ("xtensa-dynconfig-esp" ,xtensa-dynconfig-esp)))
    (home-page "https://github.com/espressif/crosstool-NG")
    (synopsis "Complete xtensa-esp-elf multilib cross toolchain")
    (description
     "This meta-package provides a complete bare-metal multilib
 cross-compilation toolchain for Espressif's Xtensa MCUs, composed of
 Espressif's Binutils/GDB fork, Espressif's GCC fork, Espressif's
 picolibc fork, newlib compatibility headers, and the Xtensa dynamic
 configuration libraries.")
    (license license:gpl3+)))
