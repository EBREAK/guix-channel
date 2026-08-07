(define-module (ebreak packages esp-idf)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix monads)
  #:use-module ((guix store) #:select (%store-monad))
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-13)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages embedded)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages xml)
  #:use-module (ebreak packages esp-clangd)
  #:use-module (ebreak packages esp-gdb)
  #:use-module (ebreak packages esp-idf-configdep)
  #:use-module (ebreak packages esp-rom-elfs)
  #:use-module (ebreak packages esp32ulp-elf)
  #:use-module (ebreak packages openocd-esp32)
  #:use-module (ebreak packages riscv32-esp-elf-toolchain)
  #:use-module (ebreak packages xtensa-esp-elf-toolchain))

;; Tools required by ESP-IDF's tools/tools.json, installed under
;; $IDF_TOOLS_PATH/tools/<name>/<version>/.
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

(define %esp-tool-inputs
  `(;; GDB for Xtensa -- built from source.
    ("xtensa-esp-elf-gdb" ,xtensa-esp-elf-gdb)
    ;; GDB for RISC-V -- built from source.
    ("riscv32-esp-elf-gdb" ,riscv32-esp-elf-gdb)
    ;; GCC toolchain for Xtensa -- built from source.
    ("xtensa-esp-elf" ,xtensa-esp-elf-toolchain)
    ;; GCC toolchain for RISC-V -- built from source.
    ("riscv32-esp-elf" ,riscv32-esp-elf-toolchain)
    ;; ULP coprocessor toolchain -- built from source.
    ("esp32ulp-elf" ,esp32ulp-elf)
    ;; OpenOCD for ESP32 -- built from source.
    ("openocd-esp32" ,openocd-esp32)
    ;; ESP ROM ELFs -- packaged as a Guix data package.
    ("esp-rom-elfs" ,esp-rom-elfs)
    ;; clangd language server -- built from source.
    ("esp-clangd" ,esp-clangd)
    ;; Configuration dependency tool -- built from source instead of using the
    ;; upstream pre-built tarball.  This is the first step in moving the whole
    ;; toolchain from binary repackaging to source builds.
    ("esp-idf-configdep" ,esp-idf-configdep)))

(define git-minimal-http1
  ;; Git wrapper used by the ESP-IDF origin method.  It used to force HTTP/1.1,
  ;; but the current network reaches GitHub reliably over HTTP/2, while HTTP/1.1
  ;; hangs.  The wrapper is kept as a convenient injection point for proxy
  ;; settings and future transport tweaks.
  (package
    (name "git-minimal-http1")
    (version (package-version git-minimal))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (bin (string-append out "/bin"))
                 (wrapper (string-append bin "/git")))
            (mkdir-p bin)
            (call-with-output-file wrapper
              (lambda (port)
                (format port "#!~a~%" #+(file-append bash "/bin/sh"))
                (format port "exec ~a \"$@\"~%"
                        #+(file-append git-minimal "/bin/git"))))
            (chmod wrapper #o555)
            #t))))
    (native-inputs '())
    (inputs '())
    (home-page (package-home-page git-minimal))
    (synopsis "Git wrapper for the ESP-IDF origin method")
    (description
     "This is a thin wrapper around Git used by the @code{esp-idf} origin
method.  It provides a single place to inject transport-wide settings without
modifying the upstream @code{git-minimal} package.")
    (license (package-license git-minimal))))

(define (read-proxyrc)
  "Read proxy settings from ~/.proxyrc if it exists.
Returns a pair (HTTP-PROXY . HTTPS-PROXY), or (#f . #f) if the file is missing,
contains no proxy declarations, or the declared proxy is not reachable from
this machine.  The values are embedded into the derivation because fixed-output
builds run in a chroot without access to the user's home directory."
  (define (proxy-reachable? url)
    "Quickly test whether a http://HOST:PORT proxy is reachable."
    (and url
         (let ((m (string-match "^https?://([^:/]+):([0-9]+)" url)))
           (and m
                (let ((host (match:substring m 1))
                      (port (match:substring m 2)))
                  ;; Use bash's /dev/tcp device for a quick, portable connect test.
                  (zero? (system*
                          (or (getenv "SHELL") "/bin/bash")
                          "-c"
                          (string-append
                           "timeout 2 bash -c 'exec 3<>/dev/tcp/"
                           host "/" port "' 2>/dev/null"))))))))
  (let ((proxyrc (string-append (or (getenv "HOME") "/root") "/.proxyrc")))
    (if (file-exists? proxyrc)
        (call-with-input-file proxyrc
          (lambda (port)
            (let loop ((http #f) (https #f))
              (let ((line (read-line port 'concat)))
                (cond
                 ((eof-object? line)
                  (if (proxy-reachable? http)
                      (cons http https)
                      (begin
                        (format (current-error-port)
                                "warning: proxy ~a from ~~/.proxyrc is unreachable, ignoring~%"
                                http)
                        (cons #f #f))))
                 ((string-match "^[[:space:]]*https?[[:space:]]*_proxy[[:space:]]*=[[:space:]]*(.*)$" line)
                  => (lambda (m)
                       (let ((val (string-trim-both (match:substring m 1))))
                         ;; If the value references the earlier http_proxy
                         ;; variable, expand it using the current http value.
                         (if (string-prefix? "$http_proxy" val)
                             (loop http (or http (string-drop val (+ 1 (string-length "$http_proxy")))))
                             (loop (or http val) (or https val))))))
                 (else
                  (loop http https)))))))
        (cons #f #f))))

(define* (git-fetch-http1 ref hash-algo hash #:optional name
                          #:key (system (%current-system))
                          (guile (default-guile))
                          (git git-minimal-http1))
  "Fetch REF from GitHub using a shallow clone with retries.
The standard git-fetch method falls back to a full-history fetch, which is too
large for this repository.  We instead do a @code{--depth 1} shallow fetch of
the requested commit and initialize submodules with the same shallow filter.
Retries and @code{--progress} are used to cope with transient TLS resets and
the Guix 3600-second silence timeout.
If ~/.proxyrc exists and the declared proxy is reachable, its settings are
embedded into the builder so the isolated fixed-output derivation can use it."
  (let ((url (git-reference-url ref))
        (commit (git-reference-commit ref))
        (recursive? (git-reference-recursive? ref))
        (proxy (read-proxyrc))
        (max-retries 3))
    (mlet %store-monad ((guile-deriv (package->derivation guile system)))
      (gexp->derivation (or name "esp-idf-checkout")
        (with-imported-modules '((guix build utils))
          #~(begin
              (use-modules (guix build utils) (ice-9 threads))
              ;; Start a background heartbeat so the build is never silent for
              ;; more than a few minutes.  Guix kills fixed-output derivations
              ;; after 3600 seconds of silence, but some submodule clones can
              ;; hang quietly for long periods on this network.
              (define heartbeat-thread
                (begin-thread
                 (let loop ((n 0))
                   (sleep 60)
                   (format #t "[heartbeat] build still in progress (~a minutes elapsed)~%" (1+ n))
                   (force-output)
                   (loop (1+ n)))))
              (let ((git #+(file-append git "/bin/git"))
                    (out #$output)
                    (http-proxy #$ (car proxy))
                    (https-proxy #$ (cdr proxy)))
                (when http-proxy
                  (setenv "http_proxy" http-proxy)
                  (setenv "HTTP_PROXY" http-proxy)
                  (setenv "https_proxy" (or https-proxy http-proxy))
                  (setenv "HTTPS_PROXY" (or https-proxy http-proxy))
                  (format #t "Using proxy: ~a~%" http-proxy))
                (setenv "GIT_SSL_NO_VERIFY" "true")
                (setenv "GIT_TERMINAL_PROMPT" "0")
                (setenv "HOME" "/tmp")
                (setenv "PATH"
                        (string-join
                         (map (lambda (pkg)
                                (string-append pkg "/bin"))
                              (list #+(file-append bash)
                                    #+(file-append coreutils)
                                    #+(file-append findutils)
                                    #+(file-append gawk)
                                    #+(file-append grep)
                                    #+(file-append gzip)
                                    #+(file-append sed)
                                    #+(file-append tar)
                                    #+(file-append xz)))
                         ":"))
                (mkdir-p out)
                (with-directory-excursion out
                  (invoke git "init")
                  (invoke git "remote" "add" "origin" #$url)
                  (when http-proxy
                    (invoke git "config" "http.proxy" http-proxy)
                    (invoke git "config" "https.proxy" (or https-proxy http-proxy)))
                  (invoke git "config" "remote.origin.promisor" "true")
                  (invoke git "config" "remote.origin.partialCloneFilter" "tree:0")
                  ;; Fetch only the commit object and its tree; blobs are fetched
                  ;; on demand during checkout.  If GitHub refuses the shallow
                  ;; fetch for this commit, fall back to a full tree:0 fetch
                  ;; (still no blobs, so it stays much smaller than a full clone).
                  ;; Retries are added because transient TLS resets are common
                  ;; through this proxy.  --progress keeps stdout/stderr active
                  ;; so Guix does not kill the build for silence.
                  (let retry ((n 0))
                    (catch #t
                      (lambda ()
                        (format #t "Fetching commit ~a (attempt ~a)...~%" #$commit (1+ n))
                        (if (zero? (system* git "fetch" "--progress" "--depth" "1" "--" "origin" #$commit))
                            (format #t "Shallow fetch succeeded.~%")
                            (begin
                              (format #t "Shallow fetch failed; retrying full tree:0 fetch...~%")
                              (invoke git "fetch" "--progress" "--filter=tree:0" "--" "origin" #$commit))))
                      (lambda (key . args)
                        (if (< n #+max-retries)
                            (begin
                              (format #t "Fetch attempt ~a failed, retrying...~%" (1+ n))
                              (retry (1+ n)))
                            (apply throw key args)))))
                  (format #t "Checking out commit ~a...~%" #$commit)
                  (invoke git "checkout" "-q" #$commit)
                  (format #t "Checkout complete.~%")
                  (when #$recursive?
                    ;; Submodules are also large; fetch a single snapshot of each
                    ;; submodule to avoid silent on-demand blob transfers.
                    (let retry ((n 0))
                      (catch #t
                        (lambda ()
                          (format #t "Updating submodules (attempt ~a)...~%" (1+ n))
                          (if (zero? (system* git "submodule" "update" "--init"
                                              "--recursive" "--progress" "--jobs" "4"
                                              "--depth" "1"))
                              (format #t "Submodule update with --depth 1 succeeded.~%")
                              (begin
                                (format #t "--depth 1 submodule update failed; retrying with tree:0...~%")
                                (invoke git "submodule" "update" "--init"
                                        "--recursive" "--progress" "--jobs" "4"
                                        "--filter=tree:0"))))
                        (lambda (key . args)
                          (if (< n #+max-retries)
                              (begin
                                (format #t "Submodule update attempt ~a failed, retrying...~%" (1+ n))
                                (retry (1+ n)))
                              (apply throw key args))))))
                  ;; The contents of .git vary, so remove it for a fixed output.
                  (delete-file-recursively ".git")
                  #t))))
        #:system system
        #:guile-for-build guile-deriv
        #:local-build? #t
        #:recursive? #t
        #:hash-algo hash-algo
        #:hash hash))))

(define %esp-idf-wheels
  ;; Python wheels required by ESP-IDF's requirements.core.txt.
  ;; Each wheel is fetched directly from PyPI so the package does not depend
  ;; on a local checkout or a manually uploaded tarball.  When updating
  ;; ESP-IDF, regenerate this list from requirements.core.txt.
  (list
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/78/b6/6307fbef88d9b5ee7421e68d78a9f162e0da4900bc5f5793f6d3d0e34fb8/annotated_types-0.7.0-py3-none-any.whl") (sha256 (base32 "0lrab0f3lgvpbj79p178xd7cn6qkr2zz9w6lw3rw7fwg7asfh0hz")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/ca/9f/f1adeadf3ec4a3bd3d1d9c809bce8526ceb3b571e8dd8356c26de0dc699e/bitarray-3.9.1-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl") (sha256 (base32 "0zlqfh7gggxmg10cdamsij657cji4nf0fdankh4gc43xsqr0d2jj")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/bf/02/1a870bab76f2896d827aa4963be95e56675ffa1453e53525d13c43036edf/bitstring-4.4.0-py3-none-any.whl") (sha256 (base32 "0dy79d9skvp7w3xj5gvk6xndyahdn416zs41c1zg4gng9x94kb7y")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/e5/ca/78d423b324b8d77900030fa59c4aa9054261ef0925631cd2501dd015b7b7/boolean_py-5.0-py3-none-any.whl") (sha256 (base32 "1ng870ciri6b8b8sj21xdvng1qj92mfh8fmm8622059ish5sfa7g")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/ef/2f/c5464532e965badff2f4c4c1a3a83f5697f0d7c407ed0cda44aaa99bb451/certifi-2026.6.17-py3-none-any.whl") (sha256 (base32 "1ny33zs207f3zyag35256pa3wy1pvkfjsxnig69gblp0myxdq9r2")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/62/f2/c9522a81c32132799a1972c39f5c5f8b4c8b9f00488a23feaa6c06f07741/cffi-2.1.0-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl") (sha256 (base32 "0riszn49mg4im6193hkygdjkvn22wha53avmbaqjbrd3jb8m17qy")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/01/c4/4fa4c8b3097a11f3c5f09a35b72ed6855fb1d332469504962ab7bafcc702/charset_normalizer-3.4.9-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl") (sha256 (base32 "1z882s4nww93d3b15yyqq6ypavr23jwsybzwq7v73g7y31i6y8jy")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/fb/e2/79c688af8b210d232694e31e59da9f6ec747bae31c3f5946e4e9b98860d5/click-8.4.2-py3-none-any.whl") (sha256 (base32 "0xkv35d3qmaj0p6lsbp02vxmgnb13nlpv0b5kmdp85n86rhzdyg6")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/b2/fb/08b3f4bf05da99aba8ffea52a558758def16e8516bc75ca94ff73587e7d3/construct-2.10.70-py3-none-any.whl") (sha256 (base32 "0c6bfakf576caw5k5x0mfqcj5vahjl4idp39xhhsi8cmylgfh2y8")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/a9/3c/f3ad17eecc1a57b0ba236dc01f90e783c51f4a2f35f64777cc4f47a184b2/cryptography-49.0.0-cp311-abi3-manylinux_2_34_x86_64.whl") (sha256 (base32 "1scbz7hazn6i85dgcarfr3icwvwnlr8ahnv3538apm93qnl7viyb")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/db/d8/7c0987f7c9fcd012915edc0a8a4287af332c519fab8142340d7d98e898a5/esp_coredump-1.16.0-py3-none-any.whl") (sha256 (base32 "0lcgz17rdkp2wyy16jb9hgllhr8zkk9n5vxflwv1rxkmr5vfvcwy")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/57/c1/646665675d568796978b967700ddab69c6d444a852cfb6ce1aab5be64af2/esp_idf_diag-0.2.0-py3-none-any.whl") (sha256 (base32 "0hj6528qmrv6yyhzg2nfsiniv9f43v09hq7w4f9iw8v3ybmvh8qa")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/9f/7b/9a8e51c717dba18840bb720431638578ee7a3107c2bf130f6a82ef978faf/esp_idf_kconfig-3.12.0-py3-none-any.whl") (sha256 (base32 "0yr3sd0z58657irvcx58kmj56mf40d1ynpfy9lslqz37gs8fiqnl")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/d9/b9/00b2469308f938705d600d8b918780bb3dfbe176a58606451e5f70b79b32/esp_idf_monitor-1.9.0-py3-none-any.whl") (sha256 (base32 "1ma4k0kylb5dhlpw2m8b73x97fb0c8zacddcrmyiffwr4f6pmy44")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/36/40/9f64c3f4e046206900f65810ed95eaa168de90192b132ae5bde52c0b18b4/esp_idf_nvs_partition_gen-0.3.0-py3-none-any.whl") (sha256 (base32 "1j9swd6hbdg21payg6dv24k6mn2ny36y261f6ri5bjya72w0j707")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/df/0a/0d9117c0f1cd521e4e5f1c7e1b12fd2009ad7878ae593650e87cd67a896e/esp_idf_panic_decoder-1.5.0-py3-none-any.whl") (sha256 (base32 "1smqhnmzmkk4hbxgl5ciwbxn7a0ldd0vcicww51w7zcyp6psn4f7")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/c3/ed/3866d85f7b70baaf2cf7c107ff20b44fdf0feab7da5d54a8b92c04de0488/esp_idf_sbom-1.3.0-py3-none-any.whl") (sha256 (base32 "1wfnvwqv9s7x6yg3c7za51gbk9gn5dg39p2li40lalklkaypx32b")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/a6/0e/fa9f9ea5d7e7ef74d1c289491056e1a7267205b03dcff8eeb10c4c388dfc/esp_idf_size-2.2.1-py3-none-any.whl") (sha256 (base32 "0yflikzjk06ajw7rrz7bmry3rc9x0qihiy4g2ic75wn3i68bisxw")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/d6/75/864b7daa0e62514a7636b8e4b7fa528691cd60cbad0735be5214212ba37a/esp_pylib-1.1.2-py3-none-any.whl") (sha256 (base32 "0hx4ygag9xm9r9majsz4qi0sns6hb3l5s4x4pricdniw9xl65pc2")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/76/ac/d2016cf6b3709d0e0166f45f84bc6e2d717757b5f59020ccb34de08d1b9b/esptool-5.3.1.tar.gz") (sha256 (base32 "160xm4s206xj1jfsvvjyicv7aik983rlajjjhk20hbbadvrq2mqj")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/84/56/caad4b087a8942a3c59a0f56e9ffb055860a172dcf895236f167ad4a17a7/freertos_gdb-1.0.4-py3-none-any.whl") (sha256 (base32 "0fz5ivawh6lkrp7xmp8a5jd5cydr0yxmgjpzmxw9k39ia5fal97r")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/5f/c9/5b5f06301f261f6b1fb69d9ea79ff3ef96535a8a04f197895caab65b2409/idf_component_manager-3.1.0-py3-none-any.whl") (sha256 (base32 "0fachpqdar9x39aff35clf0gh5rshc0ilkwdah7ifgcqaifh5wqm")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/ec/c2/90ef0c58f637d7b274bcbd38328edbb5bde88b355b2fab6eeff501eab338/idf_drivers_gdb-0.1.1-py3-none-any.whl") (sha256 (base32 "0wzjac7nk5z3d9rrzxmibm5hvr7g2syc844m5crl9vzwgg2zpcxa")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/1e/5e/d4e9f1a599fb8e573b7b87160658329fbf28d19eac2718f51fc3def3aa5a/idna-3.18-py3-none-any.whl") (sha256 (base32 "18j9x2fnijkp81f9ha1rpjldlprybi7y2zgqwdaq0s0bfaz2r5bz")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/97/78/79461288da2b13ed0a13deb65c4ad1428acb674b95278fa9abf1cefe62a2/intelhex-2.3.0-py2.py3-none-any.whl") (sha256 (base32 "1d3xq0wlq2cg1z24dinwlgrbqmpxmllfjjrmc5iyq93mcljm5k47")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/0c/ec/e1db9922bceb168197a558a2b8c03a7963f1afe93517ddd3cf99f202f996/jsonref-1.1.0-py3-none-any.whl") (sha256 (base32 "1a9hxjlbyaharvncwf02ifr1s99alw3sqpcbjjzirhpn7mvwf3ar")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/af/40/791891d4c0c4dab4c5e187c17261cedc26285fd41541577f900470a45a4d/license_expression-30.4.4-py3-none-any.whl") (sha256 (base32 "197qrcxz49ia2rgd5pggrjp6aqk2cvk4r4yws94z0hfvrbyqh5s2")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/b4/de/88b3be5c31b22333b3ca2f6ff1de4e863d8fe45aaea7485f591970ec1d3e/linkify_it_py-2.1.0-py3-none-any.whl") (sha256 (base32 "0pn0hsgyip3l3n7rr4nxn30px6rsbpdm6h24vk72xfpcjhajq98d")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/b3/81/4da04ced5a082363ecfa159c010d200ecbd959ae410c10c0264a38cac0f5/markdown_it_py-4.2.0-py3-none-any.whl") (sha256 (base32 "0jhwcj9818zrpjiw6vsbsbw86387q6bysfj54r14jngy2k6vnzlz")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/a5/69/6da5581c6a7fede7dc261bf4e67d6adca4196f176b43288b55b3db395b6e/mdit_py_plugins-0.6.1-py3-none-any.whl") (sha256 (base32 "07a8qv3znznppw0z91z18c2bawqgx0fspg55nqm4f9655bxq4k11")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/b3/38/89ba8ad64ae25be8de66a6d463314cf1eb366222074cfda9ee839c56a4b4/mdurl-0.1.2-py3-none-any.whl") (sha256 (base32 "1y5qjqhmq2nm7xj6w5rrp503r7jhj7zr2qcnr6gs858nwm0ql044")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/df/b2/87e62e8c3e2f4b32e5fe99e0b86d576da1312593b39f47d8ceef365e95ed/packaging-26.2-py3-none-any.whl") (sha256 (base32 "03lqn29hcvc2ff52phpsnqn8dqnf0z47gkhm4kzhfqa4p4v55i2z")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/9a/70/875f4a23bfc4731703a5835487d0d2fb999031bd415e7d17c0ae615c18b7/pathvalidate-3.3.1-py3-none-any.whl") (sha256 (base32 "0pvkw714pvynqk51zzvcppgmppqpxqvm3yljc3wim3hzd6mvlqsj")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/7d/68/d8d58938dfb1370b266a1a729e6d77a985be23689a0496498ee17b2cbf90/platformdirs-4.11.0-py3-none-any.whl") (sha256 (base32 "0x4yf0scdgrhn2n36q451sdxkid189cqzk40zzq0mkkz5gnws31n")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/b5/70/5d8df3b09e25bce090399cf48e452d25c935ab72dad19406c77f4e828045/psutil-7.2.2-cp36-abi3-manylinux2010_x86_64.manylinux_2_12_x86_64.manylinux_2_28_x86_64.whl") (sha256 (base32 "1yf6bg578msswkw8akh1r46sjgajb7q8kfpm8hb85m1zj8pjssh7")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/70/8b/d511486697773a3b2789f248576bee892882ee87b6c2408ffc10a1588bcc/pyclang-0.7.0-py3-none-any.whl") (sha256 (base32 "14w3pcag2jaffrq82g9lnpc4hdwf3fbbzyi9dr4dzc1an0x377d1")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/0c/c3/44f3fbbfa403ea2a7c779186dc20772604442dde72947e7d01069cbe98e3/pycparser-3.0-py3-none-any.whl") (sha256 (base32 "14m9c1hjci38clwg0bvvil3ja5sjka1k2ghw9i97ssx3d50l29xp")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/fd/7b/122376b1fd3c62c1ed9dc80c931ace4844b3c55407b6fb2d199377c9736f/pydantic-2.13.4-py3-none-any.whl") (sha256 (base32 "1fls9n964p1kmg2d34xk725kqr98n4cxkabyzlv8500xwg6q58j5")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/5f/97/2aab507d3d00ca626e8e57c1eac6a79e4e5fbcc63eb99733ff55d1717f65/pydantic_core-2.46.4-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl") (sha256 (base32 "1kkwhgzxqbqca270mds1cdnb045mzrshp2na3mlb24jbn50rav4j")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/77/c1/6e422f34e569cf8e18df68d1939c81c099d2b61e4f7d9621c8a77560799c/pydantic_settings-2.14.2-py3-none-any.whl") (sha256 (base32 "0h4lki0nkl3372vp0w6mikjyyz8qsk1bq3x5bq6mbdhhg6rrf352")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/46/2a/f9697576603dae937727827505a6126a066affb227034e77e6f9068910da/pyelftools-0.33-py3-none-any.whl") (sha256 (base32 "0dh00a5nf26fywzz48h61n225ih70yg6qsj944x3gwfk8xgss5gj")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/c8/4b/71df806f4d260ddf01f9e431f5a6538a4155db3ec84a131d7e087178c591/pygdbmi-0.11.0.0-py3-none-any.whl") (sha256 (base32 "03dnrv9q9ys2dz0sm8r1c5ldi9d1bpkd23l89i22g2am3n7c5jpp")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/f4/7e/a72dd26f3b0f4f2bf1dd8923c85f7ceb43172af56d63c7383eb62b332364/pygments-2.20.0-py3-none-any.whl") (sha256 (base32 "0xh1dna5yy5lixlx97mmz3i4cfy0g9nxhsfil8iqmligsiny5ac1")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/10/bd/c038d7cc38edc1aa5bf91ab8068b63d4308c66c4c8bb3cbba7dfbc049f9c/pyparsing-3.3.2-py3-none-any.whl") (sha256 (base32 "07cid767w02ss3kfbqj0kj1jf0sg3rx28zjq24j7x3chpm4a22w5")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/07/bc/587a445451b253b285629263eb51c2d8e9bcea4fc97826266d186f96f558/pyserial-3.5-py2.py3-none-any.whl") (sha256 (base32 "1w1c5z0gxvjcl73n828pvrfwb9b7mrxyrcwz575ac71rpav1sif4")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/0b/d7/1959b9648791274998a9c3526f6d0ec8fd2233e4d4acce81bbae76b44b2a/python_dotenv-1.2.2-py3-none-any.whl") (sha256 (base32 "0ni8rfxr9rk8bn78mak47mg9mdn6wdpsxn4bidd4bpi4k9w190hx")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/8b/9d/b3589d3877982d4f2329302ef98a8026e7f4443c765c46cfecc8858c6b4b/pyyaml-6.0.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl") (sha256 (base32 "1p7wpshndnmzija51f0ab0k84m7484b58haqfznd5qndgj5c075s")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/09/19/1bb346c0e581557c88946d2bb979b2bee8992e72314cfb418b5440e383db/reedsolo-1.7.0-py3-none-any.whl") (sha256 (base32 "1g82a02ypkdv3p54s1w8amhvqyqbdhgghcprlgpf3qqy5903wsib")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/a0/f4/c67b0b3f1b9245e8d266f0f112c500d50e5b4e83cb6f3b71b6528104182a/requests-2.34.2-py3-none-any.whl") (sha256 (base32 "1q3qw83lj7q63jdr7jxm6y6miczkq034jmg466mwcfpqfb0n039a")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/e1/d5/de8f089119205a09da657ed4784c584ede8381a0ce6821212a6d4ca47054/requests_file-3.0.1-py2.py3-none-any.whl") (sha256 (base32 "18hgq5cxpnwhscf4s785pql7fc3a2izkrihaz2cdk1ir6nafpxfh")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/3f/51/d4db610ef29373b879047326cbf6fa98b6c1969d6f6dc423279de2b1be2c/requests_toolbelt-1.0.0-py2.py3-none-any.whl") (sha256 (base32 "01mxyv66hm8sv7gr56vvcfq2n9wxcdjhysbffbsgq90abxkdvkyc")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/82/3b/64d4899d73f91ba49a8c18a8ff3f0ea8f1c1d75481760df8c68ef5235bf5/rich-15.0.0-py3-none-any.whl") (sha256 (base32 "1fz0gpi4ixcnsb9pma3qkg06kw87hiqmg8krjbz77yrj8bvlxg9k")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/6d/97/a87901aef6b7e7e4a34c6dd6cc17dca8594a592ef9d9dd765fca2b7facf7/rich_click-1.9.8-py3-none-any.whl") (sha256 (base32 "14rgb8rlzjlyla8j76xcnxjwvvcn776b3asfbn1jfsbf75jki1qj")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/b8/0c/51f6841f1d84f404f92463fc2b1ba0da357ca1e3db6b7fbda26956c3b82a/ruamel_yaml-0.19.1-py3-none-any.whl") (sha256 (base32 "14vwcq6a9a9sd2biy0361rg38hw0sbznxsc1y9i0nvnzzrbjjn97")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/c9/75/aad85817266ac5285c93391711d231ca63e9ae7d42cd3ca37549e24ebe52/schema-0.7.8-py2.py3-none-any.whl") (sha256 (base32 "1qfwy9xbbhd5ma6nnivmym44jpxam3c0r1c9y8dm5nf7mmzrgg80")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/5d/40/e1e72872c6354b306daef1703549e8e83b4d43cfea356311bf722a043752/setuptools-83.0.0-py3-none-any.whl") (sha256 (base32 "1cxb36x9vw3kw76k69zd45hbzg67ihbkkfrnfgf19x121wv3rci9")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/fb/be/35261223d9416a0751cdff1c7b4a6f881387218a12d439fe22fefebc8c04/textual-8.2.8-py3-none-any.whl") (sha256 (base32 "0jiprdipbvdkkfx498dv2zynacqf3ykyy4kj8n0xkj1d83ypawr6")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/e9/3b/267f19a008d13c704dc0b044138a56239272a43531ccb05464129d0fbd01/tibs-0.5.7-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl") (sha256 (base32 "0hfsglssy7k7zwv3givapwjwdj45dynf2990fx302jv0y9zrqfz1")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/8a/2f/6e6781b31677231366cb3cf27bc8269157f6d4b03c9032865a4f5f2bbe7e/tree_sitter-0.26.0-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl") (sha256 (base32 "197sxign4sh62xkvz1i6rgpd88r5plcb1ya1yw5bpn4208xk6sss")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/e9/8c/0dfb88d726f8821d1c4c36042f092be974a800afd734307a595b8604190c/tree_sitter_c-0.24.2-cp310-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl") (sha256 (base32 "1pmffpfjf1mb170yxiz0v8iyap2qlprqw7qbpg46pkk8xdkyyhah")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/19/97/56608b2249fe206a67cd573bc93cd9896e1efb9e98bce9c163bcdc704b88/truststore-0.10.4-py3-none-any.whl") (sha256 (base32 "10frc4rvbc4wx1cxnsk6n6r5gavg3za456wmn7ilspxv3k7sxbmd")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/49/d3/b8441a820a491ddfc024b0b0cf0393375b75ea13866d9c66727e54c2fc80/typing_extensions-4.16.0-py3-none-any.whl") (sha256 (base32 "1s62f1iqvmshyfrzx76f752pmxpijx7a3bbnn70i7s3l2d4al728")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/dc/9b/47798a6c91d8bdb567fe2698fe81e0c6b7cb7ef4d13da4114b41d239f65d/typing_inspection-0.4.2-py3-none-any.whl") (sha256 (base32 "1rs52m95pbfbs31ykx2fshs6z8fahx9fsjfj3c7j5319vk5wmlaf")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/61/73/d21edf5b204d1467e06500080a50f79d49ef2b997c79123a536d4a17d97c/uc_micro_py-2.0.0-py3-none-any.whl") (sha256 (base32 "0b145gi8inv5w7zg8w4d33zqjrgag0y72xvnphwmlgpmka2s60rn")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/7f/3e/5db95bcf282c52709639744ca2a8b149baccf648e39c8cc87553df9eae0c/urllib3-2.7.0-py3-none-any.whl") (sha256 (base32 "15v84zvqw9yy7rarmjhqpir08dpiqsxp8xp3rhqrbkmipcgcid4z")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/fe/ed/f1831681fce0e3242346e5458486003c5f124ed69e5e0b847fd029db4973/websockets-16.1.1-cp312-cp312-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl") (sha256 (base32 "1ccl5jw7c3pcf6yc7q7z8yvqfdzji45yqrk57lyd79h0i8z8cqhg")))
    (origin (method url-fetch) (uri "https://files.pythonhosted.org/packages/87/1b/9e33c09813d65e248f7f773119148a612516a4bea93e9c6f545f78455b7c/wheel-0.47.0-py3-none-any.whl") (sha256 (base32 "1vgchzjq21r7rw3p3zx63iwj1xp1jgc9qjfxrvv7iyfznk5828i1")))
  ))

(define-public esp-idf
  (package
    (name "esp-idf")
    (version "6.2.0-0.055ba9d3")
    ;; Fetch ESP-IDF with recursive submodules so the full framework source,
    ;; components and examples are available without a local checkout.
    (source
     (origin
       (method git-fetch-http1)
       (uri (git-reference
             (url "https://github.com/espressif/esp-idf.git")
             (commit "055ba9d3f9c6fd9a0efacd4993a2a942972dd65d")
             (recursive? #t)))
       (file-name (git-file-name "esp-idf" version))
       (sha256
        (base32 "1rv0fm97pqa23a0knrkk3qs6z73v4y5nfwflgla36wl909bdjl4h"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      (with-imported-modules '((ebreak build esp-idf-builder))
        #~(begin
            (use-modules (ebreak build esp-idf-builder))
            (build-esp-idf #$source #$output %build-inputs (list #$@%esp-idf-wheels))))))
    (native-inputs
     `(,@%esp-tool-inputs
       ("tar" ,tar)
       ("gzip" ,gzip)
       ("xz" ,xz)
       ("patchelf" ,patchelf)
       ("pip" ,python-pip)
       ("ca-certs" ,nss-certs)
       ("bash" ,bash)))
    (inputs
     `(("libc" ,glibc)
       ("gcc:lib" ,gcc-14 "lib")
       ("zlib" ,zlib)
       ("expat" ,expat)
       ("mpfr" ,mpfr)
       ("gmp" ,gmp)
       ("mpc" ,mpc)
       ("libusb" ,libusb)
       ("hidapi" ,hidapi)
       ("libjaylink" ,libjaylink)
       ("eudev" ,eudev)
       ("ncurses" ,ncurses)
       ("cmake" ,cmake)
       ("ninja" ,ninja)
       ("python" ,python)))
    (home-page "https://github.com/espressif/esp-idf")
    (synopsis "Espressif IoT Development Framework with toolchains")
    (description
     "This package provides the Espressif IoT Development Framework (ESP-IDF)
under @file{share/esp-idf}, including the framework source, components,
examples, documentation, and the toolchains and debug tools normally
downloaded by @command{install.sh}.  In this channel all of the bundled tools
are built from source, including the GCC toolchains for Xtensa and RISC-V and
the @command{esp-clangd} language server.  A wrapper script @command{idf.py} is
installed under @file{bin/} and sets @code{IDF_PATH}, @code{IDF_TOOLS_PATH},
and the required @code{PATH} entries.")
    (license license:asl2.0)))
