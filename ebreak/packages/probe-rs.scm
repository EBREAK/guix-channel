(define-module (ebreak packages probe-rs)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (ebreak packages probe-rs-crates))

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
      #:cargo-install-paths ''("probe-rs-tools")))
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
