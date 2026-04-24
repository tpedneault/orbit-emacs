;;; mod-tcl-docs.el --- Minimal Tcl Doxygen XML browser -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'compile)
(require 'org)
(require 'subr-x)
(require 'xml)

(defgroup mod-tcl-docs nil
  "Minimal Tcl Doxygen XML browsing helpers."
  :group 'tools)

(defconst mod-tcl-docs-buffer-prefix "*tcl-docs: "
  "Prefix used for temporary Tcl documentation buffers.")

(defconst mod-tcl-docs-regenerate-buffer-name "*tcl-doxygen*"
  "Compilation buffer name for Doxygen regeneration.")

(defun mod-tcl-docs-xml-directory ()
  "Return the configured Doxygen XML directory."
  (or orbit-user-tcl-doxygen-xml-directory
      (user-error "Set orbit-user-tcl-doxygen-xml-directory in user config")))

(defun mod-tcl-docs--index-file ()
  "Return the configured Doxygen index.xml path."
  (expand-file-name "index.xml" (mod-tcl-docs-xml-directory)))

(defun mod-tcl-docs--parse-xml-file (file)
  "Parse FILE into a simple XML tree."
  (unless (file-exists-p file)
    (user-error "Doxygen XML file not found: %s" file))
  (with-temp-buffer
    (insert-file-contents file)
    (if (fboundp 'libxml-parse-xml-region)
        (libxml-parse-xml-region (point-min) (point-max))
      (car (xml-parse-region (point-min) (point-max))))))

(defun mod-tcl-docs--node-name (node)
  "Return the tag symbol for NODE."
  (and (consp node) (car node)))

(defun mod-tcl-docs--node-attributes (node)
  "Return the attribute alist for NODE."
  (and (consp node) (cadr node)))

(defun mod-tcl-docs--node-children (node)
  "Return the child nodes for NODE."
  (and (consp node) (cddr node)))

(defun mod-tcl-docs--attr (node attr)
  "Return ATTR from NODE."
  (cdr (assq attr (mod-tcl-docs--node-attributes node))))

(defun mod-tcl-docs--children-named (node name)
  "Return direct children of NODE tagged NAME."
  (cl-remove-if-not
   (lambda (child) (eq (mod-tcl-docs--node-name child) name))
   (mod-tcl-docs--node-children node)))

(defun mod-tcl-docs--child (node name)
  "Return the first direct child of NODE tagged NAME."
  (car (mod-tcl-docs--children-named node name)))

(defun mod-tcl-docs--text (node)
  "Return normalized text content for NODE."
  (when node
    (string-trim
     (replace-regexp-in-string
      "[ \t\n\r]+"
      " "
      (mapconcat
       (lambda (child)
         (cond
          ((stringp child) child)
          ((consp child) (or (mod-tcl-docs--text child) ""))
          (t "")))
       (mod-tcl-docs--node-children node)
       "")))))

(defun mod-tcl-docs--paragraph-texts (node)
  "Return paragraph texts from NODE."
  (let ((paras (mod-tcl-docs--children-named node 'para)))
    (if paras
        (delq nil
              (mapcar
               (lambda (para)
                 (let ((text (mod-tcl-docs--text para)))
                   (unless (string-empty-p text) text)))
               paras))
      (let ((text (mod-tcl-docs--text node)))
        (unless (or (null text) (string-empty-p text))
          (list text))))))

(defun mod-tcl-docs--text-except (node skip-predicate)
  "Return normalized text content for NODE, skipping matched descendants.
SKIP-PREDICATE is called with each child node; when it returns non-nil, that
child subtree is ignored."
  (when node
    (string-trim
     (replace-regexp-in-string
      "[ \t\n\r]+"
      " "
      (mapconcat
       (lambda (child)
         (cond
          ((stringp child) child)
          ((consp child)
           (unless (funcall skip-predicate child)
             (or (mod-tcl-docs--text-except child skip-predicate) "")))
          (t "")))
       (mod-tcl-docs--node-children node)
       "")))))

(defun mod-tcl-docs--paragraph-texts-except (node skip-predicate)
  "Return paragraph texts from NODE while skipping some nested structures."
  (let ((paras (mod-tcl-docs--children-named node 'para)))
    (if paras
        (delq nil
              (mapcar
               (lambda (para)
                 (let ((text (mod-tcl-docs--text-except para skip-predicate)))
                   (unless (or (null text) (string-empty-p text))
                     text)))
               paras))
      (let ((text (mod-tcl-docs--text-except node skip-predicate)))
        (unless (or (null text) (string-empty-p text))
          (list text))))))

(defun mod-tcl-docs--find-first (node predicate)
  "Return the first descendant of NODE matching PREDICATE."
  (when node
    (or (when (funcall predicate node) node)
        (cl-some (lambda (child)
                   (when (consp child)
                     (mod-tcl-docs--find-first child predicate)))
                 (mod-tcl-docs--node-children node)))))

(defun mod-tcl-docs--symbol-at-point ()
  "Return the Tcl symbol at point or signal an error."
  (or (thing-at-point 'symbol t)
      (user-error "No symbol at point")))

(defun mod-tcl-docs--lookup-variants (symbol)
  "Return ordered documentation lookup variants for SYMBOL."
  (let ((variants (list symbol)))
    (when (string-prefix-p "::" symbol)
      (push (string-remove-prefix "::" symbol) variants))
    (when (and (string-match-p "::" symbol)
               (not (string-prefix-p "::" symbol)))
      (push (concat "::" symbol) variants))
    (nreverse (cl-remove-duplicates variants :test #'equal))))

(defun mod-tcl-docs--fallback-symbol (symbol)
  "Return the unqualified fallback symbol for SYMBOL."
  (car (last (split-string symbol "::" t))))

(defun mod-tcl-docs--qualified-symbol (compound-kind compound-name member-name)
  "Return a practical Tcl-facing symbol name.
For namespace compounds, prefer a fully qualified name like
`ait::log::value' instead of the short member name `value'.  File compounds
keep the original MEMBER-NAME."
  (if (and (equal compound-kind "namespace")
           compound-name
           (not (string-empty-p compound-name)))
      (format "%s::%s" compound-name member-name)
    member-name))

(defun mod-tcl-docs--entry-candidate (entry duplicates)
  "Return a display candidate for ENTRY.
DUPLICATES is a hash table keyed by symbol names with occurrence counts."
  (let ((symbol (plist-get entry :symbol))
        (compound (plist-get entry :compound-name)))
    (if (> (gethash symbol duplicates 0) 1)
        (format "%s  [%s]" symbol compound)
      symbol)))

(defun mod-tcl-docs--collect-index-entries ()
  "Collect documentation entries from Doxygen's index.xml.

This minimal implementation assumes the Doxygen index contains `compound'
entries with nested `member' nodes, and that each member's `refid' can be
resolved inside the compound XML file named after the compound `refid'."
  (let* ((root (mod-tcl-docs--parse-xml-file (mod-tcl-docs--index-file)))
         (compounds (mod-tcl-docs--children-named root 'compound))
         entries)
    (dolist (compound compounds)
      (let ((compound-refid (mod-tcl-docs--attr compound 'refid))
            (compound-kind (mod-tcl-docs--attr compound 'kind))
            (compound-name (mod-tcl-docs--text (mod-tcl-docs--child compound 'name))))
        (dolist (member (mod-tcl-docs--children-named compound 'member))
          (let* ((member-name (mod-tcl-docs--text (mod-tcl-docs--child member 'name)))
                 (symbol (and member-name
                              (mod-tcl-docs--qualified-symbol
                               compound-kind
                               compound-name
                               member-name))))
            (when (and symbol (not (string-empty-p symbol)))
              (push (list :symbol symbol
                          :member-name member-name
                          :refid (mod-tcl-docs--attr member 'refid)
                          :kind (mod-tcl-docs--attr member 'kind)
                          :compound-refid compound-refid
                          :compound-kind compound-kind
                          :compound-name compound-name)
                    entries))))))
    (nreverse entries)))

(defun mod-tcl-docs--find-entry-by-symbol (symbol)
  "Return an index entry for SYMBOL, with conservative fallback matching."
  (let* ((entries (mod-tcl-docs--collect-index-entries))
         (variants (mod-tcl-docs--lookup-variants symbol))
         (exact (cl-loop for variant in variants
                         thereis (cl-find-if
                                  (lambda (entry)
                                    (string= (plist-get entry :symbol) variant))
                                  entries))))
    (or exact
        (let* ((fallback (mod-tcl-docs--fallback-symbol symbol))
               (matches (cl-remove-if-not
                         (lambda (entry)
                           (string= (plist-get entry :symbol) fallback))
                         entries)))
          (when (= (length matches) 1)
            (car matches))))))

(defun mod-tcl-docs--resolve-source-file (file)
  "Return a practical source path for FILE."
  (when file
    (cond
     ((file-name-absolute-p file) file)
     ((file-exists-p file) (expand-file-name file))
     (orbit-user-doxygen-config-file
      (expand-file-name file (file-name-directory orbit-user-doxygen-config-file)))
     (t
      (expand-file-name file (file-name-directory (mod-tcl-docs-xml-directory)))))))

(defun mod-tcl-docs--detail-skip-node-p (node)
  "Return non-nil when NODE should be excluded from generic details text."
  (or (eq (mod-tcl-docs--node-name node) 'parameterlist)
      (and (eq (mod-tcl-docs--node-name node) 'simplesect)
           (member (mod-tcl-docs--attr node 'kind) '("return" "retval")))))

(defun mod-tcl-docs--parameter-docs (member)
  "Extract parameter documentation from MEMBER."
  (let (parameters)
    (dolist (item (mod-tcl-docs--children-named member 'detaileddescription))
      (dolist (parameteritem
               (cl-remove-if-not
                (lambda (node) (eq (mod-tcl-docs--node-name node) 'parameteritem))
                (let (nodes)
                  (cl-labels ((walk (node)
                                (when (consp node)
                                  (push node nodes)
                                  (dolist (child (mod-tcl-docs--node-children node))
                                    (walk child)))))
                    (walk item))
                  nodes)))
        (let* ((names
                (delq nil
                      (mapcar #'mod-tcl-docs--text
                              (cl-remove-if-not
                               (lambda (node) (eq (mod-tcl-docs--node-name node) 'parametername))
                               (let (nodes)
                                 (cl-labels ((walk (node)
                                               (when (consp node)
                                                 (push node nodes)
                                                 (dolist (child (mod-tcl-docs--node-children node))
                                                   (walk child)))))
                                   (walk parameteritem))
                                 nodes)))))
               (description
                (string-join
                 (or (mod-tcl-docs--paragraph-texts
                      (mod-tcl-docs--child parameteritem 'parameterdescription))
                     '())
                 "\n\n")))
          (dolist (name names)
            (push (cons name description) parameters)))))
    (nreverse parameters)))

(defun mod-tcl-docs--return-docs (member)
  "Extract return documentation from MEMBER."
  (let (returns)
    (cl-labels ((walk (node)
                  (when (consp node)
                    (when (and (eq (mod-tcl-docs--node-name node) 'simplesect)
                               (member (mod-tcl-docs--attr node 'kind) '("return" "retval")))
                      (let ((text (string-join
                                   (or (mod-tcl-docs--paragraph-texts node) '())
                                   "\n\n")))
                        (unless (string-empty-p text)
                          (push text returns))))
                    (dolist (child (mod-tcl-docs--node-children node))
                      (walk child)))))
      (walk member))
    (nreverse returns)))

(defun mod-tcl-docs--member-node (entry)
  "Return the memberdef node matching ENTRY."
  (let* ((compound-file
          (expand-file-name
           (format "%s.xml" (plist-get entry :compound-refid))
           (mod-tcl-docs-xml-directory)))
         (root (mod-tcl-docs--parse-xml-file compound-file))
         (target-refid (plist-get entry :refid)))
    (mod-tcl-docs--find-first
     root
     (lambda (node)
       (and (eq (mod-tcl-docs--node-name node) 'memberdef)
            (equal (mod-tcl-docs--attr node 'id) target-refid))))))

(defun mod-tcl-docs--entry-doc (entry)
  "Extract a minimal documentation plist for ENTRY.

Currently supported XML structures:
- `doxygenindex/compound/member' in index.xml
- `compounddef/.../memberdef' in the referenced compound XML
- `briefdescription', `detaileddescription', `definition', `argsstring',
  `parameterlist kind=\"param\"', `simplesect kind=\"return\"', and `location'
  inside `memberdef'"
  (let* ((member (mod-tcl-docs--member-node entry))
         (location (mod-tcl-docs--child member 'location))
         (brief (string-join
                 (or (mod-tcl-docs--paragraph-texts
                      (mod-tcl-docs--child member 'briefdescription))
                     '())
                 "\n\n"))
         (details (string-join
                   (or (mod-tcl-docs--paragraph-texts-except
                        (mod-tcl-docs--child member 'detaileddescription)
                        #'mod-tcl-docs--detail-skip-node-p)
                       '())
                   "\n\n")))
    (list
     :symbol (plist-get entry :symbol)
     :kind (plist-get entry :kind)
     :compound-name (plist-get entry :compound-name)
     :definition (mod-tcl-docs--text (mod-tcl-docs--child member 'definition))
     :argsstring (mod-tcl-docs--text (mod-tcl-docs--child member 'argsstring))
     :brief brief
     :details details
     :parameters (mod-tcl-docs--parameter-docs member)
     :returns (mod-tcl-docs--return-docs member)
     :source-file (mod-tcl-docs--resolve-source-file
                   (or (mod-tcl-docs--attr location 'bodyfile)
                       (mod-tcl-docs--attr location 'file)))
     :source-line (or (mod-tcl-docs--attr location 'bodyline)
                      (mod-tcl-docs--attr location 'line)))))

(defun mod-tcl-docs--source-link (doc)
  "Return an Org source link string for DOC, or nil."
  (when-let ((file (plist-get doc :source-file)))
    (let ((line (plist-get doc :source-line)))
      (format "[[file:%s%s][%s%s]]"
              file
              (if line (format "::%s" line) "")
              (file-name-nondirectory file)
              (if line (format ":%s" line) "")))))

(defun mod-tcl-docs--render (doc)
  "Render DOC into a temporary read-only Org buffer."
  (let ((buffer (get-buffer-create
                 (format "%s%s*" mod-tcl-docs-buffer-prefix (plist-get doc :symbol)))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "* %s\n" (plist-get doc :symbol)))
        (when-let ((definition (plist-get doc :definition)))
          (insert (format "#+begin_example\n%s%s%s\n#+end_example\n\n"
                          definition
                          (if (and (plist-get doc :argsstring)
                                   (not (string-empty-p (plist-get doc :argsstring))))
                              " "
                            "")
                          (or (plist-get doc :argsstring) ""))))
        (insert (format "- Kind :: %s\n" (or (plist-get doc :kind) "unknown")))
        (insert (format "- Compound :: %s\n" (or (plist-get doc :compound-name) "unknown")))
        (when-let ((source-link (mod-tcl-docs--source-link doc)))
          (insert (format "- Source :: %s\n" source-link)))
        (insert "\n")
        (when-let ((brief (plist-get doc :brief)))
          (unless (string-empty-p brief)
            (insert "* Summary\n\n" brief "\n\n")))
        (when-let ((parameters (plist-get doc :parameters)))
          (when parameters
            (insert "* Parameters\n\n")
            (dolist (parameter parameters)
              (insert (format "- %s :: %s\n"
                              (car parameter)
                              (cdr parameter))))
            (insert "\n")))
        (when-let ((returns (plist-get doc :returns)))
          (when returns
            (insert "* Returns\n\n"
                    (string-join returns "\n\n")
                    "\n\n")))
        (when-let ((details (plist-get doc :details)))
          (unless (string-empty-p details)
            (insert "* Details\n\n" details "\n"))))
      (goto-char (point-min))
      (org-mode)
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun mod-tcl-docs-search ()
  "Search documented Tcl symbols from Doxygen XML."
  (interactive)
  (let* ((entries (mod-tcl-docs--collect-index-entries))
         (counts (make-hash-table :test #'equal)))
    (dolist (entry entries)
      (puthash (plist-get entry :symbol)
               (1+ (gethash (plist-get entry :symbol) counts 0))
               counts))
    (let* ((candidates
            (mapcar (lambda (entry)
                      (cons (mod-tcl-docs--entry-candidate entry counts) entry))
                    entries))
           (selection
            (completing-read "Tcl docs: " candidates nil t)))
      (mod-tcl-docs--render (mod-tcl-docs--entry-doc (cdr (assoc selection candidates)))))))

(defun mod-tcl-docs-at-point ()
  "Open Tcl documentation for the symbol at point."
  (interactive)
  (let* ((symbol (mod-tcl-docs--symbol-at-point))
         (entry (mod-tcl-docs--find-entry-by-symbol symbol)))
    (unless entry
      (user-error "No Doxygen XML documentation found for: %s" symbol))
    (mod-tcl-docs--render (mod-tcl-docs--entry-doc entry))))

(defun mod-tcl-docs-regenerate ()
  "Run Doxygen to regenerate Tcl XML documentation."
  (interactive)
  (unless orbit-user-doxygen-program
    (user-error "Set orbit-user-doxygen-program in user config"))
  (unless orbit-user-doxygen-config-file
    (user-error "Set orbit-user-doxygen-config-file in user config"))
  (unless (file-exists-p orbit-user-doxygen-config-file)
    (user-error "Doxygen config file not found: %s" orbit-user-doxygen-config-file))
  (let ((default-directory (file-name-directory orbit-user-doxygen-config-file))
        (compilation-buffer-name-function (lambda (_) mod-tcl-docs-regenerate-buffer-name)))
    (compilation-start
     (mapconcat #'shell-quote-argument
                (list orbit-user-doxygen-program orbit-user-doxygen-config-file)
                " ")
     'compilation-mode
     (lambda (_) mod-tcl-docs-regenerate-buffer-name))))

(provide 'mod-tcl-docs)

;;; mod-tcl-docs.el ends here
