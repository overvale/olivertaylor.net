#!/bin/bash
# Post-build tests for olivertaylor.net
# Run after scripts/build.sh to validate the output.

set -euo pipefail

cd "$(dirname "$0")/.."

src_root="markdown"
nav_file="$src_root/site-nav.tsv"
errors=0

fail() {
  echo "  FAIL: $1"
  errors=$((errors + 1))
}

pass() {
  echo "  ok: $1"
}

# --------------------------------------------------------------------------
# 1. Markdown source validation
# --------------------------------------------------------------------------

echo ""
echo "=== Markdown source validation ==="

for md in "$src_root"/ai/*.md "$src_root"/emacs/*.md "$src_root"/notes/*.md "$src_root"/writing/*.md; do
  [ -e "$md" ] || continue
  name="${md#$src_root/}"

  # Every .md file has a title in frontmatter
  if head -20 "$md" | grep -q '^title:'; then
    pass "$name has title"
  else
    fail "$name is missing 'title:' in frontmatter"
  fi

  # No top-level heading in body (template handles the title)
  # Skip frontmatter (between --- delimiters), then look for '# '
  body=$(awk '/^---$/{n++; next} n>=2' "$md")
  if echo "$body" | grep -q '^# '; then
    fail "$name has a top-level '# Heading' (template already renders the title)"
  fi
done

# --------------------------------------------------------------------------
# 2. Nav consistency (site-nav.tsv)
# --------------------------------------------------------------------------

echo ""
echo "=== Nav consistency ==="

# Every nav entry has a corresponding markdown source file
while IFS='|' read -r section path title description; do
  [ -z "${section:-}" ] && continue
  [[ "$section" = \#* ]] && continue
  # The links section points to links.html, not a markdown file
  [ "$section" = "links" ] && continue

  # /writing/foo.html -> ./markdown/writing/foo.md
  md_path="$src_root${path%.html}.md"
  if [ -f "$md_path" ]; then
    pass "nav entry $path -> $md_path exists"
  else
    fail "nav entry $path has no source file (expected $md_path)"
  fi
done < "$nav_file"

# Every markdown file has a nav entry
for md in "$src_root"/ai/*.md "$src_root"/emacs/*.md "$src_root"/notes/*.md "$src_root"/writing/*.md; do
  [ -e "$md" ] || continue
  rel="${md#$src_root/}"
  [ "$rel" = "writing/index.md" ] && continue
  [ "$rel" = "ai/index.md" ] && continue
  expected_path="/${rel%.md}"

  if grep -q "|${expected_path}|" "$nav_file"; then
    pass "$rel is listed in site-nav.tsv"
  else
    fail "$rel has no entry in site-nav.tsv (expected path: $expected_path)"
  fi
done

# --------------------------------------------------------------------------
# 3. Build output validation
# --------------------------------------------------------------------------

echo ""
echo "=== Build output validation ==="

for md in "$src_root"/ai/*.md "$src_root"/emacs/*.md "$src_root"/notes/*.md "$src_root"/writing/*.md; do
  [ -e "$md" ] || continue
  rel="${md#$src_root/}"
  html="./${rel%.md}.html"
  name="${rel%.md}.html"

  # HTML file exists
  if [ ! -f "$html" ]; then
    fail "$name was not generated"
    continue
  fi

  # Has a non-empty <title>
  if grep -qE '<title>.+</title>' "$html"; then
    pass "$name has <title>"
  else
    fail "$name has empty or missing <title>"
  fi

  # Has a non-empty <h1>
  if grep -qE '<h1>.+</h1>' "$html"; then
    pass "$name has <h1>"
  else
    fail "$name has empty or missing <h1>"
  fi

  # Correct class attribute
  dir="$(dirname "$rel")"
  case "$dir" in
    ai)      expected_class="note" ;;
    emacs)   expected_class="emacs" ;;
    notes)   expected_class="note" ;;
    writing) expected_class="article" ;;
    *)       expected_class="note" ;;
  esac

  if grep -q "<main class=\"$expected_class\">" "$html"; then
    pass "$name has correct class=\"$expected_class\""
  else
    fail "$name has wrong class (expected $expected_class)"
  fi

  # Header nav has an active link pointing to the correct section.
  # Writing articles: Writing link is active (points to section index).
  # Notes and Emacs articles: Notes link is active (points to merged index).
  case "$dir" in
    ai)      expected_active_href="/ai/" ;;
    writing) expected_active_href="/writing/" ;;
    notes)   expected_active_href="/notes/" ;;
    emacs)   expected_active_href="/notes/" ;;
    *)       expected_active_href="/" ;;
  esac
  active_count=$(grep -c 'class="active"' "$html" || true)
  if [ "$active_count" -ge 1 ]; then
    if grep -q "href=\"$expected_active_href\" class=\"active\"" "$html"; then
      pass "$name header nav marks $expected_active_href as active"
    else
      fail "$name has an active link but it doesn't point to $expected_active_href"
    fi
  else
    fail "$name has no active nav link"
  fi
done

# --------------------------------------------------------------------------
# 4. Homepage validation
# --------------------------------------------------------------------------

echo ""
echo "=== Homepage validation ==="

index="./index.html"

# Home page is generated from markdown
if [ -f "$index" ]; then
  if grep -qE '<h1[^>]*>.+</h1>' "$index"; then
    pass "index.html exists and has heading"
  else
    fail "index.html is missing heading"
  fi
else
  fail "index.html does not exist"
fi

# AI index includes notes and the conversation-editing disclosure.
ai_index="./ai/index.html"
if [ ! -f "$src_root/ai/index.md" ]; then
  if [ -f "$ai_index" ]; then fail "unexpected AI index in this preview"; else pass "unpublished AI section stays out of preview"; fi
elif [ -f "$ai_index" ]; then
  if grep -q '<h1>Artificial Intelligence</h1>' "$ai_index" &&
     grep -qE '<h2[^>]*>Notes</h2>' "$ai_index" &&
     grep -q 'id="conversations-with-ai"' "$ai_index"; then
    pass "ai/index.html has title, Notes, and Conversations with AI sections"
  else
    fail "ai/index.html is missing its title or section headings"
  fi

  if grep -q 'All conversations are edited for clarity and length.' "$ai_index" &&
     grep -q 'href="/ai/tools-that-can-refuse"' "$ai_index" &&
     grep -q 'href="/ai/liberal-or-illiberal"' "$ai_index"; then
    pass "ai/index.html has the conversation disclosure and note links"
  else
    fail "ai/index.html is missing the disclosure or note links"
  fi
else
  fail "ai/index.html does not exist"
fi

# Links page is hand-maintained HTML
links_page="./links.html"
if [ -f "$links_page" ]; then
  if grep -q '<h1>Links</h1>' "$links_page"; then
    pass "links.html exists and has title"
  else
    fail "links.html is missing title"
  fi
  if grep -q 'class="link"' "$links_page"; then
    pass "links.html has link entries"
  else
    fail "links.html has no link entries"
  fi
else
  fail "links.html does not exist"
fi

# Notes index includes the merged Emacs listing.
notes_index="./notes/index.html"
if [ -f "$notes_index" ]; then
  if grep -q '<h1>Notes</h1>' "$notes_index" && grep -q '<h3>Emacs</h3>' "$notes_index"; then
    pass "notes/index.html has Notes and Emacs sections"
  else
    fail "notes/index.html is missing Notes or Emacs headings"
  fi

  if grep -q 'href="/notes/books"' "$notes_index" && grep -q 'href="/emacs/quick-help"' "$notes_index"; then
    pass "notes/index.html lists note and Emacs URLs"
  else
    fail "notes/index.html is missing note or Emacs links"
  fi
else
  fail "notes/index.html does not exist"
fi

# Require the shared stylesheet, but leave typography and layout choices free
# to change. Check wrapping, alignment, and readability in the browser.
style_css="./style.css"
if [ -s "$style_css" ]; then
  pass "style.css exists and is non-empty"
else
  fail "style.css is missing or empty"
fi

# --------------------------------------------------------------------------
# 5. Crawler and agent discovery
# --------------------------------------------------------------------------

echo ""
echo "=== Crawler and agent discovery ==="

robots="./robots.txt"
if [ -f "$robots" ] &&
   grep -q '^Sitemap: https://olivertaylor.net/sitemap.xml$' "$robots" &&
   grep -q '^Content-Signal: ai-train=no, search=yes, ai-input=yes$' "$robots" &&
   grep -q '^User-agent: OAI-SearchBot$' "$robots" &&
   grep -q '^User-agent: Claude-SearchBot$' "$robots"; then
  pass "robots.txt publishes crawl and content-use policy"
else
  fail "robots.txt is missing required crawl or content-use directives"
fi

sitemap="./sitemap.xml"
if [ -f "$sitemap" ] &&
   grep -q '<loc>https://olivertaylor.net/</loc>' "$sitemap" &&
   ! grep -qE '<loc>[^<]+\.(html|pdf)</loc>' "$sitemap"; then
  pass "sitemap.xml contains canonical extensionless URLs"
else
  fail "sitemap.xml is missing or contains non-canonical URLs"
fi

while IFS='|' read -r section path title description; do
  [ -z "${section:-}" ] && continue
  [[ "$section" = \#* ]] && continue
  if grep -Fq "<loc>https://olivertaylor.net$path</loc>" "$sitemap"; then
    pass "sitemap includes $path"
  else
    fail "sitemap is missing $path"
  fi
done < "$nav_file"

canonical_pages=(
  "./index.html|https://olivertaylor.net/"
  "./writing/index.html|https://olivertaylor.net/writing/"
  "./notes/index.html|https://olivertaylor.net/notes/"
  "./emacs/index.html|https://olivertaylor.net/emacs/"
  "./links.html|https://olivertaylor.net/links"
)

if [ -f "$src_root/ai/index.md" ]; then
  canonical_pages+=("./ai/index.html|https://olivertaylor.net/ai/")
fi

for entry in "${canonical_pages[@]}"; do
  page="${entry%%|*}"
  canonical="${entry#*|}"
  if grep -Fq "<link rel=\"canonical\" href=\"$canonical\" />" "$page"; then
    pass "${page#./} has canonical URL"
  else
    fail "${page#./} has missing or incorrect canonical URL"
  fi
done

for md in "$src_root"/ai/*.md "$src_root"/emacs/*.md "$src_root"/notes/*.md "$src_root"/writing/*.md; do
  [ -e "$md" ] || continue
  rel="${md#$src_root/}"
  [ "$rel" = "writing/index.md" ] && continue
  [ "$rel" = "ai/index.md" ] && continue
  page="./${rel%.md}.html"
  canonical="https://olivertaylor.net/${rel%.md}"
  if grep -Fq "<link rel=\"canonical\" href=\"$canonical\" />" "$page"; then
    pass "${page#./} has canonical URL"
  else
    fail "${page#./} has missing or incorrect canonical URL"
  fi
done

# --------------------------------------------------------------------------
# 6. HTML escaping (Bash patsub_replacement)
# --------------------------------------------------------------------------

echo ""
echo "=== HTML escaping ==="

# Load the real escape_html from the build script and require valid entities
# with patsub_replacement forced on and off. The on case is the Bash 5.2
# default that used to emit Won'#39;t for an apostrophe.
if bash --noprofile --norc -s <<'EOF'
set -euo pipefail
eval "$(sed -n '/^escape_html() {$/,/^}$/p' scripts/build.sh)"
if ! declare -F escape_html >/dev/null; then
  echo "  FAIL: could not load escape_html from scripts/build.sh" >&2
  exit 1
fi

errors=0
expect() {
  local mode="$1" label="$2" input="$3" expected="$4" actual
  actual="$(escape_html "$input")"
  if [ "$actual" = "$expected" ]; then
    printf '  ok: escape_html %s with patsub_replacement %s\n' "$label" "$mode"
  else
    printf '  FAIL: escape_html %s with patsub_replacement %s\n    expected: %s\n    actual:   %s\n' \
      "$label" "$mode" "$expected" "$actual"
    errors=$((errors + 1))
  fi
}

run_cases() {
  local mode="$1"
  local label input expected
  while IFS='|' read -r label input expected; do
    [ -n "$label" ] || continue
    expect "$mode" "$label" "$input" "$expected"
  done <<'CASES'
apostrophe|Won't|Won&#39;t
ampersand|a&b|a&amp;b
less-than|a<b|a&lt;b
greater-than|a>b|a&gt;b
quote|a"b|a&quot;b
combined|Won't <b> "q" & x|Won&#39;t &lt;b&gt; &quot;q&quot; &amp; x
CASES
}

if shopt -s patsub_replacement 2>/dev/null; then
  run_cases on
else
  echo "  ok: patsub_replacement is unavailable in this Bash; on-mode regression skipped"
fi
shopt -u patsub_replacement 2>/dev/null || true
run_cases off
[ "$errors" -eq 0 ]
EOF
then
  :
else
  fail "escape_html is not stable with patsub_replacement on and off"
fi

emacs_title='Emacs Keybindings That Won&#39;t Get Overridden by Minor Modes'
for page in ./emacs/index.html ./notes/index.html; do
  if [ -f "$page" ] &&
     grep -Fq "$emacs_title" "$page" &&
     ! grep -Fq "Won'#39;t" "$page"; then
    pass "${page#./} keeps a valid apostrophe entity in the Emacs nav title"
  else
    fail "${page#./} has a broken apostrophe escape in the Emacs nav title"
  fi
done

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

echo ""
if [ "$errors" -eq 0 ]; then
  echo "All tests passed."
else
  echo "$errors test(s) FAILED."
  exit 1
fi
