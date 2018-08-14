(define-module (www pages welcome)
  #:use-module (www pages)
  #:use-module (www config)
  #:use-module (www util)
  #:use-module (www db connections)
  #:use-module (www db overview)
  #:use-module (sparql driver)
  #:use-module (web response)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:export (page-welcome))

(define* (page-welcome request-path #:key (post-data ""))
  (let ((number-of-endpoints (length (all-connections))))
    (page-root-template "Overview" request-path
     `((h2 "Overview")
       (p "There " ,(if (= number-of-endpoints 1) "is " "are ")
          ,number-of-endpoints " configured endpoint"
          ,(if (= number-of-endpoints 1) "" "s") ", which contain"
          ,(if (= number-of-endpoints 1) "s" "") ":")
          (table
           (tr (th "Property")
               (th "Value"))
           (tr (td "Number of samples")
               (td ,(number-of-samples)))
           (tr (td "Number of variant calls (may contain duplicates)")
               (td ,(number-of-variant-calls))))))))
