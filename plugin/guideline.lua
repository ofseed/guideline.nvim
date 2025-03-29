local api = vim.api
local guideline = require "guideline"
local highlights = require "guideline.highlights"

local augroup = api.nvim_create_augroup("guideline.nvim", {})

_G.guideline = guideline
highlights.setup()
api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  desc = "Update guideline.nvim highlights",
  callback = function()
    highlights.setup()
  end,
})
