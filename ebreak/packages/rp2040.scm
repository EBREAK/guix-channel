(define-module (ebreak packages rp2040)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (ebreak packages zephyr-toolchains))

;;; Raspberry Pi RP2040/RP2350 (Pico) development packages.
;;;
;;;   pico-sdk            - Pico SDK source tree
;;;   pioasm              - PIO assembler (host build of pico-sdk's tool)
;;;   picotool            - Pico binary inspection / UF2 conversion tool
;;;   debugprobe-firmware - Raspberry Pi Debug Probe firmware, built for the
;;;                         Debug Probe accessory, the Pico and the Pico 2
;;;
;;; Firmware builds use arm-none-eabi-toolchain (GCC + newlib, rmprofile
;;; multilib) from (ebreak packages zephyr-toolchains).  pioasm and picotool
;;; are packaged as proper host tools so that no nested host/cross builds or
;;; network fetches happen inside firmware package builds.

(define %pico-sdk-version "2.2.0")

;; pico-sdk pins most of its third-party libraries as git submodules.  Only
;; tinyusb is needed to build the Debug Probe firmware, so instead of a
;; (very large) recursive clone we fetch the pinned tinyusb commit on its
;; own and drop it into lib/tinyusb below.
(define %tinyusb-commit
  "86ad6e56c1700e85f1c5678607a762cfe3aa2f47")

(define %tinyusb-origin
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/hathach/tinyusb")
          (commit %tinyusb-commit)))
    (file-name (git-file-name "tinyusb" (substring %tinyusb-commit 0 12)))
    (sha256
     (base32 "1iw2kybml53ba6v1bfndbzqslmyhi6zx32dvhc7gam3hkrlwwvw7"))))

(define-public pico-sdk
  (package
    (name "pico-sdk")
    (version %pico-sdk-version)
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/raspberrypi/pico-sdk")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1wxdp8bwmnvv7aakf1pq1hwr3qbcdyzmxy9k9g5wkz9q7xj481w5"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((dest (string-append #$output "/share/pico-sdk")))
            (mkdir-p (dirname dest))
            (copy-recursively #$source dest)
            ;; Install the pinned tinyusb submodule.
            (let ((tinyusb-dir (string-append dest "/lib/tinyusb")))
              (when (file-exists? tinyusb-dir)
                (delete-file-recursively tinyusb-dir))
              (copy-recursively #$%tinyusb-origin tinyusb-dir))
            #t))))
    (home-page "https://github.com/raspberrypi/pico-sdk")
    (synopsis "Raspberry Pi Pico SDK source tree (RP2040/RP2350)")
    (description
     "This package provides the Raspberry Pi Pico SDK source tree for
RP2040 and RP2350 development, with the pinned TinyUSB submodule included.")
    (license license:bsd-3)))

(define-public pioasm
  (package
    (name "pioasm")
    (version %pico-sdk-version)
    ;; pioasm lives in tools/pioasm inside the pico-sdk tree; the checked-in
    ;; gen/lexer.cpp and gen/parser.cpp mean no bison/flex are needed.
    (source (package-source pico-sdk))
    (build-system cmake-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'configure
            (lambda* (#:key outputs #:allow-other-keys)
              (invoke "cmake" "-S" "tools/pioasm" "-B" "build"
                      "-DCMAKE_BUILD_TYPE=Release"
                      (string-append "-DCMAKE_INSTALL_PREFIX="
                                     (assoc-ref outputs "out"))
                      (string-append "-DPIOASM_VERSION_STRING="
                                     #$version))))
          (replace 'build
            (lambda _
              (invoke "cmake" "--build" "build")))
          (replace 'install
            (lambda _
              (invoke "cmake" "--install" "build"))))))
    (home-page "https://github.com/raspberrypi/pico-sdk")
    (synopsis "PIO assembler for RP2040/RP2350")
    (description
     "pioasm assembles PIO (Programmable I/O) programs for the RP2040 and
RP2350.  The package installs the CMake package config files that pico-sdk
looks up with @code{find_package(pioasm)}, so firmware builds reuse this
host binary instead of building pioasm again.")
    (license license:bsd-3)))

(define-public picotool
  (package
    (name "picotool")
    (version "2.2.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/raspberrypi/picotool")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1c5ahxy6csq5wbqvv1sbdrapwqwki302apzg89299j2gcgsj5my5"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(list (string-append "-DPICO_SDK_PATH="
                             #$(this-package-native-input "pico-sdk")
                             "/share/pico-sdk"))))
    ;; picotool only reads pico-sdk headers and version files at configure
    ;; time; the embedded RP2350 blobs it ships are used precompiled
    ;; (USE_PRECOMPILED defaults to true), so no cross toolchain is needed.
    (native-inputs (list pico-sdk pkg-config))
    (inputs (list libusb))
    (home-page "https://github.com/raspberrypi/picotool")
    (synopsis "Tool for inspecting and manipulating RP2040/RP2350 binaries")
    (description
     "picotool is the Raspberry Pi tool for working with RP2040/RP2350
binaries: converting ELF to UF2, inspecting binaries, and interacting with
devices in BOOTSEL mode over USB.  Its CMake package config is picked up by
pico-sdk's @code{find_package(picotool)}, so firmware builds use this
package instead of downloading picotool from the network.")
    (license license:bsd-3)))

;;; ---------------------------------------------------------------------------
;;; debugprobe-firmware: end-to-end verification for the Pico stack.
;;; ---------------------------------------------------------------------------

;; FreeRTOS-Kernel submodule pinned by debugprobe v2.3.1 (pre-11.1.0).
(define %freertos-kernel-commit
  "682f0515c984da0ef283b12e99791e5ab7b41034")

(define %freertos-kernel-origin
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/FreeRTOS/FreeRTOS-Kernel")
          (commit %freertos-kernel-commit)))
    (file-name (git-file-name "freertos-kernel"
                              (substring %freertos-kernel-commit 0 12)))
    (sha256
     (base32 "1mq4hzs7lww8amdirfqapz88rfxdvpcs856zhgybdrhy7p77zprb"))))

;; Nested submodule of the pinned FreeRTOS-Kernel: home of the RP2350
;; (ARM NTZ and RISC-V) ports referenced by FreeRTOS_Kernel_import.cmake.
(define %freertos-community-ports-commit
  "8b2955f6d97bf4cd582db9f5b62d9eb1587b76d7")

(define %freertos-community-ports-origin
  (origin
    (method git-fetch)
    (uri (git-reference
          (url
           "https://github.com/FreeRTOS/FreeRTOS-Kernel-Community-Supported-Ports")
          (commit %freertos-community-ports-commit)))
    (file-name (git-file-name "freertos-kernel-community-supported-ports"
                              (substring %freertos-community-ports-commit 0 12)))
    (sha256
     (base32 "0gcgwap7c9v94375xrqb1w5wzh63s0zj8an9lbqav5gpl5aay75q"))))

(define-public debugprobe-firmware
  (package
    (name "debugprobe-firmware")
    (version "2.3.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/raspberrypi/debugprobe")
             (commit (string-append "debugprobe-v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "16jhfdw0s2sl8y87wf3g67iqk0nyzd6v4rrpflrh7ai2wx0ksyfg"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'install-freertos-kernel
            (lambda _
              ;; The build expects the FreeRTOS-Kernel submodule at
              ;; ./freertos (see FreeRTOS_Kernel_import.cmake), with its own
              ;; nested Community-Supported-Ports submodule populated (home
              ;; of the RP2350 ports).
              (copy-recursively #$%freertos-kernel-origin "freertos")
              (let ((csp-dir
                     (string-append
                      "freertos/portable/ThirdParty/Community-Supported-Ports")))
                (when (file-exists? csp-dir)
                  (delete-file-recursively csp-dir))
                (copy-recursively #$%freertos-community-ports-origin
                                  csp-dir))))
          (delete 'configure)
          (delete 'build)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              ;; Remove host (glibc) search paths that Guix sets for the
              ;; build tools; the cross compiler also honours them and would
              ;; pick glibc headers before newlib.
              (for-each unsetenv
                        '("C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
                          "OBJC_INCLUDE_PATH" "OBJCPLUS_INCLUDE_PATH"
                          "LIBRARY_PATH"))
              (let ((out (assoc-ref outputs "out"))
                    (pioasm-dir
                     (string-append #$(this-package-native-input "pioasm")
                                    "/lib/cmake/pioasm"))
                    (picotool-dir
                     (string-append #$(this-package-native-input "picotool")
                                    "/lib/cmake/picotool")))
                (for-each
                 (lambda (spec)
                   (let ((label (car spec))
                         (cmake-args (cdr spec)))
                     (let ((bdir (string-append "build-" label)))
                       (apply invoke "cmake" "-S" "." "-B" bdir "-GNinja"
                              (string-append "-Dpioasm_DIR=" pioasm-dir)
                              (string-append "-Dpicotool_DIR=" picotool-dir)
                              (append cmake-args '()))
                       (invoke "ninja" "-C" bdir)
                       (let ((odir (string-append out
                                    "/share/debugprobe-firmware/" label)))
                         (mkdir-p odir)
                         (for-each (lambda (file)
                                     (install-file file odir))
                                   (append (find-files bdir "\\.uf2$")
                                           (find-files bdir "^debugprobe.*\\.elf$")))))))
                 '(("debugprobe")
                   ("pico" "-DDEBUG_ON_PICO=ON")
                   ("pico2" "-DDEBUG_ON_PICO=ON" "-DPICO_BOARD=pico2")))))))))
    (native-inputs (list cmake
                         ninja
                         python
                         arm-none-eabi-toolchain
                         pico-sdk
                         pioasm
                         picotool))
    (home-page "https://github.com/raspberrypi/debugprobe")
    (synopsis "Raspberry Pi Debug Probe firmware for Debug Probe, Pico and Pico 2")
    (description
     "This package builds the Raspberry Pi Debug Probe firmware (CMSIS-DAP
SWD/JTAG probe plus a USB-UART bridge) for three targets: the Debug Probe
accessory itself (@file{debugprobe.uf2}), the Raspberry Pi Pico
(@file{debugprobe_on_pico.uf2}) and the Raspberry Pi Pico 2
(@file{debugprobe_on_pico2.uf2}).  The firmware is cross-compiled with the
source-built @code{arm-none-eabi} GCC toolchain against pico-sdk, and serves
as an end-to-end verification of the Pico packaging stack.  Artifacts are
installed under @file{share/debugprobe-firmware/}.")
    (license license:bsd-3)))
