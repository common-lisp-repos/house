(in-package :house)

;;;;; A minimal, custom Trie
;;;;;;;; (It needs to allow for variables at each level, including prospective matching of the rest of a URI segment)
(defstruct trie
  (value nil)
  (map (make-hash-table :test 'equal))
  (vars (make-hash-table)))

(defun any-vars? (trie)
  (> (hash-table-count (trie-vars trie)) 0))

(defun path-var? (str)
  (and (stringp str)
       (> (length str) 0)
       (eql #\< (char str 0))))

(defun var-key (str)
  (when (path-var? str)
    (let ((pair (split-at #\= (string-upcase str))))
      (intern (string-trim "<>" (car pair)) :keyword))))

(defun var-annotation (str)
  (let ((pair (split-at #\= (string-upcase str))))
    (when (cdr pair) (read-from-string (cadr pair)))))

(defun trie-insert! (key value trie)
  (labels ((rec (key-parts trie)
             (cond ((null key-parts)
                    (setf (trie-value trie) value))
                   ((path-var? (first key-parts))
                    (next! (var-key (first key-parts)) (rest key-parts) (trie-vars trie)))
                   (t
                    (next! (first key-parts) (rest key-parts) (trie-map trie)))))
           (next! (k rest map)
             (let ((next (gethash k map)))
               (if next
                   (rec rest next)
                   (rec rest (setf (gethash k map) (make-trie)))))))
    (rec key trie)
    trie))

(defun trie-lookup (key trie)
  (labels ((rec (key-parts trie bindings)
             (if key-parts
                 (let ((next (gethash (canonical (first key-parts)) (trie-map trie))))
                   (cond (next
                          (rec (rest key-parts) next bindings))
                         ((any-vars? trie)
                          (loop for k being the hash-keys of (trie-vars trie)
                             for v being the hash-values of (trie-vars trie)
                             do (multiple-value-bind (val bindings)
                                    (rec (rest key-parts) v (cons (cons k (first key-parts)) bindings))
                                  (when val
                                    (return-from trie-lookup (values val bindings))))))
                         (t
                          nil)))
                 (values (trie-value trie) bindings)))
	   (canonical (thing)
	     (typecase thing
	       (string (string-upcase thing))
	       (t thing))))
    (rec key trie nil)))

;;;;; And using it to structure our handler table
(defclass handler-table ()
  ((handlers :initform (make-trie) :initarg :handlers :reader handlers)))

(defun empty-handler-table () (make-instance 'handler-table))

(defparameter *handler-table* (empty-handler-table))

(defun process-uri (uri)
  (etypecase uri
    (string (split-at #\/ (string-upcase uri)))
    (symbol (split-at #\/ (symbol-name uri)))))

(defun insert-handler! (method uri-string handler &key (handler-table *handler-table*))
  (trie-insert! (cons method (process-uri uri-string)) handler (handlers handler-table))
  handler-table)

(defun find-handler (method uri-string &key (handler-table *handler-table*))
  (let ((split (split-at #\/ uri-string))
	(handlers (handlers handler-table)))
    (or (trie-lookup (cons method split) handlers)
	(trie-lookup (cons :any split) handlers))))

(defmacro with-handler-table (tbl &body body)
  `(let ((*handler-table* ,tbl))
     ,@body
     *handler-table*))
