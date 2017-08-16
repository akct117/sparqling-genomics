;;; Copyright © 2017 Roel Janssen <roel@gnu.org>
;;;
;;; This program is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (sparql driver)
  #:use-module (web client)
  #:export (sparql-query))

;;;
;;; SPARQL-QUERY using a POST request.
;;; ---------------------------------------------------------------------------
(define* (sparql-query query
                       #:key
                       (host "localhost")
                       (port 8890)
                       (type "text/csv"))
  (http-post (format #f "http://~a:~a/sparql" host port)
   #:body query
   #:streaming? #t
   #:headers `((user-agent . "GNU Guile")
               (content-type . (application/sparql-update))
               (accept . ((,(string->symbol type)))))))