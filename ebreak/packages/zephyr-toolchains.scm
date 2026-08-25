(define-module (ebreak packages zephyr-toolchains)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages compiler-tools)
  #:use-module (gnu packages embedded)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages python)
  #:use-module (gnu packages texinfo)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (guix utils)
  #:use-module (ice-9 format)
  #:use-module (gnu packages bash))

;;; Source-built bare-metal toolchains for Zephyr.
;;;
;;; Targets:
;;;   arm-zephyr-eabi    - RP2040, RP2350 ARM Cortex-M and other ARM boards
;;;   aarch64-zephyr-elf - Raspberry Pi 4B and other 64-bit ARM boards
;;;   riscv64-zephyr-elf - RP2350 RISC-V (Hazard3), CH32V307 and other RISC-V
;;;                        boards; uses RISC-V multilib to cover both rv32 and
;;;                        rv64 targets from a single riscv64 toolchain.
;;;
;;; The ARM toolchain is modelled on Guix's own make-gcc-arm-none-eabi-12.3.rel1
;;; generator, adapted to the arm-zephyr-eabi target and the multilib set
;;; aprofile,rmprofile used by the upstream Zephyr SDK.

(define %gcc-version
  "16.1.0")
(define %newlib-version
  "4.6.0")
(define %newlib-commit
  "8ba4275b83ec27529f67e0d477611fa6d8d6e6bd")

(define %gcc-source
  (package-source gcc-16))

(define %newlib-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "git://sourceware.org/git/newlib-cygwin.git")
          (commit %newlib-commit)))
    (file-name (git-file-name "newlib" %newlib-version))
    (sha256 (base32 "1ahz9pk30vzrm15ric44qb82bc8adbd8x9l9pbis3kr0j8aqk9cs"))))

;;; RISC-V multilib variants for the riscv64-zephyr-elf toolchain.  This set
;;; covers the 32-bit targets used by Zephyr (RP2350 Hazard3 and CH32V307 use
;;; rv32imac/ilp32) as well as common 64-bit RISC-V targets.  Both plain and
;;; _zicsr_zifencei march strings are included because Zephyr board configs
;;; may use either form.
(define %riscv-zephyr-multilib-generator
  (string-join '("rv32imac-ilp32--" "rv32imac_zicsr_zifencei-ilp32--"
                 "rv32imafc-ilp32f--"
                 "rv32imafc_zicsr_zifencei-ilp32f--"
                 "rv32imafdc-ilp32d--"
                 "rv64imac-lp64--"
                 "rv64imac_zicsr_zifencei-lp64--"
                 "rv64imafc-lp64f--"
                 "rv64imafdc-lp64d--") ";"))

(define (zephyr-cross-binutils target)
  "Return a cross-Binutils for TARGET with extra native inputs required by
recent Binutils tarballs (flex, and perl for generated man pages)."
  (let ((base (cross-binutils target)))
    (package
      (inherit base)
      (native-inputs (modify-inputs (package-native-inputs base)
                       (prepend flex)
                       (prepend perl))))))

;; Statically link the host libstdc++ into the cross compilers so they do
;; not depend on the C++ runtime at run time (matches the Zephyr SDK build).
(define %gcc-host-libstdcxx-flag
  "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm")

(define* (zephyr-gcc target
                     #:key (multilib-list #f)
                     (multilib-generator #f)
                     (with-arch #f)
                     (with-abi #f))
  "Bootstrap cross GCC (no C library) for TARGET.  This compiler is configured
with --with-newlib so that it knows it will use newlib, but the C library
itself is built separately and supplied through the final toolchain union."
  (let ((base (cross-gcc target
                         #:xgcc gcc-16
                         #:xbinutils (zephyr-cross-binutils target)
                         #:libc #f)))
    (package
      (inherit base)
      (version %gcc-version)
      (source
       %gcc-source)
      (native-inputs (modify-inputs (package-native-inputs base)
                       (delete "xkernel-headers")
                       (delete "libc:static")
                       (prepend flex)
                       (prepend which)
                       (prepend python-minimal)))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-after 'unpack 'expand-version-string
                (lambda _
                  (make-file-writable "gcc/DEV-PHASE")
                  (with-output-to-file "gcc/DEV-PHASE"
                    (lambda ()
                      (display "16.1.0"))) #t))
              (add-after 'unpack 'fix-genmultilib
                (lambda _
                  (substitute* "gcc/genmultilib"
                    (("#!/bin/sh")
                     (string-append "#!"
                                    (which "sh")))) #t))
              (add-after 'unpack 'fix-riscv-multilib-generator
                (lambda _
                  (let ((mlg "gcc/config/riscv/multilib-generator"))
                    (when (file-exists? mlg)
                      (make-file-writable mlg)
                      (substitute* mlg
                        (("#!/usr/bin/env python3")
                         (string-append "#!"
                                        (which "python3"))))) #t)))
              (add-after 'unpack 'fix-aarch64-cpuinfo-guard
                (lambda _
                  (let ((f "libgcc/config/aarch64/cpuinfo.c"))
                    (when (file-exists? f)
                      (make-file-writable f)
                      (substitute* f
                        (("#if __has_include\\(<sys/auxv\\.h>\\)")
                         "#if defined(__linux__) && __has_include(<sys/auxv.h>)")))
                    #t)))))
         ((#:configure-flags flags)
          #~(append (list "--enable-multilib"
                     "--with-newlib"
                     "--with-gnu-as"
                     "--with-gnu-ld"
                     "--with-headers=yes"
                     "--disable-decimal-float"
                     "--disable-libffi"
                     "--disable-libgomp"
                     "--disable-libmudflap"
                     "--disable-libquadmath"
                     "--disable-libssp"
                     "--disable-libstdcxx-pch"
                     "--disable-nls"
                     "--disable-shared"
                     "--disable-threads"
                     "--disable-tls"
                     "--enable-checking=release"
                            #$%gcc-host-libstdcxx-flag
                     #$@(if multilib-list
                            (list (string-append "--with-multilib-list="
                                                 multilib-list))
                            '())
                     #$@(if multilib-generator
                            (list (string-append "--with-multilib-generator="
                                                 multilib-generator))
                            '())
                     #$@(if with-arch
                            (list (string-append "--with-arch=" with-arch))
                            '())
                     #$@(if with-abi
                            (list (string-append "--with-abi=" with-abi))
                            '()))
                    (filter (lambda (flag)
                              (not (or (member flag
                                               '("--disable-multilib"
                                                 "--enable-plugins"
                                                 "--disable-libffi"))
                                       (string-prefix? "--with-arch=" flag)
                                       (string-prefix? "--with-abi=" flag)
                                       (string-prefix?
                                        "--with-multilib-generator=" flag))))
                            #$flags)))))
      (native-search-paths
       (list (search-path-specification
              (variable "CROSS_C_INCLUDE_PATH")
              (files (list (string-append target "/include"))))
             (search-path-specification
              (variable "CROSS_CPLUS_INCLUDE_PATH")
              (files (list (string-append target "/include/c++")
                           (string-append target "/include/c++/" target)
                           (string-append target "/include"))))
             (search-path-specification
              (variable "CROSS_LIBRARY_PATH")
              (files (list (string-append target "/lib")))))))))

(define (zephyr-newlib target xgcc)
  "Newlib C library built for TARGET using XGCC."
  (package
    (name (string-append "newlib-" target))
    (version %newlib-version)
    (source
     %newlib-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:out-of-source? #t
      #:configure-flags
      #~(list (string-append "--target="
                             #$target)
              "--enable-newlib-io-long-long"
              "--enable-newlib-register-fini"
              "--disable-newlib-supplied-syscalls"
              "--enable-newlib-mb"
              "--enable-newlib-reent-check-verify"
              "--with-headers=yes"
              "--disable-nls")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-references-to-/bin/sh
            (lambda _
              (substitute* (find-files "libgloss" "^Makefile\\.in$")
                (("/bin/sh")
                 (which "sh"))) #t))
          (add-before 'configure 'unset-host-search-paths
            (lambda _
              (for-each unsetenv
                        '("C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
                          "OBJC_INCLUDE_PATH" "OBJCPLUS_INCLUDE_PATH"
                          "LIBRARY_PATH")) #t)))))
    (native-inputs `(("xbinutils" ,(zephyr-cross-binutils target))
                     ("xgcc" ,xgcc)
                     ("texinfo" ,texinfo)))
    (home-page "https://www.sourceware.org/newlib/")
    (synopsis (string-append "Newlib C library for " target))
    (description "Newlib is a C library intended for use on embedded systems.")
    (license (license:non-copyleft
              "https://www.sourceware.org/newlib/COPYING.NEWLIB"))))

(define (zephyr-libstdc++ target xgcc newlib)
  "Target libstdc++ built against NEWLIB."
  (let ((base (make-libstdc++ xgcc)))
    (package
      (inherit base)
      (name (string-append "libstdc++-" target))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:make-flags flags #f)
          #~(cons* "CFLAGS=-g -O2 -fdata-sections -ffunction-sections"
                   "CXXFLAGS=-g -O2 -fdata-sections -ffunction-sections"
                   (or #$flags
                       '())))
         ((#:configure-flags _)
          #~(list "--with-target-subdir=\".\""
                  (string-append "--target="
                                 #$target)
                  (string-append "--host="
                                 #$target)
                  "--disable-libstdcxx-pch"
                  "--enable-multilib"
                  "--disable-shared"
                  "--disable-tls"
                  "--disable-plugin"
                  "--with-newlib"
                  ;; Suppress getentropy / arc4random checks that fail
                  ;; with newlib cross builds (replaces patch approach).
                  "glibcxx_cv_getentropy=no"
                  "glibcxx_cv_arc4random=no"
                  (string-append "--libdir="
                                 (assoc-ref %outputs "out") "/"
                                 #$target "/lib")
                  (string-append "--with-gxx-include-dir="
                                 (assoc-ref %outputs "out") "/"
                                 #$target "/include/c++")))
         ((#:strip-directories _ #f)
          #~(list (string-append #$target "/lib")))
         ((#:phases phases
           '%standard-phases)
          #~(modify-phases #$phases
              (add-before 'configure 'set-cross-tools
                (lambda _
                  (let* ((xgcc (assoc-ref %build-inputs "xgcc"))
                         (xbinutils (assoc-ref %build-inputs "xbinutils"))
                         (newlib (assoc-ref %build-inputs "newlib"))
                         (gcc-bin (string-append xgcc "/bin/"))
                         (binutils-bin (string-append xbinutils "/bin/"))
                         (newlib-inc (string-append newlib "/"
                                                    #$target "/include"))
                         (newlib-lib (string-append newlib "/"
                                                    #$target "/lib")))
                    (setenv "CC"
                            (string-append gcc-bin
                                           #$target "-gcc"))
                    (setenv "CXX"
                            (string-append gcc-bin
                                           #$target "-g++"))
                    (setenv "CPP"
                            (string-append gcc-bin
                                           #$target "-cpp"))
                    ;; Use the Binutils tools directly, and with absolute paths.
                    ;; The gcc-ar/gcc-nm/gcc-ranlib wrappers shipped with GCC look
                    ;; for the corresponding target tool in the same directory,
                    ;; but our cross-binutils live in a separate store item; the
                    ;; wrappers would fail with "Cannot find binary '<target>-ar'".
                    (setenv "AR"
                            (string-append binutils-bin
                                           #$target "-ar"))
                    (setenv "NM"
                            (string-append binutils-bin
                                           #$target "-nm"))
                    (setenv "RANLIB"
                            (string-append binutils-bin
                                           #$target "-ranlib"))
                    ;; Remove host (glibc) search paths that Guix sets for the
                    ;; build tools; the cross compiler also honours them and
                    ;; would pick glibc headers before newlib.
                    (for-each unsetenv
                              '("C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
                                "OBJC_INCLUDE_PATH" "OBJCPLUS_INCLUDE_PATH"))
                    ;; Point the cross compiler at the newlib headers and libs
                    ;; built in the previous step.  Use CPATH (not
                    ;; C_INCLUDE_PATH/CPLUS_INCLUDE_PATH) because the C++17
                    ;; libstdc++ sources are compiled with -nostdinc++, which
                    ;; ignores CPLUS_INCLUDE_PATH but still honours CPATH.
                    (setenv "CPATH" newlib-inc)
                    (setenv "CROSS_C_INCLUDE_PATH" newlib-inc)
                    (setenv "CROSS_CPLUS_INCLUDE_PATH" newlib-inc)
                    (setenv "LIBRARY_PATH" newlib-lib)
                    (setenv "CROSS_LIBRARY_PATH" newlib-lib)
                    #t)))))))
      (native-inputs `(("newlib" ,newlib)
                       ("xgcc" ,xgcc)
                       ("xbinutils" ,(zephyr-cross-binutils target))
                       ,@(package-native-inputs base))))))

(define* (make-zephyr-toolchain target
                                #:key (multilib-list #f)
                                (multilib-generator #f)
                                (with-arch #f)
                                (with-abi #f))
  "Complete source-based Zephyr toolchain for TARGET."
  (let* ((xgcc (zephyr-gcc target
                           #:multilib-list multilib-list
                           #:multilib-generator multilib-generator
                           #:with-arch with-arch
                           #:with-abi with-abi))
         (newlib (zephyr-newlib target xgcc))
         (libstdcxx (zephyr-libstdc++ target xgcc newlib)))
    (package
      (name (string-append target "-toolchain"))
      (version %gcc-version)
      (source
       #f)
      (build-system trivial-build-system)
      (arguments
       (list
        #:modules '((guix build union)
                    (guix build utils))
        #:builder
        #~(begin
            (use-modules (guix build union)
                         (guix build utils))
            (let* ((out (assoc-ref %outputs "out"))
                   (gcc-dir (assoc-ref %build-inputs "gcc"))
                   (bin-dir (string-append out "/bin")))
              (union-build out
                           (map cdr %build-inputs))
              ;; Zephyr's RP2040/RP2350 second stage bootloader passes
              ;; --specs=picolibc.specs when CONFIG_PICOLIBC is selected.
              ;; Provide a minimal specs file so that assembly-only
              ;; bootloader builds can proceed; the main Zephyr picolibc
              ;; module supplies the actual C library.
              (let ((specs-dir (string-append out "/"
                                              #$target "/lib"))
                    (specs-content "*cpp:
%(picolibc_cpp)

*cc1:
%(picolibc_cc1)

*cc1plus:
%(picolibc_cc1plus)

*link:
%(picolibc_link)

*lib:
--start-group %(libgcc) --end-group

*endfile:

*startfile:
"))
                (mkdir-p specs-dir)
                (call-with-output-file (string-append specs-dir
                                                      "/picolibc.specs")
                  (lambda (port)
                    (display specs-content port)))
                ;; GCC only searches for --specs=NAME files in its own
                ;; installation lib/gcc/<target>/<version>/ directory, not in
                ;; the target sysroot.  The source-built GCC package cannot be
                ;; modified after it is built, so install small wrappers for
                ;; gcc/g++ that rewrite relative specs references (e.g.
                ;; --specs=picolibc.specs, --specs=nosys.specs) to the
                ;; absolute path in this toolchain union.
                ;;
                ;; The wrappers also make the toolchain self-contained:
                ;; gcc-16 does not honour CROSS_C_INCLUDE_PATH /
                ;; CROSS_LIBRARY_PATH (no cross-environment-variables patch
                ;; is applied to it upstream), and the C library lives in a
                ;; separate store item.  Inject the target include and
                ;; library dirs here: -B gets the multilib subdirectory
                ;; (e.g. thumb/v6-m/nofp) appended by the driver and covers
                ;; both libraries and startfiles (crt0.o), while
                ;; -idirafter keeps the include_next chain (gcc's own
                ;; stdint.h -> newlib's stdint.h) working.
                (for-each (lambda (name)
                            (let ((wrapper (string-append bin-dir "/"
                                                          #$target "-" name))
                                  (real (string-append gcc-dir "/bin/"
                                                       #$target "-" name)))
                              (when (file-exists? wrapper)
                                (delete-file wrapper))
                              (call-with-output-file wrapper
                                (lambda (port)
                                  (format port "#!~a~%"
                                          #$(file-append bash "/bin/sh"))
                                  (format port "set -e~%")
                                  (format port "target_dir=\"~a\"~%"
                                          (string-append out "/" #$target))
                                  (format port "args=()~%")
                                  (format port
                                   "args+=(\"-B$target_dir/lib/\")~%")
                                  (format port
                                   "args+=(\"-idirafter\" \"$target_dir/include/c++\"~%")
                                  (format port
                                   "        \"-idirafter\" \"$target_dir/include/c++/~a\"~%"
                                          #$target)
                                  (format port
                                   "        \"-idirafter\" \"$target_dir/include\")~%")
                                  (format port "for arg in \"$@\"; do~%")
                                  (format port "  case \"$arg\" in~%")
                                  (format port "    --specs=*)~%")
                                  (format port
                                          "      name=\"${arg#--specs=}\"~%")
                                  (format port
                                   "      if [ -f \"$target_dir/lib/$name\" ]; then~%")
                                  (format port
                                   "        args+=(\"--specs=$target_dir/lib/$name\")~%")
                                  (format port "      else~%")
                                  (format port "        args+=(\"$arg\")~%")
                                  (format port "      fi ;;~%")
                                  (format port "    *) args+=(\"$arg\") ;;~%")
                                  (format port "  esac~%")
                                  (format port "done~%")
                                  (format port "exec ~a \"${args[@]}\"~%" real)))
                              (chmod wrapper #o555)))
                          (list "gcc" "g++" "c++"))
                #t)))))
      (propagated-inputs `(("binutils" ,(zephyr-cross-binutils target))
                           ("gcc" ,xgcc)
                           ("newlib" ,newlib)
                           ("libstdc++" ,libstdcxx)))
      (synopsis (string-append "Complete GCC toolchain for Zephyr (" target
                               ")"))
      (description (string-append
                    "This package provides a complete source-built GCC
 toolchain for Zephyr bare-metal development targeting "
                    target ".  It
 includes Binutils, GCC, newlib, and libstdc++."))
      (home-page "https://gcc.gnu.org/")
      (license license:gpl3+))))

(define-public arm-zephyr-eabi-toolchain
  (make-zephyr-toolchain "arm-zephyr-eabi"
                         #:multilib-list "aprofile,rmprofile"))

(define-public aarch64-zephyr-elf-toolchain
  (make-zephyr-toolchain "aarch64-zephyr-elf"))

(define-public riscv64-zephyr-elf-toolchain
  (make-zephyr-toolchain "riscv64-zephyr-elf"
                         #:multilib-generator %riscv-zephyr-multilib-generator
                         #:with-arch "rv64imac"
                         #:with-abi "lp64"))

;; Same source-built GCC/newlib stack, but with the conventional GNU triplet
;; so that pico-sdk and other bare-metal projects find arm-none-eabi-gcc by
;; default.  The rmprofile multilib set covers Cortex-M0+/M3/M4/M7 (and the
;; R profiles); RP2350 (Cortex-M33) is included as well.
(define-public arm-none-eabi-toolchain
  (package
    (inherit (make-zephyr-toolchain "arm-none-eabi"
                                    #:multilib-list "rmprofile"))
    (synopsis "Complete GCC toolchain for ARM Cortex-R/M bare-metal development")
    (description
     "This package provides a complete source-built GCC toolchain for ARM
Cortex-R/M bare-metal development with the standard @code{arm-none-eabi}
triplet.  It includes Binutils, GCC, newlib, and libstdc++, with the
@code{rmprofile} multilib set covering Cortex-M0+/M3/M4/M7/M33 and Cortex-R
targets.")))
