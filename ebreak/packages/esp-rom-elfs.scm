(define-module (ebreak packages esp-rom-elfs)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression))

(define-public esp-rom-elfs
  (package
    (name "esp-rom-elfs")
    (version "20241011")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/espressif/esp-rom-elfs/"
                           "releases/download/" version "/"
                           "esp-rom-elfs-" version ".tar.gz"))
       (file-name (string-append "esp-rom-elfs-" version ".tar.gz"))
       (sha256
        (base32
         "1ag9z459pgr7rmjxqfl8a6mayjiqffqmbvmzixicf8d4ch0h07wj"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (tar (string-append (assoc-ref %build-inputs "tar") "/bin/tar"))
                 (gzip (string-append (assoc-ref %build-inputs "gzip") "/bin/gzip")))
            (setenv "PATH" (string-append (dirname gzip) ":" (getenv "PATH")))
            (mkdir-p out)
            (invoke tar "-xzf" #$source "-C" out)
            #t))))
    (native-inputs
     `(("tar" ,tar)
       ("gzip" ,gzip)))
    (home-page "https://github.com/espressif/esp-rom-elfs")
    (synopsis "ESP32 ROM ELF files for debugging")
    (description
     "This package provides the ESP32 family ROM ELF files used by ESP-IDF
and OpenOCD for stack traces and debugging.  The files are shipped as upstream
release data.")
    (license license:asl2.0)))
