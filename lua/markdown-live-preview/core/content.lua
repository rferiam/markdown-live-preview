--- Buffer content extraction and message formatting for markdown-live-preview.

local utils = require('markdown-live-preview.lib.utils')

local M = {}

--- Get the full text content of a buffer.
---@param buf integer
---@return string
function M.get_buffer_content(buf)
  if not utils.buf_is_valid(buf) then
    return ''
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(lines, '\n')
end

--- Calculate scroll position as a ratio (0.0–1.0).
---@param win integer
---@param buf integer
---@return number
function M.get_scroll_position(win, buf)
  if not utils.buf_is_valid(buf) then
    return 0
  end
  local total = vim.api.nvim_buf_line_count(buf)
  if total <= 1 then
    return 0
  end
  local info = vim.fn.getwininfo(win)
  if not info or #info == 0 then
    return 0
  end
  local topline = info[1].topline
  return math.min(1, math.max(0, (topline - 1) / (total - 1)))
end

--- Build a JSON content message.
---@param content string
---@return string
function M.make_content_message(content)
  return utils.json_encode({ type = 'content', data = content })
end

--- Build a JSON scroll message.
---@param position number 0.0–1.0
---@return string
function M.make_scroll_message(position)
  return utils.json_encode({ type = 'scroll', position = position })
end

--- Build a JSON close message.
---@return string
function M.make_close_message()
  return utils.json_encode({ type = 'close' })
end

return M
