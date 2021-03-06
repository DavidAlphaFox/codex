(in-package :cl-user)
(defpackage codex.manifest
  (:use :cl)
  (:import-from :trivial-types
                :proper-list
                :property-list)
  ;; Classes
  (:export :output-format
           :html
           :single-html
           :multi-html
           :document
           :manifest)
  ;; Accessors
  (:export :output-html-template
           :output-html-template-options
           :document-title
           :document-authors
           :document-output-format
           :document-sources
           :docstring-markup-format
           :manifest-markup-format
           :manifest-systems
           :manifest-documents)
  (:export :*default-manifest-pathname*
           :parse-manifest
           :system-manifest-pathname)
  (:documentation "Parsing Codex manifest files."))
(defpackage :codex-manifest-user
  (:use :cl :codex.manifest)
  (:documentation "The package in which Codex manifests are read."))
(in-package :codex.manifest)

(defclass output-format ()
  ()
  (:documentation "The base class of all output formats."))

(defclass html (output-format)
  ((html-template :reader output-html-template
                  :initarg :template-name
                  :type keyword
                  :documentation "The name of the HTML template.")
   (template-options :reader output-html-template-options
                     :initarg :template-options
                     :initform nil
                     :type property-list
                     :documentation "A property list of template initargs."))
  (:documentation "The base class of HTML formats."))

(defclass single-html (html)
  ()
  (:documentation "Single-file HTML output."))

(defclass multi-html (html)
  ()
  (:documentation "Multi-file HTML output."))

(defclass document ()
  ((document-title :reader document-title
                   :initarg :title
                   :type string
                   :documentation "The document's title.")
   (document-authors :reader document-authors
                     :initarg :authors
                     :type (proper-list string)
                     :documentation "A list of the document's authors.")
   (output-format :reader document-output-format
                  :initarg :output-format
                  :type output-format
                  :documentation "The document's output format.")
   (document-sources :reader document-sources
                     :initarg :sources
                     :type (proper-list pathname)
                     :documentation "A list of pathnames to source files to
 build the document from."))
  (:documentation "A Codex document. Project manifests can define multiple
  documents, e.g. a manual, a tutorial, an advanced manual."))

(defclass manifest ()
  ((markup-format :reader manifest-markup-format
                  :initarg :markup-format
                  :type keyword
                  :documentation "The markup format used in docstrings.")
   (systems :reader manifest-systems
            :initarg :systems
            :type (proper-list keyword)
            :documentation "A list of systems to document.")
   (documents :reader manifest-documents
              :initarg :documents
              :type (proper-list document)
              :documentation "A list of documents."))
  (:documentation "Manifest options."))

(defun read-manifest (pathname)
  "Read a manifest file into an S-expression using the :codex-manifest-user
package."
  (uiop:with-safe-io-syntax (:package (find-package :codex-manifest-user))
    (uiop:read-file-form pathname)))

(defun parse-output-format (plist)
  "Create an instance of an output-format class from a plist."
  (let* ((format-name (getf plist :type))
         (args (alexandria:remove-from-plist plist :type))
         (class-name (cond
                       ((eq format-name :single-html)
                        'single-html)
                       ((eq format-name :multi-html)
                        'multi-html)
                       (t
                        (error 'codex.error:unsupported-output-format
                               :format-name format-name)))))
    (make-instance class-name
                   :template-name (getf plist :template)
                   :template-options (alexandria:remove-from-plist plist :template))))

(defun parse-document (document-plist)
  "Parse a manifest's document plist into a document object."
  (destructuring-bind (&key title authors output-format sources)
      document-plist
    (make-instance 'document
                   :title title
                   :authors authors
                   :output-format (parse-output-format output-format)
                   :sources sources)))

(defun parse-manifest (pathname)
  "Parse a manifest from a pathname."
  (let ((plist (read-manifest pathname)))
    (destructuring-bind (&key docstring-markup-format systems documents)
        plist
      (make-instance 'manifest
                     :markup-format docstring-markup-format
                     :systems systems
                     :documents (loop for doc in documents collecting
                                  (parse-document doc))))))

;;; Main interface

(defparameter *default-manifest-pathname*
  #p"docs/manifest.lisp"
  "The pathname of the Codex manifest in a system.")

(defun system-manifest-pathname (system-name &key manifest-path)
  "Return the absolute pathname to a system's Codex manifest. @c(manifest-path)
overrides @c(*default-manifest-pathname*) which is @c(#p\"docs/manifest.lisp\")"
  (asdf:system-relative-pathname system-name
                                 (if manifest-path manifest-path *default-manifest-pathname*)))
