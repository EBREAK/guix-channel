(define-module (ebreak packages esp-idf-prebuild)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages version-control)
  #:use-module (ebreak packages esp-idf))

(define %esp-prebuild-examples
  ;; Example directory (relative to ESP-IDF examples/) and the targets each
  ;; example is known to build for.  Building every example for every target
  ;; would take many hours and produce a huge closure, so this is a curated
  ;; subset.  Extend the lists below to add more pre-built images.
  ;;
  ;; Notes on component dependencies:
  ;; - hello_world has no managed components.
  ;; - station only pulls managed components for esp32p4/esp32h2, which are
  ;;   excluded here.
  ;; - bleprph depends on a local component under
  ;;   examples/bluetooth/nimble/common/nimble_peripheral_utils; it is left
  ;;   in IDF_PATH and resolved through the component manager.
  ;; - ulp_riscv/gpio has no managed components.
  '(("get-started/hello_world" ("esp32" "esp32s2" "esp32s3"
                                "esp32c3" "esp32c6" "esp32h2"))
    ("wifi/getting_started/station" ("esp32" "esp32s2" "esp32s3"
                                     "esp32c3" "esp32c6"))
    ("bluetooth/nimble/bleprph" ("esp32" "esp32s3" "esp32c3"
                                 "esp32c6" "esp32h2"))
    ("system/ulp/ulp_riscv/gpio" ("esp32s3"))))

(define-public esp-idf-prebuild
  (package
    (name "esp-idf-prebuild")
    (version "6.2.0-0.055ba9d3")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils)
                  (srfi srfi-1))
      #:builder
      #~(begin
          (use-modules (guix build utils)
                       (ice-9 match)
                       (srfi srfi-1))

          (define out (assoc-ref %outputs "out"))
          (define esp-idf (assoc-ref %build-inputs "esp-idf"))
          (define idf.py (string-append esp-idf "/bin/idf.py"))
          (define sh (string-append (assoc-ref %build-inputs "bash") "/bin/sh"))
          (define examples-src (string-append esp-idf "/share/esp-idf/examples"))
          (define prebuild-dir (string-append out "/share/esp-idf-prebuild"))
          (define build-root (string-append (getenv "TMPDIR") "/esp-prebuild"))

          (define (example-name rel)
            "Return the leaf directory name of an example path."
            (last (string-split rel #\/)))

          (define (make-writable-recursively dir)
            "Add user-write permission to every file under DIR."
            (for-each (lambda (file)
                        (chmod file (logior #o200 (stat:mode (stat file)))))
                      (find-files dir ".*")))

          (define (prebuild-example rel targets)
            "Build REL example for every TARGETS and produce merged flash images."
            (let* ((src (string-append examples-src "/" rel))
                   (name (example-name rel)))
              (for-each
               (lambda (target)
                 (let ((work (string-append build-root "/" name "-" target))
                       (target-dir (string-append prebuild-dir "/" name "/" target)))
                   (when (file-exists? work)
                     (delete-file-recursively work))
                   (copy-recursively src work)
                   (make-writable-recursively work)
                   (format #t "=== Prebuilding ~a for ~a ===~%" name target)
                   (with-directory-excursion work
                     (invoke sh idf.py "set-target" target)
                     (invoke sh idf.py "build")
                     (invoke sh idf.py "merge-bin"
                             "--format" "raw"
                             "--pad-to-size" "4MB"
                             "-o" "FLASH_4M.bin")
                     (invoke sh idf.py "merge-bin"
                             "--format" "raw"
                             "--pad-to-size" "8MB"
                             "-o" "FLASH_8M.bin")
                     (mkdir-p target-dir)
                     ;; idf.py merge-bin writes the output into the build directory.
                     (invoke "gzip" "-k" "-f" "build/FLASH_4M.bin")
                     (invoke "gzip" "-k" "-f" "build/FLASH_8M.bin")
                     (copy-file "build/FLASH_4M.bin.gz" (string-append target-dir "/FLASH_4M.bin.gz"))
                     (copy-file "build/FLASH_8M.bin.gz" (string-append target-dir "/FLASH_8M.bin.gz"))
                     (delete-file "build/FLASH_4M.bin.gz")
                     (delete-file "build/FLASH_8M.bin.gz"))))
               targets)))

          ;; The build container has no writable home directory; ESP-IDF's
          ;; component manager needs a cache directory under $HOME.
          (setenv "HOME" (string-append (getenv "TMPDIR") "/home"))
          (mkdir-p (getenv "HOME"))

          (setenv "PATH"
                  (string-append (assoc-ref %build-inputs "git") "/bin:"
                                 (assoc-ref %build-inputs "gzip") "/bin:"
                                 esp-idf "/bin:"
                                 (or (getenv "PATH") "")))

          (mkdir-p prebuild-dir)
          (for-each
           (lambda (entry)
             (let ((rel (car entry))
                   (targets (cadr entry)))
               (prebuild-example rel targets)))
           '#$%esp-prebuild-examples)

          #t)))
    (native-inputs
     `(;; esp-idf brings the idf.py wrapper, toolchains, Python env and source.
       ("esp-idf" ,esp-idf)
       ;; The idf.py wrapper is a /bin/sh script; /bin/sh does not exist in the
       ;; build container, so we invoke it explicitly with bash's sh.
       ("bash" ,bash)
       ;; git is used by ESP-IDF for version detection and submodule checks.
       ("git" ,git)
       ;; gzip is used to compress the merged flash images.
       ("gzip" ,gzip)))
    (home-page "https://github.com/espressif/esp-idf")
    (synopsis "Pre-built ESP-IDF example binaries")
    (description
     "This package pre-builds a curated set of ESP-IDF examples for several
chip targets and produces merged, padded flash images (4 MB and 8 MB) ready
for direct flashing.  The images are gzip-compressed and arranged under
@file{share/esp-idf-prebuild}.  Intermediate build artifacts are removed so
only the final flashable binaries are kept in the store.")
    (license license:asl2.0)))
