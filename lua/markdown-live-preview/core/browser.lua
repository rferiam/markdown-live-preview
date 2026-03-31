--- OS-aware browser open/close for markdown-live-preview.

local M = {}

--- Open a URL in the default (or configured) browser.
---@param url string
---@param config? table plugin config (uses config.browser if set)
function M.open(url, config)
  config = config or {}
  local utils = require('markdown-live-preview.lib.utils')

  local cmd
  if config.browser and config.browser ~= '' then
    cmd = { config.browser, url }
  else
    local os_name = utils.detect_os()
    if os_name == 'macos' then
      cmd = { 'open', url }
    elseif os_name == 'wsl' then
      -- Try wslview first (wslu package), fall back to cmd.exe
      if vim.fn.executable('wslview') == 1 then
        cmd = { 'wslview', url }
      else
        cmd = { 'cmd.exe', '/c', 'start', '', url }
      end
    elseif os_name == 'windows' then
      cmd = { 'cmd.exe', '/c', 'start', '', url }
    else
      cmd = { 'xdg-open', url }
    end
  end

  vim.fn.jobstart(cmd, { detach = true })
end

--- Close the browser tab by sending a close message via WebSocket.
--- The page JavaScript calls window.close() when it receives the signal.
function M.close()
  local server = require('markdown-live-preview.server')
  local content = require('markdown-live-preview.core.content')
  if server.is_running() then
    server.broadcast(content.make_close_message())
  end
end

return M
