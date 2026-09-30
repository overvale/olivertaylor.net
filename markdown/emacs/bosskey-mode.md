---
title: "Emacs Keybindings That Won‘t Get Overridden by Minor Modes"
dateline: 2021, Summer
author: Oliver Taylor
category: emacs
---


Recently I‘ve been making an effort to better understand what's happening under the hood of some of the packages I use, and I got curious about how [bind-key](https://melpa.org/#/bind-key) manages to ensure my bindings are never overridden by minor modes (which can be very annoying).

To understand how bind-key does it you need to learn two things. First, you need to understand the order of priority which Emacs assigns to different keymaps, which is well explained at [Mastering Emacs](https://www.masteringemacs.org/article/mastering-key-bindings-emacs#keymap-lookup-order). Second, you should read [the bind-key source code](https://github.com/jwiegley/use-package/blob/master/bind-key.el).

The technique bind-key uses is to create a minor mode that you bind keys in, and insert those bindings into the variable `emulation-mode-map-alists`. Any keymaps in that variable take priority over all other minor modes.

The code is actually very simple:

``` elisp
;; First, create the keymap
(defvar bosskey-mode-map (make-keymap)
  "Keymap for bosskey-mode")

;; Next, create the minor mode, switch it on by default, make it global,
;; and assign the keymap to it.
(define-minor-mode bosskey-mode
  "Minor mode for my personal keybindings."
  :init-value t
  :global t
  :keymap bosskey-mode-map)

;; Next, add the keymap to `emulation-mode-map-alists'
(add-to-list 'emulation-mode-map-alists
             `((bosskey-mode . ,bosskey-mode-map)))

;; Finally, bind your keys!
(define-key bosskey-mode-map (kbd "C-<return>") 'execute-extended-command)
```

Now, some people would argue that it's much simpler to just use the bind-key package, but I've found it very helpful to learn this stuff for times when I can't use a package and need to create my own solutions.
