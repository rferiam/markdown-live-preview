--- :checkhealth markdown-live-preview

local M = {}

function M.check()
  vim.health.start('markdown-live-preview')

  -- Neovim version
  local v = vim.version()
  if v.major > 0 or (v.major == 0 and v.minor >= 9) then
    vim.health.ok(string.format('Neovim version: %d.%d.%d', v.major, v.minor, v.patch))
  else
    vim.health.error(string.format('Neovim >= 0.9 required, found: %d.%d.%d', v.major, v.minor, v.patch))
  end

  -- vim.uv
  if vim.uv then
    vim.health.ok('vim.uv (libuv) is available')
  else
    vim.health.error('vim.uv is not available — cannot start server')
  end

  -- Browser command
  local utils = require('markdown-live-preview.lib.utils')
  local os_name = utils.detect_os()
  local browser_cmd
  if os_name == 'macos' then
    browser_cmd = 'open'
  elseif os_name == 'wsl' then
    browser_cmd = 'wslview'
  elseif os_name == 'windows' then
    browser_cmd = 'cmd.exe'
  else
    browser_cmd = 'xdg-open'
  end
  if vim.fn.executable(browser_cmd) == 1 then
    vim.health.ok('Browser command found: ' .. browser_cmd)
  else
    vim.health.warn('Browser command not found: ' .. browser_cmd .. ' — set config.browser manually')
  end

  -- curl
  if vim.fn.executable('curl') == 1 then
    vim.health.ok('curl is available (for asset download)')
  else
    vim.health.warn('curl not found — JS/CSS assets must be downloaded manually')
  end

  -- openssl
  if vim.fn.executable('openssl') == 1 then
    vim.health.ok('openssl is available (for WebSocket handshake)')
  else
    vim.health.error('openssl not found — WebSocket handshake will fail')
  end

  -- Cached assets
  local assets = require('markdown-live-preview.templates.assets')
  if assets.assets_exist() then
    vim.health.ok('Cached JS/CSS assets found in ' .. assets.get_data_dir())
  else
    vim.health.info('JS/CSS assets not yet downloaded — will download on first :MarkdownPreview')
  end

  -- Server status
  local server = require('markdown-live-preview.server')
  if server.is_running() then
    vim.health.ok('Preview server is running at ' .. (server.get_url() or '?'))
  else
    vim.health.info('Preview server is not running')
  end
end

return M
