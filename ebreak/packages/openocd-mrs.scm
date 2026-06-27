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

(define-public openocd-mrs
  (package
    (name "openocd-mrs")
    (version "V240")
    ;; NOTE: This URL carries a time-limited signature from the MounRiver API.
    ;; When it expires, query the API as AUR does:
    ;;   curl 'http://api.mounriver.com/mountriver/api/version/fetchRecentOpenOcd?osType=LINUX&lang=zh'
    ;;   curl 'https://api.mounriver.com/mountriver/api/version/getDownloadUrl?resourceId=<softResId>'
    (source
     (origin
       (method url-fetch)
       (uri "https://file-oss.mounriver.com/tools/MRS_Toolchain_Linux_X64_V240.tar.xz?sign=b35840efc22d9d4336f18172f1258674&time=19ef9b97a14&from=113.87.155.159&resId=2030113772066086913")
       (file-name "MRS_Toolchain_Linux_X64_V240.tar.xz")
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
                 (sharedir (string-append out "/share/openocd"))
                 (tar (string-append (assoc-ref %build-inputs "tar") "/bin/tar"))
                 (patchelf (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf"))
                 (libc (assoc-ref %build-inputs "libc"))
                 (gcc-lib (assoc-ref %build-inputs "gcc:lib"))
                 (rpath (string-join
                         (map (lambda (input)
                                (string-append (assoc-ref %build-inputs input) "/lib"))
                              '("libc" "gcc:lib" "libusb" "hidapi" "libjaylink" "eudev"))
                         ":"))
                 (interpreter (string-append libc "/lib/ld-linux-x86-64.so.2"))
                 (openocd-orig "OpenOCD/OpenOCD/bin/openocd"))
            ;; Extract the upstream tarball.
            (invoke tar "-xf" source "-C" ".")
            ;; Install OpenOCD binary.
            (mkdir-p bindir)
            (copy-file openocd-orig (string-append bindir "/openocd-mrs"))
            ;; Install scripts/configs shipped with OpenOCD.
            (mkdir-p sharedir)
            (copy-recursively "OpenOCD/OpenOCD/share/openocd/scripts"
                              (string-append sharedir "/scripts"))
            ;; Patch the interpreter and RUNPATH so it uses Guix libraries.
            (invoke patchelf "--set-interpreter" interpreter
                    "--set-rpath" rpath
                    (string-append bindir "/openocd-mrs"))
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
from Guix instead of hard-coded FHS paths.")
    (license license:unlicense)))

