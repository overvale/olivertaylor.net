#!/bin/bash
# Build all markdown files to HTML and keep nav in sync.

set -euo pipefail

cd "$(dirname "$0")/.."

src_root="markdown"
nav_file="$src_root/site-nav.tsv"
site_url="https://olivertaylor.net"

# Generated pages live beside the source folders in this checkout.
html_only=0
case "${1:-}" in
  "") ;;
  --html-only) html_only=1 ;;
  *) echo "Usage: $0 [--html-only]" >&2; exit 1 ;;
esac
[ "$#" -le 1 ] || { echo "Usage: $0 [--html-only]" >&2; exit 1; }
command -v pandoc >/dev/null || { echo "Install Pandoc to build the site." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Install Python 3 to build the site." >&2; exit 1; }
build_dir="."
mkdir -p ai notes emacs writing
# A temporary file records generated outputs, not a separate website directory.
generated_files=$(mktemp)
trap 'rm -f "$generated_files"' EXIT
printf '%s\n' index.html sitemap.xml site-index.json notes/index.html emacs/index.html > "$generated_files"

if [ ! -f "$nav_file" ]; then
  echo "Missing nav source: $nav_file"
  exit 1
fi

# Bash 5.2 enables patsub_replacement by default. An unquoted & in a pattern
# replacement then expands to the matched text, so "Won't" becomes "Won'#39;t"
# and the <, >, and " entities break the same way. Run the substitutions in a
# subshell with the option off so every entity stays literal whether or not
# the caller has it enabled. Older Bash has no such option; the shopt error
# is ignored.
escape_html() {
  (
    shopt -u patsub_replacement 2>/dev/null || true
    value="${1//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    value="${value//\'/&#39;}"
    printf '%s' "$value"
  )
}

# Wrap 2+ uppercase letter runs in <span class="smallcaps">...</span>,
# mirroring filters/smallcaps-abbr.lua for non-pandoc output paths.
smallcaps_abbr() {
  python3 -c 'import re,sys; sys.stdout.write(re.sub(r"([A-Z]{2,})", lambda m: "<span class=\"smallcaps\">"+m.group(1).lower()+"</span>", sys.argv[1]))' "$1"
}

render_header_nav() {
  local current_path="$1"
  local writing_active="" notes_active="" ai_active="" links_active=""

  if [[ "$current_path" == /writing* ]]; then
    writing_active=' class="active"'
  fi
  [[ "$current_path" == /notes* || "$current_path" == /emacs* ]] && notes_active=' class="active"'
  [[ "$current_path" == /ai* ]] && ai_active=' class="active"'
  [ "$current_path" = "/links" ] && links_active=' class="active"'

  echo '<nav class="header-nav" aria-label="Site Navigation">'
  echo '<ul>'
  printf '  <li><a href="/writing/"%s>Writing</a></li>\n' "$writing_active"
  printf '  <li><a href="/notes/"%s>Notes</a></li>\n' "$notes_active"
  if [ -f "$src_root/ai/index.md" ]; then
    printf '  <li><a href="/ai/"%s>AI</a></li>\n' "$ai_active"
  fi
  printf '  <li><a href="/links"%s>Links</a></li>\n' "$links_active"
  echo '</ul>'
  echo '</nav>'
}

# The search control is a real link so it still goes somewhere with JS off.
# palette.js turns it into the command palette and loads /site-index.json.
render_palette_button() {
  echo '<a class="palette-button" href="/notes/" aria-label="Search pages"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><circle cx="10.5" cy="10.5" r="6.25" fill="none" stroke="currentColor" stroke-width="1.75"/><path d="M15.2 15.2 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/></svg></a>'
}

render_site_header() {
  local current_path="$1"

  echo '<header>'
  echo '<div class="header-inner">'
  echo '<a class="site-title" href="/">Oliver Taylor</a>'
  render_palette_button
  render_header_nav "$current_path"
  echo '</div>'
  echo '<script src="/palette.js" defer></script>'
  echo '</header>'
}

# Page list for the command palette. Section labels are part of each record
# so the palette can show and search them without a second lookup table.
render_site_index() {
  python3 - "$nav_file" "$build_dir/site-index.json" <<'PYTHON'
import json
import sys
from pathlib import Path

labels = {
    "writing": "Writing",
    "notes": "Notes",
    "emacs": "Emacs",
    "links": "Links",
    "ai": "AI",
}
pages = []
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    parts = line.split("|")
    if len(parts) < 3:
        raise SystemExit(f"Invalid nav row: {line}")
    section, path, title = parts[0], parts[1], parts[2]
    description = "|".join(parts[3:])
    if section not in labels:
        raise SystemExit(f"Unknown nav section: {section}")
    if not path.startswith("/") or not title:
        raise SystemExit(f"Invalid nav row: {line}")
    pages.append({
        "title": title,
        "section": labels[section],
        "path": path,
        "description": description,
    })
Path(sys.argv[2]).write_text(
    json.dumps(pages, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PYTHON
}

render_index_page() {
  local section="$1"
  local title="$2"
  local current_path="$3"
  local output="$4"
  local site_header
  site_header="$(render_site_header "$current_path")"

  {
    echo '<!DOCTYPE html>'
    echo '<html lang="en">'
    echo '<head>'
    echo '<meta charset="utf-8">'
    echo '<meta name="viewport" content="width = device-width" />'
    printf '<link rel="canonical" href="%s%s" />\n' "$site_url" "$current_path"
    echo '<link rel="stylesheet" type="text/css" href="/style.css" />'
    printf '<title>%s @olivertaylor.net</title>\n' "$title"
    echo '</head>'
    echo '<body>'
    printf '%s\n' "$site_header"
    echo ''
    echo '<main>'
    echo '<article>'
    printf '<h1>%s</h1>\n' "$title"
    echo ''
    echo '<ul>'
    while IFS='|' read -r sec path item_title description; do
      [ -z "${sec:-}" ] && continue
      [[ "$sec" = \#* ]] && continue
      [ "$sec" != "$section" ] && continue
      printf '<li><a href="%s">%s</a></li>\n' \
        "$(escape_html "$path")" "$(smallcaps_abbr "$(escape_html "$item_title")")"
    done < "$nav_file"
    echo '</ul>'
    echo ''
    echo '</article>'
    echo '</main>'
    echo '</body>'
    echo '</html>'
  } > "$output"
}

render_section_list() {
  local section="$1"

  echo '<ul>'
  while IFS='|' read -r sec path item_title description; do
    [ -z "${sec:-}" ] && continue
    [[ "$sec" = \#* ]] && continue
    [ "$sec" != "$section" ] && continue
    printf '<li><a href="%s">%s</a></li>\n' \
      "$(escape_html "$path")" "$(smallcaps_abbr "$(escape_html "$item_title")")"
  done < "$nav_file"
  echo '</ul>'
}

render_notes_index_page() {
  local site_header
  site_header="$(render_site_header "/notes/")"

  {
    echo '<!DOCTYPE html>'
    echo '<html lang="en">'
    echo '<head>'
    echo '<meta charset="utf-8">'
    echo '<meta name="viewport" content="width = device-width" />'
    printf '<link rel="canonical" href="%s/notes/" />\n' "$site_url"
    echo '<link rel="stylesheet" type="text/css" href="/style.css" />'
    echo '<title>Notes @olivertaylor.net</title>'
    echo '</head>'
    echo '<body>'
    printf '%s\n' "$site_header"
    echo ''
    echo '<main>'
    echo '<article>'
    echo '<h1>Notes</h1>'
    echo ''
    render_section_list "notes"
    echo ''
    echo '<h3>Emacs</h3>'
    echo ''
    render_section_list "emacs"
    echo ''
    echo '</article>'
    echo '</main>'
    echo '</body>'
    echo '</html>'
  } > "$build_dir/notes/index.html"
}

# Render home page
home_site_header="$(render_site_header "/")"
pandoc "$src_root/index.md" \
  --from=markdown \
  --to=html5 \
  --wrap=none \
  --lua-filter=filters/smallcaps-abbr.lua \
  --template=templates/home.html \
  --variable canonical_url="$site_url/" \
  --variable site_header="$home_site_header" \
  --output="$build_dir/index.html"

# links.html and other hand-maintained assets already live in the website root.

for md in "$src_root"/ai/*.md "$src_root"/emacs/*.md "$src_root"/notes/*.md "$src_root"/writing/*.md; do
  [ -e "$md" ] || continue

  rel="${md#$src_root/}"
  html="$build_dir/${rel%.md}.html"
  printf '%s\n' "${rel%.md}.html" >> "$generated_files"
  current_path="/${rel%.md}"
  canonical_path="$current_path"
  [ "$rel" = "writing/index.md" ] && canonical_path="/writing/"
  [ "$rel" = "ai/index.md" ] && canonical_path="/ai/"

  dir="$(dirname "$rel")"
  case "$dir" in
    ai) class="note" ;;
    emacs) class="emacs" ;;
    notes) class="note" ;;
    writing) class="article" ;;
    *) class="note" ;;
  esac

  site_header="$(render_site_header "$current_path")"

  pdf_link_var=()
  if [ "$dir" = "writing" ]; then
    author=$(grep '^author:' "$md" | sed 's/^author:[[:space:]]*//' || true)
    title=$(grep '^title:' "$md" | sed 's/^title:[[:space:]]*//; s/^"//; s/"$//' || true)
    if [ -n "$author" ] && [ -n "$title" ]; then
      pdf_filename="${author} - ${title}.pdf"
      pdf_url="/writing/$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$pdf_filename")"
      pdf_link_var=(--variable "pdf_link=$pdf_url")
    fi
  fi

  pandoc "$md" \
    --from=markdown \
    --to=html5 \
    --wrap=none \
    --lua-filter=filters/smallcaps-abbr.lua \
    --template=templates/note.html \
    --metadata class="$class" \
    --variable canonical_url="$site_url$canonical_path" \
    --variable site_header="$site_header" \
    "${pdf_link_var[@]+"${pdf_link_var[@]}"}" \
    --output="$html"
done

render_notes_index_page
render_index_page "emacs" "Emacs Notes" "/emacs/" "$build_dir/emacs/index.html"

render_site_index

# Publish the canonical HTML URL inventory for search engines and agents.
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  for path in / /writing/ /notes/ /emacs/ /links; do
    printf '  <url><loc>%s%s</loc></url>\n' "$site_url" "$path"
  done
  while IFS='|' read -r section path title description; do
    [ -z "${section:-}" ] && continue
    [[ "$section" = \#* ]] && continue
    [ "$section" = "links" ] && continue
    printf '  <url><loc>%s%s</loc></url>\n' "$site_url" "$path"
  done < "$nav_file"
  if [ -f "$src_root/ai/index.md" ]; then
    printf '  <url><loc>%s/ai/</loc></url>\n' "$site_url"
  fi
  echo '</urlset>'
} > "$build_dir/sitemap.xml"

# Render writing articles to PDF via xelatex.
# Skip when the PDF is up to date with respect to its source and shared deps,
# since xelatex bakes a creation date into the file and would otherwise show
# every PDF as modified in git on every build.
pdf_deps=(
  templates/article.tex
  filters/strip-dir.lua
  filters/raw-images.lua
  filters/smallcaps-abbr.lua
)

for md in "$src_root"/writing/*.md; do
  [ -e "$md" ] || continue
  [ "$(basename "$md")" = "index.md" ] && continue

  author=$(grep '^author:' "$md" | sed 's/^author:[[:space:]]*//' || true)
  title=$(grep '^title:' "$md" | sed 's/^title:[[:space:]]*//; s/^"//; s/"$//' || true)
  # Fall back to slug-based name if frontmatter is missing
  if [ -z "$author" ] || [ -z "$title" ]; then
    rel="${md#$src_root/}"
    pdf="$build_dir/${rel%.md}.pdf"
  else
    pdf="$build_dir/writing/${author} - ${title}.pdf"
  fi

  printf '%s\n' "${pdf#./}" >> "$generated_files"
  if [ "$html_only" = 1 ]; then
    [ -f "$pdf" ] || { echo "Missing $pdf; run a full build to create it." >&2; exit 1; }
    continue
  fi
  images_changed=0
  while IFS= read -r image; do
    if [ "$image" -nt "$pdf" ]; then images_changed=1; break; fi
  done < <(find writing -type f ! -name '*.pdf' ! -name '*.html')

  if [ "$images_changed" = 0 ] && [ -f "$pdf" ] && [ ! "$md" -nt "$pdf" ]; then
    skip=1
    for dep in "${pdf_deps[@]}"; do
      if [ "$dep" -nt "$pdf" ]; then skip=0; break; fi
    done
    [ "$skip" = 1 ] && continue
  fi

  pandoc "$md" \
    --from=markdown-markdown_in_html_blocks \
    --pdf-engine=xelatex \
    --resource-path="$build_dir/writing" \
    --template=templates/article.tex \
    --shift-heading-level-by=-1 \
    --lua-filter=filters/strip-dir.lua \
    --lua-filter=filters/raw-images.lua \
    --lua-filter=filters/smallcaps-abbr.lua \
    --output="$pdf"
done

# Only remove obsolete files previously recorded as generated. Hand-maintained
# pages, images, and reference PDFs never belong to this list.
python3 - "$generated_files" <<'PYTHON'
from pathlib import Path
import sys

manifest = Path('.generated-files')
current = set(Path(sys.argv[1]).read_text().splitlines())
previous = set(manifest.read_text().splitlines()) if manifest.exists() else set()
for name in current | previous:
    path = Path(name)
    allowed = name in {'index.html', 'sitemap.xml', 'site-index.json'} or (
        len(path.parts) == 2 and path.parts[0] in {'ai', 'notes', 'emacs', 'writing'}
        and path.suffix in {'.html', '.pdf'}
    )
    if not allowed or path.is_symlink() or path.parent.is_symlink():
        raise SystemExit(f'Invalid generated file path: {name}')
for name in sorted(previous - current):
    Path(name).unlink(missing_ok=True)
    print(f'Removed obsolete generated file: {name}')
manifest.write_text('\n'.join(sorted(current)) + '\n')
PYTHON
./scripts/check.sh
if [ "$html_only" = 1 ]; then
  echo "HTML ready. Existing PDFs were retained; writing edits still need a full build."
fi
echo "Website ready in this checkout. Review git diff before committing and pushing."
