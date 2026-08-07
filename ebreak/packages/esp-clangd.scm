(define-module (ebreak packages esp-clangd)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages python)
  #:use-module (gnu packages xml)
  #:use-module (ebreak packages esp-toolchain-sources))

;;; esp-clangd is Espressif's fork of clangd with ESP-IDF-specific features.
;;; It is built from the same llvm-project source used by the upstream
;;; pre-built tarball.  Only the clangd binary is produced and installed.

(define-public esp-clangd
  (package
    (name "esp-clangd")
    (version %esp-llvm-version)
    (source %esp-llvm-source)
    (build-system cmake-build-system)
    (arguments
     (list
      #:build-type "Release"
      #:tests? #f
      #:configure-flags
      #~(list "-GNinja"
              "-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra"
              "-DLLVM_TARGETS_TO_BUILD=X86;RISCV"
              "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Xtensa"
              "-DLLVM_ENABLE_ASSERTIONS=OFF"
              "-DLLVM_ENABLE_RTTI=ON"
              "-DLLVM_ENABLE_ZLIB=ON"
              "-DLLVM_ENABLE_LIBXML2=OFF"
              "-DLLVM_ENABLE_TERMINFO=OFF"
              "-DLLVM_INCLUDE_BENCHMARKS=OFF"
              "-DLLVM_INCLUDE_TESTS=OFF"
              "-DLLVM_INCLUDE_EXAMPLES=OFF"
              "-DCLANG_INCLUDE_TESTS=OFF"
              "-DCLANG_TOOLS_EXTRA_INCLUDE_TESTS=OFF"
              "-DLLVM_BUILD_TOOLS=OFF"
              "-DLLVM_INSTALL_TOOLCHAIN_ONLY=OFF"
              "-DLLVM_ENABLE_PIC=ON")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'enter-llvm-source
            (lambda _
              ;; The tarball root is llvm-project-*/; CMake expects the
              ;; top-level llvm/ directory as its source directory.
              (chdir "llvm")
              #t))
          (replace 'build
            (lambda* (#:key parallel-build? #:allow-other-keys)
              (let ((job-count (if parallel-build?
                                   (number->string (parallel-job-count))
                                   "1")))
                (invoke "ninja" "-j" job-count "clangd"))))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((out (assoc-ref outputs "out"))
                    (bindir (string-append (assoc-ref outputs "out")
                                           "/bin")))
                (mkdir-p bindir)
                (install-file "bin/clangd" bindir)
                #t))))))
    (native-inputs
     `(("python" ,python)
       ("which" ,which)
       ("ninja" ,ninja)))
    (inputs
     `(("libffi" ,libffi)
       ("zlib" ,zlib)
       ("libxml2" ,libxml2)
       ("gcc:lib" ,gcc-14 "lib")))
    (home-page "https://github.com/espressif/llvm-project")
    (synopsis "Espressif's clangd language server")
    (description
     "This package provides Espressif's fork of @command{clangd}, the LLVM
language server.  It is used by ESP-IDF for IDE integration and code
completion.")
    (license license:asl2.0)))
