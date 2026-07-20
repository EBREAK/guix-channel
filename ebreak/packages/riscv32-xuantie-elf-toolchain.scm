(define-module (ebreak packages riscv32-xuantie-elf-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages build-tools)
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

(define %target "riscv32-xuantie-elf")

;;; The 13 XuanTie (T-Head) ISA extensions supported by upstream GCC-16.
;;; See: https://gcc.gnu.org/onlinedocs/gcc-16.1.0/gcc/RISC-V-Options.html
(define %xthead-extensions
  '("xtheadba"
    "xtheadbb"
    "xtheadbs"
    "xtheadcmo"
    "xtheadcondmov"
    "xtheadfmemidx"
    "xtheadfmv"
    "xtheadint"
    "xtheadmac"
    "xtheadmemidx"
    "xtheadmempair"
    "xtheadsync"
    "xtheadvector"))

(define (xthead-suffix extensions)
  (string-join (map (lambda (e) (string-append "_" e)) extensions) ""))

(define %xthead-all-suffix (xthead-suffix %xthead-extensions))

(define %xthead-novec-suffix
  (xthead-suffix (delete "xtheadvector" %xthead-extensions)))

(define %default-abi "ilp32d")

(define %default-arch
  (string-append "rv32imafdc_zicsr_zifencei" %xthead-all-suffix))

;;; Multilib variants: each entry is (arch-string . abi-string).
(define %multilib-variants
  `(,(cons "rv32imac_zicsr_zifencei" "ilp32")
    ,(cons "rv32imafdc_zicsr_zifencei" "ilp32d")
    ,(cons "rv32imafdc_zicsr_zifencei_zfh" "ilp32d")
    ,(cons (string-append "rv32imafdc_zicsr_zifencei" %xthead-novec-suffix)
           "ilp32d")
    ,(cons (string-append "rv32imafdc_zicsr_zifencei_zfh" %xthead-all-suffix)
           "ilp32d")
    ,(cons (string-append "rv32imac_zicsr_zifencei" %xthead-novec-suffix)
           "ilp32")))

(define (multilib-generator-string variants)
  (string-join
   (map (lambda (v)
          (string-append (car v) "-" (cdr v) "--"))
        variants)
   ";"))

;;; Intermediate multilib-capable sans-libc GCC used to build picolibc's
;;; multilib variants.  Guix's default sans-libc cross GCC is built without
;;; multilib, so picolibc cannot discover multiple target variants from it.
(define-public riscv32-xuantie-elf-gcc-sans-libc-multilib
  (let ((base (cross-gcc %target #:xgcc gcc-16 #:libc #f)))
    (package
      (inherit base)
      (name "riscv32-xuantie-elf-gcc-sans-libc-multilib")
      (native-inputs
       `(,@(package-native-inputs base)
         ("python" ,python-wrapper)
         ("which" ,which)))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:configure-flags flags)
          #~(append (list "--enable-multilib"
                          #$(string-append "--with-arch=" %default-arch)
                          #$(string-append "--with-abi=" %default-abi)
                          #$(string-append "--with-multilib-generator="
                                           (multilib-generator-string %multilib-variants)))
                    (remove (lambda (flag)
                              (or (string=? flag "--disable-multilib")
                                  (string-prefix? "--with-arch" flag)
                                  (string-prefix? "--with-abi" flag)
                                  (string-prefix? "--with-multilib-generator" flag)))
                            #$flags))))))))

(define-public riscv32-xuantie-elf-picolibc
  (package
    (name "riscv32-xuantie-elf-picolibc")
    (version "1.8.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/picolibc/picolibc.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "16y5xgz07hrlmc8abc1vqdcf953xr4qn6jaz1z6gyf71iazgwvz5"))))
    (build-system meson-build-system)
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(list (string-append "--cross-file=" (getcwd) "/source/cross-riscv32-xuantie-elf.txt")
              "-Dmultilib=true"
              (string-append "-Dspecsdir=" #$%target "/lib")
              "-Dtests=false"
              "-Derrno-function=auto"
              (string-append "--libdir=" #$output "/" #$%target "/lib")
              (string-append "--includedir=" #$output "/" #$%target "/include"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'copy-source-and-write-cross-file
            (lambda* (#:key source #:allow-other-keys)
              (let ((cwd (getcwd)))
                ;; Copy source to a writable directory so patch-shebangs can modify it.
                (copy-recursively source "source")
                (chdir "source")
                (call-with-output-file (string-append cwd "/cross-riscv32-xuantie-elf.txt")
                  (lambda (port)
                    (display
                     #$(string-append
                        "[binaries]\n"
                        "c = '" %target "-gcc'\n"
                        "ar = '" %target "-ar'\n"
                        "as = '" %target "-as'\n"
                        "nm = '" %target "-nm'\n"
                        "strip = '" %target "-strip'\n\n"
                        "[host_machine]\n"
                        "system = 'none'\n"
                        "cpu_family = 'riscv32'\n"
                        "cpu = 'riscv32'\n"
                        "endian = 'little'\n\n"
                        "[properties]\n"
                        "skip_sanity_check = true\n"
                        "c_args = ['-Os', '-march=" %default-arch "', '-mabi=" %default-abi "']\n")
                     port)))
                #t)))
          (delete 'chdir-back-to-source))))

    (native-inputs
     `(("xbinutils" ,(cross-binutils %target))
       ("xgcc" ,riscv32-xuantie-elf-gcc-sans-libc-multilib)
       ("pkg-config" ,pkg-config)
       ("meson" ,meson)
       ("ninja" ,ninja)))
    (home-page "https://keithp.com/picolibc/")
    (synopsis "Picolibc C library for riscv32-xuantie-elf")
    (description
     "Picolibc is a C library designed for embedded systems.  This build
is a multilib picolibc for the riscv32-xuantie-elf target, covering the
upstream XuanTie (T-Head) ISA extensions.")
    (license license:bsd-2)))

(define-public gcc-cross-riscv32-xuantie-elf
  (let ((base (cross-gcc %target #:xgcc gcc-16)))
    (package
      (inherit base)
      (name "gcc-cross-riscv32-xuantie-elf")
      (inputs
       `(,@(package-inputs base)
         ("picolibc" ,riscv32-xuantie-elf-picolibc)))
      (native-inputs
       `(,@(package-native-inputs base)
         ("python" ,python-wrapper)
         ("which" ,which)))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:configure-flags flags)
          #~(append (list "--enable-languages=c"
                          "--with-newlib"
                          #$(string-append "--with-arch=" %default-arch)
                          #$(string-append "--with-abi=" %default-abi)
                          #$(string-append "--with-multilib-generator="
                                           (multilib-generator-string %multilib-variants))
                          (string-append "--with-native-system-header-dir="
                                         (assoc-ref %build-inputs "picolibc")
                                         "/" #$%target "/include")
                          "--disable-shared"
                          "--disable-threads"
                          "--disable-libstdc++"
                          "--disable-libatomic"
                          "--disable-libmudflap"
                          "--disable-libmpx"
                          "--disable-libssp"
                          "--disable-libquadmath"
                          "--disable-libquadmath-support"
                          "--disable-__cxa-atexit"
                          "--disable-libitm"
                          "--disable-libvtv"
                          "--disable-libsanitizer"
                          "--disable-decimal-float"
                          "--disable-nls")
                    (remove (lambda (flag)
                              (or (string-prefix? "--enable-languages" flag)
                                  (string-prefix? "--with-arch" flag)
                                  (string-prefix? "--with-abi" flag)
                                  (string-prefix? "--with-multilib-generator" flag)
                                  (string-prefix? "--with-native-system-header-dir" flag)
                                  (string=? flag "--enable-shared")
                                  (string=? flag "--disable-multilib")))
                            #$flags)))
         ((#:make-flags make-flags #~'())
          #~(cons* "CFLAGS_FOR_TARGET=-Os -g"
                   #$make-flags))
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-before 'configure 'patch-print-sysroot-suffix
                (lambda _
                  (substitute* "gcc/config/print-sysroot-suffix.sh"
                    (("#! /bin/sh")
                     (string-append "#!" (which "sh"))))
                  #t))
              (add-after 'install 'copy-picolibc-into-gcc
                (lambda* (#:key inputs outputs #:allow-other-keys)
                  (let* ((picolibc (assoc-ref inputs "picolibc"))
                         (lib-output (assoc-ref outputs "lib"))
                         (target #$%target)
                         (lib-dir (string-append lib-output "/" target "/lib"))
                         (include-dir (string-append lib-output "/" target "/include")))
                    (mkdir-p lib-dir)
                    (mkdir-p include-dir)
                    (copy-recursively (string-append picolibc "/" target "/include")
                                      include-dir)
                    (copy-recursively (string-append picolibc "/" target "/lib")
                                      lib-dir)
                    ;; Provide an empty libgloss.a in every multilib subdirectory so
                    ;; the bare-metal linker has a fallback when -lgloss is requested.
                    (for-each
                     (lambda (libc-a)
                       (let ((gloss-a (string-append (dirname libc-a) "/libgloss.a")))
                         (unless (file-exists? gloss-a)
                           (invoke (which "ar") "rcs" gloss-a))))
                     (find-files lib-dir "libc\\.a"))
                    #t))))))))))

(define-public riscv32-xuantie-elf-toolchain
  (package
    (name "riscv32-xuantie-elf-toolchain")
    (version (package-version gcc-cross-riscv32-xuantie-elf))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (bin (string-append out "/bin")))
            (mkdir-p bin)
            (for-each (lambda (input)
                        (let ((input-bin (string-append input "/bin")))
                          (when (directory-exists? input-bin)
                            (for-each (lambda (file)
                                        (let ((target (string-append bin "/" (basename file))))
                                          (unless (file-exists? target)
                                            (symlink file target))))
                                      (find-files input-bin ".*")))))
                      (map (lambda (name)
                             (assoc-ref %build-inputs name))
                           '("binutils" "gcc" "picolibc")))
            #t))))
    (propagated-inputs
     `(("binutils" ,(cross-binutils %target))
       ("gcc" ,gcc-cross-riscv32-xuantie-elf)
       ("picolibc" ,riscv32-xuantie-elf-picolibc)))
    (home-page "https://github.com/ebreak/guix-channel")
    (synopsis "Complete GNU toolchain for riscv32-xuantie-elf")
    (description
     "This meta-package bundles Binutils, GCC 16 and Picolibc for the
riscv32-xuantie-elf target.  It is configured as a multilib toolchain covering
the upstream XuanTie (T-Head) ISA extensions, with libc/libgcc compiled at -Os.")
    (license license:gpl3+)))
