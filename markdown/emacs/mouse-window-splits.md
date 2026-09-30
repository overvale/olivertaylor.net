---
title: "Splitting Windows With the Mouse"
dateline: 2021, Spring
author: Oliver Taylor
category: emacs
---


Did you know you can create and delete window splits with the mouse? Also, the mode-line has its own... keymap?

``` elisp
(global-set-key [mode-line S-mouse-1] 'mouse-delete-other-windows)
(global-set-key [mode-line M-mouse-1] 'mouse-delete-window)
(global-set-key [mode-line C-mouse-1] 'mouse-split-window-horizontally)
```
