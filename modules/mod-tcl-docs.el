;;; mod-tcl-docs.el --- Minimal Tcl Doxygen XML browser -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'compile)
(require 'org)
(require 'subr-x)
(require 'xref)
(require 'xml)

(defgroup mod-tcl-docs nil
  "Minimal Tcl Doxygen XML browsing helpers."
  :group 'tools)

(defconst mod-tcl-docs-buffer-prefix "*tcl-docs: "
  "Prefix used for temporary Tcl documentation buffers.")

(defconst mod-tcl-docs-manual-buffer-prefix "*tcl-docs-manual: "
  "Prefix used for temporary Tcl documentation manual buffers.")

(defconst mod-tcl-docs-regenerate-buffer-name "*tcl-doxygen*"
  "Compilation buffer name for Doxygen regeneration.")

(defun mod-tcl-docs-go-back ()
  "Go back to the previous Tcl docs location using the xref stack."
  (interactive)
  (xref-go-back))

(defvar mod-tcl-docs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'mod-tcl-docs-go-back)
    (define-key map (kbd "RET") #'mod-tcl-docs-open-at-point-dwim)
    map)
  "Keymap for temporary Tcl docs buffers.")

(define-minor-mode mod-tcl-docs-mode
  "Minor mode for temporary Tcl documentation buffers."
  :lighter nil
  :keymap mod-tcl-docs-mode-map)

(defun mod-tcl-docs--enable-local-evil-bindings ()
  "Install buffer-local Evil bindings for Tcl docs buffers.
Minor-mode keymaps do not override Evil normal-state bindings by themselves,
so keys like `q' and `RET' must be rebound through Evil here."
  (when (fboundp 'evil-local-set-key)
    (evil-local-set-key 'normal (kbd "q") #'mod-tcl-docs-go-back)
    (evil-local-set-key 'normal (kbd "RET") #'mod-tcl-docs-open-at-point-dwim)))

(defun mod-tcl-docs-xml-directory ()
  "Return the configured or default Doxygen XML directory.
When no explicit override is set, this defaults to
`<project-root>/docs/xml/'."
  (let ((dir (or orbit-user-tcl-doxygen-xml-directory
                 (expand-file-name "docs/xml/" (mod-tcl-docs--project-root)))))
    (unless (file-directory-p dir)
      (user-error
       "Doxygen XML directory not found: %s. Run SPC m d r to generate docs, or set orbit-user-tcl-doxygen-xml-directory."
       dir))
    dir))

(defun mod-tcl-docs-doxygen-config-file ()
  "Return the configured or default Doxygen config file.
When no explicit override is set, this defaults to
`<project-root>/Doxyfile'."
  (or orbit-user-doxygen-config-file
      (expand-file-name "Doxyfile" (mod-tcl-docs--project-root))))

(defun mod-tcl-docs--index-file ()
  "Return the configured Doxygen index.xml path."
  (let ((index-file (expand-file-name "index.xml" (mod-tcl-docs-xml-directory))))
    (unless (file-exists-p index-file)
      (user-error
       "Doxygen index not found: %s. Run SPC m d r to generate docs."
       index-file))
    index-file))

(defun mod-tcl-docs--project-root ()
  "Return a practical project root for Tcl docs."
  (or (when-let* ((project (project-current nil)))
        (project-root project))
      (when orbit-user-doxygen-config-file
        (file-name-directory orbit-user-doxygen-config-file))
      (when orbit-user-tcl-doxygen-xml-directory
        (file-name-directory
         (directory-file-name
          (file-name-directory
           (directory-file-name orbit-user-tcl-doxygen-xml-directory)))))
      (user-error
       "Not in a project. Open a project file first, or set orbit-user-doxygen-config-file / orbit-user-tcl-doxygen-xml-directory.")))

(defun mod-tcl-docs--project-name ()
  "Return the current Tcl docs project name."
  (file-name-nondirectory
   (directory-file-name (mod-tcl-docs--project-root))))

(defun mod-tcl-docs--docs-context-name ()
  "Return the context name used for the Tcl docs manual."
  (format "docs/%s" (mod-tcl-docs--project-name)))

(defun mod-tcl-docs--manual-buffer-name ()
  "Return the Tcl docs manual buffer name."
  (format "%s%s*" mod-tcl-docs-manual-buffer-prefix (mod-tcl-docs--project-name)))

(defun mod-tcl-docs--push-location ()
  "Push the current point onto Emacs' built-in xref marker stack."
  (xref-push-marker-stack))

(defun mod-tcl-docs--edit-context-name ()
  "Return the matching edit context name for the current Tcl docs project."
  (let ((root (mod-tcl-docs--project-root)))
    (if (fboundp 'mod-context--edit-context-name)
        (mod-context--edit-context-name root)
      (format "edit/%s" (file-name-nondirectory (directory-file-name root))))))

(defun mod-tcl-docs--switch-to-edit-context ()
  "Switch to the matching edit context for the current Tcl docs project."
  (let ((name (mod-tcl-docs--edit-context-name)))
    (cond
     ((and (fboundp 'mod-context--switch-or-create)
           (fboundp 'persp-switch))
      (mod-context--switch-or-create name))
     ((fboundp 'persp-switch)
      (persp-switch name))
     (t
      nil))))

(defun mod-tcl-docs--parse-xml-file (file)
  "Parse FILE into a simple XML tree."
  (unless (file-exists-p file)
    (user-error "Doxygen XML file not found: %s" file))
  (with-temp-buffer
    (insert-file-contents file)
    (if (fboundp 'libxml-parse-xml-region)
        (libxml-parse-xml-region (point-min) (point-max))
      (car (xml-parse-region (point-min) (point-max))))))

(defun mod-tcl-docs--line-at-search-option (search-option)
  "Return a line number parsed from SEARCH-OPTION, or nil."
  (when (and search-option
             (string-match-p "\\`[0-9]+\\'" search-option))
    (string-to-number search-option)))

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

(defun mod-tcl-docs--switch-to-manual-context ()
  "Switch to the Tcl documentation context for the current project."
  (cond
   ((and (fboundp 'mod-context--switch-or-create)
         (fboundp 'persp-switch))
    (mod-context--switch-or-create (mod-tcl-docs--docs-context-name)))
   ((fboundp 'persp-switch)
    (persp-switch (mod-tcl-docs--docs-context-name)))
   (t
    nil)))

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
                          :entry-type 'member
                          :refid (mod-tcl-docs--attr member 'refid)
                          :kind (mod-tcl-docs--attr member 'kind)
                          :compound-refid compound-refid
                          :compound-kind compound-kind
                          :compound-name compound-name)
                    entries))))))
    (nreverse entries)))

(defun mod-tcl-docs--collect-index-compounds ()
  "Collect compound-level entries from Doxygen's index.xml."
  (let* ((root (mod-tcl-docs--parse-xml-file (mod-tcl-docs--index-file)))
         (compounds (mod-tcl-docs--children-named root 'compound))
         entries)
    (dolist (compound compounds)
      (let ((name (mod-tcl-docs--text (mod-tcl-docs--child compound 'name)))
            (kind (mod-tcl-docs--attr compound 'kind))
            (refid (mod-tcl-docs--attr compound 'refid)))
        (when (and name (not (string-empty-p name)))
          (push (list :entry-type 'compound
                      :symbol name
                      :kind kind
                      :refid refid)
                entries))))
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
     ((mod-tcl-docs-doxygen-config-file)
      (expand-file-name file (file-name-directory (mod-tcl-docs-doxygen-config-file))))
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

(defun mod-tcl-docs--compound-node (entry)
  "Return the compounddef node matching compound ENTRY."
  (let* ((compound-file
          (expand-file-name
           (format "%s.xml" (plist-get entry :refid))
           (mod-tcl-docs-xml-directory)))
         (root (mod-tcl-docs--parse-xml-file compound-file))
         (target-refid (plist-get entry :refid)))
    (mod-tcl-docs--find-first
     root
     (lambda (node)
       (and (eq (mod-tcl-docs--node-name node) 'compounddef)
            (equal (mod-tcl-docs--attr node 'id) target-refid))))))

(defun mod-tcl-docs--entry-by-refid (refid)
  "Return the indexed symbol entry identified by REFID."
  (cl-find-if
   (lambda (entry)
     (equal (plist-get entry :refid) refid))
   (mod-tcl-docs--collect-index-entries)))

(defun mod-tcl-docs--compound-by-refid (refid)
  "Return the indexed compound entry identified by REFID."
  (cl-find-if
   (lambda (entry)
     (equal (plist-get entry :refid) refid))
   (mod-tcl-docs--collect-index-compounds)))

(defun mod-tcl-docs--compound-inner-namespaces (compound)
  "Return indexed child namespace entries referenced by COMPOUND."
  (delq nil
        (mapcar
         (lambda (node)
           (mod-tcl-docs--compound-by-refid (mod-tcl-docs--attr node 'refid)))
         (mod-tcl-docs--children-named compound 'innernamespace))))

(defun mod-tcl-docs--namespace-member-entries (compound)
  "Return direct symbol entries defined by namespace COMPOUND.
This uses the compound XML `memberdef` list, which Doxygen 1.8.17 emits for
Tcl namespace compounds."
  (let (entries)
    (cl-labels ((walk (node)
                  (when (consp node)
                    (when (eq (mod-tcl-docs--node-name node) 'memberdef)
                      (when-let* ((entry (mod-tcl-docs--entry-by-refid
                                         (mod-tcl-docs--attr node 'id))))
                        (push entry entries)))
                    (dolist (child (mod-tcl-docs--node-children node))
                      (walk child)))))
      (walk compound))
    (nreverse (cl-remove-duplicates entries :test #'equal))))

(defun mod-tcl-docs--file-member-entries (compound entry)
  "Return symbol entries belonging to file COMPOUND for compound ENTRY.
File compounds in Doxygen's Tcl XML usually do not include their own
`memberdef`s, so this falls back to the global symbol index and compares each
symbol's resolved source file against the file compound's source path."
  (let* ((location (mod-tcl-docs--child compound 'location))
         (target-file (mod-tcl-docs--resolve-source-file
                       (or (mod-tcl-docs--attr location 'bodyfile)
                           (mod-tcl-docs--attr location 'file))))
         (entries (mod-tcl-docs--collect-index-entries))
         matches)
    (dolist (symbol-entry entries)
      (unless (equal (plist-get symbol-entry :compound-refid) (plist-get entry :refid))
        (when-let* ((source-file (plist-get (mod-tcl-docs--entry-doc symbol-entry) :source-file)))
          (when (and target-file (string= source-file target-file))
            (push symbol-entry matches)))))
    (nreverse (cl-remove-duplicates matches :test #'equal))))

(defun mod-tcl-docs--split-member-groups (entries)
  "Split ENTRIES into function and other groups."
  (list
   :functions
   (sort
    (cl-remove-if-not
     (lambda (entry) (equal (plist-get entry :kind) "function"))
     entries)
    (lambda (a b) (string< (plist-get a :symbol) (plist-get b :symbol))))
   :others
   (sort
    (cl-remove-if
     (lambda (entry) (equal (plist-get entry :kind) "function"))
     entries)
    (lambda (a b) (string< (plist-get a :symbol) (plist-get b :symbol))))))

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

(defun mod-tcl-docs--compound-doc (entry)
  "Extract a minimal documentation plist for compound ENTRY."
  (let* ((compound (mod-tcl-docs--compound-node entry))
         (location (mod-tcl-docs--child compound 'location))
         (members
          (pcase (plist-get entry :kind)
            ("namespace" (mod-tcl-docs--namespace-member-entries compound))
            ("file" (mod-tcl-docs--file-member-entries compound entry))
            (_ nil)))
         (member-groups (mod-tcl-docs--split-member-groups members))
         (brief (string-join
                 (or (mod-tcl-docs--paragraph-texts
                      (mod-tcl-docs--child compound 'briefdescription))
                     '())
                 "\n\n"))
         (details (string-join
                   (or (mod-tcl-docs--paragraph-texts
                        (mod-tcl-docs--child compound 'detaileddescription))
                       '())
                   "\n\n")))
    (list
     :symbol (plist-get entry :symbol)
     :kind (plist-get entry :kind)
     :compound-name nil
     :definition nil
     :argsstring nil
     :brief brief
     :details details
     :inner-namespaces (mod-tcl-docs--compound-inner-namespaces compound)
     :functions (plist-get member-groups :functions)
     :others (plist-get member-groups :others)
     :parameters nil
     :returns nil
     :source-file (mod-tcl-docs--resolve-source-file
                   (or (mod-tcl-docs--attr location 'bodyfile)
                       (mod-tcl-docs--attr location 'file)))
     :source-line (or (mod-tcl-docs--attr location 'bodyline)
                      (mod-tcl-docs--attr location 'line)))))

(defun mod-tcl-docs--source-link (doc)
  "Return an Org source link string for DOC, or nil."
  (when-let* ((file (plist-get doc :source-file)))
    (let ((line (plist-get doc :source-line)))
      (format "[[file:%s%s][%s%s]]"
              file
              (if line (format "::%s" line) "")
              (file-name-nondirectory file)
              (if line (format ":%s" line) "")))))

(defun mod-tcl-docs-open-symbol (symbol)
  "Open Tcl documentation for SYMBOL."
  (interactive "sTcl symbol: ")
  (mod-tcl-docs--push-location)
  (let ((entry (mod-tcl-docs--find-entry-by-symbol symbol)))
    (unless entry
      (user-error "No Doxygen XML documentation found for: %s" symbol))
    (mod-tcl-docs--render (mod-tcl-docs--entry-doc entry))))

(defun mod-tcl-docs-open-compound (refid)
  "Open Tcl documentation for a compound identified by REFID."
  (interactive "sDoxygen compound refid: ")
  (mod-tcl-docs--push-location)
  (let ((entry (cl-find-if
                (lambda (compound)
                  (equal (plist-get compound :refid) refid))
                (mod-tcl-docs--collect-index-compounds))))
    (unless entry
      (user-error "No Doxygen XML compound found for: %s" refid))
    (mod-tcl-docs--render-compound (mod-tcl-docs--compound-doc entry))))

(defun mod-tcl-docs-open-source-link-at-point ()
  "Open the file link at point in the matching edit context."
  (let* ((context (org-element-context))
         (path (org-element-property :path context))
         (search-option (org-element-property :search-option context))
         (file (if (file-name-absolute-p path)
                   path
                 (expand-file-name path default-directory)))
         (line (mod-tcl-docs--line-at-search-option search-option))
         (default-directory (mod-tcl-docs--project-root)))
    (mod-tcl-docs--push-location)
    (mod-tcl-docs--switch-to-edit-context)
    (find-file file)
    (when line
      (goto-char (point-min))
      (forward-line (1- line)))))

(defun mod-tcl-docs-open-at-point-dwim ()
  "Open the Org link at point, with Tcl docs source links routed to edit context."
  (interactive)
  (let ((context (org-element-context)))
    (if (eq (org-element-type context) 'link)
        (if (equal (org-element-property :type context) "file")
            (mod-tcl-docs-open-source-link-at-point)
          (org-open-at-point))
      (when (boundp 'mod-org-return-fallback-command)
        (call-interactively mod-org-return-fallback-command)))))

(defun mod-tcl-docs--org-link-symbol-follow (symbol)
  "Follow a `tcldoc:' Org link for SYMBOL."
  (mod-tcl-docs-open-symbol symbol))

(defun mod-tcl-docs--org-link-compound-follow (refid)
  "Follow a `tcldoc-compound:' Org link for REFID."
  (mod-tcl-docs-open-compound refid))

(with-eval-after-load 'org
  (org-link-set-parameters "tcldoc" :follow #'mod-tcl-docs--org-link-symbol-follow)
  (org-link-set-parameters "tcldoc-compound" :follow #'mod-tcl-docs--org-link-compound-follow))

(defun mod-tcl-docs--insert-manual-group (title entries link-fn)
  "Insert a manual section TITLE for ENTRIES using LINK-FN.
LINK-FN receives an entry plist and must return an Org link string."
  (when entries
    (insert (format "* %s\n\n" title))
    (dolist (entry entries)
      (insert (format "- %s\n" (funcall link-fn entry))))
    (insert "\n")))

(defun mod-tcl-docs--member-link (entry)
  "Return an Org link for member ENTRY."
  (format "[[tcldoc:%s][%s]]"
          (plist-get entry :symbol)
          (plist-get entry :symbol)))

(defun mod-tcl-docs--compound-link (entry)
  "Return an Org link for compound ENTRY."
  (format "[[tcldoc-compound:%s][%s]]"
          (plist-get entry :refid)
          (plist-get entry :symbol)))

(defun mod-tcl-docs--render-entry-list (title entries)
  "Insert a compound doc section TITLE for symbol ENTRIES."
  (when entries
    (insert (format "* %s\n\n" title))
    (dolist (entry entries)
      (insert (format "- %s\n" (mod-tcl-docs--member-link entry))))
    (insert "\n")))

(defun mod-tcl-docs--render-compound (doc)
  "Render compound DOC into a temporary read-only Org buffer."
  (let ((buffer (get-buffer-create
                 (format "%s%s*" mod-tcl-docs-buffer-prefix (plist-get doc :symbol)))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "* %s\n" (plist-get doc :symbol)))
        (insert (format "- Kind :: %s\n" (or (plist-get doc :kind) "unknown")))
        (when-let* ((source-link (mod-tcl-docs--source-link doc)))
          (insert (format "- Source :: %s\n" source-link)))
        (insert "\n")
        (when-let* ((brief (plist-get doc :brief)))
          (unless (string-empty-p brief)
            (insert "* Summary\n\n" brief "\n\n")))
        (when-let* ((details (plist-get doc :details)))
          (unless (string-empty-p details)
            (insert "* Details\n\n" details "\n\n")))
        (when-let* ((inner-namespaces (plist-get doc :inner-namespaces)))
          (when inner-namespaces
            (insert "* Namespaces\n\n")
            (dolist (entry (sort (copy-sequence inner-namespaces)
                                 (lambda (a b)
                                   (string< (plist-get a :symbol)
                                            (plist-get b :symbol)))))
              (insert (format "- %s\n" (mod-tcl-docs--compound-link entry))))
            (insert "\n")))
        (mod-tcl-docs--render-entry-list "Functions / Procedures"
                                         (plist-get doc :functions))
        (mod-tcl-docs--render-entry-list "Variables / Other"
                                         (plist-get doc :others)))
      (goto-char (point-min))
      (org-mode)
      (mod-tcl-docs-mode 1)
      (mod-tcl-docs--enable-local-evil-bindings)
      (read-only-mode 1))
    (switch-to-buffer buffer)))

(defun mod-tcl-docs--render (doc)
  "Render DOC into a temporary read-only Org buffer."
  (let ((buffer (get-buffer-create
                 (format "%s%s*" mod-tcl-docs-buffer-prefix (plist-get doc :symbol)))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "* %s\n" (plist-get doc :symbol)))
        (when-let* ((definition (plist-get doc :definition)))
          (insert (format "#+begin_example\n%s%s%s\n#+end_example\n\n"
                          definition
                          (if (and (plist-get doc :argsstring)
                                   (not (string-empty-p (plist-get doc :argsstring))))
                              " "
                            "")
                          (or (plist-get doc :argsstring) ""))))
        (insert (format "- Kind :: %s\n" (or (plist-get doc :kind) "unknown")))
        (insert (format "- Compound :: %s\n" (or (plist-get doc :compound-name) "unknown")))
        (when-let* ((source-link (mod-tcl-docs--source-link doc)))
          (insert (format "- Source :: %s\n" source-link)))
        (insert "\n")
        (when-let* ((brief (plist-get doc :brief)))
          (unless (string-empty-p brief)
            (insert "* Summary\n\n" brief "\n\n")))
        (when-let* ((parameters (plist-get doc :parameters)))
          (when parameters
            (insert "* Parameters\n\n")
            (dolist (parameter parameters)
              (insert (format "- %s :: %s\n"
                              (car parameter)
                              (cdr parameter))))
            (insert "\n")))
        (when-let* ((returns (plist-get doc :returns)))
          (when returns
            (insert "* Returns\n\n"
                    (string-join returns "\n\n")
                    "\n\n")))
        (when-let* ((details (plist-get doc :details)))
          (unless (string-empty-p details)
            (insert "* Details\n\n" details "\n"))))
      (goto-char (point-min))
      (org-mode)
      (mod-tcl-docs-mode 1)
      (mod-tcl-docs--enable-local-evil-bindings)
      (read-only-mode 1))
    (switch-to-buffer buffer)))

(defun mod-tcl-docs-manual ()
  "Open a project Tcl documentation manual from Doxygen XML."
  (interactive)
  (mod-tcl-docs--push-location)
  (let* ((project-name (mod-tcl-docs--project-name))
         (xml-directory (mod-tcl-docs-xml-directory))
         (members (mod-tcl-docs--collect-index-entries))
         (compounds (mod-tcl-docs--collect-index-compounds))
         (functions
          (sort
           (cl-remove-if-not
            (lambda (entry) (equal (plist-get entry :kind) "function"))
            members)
           (lambda (a b) (string< (plist-get a :symbol) (plist-get b :symbol)))))
         (variables/other
          (sort
           (cl-remove-if
            (lambda (entry) (equal (plist-get entry :kind) "function"))
            members)
           (lambda (a b) (string< (plist-get a :symbol) (plist-get b :symbol)))))
         (namespaces
          (sort
           (cl-remove-if-not
            (lambda (entry) (equal (plist-get entry :kind) "namespace"))
            compounds)
           (lambda (a b) (string< (plist-get a :symbol) (plist-get b :symbol)))))
         (files
          (sort
           (cl-remove-if-not
            (lambda (entry) (equal (plist-get entry :kind) "file"))
            compounds)
           (lambda (a b) (string< (plist-get a :symbol) (plist-get b :symbol)))))
         (buffer (get-buffer-create (mod-tcl-docs--manual-buffer-name))))
    (mod-tcl-docs--switch-to-manual-context)
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "* Tcl Docs Manual: %s\n\n" project-name))
        (insert (format "- XML Directory :: %s\n" xml-directory))
        (insert (format "- Context :: %s\n\n" (mod-tcl-docs--docs-context-name)))
        (insert "* Commands\n\n")
        (insert "- `SPC m d s` :: search docs\n")
        (insert "- `SPC m d p` :: docs at point\n")
        (insert "- `SPC m d r` :: regenerate XML\n")
        (insert "- `SPC m d d` :: project manual\n\n")
        (mod-tcl-docs--insert-manual-group "Functions / Procedures"
                                           functions
                                           #'mod-tcl-docs--member-link)
        (mod-tcl-docs--insert-manual-group "Namespaces"
                                           namespaces
                                           #'mod-tcl-docs--compound-link)
        (mod-tcl-docs--insert-manual-group "Files"
                                           files
                                           #'mod-tcl-docs--compound-link)
        (mod-tcl-docs--insert-manual-group "Variables / Other"
                                           variables/other
                                           #'mod-tcl-docs--member-link))
      (goto-char (point-min))
      (org-mode)
      (mod-tcl-docs-mode 1)
      (mod-tcl-docs--enable-local-evil-bindings)
      (read-only-mode 1))
    (switch-to-buffer buffer)))

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
  (mod-tcl-docs-open-symbol (mod-tcl-docs--symbol-at-point)))

(defun mod-tcl-docs-regenerate ()
  "Run Doxygen to regenerate Tcl XML documentation."
  (interactive)
  (unless orbit-user-doxygen-program
    (user-error "Set orbit-user-doxygen-program in user config"))
  (let ((config-file (mod-tcl-docs-doxygen-config-file)))
    (unless (file-exists-p config-file)
      (user-error
       "Doxygen config file not found: %s. Create %s or set orbit-user-doxygen-config-file."
       config-file
       config-file))
    (let ((default-directory (file-name-directory config-file))
        (compilation-buffer-name-function (lambda (_) mod-tcl-docs-regenerate-buffer-name)))
      (compilation-start
       (mapconcat #'shell-quote-argument
                  (list orbit-user-doxygen-program config-file)
                  " ")
       'compilation-mode
       (lambda (_) mod-tcl-docs-regenerate-buffer-name)))))

(provide 'mod-tcl-docs)

;;; mod-tcl-docs.el ends here
