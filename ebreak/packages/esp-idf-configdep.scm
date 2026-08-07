(define-module (ebreak packages esp-idf-configdep)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc))

(define-public esp-idf-configdep
  (package
    (name "esp-idf-configdep")
    (version "0.2.3")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/espressif/esp-idf-configdep.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0k7b6854yc4zh0n6dvxlqhgd7x9zbnyjhx4k7yz4m9g4ap4n9qa0"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                           (string-append "VERSION=" #$version)
                           "V=1")
      #:tests? #f                    ; tests need Perl prove + extra setup
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin")))
                (install-file (string-append "build/" #$name) bin)
                #t))))))
    (native-inputs
     `(("gcc" ,gcc)))
    (home-page "https://github.com/espressif/esp-idf-configdep")
    (synopsis "ESP-IDF sdkconfig dependency optimizer")
    (description
     "This small C tool wraps the ESP-IDF compiler and rewrites dependency
files so that source files depend on the specific @code{CONFIG_*} options they
actually use, rather than the monolithic @code{sdkconfig.h}.  This reduces
incremental rebuild times after @code{sdkconfig} changes.")
    (license license:asl2.0)))
