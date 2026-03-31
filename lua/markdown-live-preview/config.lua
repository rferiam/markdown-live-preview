--- Configuration for markdown-live-preview (browser-based preview).
--- Provides sane defaults and a deep-merge utility.

local M = {}

---@class MarkdownLivePreview.Config
M.defaults = {
  port = 8090,
  host = '127.0.0.1',
  browser = '', -- auto-detect if empty (open/xdg-open/start)
  auto_close = true, -- close browser tab when preview stops
  auto_start = false, -- auto-start preview when opening .md files
  scroll_sync = true, -- bidirectional scroll sync
  theme = 'auto', -- 'auto', 'light', 'dark'
  debounce_ms = 100, -- debounce for content updates
  scroll_debounce_ms = 50, -- debounce for scroll sync
  keys = {
    preview = '<leader>mp', -- start preview (set to false to disable)
    stop = '<leader>ms', -- stop preview
    toggle = '<leader>mt', -- toggle preview
  },
}

---@param dst table
---@param src table
---@return table
local function deep_merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == 'table' and type(dst[k]) == 'table' then
      deep_merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

--- Apply user overrides on top of defaults.
--- Returns a new config table (does not mutate defaults).
---@param user_config? table
---@return MarkdownLivePreview.Config
function M.apply(user_config)
  local config = vim.deepcopy(M.defaults)
  if user_config then
    deep_merge(config, user_config)
  end
  return config
end

return M
