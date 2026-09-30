---
title: "Keymap Prompts"
dateline: 2021, Summer
author: Oliver Taylor
category: emacs
---


If you bind a key to a keymap Emacs will display a useful prompt in the echo area. Quite handy for rarely used keymaps with only a few bindings.

This is (of course) well documented in the Emacs info manuals, but my discovery of it should be credited to [u/oantolin on reddit](https://old.reddit.com/r/emacs/comments/ch016m/how_to_tell_if_a_keymap_is_active/euz3rfs/?context=3).

Minor update: it is better to use `define-prefix-command` as this creates both a keymap and an interactive function. I've found that binding a key to a variable, instead of an interactive function, is not widely supported.

``` elisp
(define-prefix-command 'pkg-ops-map nil "Packages")

(let ((map pkg-ops-map))
  (define-key map "h" '("describe" . describe-package))
  (define-key map "a" '("autoremove" . package-autoremove))
  (define-key map "d" '("delete" . package-delete))
  (define-key map "i" '("install" . package-install))
  (define-key map "s" '("selected" . package-install-selected-packages))
  (define-key map "r" '("refresh" . package-refresh-contents))
  (define-key map "l" '("list" . list-packages)))

(global-set-key (kbd "C-c p") 'pkg-ops-map)
```
