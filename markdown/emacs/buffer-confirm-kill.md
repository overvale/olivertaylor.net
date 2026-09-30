---
title: "Confirm Killing Modified Buffers"
dateline: 2021-09-04
author: Oliver Taylor
category: emacs
---


In Emacs, a file-visiting buffer is one where the buffer displays the contents of a file. A regular buffer simply displays text: the output of a command, documentation, messages, an unsaved document, etc. Emacs uses these regular buffers to display its user interface in the same way that most apps use windows.

When killing a file-visiting buffer that has unsaved changes Emacs will prompt you to confirm that action since you would lose those unsaved changes to the file. However, when killing a modified regular buffer Emacs does not prompt you at all. I imagine the reasoning for this is simply that Emacs creates and kills many temporary buffers to display its user interface, and no user wants to confirm killing every one of those buffers. This means that Emacs assumes the user does not want to lose modifications to file-visiting buffers but that losing modifications to regular buffers is just fine.

In most cases this is a fair assumption, but there are times when the user probably wants Emacs to prompt them for confirmation when killing modified regular buffers. For example, after the user has explicitly created a buffer with a particular name. In that case the user probably wants to confirm the loss of that data.

You can, however, protect against the loss of modified regular buffers when you *exit* Emacs by setting the buffer-local variable `buffer-offer-save`. But no such variable exists for when you try to kill a modified buffer. This means *there is no mechanism for protecting modified regular buffers from being killed.*

As with anything Emacs, it is not hard to fix this problem. You simply need a new buffer-local variable you can set when you want to protect a regular buffer, and a function to attach to `kill-buffer-query-functions`.

This is what I have in my init file:

``` elisp
(defvar-local buffer-confirm-kill nil
  "Non-nil means confirm killing buffer when modified.
Variable is checked by `buffer-confirm-kill-p'.")

(defun buffer-confirm-kill-p ()
  "Return nil if buffer is modified and `buffer-confirm-kill' is t.
This function is designed to be called from `kill-buffer-query-functions'."
  (if (and (buffer-modified-p)
           buffer-confirm-kill)
      (yes-or-no-p
       (format "Buffer %S is modified; kill anyway? " (buffer-name)))
    t))

(add-hook 'kill-buffer-query-functions #'buffer-confirm-kill-p)
```

Now, one simply needs to set the variable `buffer-confirm-kill` in any buffer whose modifications you want protected. A simple example would be a function for creating a new buffer:

``` elisp
(defun new-buffer (name)
  "Create a new buffer, prompting for NAME."
  (interactive
   (list (read-string
          "Create buffer (default \"untitled\"): "
          nil nil "untitled")))
  (let ((buffer (generate-new-buffer name)))
    (switch-to-buffer buffer)
    (setq-local buffer-offer-save t)
    (setq-local buffer-confirm-kill t)))
```

This new buffer is now protected from data-loss when the user attempts to either exit Emacs or kill the buffer.
