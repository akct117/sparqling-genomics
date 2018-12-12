;;; Copyright © 2018  Roel Janssen <roel@gnu.org>
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

(define-module (www db connections)
  #:use-module (www util)
  #:use-module (www config)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)

  #:export (connection-add
            connection-edit
            connection-remove
            all-connections
            connection-by-name
            load-connections

            alist->connection
            connection->alist

            make-connection
            connection-name
            connection-uri
            connection-backend
            connection-username
            connection-password
            connection-is-default?
            connection?

            connection-set-as-default!
            set-connection-name!
            set-connection-username!
            set-connection-password!

            persist-connections
            default-connection))


;; CONNECTION RECORD TYPE
;; ----------------------------------------------------------------------------
(define-record-type <connection>
  (make-connection name uri backend username password is-default?)
  connection?
  (name         connection-name        set-connection-name!)
  (uri          connection-uri         set-connection-uri!)
  (backend      connection-backend     set-connection-backend!)
  (username     connection-username    set-connection-username!)
  (password     connection-password    set-connection-password!)
  (is-default?  connection-is-default? set-connection-default!))


;; ALIST->CONNECTION AND CONNECTION->ALIST
;; ----------------------------------------------------------------------------
(define (alist->connection input)
  "Turns the association list INPUT into a connection record."
  (catch #t
    (lambda _
      (let ((obj (make-connection (assoc-ref input 'name)
                                  (assoc-ref input 'uri)
                                  (assoc-ref input 'backend)
                                  (assoc-ref input 'username)
                                  (assoc-ref input 'password)
                                  (assoc-ref input 'is-default?))))
        (unless (and (string? (connection-username obj))
                     (not (string= (connection-username obj) "")))
          (set-connection-username! obj #f))
        (unless (and (string? (connection-password obj))
                     (not (string= (connection-password obj) "")))
          (set-connection-password! obj #f))
        (let ((backend (connection-backend obj)))
          (cond
           [(symbol? backend)
            (set-connection-backend! obj backend)]
           [(and (string? backend) (not (string= backend "")))
            (set-connection-backend! obj (string->symbol backend))]
           [else
            (set-connection-backend! obj 'virtuoso)]))
        obj))
    (lambda (key . args)
       #f)))

(define (connection->alist record)
  `((name        . ,(connection-name     record))
    (uri         . ,(connection-uri      record))
    (backend     . ,(connection-backend  record))
    (username    . ,(connection-username record))
    (password    . ,(connection-password record))
    (is-default? . ,(connection-is-default? record))))


;; CONNECTIONS PERSISTENCE
;; ----------------------------------------------------------------------------

(define (persistence-path username)
  (string-append (www-cache-root) "/" username "/connections.scm"))

(define (load-connections username)
  (catch #t
    (lambda _
      (let ((filename (persistence-path username)))
        (if (file-exists? filename)
          (call-with-input-file filename
            (lambda (port)
              (map alist->connection (read port))))
          '())))
    (lambda (key . args)
      #f)))

(define (persist-connections connections username)
  (let ((filename (persistence-path username)))
    (unless (file-exists? (dirname filename))
      (mkdir-p (dirname filename)))
    (call-with-output-file filename
      (lambda (port)
        ;; Before writing to the file under 'port', chmod it so that
        ;; only the user this process runs as can read its contents.
        (chmod port #o600)
        (format port ";; This file was generated by sparqling-genomics.~%")
        (format port ";; Please do not edit this file manually.~%")
        (write (map connection->alist connections) port)))))


;; CONNECTION-ADD
;; ----------------------------------------------------------------------------
(define (connection-add record connections username)
  "Adds a reference to the internal graph for the connection RECORD."
  (let ((name    (connection-name    record))
        (uri     (connection-uri     record)))
    (cond
     ((string-is-longer-than name (graph-name-max-length))
      (values #f (format #f "The connection name cannot be longer than ~a characters."
                         (graph-name-max-length))))
     ((string= name "")
      (values #f (format #f "The connection name cannot empty.")))
     ((connection-by-name (connection-name record) username)
      (values #f (format #f "There already exists a connection with this name.")))
     ((string= uri "")
      (values #f (format #f "The connection URI cannot empty.")))
     ((string-contains name " ")
      (values #f (format #f "The connection name cannot contain whitespace characters.")))
     (#t (let ((new-state (cons record connections)))
           (persist-connections
            (connection-set-as-default! record new-state) username)
           (values #t ""))))))


;; CONNECTION-EDIT
;; ----------------------------------------------------------------------------
(define (connection-edit record connections username)
  "Updates RECORD for which NAME equals the name of an existing record."
  (let ((name    (connection-name    record))
        (uri     (connection-uri     record)))
    (cond
     ((string-is-longer-than name (graph-name-max-length))
      (values #f (format #f "The connection name cannot be longer than ~a characters."
                         (graph-name-max-length))))
     ((string= name "")
      (values #f (format #f "An empty connection name is not allowed.")))
     ((not (connection-by-name name username))
      (values #f (format #f "There is no connection with this name.")))
     ((string= uri "")
      (values #f (format #f "The connection URI cannot empty.")))
     ((string-contains name " ")
      (values #f (format #f "The connection name cannot contain whitespace characters.")))
     (#t (begin
           (persist-connections
            (cons record
                  (delete #f
                    (map (lambda (connection)
                           (if (string= (connection-name connection) name)
                               #f
                               connection))
                         connections)))
            username)
           (values #t "The connection has been modified."))))))


;; CONNECTION-REMOVE
;; ----------------------------------------------------------------------------

(define (connection-remove connection connections username)
  "Removes the reference in the internal graph for CONNECTION."
  (let ((name (if (string? connection) connection (connection-name connection))))
    (persist-connections
     (filter (lambda (record)
               (not (string= (connection-name record) name)))
             connections)
     username)
    (values #t (format #f "Removed “~a”." name))))

;; CONNECTION-SET-AS-DEFAULT!
;; ----------------------------------------------------------------------------
(define (connection-set-as-default! connection connections)
  "Sets CONNECTION as the default connection."
  (let ((name (if (string? connection) connection (connection-name connection))))
    (map (lambda (record)
           (set-connection-default! record (string= (connection-name record) name))
           record)
         connections)))

;; ALL-CONNECTIONS
;; ----------------------------------------------------------------------------

(define* (all-connections username #:key (filter #f))
  "Returns a list of connection records, applying FILTER to the records."
  (let ((connections (sort (delete #f (load-connections username))
                           (lambda (first second)
                             (string<? (connection-name first)
                                       (connection-name second))))))
    (if filter
        (map filter connections)
        connections)))


;; CONNECTION-BY-NAME
;; ----------------------------------------------------------------------------

(define (connection-by-name name username)
  (let ((item (filter (lambda (connection)
                        (string= (connection-name connection) name))
                      (load-connections username))))
    (if (null? item)
        #f
        (car item))))

;; DEFAULT-CONNECTION
;; ----------------------------------------------------------------------------

(define (default-connection username)
  (let ((default (delete #f
                         (all-connections username
                                          #:filter
                                          (lambda (connection)
                                            (if (connection-is-default?
                                                 connection)
                                                connection
                                                #f))))))
    (if (> (length default) 0)
        (car default)
        #f)))
