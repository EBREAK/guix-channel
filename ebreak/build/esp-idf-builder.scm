;;; GNU Guix --- Functional package management for GNU
;;; Build-side helper for the esp-idf package.

(define-module (ebreak build esp-idf-builder)
  #:use-module (guix build utils)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 ftw)
  #:export (build-esp-idf))

;; Pre-built tools marked 'install: always' in ESP-IDF's tools/tools.json.
;; Each archive extracts to a top-level directory; idf_tools.py expects the
;; contents to live under $IDF_TOOLS_PATH/tools/<name>/<version>/.
(define %esp-tool-specs
  '(("xtensa-esp-elf-gdb" "17.1_20260402"
     "xtensa-esp-elf-gdb/bin")
    ("riscv32-esp-elf-gdb" "17.1_20260402"
     "riscv32-esp-elf-gdb/bin")
    ("xtensa-esp-elf" "esp-16.1.0_20260609"
     "xtensa-esp-elf/bin")
    ("riscv32-esp-elf" "esp-16.1.0_20260609"
     "riscv32-esp-elf/bin")
    ("esp32ulp-elf" "2.38_20240113"
     "esp32ulp-elf/bin")
    ("openocd-esp32" "v0.12.0-esp32-20260703"
     "openocd-esp32/bin")
    ("esp-rom-elfs" "20241011"
     "")
    ("esp-clangd" "esp-21.1.3_20260408"
     "esp-clangd/bin")
    ("esp-idf-configdep" "0.2.3"
     "esp-idf-configdep-0.2.3/bin")))

(define (elf-file? file)
  "Return #t if FILE is an ELF file."
  (let ((header (false-if-exception
                 (call-with-input-file file
                   (lambda (port)
                     (setvbuf port 'block)
                     (let ((buf (make-string 4)))
                       (read-string! buf port)
                       buf))))))
    (and (string? header)
         (string=? header (string #\x7f #\E #\L #\F)))))

(define (patch-elf file interpreter patchelf)
  "Patch ELF FILE to run on Guix.
Executables get a new interpreter; shared libraries are left untouched here
because many of the bundled tool binaries break when an rpath is injected.
Object files and other un-patchable ELF files are skipped silently."
  (when (elf-file? file)
    (format #t "patchelf: ~a~%" file)
    (catch #t
      (lambda ()
        (invoke patchelf "--set-interpreter" interpreter file))
      (lambda (key . args)
        ;; No .interp section: shared object, static binary, or object file.
        ;; Do not try to add an rpath; rely on LD_LIBRARY_PATH at runtime.
        (format #t "patchelf (skipping un-patchable file): ~a~%" file)))))

(define (extract-tool archive dest tar gzip xz)
  "Extract ARCHIVE into DEST."
  (mkdir-p dest)
  (cond
   ((string-suffix? ".tar.xz" archive)
    (invoke tar "-C" dest "-xJf" archive))
   ((string-suffix? ".tar.gz" archive)
    (invoke tar "-C" dest "-xzf" archive))
   (else
    (error "unsupported archive format:" archive))))

(define (install-python-env idf-dir wheelhouse pip python ca-certs)
  "Install the ESP-IDF Python packages from WHEELHOUSE into IDF-DIR.
idf_tools.py insists on a virtual-env style directory, so we create a fake
venv containing a symlink to the store python interpreter and put the actual
packages under its site-packages directory."
  (define python-env-dir
    (string-append idf-dir "/.espressif/python_env/idf6.2_py3.12_env"))
  (define python-bin-dir
    (string-append python-env-dir "/bin"))
  (define site-packages
    (string-append python-env-dir "/lib/python3.12/site-packages"))

  (mkdir-p python-bin-dir)
  (mkdir-p site-packages)

  ;; idf_tools.py only checks that this symlink exists.
  (symlink (string-append python "/bin/python3")
           (string-append python-bin-dir "/python"))

  ;; Create a CA bundle from nss-certs so pip's vendored requests can
  ;; initialize its SSL context without network access.
  (define ca-bundle (string-append (getenv "TMPDIR") "/ca-certificates.crt"))
  (let ((cert-dir (string-append ca-certs "/etc/ssl/certs")))
    (call-with-output-file ca-bundle
      (lambda (out)
        (for-each
         (lambda (file)
           (when (string-suffix? ".pem" file)
             (call-with-input-file (string-append cert-dir "/" file)
               (lambda (in)
                 (dump-port in out)))))
         (scandir cert-dir)))))
  (setenv "SSL_CERT_FILE" ca-bundle)

  ;; Make the target site-packages visible to pip and PEP 517 build backends
  ;; so that source distributions (esptool) can find the build tools installed
  ;; below without network access or build isolation.
  (setenv "PYTHONPATH"
          (string-append site-packages
                         (if (getenv "PYTHONPATH")
                             (string-append ":" (getenv "PYTHONPATH"))
                             "")))

  ;; Ensure build tools are available so that source distributions (notably
  ;; esptool) can be built without network access or PEP 517 build isolation.
  (invoke pip "install" "--no-index" "--no-build-isolation" "--find-links" wheelhouse
          "--target" site-packages "setuptools" "packaging" "wheel")

  ;; Install all core requirements from the local find-links index.
  (invoke pip "install" "--no-index" "--no-build-isolation" "--find-links" wheelhouse
          "--target" site-packages
          "-r" (string-append idf-dir "/tools/requirements/requirements.core.txt")))

(define (build-esp-idf source output build-inputs wheel-paths)
  "Install ESP-IDF SOURCE into OUTPUT using BUILD-INPUTS and WHEEL-PATHS."
  (define idf-dir (string-append output "/share/esp-idf"))
  (define tools-dir (string-append idf-dir "/.espressif/tools"))
  (define bin-dir (string-append output "/bin"))

  (define tar (string-append (assoc-ref build-inputs "tar") "/bin/tar"))
  (define gzip (string-append (assoc-ref build-inputs "gzip") "/bin/gzip"))
  (define xz (string-append (assoc-ref build-inputs "xz") "/bin/xz"))
  (define patchelf (string-append (assoc-ref build-inputs "patchelf") "/bin/patchelf"))
  (define pip (string-append (assoc-ref build-inputs "pip") "/bin/pip"))
  (define libc (assoc-ref build-inputs "libc"))
  (define ca-certs (assoc-ref build-inputs "ca-certs"))
  (define cmake (string-append (assoc-ref build-inputs "cmake") "/bin/cmake"))
  (define ninja (string-append (assoc-ref build-inputs "ninja") "/bin/ninja"))

  ;; Directories that contain shared libraries needed by the pre-built binaries.
  (define guix-lib-dirs
    (map (lambda (input)
           (string-append (assoc-ref build-inputs input) "/lib"))
         ;; Note: "libc" is deliberately omitted.  The pre-built binaries already
         ;; run with the Guix interpreter, and putting glibc on LD_LIBRARY_PATH
         ;; breaks helper programs invoked by idf.py that need the host libc.
         '("gcc:lib" "zlib" "expat" "mpfr" "gmp" "mpc"
           "libusb" "hidapi" "libjaylink" "eudev" "python"
           "ncurses")))

  (define interpreter
    (string-append libc "/lib/ld-linux-x86-64.so.2"))

  (define (read-idf-version)
    "Return the major.minor IDF version from tools/cmake/version.cmake."
    (call-with-input-file (string-append idf-dir "/tools/cmake/version.cmake")
      (lambda (port)
        (let loop ((line (read-line port 'concat))
                   (major #f)
                   (minor #f))
          (cond
           ((and major minor)
            (string-append major "." minor))
           ((eof-object? line)
            "6.2")
           (else
            (let ((m-major (string-match "set\\s*\\(\\s*IDF_VERSION_MAJOR\\s+([0-9]+)" line))
                  (m-minor (string-match "set\\s*\\(\\s*IDF_VERSION_MINOR\\s+([0-9]+)" line)))
              (loop (read-line port 'concat)
                    (or major (and m-major (match:substring m-major 1)))
                    (or minor (and m-minor (match:substring m-minor 1)))))))))))

  ;; tar needs gzip/xz on $PATH for -xzf/-xJf.
  (setenv "PATH" (string-append (dirname gzip) ":" (dirname xz) ":" (getenv "PATH")))

  ;; Install the ESP-IDF source tree by symlinking every top-level entry from
  ;; the (read-only) source store item.  This avoids a multi-gigabyte copy of
  ;; the repository with all recursive submodules; the tools directory below
  ;; is created as a real directory because idf.py/idf_tools.py write there.
  (mkdir-p idf-dir)
  (for-each
   (lambda (entry)
     (let ((src (string-append source "/" entry))
           (dst (string-append idf-dir "/" entry)))
       (symlink src dst)))
   (scandir source (lambda (entry) (not (member entry '("." ".."))))))

  ;; Tools that are built from source in separate Guix packages.  They are
  ;; installed under the same $IDF_TOOLS_PATH/tools/<name>/<version>/ layout
  ;; that idf_tools.py expects, but they do not need tarball extraction or
  ;; patchelf because Guix already produced a correctly-linked ELF.
  (define %esp-source-tool-binaries
    '(("esp-idf-configdep" . "bin/esp-idf-configdep")
      ("esp32ulp-elf" . "bin")
      ;; The source-built OpenOCD package contains both bin/ and
      ;; share/openocd/scripts/, so symlink the whole package root.
      ("openocd-esp32" . ".")
      ("xtensa-esp-elf-gdb" . "bin")
      ("riscv32-esp-elf-gdb" . "bin")
      ;; The GCC toolchains and clangd need their lib/ directories (and, for
      ;; Xtensa, the dynconfig shared objects) at runtime, so symlink the
      ;; whole package root.
      ("xtensa-esp-elf" . ".")
      ("riscv32-esp-elf" . ".")
      ("esp-clangd" . ".")
      ;; ROM ELF files are pure data; symlink the whole package root.
      ("esp-rom-elfs" . ".")))

  ;; Extract/install each tool into the layout expected by idf_tools.py.
  (mkdir-p tools-dir)
  (for-each
   (lambda (tool-spec)
     (let* ((name (car tool-spec))
            (version (cadr tool-spec))
            (input (assoc-ref build-inputs name))
            (dest (string-append tools-dir "/" name "/" version)))
       (cond
        ((assoc name %esp-source-tool-binaries)
         => (lambda (entry)
              (let* ((binary-rel (cdr entry))
                     (tool-rel (caddr (assoc name %esp-tool-specs)))
                     (top-dir (if (string-null? tool-rel)
                                  name
                                  (car (string-split tool-rel #\/)))))
                (cond
                 ;; Symlink the whole package root (e.g. openocd-esp32).
                 ;; For tools with an empty tool-rel (e.g. esp-rom-elfs),
                 ;; symlink the package root directly to DEST.
                 ((string=? binary-rel ".")
                  (if (string-null? tool-rel)
                      (begin
                        (mkdir-p (dirname dest))
                        (symlink input dest))
                      (let ((tool-dir (string-append dest "/" top-dir)))
                        (mkdir-p (dirname tool-dir))
                        (symlink input tool-dir))))
                 (else
                  (let* ((binary (string-append input "/" binary-rel))
                         (bin-dir (string-append dest "/" top-dir "/bin")))
                    (mkdir-p (dirname bin-dir))
                    (if (file-is-directory? binary)
                        (symlink binary bin-dir)
                        (begin
                          (mkdir-p bin-dir)
                          (symlink binary (string-append bin-dir "/" (basename binary-rel)))))))))))
        (else
         (extract-tool input dest tar gzip xz)))))
   %esp-tool-specs)

  ;; Patch every ELF executable and shared library so the FHS toolchains run on Guix.
  ;; Source-built tools are skipped because Guix already linked them correctly.
  (for-each
   (lambda (tool-spec)
     (let* ((name (car tool-spec))
            (version (cadr tool-spec))
            (tool-dir (string-append tools-dir "/" name "/" version)))
       (unless (assoc name %esp-source-tool-binaries)
         (for-each (lambda (file)
                     (patch-elf file interpreter patchelf))
                   (find-files tool-dir ".*")))))
   %esp-tool-specs)

  ;; Install the Python packages required by idf.py.
  ;; Each wheel/sdist origin was passed in as an input path; link them into a
  ;; single directory so pip can use them as a local find-links index.
  (define wheelhouse-dir (string-append (getenv "TMPDIR") "/esp-idf-wheelhouse"))
  (mkdir-p wheelhouse-dir)
  (let loop ((paths wheel-paths))
    (unless (null? paths)
      (let* ((whl (car paths))
             (base (basename whl))
             (dash (string-index base #\-))
             (canonical (if dash
                            (string-drop base (1+ dash))
                            base)))
        (symlink whl (string-append wheelhouse-dir "/" canonical))
        (loop (cdr paths)))))
  (install-python-env idf-dir wheelhouse-dir pip (assoc-ref build-inputs "python") ca-certs)

  ;; Wrapper for idf.py that sets IDF_PATH, IDF_TOOLS_PATH, PATH,
  ;; LD_LIBRARY_PATH, PYTHONPATH and the environment variables idf.py expects.
  ;; We only patch the ELF interpreter; rpath injection breaks several
  ;; Espressif toolchain binaries, so shared libraries are located through
  ;; LD_LIBRARY_PATH at runtime.

  (mkdir-p bin-dir)
  (let* ((bash-sh (string-append (assoc-ref build-inputs "bash") "/bin/sh"))
         (python (string-append (assoc-ref build-inputs "python") "/bin/python3"))
         (idf-version (read-idf-version))
         (python-env-dir (string-append idf-dir "/.espressif/python_env/idf6.2_py3.12_env"))
         (venv-python (string-append python-env-dir "/bin/python"))
         (python-site-packages (string-append python-env-dir "/lib/python3.12/site-packages"))
         (tool-bin-dirs
          (map (lambda (tool-spec)
                 (let ((name (car tool-spec))
                       (version (cadr tool-spec))
                       (rel (caddr tool-spec)))
                   (string-append tools-dir "/" name "/" version "/" rel)))
               %esp-tool-specs))
         (tool-lib-dirs
          (filter (lambda (dir) (and dir (file-exists? dir)))
                  (map (lambda (tool-spec)
                         (let ((name (car tool-spec))
                               (version (cadr tool-spec))
                               (rel (caddr tool-spec)))
                           (and (not (string-null? rel))
                                (let ((top (car (string-split rel #\/))))
                                  (string-append tools-dir "/" name "/"
                                                 version "/" top "/lib")))))
                        %esp-tool-specs)))
         (path-dirs (append tool-bin-dirs
                            (list (string-append source "/tools")
                                  (dirname cmake)
                                  (dirname ninja))))
         (ld-library-path-dirs (append guix-lib-dirs tool-lib-dirs)))
    (call-with-output-file (string-append bin-dir "/idf.py")
      (lambda (port)
        ;; Use the store bash instead of /bin/sh so the wrapper works in
        ;; build containers and other environments without a host /bin/sh.
        (format port "#!~a~%" bash-sh)
        ;; Use the original source tree for IDF_PATH so that idf.py's own
        ;; path detection matches the environment variable (no symlink mismatch
        ;; warning).  The writable .espressif directory lives in the output.
        (format port "export IDF_PATH=~a~%" source)
        (format port "export IDF_TOOLS_PATH=~a/.espressif~%" idf-dir)
        (format port "export IDF_PYTHON_ENV_PATH=~a~%" python-env-dir)
        (format port "export ESP_IDF_VERSION=~a~%" idf-version)
        (format port "export OPENOCD_SCRIPTS=~a/.espressif/tools/openocd-esp32/v0.12.0-esp32-20260703/openocd-esp32/share/openocd/scripts~%" idf-dir)
        (format port "export ESP_ROM_ELF_DIR=~a/.espressif/tools/esp-rom-elfs/20241011~%" idf-dir)
        (format port "export PATH=~a:$PATH~%" (string-join path-dirs ":"))
        (format port "export LD_LIBRARY_PATH=~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}~%" (string-join ld-library-path-dirs ":"))
        ;; XTENSA_GNU_CONFIG is set by the chip-specific wrappers installed by
        ;; the xtensa-esp-elf-toolchain meta-package; leave this variable set
        ;; to the ESP32 configuration as a sensible default for any tool that
        ;; is invoked without a chip wrapper.
        (format port "export XTENSA_GNU_CONFIG=~a/.espressif/tools/xtensa-esp-elf/esp-16.1.0_20260609/xtensa-esp-elf/lib/xtensa_esp32.so~%" idf-dir)
        (format port "export PYTHONPATH=~a${PYTHONPATH:+:$PYTHONPATH}~%" python-site-packages)
        (format port "export IDF_PYTHON_CHECK_CONSTRAINTS=no~%")
        (format port "exec ~a ~a/tools/idf.py \"$@\"~%" venv-python source)))
    (chmod (string-append bin-dir "/idf.py") #o555))

  #t)
