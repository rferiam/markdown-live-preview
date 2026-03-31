--- RFC 6455 WebSocket protocol implementation for markdown-live-preview.
--- Handles handshake, frame encoding/decoding, and message I/O.

local bit = require('bit')

local M = {}

-- Opcodes
M.TEXT = 0x1
M.BINARY = 0x2
M.CLOSE = 0x8
M.PING = 0x9
M.PONG = 0xA

--- Perform the WebSocket handshake (server side).
--- Validates the Upgrade request and sends the 101 Switching Protocols response.
---@param client userdata TCP handle
---@param headers table<string, string> parsed HTTP headers (lower-cased keys)
---@return boolean success
function M.handshake(client, headers)
  local key = headers['sec-websocket-key']
  if not key then
    return false
  end

  local utils = require('markdown-live-preview.lib.utils')
  local accept = utils.ws_accept_key(key)

  local http = require('markdown-live-preview.server.http')
  http.send_response(client, 101, {
    ['Upgrade'] = 'websocket',
    ['Connection'] = 'Upgrade',
    ['Sec-WebSocket-Accept'] = accept,
  })

  return true
end

--- Encode a WebSocket frame (server → client, NOT masked).
---@param payload string
---@param opcode? integer defaults to TEXT (0x1)
---@return string binary frame data
function M.encode_frame(payload, opcode)
  opcode = opcode or M.TEXT
  local len = #payload
  local first_byte = bit.bor(0x80, opcode) -- FIN=1

  local header
  if len <= 125 then
    header = string.char(first_byte, len)
  elseif len <= 65535 then
    header = string.char(
      first_byte,
      126,
      bit.rshift(len, 8),
      bit.band(len, 0xFF)
    )
  else
    -- 64-bit length: build 8 bytes big-endian
    local bytes = {}
    local remaining = len
    for i = 8, 1, -1 do
      bytes[i] = remaining % 256
      remaining = math.floor(remaining / 256)
    end
    header = string.char(first_byte, 127, unpack(bytes))
  end

  return header .. payload
end

--- Decode a WebSocket frame from a data buffer.
--- Returns nil if the buffer doesn't contain a complete frame yet.
---@param data string accumulated buffer
---@return table|nil frame {fin: boolean, opcode: integer, payload: string}
---@return string remaining unprocessed data
function M.decode_frame(data)
  if #data < 2 then
    return nil, data
  end

  local b1 = data:byte(1)
  local b2 = data:byte(2)

  local fin = bit.band(b1, 0x80) ~= 0
  local opcode = bit.band(b1, 0x0F)
  local masked = bit.band(b2, 0x80) ~= 0
  local payload_len = bit.band(b2, 0x7F)

  local offset = 2

  if payload_len == 126 then
    if #data < 4 then
      return nil, data
    end
    payload_len = data:byte(3) * 256 + data:byte(4)
    offset = 4
  elseif payload_len == 127 then
    if #data < 10 then
      return nil, data
    end
    payload_len = 0
    for i = 3, 10 do
      payload_len = payload_len * 256 + data:byte(i)
    end
    offset = 10
  end

  local mask_key
  if masked then
    if #data < offset + 4 then
      return nil, data
    end
    mask_key = { data:byte(offset + 1, offset + 4) }
    offset = offset + 4
  end

  if #data < offset + payload_len then
    return nil, data
  end

  local payload = data:sub(offset + 1, offset + payload_len)

  -- Unmask client frames
  if masked and mask_key then
    local unmasked = {}
    for i = 1, #payload do
      unmasked[i] = string.char(bit.bxor(payload:byte(i), mask_key[((i - 1) % 4) + 1]))
    end
    payload = table.concat(unmasked)
  end

  local remaining = data:sub(offset + payload_len + 1)

  return {
    fin = fin,
    opcode = opcode,
    payload = payload,
  }, remaining
end

--- Send a text message to a WebSocket client.
---@param client userdata TCP handle
---@param message string
function M.send(client, message)
  local frame = M.encode_frame(message, M.TEXT)
  pcall(function()
    client:write(frame)
  end)
end

--- Send a close frame to a WebSocket client.
---@param client userdata TCP handle
function M.send_close(client)
  local frame = M.encode_frame('', M.CLOSE)
  pcall(function()
    client:write(frame)
  end)
end

--- Send a ping frame.
---@param client userdata TCP handle
---@param payload? string optional ping payload
function M.send_ping(client, payload)
  local frame = M.encode_frame(payload or '', M.PING)
  pcall(function()
    client:write(frame)
  end)
end

--- Send a pong frame (reply to ping).
---@param client userdata TCP handle
---@param payload? string echo back the ping payload
function M.send_pong(client, payload)
  local frame = M.encode_frame(payload or '', M.PONG)
  pcall(function()
    client:write(frame)
  end)
end

return M
