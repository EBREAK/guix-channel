(define-module (ebreak packages vx32)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages xorg)
  #:use-module ((guix licenses) #:prefix license:))

;; vx32 is a 32-bit i386-only code base: the guest code it executes is
;; mapped into the host process at fixed 32-bit addresses, so the whole
;; program, host side included, must be built as a 32-bit executable.
;; Like wine32 in Guix, we force an i686 build environment; the
;; resulting binary runs natively on x86_64 systems.

(define %commit "9d17e4db4a1718a9a6a50c89cc9ca0af149ccd05")

(define-public vx32
  (package
    (name "vx32")
    (version (git-version "0" "0" %commit))
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/9fans/vx32/archive/"
             %commit ".tar.gz"))
       (sha256
        (base32
         "19l0c1xw8f0cpfc482i9wkzf80ba6s3y72h246knyfzl9f2mwayf"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:system "i686-linux"
      #:make-flags
      #~(list "PERL=perl"
              (string-append "prefix=" #$output)
              (string-append "BINDIR=" #$output "/bin"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-after 'unpack 'patch-pagefile-tmpdir
            ;; 9vx backs its physical memory with a file created in
            ;; /var/tmp; honor $TMPDIR instead so that it also works in
            ;; sandboxes without /var/tmp.
            (lambda _
              (substitute* "src/9vx/mmu.c"
                (("\tchar tmp\\[\\] = \"/var/tmp/9vx.pages.XXXXXX\";")
                 "\tchar *tmpdir = getenv(\"TMPDIR\");
\tchar tmp[256];

\tif(tmpdir == nil)
\t\ttmpdir = \"/var/tmp\";
\tstrcpy(tmp, tmpdir);
\tstrcat(tmp, \"/9vx.pages.XXXXXX\");"))
              ;; 9front userland creates lock files with the DMEXCL
              ;; (and DMTMP) permission bits set; the Plan 9 4th
              ;; edition devfs-posix rejects them, breaking e.g.
              ;; webcookies.  Accept the bits (exclusivity is not
              ;; enforced on the host-backed file system).
              (substitute* "src/9vx/devfs-posix.c"
                (("~\\(DMDIR\\|0777\\)")
                 "~(DMDIR|DMEXCL|0x40000000|0777)"))
              ;; Guard against cclose(nil) in the namec create-error
              ;; path, which 9front userland can provoke.
              (substitute* "src/9vx/a/chan.c"
                (("/\\* create failed \\*/\n\tcclose\\(cnew\\);")
                 "/* create failed */
\tif(cnew)
\t\tcclose(cnew);"))))
          (replace 'build
            (lambda* (#:key make-flags #:allow-other-keys)
              (apply invoke "make" "-C" "src" make-flags)))
          (replace 'check
            (lambda* (#:key #:allow-other-keys)
              ;; Smoke test: boot the kernel with the embedded root
              ;; filesystem on the console and run a few rc builtins.
              ;; The guest /bin tools are not in the minimal embedded
              ;; root, so only builtins can be exercised.
              (call-with-output-file "9vx-test.in"
                (lambda (port)
                  (display "\nbootvar=smoketest-ok\nwhatis bootvar\n" port)))
              (system "timeout 120 ./src/9vx/9vx -g -u glenda \
< 9vx-test.in > 9vx-test.out 2>&1")
              (invoke "grep" "-q" "bootvar=smoketest-ok" "9vx-test.out")))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out #$output)
                     (bin (string-append out "/bin"))
                     (man1 (string-append out "/share/man/man1"))
                     (doc (string-append out "/share/doc/" #$name "-" #$version)))
                (mkdir-p bin)
                (install-file "src/9vx/9vx" bin)
                ;; Helper scripts shipped in bin/ refer to a hardcoded
                ;; /usr/local/bin/9vx(9vxp); point them at this package.
                (for-each
                 (lambda (script)
                   (substitute* (string-append "bin/" script)
                     (("/usr/local/bin/9vx")
                      (string-append bin "/9vx"))
                     (("/usr/local/bin/9vxp")
                      (string-append bin "/9vxp"))
                     ;; Invoke 9vx(9vxp) by absolute path instead of
                     ;; relying on PATH.
                     (("exec 9vx ") (string-append "exec " bin "/9vx "))
                     (("exec 9vxp ") (string-append "exec " bin "/9vxp ")))
                   (chmod (string-append "bin/" script) #o555)
                   (install-file (string-append "bin/" script) bin))
                 '("9vxc" "9vxp" "acmevx" "rcvx" "tap"))
                (mkdir-p man1)
                (install-file "doc/9vx.1" man1)
                (mkdir-p doc)
                (install-file "doc/vx32.pdf" doc)
                (install-file "doc/vxa.pdf" doc)))))))
    (inputs (list libx11))
    (native-inputs (list perl))
    ;; The vx32 library and the 9vx kernel code are MIT licensed (the
    ;; latter by the Plan 9 Foundation, which re-licensed the Plan 9
    ;; code it is derived from).
    (supported-systems '("x86_64-linux" "i686-linux"))
    (home-page "https://github.com/9fans/vx32")
    (synopsis "Sandboxing library for untrusted x86 code, with 9vx")
    (description
      "Vx32 is a user-mode library for executing untrusted x86
instruction-set code safely and quickly within a host process.  This
package builds 9vx, a port of the Plan 9 from Bell Labs kernel that
runs as an ordinary operating-system process on top of vx32, allowing
a Plan 9 environment (for example the Acme editor) on a host system.")
    (license license:expat)))
