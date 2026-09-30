-- Convert raw HTML <img> and <figure><img><figcaption></figcaption></figure>
-- into real pandoc Image / Figure elements so non-HTML writers (e.g. LaTeX)
-- render them with proper figure environments and captions.

local function extract_img(html)
  local src = html:match('<img[^>]*src%s*=%s*"([^"]+)"')
           or html:match("<img[^>]*src%s*=%s*'([^']+)'")
  if not src then return nil end
  local alt = html:match('<img[^>]*alt%s*=%s*"([^"]*)"')
             or html:match("<img[^>]*alt%s*=%s*'([^']*)'")
             or ""
  return src, alt
end

local function extract_figcaption(html)
  return html:match("<figcaption[^>]*>(.-)</figcaption>")
end

-- Parse a fragment of inline HTML/text into pandoc Inlines.
local function parse_inlines(text)
  if not text or text == "" then return {} end
  local doc = pandoc.read(text, "html")
  if #doc.blocks == 0 then return {} end
  return pandoc.utils.blocks_to_inlines(doc.blocks)
end

function RawBlock(el)
  if el.format ~= "html" then return nil end
  if not el.text:match("<img") then return nil end
  local src, alt = extract_img(el.text)
  if not src then return nil end
  local caption_html = extract_figcaption(el.text)
  local image = pandoc.Image({ pandoc.Str(alt) }, src, alt)
  if caption_html and caption_html ~= "" then
    local caption_inlines = parse_inlines(caption_html)
    return pandoc.Figure(
      { pandoc.Plain({ image }) },
      { long = { pandoc.Plain(caption_inlines) } }
    )
  end
  return pandoc.Para{ image }
end

function RawInline(el)
  if el.format ~= "html" then return nil end
  if not el.text:match("^<img") then return nil end
  local src, alt = extract_img(el.text)
  if not src then return nil end
  return pandoc.Image({ pandoc.Str(alt) }, src, alt)
end
