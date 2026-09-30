---
title: "Custom Scratch Buffers"
dateline: 2021, August
author: Oliver Taylor
category: emacs
---


It can be useful to create temporary scratch buffers in specific languages. [A number of packages exist to help you do this](https://melpa.org/#/?q=scratch%20buffer). I, however, prefer writing code over installing packages, so I came up with the following:

``` elisp
(defvar scratch-org-initial-message "# Org Mode Scratch Buffer\n\n"
  "Message to be inserted in org scratch buffer.")

(defvar scratch-org-buffer "*scratch-org*"
  "Name of org-mode scratch buffer.")

(defun scratch-buffer-org ()
  "Create a *scratch* buffer in Org Mode and switch to it."
  (interactive)
  (let ((buf scratch-org-buffer))
    (if (get-buffer buf)
        (switch-to-buffer buf)
      (progn
        (switch-to-buffer buf)
        (org-mode)
        (with-current-buffer buf
          (setq-local buffer-confirm-kill t)
          (setq-local buffer-offer-save t)
          (insert scratch-org-initial-message)
          (not-modified))))))
```

The above function sets the variable `buffer-confirm-kill` which I wrote [a separate note about](/emacs/buffer-confirm-kill).
