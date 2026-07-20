(define-module (ebreak packages riscv32-qingke-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages build-tools)    ;meson, ninja
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1))

(define %target "riscv32-qingke-elf")

;;; Multilib variants supported by this toolchain.  Each entry has the form
;;; "arch-abi--" for GCC's RISC-V --with-multilib-generator.
(define %multilib-generator
  (string-join
   '("rv32ec-ilp32e--"
     "rv32emc-ilp32e--"
     "rv32imc-ilp32--"
     "rv32ic-ilp32--"
     "rv32imac-ilp32--"
     "rv32imafc-ilp32f--"
     "rv32imafc_zba_zbb_zbc_zbs-ilp32f--")
   ";"))

;;;
;;; 1. picolibc: a small C library for embedded systems.
;;;
;;; It is built with Meson multilib support enabled so that a single build
;;; produces libraries for all of the variants listed above.  Picolibc uses
;;; the compiler's --print-multi-lib output to discover which variants the
;;; GCC multilib generator will provide.
;;;
(define-public riscv32-qingke-picolibc
  (package
    (name "riscv32-qingke-picolibc")
    (version "1.8.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/picolibc/picolibc.git")
             (commit version)))
       (file-name (git-file-name "picolibc" version))
       (sha256
        (base32
         "16y5xgz07hrlmc8abc1vqdcf953xr4qn6jaz1z6gyf71iazgwvz5"))))
    (build-system meson-build-system)
    (arguments
     (list
      #:build-type "release"
      #:configure-flags
      #~(list "--cross-file=../source/cross-riscv32-qingke-elf.txt"
              (string-append "-Dspecsdir=" #$%target "/lib")
              "-Dtests=false"
              "-Derrno-function=auto"
              (string-append "--libdir=" #$output "/" #$%target "/lib")
              (string-append "--includedir=" #$output "/" #$%target "/include"))
      #:phases
      #~(modify-phases %standard-phases
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
                     (cross-file "cross-riscv32-qingke-elf.txt"))
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
                              c_args = ['-g', '-msave-restore', '-fshort-enums']
                              c_link_args = ['-g', '-msave-restore', '-fshort-enums']
                              skip_sanity_check = true
                              needs_exe_wrapper = true
"
                              cc ar as ld nm objcopy strip))))
                #t))))))
    (native-inputs
     `(("xgcc" ,gcc-cross-sans-libc-riscv32-qingke)
       ("xbinutils" ,(cross-binutils %target))
       ("meson" ,meson)
       ("ninja" ,ninja)
       ("pkg-config" ,pkg-config)))
    (home-page "https://keithp.com/picolibc/")
    (synopsis "PicoLIBC for 32-bit RISC-V embedded targets")
    (description
     "PicoLIBC is a C library designed for small embedded systems.  This
package builds it for the riscv32-qingke-elf multilib toolchain so it can be
used as the C library of a bare-metal RISC-V GCC toolchain.")
    (license (license:non-copyleft "file://COPYING"))))

;;;
;;;
;;; 2. Bootstrap cross GCC (no C library) used to build picolibc.
;;;
;;; Picolibc discovers the available multilib variants from the compiler's
;;; --print-multi-lib output, so the bootstrap compiler must be built with the
;;; same multilib generator configuration as the final GCC.
;;;
(define (gcc-cross-sans-libc-riscv32-qingke-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c"
                     "--enable-multilib"
                     (string-append "--with-multilib-generator=" #$%multilib-generator)
                     "--with-arch=rv32imac_zicsr"
                     "--with-abi=ilp32")
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)
                             (string-prefix? "--disable-multilib" flag)
                             (string-prefix? "--enable-multilib" flag)
                             (string-prefix? "--with-multilib-generator=" flag)
                             (string-prefix? "--with-arch=" flag)
                             (string-prefix? "--with-abi=" flag)))
                       #$flags)))
    ((#:make-flags flags)
     #~(list))))

(define-public gcc-cross-sans-libc-riscv32-qingke
  (let ((base (cross-gcc %target
                         #:xgcc gcc-16
                         #:xbinutils (cross-binutils %target)
                         #:libc #f)))
    (package
      (inherit base)
      (name "gcc-cross-sans-libc-riscv32-qingke")
      (arguments (gcc-cross-sans-libc-riscv32-qingke-arguments base %target))
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static")
         (prepend python-minimal)
         (prepend which))))))

;;;
;;;
;;; 3. Cross GCC using picolibc as the target C library.
;;;
;;; Build a helper outside of the let* binding because
;;; substitute-keyword-arguments is a macro and Guile can have trouble
;;; expanding it inside some binding forms.
;;;
(define (gcc-cross-riscv32-qingke-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c"
                     "--enable-multilib"
                     (string-append "--with-multilib-generator=" #$%multilib-generator)
                     "--with-arch=rv32imac_zicsr"
                     "--with-abi=ilp32"
                     (string-append "--with-native-system-header-dir="
                                    (assoc-ref %build-inputs "libc")
                                    "/" #$target "/include"))
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)
                             (string-prefix? "--disable-multilib" flag)
                             (string-prefix? "--enable-multilib" flag)
                             (string-prefix? "--with-multilib-generator=" flag)))
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
                    ;; Use the freshly installed cross-GCC and the cross-binutils
                    ;; inputs to build the stub.
                    (gcc (string-append (assoc-ref outputs "out")
                                        "/bin/" target "-gcc"))
                    (ar (string-append (assoc-ref inputs "binutils-cross")
                                       "/bin/" target "-ar"))
                    (include-dir (string-append lib-output "/" target "/include"))
                    (lib-dir (string-append lib-output "/" target "/lib"))
                    (empty (string-append (getcwd) "/empty.o")))
               ;; Copy picolibc headers and libraries into GCC's lib output so
               ;; that the compiler finds them by default.  Keep them under the
               ;; target directory so different toolchains can coexist in the
               ;; same profile without colliding.
               (copy-recursively (string-append libc "/" target "/include")
                                 include-dir)
               (copy-recursively (string-append libc "/" target "/lib")
                                 lib-dir)
               ;; GCC's default link specs for bare-metal targets add -lgloss,
               ;; which picolibc does not provide.  Create an empty stub in every
               ;; multilib directory so that the linker succeeds even without
               ;; --specs=picolibc.specs.
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
               #t)))))))

(define-public gcc-cross-riscv32-qingke
  (let ((base (cross-gcc %target
                         #:xgcc gcc-16
                         #:xbinutils (cross-binutils %target)
                         #:libc riscv32-qingke-picolibc)))
    (package
      (inherit base)
      (arguments (gcc-cross-riscv32-qingke-arguments base %target))
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static")
         (prepend python-minimal)
         (prepend which))))))

(define-public riscv32-qingke-elf-toolchain
  (package
    (name "riscv32-qingke-elf-toolchain")
    (version (package-version gcc-cross-riscv32-qingke))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out #$output))
            (mkdir-p (string-append out "/bin"))
            ;; Create symlinks to all toolchain binaries in one place.
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
             (list #$(cross-binutils %target)
                   #$gcc-cross-riscv32-qingke
                   #$riscv32-qingke-picolibc))
            #t))))
    (propagated-inputs
     `(("binutils-cross-riscv32-qingke-elf" ,(cross-binutils %target))
       ("gcc-cross-riscv32-qingke-elf" ,gcc-cross-riscv32-qingke)
       ("riscv32-qingke-picolibc" ,riscv32-qingke-picolibc)))
    (home-page "https://www.gnu.org/software/guix/")
    (synopsis "Complete riscv32-qingke-elf multilib cross toolchain")
    (description
     "This meta-package provides a complete bare-metal multilib
cross-compilation toolchain for 32-bit RISC-V, composed of Binutils, GCC and
picolibc.  Users select the target variant with -march and -mabi flags.")
    (license license:gpl3+)))
