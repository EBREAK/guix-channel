(define-module (ebreak packages usb-tools)
  #:use-module (gnu packages)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages pkg-config)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public usb-sniffer
  (package
    (name "usb-sniffer")
    (version "0d26e7e")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ataradov/usb-sniffer.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "13190bzpp00vnl1f9d01lws5h8i4jhi1myv57prk9nlv4zmrv1ys"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags
      #~(list (string-append "CC=" #$(cc-for-target))
              (string-append "BIN=" #$name))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-before 'build 'chdir
            (lambda _
              (chdir "software")
              #t))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin"))
                     (extcap (string-append out "/lib/wireshark/extcap"))
                     (libexec (string-append out "/libexec/usb-sniffer"))
                     (rules (string-append out "/lib/udev/rules.d")))
                (mkdir-p extcap)
                (install-file "usb-sniffer" extcap)
                (mkdir-p bin)
                (symlink (string-append extcap "/usb-sniffer")
                         (string-append bin "/usb-sniffer"))
                (mkdir-p libexec)
                (install-file "../bin/usb_sniffer.bin" libexec)
                (install-file "../bin/usb_sniffer_impl.jed" libexec)
                (mkdir-p rules)
                (install-file "../bin/90-usb-sniffer.rules" rules)
                #t))))))
    (native-inputs
     (list pkg-config))
    (inputs
     (list libusb))
    (home-page "https://github.com/ataradov/usb-sniffer")
    (synopsis "USB sniffer software for the usb-sniffer hardware")
    (description
     "This package provides the host-side capture software for Alex Taradov's
USB sniffer.  It captures USB traffic using a Cypress FX2LP-based hardware
sniffer and outputs pcapng files for analysis in Wireshark.")
    (license license:bsd-3)))

(define-public wch-ble-analyzer-capture
  (package
    (name "wch-ble-analyzer-capture")
    (version "36805b1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/xecaz/BLE-Analyzer-pro-linux-capture.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0f6zgjhqx3g14140dk4vzmgldn48f529d3d9cwqmnasgiywlaqc2"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags
      #~(list (string-append "CC=" #$(cc-for-target))
              (string-append "DESTDIR=" #$output))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin"))
                     (rules (string-append out "/lib/udev/rules.d")))
                (mkdir-p bin)
                (mkdir-p rules)
                (install-file "wch_capture" bin)
                (install-file "99-wch-ble-analyzer.rules" rules)
                #t))))))
    (native-inputs
     (list pkg-config))
    (inputs
     (list libusb))
    (home-page "https://github.com/xecaz/BLE-Analyzer-pro-linux-capture")
    (synopsis "Capture software for the WCH BLE Analyzer Pro")
    (description
     "This package provides a Linux capture tool for the WCH BLE Analyzer Pro
hardware.  It captures BLE traffic over USB and writes capture files that can
be analyzed with Wireshark.")
    (license license:unlicense)))
