(define-module (ebreak services u9fs)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix least-authority)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module ((gnu services admin) #:select (log-rotation-service-type))
  #:use-module (gnu system shadow)
  #:use-module ((gnu packages admin) #:select (shadow))
  #:use-module ((ebreak packages u9fs) #:select (u9fs))
  #:autoload   (gnu build linux-container) (%namespaces)
  #:autoload   (gnu system file-systems) (file-system-mapping)
  #:use-module (srfi srfi-1)
  #:export (u9fs-service-type
            u9fs-configuration))

;;; Commentary:
;;;
;;; Serve a directory tree over 9P2000 with u9fs, intended for Plan 9
;;; machines booting a root file system over the network.  The service uses
;;; the Shepherd's inetd-style socket activation (one u9fs process per
;;; connection) and runs each process sandboxed with least-authority-wrapper
;;; as a dedicated unprivileged user -- never as root.
;;;
;;; Code:

(define-record-type* <u9fs-configuration>
  u9fs-configuration make-u9fs-configuration
  u9fs-configuration?
  (u9fs            u9fs-configuration-u9fs              ;file-like
                   (default u9fs))
  (addresses       u9fs-configuration-addresses         ;list of strings
                   (default '("0.0.0.0" "::")))
  (port            u9fs-configuration-port              ;integer
                   (default 564))
  (user            u9fs-configuration-user              ;string
                   (default "u9fs"))
  (group           u9fs-configuration-group             ;string
                   (default "u9fs"))
  (root            u9fs-configuration-root              ;string
                   (default "/srv/9p"))
  (read-only?      u9fs-configuration-read-only?        ;Boolean
                   (default #t))
  (auth            u9fs-configuration-auth              ;'none | 'rhosts | 'p9any
                   (default 'none))
  (auth-file       u9fs-configuration-auth-file         ;string | #f
                   (default #f))
  (debug?          u9fs-configuration-debug?            ;Boolean
                   (default #f))
  (log-file        u9fs-configuration-log-file          ;string
                   (default "/var/log/u9fs.log"))
  (extra-arguments u9fs-configuration-extra-arguments   ;list of strings
                   (default '())))

(define (u9fs-accounts config)
  "Return the user account and group for CONFIG."
  (list (user-group
         (name (u9fs-configuration-group config))
         (system? #t))
        (user-account
         (name (u9fs-configuration-user config))
         (group (u9fs-configuration-group config))
         (system? #t)
         (comment "u9fs 9P file server")
         (home-directory "/var/empty")
         (shell (file-append shadow "/sbin/nologin")))))

(define (u9fs-activation config)
  "Create the export root and log file of CONFIG, owned by its user."
  (with-imported-modules '((gnu build activation))
    #~(begin
        (use-modules (gnu build activation))

        (let ((root  #$(u9fs-configuration-root config))
              (log   #$(u9fs-configuration-log-file config))
              (user  (getpwnam #$(u9fs-configuration-user config))))
          (mkdir-p root)
          (chown root (passwd:uid user) (passwd:gid user))
          (mkdir-p (dirname log))
          (unless (file-exists? log)
            (close-port (open-file log "w")))
          (chown log (passwd:uid user) (passwd:gid user))))))

(define (u9fs-shepherd-services config)
  "Return a list of one <shepherd-service> for u9fs with CONFIG."
  (let* ((root       (u9fs-configuration-root config))
         (log-file   (u9fs-configuration-log-file config))
         (auth-file  (u9fs-configuration-auth-file config))
         (read-only? (u9fs-configuration-read-only? config))
         (mappings   `(,(file-system-mapping
                         (source root)
                         (target source)
                         (writable? (not read-only?)))
                       ,(file-system-mapping
                         (source log-file)
                         (target source)
                         (writable? #t))
                       ,@(if auth-file
                             (list (file-system-mapping
                                    (source auth-file)
                                    (target source)))
                             '())))
         ;; Keep the 'net namespace (the Shepherd passes us a connected
         ;; socket) but drop the 'user namespace: u9fs resolves users with
         ;; getpwnam(3) and reports owners with getpwuid(3), which requires
         ;; the host user database and real UIDs.  Without a user namespace,
         ;; creating the mount/PID/IPC/UTS namespaces needs CAP_SYS_ADMIN,
         ;; so the wrapper must be spawned as root; it drops to USER/GROUP
         ;; inside the container before executing u9fs (hence no #:user on
         ;; make-inetd-constructor below).
         (user       (u9fs-configuration-user config))
         (group      (u9fs-configuration-group config))
         (u9fs*      (least-authority-wrapper
                      (file-append (u9fs-configuration-u9fs config)
                                   "/bin/u9fs")
                      #:name "u9fs"
                      #:user user
                      #:group group
                      #:mappings mappings
                      #:namespaces (delq 'net (delq 'user %namespaces)))))
    (list
     (shepherd-service
      (provision '(u9fs))
      (requirement '(user-processes))
      (documentation "Serve a directory tree over 9P2000 to Plan 9 clients.")
      (start
       #~(make-inetd-constructor
            (list #$u9fs*
                  "-a" #$(symbol->string
                          (u9fs-configuration-auth config))
                  #$@(if auth-file
                         (list "-A" auth-file)
                         '())
                  #$@(if (u9fs-configuration-debug? config)
                         (list "-D")
                         '())
                  ;; Map every attach to the service user; this is what
                  ;; allows u9fs to run without root privileges.
                  "-u" #$(u9fs-configuration-user config)
                  "-l" #$log-file
                  #$@(u9fs-configuration-extra-arguments config)
                  #$root)
            (map (lambda (address)
                   (endpoint
                    (addrinfo:addr
                     (car (getaddrinfo
                           address
                           #$(number->string
                              (u9fs-configuration-port config)))))))
                 '#$(u9fs-configuration-addresses config))
            #:requirements '(user-processes)
            #:service-name-stem "u9fs"))
      (stop #~(make-inetd-destructor))))))

(define u9fs-service-type
  (service-type
   (name 'u9fs)
   (extensions
    (list (service-extension account-service-type
                             u9fs-accounts)
          (service-extension activation-service-type
                             u9fs-activation)
          ;; Rotate the log file; u9fs appends client-triggered messages
          ;; to it, so an unbounded log is a disk-fill DoS vector.
          (service-extension log-rotation-service-type
                             (lambda (config)
                               (list (u9fs-configuration-log-file config))))
          (service-extension shepherd-root-service-type
                             u9fs-shepherd-services)))
   (default-value (u9fs-configuration))
   (description
    "Run @command{u9fs}, a 9P2000 file server, to serve a Unix directory
tree to Plan 9 clients (including Plan 9 machines booting their root file
system over the network).  The service listens with the Shepherd's
inetd-style socket activation and spawns one @command{u9fs} process per
connection.  Each process runs in its own mount/PID/IPC/UTS namespaces as
the unprivileged @code{u9fs} user, with only the export root (read-only by
default) and the log file visible.

Security notes: with the default @code{'none} authentication clients mount
without credentials, so the service should only be exposed on trusted
networks; @code{'rhosts} and @code{'p9any} are legacy mechanisms (ruserok
and DES-based p9sk1 respectively) offered only for Plan 9 interoperability.
u9fs follows symlinks, so the export root should not contain symlinks to
absolute paths; it also must not contain device nodes, which clients can
open via @code{aname=\"device\"}.  Enable @code{debug?} only on private
instances, as it logs client-controlled data and can fill the log file.")))
