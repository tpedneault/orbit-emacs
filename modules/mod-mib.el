;;; mod-mib.el --- SCOS-2000 MIB TSV editing -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

(defgroup mod-mib nil
  "SCOS-2000 MIB editing helpers."
  :group 'tools)

(defvar orbit-user-mib-roots nil
  "Configured SCOS-2000 MIB directories.")

(defvar orbit-user-mib-icd-version "7.2"
  "SCOS-2000 Database Import ICD version used for MIB column names.")

(defconst mod-mib--schemas-7.2
  '(("caf" . ("CAF_NUMBR" "CAF_DESCR" "CAF_ENGFMT" "CAF_RAWFMT" "CAF_RADIX" "CAF_UNIT" "CAF_NCURVE" "CAF_INTER"))
    ("cap" . ("CAP_NUMBR" "CAP_XVALS" "CAP_YVALS"))
    ("cca" . ("CCA_NUMBR" "CCA_DESCR" "CCA_ENGFMT" "CCA_RAWFMT" "CCA_RADIX" "CCA_UNIT" "CCA_NCURVE"))
    ("ccf" . ("CCF_CNAME" "CCF_DESCR" "CCF_DESCR2" "CCF_CTYPE" "CCF_CRITICAL" "CCF_PKTID" "CCF_TYPE" "CCF_STYPE" "CCF_APID" "CCF_NPARS" "CCF_PLAN" "CCF_EXEC" "CCF_ILSCOPE" "CCF_ILSTAGE" "CCF_SUBSYS" "CCF_HIPRI" "CCF_MAPID" "CCF_DEFSET" "CCF_RAPID" "CCF_ACK" "CCF_SUBSCHEDID"))
    ("ccs" . ("CCS_NUMBR" "CCS_XVALS" "CCS_YVALS"))
    ("cdf" . ("CDF_CNAME" "CDF_ELTYPE" "CDF_DESCR" "CDF_ELLEN" "CDF_BIT" "CDF_GRPSIZE" "CDF_PNAME" "CDF_INTER" "CDF_VALUE" "CDF_TMID"))
    ("cpc" . ("CPC_NAME" "CPC_DESCR" "CPC_PTC" "CPC_PFC" "CPC_DISPFMT" "CPC_RADIX" "CPC_UNIT" "CPC_CATEG" "CPC_PRFREF" "CPC_CCAREF" "CPC_PAFREF" "CPC_INTER" "CPC_DEFVAL" "CPC_CORR" "CPC_OBTIP" "CPC_DESCR2" "CPC_ENDIAN"))
    ("csf" . ("CSF_NAME" "CSF_DESC" "CSF_DESC2" "CSF_IFTT" "CSF_NFPARS" "CSF_ELEMS" "CSF_CRITICAL" "CSF_PLAN" "CSF_EXEC" "CSF_SUBSYS" "CSF_GENTIME" "CSF_DOCNAME" "CSF_ISSUE" "CSF_DATE" "CSF_DEFSET" "CSF_SUBSCHEDID"))
    ("csp" . ("CSP_SQNAME" "CSP_FPNAME" "CSP_FPNUM" "CSP_DESCR" "CSP_PTC" "CSP_PFC" "CSP_DISPFMT" "CSP_RADIX" "CSP_TYPE" "CSP_VTYPE" "CSP_DEFVAL" "CSP_CATEG" "CSP_PRFREF" "CSP_CCAREF" "CSP_PAFREF" "CSP_UNIT"))
    ("css" . ("CSS_SQNAME" "CSS_COMM" "CSS_ENTRY" "CSS_TYPE" "CSS_ELEMID" "CSS_NPARS" "CSS_MANDISP" "CSS_RELTYPE" "CSS_RELTIME" "CSS_EXTIME" "CSS_PREVREL" "CSS_GROUP" "CSS_BLOCK" "CSS_ILSCOPE" "CSS_ILSTAGE" "CSS_DYNPTV" "CSS_STATPTV" "CSS_CEV"))
    ("cur" . ("CUR_PNAME" "CUR_POS" "CUR_RLCHK" "CUR_VALPAR" "CUR_SELECT"))
    ("dst" . ("DST_APID" "DST_ROUTE"))
    ("lgf" . ("LGF_IDENT" "LGF_DESCR" "LGF_POL1" "LGF_POL2" "LGF_POL3" "LGF_POL4" "LGF_POL5"))
    ("mcf" . ("MCF_IDENT" "MCF_DESCR" "MCF_POL1" "MCF_POL2" "MCF_POL3" "MCF_POL4" "MCF_POL5"))
    ("ocf" . ("OCF_NAME" "OCF_NBCHCK" "OCF_NBOOL" "OCF_INTER" "OCF_CODIN"))
    ("ocp" . ("OCP_NAME" "OCP_POS" "OCP_TYPE" "OCP_LVALU" "OCP_HVALU" "OCP_RLCHK" "OCP_VALPAR"))
    ("paf" . ("PAF_NUMBR" "PAF_DESCR" "PAF_RAWFMT" "PAF_NALIAS"))
    ("pas" . ("PAS_NUMBR" "PAS_ALTXT" "PAS_ALVAL"))
    ("pcdf" . ("PCDF_TCNAME" "PCDF_DESC" "PCDF_TYPE" "PCDF_LEN" "PCDF_BIT" "PCDF_PNAME" "PCDF_VALUE" "PCDF_RADIX"))
    ("pcf" . ("PCF_NAME" "PCF_DESCR" "PCF_PID" "PCF_UNIT" "PCF_PTC" "PCF_PFC" "PCF_WIDTH" "PCF_VALID" "PCF_RELATED" "PCF_CATEG" "PCF_NATUR" "PCF_CURTX" "PCF_INTER" "PCF_USCON" "PCF_DECIM" "PCF_PARVAL" "PCF_SUBSYS" "PCF_VALPAR" "PCF_SPTYPE" "PCF_CORR" "PCF_OBTID" "PCF_DARC" "PCF_ENDIAN" "PCF_DESCR2"))
    ("pcpc" . ("PCPC_PNAME" "PCPC_DESC" "PCPC_CODE"))
    ("pic" . ("PIC_TYPE" "PIC_STYPE" "PIC_PI1_OFF" "PIC_PI1_WID" "PIC_PI2_OFF" "PIC_PI2_WID" "PIC_APID"))
    ("pid" . ("PID_TYPE" "PID_STYPE" "PID_APID" "PID_PI1_VAL" "PID_PI2_VAL" "PID_SPID" "PID_DESCR" "PID_UNIT" "PID_TPSD" "PID_DFHSIZE" "PID_TIME" "PID_INTER" "PID_VALID" "PID_CHECK" "PID_EVENT" "PID_EVID"))
    ("plf" . ("PLF_NAME" "PLF_SPID" "PLF_OFFBY" "PLF_OFFBI" "PLF_NBOCC" "PLF_LGOCC" "PLF_TIME" "PLF_TDOCC"))
    ("prf" . ("PRF_NUMBR" "PRF_DESCR" "PRF_INTER" "PRF_DSPFMT" "PRF_RADIX" "PRF_NRANGE" "PRF_UNIT"))
    ("prv" . ("PRV_NUMBR" "PRV_MINVAL" "PRV_MAXVAL"))
    ("pst" . ("PST_NAME" "PST_DESCR"))
    ("psv" . ("PSV_NAME" "PSV_PVSID" "PSV_DESCR"))
    ("ptv" . ("PTV_CNAME" "PTV_PARNAM" "PTV_INTER" "PTV_VAL"))
    ("sdf" . ("SDF_SQNAME" "SDF_ENTRY" "SDF_ELEMID" "SDF_POS" "SDF_PNAME" "SDF_FTYPE" "SDF_VTYPE" "SDF_VALUE" "SDF_VALSET" "SDF_REPPOS"))
    ("tcp" . ("TCP_ID" "TCP_DESC"))
    ("tpcf" . ("TPCF_SPID" "TPCF_NAME" "TPCF_SIZE"))
    ("txf" . ("TXF_NUMBR" "TXF_DESCR" "TXF_RAWFMT" "TXF_NALIAS"))
    ("txp" . ("TXP_NUMBR" "TXP_FROM" "TXP_TO" "TXP_ALTXT"))
    ("vdf" . ("VDF_NAME" "VDF_COMMENT"))
    ("vpd" . ("VPD_TPSD" "VPD_POS" "VPD_NAME" "VPD_GRPSIZE" "VPD_FIXREP" "VPD_CHOICE" "VPD_PIDREF" "VPD_DISDESC" "VPD_WIDTH" "VPD_JUSTIFY" "VPD_NEWLINE" "VPD_DCHAR" "VPD_FORM" "VPD_OFFSET")))
  "Seed ICD 7.2 column schemas for common SCOS-2000 MIB tables.")

(defvar mod-mib--selected-root nil
  "Currently selected MIB root entry.")

(defvar-local mod-mib--root-entry nil)
(defvar-local mod-mib--column-widths nil)
(defvar-local mod-mib--display-overlays nil)
(defvar-local mod-mib--ruler-overlay nil)
(defvar-local mod-mib--ruler-visible nil)
(defvar-local mod-mib--scroll-peer-buffer nil)

(defvar mod-mib--syncing-scroll nil)

(defun mod-mib--normalize-root-entry (entry)
  "Return normalized root data for ENTRY."
  (let* ((label (if (consp entry) (car entry) nil))
         (path (if (consp entry) (cdr entry) entry))
         (expanded (file-name-as-directory
                    (expand-file-name (substitute-in-file-name path)))))
    (list :label (or label
                     (file-name-nondirectory
                      (directory-file-name expanded)))
          :path expanded)))

(defun mod-mib--root-entries ()
  "Return configured MIB roots that exist on disk."
  (delq nil
        (mapcar
         (lambda (entry)
           (let ((root (mod-mib--normalize-root-entry entry)))
             (when (file-directory-p (plist-get root :path))
               root)))
         orbit-user-mib-roots)))

(defun mod-mib--root-display (entry)
  "Return minibuffer display text for root ENTRY."
  (format "%s  %s"
          (plist-get entry :label)
          (abbreviate-file-name (plist-get entry :path))))

(defun mod-mib--read-root (&optional prompt exclude)
  "Read a configured MIB root using PROMPT, excluding EXCLUDE path."
  (let* ((entries (cl-remove-if
                   (lambda (entry)
                     (and exclude
                          (file-equal-p (plist-get entry :path) exclude)))
                   (mod-mib--root-entries)))
         (choices (mapcar (lambda (entry)
                            (cons (mod-mib--root-display entry) entry))
                          entries)))
    (unless choices
      (user-error "No configured MIB roots available"))
    (cdr (assoc (completing-read (or prompt "MIB root: ") choices nil t)
                choices))))

(defun mod-mib--root-for-file (file)
  "Return the configured MIB root entry containing FILE."
  (let ((expanded (file-name-as-directory
                   (expand-file-name
                    (file-name-directory file)))))
    (cl-find-if
     (lambda (entry)
       (string-prefix-p (plist-get entry :path) expanded))
     (mod-mib--root-entries))))

(defun mod-mib--table-name (&optional file)
  "Return lower-case MIB table name for FILE or current buffer."
  (downcase
   (file-name-base (or file buffer-file-name (buffer-name)))))

(defun mod-mib--schema (&optional table)
  "Return schema for TABLE under the configured ICD version."
  (unless (string= orbit-user-mib-icd-version "7.2")
    (user-error "Unsupported SCOS-2000 MIB ICD version: %s"
                orbit-user-mib-icd-version))
  (alist-get (or table (mod-mib--table-name))
             mod-mib--schemas-7.2 nil nil #'string=))

(defun mod-mib--line-fields ()
  "Return TSV fields for the current line."
  (split-string
   (buffer-substring-no-properties
    (line-beginning-position)
    (line-end-position))
   "\t"))

(defun mod-mib--max-column-count ()
  "Return the maximum field count in the buffer."
  (let ((count 0))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (setq count (max count (length (mod-mib--line-fields))))
        (forward-line 1)))
    count))

(defun mod-mib--column-name (index)
  "Return display name for zero-based column INDEX."
  (or (nth index (mod-mib--schema))
      (format "Column %d" (1+ index))))

(defun mod-mib--current-column-index ()
  "Return zero-based column index at point."
  (save-excursion
    (let ((end (point))
          (count 0))
      (goto-char (line-beginning-position))
      (while (search-forward "\t" end t)
        (setq count (1+ count)))
      count)))

(defun mod-mib--field-bounds (&optional column)
  "Return bounds for COLUMN on the current line, defaulting to point."
  (let ((target (or column (mod-mib--current-column-index)))
        (line-end (line-end-position))
        (start (line-beginning-position))
        (index 0))
    (save-excursion
      (goto-char start)
      (while (and (< index target)
                  (search-forward "\t" line-end t))
        (setq start (point)
              index (1+ index)))
      (let ((end (if (search-forward "\t" line-end t)
                     (1- (point))
                   line-end)))
        (cons start end)))))

(defun mod-mib--goto-column (column)
  "Move point to zero-based COLUMN on the current line."
  (goto-char (car (mod-mib--field-bounds column))))

(defun mod-mib--compute-column-widths ()
  "Compute display widths for aligned TSV columns."
  (let* ((schema (mod-mib--schema))
         (count (max (length schema) (mod-mib--max-column-count)))
         (widths (make-vector count 4)))
    (cl-loop for name in schema
             for i from 0
             do (aset widths i (max (aref widths i) (string-width name))))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (cl-loop for field in (mod-mib--line-fields)
                 for i from 0
                 when (< i count)
                 do (aset widths i (max (aref widths i)
                                        (string-width field))))
        (forward-line 1)))
    (mapcar (lambda (width) (+ width 2)) (append widths nil))))

(defun mod-mib--column-stops ()
  "Return absolute display stops derived from `mod-mib--column-widths'."
  (let ((pos 0)
        stops)
    (dolist (width mod-mib--column-widths)
      (setq pos (+ pos width))
      (push pos stops))
    (nreverse stops)))

(defun mod-mib--clear-display-overlays ()
  "Remove display alignment overlays."
  (mapc #'delete-overlay mod-mib--display-overlays)
  (setq mod-mib--display-overlays nil))

(defun mod-mib--clear-ruler ()
  "Remove the column ruler overlay."
  (when (overlayp mod-mib--ruler-overlay)
    (delete-overlay mod-mib--ruler-overlay))
  (setq mod-mib--ruler-overlay nil))

(defun mod-mib--install-display-overlays ()
  "Install display-only tab alignment overlays."
  (let ((stops (mod-mib--column-stops)))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line-end (line-end-position))
              (index 0))
          (while (search-forward "\t" line-end t)
            (when-let* ((stop (nth index stops)))
              (let ((overlay (make-overlay (1- (point)) (point)
                                           (current-buffer) nil t)))
                (overlay-put overlay 'display `(space :align-to ,stop))
                (push overlay mod-mib--display-overlays)))
            (setq index (1+ index))))
        (forward-line 1)))))

(defun mod-mib--ruler-string ()
  "Return the aligned column ruler text."
  (let ((parts nil))
    (cl-loop for width in mod-mib--column-widths
             for i from 0
             for name = (mod-mib--column-name i)
             do (push (truncate-string-to-width
                       name width 0 ?\s)
                      parts))
    (propertize (string-join (nreverse parts) "")
                'face 'font-lock-comment-face)))

(defun mod-mib--install-ruler ()
  "Install the display-only column ruler overlay."
  (mod-mib--clear-ruler)
  (when mod-mib--ruler-visible
    (setq mod-mib--ruler-overlay (make-overlay (point-min) (point-min)
                                               (current-buffer) nil t))
    (overlay-put mod-mib--ruler-overlay
                 'before-string
                 (concat (mod-mib--ruler-string) "\n"))))

(defun mod-mib-realign ()
  "Realign display-only MIB TSV columns."
  (interactive)
  (setq mod-mib--column-widths (mod-mib--compute-column-widths))
  (mod-mib--clear-display-overlays)
  (mod-mib--install-display-overlays)
  (mod-mib--install-ruler)
  (force-mode-line-update)
  (message "MIB columns aligned"))

(defun mod-mib-toggle-ruler ()
  "Toggle the display-only MIB column ruler."
  (interactive)
  (setq mod-mib--ruler-visible (not mod-mib--ruler-visible))
  (unless mod-mib--column-widths
    (setq mod-mib--column-widths (mod-mib--compute-column-widths)))
  (mod-mib--install-ruler)
  (message "MIB column ruler %s"
           (if mod-mib--ruler-visible "shown" "hidden")))

(defun mod-mib-next-field ()
  "Move to the next TSV field."
  (interactive)
  (let ((column (mod-mib--current-column-index))
        (count (length (mod-mib--line-fields))))
    (if (< column (1- count))
        (mod-mib--goto-column (1+ column))
      (user-error "No next field on this row"))))

(defun mod-mib-previous-field ()
  "Move to the previous TSV field."
  (interactive)
  (let ((column (mod-mib--current-column-index)))
    (if (> column 0)
        (mod-mib--goto-column (1- column))
      (user-error "No previous field on this row"))))

(defun mod-mib-next-row ()
  "Move to the next row, preserving the current MIB column."
  (interactive)
  (let ((column (mod-mib--current-column-index)))
    (forward-line 1)
    (mod-mib--goto-column column)))

(defun mod-mib-previous-row ()
  "Move to the previous row, preserving the current MIB column."
  (interactive)
  (let ((column (mod-mib--current-column-index)))
    (forward-line -1)
    (mod-mib--goto-column column)))

(defun mod-mib-jump-column ()
  "Jump to a MIB column by ICD name or number."
  (interactive)
  (let* ((schema (mod-mib--schema))
         (count (max (length schema) (mod-mib--max-column-count)))
         (choices (cl-loop for i below count
                           collect (cons (format "%02d %s"
                                                 (1+ i)
                                                 (mod-mib--column-name i))
                                         i)))
         (column (cdr (assoc (completing-read "Column: " choices nil t)
                             choices))))
    (mod-mib--goto-column column)
    (message "%s" (mod-mib--column-name column))))

(defun mod-mib-edit-field ()
  "Edit the current TSV field through the minibuffer."
  (interactive)
  (pcase-let* ((`(,beg . ,end) (mod-mib--field-bounds))
               (old (buffer-substring-no-properties beg end))
               (new (read-string (format "%s: "
                                         (mod-mib--column-name
                                          (mod-mib--current-column-index)))
                                 old)))
    (setq new (replace-regexp-in-string "[\t\r\n]" " " new))
    (delete-region beg end)
    (insert new)
    (mod-mib-realign)))

(defun mod-mib--table-files (root)
  "Return .dat table files under ROOT."
  (sort (directory-files root nil "\\.dat\\'" t) #'string-lessp))

(defun mod-mib--read-table (root &optional prompt)
  "Read a MIB table filename from ROOT."
  (let ((files (mod-mib--table-files root)))
    (unless files
      (user-error "No .dat tables found under %s" root))
    (completing-read (or prompt "MIB table: ") files nil t)))

(defun mod-mib--current-or-selected-root ()
  "Return the current buffer root, selected root, or prompt for one."
  (or mod-mib--root-entry
      mod-mib--selected-root
      (setq mod-mib--selected-root (mod-mib--read-root))))

(defun mod-mib-switch-root ()
  "Select a configured MIB root for subsequent MIB commands."
  (interactive)
  (setq mod-mib--selected-root (mod-mib--read-root))
  (message "MIB root: %s" (mod-mib--root-display mod-mib--selected-root)))

(defun mod-mib-open-table ()
  "Open a table from the current or selected MIB root."
  (interactive)
  (let* ((entry (mod-mib--current-or-selected-root))
         (root (plist-get entry :path))
         (table (mod-mib--read-table root)))
    (setq mod-mib--selected-root entry)
    (find-file (expand-file-name table root))))

(defun mod-mib-open-table-other-root ()
  "Open the current table name from another configured MIB root."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer has no file"))
  (let* ((current-root (plist-get mod-mib--root-entry :path))
         (entry (mod-mib--read-root "Other MIB root: " current-root))
         (path (expand-file-name (file-name-nondirectory buffer-file-name)
                                 (plist-get entry :path))))
    (unless (file-exists-p path)
      (user-error "Table does not exist: %s" path))
    (find-file path)))

(defun mod-mib--sync-scroll (window _display-start)
  "Synchronize peer MIB WINDOW scrolling."
  (when (and mod-mib--scroll-peer-buffer
             (not mod-mib--syncing-scroll))
    (let* ((source-buffer (window-buffer window))
           (peer-buffer mod-mib--scroll-peer-buffer)
           (peer-window (get-buffer-window peer-buffer))
           (line (with-current-buffer source-buffer
                   (save-excursion
                     (goto-char (window-start window))
                     (line-number-at-pos)))))
      (when (window-live-p peer-window)
        (let ((mod-mib--syncing-scroll t))
          (with-current-buffer peer-buffer
            (save-excursion
              (goto-char (point-min))
              (forward-line (1- line))
              (set-window-start peer-window (point)))))))))

(defun mod-mib--pair-scroll (left right)
  "Synchronize scrolling between LEFT and RIGHT buffers."
  (with-current-buffer left
    (setq-local mod-mib--scroll-peer-buffer right)
    (add-hook 'window-scroll-functions #'mod-mib--sync-scroll nil t))
  (with-current-buffer right
    (setq-local mod-mib--scroll-peer-buffer left)
    (add-hook 'window-scroll-functions #'mod-mib--sync-scroll nil t)))

(defun mod-mib-compare-table ()
  "Compare the current table with the same table from another MIB root."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer has no file"))
  (let* ((left-buffer (current-buffer))
         (current-root (plist-get mod-mib--root-entry :path))
         (entry (mod-mib--read-root "Compare with MIB root: " current-root))
         (path (expand-file-name (file-name-nondirectory buffer-file-name)
                                 (plist-get entry :path))))
    (unless (file-exists-p path)
      (user-error "Table does not exist: %s" path))
    (let ((right-window (split-window-right)))
      (select-window right-window)
      (find-file path)
      (mod-mib-realign)
      (mod-mib--pair-scroll left-buffer (current-buffer))
      (balance-windows)
      (message "Comparing %s with %s"
               (buffer-name left-buffer)
               (buffer-name (current-buffer))))))

(defun mod-mib--header-line ()
  "Return the MIB header-line text for the current buffer."
  (let* ((root (or mod-mib--root-entry
                   (and buffer-file-name
                        (mod-mib--root-for-file buffer-file-name))))
         (table (file-name-nondirectory (or buffer-file-name (buffer-name))))
         (column (mod-mib--current-column-index))
         (name (mod-mib--column-name column)))
    (format "  MIB %s  >  %s  >  row %d  col %d %s"
            (if root (plist-get root :label) "<unconfigured>")
            table
            (line-number-at-pos)
            (1+ column)
            name)))

(defun mod-mib--maybe-enable ()
  "Enable `mod-mib-mode' for configured SCOS-2000 MIB .dat files."
  (when (and buffer-file-name
             (string= (downcase (or (file-name-extension buffer-file-name) ""))
                      "dat")
             (mod-mib--root-for-file buffer-file-name)
             (not (derived-mode-p 'mod-mib-mode)))
    (mod-mib-mode)))

;;;###autoload
(define-derived-mode mod-mib-mode text-mode "MIB"
  "Major mode for editing SCOS-2000 MIB TSV .dat files."
  (setq-local mod-mib--root-entry
              (and buffer-file-name
                   (mod-mib--root-for-file buffer-file-name)))
  (setq mod-mib--selected-root (or mod-mib--root-entry mod-mib--selected-root))
  (setq-local truncate-lines t
              word-wrap nil
              tab-width 8
              indent-tabs-mode t
              header-line-format '(:eval (mod-mib--header-line))
              whitespace-style '(face tabs trailing))
  (when (fboundp 'whitespace-mode)
    (whitespace-mode 1))
  (mod-mib-realign))

(add-hook 'find-file-hook #'mod-mib--maybe-enable)

(provide 'mod-mib)

;;; mod-mib.el ends here
