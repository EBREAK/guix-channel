(define-module (ebreak packages gamecube-toolchain)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils))

(define %target "powerpc-gamecube-elf")

(define-public picolibc-gamecube
  (package
    (name "picolibc-gamecube")
    (version "1.8.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/picolibc/picolibc.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "16y5xgz07hrlmc8abc1vqdcf953xr4qn6jaz1z6gyf71iazgwvz5"))))
    (build-system meson-build-system)
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(list (string-append "--cross-file=" (getcwd) "/source/cross-powerpc-gamecube-elf.txt")
              "-Dmultilib=false"
              (string-append "-Dspecsdir=" #$%target "/lib")
              "-Dtests=false"
              "-Derrno-function=auto"
              (string-append "--libdir=" #$output "/" #$%target "/lib")
              (string-append "--includedir=" #$output "/" #$%target "/include"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'copy-source-and-write-cross-file
            (lambda* (#:key source #:allow-other-keys)
              (let ((cwd (getcwd)))
                ;; Copy source to a writable directory so patch-shebangs can modify it.
                (copy-recursively source "source")
                (chdir "source")
                (call-with-output-file (string-append cwd "/cross-powerpc-gamecube-elf.txt")
                  (lambda (port)
                    (display
                     (string-append
                      "[binaries]\n"
                      "c = '" #$%target "-gcc'\n"
                      "ar = '" #$%target "-ar'\n"
                      "as = '" #$%target "-as'\n"
                      "nm = '" #$%target "-nm'\n"
                      "strip = '" #$%target "-strip'\n\n"
                      "[host_machine]\n"
                      "system = 'none'\n"
                      "cpu_family = 'powerpc'\n"
                      "cpu = '750'\n"
                      "endian = 'big'\n\n"
                      "[properties]\n"
                      "skip_sanity_check = true\n"
                      "c_args = ['-mcpu=750', '-mbig-endian', '-mno-eabi']\n")
                     port)))
                #t)))
          (delete 'chdir-back-to-source))))

    (native-inputs
     `(("xbinutils" ,(cross-binutils %target))
       ("xgcc" ,(cross-gcc %target #:xgcc gcc-16))
       ("meson" ,meson)
       ("ninja" ,ninja)))
    (home-page "https://keithp.com/picolibc/")
    (synopsis "Picolibc C library for powerpc-gamecube-elf")
    (description
     "Picolibc is a C library designed for embedded systems.  This build
targets the big-endian powerpc-gamecube-elf target used by the Nintendo GameCube.")
    (license license:bsd-2)))

(define-public gcc-cross-gamecube
  (let ((base (cross-gcc %target #:xgcc gcc-16)))
    (package
      (inherit base)
      (name "gcc-cross-gamecube")
      (inputs
       `(,@(package-inputs base)
         ("picolibc" ,picolibc-gamecube)))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:configure-flags flags)
          #~(append (list "--enable-languages=c"
                          "--with-cpu=750"
                          "--with-big-endian"
                          "--with-newlib"
                          "--disable-shared"
                          "--disable-threads"
                          "--disable-libstdc++"
                          "--disable-libatomic"
                          "--disable-libmudflap"
                          "--disable-libmpx"
                          "--disable-libssp"
                          "--disable-libquadmath"
                          "--disable-libquadmath-support"
                          "--disable-__cxa-atexit"
                          "--disable-libitm"
                          "--disable-libvtv"
                          "--disable-libsanitizer"
                          "--disable-decimal-float"
                          "--disable-nls"
                          "--disable-multilib"
                          (string-append "--with-native-system-header-dir="
                                         (assoc-ref %build-inputs "picolibc")
                                         "/" #$%target "/include"))
                    (remove (lambda (flag)
                              (or (string-prefix? "--enable-languages" flag)
                                  (string-prefix? "--with-native-system-header-dir" flag)
                                  (string=? flag "--enable-shared")))
                            #$flags)))
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-before 'configure 'patch-print-sysroot-suffix
                (lambda _
                  (substitute* "gcc/config/print-sysroot-suffix.sh"
                    (("#! /bin/sh")
                     (string-append "#!" (which "sh"))))
                  #t))
              (add-after 'install 'copy-picolibc-into-gcc
                (lambda* (#:key inputs outputs #:allow-other-keys)
                  (let* ((picolibc (assoc-ref inputs "picolibc"))
                         (lib-output (assoc-ref outputs "lib"))
                         (target #$%target)
                         (lib-dir (string-append lib-output "/" target "/lib"))
                         (include-dir (string-append lib-output "/" target "/include")))
                    (mkdir-p lib-dir)
                    (mkdir-p include-dir)
                    (copy-recursively (string-append picolibc "/" target "/include")
                                      include-dir)
                    (copy-recursively (string-append picolibc "/" target "/lib")
                                      lib-dir)
                    #t))))))))))

(define-public gamecube-toolchain
  (package
    (name "gamecube-toolchain")
    (version (package-version gcc-cross-gamecube))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (bin (string-append out "/bin")))
            (mkdir-p bin)
            (for-each (lambda (input)
                        (let ((input-bin (string-append input "/bin")))
                          (when (directory-exists? input-bin)
                            (for-each (lambda (file)
                                        (let ((target (string-append bin "/" (basename file))))
                                          (unless (file-exists? target)
                                            (symlink file target))))
                                      (find-files input-bin ".*")))))
                      (map (lambda (name)
                             (assoc-ref %build-inputs name))
                           '("binutils" "gcc" "picolibc")))
            #t))))
    (propagated-inputs
     `(("binutils" ,(cross-binutils %target))
       ("gcc" ,gcc-cross-gamecube)
       ("picolibc" ,picolibc-gamecube)))
    (home-page "https://github.com/ebreak/gamecube-toolchain")
    (synopsis "Complete GNU toolchain for GameCube (powerpc-gamecube-elf)")
    (description
     "This meta-package bundles Binutils, GCC 16 and Picolibc for the
big-endian powerpc-gamecube-elf target used by the Nintendo GameCube.  It is
configured with --with-cpu=750, picolibc, no shared libraries, C language only.")
    (license license:gpl3+)))
