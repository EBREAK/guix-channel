(define-module (ebreak packages zephyr)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages embedded)
  #:use-module (gnu packages gperf)
  #:use-module (gnu packages bootloaders)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages commencement)
  #:use-module (ebreak packages zephyr-toolchains))

;;; Zephyr development environment for Guix.
;;;
;;; Each HAL / library module is a separate Guix package.  Every module
;;; package exports ZEPHYR_MODULES via native-search-paths (separator ";"),
;;; so when multiple packages are in a profile, Guix concatenates them
;;; automatically.
;;;
;;; Adding a new MCU family = one more package in the profile.  No rebuild
;;; of existing packages.

;;; ---------------------------------------------------------------------------
;;; Helper: create a Zephyr module package from a git origin.
;;; ---------------------------------------------------------------------------

(define* (make-zephyr-module pkg-name
                             synopsis
                             commit
                             url
                             hash
                             dest)
  "Return a package that installs a single Zephyr module to
$out/share/zephyr-modules/<dest>."
  (package
    (name pkg-name)
    (version (string-append "zephyr-4.4.2-"
                            (substring commit 0 12)))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url url)
             (commit commit)))
       (file-name (git-file-name pkg-name commit))
       (sha256
        (base32 hash))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (d (string-append out "/share/zephyr-modules/"
                                   #$dest)))
            (mkdir-p (dirname d))
            (copy-recursively #$source d) #t))))
    ;; NOTE: ZEPHYR_MODULES is exported once, by the meta package
    ;; (see %zephyr-module-dirs below): Guix search-path specs with the
    ;; same variable but different files fields do not accumulate, so
    ;; each module must not export the variable itself.
    (home-page url)
    (synopsis synopsis)
    (description (string-append synopsis "."))
    (license license:asl2.0)))

;;; ---------------------------------------------------------------------------
;;; Module packages — common.
;;; ---------------------------------------------------------------------------

(define-public zephyr-modules-cmsis
  (make-zephyr-module "zephyr-modules-cmsis"
                      "CMSIS-Core headers for ARM Cortex-A/R"
                      "512cc7e895e8491696b61f7ba8066b4a182569b8"
                      "https://github.com/zephyrproject-rtos/cmsis"
                      "0i89w596mqcqzmwd01zhkq5agrfs14ayzfd2jbkqwqgfqimij7i1"
                      "cmsis"))

(define-public zephyr-modules-cmsis-6
  (make-zephyr-module "zephyr-modules-cmsis-6"
                      "CMSIS-Core 6 headers for ARM Cortex-M"
                      "30a859f44ef8ab4dc8f84b03ed586fd16ccf9d74"
                      "https://github.com/zephyrproject-rtos/CMSIS_6"
                      "16nz1kqjknwv397hda20vjccaw23h5ka8k76kihfz9kl4chs2dwx"
                      "cmsis_6"))

(define-public zephyr-modules-picolibc
  (make-zephyr-module "zephyr-modules-picolibc"
                      "Picolibc C library for Zephyr"
                      "01254932e8e81085817ed61fd858648584ffe37c"
                      "https://github.com/zephyrproject-rtos/picolibc"
                      "0ynb9cn70svdg27y8fcr4r06wh38wym0sc8m25y4ifxvacr9hyky"
                      "picolibc"))

(define-public zephyr-modules-segger
  (make-zephyr-module "zephyr-modules-segger"
                      "SEGGER RTT and SystemView libraries"
                      "50892fdbcf2f570e67baa72b8894a66b16946f72"
                      "https://github.com/zephyrproject-rtos/segger"
                      "1i251npn1w9k5wg00i1dac8dvv85xk2fyfq7f2ji1wh37cxwqahk"
                      "segger"))

;;; ---------------------------------------------------------------------------
;;; Module packages — MCU families.
;;; ---------------------------------------------------------------------------

(define-public zephyr-modules-hal-rpi-pico
  (make-zephyr-module "zephyr-modules-hal-rpi-pico"
                      "Raspberry Pi RP2040 / RP2350 HAL"
                      "562b41e10a1d8b1a761b253b107c5c6a84cf4535"
                      "https://github.com/zephyrproject-rtos/hal_rpi_pico"
                      "1386iz543d0vgp64xncbw5p206xxafgnyy8zhk5dqww6bxmi1jyp"
                      "hal/rpi_pico"))

(define-public zephyr-modules-hal-wch
  (make-zephyr-module "zephyr-modules-hal-wch"
                      "WCH CH32V / CH32L HAL (ch32fun)"
                      "dd3855ea624b05de7e6e95584789615d2058a0f3"
                      "https://github.com/zephyrproject-rtos/hal_wch"
                      "0ga2skb0xbknkjy26lr8ywq30s4y29m7h3c87kwykshl8xx9hff0"
                      "hal/wch"))

;;--- To add a new family, copy the pattern: ---
;; (define-public zephyr-modules-hal-stm32
;;   (make-zephyr-module
;;    "zephyr-modules-hal-stm32"
;;    "STMicroelectronics STM32 HAL"
;;    "<commit>"                          ; from west.yml
;;    "https://github.com/zephyrproject-rtos/hal_stm32"
;;    "<base32-hash>"                     ; guix hash -rx .
;;    "hal/stm32"))                       ; install dest

;;; ---------------------------------------------------------------------------
;;; zephyr-source: Zephyr RTOS core source tree.  Exports ZEPHYR_BASE.
;;; ---------------------------------------------------------------------------

(define-public zephyr-source
  (package
    (name "zephyr-source")
    (version "4.4.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/zephyrproject-rtos/zephyr/"
                           "archive/refs/tags/v" version ".tar.gz"))
       (file-name (string-append "zephyr-" version ".tar.gz"))
       (sha256
        (base32 "0m0xv3mp02z0mdlhqjs9d7rmyrnhnfs1iw4yxhr5yxa8p2k27p7p"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (source #$source)
                 (tar (string-append (assoc-ref %build-inputs "tar")
                                     "/bin/tar"))
                 (gzip (string-append (assoc-ref %build-inputs "gzip")
                                      "/bin/gzip")))
            (setenv "PATH"
                    (string-append (dirname tar) ":"
                                   (dirname gzip)))
            (mkdir-p (string-append out "/share/zephyr"))
            (invoke tar
                    "-xzf"
                    source
                    "-C"
                    (string-append out "/share/zephyr")
                    "--strip-components=1")
            ;; Fix: zephyr_get() caches ZEPHYR_MODULES as an INTERNAL
            ;; CMake cache entry; a stale cache or a non-accumulating
            ;; env var then yields only the last module.  Read the env
            ;; var directly instead.
            (substitute* (string-append out
                          "/share/zephyr/cmake/modules/zephyr_module.cmake")
              (("zephyr_get\\(ZEPHYR_MODULES\\)")
               "if(DEFINED ENV{ZEPHYR_MODULES} AND NOT DEFINED ZEPHYR_MODULES)
  set(ZEPHYR_MODULES \"$ENV{ZEPHYR_MODULES}\")
endif()")
              ;; Skip zephyr_module.py when the module files were
              ;; pre-generated (Guix package builds do this from Guile).
              ;; Interactive builds generate them here as usual.
              (("if\\(WEST OR ZEPHYR_MODULES\\)")
               "if(WEST OR ZEPHYR_MODULES)
if(NOT EXISTS ${cmake_modules_file})")
              (("  if\\(EXISTS ..zephyr_settings_file.\\)")
               "  endif()
  if(EXISTS ${zephyr_settings_file})"))
            ;; Fix: sysroot auto-detection globs the whole compiler root
            ;; for libc.a.  In a Guix profile that merges several cross
            ;; toolchains this picks the alphabetically first triplet
            ;; (e.g. aarch64 when building riscv64).  Restrict the glob
            ;; to the triplet matching the CROSS_COMPILE prefix.
            (substitute* (string-append out
                          "/share/zephyr/cmake/toolchain/cross-compile/target.cmake")
              (("file.GLOB_RECURSE libc_dirs RELATIVE [$][{]search_path[}] [$][{]search_path[}]/[*][*]/libc[.]a [)]")
               "if(CROSS_COMPILE)
      string(REGEX REPLACE \"-$\" \"\" _guix_zephyr_target \"${CROSS_COMPILE}\")
      file(GLOB_RECURSE libc_dirs RELATIVE ${search_path} ${search_path}/${_guix_zephyr_target}/**/libc.a)
    else()
      file(GLOB_RECURSE libc_dirs RELATIVE ${search_path} ${search_path}/**/libc.a )
    endif()"))
            #t))))
    (native-inputs `(("tar" ,tar)
                     ("gzip" ,gzip)))
    (native-search-paths
     (list (search-path-specification
            (variable "ZEPHYR_BASE")
            (files '("share/zephyr")))))
    (home-page "https://zephyrproject.org/")
    (synopsis "Zephyr RTOS core source tree")
    (description "Zephyr RTOS core source tree.  Exports @code{ZEPHYR_BASE}.")
    (license license:asl2.0)))

;;; ---------------------------------------------------------------------------
;;; zephyr-sdk: toolchains + host tools.
;;; ---------------------------------------------------------------------------

(define-public zephyr-sdk
  (package
    (name "zephyr-sdk")
    (version "1.0-guix")
    (source
     #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build union))
      #:builder
      #~(begin
          (use-modules (guix build union))
          (union-build (assoc-ref %outputs "out")
                       (list #$arm-zephyr-eabi-toolchain
                             #$aarch64-zephyr-elf-toolchain
                             #$riscv64-zephyr-elf-toolchain
                             #$(gexp-input openocd "out")
                             #$(gexp-input qemu "out")
                             #$(gexp-input dtc "out")
                             #$(gexp-input cmake "out")
                             #$(gexp-input ninja "out")
                             #$(gexp-input gperf "out"))))))
    ;; The toolchains are already unioned into this SDK package; do not
    ;; propagate them again to avoid collisions in the user profile.
    (propagated-inputs `(("openocd" ,openocd)
                         ("qemu" ,qemu)
                         ("dtc" ,dtc)
                         ("cmake" ,cmake)
                         ("ninja" ,ninja)
                         ("gperf" ,gperf)))
    (home-page "https://zephyrproject.org/")
    (synopsis "Source-built Zephyr SDK for ARM, AArch64 and RISC-V")
    (description
     "Bundles Zephyr toolchains and host tools: OpenOCD, QEMU, DTC, CMake,
Ninja and gperf.")
    (license license:gpl3+)))

;;; ---------------------------------------------------------------------------
;;; zephyr-python-deps: Python packages for Zephyr build scripts.
;;; ---------------------------------------------------------------------------

;; Single source of truth: used both by zephyr-python-deps below and by
;; zephyr-prebuild's native-inputs.
(define %zephyr-python-packages
  (list python
        python-pyelftools
        python-pyyaml
        python-pyserial
        python-packaging
        python-jsonschema
        python-pykwalify
        python-anytree
        python-intelhex
        python-semver))

(define-public zephyr-python-deps
  (package
    (name "zephyr-python-deps")
    (version "1.0")
    (source
     #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:builder
      #~(mkdir (assoc-ref %outputs "out"))))
    (propagated-inputs (map (lambda (p)
                              (list (package-name p) p))
                            %zephyr-python-packages))
    (home-page "https://zephyrproject.org/")
    (synopsis "Python dependencies for Zephyr build scripts")
    (description "Python packages required by Zephyr's CMake scripts.")
    ;; Meta-package: licenses of the individual packages vary.
    (license (list license:psfl license:asl2.0 license:expat))))

;;; ---------------------------------------------------------------------------
;;; zephyr-prebuild: builds blinky for each target, producing hex/bin/uf2.
;;; Verifies toolchains and modules work end-to-end.
;;; ---------------------------------------------------------------------------

(define-public zephyr-prebuild
  (package
    (name "zephyr-prebuild")
    (version (package-version zephyr-source))
    (source
     #f)
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'unpack)
          (delete 'configure)
          (delete 'build)
          (replace 'install
            (lambda* (#:key outputs inputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (dest (string-append out "/share/zephyr-prebuild"))
                     (zbase (getenv "ZEPHYR_BASE"))
                     (py3 (which "python3"))
                     (cache (string-append (getcwd) "/cache"))
                     (mod-roots '()))
                (define (collect-modules)
                  (for-each (lambda (pair)
                              (let ((zmod (string-append (cdr pair)
                                           "/share/zephyr-modules")))
                                (when (directory-exists? zmod)
                                  (for-each (lambda (yml)
                                              (set! mod-roots
                                                    (cons (dirname (dirname
                                                                    yml))
                                                          mod-roots)))
                                            (find-files zmod "^module.yml$")))))
                            (or inputs
                                '())))
                (collect-modules)
                (set! mod-roots
                      (string-join (reverse mod-roots) ";"))
                ;; Save original include paths before build-cross unsets them
                (define orig-c-include-path
                  (getenv "C_INCLUDE_PATH"))
                (define orig-cplus-include-path
                  (getenv "CPLUS_INCLUDE_PATH"))
                ;; Clean any stale cache from previous --keep-failed builds
                (when (file-exists? cache)
                  (delete-file-recursively cache))
                (mkdir-p cache)

                (define (copy-artifacts label bdir files)
                  (let ((odir (string-append dest "/" label)))
                    (mkdir-p odir)
                    (for-each (lambda (f)
                                (let ((src (string-append bdir "/zephyr/" f)))
                                  (when (file-exists? src)
                                    (copy-file src
                                               (string-append odir "/" f)))))
                              files)))

                (define (pre-generate-modules bdir)
                  "Pre-generate zephyr_modules.txt and Kconfig.modules by
running zephyr_module.py directly, bypassing cmake's execute_process."
                  (mkdir-p bdir)
                  (mkdir-p (string-append bdir "/Kconfig"))
                  (let* ((mod-script (string-append zbase
                                      "/scripts/zephyr_module.py"))
                         (mod-paths (string-split mod-roots #\;))
                         (args (append (list mod-script
                                             (string-append "--zephyr-base="
                                                            zbase) "--modules")
                                       mod-paths
                                       (list (string-append "--kconfig-out="
                                              bdir "/Kconfig/Kconfig.modules")
                                             (string-append "--cmake-out="
                                              bdir "/zephyr_modules.txt")
                                             (string-append
                                              "--sysbuild-kconfig-out=" bdir
                                              "/Kconfig/Kconfig.sysbuild.modules")
                                             (string-append
                                              "--sysbuild-cmake-out=" bdir
                                              "/sysbuild_modules.txt")
                                             (string-append "--settings-out="
                                              bdir "/zephyr_settings.txt")))))
                    (apply invoke py3 args)))

                (define (build-cross label board cross . rest)
                  (let ((overlay (if (null? rest) #f
                                     (car rest))))
                    (for-each unsetenv
                              '("C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
                                "OBJC_INCLUDE_PATH" "OBJCPLUS_INCLUDE_PATH"
                                "LIBRARY_PATH"))
                    ;; Override Guix's ZEPHYR_MODULES env var (which only has
                    ;; the last module due to non-accumulating search-paths).
                    (setenv "ZEPHYR_MODULES" mod-roots)
                    (setenv "CPATH"
                            (string-append zbase "/modules/cmsis"))
                    (let ((bdir (string-append (getcwd) "/build-" label))
                          (extra-args (if overlay
                                          (list (string-append
                                                 "-DEXTRA_DTC_OVERLAY_FILE="
                                                 overlay))
                                          '())))
                      (when (file-exists? bdir)
                        (delete-file-recursively bdir))
                      (pre-generate-modules bdir)
                      (let ((tcbin (dirname (which (string-append cross "gcc")))))
                        (setenv "CROSS_COMPILE" cross)
                        (setenv "ZEPHYR_TOOLCHAIN_VARIANT" "cross-compile")
                        (setenv "TOOLCHAIN_HOME" tcbin)
                        (apply invoke
                               "cmake"
                               "-B"
                               bdir
                               "-GNinja"
                               (append (list (string-append "-DBOARD=" board)
                                             (string-append
                                              "-DTOOLCHAIN_HOME=" tcbin)
                                             (string-append
                                              "-DPython3_EXECUTABLE=" py3)
                                             (string-append
                                              "-DUSER_CACHE_DIR=" cache))
                                       extra-args
                                       (list (string-append zbase
                                              "/samples/basic/blinky")))))
                      (invoke "ninja" "-C" bdir)
                      (copy-artifacts label bdir
                                      '("zephyr.elf" "zephyr.bin" "zephyr.hex"
                                        "zephyr.uf2")))))

                (define (build-native label board)
                  (let ((bdir (string-append (getcwd) "/build-" label)))
                    (when (file-exists? bdir)
                      (delete-file-recursively bdir))
                    (unsetenv "CROSS_COMPILE")
                    (setenv "ZEPHYR_TOOLCHAIN_VARIANT" "host")
                    (unsetenv "TOOLCHAIN_HOME")
                    ;; Restore host include paths (unset by build-cross)
                    (when orig-c-include-path
                      (setenv "C_INCLUDE_PATH" orig-c-include-path))
                    (when orig-cplus-include-path
                      (setenv "CPLUS_INCLUDE_PATH" orig-cplus-include-path))
                    (unsetenv "CPATH")
                    (pre-generate-modules bdir)
                    (invoke "cmake"
                            "-B"
                            bdir
                            "-GNinja"
                            (string-append "-DBOARD=" board)
                            (string-append "-DPython3_EXECUTABLE=" py3)
                            (string-append "-DUSER_CACHE_DIR=" cache)
                            (string-append zbase "/samples/basic/blinky"))
                    (invoke "ninja" "-C" bdir)
                    (copy-artifacts label bdir
                                    '("zephyr.elf"))))

                ;; RP2350 hazard3 (RISC-V) variant is missing the common
                ;; LED include in Zephyr 4.4.2; supply it via overlay.
                (define hazard3-overlay
                  (string-append (getcwd) "/hazard3-led.overlay"))
                (call-with-output-file hazard3-overlay
                  (lambda (port)
                    (format port "/ {
	leds {
		compatible = \"gpio-leds\";
		led0: led_0 {
			gpios = <&gpio0 25 GPIO_ACTIVE_HIGH>;
			label = \"LED\";
		};
	};
	aliases {
		led0 = &led0;
	};
};
")))
                (mkdir-p dest)
                (build-cross "rp2040" "rpi_pico" "arm-zephyr-eabi-")
                (build-cross "rp2350-arm" "rpi_pico2/rp2350a/m33"
                             "arm-zephyr-eabi-")
                (build-cross "rp2350-riscv" "rpi_pico2/rp2350a/hazard3"
                             "riscv64-zephyr-elf-" hazard3-overlay)
                (build-cross "ch32v307" "ch32v307v_evt_r1"
                             "riscv64-zephyr-elf-")
                (build-cross "rpi4b" "rpi_4b" "aarch64-zephyr-elf-")
                (build-native "native-sim" "native_sim/native/64")))))))
    (native-inputs (append (list cmake ninja dtc gperf gcc-toolchain)
                           %zephyr-python-packages
                           (list arm-zephyr-eabi-toolchain
                                 aarch64-zephyr-elf-toolchain
                                 riscv64-zephyr-elf-toolchain
                                 zephyr-source
                                 zephyr-modules-cmsis
                                 zephyr-modules-cmsis-6
                                 zephyr-modules-picolibc
                                 zephyr-modules-segger
                                 zephyr-modules-hal-rpi-pico
                                 zephyr-modules-hal-wch)))
    (home-page "https://zephyrproject.org/")
    (synopsis
     "Pre-built blinky firmware for RP2040, RP2350, CH32V307, RPi4B and native_sim")
    (description
     "Builds the Zephyr @code{blinky} sample for RP2040, RP2350 (ARM Cortex-M33
and RISC-V Hazard3), CH32V307, Raspberry Pi 4B and the native_sim architecture
during the package build phase.  The resulting @file{.elf}, @file{.bin},
@file{.hex} and @file{.uf2} files are installed under
@file{share/zephyr-prebuild/}.  This package serves as an end-to-end
verification that the toolchains and HAL modules are functional.")
    (license license:asl2.0)))

;;; ---------------------------------------------------------------------------
;;; zephyr-development-environment: convenience meta-package.
;;; ---------------------------------------------------------------------------

(define %zephyr-module-dirs
  ;; All module install directories, relative to a profile prefix.  Used
  ;; for the single ZEPHYR_MODULES search-path spec below: Guix merges
  ;; search-path entries for one spec, but specs with the same variable
  ;; and different files fields overwrite each other, so exactly one
  ;; package must export ZEPHYR_MODULES.
  '("share/zephyr-modules/cmsis" "share/zephyr-modules/cmsis_6"
    "share/zephyr-modules/picolibc" "share/zephyr-modules/segger"
    "share/zephyr-modules/hal/rpi_pico" "share/zephyr-modules/hal/wch"))

(define-public zephyr-development-environment
  (package
    (name "zephyr-development-environment")
    (version (package-version zephyr-source))
    (source
     #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:builder
      #~(mkdir (assoc-ref %outputs "out"))))
    (propagated-inputs `(("zephyr-source" ,zephyr-source)
                         ("zephyr-modules-cmsis" ,zephyr-modules-cmsis)
                         ("zephyr-modules-cmsis-6" ,zephyr-modules-cmsis-6)
                         ("zephyr-modules-picolibc" ,zephyr-modules-picolibc)
                         ("zephyr-modules-segger" ,zephyr-modules-segger)
                         ("zephyr-modules-hal-rpi-pico" ,zephyr-modules-hal-rpi-pico)
                         ("zephyr-modules-hal-wch" ,zephyr-modules-hal-wch)
                         ("zephyr-sdk" ,zephyr-sdk)
                         ("zephyr-python-deps" ,zephyr-python-deps)
                         ;; Use full git to avoid colliding with git-minimal
                         ;; propagated by other packages in the same profile.
                         ("git" ,git)
                         ("nss-certs" ,nss-certs)))
    ;; Export ZEPHYR_MODULES listing every module in the profile union.
    (native-search-paths
     (list (search-path-specification
            (variable "ZEPHYR_MODULES")
            (separator ";")
            (files %zephyr-module-dirs))))
    (home-page "https://zephyrproject.org/")
    (synopsis "Complete Zephyr development environment")
    (description
     "Convenience meta-package.  For custom setups, compose individual packages:
@example
guix shell zephyr-development-environment
@end example
See @file{docs/ZEPHYR-HOW-TO.md} in the channel repository for usage.")
    (license (list license:asl2.0 license:gpl3+))))
