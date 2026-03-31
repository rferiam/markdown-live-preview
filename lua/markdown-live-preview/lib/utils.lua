--- Utility functions for markdown-live-preview
--- Debounce, OS detection, WebSocket accept key, base64, JSON wrappers.

local M = {}

--- Returns a debounced wrapper around `fn`.
--- Successive calls within `ms` milliseconds cancel the previous timer.
---@param fn function
---@param ms integer
---@return function
function M.debounce(fn, ms)
  local timer = vim.uv.new_timer()
  return function(...)
    local args = { ... }
    timer:stop()
    timer:start(ms, 0, vim.schedule_wrap(function()
      fn(unpack(args))
    end))
  end
end

--- Detect the operating system.
---@return 'macos'|'linux'|'windows'|'wsl'
function M.detect_os()
  local uname = vim.uv.os_uname()
  local sysname = uname.sysname
  if sysname == 'Darwin' then
    return 'macos'
  elseif sysname == 'Linux' then
    local release = uname.release or ''
    if release:lower():find('microsoft') or release:lower():find('wsl') then
      return 'wsl'
    end
    return 'linux'
  elseif sysname:find('Windows') or sysname:find('MINGW') or sysname:find('MSYS') then
    return 'windows'
  end
  return 'linux'
end

--- Compute the Sec-WebSocket-Accept value for a client key (RFC 6455).
--- Uses openssl for SHA1 — available on all target platforms.
---@param client_key string the Sec-WebSocket-Key header value
---@return string base64-encoded SHA1 hash
function M.ws_accept_key(client_key)
  local concat = client_key .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
  local cmd = string.format(
    "printf '%%s' '%s' | openssl dgst -sha1 -binary | openssl base64",
    concat:gsub("'", "'\\''")
  )
  local result = vim.fn.system(cmd)
  return vim.trim(result)
end

--- Base64-encode a binary string.
---@param str string
---@return string
function M.base64_encode(str)
  local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local result = {}
  local padding = ''

  local mod = #str % 3
  if mod > 0 then
    padding = string.rep('=', 3 - mod)
    str = str .. string.rep('\0', 3 - mod)
  end

  for i = 1, #str, 3 do
    local b1, b2, b3 = str:byte(i, i + 2)
    local n = b1 * 65536 + b2 * 256 + b3
    result[#result + 1] = b64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
    result[#result + 1] = b64:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
    result[#result + 1] = b64:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
    result[#result + 1] = b64:sub(n % 64 + 1, n % 64 + 1)
  end

  local encoded = table.concat(result)
  if #padding > 0 then
    encoded = encoded:sub(1, -(#padding + 1)) .. padding
  end
  return encoded
end

--- Check whether a buffer handle is still valid and loaded.
---@param buf integer
---@return boolean
function M.buf_is_valid(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)
end

--- JSON encode a Lua table.
---@param tbl table
---@return string
function M.json_encode(tbl)
  return vim.json.encode(tbl)
end

--- JSON decode a string into a Lua table.
---@param str string
---@return table
function M.json_decode(str)
  return vim.json.decode(str)
end

--- Check whether the running Neovim version is at least major.minor.patch.
---@param major integer
---@param minor integer
---@param patch integer
---@return boolean
function M.nvim_version_gte(major, minor, patch)
  local v = vim.version()
  if v.major > major then return true end
  if v.major < major then return false end
  if v.minor > minor then return true end
  if v.minor < minor then return false end
  return v.patch >= patch
end

return M
