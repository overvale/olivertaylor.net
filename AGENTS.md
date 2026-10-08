# Website working instructions

## Context and discovery

- This environment contains Oliver Taylor's website, `olivertaylor.net`. Start with this checkout and its instructions when answering questions about the site or published content.
- Interpret questions about content, publishing, design, and site behavior in the context of this website unless Oliver names another project or service. Inspect the relevant local files and Git history before reaching for external apps or asking where the work lives. Use `origin/master` as the recorded publication baseline when distinguishing local changes from published content; verify the live site when the answer requires its current state.

## Workflow

- This checkout contains both source and generated website files. There is no separate output directory or publishing repository.
- Edit `markdown/`, `templates/`, and `filters/` for generated content. Edit CSS, images, fonts, `links.html`, `404.html`, `CNAME`, and `robots.txt` directly in the website root or their asset folders.
- Use the Makefile commands documented in README.md. `make build` and `make html` run site checks automatically. `make test` also exercises building and previewing in temporary directories.
- Builds write directly into the checkout. After a failed build, fix the problem and rerun before committing. Do not hand-edit generated HTML.
- `.generated-files` records generated pages and PDFs so the build can remove obsolete output. Never add hand-maintained files to that list. Include inventory changes with the corresponding source and output changes.
- Review source and output together. Commit and push only when Oliver explicitly instructs it. Publishing uses the existing `origin master`; no separate publication helper is needed.
- Preserve unrelated edits and deletions. Do not change fonts, layout, or writing as a side effect of tooling changes.

## Build and preview

- Use the shared environment setup recipe in README.md for dependencies, HTML verification, and optional PDF tooling. Keep dependency installation instructions there rather than duplicating them in service configuration.
- `make html` retains existing PDFs and fails if an expected PDF is missing. Writing or PDF-template changes require a full build before publication. PDFs are reused based on modification times; fresh clones may regenerate them.
- Codex setup runs `make html`; native actions run `make serve` and `make build`. Keep these as thin pointers to the same Makefile commands.
- `make serve` prints the root directory and preview URL without opening a browser. Use Codex's native browser opener when showing the preview. Reuse an existing server for this checkout; stop it with Ctrl-C.
- Reserve port 8000 for the primary checkout; use `make serve PORT=8001` or another available port for worktrees. Each worktree is an independent, complete checkout.
- Preview supports extensionless URLs and live reload. Builds remain manual: rebuild after source changes; direct CSS or asset edits reload immediately.
- For optional server flags use `python3 scripts/serve.py --help`. Use `--lan` only when explicitly requested. Hidden paths, local drafts, and directory listings are blocked.

## Content conventions

- Do not hard-wrap prose. Use double hyphens instead of literal em dashes in source text; preserve existing content unless editing it for the task.
- Notes and essays use YAML frontmatter with `title`, optional `dateline`, and optional `author`. Do not add a top-level `# Heading` in the body because the template renders the title. The homepage is an exception.
- Directory determines article class: `notes` and `ai` use `note`, `emacs` uses `emacs`, and `writing` uses `article`.
- Update `markdown/site-nav.tsv` when adding, renaming, or removing an article.
- Edit `links.html` directly. Never overwrite it with `archive/links-legacy.md`. New links go at the top, newest first, with permalinks based on the date added (`YYYY-MM-DD`, followed by `a`, `b`, etc. for multiple entries that day). After publishing a link, ask whether a corresponding draft should be cleaned up.

## Drafts and publication

- The AI section is built only when `markdown/ai/index.md` exists. Keep private unpublished drafts outside the website repository and cloud checkout. Do not retrieve, copy, import, finalize, or publish them without Oliver's explicit instruction; do not assume a particular local draft path exists.
- Optional `drafts/` within this checkout is ignored and excluded from builds, but is not storage for genuinely private material. Nothing is promoted automatically. Historical material in `archive/` is also excluded from builds.
- Source and scripts may be public. Pushed branches are public even when not deployed; keep genuinely private material out of Git. Local-only drafts and unpushed branches do not follow a cloud checkout.
- `.nojekyll` lets GitHub Pages serve the committed files directly. Keep the README focused on the public project overview and commands; maintain operational instructions here.
