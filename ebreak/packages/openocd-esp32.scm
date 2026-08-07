(define-module (ebreak packages openocd-esp32)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
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

(define %esp-stub-lib-version
  "4f277e223863039b3a609555c5b27779b3a6901f")

;; The esp-stub-lib submodule is required by the OpenOCD ESP32 build to
;; produce the flash loader stubs.  We fetch it as a plain tarball instead of
;; using git-fetch's recursive mode so that the unrelated jimtcl/libjaylink
;; submodules (which are disabled below via --disable-internal-*) do not have
;; to be cloned inside the build sandbox.
(define %esp-stub-lib
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/espressif/esp-stub-lib/archive/"
                        %esp-stub-lib-version ".tar.gz"))
    (file-name (string-append "esp-stub-lib-" %esp-stub-lib-version ".tar.gz"))
    (sha256
     (base32
      "0ca6q1jq0jnnn11zkvzwsq2cnyxyrbw8mxi2d19kfg961sffcv1q"))))

(define-public openocd-esp32
  (package
    (name "openocd-esp32")
    (version "0.12.0-esp32-20260703")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/espressif/openocd-esp32/"
                           "archive/refs/tags/v" version ".tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32
         "1mp0049zx0fm6dv51q0nqp79npaq2y04jf26d87v0rbzhhvy87ax"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("libtool" ,libtool)
       ("which" ,which)
       ("pkg-config" ,pkg-config)
       ("texinfo" ,texinfo)
       ("esp-stub-lib" ,%esp-stub-lib)))
    (inputs
     (list hidapi jimtcl libftdi libjaylink openssl zlib))
    (arguments
     (list
      ;; The upstream test suite contains JTAG hardware-in-the-loop tests
      ;; (e.g. testing/tcl_commands/test-target-smp-command.cfg) that cannot
      ;; succeed inside the Guix build sandbox.
      #:tests? #f
      #:configure-flags
      #~(append (list "LIBS=-lutil -lcrypto -lssl -lz"
                      "--disable-werror"
                      "--enable-sysfsgpio"
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
          (add-after 'unpack 'install-esp-stub-lib
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Place the externally-fetched esp-stub-lib submodule where
              ;; the build system expects it.  The source tarball contains an
              ;; empty placeholder directory for the submodule, so remove it
              ;; before creating the symlink.
              (let* ((stub-lib-input (assoc-ref inputs "esp-stub-lib"))
                     (stub-lib-dir (string-append stub-lib-input
                                                  "/esp-stub-lib-"
                                                  #$%esp-stub-lib-version))
                     (dest-dir "contrib/loaders/flash/espressif")
                     (dest (string-append dest-dir "/esp-stub-lib")))
                (mkdir-p dest-dir)
                (when (file-exists? dest)
                  (delete-file-recursively dest))
                (symlink stub-lib-dir dest))))
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
              (install-file "contrib/60-openocd.rules"
                            (string-append
                             (assoc-ref outputs "out")
                             "/lib/udev/rules.d/")))))))
    (home-page "https://github.com/espressif/openocd-esp32")
    (synopsis "OpenOCD fork with Espressif ESP32 support")
    (description
     "This package provides Espressif's fork of OpenOCD, which adds support
for debugging and flashing ESP32, ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C6
and other Espressif chips.")
    (license license:gpl2+)))
