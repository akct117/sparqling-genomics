;;; Copyright © 2016, 2017, 2018  Roel Janssen <roel@gnu.org>
;;;
;;; This program is free software: you can redistribute it and/or
;;; modify it under the terms of the GNU Affero General Public License
;;; as published by the Free Software Foundation, either version 3 of
;;; the License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Affero General Public License for more details.
;;;
;;; You should have received a copy of the GNU Affero General Public
;;; License along with this program.  If not, see
;;; <http://www.gnu.org/licenses/>.

(define-module (www requests)
  #:use-module (ice-9 getopt-long)
  #:use-module (ice-9 rdelim)
  #:use-module (rnrs bytevectors)
  #:use-module (rnrs io ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (sxml simple)
  #:use-module (fibers web server)
  #:use-module (ldap authenticate)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (www config)
  #:use-module (www db connections)
  #:use-module (www db projects)
  #:use-module (www db sessions)
  #:use-module (www pages error)
  #:use-module (www pages welcome)
  #:use-module (www pages project-samples)
  #:use-module (www pages edit-connection)
  #:use-module (www pages edit-project)
  #:use-module (www pages)
  #:use-module (www util)

  #:export (request-handler))

;; ----------------------------------------------------------------------------
;; HANDLERS
;; ----------------------------------------------------------------------------
;;
;; The way a request is handled varies upon the nature of the request.  It can
;; be as simple as serving a pre-existing file, or as complex as finding a
;; Scheme module to use for handling the request.
;;
;; In this section, the different handlers are implemented.
;;

(define (request-file-handler path)
  "This handler takes data from a file and sends that as a response."

  (define (response-content-type path)
    "This function returns the content type of a file based on its extension."
    (let ((extension (substring path (1+ (string-rindex path #\.)))))
      (cond [(string= extension "css")  '(text/css)]
            [(string= extension "js")   '(application/javascript)]
            [(string= extension "json") '(application/javascript)]
            [(string= extension "html") '(text/html)]
            [(string= extension "n3")  '(text/plain)]
            [(string= extension "png")  '(image/png)]
            [(string= extension "svg")  '(image/svg+xml)]
            [(string= extension "ico")  '(image/x-icon)]
            [(string= extension "pdf")  '(application/pdf)]
            [(string= extension "ttf")  '(application/font-sfnt)]
            [(#t '(text/plain))])))

  (let ((full-path (string-append (www-root) "/" path)))
    (if (not (file-exists? full-path))
        (values '((content-type . (text/html)))
                (with-output-to-string (lambda _ (sxml->xml (page-error-404 path)))))
        ;; Do not handle files larger than (maximum-file-size).
        ;; Please increase the file size if your server can handle it.
        (let ((file-stat (stat full-path)))
          (if (> (stat:size file-stat) (www-max-file-size))
              (values '((content-type . (text/html)))
                      (with-output-to-string
                        (lambda _ (sxml->xml (page-error-filesize path)))))
              (values `((content-type . ,(response-content-type full-path)))
                      (with-input-from-file full-path
                        (lambda _
                          (setvbuf (current-input-port) 'block)
                          (get-bytevector-all (current-input-port))))))))))

(define (request-scheme-page-handler request request-body request-path)

  (define (module-path prefix elements)
    "Returns the module path so it can be loaded."
    (append prefix (map string->symbol elements)))

  (define (resolve-module-function request-path)
    "Return FUNCTION from MODULE."
    (let* ((module (resolve-module (module-path '(www pages)
                     (string-split request-path #\/)) #:ensure #f))
           (page-symbol (symbol-append 'page-
                         (string->symbol
                          (string-replace-occurrence request-path #\/ #\-)))))
      ;; Return #f unless the 'page-symbol' exists in 'module',
      ;; in which case we return that.
      (if module
          (catch #t
            (lambda _ (module-ref module page-symbol))
            (lambda (key . args) #f))
          #f)))

  ;; Return-type handlers.
  ;; --------------------------------------------------------------------------
  (cond
   ;; The “/” page is special, because we re-route it to “welcome”.
   [(not (string-is-longer-than request-path 2))
    (values '((content-type . (text/html)))
            (call-with-output-string
              (lambda (port)
                (set-port-encoding! port "utf8")
                (format port "<!DOCTYPE html>~%")
                (sxml->xml (page-welcome "/") port))))]

   ;; Static resources can be served directly using the ‘request-file-handler’.
   ;; -------------------------------------------------------------------------
   [(string-prefix? "/static/" request-path)
    (request-file-handler request-path)]

   ;; When the URI begins with “/project-samples/”, use the project-samples
   ;; page to construct a suitable output.
   [(string-prefix? "/project-samples" request-path)
    (cond
     [(string-suffix? ".json" request-path)
      (values '((content-type . (application/javascript)))
              (call-with-output-string
                (lambda (port)
                  (set-port-encoding! port "utf8")
                  (put-string port (page-project-samples
                                    (basename request-path ".json")
                                    'json)))))]
     [(string-suffix? ".n3" request-path)
      (values '((content-type . (application/javascript)))
              (call-with-output-string
                (lambda (port)
                  (set-port-encoding! port "utf8")
                  (put-string port (page-project-samples
                                    (basename request-path ".n3")
                                    'ntriples)))))])]

   ;; The POST request of the login page is special, because it must set
   ;; a Set-Cookie HTTP header.  This is something out of the control of
   ;; the normal page functions.
   [(and (string-prefix? "/login" request-path)
         (eq? (request-method request) 'POST))
    (let ((data (post-data->alist (utf8->string request-body))))
      (if (or (and (ldap-enabled?)
                   (may-access? (ldap-uri) (ldap-organizational-unit) (ldap-domain)
                                (assoc-ref data 'username)
                                (assoc-ref data 'password)))
              (and (not (ldap-enabled?))
                   (authentication-enabled?)
                   (string= (authentication-username) (assoc-ref data 'username))
                   (string= (authentication-password) (assoc-ref data 'password))))
          (let ((session (session-by-username (assoc-ref data 'username))))
            (unless session
              (set! session (alist->session
                             `((username . ,(assoc-ref data 'username))
                               (token    . ""))))
              (session-add session))
            ;; Redirect to the “welcome” page.
            (values (build-response
                     #:code 303
                     #:headers
                     `((Location   . "/")
                       (Set-Cookie . ,(string-append
                                       "Session=" (session-token session)))))
                    (call-with-output-string
                      (lambda (port) (display "")))))
          (values '((content-type . (text/html)))
                  (call-with-output-string
                    (lambda (port)
                      (set-port-encoding! port "utf8")
                      (let* ((page-function (resolve-module-function "login"))
                             (sxml-tree     (page-function request-path
                                              #:post-data
                                              (utf8->string request-body))))
                        (catch 'wrong-type-arg
                          (lambda _
                            (when (eq? (car (car sxml-tree)) 'html)
                              (format port "<!DOCTYPE html>~%")))
                          (lambda (key . args) #f))
                        (sxml->xml sxml-tree port)))))))]

   [(string-prefix? "/logout" request-path)
    (values (build-response
                   #:code 303
                   #:headers `((Location . "/")
                               (Set-Cookie  . ,(string-append
                                                "Session=deleted; expires=Thu,"
                                                " Jan 01 1970 00:00:00 UTC;"))))
            (call-with-output-string
              (lambda (port) (display ""))))]

   ;; When the “file extension” of the request indicates JSON, treat the
   ;; returned format as ‘application/javascript’.
   [(string-suffix? ".json" request-path)
    (values '((content-type . (application/javascript)))
            (call-with-output-string
              (lambda (port)
                (set-port-encoding! port "utf8")
                (let* ((request-path (basename request-path ".json"))
                       (page-function (resolve-module-function request-path)))
                  (if page-function
                      (if (eq? (request-method request) 'POST)
                          (put-string port
                                      (page-function
                                       request-path
                                       #:post-data (utf8->string request-body)))
                          (put-string port (page-function request-path)))
                      (put-string port "[]"))))))]

   
   ;; When the URI begins with “/ontology/”, use the internal ontology viewer.
   [(string-prefix? "/ontology/" request-path)
    (values '((content-type . (text/html)))
            (call-with-output-string
              (lambda (port)
                (set-port-encoding! port "utf8")
                (format port "<!DOCTYPE html>~%")
                (sxml->xml (page-ontology-or-error-404
                            (substring request-path 10)
                            #:is-ontology? #t) port))))]

   ;; When the URI begins with “/edit-connection/”, use the edit-connection
   ;; page.
   [(string-prefix? "/edit-connection" request-path)
    (values '((content-type . (text/html)))
            (call-with-output-string
              (lambda (port)
                (set-port-encoding! port "utf8")
                (format port "<!DOCTYPE html>~%")
                (sxml->xml (if (eq? (request-method request) 'POST)
                               (page-edit-connection request-path
                                #:post-data (utf8->string request-body))
                               (page-edit-connection request-path)) port))))]

   ;; When the URI begins with “/edit-project/”, use the edit-project
   ;; page.
   [(string-prefix? "/edit-project" request-path)
    (values '((content-type . (text/html)))
            (call-with-output-string
              (lambda (port)
                (set-port-encoding! port "utf8")
                (format port "<!DOCTYPE html>~%")
                (sxml->xml (if (eq? (request-method request) 'POST)
                               (page-edit-project request-path
                                #:post-data (utf8->string request-body))
                               (page-edit-project request-path)) port))))]

   ;; All other requests can be handled as HTML responses.
   [#t
    (values '((content-type . (text/html)))
            (call-with-output-string
              (lambda (port)
                (set-port-encoding! port "utf8")
                (let* ((path          (substring request-path 1))
                       (page-function (resolve-module-function path))
                       (sxml-tree     (if page-function
                                          (if (eq? (request-method request) 'POST)
                                              (page-function request-path
                                                             #:post-data
                                                             (utf8->string request-body))
                                              (page-function request-path))
                                          (page-ontology-or-error-404
                                           request-path))))
                  (catch 'wrong-type-arg
                    (lambda _
                      (when (eq? (car (car sxml-tree)) 'html)
                        (format port "<!DOCTYPE html>~%")))
                    (lambda (key . args) #f))
                  (sxml->xml sxml-tree port)))))]))


;; ----------------------------------------------------------------------------
;; ROUTING & HANDLERS
;; ----------------------------------------------------------------------------
;;
;; Requests can have different handlers.
;; * Static objects (images, stylesheet, javascript files) have their own
;;   handler.
;; * Package pages are generated dynamically, so they have their own handler.
;; * The 'regular' Scheme pages have their own handler that resolves the
;;   module dynamically.
;;
;; Feel free to add your own handler whenever that is necessary.
;;

(define (request-handler request request-body)
  (let ((request-path (uri-path (request-uri request)))
        (headers      (request-headers request)))
    (let ((token (assoc-ref headers 'cookie)))
      (cond
       [(and (string? token)
             ;; The token starts with 'Session=', we have to strip that
             ;; off to get the actual token.
             (is-valid-session-token? (substring token 8)))
        (let* ((real-token (substring token 8))
               (username (session-username (session-by-token real-token))))
          ;; Load the user's configuration.  We do this here because the memory
          ;; at this point is local to the thread handling the HTTP request.
          (load-connections username)
          (load-projects username)
          (request-scheme-page-handler request request-body request-path))]
       [(or (string-prefix? "/login" request-path)
            (string-prefix? "/static/" request-path))
        (request-scheme-page-handler request request-body request-path)]
       [else
        (values (build-response
                 #:code 303
                 #:headers '((Location . "/login")))
                (call-with-output-string
                  (lambda (port) (display ""))))]))))
