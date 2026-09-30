# olivertaylor.net

Source and generated files for [Oliver Taylor's website](https://olivertaylor.net).

Markdown lives in `markdown/`; templates and filters live in `templates/` and `filters/`. The generated website lives at the repository root and is committed alongside its sources.

```sh
make build          # Build HTML and PDFs, then check the site
make serve          # Preview at http://localhost:8000
make test           # Run site checks and workflow tests
```

Requires Make, Bash, Python 3, and Pandoc. PDF generation also requires XeLaTeX and Brill fonts. Use `make html` to build HTML while retaining existing PDFs, or `make check` to check the site without rebuilding. Writing changes need a full build before publication.

Use `make serve PORT=8001` for a different preview port. Build and preview scripts live in `scripts/`; regression tests live in `tests/`.
