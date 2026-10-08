# olivertaylor.net

Source and generated files for [Oliver Taylor's website](https://olivertaylor.net).

Markdown lives in `markdown/`; templates and filters live in `templates/` and `filters/`. The generated website lives at the repository root and is committed alongside its sources.

```sh
make build          # Build HTML and PDFs, then check the site
make html           # Build HTML using existing PDFs, then check the site
make check          # Check the existing site without rebuilding
make serve          # Preview at http://localhost:8000
make test           # Run site checks and workflow tests
```

Use `make serve PORT=8001` for a different preview port. Build and preview scripts live in `scripts/`; regression tests live in `tests/`.

## Environment setup

This is the shared setup recipe for local development and cloud agents. Run commands from the repository root. A saved cloud environment is optional; each service can use this recipe to prepare its own machine. Repository access and any service credentials are configured separately, outside Git. Building and previewing the static site require no application secrets.

### HTML development

Install Git, Make, Bash, Python 3, and Pandoc with Lua-filter support using your machine's package manager. For an Ubuntu or Debian machine with package-install privileges, the HTML dependencies can be installed with:

```sh
sudo apt-get update
sudo apt-get install -y git make bash python3 pandoc
```

Other operating systems need their own installation steps. There are no Python third-party packages or Node dependencies to install. The verified Linux toolchain is Make 4.4.1, Bash 5.2.37, Python 3.12.14, and Pandoc 3.1.11.1; these are a reference, not claimed minimum versions.

Confirm the installed tools, then validate the checkout:

```sh
git --version
make --version
bash --version
python3 --version
pandoc --version
make check
make html
make test
git diff --stat
git diff
```

`make html` exercises the Lua filters and checks the generated site. It retains the three committed writing PDFs and fails if an expected PDF is missing. `make test` runs site checks plus build and preview regression tests in temporary directories. Passing checks do not replace reviewing the generated diff.

Builds write generated files directly into this checkout. Review those differences before committing; setup must not commit, push, or publish automatically. For a local preview, run `make serve` in a separate terminal and stop it with Ctrl-C. It binds to loopback by default, supports extensionless URLs and live reload, and does not open a browser. Rebuild manually after source changes.

Cloud setup should finish with `make html` and `make test`. Start the preview separately when needed; a saved environment does not preserve a running server. Use the same Makefile commands for service actions rather than duplicating build logic or dependency lists.

### Optional PDF generation

HTML-only structural work does not need a TeX installation. A full `make build` additionally requires:

- XeLaTeX and the LaTeX packages declared in `templates/article.tex`, supplied by your TeX distribution.
- The Brill font family, including Roman, Bold, Italic, and Bold Italic faces, installed so XeLaTeX can find them. Obtain the fonts from Brill and follow their license terms; do not assume a cloud image includes them.

Check `xelatex --version` and use `kpsewhich` to diagnose missing LaTeX packages. On Linux, `fc-match Brill` should resolve to a Brill font rather than a fallback. Environment-specific font or TeX paths must be supplied by that environment; the build does not depend on another checkout's absolute paths.

Run `make build`, followed by `make test` and a source/output diff review, to verify full PDF readiness. Fresh clones may regenerate PDFs because reuse depends on modification times. Writing or PDF-template changes require a full build before publication; an HTML-only pass does not verify PDF generation.
