(define-module (ebreak packages openocd-rpi)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module ((gnu packages embedded) #:select (libjaylink))
  #:use-module (gnu packages libftdi)
  #:use-module (gnu packages tcl)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages compression))

;; Raspberry Pi's fork of OpenOCD, pinned to the sdk-2.0.0 branch tip used
;; by the pico-sdk tooling.  It is based on OpenOCD 0.12.0 and adds RP2040 /
;; RP2350 target support.
;;
;; The fork carries jimtcl and libjaylink as git submodules.  We fetch
;; non-recursively (leaving empty submodule directories) and use Guix's
;; jimtcl/libjaylink via --disable-internal-* instead; the bootstrap script
;; must therefore be invoked with "nosubmodule".
(define-public openocd-rpi
  (package
    (name "openocd-rpi")
    (version "sdk-2.0.0-0.cf9c0b41")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/raspberrypi/openocd")
             (commit "cf9c0b41cd5c45b2faf01b4fd1186f160342b7b7")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "083a7kmbzphd0nmdhsy9016kwqsmwy2kvalmzyj08qijdk6gvass"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("libtool" ,libtool)
       ("which" ,which)
       ("pkg-config" ,pkg-config)
       ("texinfo" ,texinfo)))
    (inputs
     (list hidapi jimtcl libftdi libjaylink openssl zlib))
    (arguments
     (list
      ;; The upstream test suite contains JTAG hardware-in-the-loop tests
      ;; that cannot succeed inside the Guix build sandbox.
      #:tests? #f
      #:configure-flags
      #~(append (list "LIBS=-lutil -lcrypto -lssl -lz"
                      "--disable-werror"
                      "--enable-sysfsgpio"
                      "--enable-bcm2835gpio"
                      "--disable-internal-jimtcl"
                      "--disable-internal-libjaylink")
                (map (lambda (programmer)
                       (string-append "--enable-" programmer))
                     '("ftdi" "jlink" "cmsis-dap" "cmsis-dap-v2"
                       "usb-blaster-2" "usb_blaster" "openjtag"
                       "xds110" "ti-icdi" "stlink" "ulink" "nulink"
                       "kitprog" "rshim" "remote-bitbang")))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              ;; Make build reproducible.
              (substitute* "src/Makefile.am"
                (("-DPKGBLDDATE=") "-DDISABLED_PKGBLDDATE="))
              (patch-shebang "bootstrap")
              (invoke "./bootstrap" "nosubmodule")))
          (add-after 'unpack 'change-udev-group
            (lambda _
              (substitute* "contrib/60-openocd.rules"
                (("plugdev") "dialout"))))
          (add-after 'install 'install-udev-rules
            (lambda* (#:key outputs #:allow-other-keys)
              ;; Rename so the file does not conflict with the rules file
              ;; shipped by the upstream 'openocd' package.
              (install-file "contrib/60-openocd.rules"
                            (string-append
                             (assoc-ref outputs "out")
                             "/lib/udev/rules.d/60-openocd-rpi.rules"))))
          (add-after 'install-udev-rules 'rename-for-openocd-rpi
            (lambda* (#:key outputs #:allow-other-keys)
              ;; Move everything that would conflict with the upstream
              ;; 'openocd' package out of the way and provide an
              ;; 'openocd-rpi' command instead.
              (let* ((out (assoc-ref outputs "out"))
                     (bindir (string-append out "/bin"))
                     (real-binary (string-append bindir "/.openocd-rpi-real"))
                     (sharedir (string-append out "/share"))
                     (scriptsdir (string-append sharedir
                                                "/openocd-rpi/scripts")))
                ;; Install the real OpenOCD binary under a hidden name.
                (rename-file (string-append bindir "/openocd") real-binary)
                ;; Move the scripts tree under a package-specific directory.
                (rename-file (string-append sharedir "/openocd")
                             (string-append sharedir "/openocd-rpi"))
                ;; Some board configs refer to
                ;; "../share/openocd/scripts/..."; resolve those through the
                ;; -s search path used by the wrapper below.
                (for-each
                 (lambda (file)
                   (substitute* file
                     (("\\.\\./share/openocd/scripts/") "")))
                 (find-files scriptsdir "\\.(cfg|tcl)$"))
                ;; Rename the man page and the info manual, which would
                ;; otherwise also conflict with the upstream package.
                (let ((man1 (string-append out "/share/man/man1")))
                  (when (file-exists? (string-append man1 "/openocd.1"))
                    (rename-file (string-append man1 "/openocd.1")
                                 (string-append man1 "/openocd-rpi.1"))))
                (for-each
                 (lambda (file)
                   (rename-file
                    file
                    (string-append (dirname file) "/openocd-rpi.info"
                                   (substring file
                                              (+ (string-length (dirname file))
                                                 (string-length
                                                  "/openocd.info"))))))
                 (find-files (string-append out "/share/info")
                             "^openocd\\.info"))
                ;; Create a wrapper script that points OpenOCD to its own
                ;; scripts.  This avoids relying on the built-in FHS search
                ;; path, which does not exist on Guix systems.
                (call-with-output-file (string-append bindir "/openocd-rpi")
                  (lambda (port)
                    (format port "#!/bin/sh~%exec ~a -s ~a \"$@\"~%"
                            real-binary scriptsdir)))
                (chmod (string-append bindir "/openocd-rpi") #o555)))))))
    (home-page "https://github.com/raspberrypi/openocd")
    (synopsis "Raspberry Pi fork of OpenOCD with RP2040/RP2350 support")
    (description
     "This package provides Raspberry Pi's fork of OpenOCD (sdk-2.0.0 branch,
based on OpenOCD 0.12.0), which adds support for debugging and flashing
RP2040 and RP2350 microcontrollers, e.g. via the Raspberry Pi Debug Probe or
Picoprobe.  To avoid file conflicts with the upstream @code{openocd} package,
the executable is installed as @command{openocd-rpi} (a wrapper that points
OpenOCD to its scripts under @file{share/openocd-rpi/scripts}).")
    (license license:gpl2+)))
