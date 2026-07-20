(define-module (ebreak packages u9fs)
  #:use-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define %commit "d65923fd17e8b158350d3ccd6a4e32b89b15014a")

(define-public u9fs
  (package
    (name "u9fs")
    (version (git-version "0" "0" %commit))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://bitbucket.org/plan9-from-bell-labs/u9fs")
             (commit %commit)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0h06l7ciikp3gzrr550z0fyrfp3y2067dfd3rxxw0q95z4l6vhy1"))
       ;; Hardening for serving untrusted 9P clients; see the patch headers.
       (patches (search-patches "ebreak/packages/patches/u9fs-security.patch"
                                "ebreak/packages/patches/u9fs-single-user-mode.patch"
                                "ebreak/packages/patches/u9fs-interop.patch"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f                       ;upstream has no test suite
      #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                           (string-append "LD=" #$(cc-for-target))
                           "CFLAGS=-g -O2 -I. -fstack-protector-strong -D_FORTIFY_SOURCE=2"
                           "LDFLAGS=-Wl,-z,relro,-z,now")
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin"))
                     (man (string-append out "/share/man/man4")))
                (mkdir-p bin)
                (install-file "u9fs" bin)
                (mkdir-p man)
                (install-file "u9fs.man" man)
                (rename-file (string-append man "/u9fs.man")
                             (string-append man "/u9fs.4"))
                #t))))))
    (home-page "https://bitbucket.org/plan9-from-bell-labs/u9fs")
    (synopsis "9P2000 file server for Unix")
    (description
     "u9fs is the Plan 9 user-space file server for Unix.  It speaks the
classic 9P2000 protocol and serves a Unix directory tree to Plan 9 clients,
including terminals and CPU servers booting a root file system over the
network.  It talks 9P on its standard input and output and is meant to be
run from inetd or an equivalent super-server, as root or (with @code{-u})
as a single dedicated user.  Supported authentication methods are
@code{none}, @code{rhosts}, and @code{p9any} (p9sk1).")
    (license (license:non-copyleft "file://LICENSE"))))
