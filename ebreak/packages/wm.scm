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
           (commit "7cee5076c00a1a0b85091540bc4a00cee659af9d")))
     (file-name (git-file-name name version))
     (sha256
      (base32
       "127m36gdf8b8fvc2d81lgafjnkf0glrwqrzlfja8d3aqlkl9vygx"))))
   (inputs
    (list wlroots-0.19))))
