---
title: "Quick Help: Emacs as a Text Productivity Platform"
dateline: November 2021
author: Oliver Taylor
category: emacs
---


Reading blog posts about Emacs is fun, watching videos on YouTube is sometimes useful (though often tedious), but I've learned the most, and been influenced the most, by reading the actual code of other people's init files.

Now, most init files you run in to are endless repetitions of use-package statements. Yuck. What fun is that? And, honestly, what's to learn from it? Me, I'd rather read the config of a lunatic who has been using Emacs for 30 years, has a 20,000-line config, and has never installed a single package. *That's* where you'll find the good stuff, the stuff that makes you think about Emacs's possibilities in a new light.

I recently saw something in [such a config](https://svn.red-bean.com/repos/kfogel/trunk/.emacs) that blew my mind because it's such a simple idea – but it's an idea that would only occur to you if you don't think of Emacs as an *editor* but as a *productivity platform*.

I recently started a new job and my work computer is a Windows 7 machine. Let me tell you what's no fun at all: a Windows 7 machine is no fun at all. Convincing IT to install Emacs was a great idea because now Emacs is my home away from home at work. I use it to keep all my notes, track my todo list and things to follow up on, and I've started to use it for more and more things like a calendar, a calculator, and a simple way of drafting emails – but the most fun thing I've set up is a quick way of bringing up reference material.

There are 14 separate departments I need to work with, in 4 separate time-zones, and each one of them has at least three people I need to keep in touch with about different things, that's ~42 people in 4 time zones! As a new employee, how can I be expected to keep all that straight? Sure, the company wiki displays that information, but in a format that takes a while to navigate. Emacs to the rescue!

The idea is to create buffers of reference material that are super easy to call-up and super easy to dismiss. In the past I've put this information in *files* on the computer and then created quick ways of opening those files, but why not just do it with code?

Example time. Try pasting the below in your Scratch buffer and evaluating it.

``` elisp
(let ((buffer-name "*Quick Help*"))
  (with-current-buffer (get-buffer-create buffer-name)
    (insert "IT HOTLINE: 855-555-5555")
    (goto-char (point-min))
    (local-set-key (kbd "q") 'kill-buffer-and-window)
    (not-modified)
    (read-only-mode))
  (pop-to-buffer buffer-name '((display-buffer-below-selected)
                               (window-parameters . ((no-other-window . nil)))
                               (window-height . fit-window-to-buffer))))
```

This will create a small window, below your current one, that displays the IT Hotline number, which you can quickly dismiss by pressing "q".

Now all that remains to be done is to turn this code into a macro that can be used repeatedly, define the reference help we want, and give the generated functions a nice set of bindings.

``` elisp
(defmacro quick-help (name buffer text)
  "Macro for creating callable functions that display help.
Where NAME is name of function, BUFFER is name of buffer, and TEXT is displayed."
  (declare (indent defun))
  `(progn
     (defun ,name nil
       ,buffer
       (interactive)
       (let ((qh-buff (concat "*Quick Help: " ,buffer "*"))
             (qh-text ,text))
         (get-buffer-create qh-buff)
         (with-current-buffer qh-buff
           (insert qh-text)
           (goto-char (point-min))
           (not-modified)
           (read-only-mode)
           (local-set-key (kbd "C-g") (lambda () (interactive) (other-window -1)))
           (local-set-key (kbd "q") 'kill-buffer-and-window))
         (pop-to-buffer qh-buff '((display-buffer-below-selected)
                                  (window-parameters . ((no-other-window . nil)))
                                  (window-height . fit-window-to-buffer)))
         (message "C-g - Previous Window, q - Remove Window")))))

(quick-help qh--it-hotline
  "IT Hotline"
  "IT HOTLINE: 855-555-5555")

(quick-help qh--departments
  "Departments"
  "\
| Department | Manager     | Extension | Time Zone |
|------------+-------------+-----------+-----------|
| Sales      | Dave F      |        16 | LA        |
| IT         | Sydney R    |       198 | NY        |
| Support    | Ellie T     |        29 | DEN       |
| Shipping   | Shaun D     |       345 | ATL       |
| Recieving  | Brian C     |       876 | NY        |
| Marketing  | Elizabeth W |        12 | LA        |
| Coffee     | Donna F     |        34 | NY        |")

(quick-help qh--wheather
  "Weather Whether Wether"
  "The climate is made up of “WEATHER”;
WHETHER it is nice out depends on whether it is raining or not.
A WETHER is just a castrated sheep.")

(define-prefix-command 'quick-help-prompt nil "Quick Help")

(let ((map quick-help-prompt))
  (define-key map "i" '("IT Hotline" . qh--it-hotline))
  (define-key map "d" '("Departments" . qh--departments))
  (define-key map "w" '("Weather Whether Wether" . qh--wheather)))

(global-set-key (kbd "C-c h") 'quick-help-prompt)
```

Now, any time you need that reference material you can call it up directly in Emacs as naturally as you would the definition of a function or variable.

*Emacs isn't an editor, it is a text productivity platform.*
