---
title: "How Package.el Works with Use Package"
dateline: 2021-04-31
author: Oliver Taylor
category: emacs
---


*I suppose the below could be framed simply as a complaint that use-package does not update `package-selected-packages`. Fair enough.*

I've recently moved from Straight to package.el for package management (long story), and have been reading-up on how package.el actually works, I took some notes and figured I'd share. I'm surprised that so few configs I see on GitHub take into account the subtleties of how package.el works, particularly in how it interacts with Use Package.

Unsurprisingly, all of this is well documented in `(info "(elisp) Startup Summary")` and `(info "(emacs) Packages")` so I'm not writing anything groundbreaking here, just summarizing available information.

------------------------------------------------------------------------

Emacs activates all installed packages before reading the user-init-file unless you've set `package-enable-at-startup` to nil in the early init file. I'm sure this activation does many things but the most important (to me) is that it creates autoloads for all your packages. That way you can bind a key to a package's command, or run it via `M-x`, without actually loading the package first.

If you want to restrict exactly which installed packages are activated at startup you can customize the `package-load-list`, but you have to do it before your packages are activated.

When you interactively install a package (via `M-x package-install` or via the Package Menu) Emacs adds that package to `package-selected-packages` in your custom-file, which is supposed to be the canonical list of packages you'd like installed. package.el includes commands for installing all your "selected" packages, and removing any installed package that is not "selected".

Use Package does not update `package-selected-packages`, nor does it have the ability to delete installed packages. This means every package you've ever installed via Use Package's `:ensure` function is activated when Emacs starts up, even if you've removed all traces of it from your init file. And to remove the packages from your system you'll have to manually compare what's installed against what's in your init file.

If you've disabled `package-enable-at-startup` in your early init file and use <span href"https:="" github.com="" raxod502="" straight.el"="">Straight</span> (or something similar) to install packages, you won't have this problem as Straight is designed to never load anything not declared in your init file, regardless of if it is installed or not.

------------------------------------------------------------------------

What I learned…

If you're using an alternative to package.el such as Straight, don't forget to place `(setq package-enable-at-startup nil)` in your early init file.

If you're using Use Package with package.el, and you want to manage your packages via your init file and **not** via interactive customization, you should really consider manually maintaining `package-selected-packages` somewhere in your init file, and abstaining from Use Package's `:ensure` feature. Think of Use Package strictly as a way to configure packages, not installing them. This will allow you to take advantage of package.el's package management features.

The following is everything you need to get your packages installed and configured using package.el + Use Package:

``` elisp
(require 'package)

;; (package-initialize) is unnecessary since I have not disabled
;; package-enable-at-startup in early-init.

;; Add MELPA to package sources (optional)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; Prefer GNU over MELPA (optional)
(setq package-archive-priorities '(("gnu" . 20)("melpa" . 10)))

(setq package-selected-packages
  '(use-package
    vertico
    orderless))

;; Install packages with (package-install-selected-packages)
;; Remove packages with (package-autoremove)
;; If you want to automate that, maybe add them to your 'emacs-startup-hook'?

(eval-when-compile
  (require 'use-package))

(use-package orderless
  :demand
  :custom
  (completion-styles '(orderless))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles . (partial-completion))))))

(use-package vertico
  :init (vertico-mode))
```

To install a new package, simply add it your package-selected-packages list and call `(package-install-selected-packages)`.

Hope this is useful to someone.

[Discussion on r/emacs](https://www.reddit.com/r/emacs/comments/np6ey4/how_packageel_works_with_use_package/).
