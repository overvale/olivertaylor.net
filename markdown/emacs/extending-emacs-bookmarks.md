---
title: "Extending Emacs Bookmarks to Work With EWW"
dateline: 2021-02-07
author: Oliver Taylor
category: emacs
---


[Emacs bookmarks](https://www.gnu.org/software/emacs/manual/html_node/emacs/Bookmarks.html) are pretty wonderful, you can bookmark almost anything: files, directories, info and help buffers, [Magit](https://magit.vc) buffers, [elfeed](https://github.com/skeeto/elfeed#bookmarks) searches and entries. And, naturally, you can extend Emacs to be able to bookmark almost anything you want.

There's a basic web browser in Emacs called [EWW](https://www.gnu.org/software/emacs/manual/html_mono/eww.html) which, by default, uses its own bookmarking system rather than Emacs's global one. This note demonstrates how to extend Emacs to make EWW use the standard bookmarks system.

*As of September 2021 [Emacs added support](http://git.savannah.gnu.org/cgit/emacs.git/commit/etc/NEWS?id=da89bdde2e3aa941594a112db884ede1beaac658) for exactly this feature. But the below is still a useful way to learn how the bookmarking system creates and uses bookmarks.*

------------------------------------------------------------------------

Let's start by taking a closer look at what a bookmark looks like under the hood. When you type `M-x bookmark-set` Emacs adds a 'record' to the `bookmark-alist`. This list is then saved to a file (defined in the variable `bookmark-default-file`) so you don't loose your bookmarks when you quit Emacs. An individual bookmark record looks like this:

``` elisp
(front-context-string . "13.8 Bookmarks\n=")
(rear-context-string . " Up: Registers\n\n")
(position . 251555)
(filename . "/Users/oht/Applications/Emacs.app/Contents/Resources/info/emacs")
(info-node . "Bookmarks")
(handler . Info-bookmark-jump))
```

Let's break that down piece-by-piece.

- `(emacs) Bookmarks` is the name of the bookmark, and what gets displayed in the bookmark list.
- `front-context-string` and `rear-context-string` help keep your bookmarks accurate when you edit a file after setting a bookmark. If you simply recorded the filename and line number subsequent edits to the file would quickly render your bookmarks inaccurate. Emacs uses the position and context to keep the bookmark accurate.
- `position` is the point's position in the buffer.
- `filename` is pretty self explanatory, as is `info-node` (which is specific to bookmarking the info manuals).
- `handler` defines the function that `bookmark-jump` will use to go to that bookmark.

Detailed information about how bookmark records can be found by describing the variable `bookmark-alist`.

With a little imagination, one can envision a bookmark record for a webpage that looks something like this:

``` elisp
("Name of Webpage"
(location . "https://example.com")
(handler . eww-handler-function))
```

Emacs refers to a function which creates these records as a "bookmark make record function". In this case that function would look like this:

``` elisp
(defun custom-make-record-function ()
 `(,(name-bookmark-function)
   (location . ,(get-url-function))
   (handler . eww-handler-function)))
```

Emacs uses different functions to create each kind of bookmark; one function for bookmarking files and another for bookmarking directories. Defining which function to use in which context is the job of the variable `bookmark-make-record-function`. In our case we want to set that variable, when using EWW, to the name of our custom make record function. Then, when you type `M-x bookmark-set` Emacs will call your make-record function and insert the record into the `bookmark-alist`.

Now that we understand how it works, we can enumerate all the pieces we'll need.

1.  We need to write a function which creates a properly formatted bookmark record.
2.  We need a way to open the URL from the bookmark list, a 'handler' function.
3.  We need to set the variable `bookmark-make-record-function` locally when EWW buffers are created.

First, the make-record function. You can grab the url from EWW with the function `eww-current-url` but EWW provides no such function for getting the page's title. You can, however, grab the page title with a little lisp: `(plist-get eww-data :title)`. All together the complete make-record function looks like this:

``` elisp
(defun oht-eww-bookmark-make-record ()
 "Make a bookmark record for the current eww buffer."
 `(,(plist-get eww-data :title)
   ((location . ,(eww-current-url))
    (handler . oht-eww-bookmark-handler)
    (defaults . (,(plist-get eww-data :title))))))
```

(It's not clear *to me* why the `defaults` part of this is needed but without it EWW will not properly update the `:title` when browsing pages. This fix was [suggested by Joe Corneli](https://lists.gnu.org/archive/html/emacs-humanities/2021-02/msg00014.html).)

Second, the handler function for jumping to the URL:

``` elisp
(defun oht-eww-bookmark-handler (record)
 "Jump to a bookmark's url with bookmarked location."
 (eww (bookmark-prop-get record 'location)))
```

Third, we need to set the buffer-local variable `bookmark-make-record-function` to the name of our custom make-record function when using EWW. We do this by first defining a function which sets the local variable, then adding a hook to `eww-mode` which calls that function. Like this:

``` elisp
(defun oht-eww-set-bookmark-handler ()
 "Assigns `bookmark-make-record-function' to a custom function."
 (set (make-local-variable 'bookmark-make-record-function)
      #'oht-eww-bookmark-make-record))

(add-hook 'eww-mode-hook 'oht-eww-set-bookmark-handler)
```

------------------------------------------------------------------------

Now, when visiting a page in EWW you can type `M-x bookmark-set` and a bookmark will be created, and jumping to that bookmark will open the URL in EWW.

While this example is specific to the EWW browser, it should give you an idea of how you can extend Emacs's bookmarking system in other ways.
