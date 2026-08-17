(define-module (ebreak packages riscv-isa-manual)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages ruby-xyz)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system ruby)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

;;; Ruby gems required to build the RISC-V ISA manual with asciidoctor.

;;; The RISC-V manual needs no asciidoctor diagrams, but upstream's
;;; Makefile still loads asciidoctor-diagram.  Loading it would drag
;;; pandoc (and GHC) into the closure through ruby-tilt, so it is left
;;; out; the sources contain no diagram blocks.

;;; Guix's ruby-asciidoctor carries a reference to ruby-tilt (pulled in
;;; as a native test dependency), which in turn propagates pandoc and a
;;; full GHC toolchain into the runtime closure.  Strip it for a slim
;;; asciidoctor used only for building manuals.
(define ruby-asciidoctor-slim
  (hidden-package
   (package
    (inherit ruby-asciidoctor)
    (arguments (list #:tests? #f))
    (native-inputs '()))))

(define ruby-asciidoctor-pdf-slim
  (hidden-package
   (package
    (inherit ruby-asciidoctor-pdf)
    ;; Keep the upstream relax-dependencies phase (it loosens the
    ;; prawn-svg gemspec constraint); only drop the test suite.
    (arguments
     (substitute-keyword-arguments (package-arguments ruby-asciidoctor-pdf)
       ((#:phases phases)
        #~(modify-phases #$phases
            (delete 'check)))))
    (propagated-inputs
     (modify-inputs (package-propagated-inputs ruby-asciidoctor-pdf)
       (replace "ruby-asciidoctor" ruby-asciidoctor-slim))))))

(define-public ruby-csl
  (package
    (name "ruby-csl")
    (version "1.6.0")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "csl" version))
       (sha256
        (base32
         "0n8iqmzvvqy2b1wfr4c7yj28x4z3zgm36628y8ybl49dgnmjycrk"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f))                    ; needs rspec fixtures not in the gem
    (propagated-inputs (list ruby-namae))
    (synopsis "Ruby parser and API for CSL styles")
    (description
      "CSL is the Citation Style Language, an XML-based language to
describe the formatting of citations, notes and bibliographies.  This
library provides a Ruby parser and API for CSL styles.")
    (home-page "https://github.com/inukshuk/csl-ruby")
    (license license:bsd-2)))

(define-public ruby-csl-styles
  (package
    (name "ruby-csl-styles")
    (version "1.0.1.11")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "csl-styles" version))
       (sha256
        (base32
         "0l29qlk7i74088fpba5iqhhgiqkj7glcmc42nbmvgqysx577nag8"))))
    (build-system ruby-build-system)
    (arguments '(#:tests? #f))
    (propagated-inputs (list ruby-csl))
    (synopsis "CSL styles collection")
    (description
      "This gem ships the official Citation Style Language (CSL) style
repository for use with Ruby citation processors such as citeproc-ruby.")
    (home-page "https://github.com/inukshuk/csl-styles")
    (license license:cc-by-sa3.0)))

(define-public ruby-citeproc-ruby
  (package
    (name "ruby-citeproc-ruby")
    (version "1.1.14")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "citeproc-ruby" version))
       (sha256
        (base32
         "0a8ahyhhmdinl4kcyv51r74ipnclmfyz4zjv366dns8v49n5vkk3"))))
    (build-system ruby-build-system)
    (arguments '(#:tests? #f))
    (propagated-inputs (list ruby-citeproc ruby-csl))
    (synopsis "CiteProc processor for Ruby")
    (description
      "CiteProc-Ruby is a Citation Style Language (CSL) 1.0.2 cite
processor implementation for Ruby, used to format citations and
bibliographies.")
    (home-page "https://github.com/inukshuk/citeproc-ruby")
    (license license:bsd-2)))

(define-public ruby-asciidoctor-bibtex
  (package
    (name "ruby-asciidoctor-bibtex")
    (version "0.9.0")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "asciidoctor-bibtex" version))
       (sha256
        (base32
         "16l7s926h6cjzy4y582sf3x32l4w10klmdnphxi7p4g6d8vhb61y"))))
    (build-system ruby-build-system)
    (arguments '(#:tests? #f))
    (propagated-inputs
     (list ruby-asciidoctor-slim
           ruby-bibtex-ruby
           ruby-citeproc-ruby
           ruby-csl-styles
           ruby-latex-decode))
    (synopsis "BibTeX extension for Asciidoctor")
    (description
      "This extension for Asciidoctor allows the user to cite
references and generate a reference list from a BibTeX bibliography
file.")
     (home-page "https://github.com/asciidoctor-contrib/asciidoctor-bibtex")
    ;; Dual licensed under the Open Works License and AGPL-3; the gem
    ;; carries the Open Works License text.
    (license
     (license:non-copyleft "https://owl.apotheon.org/"
       "Open Works License 0.9.2"))))

(define-public ruby-asciidoctor-lists
  (package
    (name "ruby-asciidoctor-lists")
    (version "1.1.2")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "asciidoctor-lists" version))
       (sha256
        (base32
         "06xsz90ffyw4ppa1vsmkf3f82a1wsdaasjspi0y3jklnz9jrkn64"))))
    (build-system ruby-build-system)
    (arguments '(#:tests? #f))
    (propagated-inputs (list ruby-asciidoctor-slim))
    (synopsis "List-of macro extension for Asciidoctor")
    (description
      "This extension for Asciidoctor adds the lists:: macro which can
be used to generate lists of certain types of elements in a document,
such as all tables or figures.")
    (home-page "https://github.com/Alwinator/asciidoctor-lists")
    (license license:mpl2.0)))

(define-public ruby-asciidoctor-sail
  (package
    (name "ruby-asciidoctor-sail")
    (version "0.2")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "asciidoctor-sail" version))
       (sha256
        (base32
         "05iav5dcr2q24z2j5h6ad57hvssiyb2ys1p3pg1xszlpnffiwkjf"))))
    (build-system ruby-build-system)
    (arguments '(#:tests? #f))
    (propagated-inputs (list ruby-asciidoctor-slim))
    (synopsis "SAIL block extension for Asciidoctor")
    (description
      "This extension for Asciidoctor formats SAIL model definitions,
as used by the formal specifications of the RISC-V instruction set.")
    (home-page "https://github.com/Alasdair/asciidoctor-sail")
    (license license:expat)))

(define-public riscv-isa-manual
  (package
    (name "riscv-isa-manual")
    (version "7fa630c")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/riscv/riscv-isa-manual")
             (commit "7fa630c8536cd614fb3cbb58169481c7148155f5")
             (recursive? #t)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1vbi1l3njazz64vmc4gwd5lgnijsx8z96jj3nrknmpn0jqar4fcb"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-before 'build 'extend-gem-path
            ;; The asciidoctor-pdf wrapper resets GEM_PATH to its own
            ;; closure; make sure the extension gems are visible too.
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((vendor (lambda (dir)
                               (string-append dir "/lib/ruby/vendor_ruby")))
                     (dirs (filter directory-exists?
                                   (map vendor
                                        (map cdr inputs)))))
                (setenv "GEM_PATH"
                        (string-join (cons (or (getenv "GEM_PATH") "") dirs)
                                     ":")))))
          (replace 'build
            (lambda _
              (setenv "LANG" "C.utf8")
              ;; Reproduce the Makefile's non-container PDF rule with a
              ;; fixed release date for reproducibility.
              (invoke "asciidoctor-pdf" "--trace"
                      "-a" "compress"
                      "-a" "pdf-fontsdir=docs-resources/fonts"
                      "-a" "pdf-theme=docs-resources/themes/riscv-pdf.yml"
                      "-a" "revnumber=20260813"
                      "-a" "monthyear=August 2026"
                      "-a" "revcite=20260813-intermediate"
                      "-a" "revremark=Intermediate Release"
                      "-a" "docinfo=shared"
                      "-D" "build"
                      "-r" "asciidoctor-bibtex"
                      "-r" "asciidoctor-lists"
                      "-r" "asciidoctor-sail"
                      "-r" "./src/lib/volume-xrefs.rb"
                      "-r" "./src/lib/macros.rb"
                      "src/riscv-spec.adoc")))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((doc (string-append #$output
                                        "/share/doc/" #$name "-" #$version)))
                (mkdir-p doc)
                (install-file "build/riscv-spec.pdf" doc)
                (install-file "LICENSE" doc)))))))
    (native-inputs
     (list ruby-asciidoctor-pdf-slim
           ruby-asciidoctor-bibtex
           ruby-asciidoctor-lists
           ruby-asciidoctor-sail))
    (home-page "https://github.com/riscv/riscv-isa-manual")
    (synopsis "RISC-V instruction set manual")
    (description
      "This package provides the RISC-V Instruction Set Manual,
Volume I: Unprivileged Specification, built from source with
Asciidoctor.  The PDF is installed under @file{share/doc}.")
    (license license:cc-by-sa4.0)))
