-- Convert ALL-CAPS abbreviations (2+ capital letters) to small caps.
-- e.g. NASA, VFX, CEO -> \textsc{nasa}, \textsc{vfx}, \textsc{ceo}
-- Handles leading/trailing punctuation and possessives with straight or
-- curly apostrophes (NASA's, NASA’s). Processes metadata too (abstract).

local CURLY_APOS = "\226\128\153"  -- U+2019 as UTF-8 bytes

local function is_acceptable_tail(tail)
  if tail == "" then return true end
  -- Strip optional possessive: apostrophe (straight or curly) + optional s.
  local stripped = tail:gsub("^'", ""):gsub("^" .. CURLY_APOS, "")
  if stripped ~= tail then
    stripped = stripped:gsub("^s", "")
  end
  -- Remainder must be non-letter bytes only.
  return stripped:match("^%A*$") ~= nil
end

local function process_str(el)
  local text = el.text
  local lead, word, tail = text:match("^(%A*)([A-Z][A-Z]+)(.*)$")
  if not word then return nil end
  if not is_acceptable_tail(tail) then return nil end
  local result = {}
  if lead ~= "" then
    table.insert(result, pandoc.Str(lead))
  end
  table.insert(result, pandoc.SmallCaps({ pandoc.Str(word:lower()) }))
  if tail ~= "" then
    table.insert(result, pandoc.Str(tail))
  end
  return result
end

return {
  {
    Pandoc = function(doc)
      -- Preserve the original title (e.g. "NASA") for the HTML <title> tag
      -- via $pagetitle$, before the filter lowercases matches into SmallCaps.
      if doc.meta.title and not doc.meta.pagetitle then
        doc.meta.pagetitle = pandoc.MetaString(pandoc.utils.stringify(doc.meta.title))
      end
      return doc:walk({ Str = process_str })
    end,
  },
}
