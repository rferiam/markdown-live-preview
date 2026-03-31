--- Buffer lifecycle management for markdown-live-preview.
--- Watches buffer changes and scroll events, pushes updates to the preview server.

local utils = require('markdown-live-preview.lib.utils')

local M = {}

---@type table|nil
local _config = nil

---@type table|nil server module reference
local _server = nil

---@type integer|nil currently attached buffer
local _attached_buf = nil

---@type integer|nil augroup for the attached buffer
local _augroup = nil

--- Flag to prevent scroll feedback loops.
---@type boolean
local _syncing = false

--- Initialize the manager with config and server references.
---@param config table
---@param server table the server module
function M.init(config, server)
  _config = config
  _server = server
end

--- Attach to a buffer: register autocommands for change and scroll events.
---@param buf integer
function M.attach(buf)
  if _attached_buf == buf then
    return
  end
  if not utils.buf_is_valid(buf) then
    return
  end

  -- Detach previous buffer first
  if _attached_buf then
    M.detach(_attached_buf)
  end

  _attached_buf = buf
  _augroup = vim.api.nvim_create_augroup('MarkdownLivePreview_' .. buf, { clear = true })

  local content = require('markdown-live-preview.core.content')

  -- Debounced content push
  local push_content = utils.debounce(function()
    if not utils.buf_is_valid(buf) or not _server then
      return
    end
    local text = content.get_buffer_content(buf)
    _server.broadcast(content.make_content_message(text))
  end, _config.debounce_ms)

  -- Debounced scroll push
  local push_scroll = utils.debounce(function()
    if _syncing then
      return
    end
    if not utils.buf_is_valid(buf) or not _server then
      return
    end
    local win = vim.fn.bufwinid(buf)
    if win == -1 then
      return
    end
    local pos = content.get_scroll_position(win, buf)
    _server.broadcast(content.make_scroll_message(pos))
  end, _config.scroll_debounce_ms)

  -- Text changes → push content
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = _augroup,
    buffer = buf,
    callback = push_content,
  })

  -- Scroll sync (outbound: Neovim → browser)
  if _config.scroll_sync then
    vim.api.nvim_create_autocmd({ 'WinScrolled', 'CursorMoved' }, {
      group = _augroup,
      buffer = buf,
      callback = push_scroll,
    })

    -- Inbound: browser → Neovim
    _server.on_scroll(function(position)
      if not utils.buf_is_valid(buf) then
        return
      end
      local win = vim.fn.bufwinid(buf)
      if win == -1 then
        return
      end

      _syncing = true
      local total = vim.api.nvim_buf_line_count(buf)
      local target_line = math.max(1, math.floor(position * (total - 1)) + 1)
      pcall(vim.api.nvim_win_set_cursor, win, { math.min(target_line, total), 0 })

      vim.defer_fn(function()
        _syncing = false
      end, 200)
    end)
  end

  -- Buffer deletion → stop preview
  vim.api.nvim_create_autocmd('BufDelete', {
    group = _augroup,
    buffer = buf,
    callback = function()
      M.detach(buf)
      vim.schedule(function()
        require('markdown-live-preview').stop()
      end)
    end,
  })

  -- Initial content push (give WS clients a moment to connect)
  vim.defer_fn(function()
    if utils.buf_is_valid(buf) and _server and _server.is_running() then
      local text = content.get_buffer_content(buf)
      _server.broadcast(content.make_content_message(text))
    end
  end, 500)
end

--- Detach from a buffer: remove autocommands.
---@param buf integer
function M.detach(buf)
  if _attached_buf ~= buf then
    return
  end
  _attached_buf = nil

  pcall(vim.api.nvim_del_augroup_by_name, 'MarkdownLivePreview_' .. buf)
  _augroup = nil
end

--- Get the currently attached buffer.
---@return integer|nil
function M.get_attached_buf()
  return _attached_buf
end

return M
