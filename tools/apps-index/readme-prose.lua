-- oops-apps index: reduce an app's README to prose for the "About" panel.
--
-- Drops images (the card's gallery shows them), the leading level-1 title, and headings
-- left empty; repoints relative links at the repository on github.com. Takes
-- `-M appdir=<repo-relative app dir>` and `-M repo=<owner/name>` from build-apps-index.sh.

function Pandoc(doc)
  local repo = doc.meta.repo and pandoc.utils.stringify(doc.meta.repo) or "project-oops/oops-apps"
  local appdir = doc.meta.appdir and pandoc.utils.stringify(doc.meta.appdir) or ""
  local blob = "https://github.com/" .. repo .. "/blob/main/"

  local function has_img(text) return text:match("<%s*[iI][mM][gG]") ~= nil end

  -- Collapse `a/b/../c` to `a/c`: github resolves no `..`, and pandoc.path.normalize keeps it.
  local function resolve(p)
    local parts = {}
    for seg in p:gmatch("[^/]+") do
      if seg == ".." then
        if #parts > 0 and parts[#parts] ~= ".." then table.remove(parts) else parts[#parts + 1] = seg end
      elseif seg ~= "." and seg ~= "" then
        parts[#parts + 1] = seg
      end
    end
    return table.concat(parts, "/")
  end

  doc = doc:walk {
    Image = function() return {} end,
    RawInline = function(el) if el.format:match("html") and has_img(el.text) then return {} end end,
    RawBlock = function(el) if el.format:match("html") and has_img(el.text) then return {} end end,
    Para = function(el) if #el.content == 0 then return {} end end,
    Link = function(el)
      local t = el.target
      if t:match("^%a[%w+.-]*:") or t:match("^#") or t:match("^//") then return nil end
      local path, anchor = t, ""
      local h = t:find("#", 1, true)
      if h then path, anchor = t:sub(1, h - 1), t:sub(h) end
      if path == "" then return nil end
      el.target = blob .. resolve(appdir .. "/" .. path) .. anchor
      return el
    end,
  }

  local out, blocks = {}, doc.blocks
  local first = 1
  if blocks[1] and blocks[1].t == "Header" and blocks[1].level == 1 then first = 2 end
  for i = first, #blocks do
    local b = blocks[i]
    if b.t == "Header" then
      local nxt = blocks[i + 1]
      if nxt and nxt.t ~= "Header" then out[#out + 1] = b end -- keep only non-empty sections
    else
      out[#out + 1] = b
    end
  end
  return pandoc.Pandoc(out, doc.meta)
end
