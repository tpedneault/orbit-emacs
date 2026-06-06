;;; mod-mib.el --- SCOS-2000 MIB TSV editing -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

(declare-function mod-utility--display-buffer "mod-utility")

(defgroup mod-mib nil
  "SCOS-2000 MIB editing helpers."
  :group 'tools)

(defvar orbit-user-mib-roots nil
  "Configured SCOS-2000 MIB directories.")

(defvar orbit-user-mib-icd-version "7.2"
  "SCOS-2000 Database Import ICD version used for MIB column names.")

(defvar orbit-user-mib-telecommand-template
  "telecommand_send PUS_T={type} PUS_ST={stype} APID={apid} MNEMO={mnemo} ARGUMENTS=[{arguments}]"
  "Template used when inserting a telecommand from the MIB.
Supported placeholders are {type}, {stype}, {apid}, {mnemo},
{description}, {mib}, and {arguments}.")

(defvar orbit-user-mib-telecommand-argument-template "{name}={value}"
  "Template used for one variable telecommand argument.")

(defvar orbit-user-mib-telecommand-argument-separator ", "
  "Separator used between generated telecommand arguments.")

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

(defvar mod-mib--row-cache (make-hash-table :test #'equal)
  "Cache of parsed MIB rows keyed by absolute table file path.")

(defvar mod-mib--last-detail-source nil
  "Source plist for the most recent global MIB detail lookup.")

(defvar-local mod-mib--root-entry nil)
(defvar-local mod-mib--column-widths nil)
(defvar-local mod-mib--display-overlays nil)
(defvar-local mod-mib--ruler-overlay nil)
(defvar-local mod-mib--ruler-visible nil)
(defvar-local mod-mib--scroll-peer-buffer nil)

(defvar mod-mib--syncing-scroll nil)

(defconst mod-mib--tc-summary-fields
  '("CCF_CNAME" "CCF_TYPE" "CCF_STYPE" "CCF_APID" "CCF_DESCR" "CCF_DESCR2"
    "CCF_NPARS" "CCF_PKTID" "CCF_SUBSYS")
  "Fields shown first for telecommand lookup details.")

(defconst mod-mib--tm-packet-summary-fields
  '("PID_SPID" "PID_TYPE" "PID_STYPE" "PID_APID" "PID_DESCR" "PID_UNIT"
    "PID_TPSD" "PID_DFHSIZE")
  "Fields shown first for TM packet lookup details.")

(defconst mod-mib--tm-parameter-summary-fields
  '("PCF_NAME" "PCF_DESCR" "PCF_PID" "PCF_UNIT" "PCF_PTC" "PCF_PFC"
    "PCF_WIDTH" "PCF_CATEG" "PCF_INTER" "PCF_VALPAR" "PCF_DESCR2")
  "Fields shown first for TM parameter lookup details.")

(defconst mod-mib--numeric-ptcs '("1" "2" "3" "4")
  "Packet parameter type values treated as numeric for v1 validation.")

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

(defun mod-mib--clean-value (value)
  "Return VALUE with presentation whitespace normalized."
  (string-trim (or value "")))

(defun mod-mib--row-value (row field)
  "Return ROW value for FIELD."
  (cdr (assoc field (plist-get row :fields))))

(defun mod-mib--row-source (row)
  "Return ROW source metadata."
  (plist-get row :source))

(defun mod-mib--source-label (source)
  "Return a compact label for SOURCE."
  (format "%s:%s:%d"
          (plist-get source :root-label)
          (plist-get source :table)
          (plist-get source :line)))

(defun mod-mib--table-file (root table)
  "Return TABLE .dat path under ROOT."
  (expand-file-name (concat table ".dat") root))

(defun mod-mib--file-mtime (file)
  "Return FILE modification time as a comparable value."
  (when (file-exists-p file)
    (file-attribute-modification-time (file-attributes file))))

(defun mod-mib--fields-alist (schema values)
  "Return an alist mapping SCHEMA field names to VALUES."
  (cl-loop for name in schema
           for value in values
           collect (cons name value)))

(defun mod-mib--parse-table-file (root-entry table file)
  "Parse TABLE FILE for ROOT-ENTRY into MIB row plists."
  (let ((schema (mod-mib--schema table))
        (rows nil)
        (line-number 1))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position))))
          (unless (string-empty-p line)
            (let* ((values (split-string line "\t"))
                   (source (list :root-label (plist-get root-entry :label)
                                 :root-path (plist-get root-entry :path)
                                 :table table
                                 :file file
                                 :line line-number)))
              (push (list :table table
                          :values values
                          :fields (mod-mib--fields-alist schema values)
                          :source source)
                    rows))))
        (setq line-number (1+ line-number))
        (forward-line 1)))
    (nreverse rows)))

(defun mod-mib--cached-table-rows (root-entry table)
  "Return cached rows for TABLE under ROOT-ENTRY."
  (let* ((file (mod-mib--table-file (plist-get root-entry :path) table))
         (mtime (mod-mib--file-mtime file))
         (cached (and mtime (gethash file mod-mib--row-cache))))
    (cond
     ((not mtime) nil)
     ((and cached (equal (car cached) mtime))
      (cdr cached))
     (t
      (let ((rows (mod-mib--parse-table-file root-entry table file)))
        (puthash file (cons mtime rows) mod-mib--row-cache)
        rows)))))

(defun mod-mib--rows (table &optional root-entry)
  "Return parsed rows for TABLE across enabled roots or ROOT-ENTRY."
  (let ((roots (if root-entry
                   (list root-entry)
                 (mod-mib--root-entries))))
    (apply #'append
           (mapcar (lambda (entry)
                     (mod-mib--cached-table-rows entry table))
                   roots))))

(defun mod-mib--rows-by-field (table field value &optional root-entry)
  "Return rows from TABLE where FIELD equals VALUE."
  (let ((needle (mod-mib--clean-value value)))
    (cl-remove-if-not
     (lambda (row)
       (string= (mod-mib--clean-value (mod-mib--row-value row field))
                needle))
     (mod-mib--rows table root-entry))))

(defun mod-mib--first-row-by-field (table field value &optional root-entry)
  "Return the first row from TABLE where FIELD equals VALUE."
  (car (mod-mib--rows-by-field table field value root-entry)))

(defun mod-mib--ensure-roots ()
  "Signal unless at least one enabled MIB root is configured."
  (unless (mod-mib--root-entries)
    (user-error "No existing MIB roots configured in orbit-user-mib-roots")))

(defun mod-mib-refresh-index ()
  "Refresh the global MIB lookup cache."
  (interactive)
  (clrhash mod-mib--row-cache)
  (message "MIB lookup index refreshed"))

(defun mod-mib--candidate (kind row title type stype description)
  "Return completion candidate for KIND ROW and display fields."
  (let* ((source (mod-mib--row-source row))
         (root (plist-get source :root-label))
         (title (or title "<unnamed>"))
         (display (string-join
                   (delq nil
                         (list title
                               (unless (string-empty-p (or type ""))
                                 (format "type:%s" type))
                               (unless (string-empty-p (or stype ""))
                                 (format "stype:%s" stype))
                               (format "[%s]" root)
                               (unless (string-empty-p (or description ""))
                                 description)
                               (format "@%s:%d"
                                       (plist-get source :table)
                                       (plist-get source :line))))
                   "  ")))
    (cons display (list :kind kind :row row))))

(defun mod-mib--sort-candidates (candidates)
  "Return CANDIDATES sorted by display text."
  (sort candidates (lambda (left right)
                     (string-lessp (car left) (car right)))))

(defun mod-mib--read-entity (prompt candidates)
  "Read one MIB entity from CANDIDATES with PROMPT."
  (unless candidates
    (user-error "No matching MIB entries found"))
  (cdr (assoc (completing-read prompt candidates nil t) candidates)))

(defun mod-mib--insert-line (format-string &rest args)
  "Insert FORMAT-STRING with ARGS and a trailing newline."
  (insert (apply #'format format-string args) "\n"))

(defun mod-mib--insert-source (source)
  "Insert SOURCE provenance into the current buffer."
  (mod-mib--insert-line "- MIB: %s" (plist-get source :root-label))
  (mod-mib--insert-line "- Table: %s.dat" (plist-get source :table))
  (mod-mib--insert-line "- Row: %d" (plist-get source :line))
  (mod-mib--insert-line "- File: %s" (abbreviate-file-name (plist-get source :file))))

(defun mod-mib--insert-field-list (row fields)
  "Insert selected FIELDS from ROW."
  (dolist (field fields)
    (let ((value (mod-mib--clean-value (mod-mib--row-value row field))))
      (unless (string-empty-p value)
        (mod-mib--insert-line "- %s: %s" field value)))))

(defun mod-mib--insert-raw-fields (row title)
  "Insert all raw ROW fields under TITLE."
  (mod-mib--insert-line "\n* %s" title)
  (dolist (field (plist-get row :fields))
    (mod-mib--insert-line "- %s: %s" (car field) (cdr field))))

(defun mod-mib--root-entry-for-row (row)
  "Return the configured root entry containing ROW."
  (let* ((source (mod-mib--row-source row))
         (path (plist-get source :root-path)))
    (cl-find-if
     (lambda (entry)
       (file-equal-p (plist-get entry :path) path))
     (mod-mib--root-entries))))

(defun mod-mib--calibration-rows (cpc-row)
  "Return direct calibration/reference rows related to CPC-ROW."
  (let ((root (mod-mib--root-entry-for-row cpc-row))
        (rows nil))
    (dolist (spec '(("CPC_CCAREF" . (("cca" . "CCA_NUMBR")
                                      ("caf" . "CAF_NUMBR")
                                      ("ccs" . "CCS_NUMBR")))
                   ("CPC_PAFREF" . (("paf" . "PAF_NUMBR")
                                     ("pas" . "PAS_NUMBR")))
                   ("CPC_PRFREF" . (("prf" . "PRF_NUMBR")
                                     ("prv" . "PRV_NUMBR")))))
      (let ((ref (mod-mib--clean-value (mod-mib--row-value cpc-row (car spec)))))
        (unless (string-empty-p ref)
          (dolist (table-field (cdr spec))
            (setq rows
                  (append rows
                          (mod-mib--rows-by-field
                           (car table-field) (cdr table-field) ref root)))))))
    rows))

(defun mod-mib--insert-calibrations (cpc-row)
  "Insert calibration/reference details for CPC-ROW."
  (let ((rows (mod-mib--calibration-rows cpc-row)))
    (when rows
      (mod-mib--insert-line "  Calibration / references:")
      (dolist (row rows)
        (let ((source (mod-mib--row-source row)))
          (mod-mib--insert-line
           "  - %s  %s"
           (mod-mib--source-label source)
           (string-join (mapcar (lambda (field)
                                  (format "%s=%s" (car field) (cdr field)))
                                (plist-get row :fields))
                        ", ")))))))

(defun mod-mib--display-detail (buffer-name render-fn source)
  "Display BUFFER-NAME in the utility bay after calling RENDER-FN."
  (setq mod-mib--last-detail-source source)
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (funcall render-fn)
        (goto-char (point-min))
        (special-mode)))
    (if (fboundp 'mod-utility--display-buffer)
        (mod-utility--display-buffer buffer)
      (pop-to-buffer buffer))))

(defun mod-mib--replace-placeholders (template values)
  "Replace TEMPLATE placeholders using VALUES alist."
  (let ((text template))
    (dolist (entry values)
      (setq text
            (replace-regexp-in-string
             (regexp-quote (format "{%s}" (car entry)))
             (or (cdr entry) "")
             text
             t t)))
    text))

(defun mod-mib--tc-parameters (ccf-row)
  "Return joined telecommand parameter plists for CCF-ROW."
  (let* ((name (mod-mib--row-value ccf-row "CCF_CNAME"))
         (root (mod-mib--root-entry-for-row ccf-row)))
    (mapcar
     (lambda (cdf)
       (let* ((pname (mod-mib--row-value cdf "CDF_PNAME"))
              (cpc (mod-mib--first-row-by-field "cpc" "CPC_NAME" pname root))
              (fixed (not (string-empty-p
                           (mod-mib--clean-value
                            (mod-mib--row-value cdf "CDF_VALUE"))))))
         (list :name pname :cdf cdf :cpc cpc :fixed fixed)))
     (mod-mib--rows-by-field "cdf" "CDF_CNAME" name root))))

(defun mod-mib--number-string-p (value)
  "Return non-nil when VALUE looks numeric."
  (string-match-p "\\`[+-]?[0-9]+\\(?:\\.[0-9]+\\)?\\'" (mod-mib--clean-value value)))

(defun mod-mib--alias-values (cpc-row)
  "Return engineering alias values for CPC-ROW."
  (let* ((root (mod-mib--root-entry-for-row cpc-row))
         (ref (mod-mib--clean-value (mod-mib--row-value cpc-row "CPC_PAFREF"))))
    (unless (string-empty-p ref)
      (delq nil
            (mapcar (lambda (row)
                      (let ((alias (mod-mib--clean-value
                                    (mod-mib--row-value row "PAS_ALTXT"))))
                        (unless (string-empty-p alias) alias)))
                    (mod-mib--rows-by-field "pas" "PAS_NUMBR" ref root))))))

(defun mod-mib--range-pairs (cpc-row)
  "Return numeric engineering ranges for CPC-ROW."
  (let* ((root (mod-mib--root-entry-for-row cpc-row))
         (ref (mod-mib--clean-value (mod-mib--row-value cpc-row "CPC_PRFREF"))))
    (unless (string-empty-p ref)
      (delq nil
            (mapcar
             (lambda (row)
               (let ((min (mod-mib--clean-value (mod-mib--row-value row "PRV_MINVAL")))
                     (max (mod-mib--clean-value (mod-mib--row-value row "PRV_MAXVAL"))))
                 (when (and (mod-mib--number-string-p min)
                            (mod-mib--number-string-p max))
                   (cons (string-to-number min)
                         (string-to-number max)))))
             (mod-mib--rows-by-field "prv" "PRV_NUMBR" ref root))))))

(defun mod-mib--format-ranges (ranges)
  "Return display text for numeric RANGES."
  (string-join
   (mapcar (lambda (range)
             (format "%s..%s" (car range) (cdr range)))
           ranges)
   ", "))

(defun mod-mib--tc-parameter-domain (param)
  "Return engineering input metadata for telecommand PARAM."
  (let* ((cdf (plist-get param :cdf))
         (cpc (plist-get param :cpc))
         (description (mod-mib--clean-value
                       (or (mod-mib--row-value cdf "CDF_DESCR")
                           (and cpc (mod-mib--row-value cpc "CPC_DESCR"))
                           "")))
         (unit (and cpc (mod-mib--clean-value
                         (mod-mib--row-value cpc "CPC_UNIT"))))
         (default (and cpc (mod-mib--clean-value
                            (mod-mib--row-value cpc "CPC_DEFVAL"))))
         (ptc (and cpc (mod-mib--clean-value
                        (mod-mib--row-value cpc "CPC_PTC"))))
         (pfc (and cpc (mod-mib--clean-value
                        (mod-mib--row-value cpc "CPC_PFC"))))
         (aliases (and cpc (mod-mib--alias-values cpc)))
         (ranges (and cpc (mod-mib--range-pairs cpc))))
    (list :description description
          :unit unit
          :default default
          :ptc ptc
          :pfc pfc
          :aliases aliases
          :ranges ranges
          :numeric (and cpc (mod-mib--numeric-cpc-p cpc)))))

(defun mod-mib--numeric-cpc-p (cpc-row)
  "Return non-nil when CPC-ROW describes a numeric-looking parameter."
  (member (mod-mib--clean-value (mod-mib--row-value cpc-row "CPC_PTC"))
          mod-mib--numeric-ptcs))

(defun mod-mib--validate-tc-argument (param value &optional domain)
  "Return warning strings for PARAM engineering VALUE."
  (let* ((name (plist-get param :name))
         (domain (or domain (mod-mib--tc-parameter-domain param)))
         (value (mod-mib--clean-value value))
         (aliases (plist-get domain :aliases))
         (ranges (plist-get domain :ranges))
         (known-alias (and aliases (member value aliases)))
         (warnings nil))
    (when (and aliases (not known-alias))
      (push (format "%s: `%s' is not one of the known engineering aliases: %s"
                    name value (string-join aliases ", "))
            warnings))
    (when (and ranges (not aliases))
      (if (not (mod-mib--number-string-p value))
          (push (format "%s: `%s' is not numeric for range validation"
                        name value)
                warnings)
        (let ((number (string-to-number value)))
          (unless (cl-some (lambda (range)
                             (and (<= (car range) number)
                                  (<= number (cdr range))))
                           ranges)
            (push (format "%s: `%s' is outside the known engineering range(s): %s"
                          name value
                          (mod-mib--format-ranges ranges))
                  warnings)))))
    (when (and (not ranges)
               (not aliases)
               (plist-get domain :numeric)
               (not (mod-mib--number-string-p value)))
      (push (format "%s: `%s' is not numeric for PTC/PFC %s/%s"
                    name value
                    (or (plist-get domain :ptc) "")
                    (or (plist-get domain :pfc) ""))
            warnings))
    (nreverse warnings)))

(defun mod-mib--tc-argument-prompt (param domain)
  "Return a helpful minibuffer prompt for PARAM using DOMAIN."
  (let ((parts (delq nil
                     (list
                      (let ((description (plist-get domain :description)))
                        (unless (string-empty-p (or description ""))
                          description))
                      (let ((aliases (plist-get domain :aliases)))
                        (when aliases
                          (format "values %s" (string-join aliases ", "))))
                      (let ((ranges (plist-get domain :ranges)))
                        (when (and ranges (not (plist-get domain :aliases)))
                          (format "range %s" (mod-mib--format-ranges ranges))))
                      (let ((unit (plist-get domain :unit)))
                        (unless (string-empty-p (or unit ""))
                          (format "unit %s" unit)))
                      (let ((default (plist-get domain :default)))
                        (unless (string-empty-p (or default ""))
                          (format "default %s" default)))))))
    (format "%s%s: "
            (plist-get param :name)
            (if parts
                (format " (%s)" (string-join parts "; "))
              ""))))

(defun mod-mib--read-tc-argument (param)
  "Read one engineering value for telecommand PARAM."
  (let* ((domain (mod-mib--tc-parameter-domain param))
         (aliases (plist-get domain :aliases))
         (default (plist-get domain :default))
         (prompt (mod-mib--tc-argument-prompt param domain))
         (default (unless (string-empty-p (or default "")) default)))
    (if aliases
        (completing-read prompt aliases nil nil nil nil default)
      (read-string prompt nil nil default))))

(defun mod-mib--render-tc-argument (argument)
  "Render one ARGUMENT plist using the user argument template."
  (mod-mib--replace-placeholders
   orbit-user-mib-telecommand-argument-template
   `(("name" . ,(plist-get argument :name))
     ("value" . ,(plist-get argument :value)))))

(defun mod-mib--render-telecommand (ccf-row arguments)
  "Render CCF-ROW and ARGUMENTS using the user telecommand template."
  (let* ((source (mod-mib--row-source ccf-row))
         (argument-text (string-join
                         (mapcar #'mod-mib--render-tc-argument arguments)
                         orbit-user-mib-telecommand-argument-separator)))
    (mod-mib--replace-placeholders
     orbit-user-mib-telecommand-template
     `(("type" . ,(mod-mib--row-value ccf-row "CCF_TYPE"))
       ("stype" . ,(mod-mib--row-value ccf-row "CCF_STYPE"))
       ("apid" . ,(mod-mib--row-value ccf-row "CCF_APID"))
       ("mnemo" . ,(mod-mib--row-value ccf-row "CCF_CNAME"))
       ("description" . ,(or (mod-mib--row-value ccf-row "CCF_DESCR") ""))
       ("mib" . ,(plist-get source :root-label))
       ("arguments" . ,argument-text)))))

(defun mod-mib--build-telecommand-insertion (ccf-row values)
  "Build insertion data for CCF-ROW using VALUES keyed by parameter name."
  (let ((params (mod-mib--tc-parameters ccf-row))
        (arguments nil)
        (omitted nil)
        (warnings nil))
    (dolist (param params)
      (if (plist-get param :fixed)
          (push param omitted)
        (let* ((name (plist-get param :name))
               (value (mod-mib--clean-value (cdr (assoc name values))))
               (domain (mod-mib--tc-parameter-domain param))
               (argument (list :name name
                               :value value
                               :param param
                               :domain domain
                               :warnings (mod-mib--validate-tc-argument
                                          param value domain))))
          (setq warnings (append warnings (plist-get argument :warnings)))
          (push argument arguments))))
    (setq arguments (nreverse arguments)
          omitted (nreverse omitted))
    (list :ccf ccf-row
          :arguments arguments
          :omitted omitted
          :warnings warnings
          :command (mod-mib--render-telecommand ccf-row arguments))))

(defun mod-mib--skip-telecommand-arguments (ccf-row)
  "Build insertion data for CCF-ROW without prompting for arguments."
  (let* ((params (mod-mib--tc-parameters ccf-row))
         (omitted (cl-remove-if-not (lambda (param)
                                      (plist-get param :fixed))
                                    params))
         (skipped (cl-remove-if (lambda (param)
                                  (plist-get param :fixed))
                                params)))
    (list :ccf ccf-row
          :arguments nil
          :omitted omitted
          :skipped skipped
          :warnings nil
          :command (mod-mib--render-telecommand ccf-row nil))))

(defun mod-mib--read-telecommand-argument-mode (ccf-row)
  "Read whether to build or skip arguments for CCF-ROW."
  (let* ((variable-count
          (length (cl-remove-if (lambda (param)
                                  (plist-get param :fixed))
                                (mod-mib--tc-parameters ccf-row))))
         (choices '(("Build arguments" . build)
                    ("Skip arguments" . skip))))
    (if (zerop variable-count)
        'skip
      (cdr (assoc (completing-read
                   (format "Arguments (%d variable): " variable-count)
                   choices nil t nil nil "Build arguments")
                  choices)))))

(defun mod-mib--prompt-telecommand-insertion (ccf-row)
  "Prompt for variable argument values and build insertion data for CCF-ROW."
  (let ((values nil))
    (dolist (param (mod-mib--tc-parameters ccf-row))
      (unless (plist-get param :fixed)
        (push (cons (plist-get param :name)
                    (mod-mib--read-tc-argument param))
              values)))
    (mod-mib--build-telecommand-insertion ccf-row (nreverse values))))

(defun mod-mib--preview-telecommand-insertion (data)
  "Preview telecommand insertion DATA in the utility bay."
  (let* ((ccf (plist-get data :ccf))
         (source (mod-mib--row-source ccf))
         (name (mod-mib--row-value ccf "CCF_CNAME")))
    (mod-mib--display-detail
     (format "*MIB Insert TC: %s*" name)
     (lambda ()
       (mod-mib--insert-line "* Insert Telecommand %s" name)
       (mod-mib--insert-line "\n* Source")
       (mod-mib--insert-source source)
       (mod-mib--insert-line "\n* Summary")
       (mod-mib--insert-field-list ccf mod-mib--tc-summary-fields)
       (mod-mib--insert-line "\n* Variable Arguments")
       (if-let* ((arguments (plist-get data :arguments)))
           (dolist (argument arguments)
             (let* ((param (plist-get argument :param))
                    (cpc (plist-get param :cpc))
                    (domain (or (plist-get argument :domain)
                                (mod-mib--tc-parameter-domain param))))
               (mod-mib--insert-line "- %s: %s"
                                     (plist-get argument :name)
                                     (plist-get argument :value))
               (when cpc
                 (mod-mib--insert-line "  CPC: %s, PTC/PFC %s/%s, unit %s"
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_DESCR"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_PTC"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_PFC"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_UNIT"))))
               (when-let* ((aliases (plist-get domain :aliases)))
                 (mod-mib--insert-line "  Allowed engineering aliases: %s"
                                       (string-join aliases ", ")))
               (when-let* ((ranges (and (not (plist-get domain :aliases))
                                        (plist-get domain :ranges))))
                 (mod-mib--insert-line "  Engineering range: %s"
                                       (mod-mib--format-ranges ranges)))))
         (if-let* ((skipped (plist-get data :skipped)))
             (progn
               (mod-mib--insert-line "- Skipped; {arguments} will be empty")
               (dolist (param skipped)
                 (mod-mib--insert-line "  - %s" (plist-get param :name))))
           (mod-mib--insert-line "- None")))
       (mod-mib--insert-line "\n* Omitted Fixed Values")
       (if-let* ((omitted (plist-get data :omitted)))
           (dolist (param omitted)
             (let ((cdf (plist-get param :cdf)))
               (mod-mib--insert-line "- %s: %s"
                                     (plist-get param :name)
                                     (mod-mib--clean-value
                                      (mod-mib--row-value cdf "CDF_VALUE")))))
         (mod-mib--insert-line "- None"))
       (mod-mib--insert-line "\n* Validation")
       (if-let* ((warnings (plist-get data :warnings)))
           (dolist (warning warnings)
             (mod-mib--insert-line "- WARNING: %s" warning))
         (mod-mib--insert-line "- OK"))
       (mod-mib--insert-line "\n* Command")
       (mod-mib--insert-line "%s" (plist-get data :command)))
     source)))

(defun mod-mib--confirm-telecommand-insertion (data)
  "Return non-nil when DATA should be inserted."
  (let ((prompt (if (plist-get data :warnings)
                    "Validation warnings exist. Insert telecommand anyway? "
                  "Insert telecommand? ")))
    (yes-or-no-p prompt)))

(defun mod-mib-insert-telecommand ()
  "Build and insert a telecommand call from the global MIB index."
  (interactive)
  (mod-mib--ensure-roots)
  (let* ((target-buffer (current-buffer))
         (target-window (selected-window))
         (target-point (point-marker))
         (entity (mod-mib--read-entity "Telecommand: "
                                       (mod-mib--tc-candidates)))
         (row (plist-get entity :row))
         (mode (mod-mib--read-telecommand-argument-mode row))
         (data (if (eq mode 'skip)
                   (mod-mib--skip-telecommand-arguments row)
                 (mod-mib--prompt-telecommand-insertion row))))
    (mod-mib--preview-telecommand-insertion data)
    (when (mod-mib--confirm-telecommand-insertion data)
      (with-current-buffer target-buffer
        (goto-char target-point)
        (insert (plist-get data :command)))
      (when (window-live-p target-window)
        (select-window target-window))
      (message "Inserted telecommand %s"
               (mod-mib--row-value row "CCF_CNAME")))))

(defun mod-mib--tc-candidates ()
  "Return telecommand completion candidates."
  (mod-mib--sort-candidates
   (mapcar
    (lambda (row)
      (mod-mib--candidate
       'tc row
       (mod-mib--row-value row "CCF_CNAME")
       (mod-mib--row-value row "CCF_TYPE")
       (mod-mib--row-value row "CCF_STYPE")
       (or (mod-mib--row-value row "CCF_DESCR")
           (mod-mib--row-value row "CCF_DESCR2"))))
    (mod-mib--rows "ccf"))))

(defun mod-mib--tm-packet-candidates ()
  "Return TM packet completion candidates."
  (mod-mib--sort-candidates
   (mapcar
    (lambda (row)
      (mod-mib--candidate
       'tm-packet row
       (format "SPID:%s" (mod-mib--row-value row "PID_SPID"))
       (mod-mib--row-value row "PID_TYPE")
       (mod-mib--row-value row "PID_STYPE")
       (mod-mib--row-value row "PID_DESCR")))
    (mod-mib--rows "pid"))))

(defun mod-mib--tm-parameter-candidates ()
  "Return TM parameter completion candidates."
  (mod-mib--sort-candidates
   (mapcar
    (lambda (row)
      (mod-mib--candidate
       'tm-parameter row
       (mod-mib--row-value row "PCF_NAME")
       (mod-mib--row-value row "PCF_SPTYPE")
       nil
       (mod-mib--row-value row "PCF_DESCR")))
    (mod-mib--rows "pcf"))))

(defun mod-mib--show-telecommand (row)
  "Render telecommand ROW details."
  (let* ((name (mod-mib--row-value row "CCF_CNAME"))
         (root (mod-mib--root-entry-for-row row))
         (params (mod-mib--rows-by-field "cdf" "CDF_CNAME" name root))
         (source (mod-mib--row-source row)))
    (mod-mib--display-detail
     (format "*MIB TC: %s*" name)
     (lambda ()
       (mod-mib--insert-line "* Telecommand %s" name)
       (mod-mib--insert-line "\n* Source")
       (mod-mib--insert-source source)
       (mod-mib--insert-line "\n* Summary")
       (mod-mib--insert-field-list row mod-mib--tc-summary-fields)
       (mod-mib--insert-line "\n* Parameters")
       (if params
           (dolist (param params)
             (let* ((pname (mod-mib--row-value param "CDF_PNAME"))
                    (cpc (mod-mib--first-row-by-field "cpc" "CPC_NAME" pname root)))
               (mod-mib--insert-line "- %s  %s  bit:%s  len:%s  value:%s"
                                     pname
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "CDF_DESCR"))
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "CDF_BIT"))
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "CDF_ELLEN"))
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "CDF_VALUE")))
               (when cpc
                 (mod-mib--insert-line "  CPC: %s, PTC/PFC %s/%s, unit %s, default %s"
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_DESCR"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_PTC"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_PFC"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_UNIT"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value cpc "CPC_DEFVAL")))
                 (mod-mib--insert-calibrations cpc))))
         (mod-mib--insert-line "- No CDF parameters found"))
       (mod-mib--insert-raw-fields row "Raw CCF Fields"))
     source)))

(defun mod-mib--show-tm-packet (row)
  "Render TM packet ROW details."
  (let* ((spid (mod-mib--row-value row "PID_SPID"))
         (root (mod-mib--root-entry-for-row row))
         (params (mod-mib--rows-by-field "plf" "PLF_SPID" spid root))
         (source (mod-mib--row-source row)))
    (mod-mib--display-detail
     (format "*MIB TM Packet: %s*" spid)
     (lambda ()
       (mod-mib--insert-line "* TM Packet SPID %s" spid)
       (mod-mib--insert-line "\n* Source")
       (mod-mib--insert-source source)
       (mod-mib--insert-line "\n* Summary")
       (mod-mib--insert-field-list row mod-mib--tm-packet-summary-fields)
       (mod-mib--insert-line "\n* Parameters")
       (if params
           (dolist (param params)
             (let* ((pname (mod-mib--row-value param "PLF_NAME"))
                    (pcf (mod-mib--first-row-by-field "pcf" "PCF_NAME" pname root)))
               (mod-mib--insert-line "- %s  off:%s.%s  occ:%s"
                                     pname
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "PLF_OFFBY"))
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "PLF_OFFBI"))
                                     (mod-mib--clean-value
                                      (mod-mib--row-value param "PLF_NBOCC")))
               (when pcf
                 (mod-mib--insert-line "  PCF: %s, PTC/PFC %s/%s, unit %s, width %s"
                                       (mod-mib--clean-value
                                        (mod-mib--row-value pcf "PCF_DESCR"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value pcf "PCF_PTC"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value pcf "PCF_PFC"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value pcf "PCF_UNIT"))
                                       (mod-mib--clean-value
                                        (mod-mib--row-value pcf "PCF_WIDTH"))))))
         (mod-mib--insert-line "- No PLF parameters found"))
       (mod-mib--insert-raw-fields row "Raw PID Fields"))
     source)))

(defun mod-mib--show-tm-parameter (row)
  "Render TM parameter ROW details."
  (let* ((name (mod-mib--row-value row "PCF_NAME"))
         (root (mod-mib--root-entry-for-row row))
         (occurrences (mod-mib--rows-by-field "plf" "PLF_NAME" name root))
         (source (mod-mib--row-source row)))
    (mod-mib--display-detail
     (format "*MIB TM Parameter: %s*" name)
     (lambda ()
       (mod-mib--insert-line "* TM Parameter %s" name)
       (mod-mib--insert-line "\n* Source")
       (mod-mib--insert-source source)
       (mod-mib--insert-line "\n* Summary")
       (mod-mib--insert-field-list row mod-mib--tm-parameter-summary-fields)
       (mod-mib--insert-line "\n* Packet Occurrences")
       (if occurrences
           (dolist (occurrence occurrences)
             (let* ((spid (mod-mib--row-value occurrence "PLF_SPID"))
                    (pid (mod-mib--first-row-by-field "pid" "PID_SPID" spid root)))
               (mod-mib--insert-line
                "- SPID %s  type:%s  stype:%s  off:%s.%s  %s"
                spid
                (if pid (mod-mib--clean-value (mod-mib--row-value pid "PID_TYPE")) "")
                (if pid (mod-mib--clean-value (mod-mib--row-value pid "PID_STYPE")) "")
                (mod-mib--clean-value (mod-mib--row-value occurrence "PLF_OFFBY"))
                (mod-mib--clean-value (mod-mib--row-value occurrence "PLF_OFFBI"))
                (if pid (mod-mib--clean-value (mod-mib--row-value pid "PID_DESCR")) ""))))
         (mod-mib--insert-line "- No PLF packet occurrences found"))
       (mod-mib--insert-raw-fields row "Raw PCF Fields"))
     source)))

(defun mod-mib-lookup-telecommand ()
  "Lookup a telecommand from the global MIB index."
  (interactive)
  (mod-mib--ensure-roots)
  (let* ((entity (mod-mib--read-entity "Telecommand: "
                                       (mod-mib--tc-candidates)))
         (row (plist-get entity :row)))
    (mod-mib--show-telecommand row)))

(defun mod-mib-lookup-tm-packet ()
  "Lookup a TM packet from the global MIB index."
  (interactive)
  (mod-mib--ensure-roots)
  (let* ((entity (mod-mib--read-entity "TM packet: "
                                       (mod-mib--tm-packet-candidates)))
         (row (plist-get entity :row)))
    (mod-mib--show-tm-packet row)))

(defun mod-mib-lookup-tm-parameter ()
  "Lookup a TM parameter from the global MIB index."
  (interactive)
  (mod-mib--ensure-roots)
  (let* ((entity (mod-mib--read-entity "TM parameter: "
                                       (mod-mib--tm-parameter-candidates)))
         (row (plist-get entity :row)))
    (mod-mib--show-tm-parameter row)))

(defun mod-mib-open-detail-source ()
  "Open the source row for the most recent MIB detail buffer."
  (interactive)
  (unless mod-mib--last-detail-source
    (user-error "No MIB detail source available"))
  (let ((file (plist-get mod-mib--last-detail-source :file))
        (line (plist-get mod-mib--last-detail-source :line)))
    (find-file file)
    (goto-char (point-min))
    (forward-line (1- line))))

(defun mod-mib-index-status ()
  "Show global MIB index status in the utility bay."
  (interactive)
  (mod-mib--ensure-roots)
  (let ((roots (mod-mib--root-entries)))
    (mod-mib--display-detail
     "*MIB Index Status*"
     (lambda ()
       (mod-mib--insert-line "* MIB Index Status")
       (mod-mib--insert-line "\n* Roots")
       (dolist (root roots)
         (mod-mib--insert-line "- %s  %s"
                               (plist-get root :label)
                               (abbreviate-file-name (plist-get root :path))))
       (mod-mib--insert-line "\n* Tables")
       (dolist (table '("ccf" "cdf" "cpc" "pid" "plf" "pcf" "cca" "caf" "paf" "pas" "prf" "prv"))
         (let ((count (length (mod-mib--rows table))))
           (when (> count 0)
             (mod-mib--insert-line "- %s.dat: %d rows" table count)))))
     nil)))

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
