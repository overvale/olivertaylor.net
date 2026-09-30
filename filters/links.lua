-- Pandoc Lua filter for the links page.
-- Groups level-2 headings (permalinks) and their content into
-- <div class="link"> wrappers with a <time> element holding the permalink.
--
-- A permalink is the YYYY-MM-DD anchor identifying when a link was added
-- to the site (see CLAUDE.md > Links > Permalinks). Heading text like
-- "2025-02-17a" becomes:
--   href="#2025-02-17a"  display="2025-02-17"
-- Trailing lowercase letters (collision suffixes) are stripped for display
-- but preserved in the anchor so each permalink is unique.

function Pandoc(doc)
  local result = {}
  local current_div = nil

  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level == 2 then
      if current_div then
        table.insert(result, current_div)
      end

      local id = pandoc.utils.stringify(block)
      local display_date = id:gsub("[a-z]+$", "")
      local time_html = '<time class="permalink"><a href="#' .. id .. '">' .. display_date .. '</a></time>'

      current_div = pandoc.Div(
        {pandoc.RawBlock('html', time_html)},
        pandoc.Attr("", {"link"})
      )
    elseif current_div then
      current_div.content:insert(block)
    else
      table.insert(result, block)
    end
  end

  if current_div then
    table.insert(result, current_div)
  end

  return pandoc.Pandoc(result, doc.meta)
end
