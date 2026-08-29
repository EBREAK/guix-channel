(define-module (ebreak packages riscv32-esp-elf-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (ebreak packages esp-toolchain-sources)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1))

(define %target "riscv32-esp-elf")

;;; Multilib variants extracted from the upstream pre-built toolchain via
;;; `riscv32-esp-elf-gcc --print-multi-lib'.
(define %multilib-generator
  (string-join
   '("rv32i-ilp32--"
     "rv32imc_zmmul_zca-ilp32--"
     "rv32imac_zmmul_zaamo_zalrsc_zca-ilp32--"
     "rv32imafc_zicsr_zmmul_zaamo_zalrsc_zca_zcf-ilp32f--")
   ";"))

;;;
;;; 1. picolibc: Espressif's fork configured for riscv32-esp-elf.
;;;
(define-public riscv32-esp-elf-picolibc
  (package
    (name "riscv32-esp-elf-picolibc")
    (version %esp-picolibc-version)
    (source %esp-picolibc-source)
    (build-system meson-build-system)
    (arguments
     (list
      #:build-type "release"
      #:configure-flags
      #~(list (string-append "--cross-file=" (getcwd) "/cross-riscv32-esp-elf.txt")
              (string-append "-Dspecsdir=" #$%target "/lib")
              "-Dtests=false"
              "-Derrno-function=auto"
              "-Dio-long-long=true"
              "-Dsysroot-install=true"
              "-Dsysroot-install-skip-checks=true"
              "-Dsemihost=false"
              "-Dpicocrt=true"
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
              #t))
          (add-before 'configure 'prepare-cross-file
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((xgcc (assoc-ref inputs "xgcc"))
                     (xbin (assoc-ref inputs "xbinutils"))
                     (target #$%target)
                     (cc (string-append xgcc "/bin/" target "-gcc"))
                     (ar (string-append xbin "/bin/" target "-ar"))
                     (as (string-append xbin "/bin/" target "-as"))
                     (ld (string-append xbin "/bin/" target "-ld"))
                     (nm (string-append xbin "/bin/" target "-nm"))
                     (objcopy (string-append xbin "/bin/" target "-objcopy"))
                     (strip (string-append xbin "/bin/" target "-strip"))
                     (cross-file (string-append (dirname (getcwd))
                                                "/cross-riscv32-esp-elf.txt")))
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
                              cpu_family = 'riscv32'
                              cpu = 'riscv'
                              endian = 'little'

                              [properties]
                              c_args = ['-g', '-mno-cm-popret', '-mno-cm-push-reverse']
                              c_link_args = ['-g', '-mno-cm-popret', '-mno-cm-push-reverse']
                              skip_sanity_check = true
                              needs_exe_wrapper = true
"
                              cc ar as ld nm objcopy strip))))
                #t))))))
    (native-inputs
     `(("xgcc" ,gcc-cross-sans-libc-riscv32-esp-elf)
       ("xbinutils" ,(cross-binutils %target #:binutils binutils-esp))
       ("meson" ,meson)
       ("ninja" ,ninja)
       ("pkg-config" ,pkg-config)))
    (home-page "https://keithp.com/picolibc/")
    (synopsis "PicoLIBC for riscv32-esp-elf")
    (description
     "PicoLIBC built from Espressif's fork for the riscv32-esp-elf target.
It is used as the C library of the bare-metal RISC-V ESP-IDF toolchain.")
    (license (license:non-copyleft "file://COPYING"))))

;;;
;;; 2. Bootstrap cross GCC (no C library) used to build picolibc.
;;;
(define (gcc-cross-sans-libc-riscv32-esp-elf-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c"
                     "--enable-multilib"
                     (string-append "--with-multilib-generator=" #$%multilib-generator)
                     "--with-arch=rv32gc"
                     "--with-abi=ilp32"
                     (string-append "--with-as="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-as")
                     (string-append "--with-ld="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-ld")
                     "--disable-__cxa-atexit"
                     "--enable-cxx-flags=-ffunction-sections -fdata-sections"
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
                     "--enable-multiarch")
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)
                             (string-prefix? "--disable-multilib" flag)
                             (string-prefix? "--enable-multilib" flag)
                             (string-prefix? "--with-multilib-generator=" flag)
                             (string-prefix? "--with-arch=" flag)
                             (string-prefix? "--with-abi=" flag)
                             (string-prefix? "--with-as=" flag)
                             (string-prefix? "--with-ld=" flag)))
                       #$flags)))
    ((#:make-flags flags)
     #~(list))))

(define-public gcc-cross-sans-libc-riscv32-esp-elf
  (let ((base (cross-gcc %target
                         #:xgcc gcc-16-esp
                         #:xbinutils (cross-binutils %target #:binutils binutils-esp)
                         #:libc #f)))
    (package
      (inherit base)
      (name "gcc-cross-sans-libc-riscv32-esp-elf")
      (arguments (gcc-cross-sans-libc-riscv32-esp-elf-arguments base %target))
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static")
         (prepend flex)
         (prepend python-minimal)
         (prepend which))))))

;;; Newlib headers are still required by ESP-IDF source files (e.g. reent.h)
;;; even though the C library itself is picolibc.
(define-public riscv32-esp-elf-newlib-esp-headers
  (newlib-esp-headers %target
                      gcc-cross-sans-libc-riscv32-esp-elf
                      (cross-binutils %target #:binutils binutils-esp)))

;;;
;;; 3. Cross GCC using picolibc as the target C library.
;;;
(define (gcc-cross-riscv32-esp-elf-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c,c++"
                     "--enable-multilib"
                     (string-append "--with-multilib-generator=" #$%multilib-generator)
                     "--with-arch=rv32gc"
                     "--with-abi=ilp32"
                     (string-append "--with-as="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-as")
                     (string-append "--with-ld="
                                    (assoc-ref %build-inputs "binutils-cross")
                                    "/bin/" #$target "-ld")
                     "--disable-__cxa-atexit"
                     "--enable-cxx-flags=-ffunction-sections -fdata-sections"
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
                                    "/" #$target "/include"))
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)
                             (string-prefix? "--disable-multilib" flag)
                             (string-prefix? "--enable-multilib" flag)
                             (string-prefix? "--with-multilib-generator=" flag)
                             (string-prefix? "--with-arch=" flag)
                             (string-prefix? "--with-abi=" flag)
                             (string-prefix? "--with-as=" flag)
                             (string-prefix? "--with-ld=" flag)))
                       #$flags)))
    ((#:make-flags flags)
     #~(list (string-append "FLAGS_FOR_TARGET=-B"
                            (assoc-ref %build-inputs "libc")
                            "/" #$target "/lib")))
    ((#:phases phases)
     #~(modify-phases #$phases
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
         (add-after 'make-cross-binutils-visible 'install-picolibc-files
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
                    (crt0-s (string-append (getcwd) "/crt0-minimal.S"))
                    (base-crt0 (string-append lib-dir "/crt0.o")))
               ;; ESP-IDF uses -nostartfiles and provides its own startup,
               ;; but CMake's compiler sanity test needs a working default
               ;; link.  Picolibc's crt0.o requires symbols from picolibc.ld,
               ;; so replace it with a minimal RV32I stub.  This is only a
               ;; fallback for the compiler sanity test, not a real runtime
               ;; startup.  Compile with the base RV32I instruction set so the
               ;; same object can be copied into every multilib directory.
               (with-output-to-file crt0-s
                 (lambda ()
                   (display "\t.section .text._start,\"ax\",@progbits\n")
                   (display "\t.globl _start\n")
                   (display "\t.type _start, @function\n")
                   (display "_start:\n")
                   (display "1:\tj 1b\n")
                   (display "\t.size _start, .-_start\n")))
               (invoke gcc "-march=rv32i" "-mabi=ilp32" "-c" crt0-s "-o" base-crt0)
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

(define-public gcc-cross-riscv32-esp-elf
  (let ((base (cross-gcc %target
                         #:xgcc gcc-16-esp
                         #:xbinutils (cross-binutils %target #:binutils binutils-esp)
                         #:libc riscv32-esp-elf-picolibc)))
    (package
      (inherit base)
      (name "gcc-cross-riscv32-esp-elf")
      (arguments (gcc-cross-riscv32-esp-elf-arguments base %target))
      ;; Do not export CROSS_* search-path variables into the user's shell;
      ;; the toolchain meta-package uses wrapper scripts and specs files to
      ;; locate libraries and headers.
      (native-search-paths '())
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static")
         (prepend flex)
         (prepend python-minimal)
         (prepend which))))))

;;;
;;; 4. Meta-package: bundles binutils, GCC and picolibc.
;;;
(define-public riscv32-esp-elf-toolchain
  (package
    (name "riscv32-esp-elf-toolchain")
    (version (package-version gcc-cross-riscv32-esp-elf))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (gcc-real (string-append #$gcc-cross-riscv32-esp-elf
                                          "/bin/riscv32-esp-elf-gcc"))
                 (gcc-lib #$(gexp-input gcc-cross-riscv32-esp-elf "lib"))
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
                    (format #t "%{!ftls-model:-ftls-model=local-exec} %{!mstack-protector-guard:-mstack-protector-guard=global}  %(picolibc_cc1)~%")
                    (format #t "~%*cc1plus:~%")
                    (format #t "-isystem ~a/ -isystem ~a/ %{!ftls-model:-ftls-model=local-exec} %{!mstack-protector-guard:-mstack-protector-guard=global}   %(picolibc_cc1plus)~%" picolibc-include newlib-include)
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
                                  (string-append #$riscv32-esp-elf-newlib-esp-headers
                                                 "/" #$%target "/include"))

            ;; ESP-IDF's ULP build passes --specs=nano.specs and
            ;; --specs=nosys.specs to the RISC-V compiler.  Picolibc already
            ;; provides the nano-style stubs and the application supplies its
            ;; own system call stubs, so nano.specs can reuse picolibc.specs.
            ;; nosys.specs must be a separate no-op file so that loading it
            ;; after nano.specs does not trigger a spec rename conflict.
            (symlink (string-append out "/" #$%target "/lib/picolibc.specs")
                     (string-append out "/" #$%target "/lib/nano.specs"))
            ;; nosys.specs must be a valid GCC spec file but should not alter
            ;; the picolibc link command.  An empty file is accepted by GCC.
            (call-with-output-file (string-append out "/" #$%target "/lib/nosys.specs")
              (lambda (port)
                ;; Empty nosys.specs: GCC reads it and applies no overrides.
                #t))

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
                   #$gcc-cross-riscv32-esp-elf
                   #$riscv32-esp-elf-picolibc))

            ;; The RISC-V GCC driver invokes the bare program name `as`, so
            ;; provide a cross-`as` in the meta-package bin directory before the
            ;; host `as` is reached on PATH.
            (let ((as-link (string-append out "/bin/as"))
                  (target-as (string-append out "/bin/" #$%target "-as")))
              (unless (file-exists? as-link)
                (symlink target-as as-link)))

            ;; The source-built GCC's --version does not include the
            ;; crosstool-NG tag that ESP-IDF's idf_tools.py expects.  Wrap the
            ;; base GCC driver so it reports the expected version string while
            ;; still delegating all real work to the compiler.
            (let ((gcc-wrapper (string-append out "/bin/riscv32-esp-elf-gcc"))
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

            ;; Provide matching wrappers for the C++ drivers so that CMake's
            ;; compiler tests pick up the patched picolibc.specs as well.
            (let ((gcc-exec-prefix (string-append (dirname (dirname gcc-real))
                                                  "/libexec/gcc/")))
              (for-each
               (lambda (tool)
                 (let ((wrapper (string-append out "/bin/" #$%target "-" tool))
                       (real (string-append #$gcc-cross-riscv32-esp-elf "/bin/"
                                            #$%target "-" tool)))
                   (when (file-exists? wrapper)
                     (delete-file wrapper))
                   (with-output-to-file wrapper
                     (lambda ()
                       ;; Use the store bash so this wrapper can be executed
                       ;; directly in build containers where /bin/sh does not exist.
                       (format #t "#!~a~%" bash-sh)
                       (format #t "export GCC_EXEC_PREFIX=~a~%" gcc-exec-prefix)
                       ;; Pass library search directories via -B prefixes.
                       (format #t "if printf '%s\\n' \"$@\" | ~a -qx -- '--version'; then~%"
                               grep-cmd)
                       (format #t "  ~a ~a \"$@\" | ~a '1{/(crosstool-NG/!s/$/ (crosstool-NG esp-~a)/}'~%"
                               real cross-library-flags sed-cmd #$%esp-gcc-version)
                       (format #t "else~%")
                       (format #t "  exec ~a ~a \"$@\"~%" real cross-library-flags)
                       (format #t "fi~%")))
                   (chmod wrapper #o555)))
               '("g++" "c++")))
            #t))))
    (native-inputs
     `(;; Build-time tools used to generate the wrapper scripts.
       ("bash" ,bash)
       ("grep" ,grep)
       ("sed" ,sed)))
    (propagated-inputs
     `(("binutils-cross-riscv32-esp-elf" ,(cross-binutils %target #:binutils binutils-esp))
       ("gcc-cross-riscv32-esp-elf" ,gcc-cross-riscv32-esp-elf)
       ("riscv32-esp-elf-picolibc" ,riscv32-esp-elf-picolibc)
       ("riscv32-esp-elf-newlib-esp-headers" ,riscv32-esp-elf-newlib-esp-headers)))
    (home-page "https://github.com/espressif/crosstool-NG")
    (synopsis "Complete riscv32-esp-elf multilib cross toolchain")
    (description
     "This meta-package provides a complete bare-metal multilib
 cross-compilation toolchain for Espressif's 32-bit RISC-V MCUs, composed of
 Espressif's Binutils/GDB fork, Espressif's GCC fork, Espressif's
 picolibc fork, and newlib compatibility headers.")
    (license license:gpl3+)))
