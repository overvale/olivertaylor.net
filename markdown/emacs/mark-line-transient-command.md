---
title: "Mark Line &amp; Marking Transient Command"
dateline: 2021, Summer
author: Oliver Taylor
category: emacs
---


Emacs has a lot of commands for marking (selecting) things. You can find them all by typing `M-x mark-` and seeing the available options. You can also read about (most of) them in the [manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Marking-Objects.html). They all work the same way, they leave the point where it is and extend the region (selection) forward by a given about (word, sentence, etc) by moving the "mark" (end of region).

One command that is missing (no idea why) is one for marking lines. Fortunately, the code for `mark-end-of-sentence` is really simple and easily adapted to mark lines.

``` elisp
(defun mark-line (arg)
  "Put mark at end of line.
ARG works as in `forward-line'.  If this command is repeated,
it marks the next ARG lines after the ones already marked."
  (interactive "p")
  (push-mark
   (save-excursion
     (if (and (eq last-command this-command) (mark t))
     (goto-char (mark)))
     (forward-line arg)
     (point))
   nil t))
```

Additionally I have `mark-end-of-sentence` aliased to `mark-sentence` to be more consistent with the other mark commands.

I have also found it valuable to create a far more logical set of bindings for all these commands. I use the transient package for this, but you could set this up with a prefix binding or using another method you prefer.

``` elisp
(transient-define-prefix general-transient--mark ()
  "Transient for setting the mark."
  :transient-suffix 'transient--do-stay
  :transient-non-suffix 'transient--do-exit
  ["Mark"
   [("w" "Word" mark-word)
    ("s" "Sexp" mark-sexp)
    ("d" "Defun" mark-defun)]
   [("n" "Line" mark-line)
    (")" "Sentence" mark-sentence)
    ("}" "Paragraph" mark-paragraph)]
   [("<" "Beginning of Buffer" mark-beginning-of-buffer)
    (">" "End of Buffer" mark-end-of-buffer)]
   [("x" "Exchange Point/Mark" exchange-point-and-mark :transient nil)
    ("q" "Quit" transient-quit-all)]])
```
