(define-module (ebreak packages openocd-mrs)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages embedded)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages elf)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:))

(define %openocd-mrs-script-dir
  ;; Directory where MounRiver-specific OpenOCD scripts are installed.
  "/share/openocd-mrs/scripts")

(define-public openocd-mrs
  (package
    (name "openocd-mrs")
    (version "V240")
    (source
     (origin
      (method url-fetch)
      (uri "https://github.com/EBREAK/blob/releases/download/20260707/MRS_Toolchain_Linux_X64_V240.tar.xz")
      (sha256
       (base32
        "0v9az3z44lg3g0m92gp3gxc3y526yw0gvw1dgkqnci724wymkbhz"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (begin
            (setenv "PATH" (string-append (assoc-ref %build-inputs "xz") "/bin"))
            (let* ((source #$source)
                   (out #$output)
                   (bindir (string-append out "/bin"))
                   (sharedir (string-append out #$%openocd-mrs-script-dir))
                   (real-binary (string-append bindir "/.openocd-mrs-real"))
                   (tar (string-append (assoc-ref %build-inputs "tar") "/bin/tar"))
                   (patchelf (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf"))
                   (libc (assoc-ref %build-inputs "libc"))
                   (rpath (string-join
                           (map (lambda (input)
                                  (string-append (assoc-ref %build-inputs input) "/lib"))
                                '("libc" "gcc:lib" "libusb" "hidapi" "libjaylink" "eudev"))
                           ":"))
                   (interpreter (string-append libc "/lib/ld-linux-x86-64.so.2"))
                   (openocd-orig "OpenOCD/OpenOCD/bin/openocd"))
              ;; Extract the upstream tarball.
              (invoke tar "-xf" source "-C" ".")
              ;; Install the real OpenOCD binary under a hidden name.
              (mkdir-p bindir)
              (copy-file openocd-orig real-binary)
              ;; Install scripts/configs shipped with OpenOCD under a package-specific
              ;; directory so that they do not conflict with the upstream 'openocd'
              ;; package when both are installed in the same profile.
              (mkdir-p sharedir)
              (copy-recursively "OpenOCD/OpenOCD/share/openocd/scripts"
                                sharedir)
              ;; Patch the interpreter and RUNPATH so it uses Guix libraries.
              (invoke patchelf "--set-interpreter" interpreter
                      "--set-rpath" rpath
                      real-binary)
              ;; MounRiver's scripts contain relative FHS references such as
              ;; "../share/openocd/scripts/target/swj-dp.tcl".  Rewrite them so
              ;; that OpenOCD finds them through the -s search path above.
              (for-each
               (lambda (file)
                 (substitute* file
                   (("\\.\\./share/openocd/scripts/") "")))
               (find-files sharedir "\\.(cfg|tcl)$"))
              ;; Create a wrapper script that points OpenOCD to its own scripts.
              ;; This avoids relying on the built-in FHS search path, which does
              ;; not exist on Guix systems.
              (call-with-output-file (string-append bindir "/openocd-mrs")
                (lambda (port)
                  (format port "#!/bin/sh~%exec ~a -s ~a \"$@\"~%"
                          real-binary sharedir)))
              (chmod (string-append bindir "/openocd-mrs") #o555)
              #t)))))
    (native-inputs
     `(("patchelf" ,patchelf)
       ("tar" ,tar)
       ("xz" ,xz)))
    (inputs
     `(("libc" ,glibc)
       ("gcc:lib" ,gcc-14 "lib")
       ("libusb" ,libusb)
       ("hidapi" ,hidapi)
       ("libjaylink" ,libjaylink)
       ("eudev" ,eudev)))
    (home-page "https://www.mounriver.com/")
    (synopsis "MounRiver Studio OpenOCD binary distribution")
    (description
     "This package repackages the MounRiver Studio OpenOCD binary
      distribution for Linux x86_64.  The embedded @command{openocd} ELF
      executable is patched with @command{patchelf} so that it uses libraries
      from Guix instead of hard-coded FHS paths.  To avoid file conflicts with
      the upstream @code{openocd} package, scripts are installed under
      @file{share/openocd-mrs/scripts} and the @command{openocd-mrs} command is
      a wrapper that points OpenOCD to that directory.")
    (license license:unlicense)))
