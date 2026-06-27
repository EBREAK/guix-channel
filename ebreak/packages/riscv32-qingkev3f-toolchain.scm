(define-module (ebreak packages riscv32-qingkev3f-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages build-tools)    ;meson, ninja
  #:use-module (gnu packages pkg-config)
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

(define %target "riscv32-qingkev3f-elf")

;;;
;;; 1. picolibc: a small C library for embedded systems.
;;;
;;; It is built with a Meson cross-file so that it targets riscv32-picolibc-elf.
;;; The cross compilers come from Guix's own cross-binutils/cross-gcc helpers.
;;;
(define-public riscv32-qingkev3f-picolibc
  (package
    (name "riscv32-qingkev3f-picolibc")
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
      #~(list "--cross-file=../source/cross-riscv32-qingkev3f-elf.txt"
              "-Dmultilib=false"
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
                     (cross-file "cross-riscv32-qingkev3f-elf.txt"))
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
                              cpu = 'rv32imacf_zba_zbb_zbc_zbs_zicsr'
                              endian = 'little'

                              [properties]
                              c_args = ['-g', '-march=rv32imacf_zba_zbb_zbc_zbs_zicsr', '-mabi=ilp32f', '-msave-restore', '-fshort-enums']
                              c_link_args = ['-g', '-march=rv32imacf_zba_zbb_zbc_zbs_zicsr', '-mabi=ilp32f', '-msave-restore', '-fshort-enums']
                              skip_sanity_check = true
                              needs_exe_wrapper = true
"
                              cc ar as ld nm objcopy strip))))
                #t))))))
    (native-inputs
     `(("xgcc" ,(cross-gcc %target
                            #:xgcc gcc-14
                            #:xbinutils (cross-binutils %target)
                            #:libc #f))
       ("xbinutils" ,(cross-binutils %target))
       ("meson" ,meson)
       ("ninja" ,ninja)
       ("pkg-config" ,pkg-config)))
    (home-page "https://keithp.com/picolibc/")
    (synopsis "PicoLIBC for 32-bit RISC-V embedded targets")
    (description
     "PicoLIBC is a C library designed for small embedded systems.  This
package builds it for the riscv32-qingkev3f-elf target so it can be used as the
C library of a bare-metal RISC-V GCC toolchain.")
    (license (license:non-copyleft "file://COPYING"))))

;;;
;;;
;;; 2. Cross GCC using picolibc as the target C library.
;;;
;;; Build a helper outside of the let* binding because
;;; substitute-keyword-arguments is a macro and Guile can have trouble
;;; expanding it inside some binding forms.
;;;
(define (gcc-cross-riscv32-qingkev3f-arguments base target)
  (substitute-keyword-arguments (package-arguments base)
    ((#:configure-flags flags)
     #~(append (list "--enable-languages=c"
                     "--with-arch=rv32imacf"
                     "--with-abi=ilp32f"
                     (string-append "--with-native-system-header-dir="
                                    (assoc-ref %build-inputs "libc")
                                    "/" #$target "/include"))
               (remove (lambda (flag)
                         (or (string-prefix? "--enable-languages=" flag)
                             (string-prefix? "--with-native-system-header-dir=" flag)))
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
                    (lib-dir (string-append lib-output "/" target "/lib"))
                    (empty (string-append (getcwd) "/empty.o")))
               ;; Copy picolibc headers and libraries into GCC's lib output so
               ;; that the compiler finds them by default.  Keep them under the
               ;; target directory so different toolchains can coexist in the
               ;; same profile without colliding.
               (copy-recursively (string-append libc "/" target "/include")
                                 (string-append lib-output "/" target "/include"))
               (copy-recursively (string-append libc "/" target "/lib")
                                 lib-dir)
               ;; GCC's default link specs for bare-metal targets add -lgloss,
               ;; which picolibc does not provide.  Create an empty stub so that
               ;; the linker succeeds even without --specs=picolibc.specs.
               (with-output-to-file "empty.c"
                 (lambda () (display "/* empty */\n")))
               (invoke gcc "-c" "empty.c" "-o" empty)
               (invoke ar "rcs" (string-append lib-dir "/libgloss.a") empty)
               #t)))))))

(define-public gcc-cross-riscv32-qingkev3f
  (let ((base (cross-gcc %target
                         #:xgcc gcc-14
                         #:xbinutils (cross-binutils %target)
                         #:libc riscv32-qingkev3f-picolibc)))
    (package
      (inherit base)
      (arguments (gcc-cross-riscv32-qingkev3f-arguments base %target))
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (delete "xkernel-headers")
         (delete "libc:static"))))))

(define-public riscv32-qingkev3f-elf-toolchain
  (package
    (name "riscv32-qingkev3f-elf-toolchain")
    (version (package-version gcc-cross-riscv32-qingkev3f))
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
                   #$gcc-cross-riscv32-qingkev3f
                   #$riscv32-qingkev3f-picolibc))
            #t))))
    (propagated-inputs
     `(("binutils" ,(cross-binutils %target))
       ("gcc" ,gcc-cross-riscv32-qingkev3f)
       ("libc" ,riscv32-qingkev3f-picolibc)))
    (home-page "https://www.gnu.org/software/guix/")
    (synopsis "Complete riscv32-qingkev3f-elf cross toolchain")
    (description
     "This meta-package provides a complete bare-metal cross-compilation
toolchain for 32-bit RISC-V, composed of Binutils, GCC and picolibc.")
    (license license:gpl3+)))
