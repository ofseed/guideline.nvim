local api = vim.api

---@class GuideLine.Highlight
---@field name string
---@field fg? string
---@field bold? boolean

local M = {}

---@param color integer
---@return integer
local function darken(color)
  local factor = 0.7
  local x = color
  local r = math.floor(x / 2 ^ 16)
  color = x - (r * 2 ^ 16)
  local g = math.floor(color / 2 ^ 8)
  local b = math.floor(color - (g * 2 ^ 8))
  return math.floor(
    math.floor(r * factor) * 2 ^ 16
      + math.floor(g * factor) * 2 ^ 8
      + math.floor(b * factor)
  )
end

function M.setup()
  vim.api.nvim_set_hl(0, "GuideLineSel", {
    bg = vim.api.nvim_get_hl(0, {
      name = "Normal",
      link = false,
    }).bg,
  })
  vim.api.nvim_set_hl(0, "GuideLine", {
    bg = vim.api.nvim_get_hl(0, {
      name = "NormalFloat",
      link = false,
    }).bg,
  })
  vim.api.nvim_set_hl(0, "GuideLineFill", {
    bg = vim.api.nvim_get_hl(0, {
      name = "StatusLine",
      link = false,
    }).bg,
  })
  vim.api.nvim_set_hl(0, "GuideLineSeparatorSel", {
    fg = vim.api.nvim_get_hl(0, {
      name = "FloatTitle",
      link = false,
    }).fg,
    bg = vim.api.nvim_get_hl(0, {
      name = "GuideLineSel",
    }).bg,
  })
  vim.api.nvim_set_hl(0, "GuideLineSeparator", {
    fg = vim.api.nvim_get_hl(0, {
      name = "FloatTitle",
      link = false,
    }).fg,
    bg = vim.api.nvim_get_hl(0, {
      name = "GuideLine",
    }).bg,
  })
  vim.api.nvim_set_hl(0, "GuideLineSeparatorFill", {
    fg = vim.api.nvim_get_hl(0, {
      name = "FloatTitle",
      link = false,
    }).fg,
    bg = vim.api.nvim_get_hl(0, {
      name = "GuideLineFill",
    }).bg,
  })

  ---@type GuideLine.Highlight[]
  local palette = {
    {
      name = "GuideLineIcon",
      fg = "Keyword",
    },
    {
      name = "GuideLineLabel",
      fg = "Normal",
    },
    {
      name = "GuideLineLabelSel",
      fg = "GuideLineLabel",
      bold = true,
    },
    {
      name = "GuideLineCount",
      fg = "GuideLineLabel",
    },
    {
      name = "GuideLineModified",
      fg = "Winbar",
    },
  }

  for i = 1, 4 do
    local name = vim.diagnostic.severity[i]:lower():gsub("^%a", string.upper)
    palette[#palette + 1] = {
      name = "GuideLineDiagnostic" .. name,
      fg = "Diagnostic" .. name,
    }
  end

  for _, hl in ipairs(palette) do
    local fg = api.nvim_get_hl(0, { name = hl.fg, link = false }).fg
    local bg = api.nvim_get_hl(0, { name = "GuideLineSel" }).bg
    api.nvim_set_hl(0, hl.name, {
      fg = fg,
      bold = hl.bold,
      bg = bg,
    })
  end

  for _, hl in ipairs(palette) do
    local info = api.nvim_get_hl(0, { name = hl.name })
    local bg = api.nvim_get_hl(0, { name = "GuideLine" }).bg
    api.nvim_set_hl(0, hl.name .. "NC", {
      fg = darken(info.fg),
      bg = bg,
      bold = info.bold,
    })
  end
end

return M
