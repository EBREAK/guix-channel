(define-module (ebreak packages wm)
  #:use-module (gnu packages)
  #:use-module (gnu packages wm)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils))

(define-public dwl-ebreak
  (package
   (inherit dwl)
   (name "dwl-ebreak")
   (version "20260706")
   (source
    (origin
     (method git-fetch)
     (uri (git-reference
           (url "https://github.com/ebreak/dwl-ebreak")
           (commit "48af6feeb4c2e4b83183b19ce162e958f4773456")))
     (file-name (git-file-name name version))
     (sha256
      (base32
       "11icyj658w02qqijzf56ldcgx00mqwqdf0didvshjspqb98vjria"))))
   (inputs
    (list wlroots-0.19))))
