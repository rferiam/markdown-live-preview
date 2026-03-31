--- markdown-live-preview — Public API
--- Browser-based markdown preview with live updates and scroll sync.

local M = {}

---@type table|nil Merged configuration
M.config = nil

---@type boolean Whether setup() has been called
M._ready = false

--- Setup the plugin with optional user overrides.
---@param user_config? table
function M.setup(user_config)
  local cfg = require('markdown-live-preview.config')
  M.config = cfg.apply(user_config)
  M._ready = true

  -- Register keymaps for markdown buffers
  M._setup_keys()

  if M.config.auto_start then
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('MarkdownLivePreviewAutoStart', { clear = true }),
      pattern = { 'markdown', 'markdown.mdx' },
      callback = function()
        if not M.is_running() then
          M.start()
        end
      end,
    })
  end
end

--- Start the preview: download assets, start server, attach to buffer, open browser.
function M.start()
  if not M._ready then
    M.setup()
  end

  local server = require('markdown-live-preview.server')
  if server.is_running() then
    return
  end

  local config = M.config
  local assets = require('markdown-live-preview.templates.assets')

  assets.ensure_assets(function(ok)
    vim.schedule(function()
      if not ok then
        vim.notify(
          '[markdown-live-preview] Some assets failed to download — using CDN fallback',
          vim.log.levels.WARN
        )
      end

      local success = server.start(config)
      if not success then
        return
      end

      local manager = require('markdown-live-preview.core.manager')
      manager.init(config, server)

      local buf = vim.api.nvim_get_current_buf()
      manager.attach(buf)

      -- Brief delay so the server is fully ready before the browser connects
      vim.defer_fn(function()
        local browser = require('markdown-live-preview.core.browser')
        browser.open(server.get_url(), config)
      end, 200)

      vim.notify('[markdown-live-preview] Preview started at ' .. server.get_url(), vim.log.levels.INFO)
    end)
  end)
end

--- Stop the preview: close browser tab, detach buffer, shut down server.
function M.stop()
  local server = require('markdown-live-preview.server')
  local manager = require('markdown-live-preview.core.manager')

  if not server.is_running() then
    return
  end

  -- Send close signal to browser
  if M.config and M.config.auto_close then
    local content = require('markdown-live-preview.core.content')
    server.broadcast(content.make_close_message())

    -- Give the close message time to transmit before tearing down
    vim.defer_fn(function()
      local buf = manager.get_attached_buf()
      if buf then
        manager.detach(buf)
      end
      server.stop()
      vim.notify('[markdown-live-preview] Preview stopped', vim.log.levels.INFO)
    end, 100)
  else
    local buf = manager.get_attached_buf()
    if buf then
      manager.detach(buf)
    end
    server.stop()
    vim.notify('[markdown-live-preview] Preview stopped', vim.log.levels.INFO)
  end
end

--- Toggle the preview on/off.
function M.toggle()
  if M.is_running() then
    M.stop()
  else
    M.start()
  end
end

--- Check if the preview is currently active.
---@return boolean
function M.is_running()
  return require('markdown-live-preview.server').is_running()
end

--- Register buffer-local keymaps for markdown files.
--- Called once during setup(). Uses FileType autocmd for buffer-local bindings.
function M._setup_keys()
  local keys = M.config.keys
  if not keys then
    return
  end

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('MarkdownLivePreviewKeys', { clear = true }),
    pattern = { 'markdown', 'markdown.mdx' },
    callback = function(ev)
      local buf = ev.buf
      local opts = function(desc)
        return { buffer = buf, silent = true, desc = desc }
      end

      if keys.preview then
        vim.keymap.set('n', keys.preview, function()
          require('markdown-live-preview').start()
        end, opts('Start Markdown Preview'))
      end

      if keys.stop then
        vim.keymap.set('n', keys.stop, function()
          require('markdown-live-preview').stop()
        end, opts('Stop Markdown Preview'))
      end

      if keys.toggle then
        vim.keymap.set('n', keys.toggle, function()
          require('markdown-live-preview').toggle()
        end, opts('Toggle Markdown Preview'))
      end
    end,
  })

  -- Also set keymaps for any already-open markdown buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft == 'markdown' or ft == 'markdown.mdx' then
        local opts = function(desc)
          return { buffer = buf, silent = true, desc = desc }
        end
        if keys.preview then
          vim.keymap.set('n', keys.preview, function()
            require('markdown-live-preview').start()
          end, opts('Start Markdown Preview'))
        end
        if keys.stop then
          vim.keymap.set('n', keys.stop, function()
            require('markdown-live-preview').stop()
          end, opts('Stop Markdown Preview'))
        end
        if keys.toggle then
          vim.keymap.set('n', keys.toggle, function()
            require('markdown-live-preview').toggle()
          end, opts('Toggle Markdown Preview'))
        end
      end
    end
  end
end

return M
