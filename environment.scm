;; Copyright (C) 2017, 2018  Roel Janssen

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(use-modules (guix packages)
             ((guix licenses) #:prefix license:)
             (gnu packages autotools)
             (gnu packages bioinformatics)
             (gnu packages compression)
             (gnu packages curl)
             (gnu packages gnupg)
             (gnu packages guile)
             (gnu packages guile-xyz)
             (gnu packages openldap)
             (gnu packages pkg-config)
             (gnu packages rdf)
             (gnu packages tex)
             (gnu packages tls)
             (gnu packages xml)
             (gnu packages)
             (guix build utils)
             (guix build-system gnu)
             (guix download)
             (guix git-download)
             (guix packages)
             (ice-9 format)
             (ice-9 rdelim))

(define sparqling-genomics
  (package
   (name "sparqling-genomics")
   (version "0.99.10")
   (source (origin
            (method url-fetch)
            (uri (string-append
                  "https://github.com/UMCUGenetics/sparqling-genomics/"
                  "releases/download/" version "/sparqling-genomics-"
                  version ".tar.gz"))
            (sha256
             (base32
              "114sjnm850gj63jsiqk22dc5g4pd297qigj4ggpavb20k0k7yn30"))))
   (build-system gnu-build-system)
   (arguments
    `(#:configure-flags (list (string-append
                               "--with-libldap-prefix="
                               (assoc-ref %build-inputs "openldap")))
      #:parallel-build? #f ; It breaks building the documentation.
      #:phases
      (modify-phases %standard-phases
        (add-after 'install 'wrap-executable
          (lambda* (#:key outputs #:allow-other-keys)
            (let* ((out  (assoc-ref outputs "out"))
                   (guile-load-path
                    (string-append out "/share/guile/site/2.2:"
                                   (getenv "GUILE_LOAD_PATH")))
                   (guile-load-compiled-path
                    (string-append out "/lib/guile/2.2/site-ccache:"
                                   (getenv "GUILE_LOAD_COMPILED_PATH")))
                   (web-root (string-append
                              out "/share/sparqling-genomics/web")))
              (wrap-program (string-append out "/bin/sg-web")
                `("GUILE_LOAD_PATH" ":" prefix (,guile-load-path))
                `("GUILE_LOAD_COMPILED_PATH" ":" prefix
                  (,guile-load-compiled-path))
                `("SG_WEB_ROOT" ":" prefix (,web-root)))))))))
   (native-inputs
    `(("texlive" ,texlive)
      ("pkg-config" ,pkg-config)))
   (inputs
    `(("guile" ,guile-next)
      ("htslib" ,htslib)
      ("libgcrypt" ,libgcrypt)
      ("libxml2" ,libxml2)
      ("openldap" ,openldap)
      ("raptor2" ,raptor2)
      ("xz" ,xz)
      ("zlib" ,zlib)))
   (propagated-inputs
    `(("gnutls" ,gnutls))) ; Needed to query HTTPS endpoints.
   (home-page "https://github.com/UMCUGenetics/sparqling-genomics")
   (synopsis "Tools to use SPARQL to analyze genomics data")
   (description "This package provides various tools to extract RDF triples
from genomic data formats, and a web interface to query SPARQL endpoints.")
   ;; All programs except the web interface is licensed GPLv3+.  The web
   ;; interface is licensed AGPLv3+.
   (license (list license:gpl3+ license:agpl3+))))

;; Evaluate to the complete recipe, so that the development
;; environment has everything to start from scratch.
sparqling-genomics
