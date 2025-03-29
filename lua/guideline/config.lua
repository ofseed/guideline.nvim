local M = {}

---@class GuideLine.Options.Ignore
---@field window fun(winid: integer): boolean
---@field buffer fun(bufnr: integer): boolean

---@class GuideLine.OptionsStrict
---@field ignore GuideLine.Options.Ignore

---@class GuideLine.Options : GuideLine.OptionsStrict, {}

function M.make_defaults()
  ---@type GuideLine.OptionsStrict
  return {
    ignore = {
      window = function(winid)
        local config = vim.api.nvim_win_get_config(winid)
        return not config.focusable
      end,
      buffer = function()
        return false
      end,
    },
  }
end

---@type GuideLine.OptionsStrict
M.opts = M.make_defaults()

---@param opts? GuideLine.Options
function M.setup(opts)
  opts = opts or {}
  M.opts = vim.tbl_deep_extend("force", M.opts, opts)
end

return M
