(in-package :cl-user)
(defpackage codex.macro
  (:use :cl :trivial-types)
  (:import-from :common-doc
                :define-node
                :text-node
                :children
                :text)
  (:import-from :common-doc.util
                :make-meta
                :make-text)
  (:documentation "CommonDoc macros for representing documentation."))
(in-package :codex.macro)

;;; Variables

(defparameter *current-package* "common-lisp")

;;; Utilities

(defun make-class-metadata (class-name)
  "Create metadata for HTML classes."
  (make-meta
   (list
    (cons "class" (concatenate 'string
                               "codex-"
                               class-name)))))

;;; Macros in user input (Docstrings, files, etc.)

(define-node cl-ref (macro-node)
  ()
  (:tag-name "clref")
  (:documentation "A reference to a Common Lisp symbol."))

;;; Macros generated by parsing the documentation

(define-node documentation-node (common-doc.macro:macro-node)
  ((documentation-name :reader doc-name
                       :initarg :name
                       :type string
                       :documentation "The name of the operator, variable, or class.")
   (documentation-desc :reader doc-description
                       :initarg :doc
                       :type document-node
                       :documentation "The node's documentation."))
  (:documentation "Superclass for all documentation nodes."))

(define-node operator-node (documentation-node)
 ((l-list :reader operator-lambda-list
          :initarg :lambda-list
          :type (proper-list string)
          :documentation "The operator's lambda list."))
  (:documentation "The base class of functions and macros."))

(define-node function-node (operator-node)
  ()
  (:documentation "A function."))

(define-node macro-node (operator-node)
  ()
  (:documentation "A macro."))

(define-node generic-function-node (operator-node)
  ()
  (:documentation "A generic function."))

(define-node method-node (operator-node)
  ()
  (:documentation "A method."))

(define-node variable-node (documentation-node)
  ()
  (:documentation "A variable."))

(define-node slot-node (documentation-node)
  ((accessors :reader slot-accessors
              :initarg :accessors
              :initform nil
              :type (proper-list string))
   (readers :reader slot-readers
            :initarg :readers
            :initform nil
            :type (proper-list string))
   (writers :reader slot-writers
            :initarg :writers
            :initform nil
            :type (proper-list string)))
  (:documentation "A class or structure slot."))

(define-node record-node (documentation-node)
  ((slots :reader record-slots
          :initarg :slots
          :type (proper-list slot-node)
          :documentation "A list of slots.")))

(define-node struct-node (record-node)
  ()
  (:documentation "A structure."))

(define-node class-node (record-node)
  ()
  (:documentation "A class."))

;;; Macroexpansions

(defmethod expand-macro ((ref cl-ref))
  (let ((text-node (elt (children ref) 0)))
    (assert (typep text-node 'text-node))
    (let* ((symbol (text text-node))
           (colon-pos (position #\: symbol))
           (package-name (if colon-pos
                             (subseq symbol 0 colon-pos)
                             *current-package*))
           (symbol-name (if colon-pos
                            (subseq symbol (1+ colon-pos))
                            symbol)))
      (make-instance 'document-link
                     :document-reference package-name
                     :section-reference (concatenate 'string
                                                     "symbol-"
                                                     symbol-name)))))

(defun expand-operator-macro (instance class-name)
  (make-instance 'content-node
                 :metadata (make-class-metadata class-name)
                 :children
                 (list (make-text (doc-name instance)
                                  (make-class-metadata "name"))
                       (doc-description instance))))

(defmethod expand-macro ((function function-node))
  (expand-operator-macro function "function"))

(defmethod expand-macro ((macro macro-node))
  (expand-operator-macro macro "macro"))

(defmethod expand-macro ((generic-function generic-function-node))
  (expand-operator-macro generic-function "generic-function"))

(defmethod expand-macro ((method method-node))
  (expand-operator-macro method "method"))

(defmethod expand-macro ((variable variable-node))
  (make-instance 'content-node
                 :metadata (make-class-metadata "variable")
                 :children
                 (list (make-text (doc-name variable)
                                  (make-class-metadata "name"))
                       (doc-description variable))))

(defmethod expand-macro ((slot slot-node))
  (labels ((list-of-strings-to-list (strings)
             (make-instance 'unordered-list
                            :children
                            (loop for string in strings collecting
                              (make-instance 'list-item
                                             :children
                                             (list (make-text string))))))
           (make-definition (slot-name text)
             (when (slot-value slot slot-name)
               (make-instance 'definition
                              :term (make-text text)
                              :definition (list-of-strings-to-list
                                           (slot-value slot slot-name))))))
    (let* ((accessors-definition (make-definition 'accessors "Accessors"))
           (readers-definition (make-definition 'readers "Readers"))
           (writers-definition (make-definition 'writers "Writers"))
           (slot-methods (remove-if #'null (list accessors-definition
                                                 readers-definition
                                                 writers-definition)))
           (slot-methods-node (make-instance 'definition-list
                                             :metadata (make-class-metadata "slot-methods")
                                             :children slot-methods)))
      (make-instance 'content-node
                     :metadata (make-class-metadata "slot")
                     :children
                     (list (doc-description slot)
                           slot-methods-node)))))

(defun expand-record-macro (instance class-metadata)
  (make-instance 'content-node
                 :metadata (make-class-metadata class-metadata)
                 :children
                 (list (make-text (doc-name instance)
                                  (make-class-metadata "name"))
                       (doc-description instance)
                       (record-slots instance))))

(defmethod expand-macro ((struct struct-node))
  (expand-record-macro struct "struct"))

(defmethod expand-macro ((class class-node))
  (expand-record-macro class "class"))
