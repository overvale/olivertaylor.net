-- Drop `dir` attributes from Span elements so LaTeX output doesn't emit
-- \RL{} (which requires the bidi package). The web build keeps them.
function Span(el)
  el.attributes.dir = nil
  return el
end
