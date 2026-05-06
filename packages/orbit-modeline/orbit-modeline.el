;;; orbit-modeline.el --- Orbit modeline package -*- lexical-binding: t; -*-

(require 'orbit-modeline-layout)

(defun orbit-modeline-install ()
  "Install the orbit modeline as the default mode line."
  (setq-default mode-line-format '("%e" (:eval (orbit-modeline-format)))))

(provide 'orbit-modeline)

;;; orbit-modeline.el ends here
