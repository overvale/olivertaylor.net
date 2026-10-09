// Command palette. The page list is generated at /site-index.json.
(function () {
  "use strict";

  var INDEX_URL = "/site-index.json";
  var pages = null;
  var pagesRequest = null;
  var root = null;
  var input = null;
  var list = null;
  var status = null;
  var webWrap = null;
  var webLink = null;
  var webQuery = null;
  var closeButton = null;
  var activeIndex = -1;
  var lastFocus = null;

  function isSafePath(path) {
    return typeof path === "string" &&
      path.charAt(0) === "/" &&
      path.charAt(1) !== "/" &&
      path.indexOf("\\") === -1 &&
      path.indexOf(" ") === -1 &&
      path.indexOf("://") === -1;
  }

  function haystack(page) {
    return [page.section, page.title, page.description, page.path]
      .join("\n")
      .toLowerCase();
  }

  function tokensOf(query) {
    return String(query || "").toLowerCase().split(/\s+/).filter(Boolean);
  }

  function matches(page, tokens) {
    if (!tokens.length) return true;
    var hay = haystack(page);
    for (var i = 0; i < tokens.length; i++) {
      if (hay.indexOf(tokens[i]) === -1) return false;
    }
    return true;
  }

  function loadPages() {
    if (pages) return Promise.resolve(pages);
    if (!pagesRequest) {
      pagesRequest = fetch(INDEX_URL, { headers: { Accept: "application/json" } })
        .then(function (response) {
          if (!response.ok) throw new Error(String(response.status));
          return response.json();
        })
        .then(function (data) {
          if (!Array.isArray(data)) throw new Error("Invalid page index");
          pages = data;
          return pages;
        })
        .catch(function (error) {
          pagesRequest = null;
          throw error;
        });
    }
    return pagesRequest;
  }

  function isTypingTarget(target) {
    if (!target || target.nodeType !== 1) return false;
    var tag = target.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return true;
    return target.isContentEditable;
  }

  function isOpen() {
    return root && !root.hidden;
  }

  function setButtonsExpanded(open) {
    var buttons = document.querySelectorAll(".palette-button");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].setAttribute("aria-expanded", open ? "true" : "false");
    }
  }

  function setPageInert(on) {
    var nodes = document.body.children;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] === root) continue;
      if (on) nodes[i].setAttribute("inert", "");
      else nodes[i].removeAttribute("inert");
    }
  }

  function showStatus(message) {
    status.hidden = !message;
    status.textContent = message || "";
  }

  function googleSearchHref(term) {
    return "https://www.google.com/search?q=" +
      encodeURIComponent("site:olivertaylor.net " + term).replace(/%20/g, "+");
  }

  function paletteOptions() {
    var options = Array.prototype.slice.call(list.querySelectorAll('[role="option"]'));
    if (webWrap && !webWrap.hidden) options.push(webLink);
    return options;
  }

  function scrollOptionIntoView(option) {
    if (!list.contains(option)) return;
    var optionRect = option.getBoundingClientRect();
    var listRect = list.getBoundingClientRect();
    if (optionRect.top < listRect.top) {
      list.scrollTop -= listRect.top - optionRect.top;
    } else if (optionRect.bottom > listRect.bottom) {
      list.scrollTop += optionRect.bottom - listRect.bottom;
    }
  }

  function setActive(index, shouldScroll) {
    var options = paletteOptions();
    if (!options.length) {
      activeIndex = -1;
      input.removeAttribute("aria-activedescendant");
      return;
    }
    if (index < 0) index = options.length - 1;
    if (index >= options.length) index = 0;
    activeIndex = index;
    for (var i = 0; i < options.length; i++) {
      options[i].setAttribute("aria-selected", i === index ? "true" : "false");
    }
    input.setAttribute("aria-activedescendant", options[index].id);
    if (shouldScroll) scrollOptionIntoView(options[index]);
  }

  function optionId(page, index) {
    var slug = String(page.path || index).replace(/[^A-Za-z0-9]+/g, "-");
    return "palette-option-" + index + "-" + slug;
  }

  function renderOption(page, index, total) {
    var item = document.createElement("li");
    item.className = "palette-item";
    item.setAttribute("role", "presentation");

    var link = document.createElement("a");
    link.className = "palette-option";
    link.id = optionId(page, index);
    link.href = page.path;
    link.setAttribute("role", "option");
    link.tabIndex = -1;
    link.setAttribute("aria-selected", "false");
    link.setAttribute("aria-posinset", String(index + 1));
    link.setAttribute("aria-setsize", String(total));

    var title = document.createElement("span");
    title.className = "palette-title";
    title.textContent = page.title;

    var section = document.createElement("span");
    section.className = "palette-section";
    section.textContent = page.section || "";

    link.appendChild(title);
    link.appendChild(section);
    link.addEventListener("mouseenter", function () {
      setActive(index, false);
    });
    item.appendChild(link);
    return item;
  }

  function showWebSearch(term, total) {
    webWrap.hidden = false;
    webLink.href = googleSearchHref(term);
    webQuery.textContent = term;
    webLink.setAttribute("role", "option");
    webLink.setAttribute("aria-selected", "false");
    webLink.setAttribute("aria-posinset", String(total));
    webLink.setAttribute("aria-setsize", String(total));
    webLink.setAttribute("aria-label", "Search Google for " + term);
    list.setAttribute("aria-owns", webLink.id);
  }

  function hideWebSearch() {
    webWrap.hidden = true;
    webLink.removeAttribute("href");
    webLink.removeAttribute("aria-posinset");
    webLink.removeAttribute("aria-setsize");
    webLink.removeAttribute("aria-label");
    webLink.setAttribute("aria-selected", "false");
    list.removeAttribute("aria-owns");
  }

  function render(query) {
    var term = String(query || "").trim();
    var tokens = tokensOf(query);
    var found = [];
    var source = pages || [];
    for (var i = 0; i < source.length; i++) {
      var page = source[i];
      if (!page || typeof page.title !== "string" || !isSafePath(page.path)) continue;
      if (matches(page, tokens)) found.push(page);
    }

    var showWeb = term.length > 0;
    var total = found.length + (showWeb ? 1 : 0);
    list.replaceChildren();
    if (found.length) {
      var fragment = document.createDocumentFragment();
      for (var j = 0; j < found.length; j++) {
        fragment.appendChild(renderOption(found[j], j, total));
      }
      list.appendChild(fragment);
    }
    if (showWeb) showWebSearch(term, total);
    else hideWebSearch();

    if (!pages) showStatus("Loading pages…");
    else if (!found.length) showStatus("No matching pages");
    else showStatus("");

    if (!total) {
      input.setAttribute("aria-expanded", "false");
      input.removeAttribute("aria-activedescendant");
      activeIndex = -1;
      return;
    }

    input.setAttribute("aria-expanded", "true");
    setActive(0, false);
    list.scrollTop = 0;
  }

  function go() {
    var options = paletteOptions();
    var selected = null;
    for (var i = 0; i < options.length; i++) {
      if (options[i].getAttribute("aria-selected") === "true") {
        selected = options[i];
        break;
      }
    }
    if (!selected || !selected.getAttribute("href")) return;
    window.location.assign(selected.href);
  }

  function move(delta) {
    if (activeIndex < 0) return;
    setActive(activeIndex + delta, true);
  }

  function ensureDialog() {
    if (root) return;

    root = document.createElement("div");
    root.id = "palette";
    root.className = "palette";
    root.hidden = true;

    var backdrop = document.createElement("div");
    backdrop.className = "palette-backdrop";
    backdrop.addEventListener("click", closePalette);

    var dialog = document.createElement("div");
    dialog.className = "palette-dialog";
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-labelledby", "palette-label");

    var search = document.createElement("div");
    search.className = "palette-search";

    var label = document.createElement("label");
    label.id = "palette-label";
    label.className = "palette-visually-hidden";
    label.htmlFor = "palette-input";
    label.textContent = "Search pages";

    input = document.createElement("input");
    input.id = "palette-input";
    input.className = "palette-input";
    input.type = "text";
    input.placeholder = "Search pages";
    input.setAttribute("role", "combobox");
    input.setAttribute("aria-autocomplete", "list");
    input.setAttribute("aria-expanded", "false");
    input.setAttribute("aria-controls", "palette-list");
    input.setAttribute("aria-haspopup", "listbox");
    input.setAttribute("autocomplete", "off");
    input.setAttribute("autocapitalize", "off");
    input.setAttribute("autocorrect", "off");
    input.setAttribute("spellcheck", "false");
    input.setAttribute("inputmode", "search");
    input.addEventListener("input", function () {
      render(input.value);
    });

    closeButton = document.createElement("button");
    closeButton.type = "button";
    closeButton.className = "palette-close";
    closeButton.setAttribute("aria-label", "Close search");
    closeButton.textContent = "\u00d7";
    closeButton.addEventListener("click", closePalette);

    list = document.createElement("ul");
    list.id = "palette-list";
    list.className = "palette-list";
    list.setAttribute("role", "listbox");
    list.setAttribute("aria-label", "Pages");

    status = document.createElement("p");
    status.className = "palette-empty";
    status.setAttribute("role", "status");
    status.hidden = true;

    webWrap = document.createElement("div");
    webWrap.className = "palette-web";
    webWrap.hidden = true;

    webLink = document.createElement("a");
    webLink.id = "palette-web-option";
    webLink.className = "palette-web-option";
    webLink.setAttribute("role", "option");
    webLink.tabIndex = -1;
    webLink.setAttribute("aria-selected", "false");
    webLink.addEventListener("mouseenter", function () {
      var options = paletteOptions();
      var index = options.indexOf(webLink);
      if (index >= 0) setActive(index, false);
    });

    var webLabel = document.createElement("span");
    webLabel.className = "palette-web-label";
    webLabel.textContent = "Search Google";

    webQuery = document.createElement("span");
    webQuery.className = "palette-web-query";

    webLink.appendChild(webLabel);
    webLink.appendChild(webQuery);
    webWrap.appendChild(webLink);

    search.appendChild(label);
    search.appendChild(input);
    search.appendChild(closeButton);
    dialog.appendChild(search);
    dialog.appendChild(list);
    dialog.appendChild(status);
    dialog.appendChild(webWrap);
    root.appendChild(backdrop);
    root.appendChild(dialog);
    document.body.appendChild(root);

    var buttons = document.querySelectorAll(".palette-button");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].setAttribute("aria-haspopup", "dialog");
      buttons[i].setAttribute("aria-controls", "palette");
      buttons[i].setAttribute("aria-expanded", "false");
    }
  }

  function openPalette() {
    ensureDialog();
    if (isOpen()) {
      input.focus();
      return;
    }
    lastFocus = document.activeElement;
    root.hidden = false;
    document.body.classList.add("palette-open");
    setButtonsExpanded(true);
    setPageInert(true);
    input.value = "";
    if (pages) {
      render("");
    } else {
      list.replaceChildren();
      hideWebSearch();
      input.setAttribute("aria-expanded", "false");
      showStatus("Loading pages\u2026");
      loadPages().then(function () {
        if (!isOpen()) return;
        render(input.value);
      }).catch(function () {
        if (!isOpen()) return;
        showStatus("The page list could not be loaded.");
      });
    }
    input.focus();
  }

  function closePalette() {
    if (!isOpen()) return;
    var focus = lastFocus;
    lastFocus = null;
    setPageInert(false);
    var canRestore = focus &&
      focus !== document.body &&
      focus !== document.documentElement &&
      typeof focus.focus === "function" &&
      document.contains(focus);
    if (canRestore) focus.focus();
    else if (document.activeElement === input) input.blur();
    root.hidden = true;
    document.body.classList.remove("palette-open");
    setButtonsExpanded(false);
    input.setAttribute("aria-expanded", "false");
    input.removeAttribute("aria-activedescendant");
  }

  function isCommandK(event) {
    if (event.altKey || event.shiftKey || event.repeat) return false;
    if (!event.metaKey && !event.ctrlKey) return false;
    if (event.code === "KeyK") return true;
    var key = event.key;
    if (typeof key === "string" && key.toLowerCase() === "k") return true;
    // Safari can leave code empty and key as "Unidentified" for meta chords.
    return (event.keyCode || event.which) === 75;
  }

  function onKeydown(event) {
    // Handle the chord before defaultPrevented. Chrome and Safari claim
    // Cmd-K and Ctrl-K for the address bar unless the page cancels it
    // during the capture phase.
    if (isCommandK(event)) {
      event.preventDefault();
      event.stopPropagation();
      if (isOpen()) closePalette();
      else openPalette();
      return;
    }
    if (event.defaultPrevented) return;

    if (!isOpen()) {
      if (event.key === "/" &&
          !event.metaKey &&
          !event.ctrlKey &&
          !event.altKey &&
          !event.shiftKey &&
          !isTypingTarget(event.target)) {
        event.preventDefault();
        openPalette();
      }
      return;
    }

    if (event.isComposing || event.key === "Process") return;
    if (event.key === "Escape") {
      event.preventDefault();
      closePalette();
      return;
    }
    if (event.key === "ArrowDown") {
      event.preventDefault();
      move(1);
      return;
    }
    if (event.key === "ArrowUp") {
      event.preventDefault();
      move(-1);
      return;
    }
    if (event.key === "Enter" && event.target !== closeButton) {
      event.preventDefault();
      go();
      return;
    }
    if (event.key === "Tab") {
      var first = input;
      var last = closeButton;
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  }

  document.addEventListener("click", function (event) {
    var button = event.target.closest && event.target.closest(".palette-button");
    if (!button) return;
    event.preventDefault();
    openPalette();
  });
  window.addEventListener("keydown", onKeydown, true);
  loadPages().catch(function () {});
})();
