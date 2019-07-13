#lang racket/base

(require db
         deta
         deta/private/meta
         racket/match
         racket/string
         rackunit)

(provide
 crud-tests)

(define current-conn
  (make-parameter #f))

(define-schema crud-user
  ([id id/f #:primary-key #:auto-increment]
   [username string/f #:unique #:wrapper string-downcase]
   [password-hash string/f #:nullable]))

(define crud-tests
  (test-suite
   "crud"
   #:before
   (lambda ()
     (drop-table! (current-conn) 'crud-user)
     (create-table! (current-conn) 'crud-user))

   (test-suite
    "insert!"

    (test-case "persists entities"
      (define u (make-crud-user #:username "bogdan@example.com"))
      (check-eq? (meta-state (entity-meta u)) 'created)

      (define u* (car (insert! (current-conn) u)))
      (check-eq? (meta-state (entity-meta u*)) 'persisted)
      (check-not-eq? (crud-user-id u*) sql-null)

      (test-case "changing a persistent entity updates its meta state"
        (define u** (set-crud-user-username u* "jim@example.com"))
        (check-eq? (meta-state (entity-meta u**)) 'changed))))

   (test-suite
    "delete!"

    (test-case "does nothing to entities that haven't been persisted"
      (define u (make-crud-user #:username "bogdan@example.com"))
      (check-equal? (delete! (current-conn) u) null))

    (test-case "deletes persisted entities"
      (define u (make-crud-user #:username "will-delete@example.com"))
      (match-define (list u*)  (insert! (current-conn) u))
      (match-define (list u**) (delete! (current-conn) u*))
      (check-eq? (meta-state (entity-meta u**)) 'deleted)))

   (test-suite
    "query"

    (test-suite
     "from"

     (test-case "retrieves whole entities from the database"
       (define all-users
         (for/list ([u (in-rows (current-conn) (from crud-user #:as u))])
           (check-true (crud-user? u))))

       (check-true (> (length all-users) 0)))))))

(module+ test
  (require rackunit/text-ui)

  (parameterize ([current-conn (sqlite3-connect #:database 'memory)])
    (run-tests crud-tests))

  (define pg-database (getenv "DETA_POSTGRES_DB"))
  (define pg-username (getenv "DETA_POSTGRES_USER"))
  (define pg-password (getenv "DETA_POSTGRES_PASS"))
  (when pg-database
    (parameterize ([current-conn (postgresql-connect #:server   "127.0.0.1"
                                                     #:port     5432
                                                     #:database pg-database
                                                     #:user     pg-username
                                                     #:password pg-password)])
      (run-tests crud-tests))))