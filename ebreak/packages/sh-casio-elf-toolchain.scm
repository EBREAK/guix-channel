(define-module (ebreak packages sh-casio-elf-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils))

(define %target "sh-casio-elf")

;;;
;;; GCC cross-compiler for sh-casio-elf, without a C library.
;;;
;;; This matches the crosstool-NG build used for Casio SuperH calculators:
;;; big-endian SH, multilib m4a-nofpu, C language only.
;;;
(define-public gcc-cross-sh-casio-elf
  (let ((base (cross-gcc %target #:xgcc gcc-16)))
    (package
      (inherit base)
      (name "gcc-cross-sh-casio-elf")
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:configure-flags flags)
          #~(append (list "--enable-languages=c"
                          "--with-endian=big"
                          "--enable-multilib"
                          "--with-multilib-list=m4a-nofpu"
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
                          "--disable-nls"
                          "--enable-lto"
                          "--enable-target-optspace"
                          "--enable-plugin")
                    (remove (lambda (flag)
                              (or (string-prefix? "--enable-languages" flag)
                                  (string=? flag "--disable-multilib")
                                  (string=? flag "--enable-shared")))
                            #$flags)))
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-before 'configure 'patch-print-sysroot-suffix
                (lambda _
                  ;; The script generates temporary helper scripts with a
                  ;; #!/bin/sh shebang.  In the Guix build chroot that path is
                  ;; not available for dynamically-created files, so force the
                  ;; real shell path instead.
                  (substitute* "gcc/config/print-sysroot-suffix.sh"
                    (("#! /bin/sh")
                     (string-append "#!" (which "sh"))))
                  #t)))))))))

;;;
;;; Meta-package: pulls binutils and GCC into one profile.
;;;
(define-public sh-casio-elf-toolchain
  (package
    (name "sh-casio-elf-toolchain")
    (version (package-version gcc-cross-sh-casio-elf))
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
                           '("binutils" "gcc")))
            #t))))
    (propagated-inputs
     `(("binutils" ,(cross-binutils %target))
       ("gcc" ,gcc-cross-sh-casio-elf)))
    (home-page "https://github.com/ebreak/casio-calculator-dev")
    (synopsis "Complete GNU toolchain for sh-casio-elf (no C library)")
    (description
     "This meta-package bundles Binutils and GCC 16 for the sh-casio-elf
target used by Casio SuperH-based calculators.  It is configured to match
the crosstool-NG build: big-endian SH, multilib m4a-nofpu, no shared
libraries, C language only.  No C library is included; link with
-nostdlib or provide your own.")
    (license license:gpl3+)))
