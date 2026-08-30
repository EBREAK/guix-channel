(define-module (ebreak packages probe-rs)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (ebreak packages probe-rs-crates))

(define %probe-rs-udev-rules
  (string-append
    "# Copy this file to /etc/udev/rules.d/\n"
    "# If rules fail to reload automatically, you can refresh udev rules\n"
    "# with the command \"udevadm control --reload\"\n"
    "\n"
    "# This rules are based on the udev rules from the OpenOCD project, with unsupported probes removed.\n"
    "# See http://openocd.org/ for more details.\n"
    "#\n"
    "# This file is available under the GNU General Public License v2.0\n"
    "\n"
    "ACTION!=\"add|change\", GOTO=\"probe_rs_rules_end\"\n"
    "\n"
    "SUBSYSTEM==\"gpio\", MODE=\"0660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "SUBSYSTEM!=\"usb|tty|hidraw\", GOTO=\"probe_rs_rules_end\"\n"
    "\n"
    "# Please keep this list sorted by VID:PID\n"
    "\n"
    "# STMicroelectronics ST-LINK V1\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"3744\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# STMicroelectronics ST-LINK/V2\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"3748\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# STMicroelectronics ST-LINK/V2.1\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"374b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"3752\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# STMicroelectronics STLINK-V3\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"374d\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"374e\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"374f\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"3753\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"3754\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"3757\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# SEGGER J-Link\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0101\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0102\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0103\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0104\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0105\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0107\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"0108\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1001\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1002\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1003\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1004\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1005\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1006\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1007\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1008\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1009\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"100a\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"100b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"100c\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"100d\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"100e\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"100f\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1010\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1011\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1012\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1013\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1014\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1015\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1016\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1017\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1018\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1019\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"101a\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"101b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"101c\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"101d\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"101e\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"101f\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1020\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1021\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1022\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1023\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1024\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1025\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1026\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1027\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1028\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1029\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"102a\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"102b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"102c\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"102d\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"102e\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"102f\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1050\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1051\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1052\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1053\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1054\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1055\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1056\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1057\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1058\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1059\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"105a\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"105b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"105c\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"105d\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"105e\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"105f\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1060\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1061\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1062\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1063\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1064\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1065\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1066\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1067\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1068\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"1069\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"106a\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"106b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"106c\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"106d\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"106e\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1366\", ATTRS{idProduct}==\"106f\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# FT232H\n"
    "ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6014\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "# FT2232x\n"
    "ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6010\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "# FT4232H\n"
    "ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6011\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# FTDI-based Olimex devices\n"
    "ATTRS{idVendor}==\"0x15ba\", ATTRS{idProduct}==\"0x0003\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0x15ba\", ATTRS{idProduct}==\"0x0004\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0x15ba\", ATTRS{idProduct}==\"0x002a\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"0x15ba\", ATTRS{idProduct}==\"0x002b\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# Espressif USB JTAG/serial debug unit\n"
    "ATTRS{idVendor}==\"303a\", ATTRS{idProduct}==\"1001\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "# Espressif USB Bridge\n"
    "ATTRS{idVendor}==\"303a\", ATTRS{idProduct}==\"1002\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# CMSIS-DAP compatible adapters\n"
    "ATTRS{product}==\"*CMSIS-DAP*\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "# WCH Link (CMSIS-DAP compatible adapter)\n"
    "ATTRS{idVendor}==\"1a86\", ATTRS{idProduct}==\"8010\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "ATTRS{idVendor}==\"1a86\", ATTRS{idProduct}==\"8011\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "# Infineon KitProg\n"
    "ATTRS{idVendor}==\"04b4\", ATTRS{idProduct}==\"f155\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"\n"
    "\n"
    "LABEL=\"probe_rs_rules_end\"\n"
    "\n"))

(define-public probe-rs
  (package
    (name "probe-rs")
    (version "0.32.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             ;; Fetch through the ghfast.top GitHub proxy: github.com is
             ;; unreachable from the build machines on this network.  The
             ;; proxy serves the identical repository contents, so the hash
             ;; below matches upstream tag v0.32.0.
             (url "https://ghfast.top/https://github.com/probe-rs/probe-rs")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0gqff1h4wc80l9g1wi7wv5kzy81sirn3rqflbarn1dil8lpaia0b"))))
    (build-system cargo-build-system)
    (arguments
     (list
      ;; The test suite requires connected debug probes and cannot succeed
      ;; inside the build sandbox.
      #:tests? #f
      #:install-source? #f
      ;; probe-rs is a workspace; only build and install the CLI crate
      ;; (probe-rs, cargo-flash and cargo-embed binaries).
      #:cargo-build-flags ''("--release" "-p" "probe-rs-tools")
      #:cargo-install-paths ''("probe-rs-tools")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'install-udev-rules
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((rules (string-append (assoc-ref outputs "out")
                                          "/lib/udev/rules.d")))
                (mkdir-p rules)
                (with-output-to-file (string-append rules "/69-probe-rs.rules")
                  (lambda _
                    (display #$%probe-rs-udev-rules))))
              #t)))))
    ;; aws-lc-sys builds its bundled C/ASM code with cmake; hidapi and
    ;; basic-udev locate libudev through pkg-config.
    (native-inputs (list cmake pkg-config))
    (inputs
     (cons eudev
           (cargo-inputs 'probe-rs-tools
                         #:module '(ebreak packages probe-rs-crates))))
    (home-page "https://probe.rs/")
    (synopsis "Modern embedded debugging toolkit for ARM and RISC-V targets")
    (description
     "probe-rs is a modern, embedded debugging toolkit that provides on-chip
debugging and flashing of ARM and RISC-V microcontrollers.  This package
provides the @command{probe-rs}, @command{cargo-flash} and
@command{cargo-embed} command line tools.")
    (license (list license:expat license:asl2.0))))
