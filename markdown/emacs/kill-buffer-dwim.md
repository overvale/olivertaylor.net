---
title: "Kill Buffer DWIM"
dateline: 2021, Summer
author: Oliver Taylor
category: emacs
---


When you call `kill-buffer` Emacs prompts you for which buffer you'd like to kill. The default choice is the current buffer, which is good because 9 times out of 10 that's the buffer I want to kill, but confirming that choice every time is tedious.

Emacs has a wonderful convention of "do what I mean" (DWIM) commands, versions of commands which do one thing if a condition is met and another if it isn't. My version of `kill-buffer` should kill the current buffer by default, and if it is prefixed by the universal argument I should be prompted for which buffer I'd like to kill. The best of both worlds I think.

``` elisp
(defun kill-buffer-dwim (&optional u-arg)
  "Call kill-current-buffer, with C-u: call kill-buffer."
  (interactive "P")
  (if u-arg
      (call-interactively 'kill-buffer)
    (call-interactively 'kill-current-buffer)))
```
