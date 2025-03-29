local api = vim.api
local fn = vim.fn

local config = require "guideline.config"

---@param hl string
---@param s string
---@param current? boolean Default to true
local function hl_string(hl, s, current)
  current = current == nil or current == true
  return s == "" and s or ("%%#%s%s#%s"):format(hl, current and "" or "NC", s)
end

---@param components string[]
---@param sep? string
local function render_components(components, sep)
  sep = sep and sep:gsub("%%", "%%%%")
  return ("%s"):rep(#components, sep):format(unpack(components))
end

---@class GuideLine.Buffer
---@field bufnr integer
---@field name string
---@field modified boolean
---@field level_diagnostics table<1|2|3|4, vim.Diagnostic[]>
local Buffer = {}

---@param bufnr integer
---@return GuideLine.Buffer
function Buffer.new(bufnr)
  ---@type GuideLine.Buffer
  local self = setmetatable({}, Buffer)

  self.bufnr = bufnr
  self.name = api.nvim_buf_get_name(bufnr)
  self.modified = vim.bo[bufnr].modified

  self.level_diagnostics = {}
  for i = 1, 4 do
    self.level_diagnostics[i] = vim.diagnostic.get(bufnr, { severity = i })
  end

  return self
end

---A `BufWin` is a `buffer` that is displayed
---by windows with `winids`
---in one specific `tabpage`
---
---@class GuideLine.BufWin
---@field buffer GuideLine.Buffer
---@field winids integer[]
---
---Any of the window is the current window in `self.tabpage`
---@field current boolean
---
---Minimum window number
---@field winnr integer
---
---@field tabpage GuideLine.Tabpage
local BufWin = {}

---@return GuideLine.BufWin
function BufWin.new(buffer, winids, tabpage)
  ---@type GuideLine.BufWin
  local self = setmetatable({}, { __index = BufWin })
  self.tabpage = tabpage
  self.buffer = buffer
  self.winids = winids
  return self
end

---@return string
function BufWin:render()
  local buffer = self.buffer
  local winids = self.winids
  local current = self.tabpage.current

  local components = {}

  local icon = hl_string("GuideLineIcon", " ", current)
  components[#components + 1] = icon

  local name = fn.fnamemodify(buffer.name, ":t")
  if name == "" then
    if fn.buflisted(buffer.bufnr) == 1 then
      name = "[No Name]"
    else
      return ""
    end
  end
  local label = hl_string(
    ("GuideLineLabel%s"):format(self.current and "Sel" or ""),
    name,
    current
  )
  components[#components + 1] = label

  if #winids > 1 then
    local count =
      hl_string("GuideLineCount", ("× %d"):format(#winids), current)
    components[#components + 1] = count
  end

  if buffer.modified then
    local modified = hl_string("GuideLineModified", "[+]", current)
    components[#components + 1] = modified
  end

  local diagnostic_components = {}
  for i = 1, 4 do
    local n = #buffer.level_diagnostics[i]
    if n ~= 0 then
      local signs = (vim.diagnostic.config() or {}).signs
      local text = type(signs) == "table" and signs.text[i]
        or vim.diagnostic.severity[i]:sub(1, 1)
      diagnostic_components[#diagnostic_components + 1] = hl_string(
        ("GuideLineDiagnostic%s"):format(
          vim.diagnostic.severity[i]:lower():gsub("^%a", string.upper)
        ),
        ("%s%d"):format(text, n),
        current
      )
    end
  end
  local rendered_diagnostics = render_components(diagnostic_components, " ")
  if rendered_diagnostics ~= "" then
    components[#components + 1] = rendered_diagnostics
  end

  return render_components(components, " ")
end

---@class GuideLine.Tabpage
---@field tabid integer
---@field bufnr_bufwins table<integer, GuideLine.BufWin?>
---
---Is current tabpage
---@field current boolean
---
---@field guideline GuideLine
local Tabpage = {}

---@param guideline GuideLine
---@param tabid integer
---@return GuideLine.Tabpage
function Tabpage.new(tabid, guideline)
  ---@type GuideLine.Tabpage
  local self = setmetatable({}, { __index = Tabpage })
  self.guideline = guideline
  self.tabid = tabid
  self.current = tabid == api.nvim_get_current_tabpage()

  self.bufnr_bufwins = {}
  local bufnr_bufwin = self.bufnr_bufwins
  for _, winid in ipairs(api.nvim_tabpage_list_wins(tabid)) do
    if not config.opts.ignore.window(winid) then
      local bufnr = api.nvim_win_get_buf(winid)
      if not config.opts.ignore.buffer(bufnr) then
        local buffer = self.guideline.bufnr_buffer[bufnr]
        if not buffer then
          buffer = Buffer.new(bufnr)
        end

        local bufwin = bufnr_bufwin[bufnr]
        if bufwin then
          bufwin.winids[#bufwin.winids + 1] = winid
        else
          bufwin = BufWin.new(buffer, { winid }, self)
          bufnr_bufwin[bufnr] = bufwin
        end
        bufwin.current = bufwin.current
          or api.nvim_tabpage_get_win(tabid) == winid
        bufwin.winnr =
          math.min(bufwin.winnr or math.huge, api.nvim_win_get_number(winid))
      end
    end
  end

  return self
end

---@return string
function Tabpage:render()
  local tabid = self.tabid
  local current = tabid == api.nvim_get_current_tabpage()

  -- Insert bufwins, order by `winnr`
  local bufwin_components = {}
  local winnr_bufwins = {}
  for _, bufwin in pairs(self.bufnr_bufwins) do
    winnr_bufwins[bufwin.winnr] = bufwin
  end
  local bufwins = {}
  for i = 1, fn.tabpagewinnr(api.nvim_tabpage_get_number(tabid), "$") do
    local bufwin = winnr_bufwins[i]
    if bufwin then
      bufwins[#bufwins + 1] = bufwin
      local rendered_bufwin = bufwin:render()
      if rendered_bufwin ~= "" then
        bufwin_components[#bufwin_components + 1] = rendered_bufwin
      end
    end
  end
  local rendered_bufwins = render_components(bufwin_components, " ")
  if rendered_bufwins == "" then
    return ""
  end

  local hl = current and "GuideLineSeparatorSel" or "GuideLineSeparator"
  return render_components {
    current and "%#GuideLine#" or "%#GuideLineSel#",
    hl_string(hl, api.nvim_tabpage_get_number(tabid) == 1 and "▎" or "▏"),
    ("%%%dT"):format(api.nvim_tabpage_get_number(tabid)),
    rendered_bufwins,
    hl_string(hl, "▕"),
    "%T",
  }
end

---@class GuideLine
---@field bufnr_buffer table<integer, GuideLine.Buffer?>
---@field tabid_tabpage table<integer, GuideLine.Tabpage?>
local GuideLine = {}

---@return GuideLine
function GuideLine.new()
  ---@type GuideLine
  local self = setmetatable({}, { __index = GuideLine })
  self.bufnr_buffer = {}

  self.tabid_tabpage = {}
  local tabid_tabpage = self.tabid_tabpage
  for _, tabid in ipairs(api.nvim_list_tabpages()) do
    tabid_tabpage[tabid] = Tabpage.new(tabid, self)
  end

  return self
end

function GuideLine:render()
  -- Insert tabpages, order by `tabnr`
  local tabpage_components = {}
  for tabid, tabpage in pairs(self.tabid_tabpage) do
    tabpage_components[api.nvim_tabpage_get_number(tabid)] = tabpage:render()
  end
  local rendered_tabpages = render_components(tabpage_components)

  return render_components {
    rendered_tabpages,
    hl_string("GuideLineSeparatorFill", "▏"),
    "%#GuideLineFill",
  }
end

---@param opts GuideLine.Options
function GuideLine.setup(opts)
  config.setup(opts)

  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.guideline()"
end

return setmetatable(GuideLine, {
  __call = function()
    return GuideLine.new():render()
  end,
})
