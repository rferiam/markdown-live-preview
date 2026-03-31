--- Route handling and WebSocket client tracking for markdown-live-preview.

local M = {}
M.__index = M

--- Create a new router instance.
---@param config table plugin config
---@return table router instance
function M.new(config)
  return setmetatable({
    clients = {},
    config = config,
    _on_scroll = nil,
  }, M)
end

--- Route an incoming HTTP request to the appropriate handler.
---@param client userdata TCP handle
---@param method string HTTP method
---@param path string request path
---@param headers table<string, string> lower-cased header keys
---@param body string request body
function M:handle_request(client, method, path, headers, body) -- luacheck: no unused args
  -- WebSocket upgrade
  if headers['upgrade'] and headers['upgrade']:lower() == 'websocket' then
    self:_handle_websocket(client, headers)
    return
  end

  if method == 'GET' and path == '/' then
    self:_serve_page(client)
  elseif method == 'GET' and path:match('^/assets/') then
    self:_serve_asset(client, path)
  else
    local http = require('markdown-live-preview.server.http')
    http.send_response(client, 404, { ['Content-Type'] = 'text/plain' }, 'Not Found')
  end
end

--- Serve the HTML preview page.
---@param client userdata
function M:_serve_page(client)
  local page = require('markdown-live-preview.templates.page')
  local html = page.generate(self.config)
  local http = require('markdown-live-preview.server.http')
  http.send_response(client, 200, {
    ['Content-Type'] = 'text/html; charset=utf-8',
    ['Cache-Control'] = 'no-cache',
  }, html)
end

--- Serve a cached JS/CSS asset.
---@param client userdata
---@param path string e.g. "/assets/marked.min.js"
function M:_serve_asset(client, path)
  local filename = path:match('^/assets/(.+)$')
  local http = require('markdown-live-preview.server.http')

  if not filename then
    http.send_response(client, 404, { ['Content-Type'] = 'text/plain' }, 'Not Found')
    return
  end

  local assets = require('markdown-live-preview.templates.assets')
  local content = assets.read_asset(filename)

  if not content then
    http.send_response(client, 404, { ['Content-Type'] = 'text/plain' }, 'Asset not found: ' .. filename)
    return
  end

  local content_type = 'application/octet-stream'
  if filename:match('%.js$') then
    content_type = 'text/javascript; charset=utf-8'
  elseif filename:match('%.css$') then
    content_type = 'text/css; charset=utf-8'
  end

  http.send_response(client, 200, {
    ['Content-Type'] = content_type,
    ['Cache-Control'] = 'public, max-age=86400',
  }, content)
end

--- Handle a WebSocket upgrade request.
---@param client userdata
---@param headers table
function M:_handle_websocket(client, headers)
  local ws = require('markdown-live-preview.server.websocket')
  local ok = ws.handshake(client, headers)
  if not ok then
    local http = require('markdown-live-preview.server.http')
    http.send_response(client, 400, { ['Content-Type'] = 'text/plain' }, 'Bad WebSocket handshake')
    return
  end

  local entry = { socket = client, buffer = '' }
  table.insert(self.clients, entry)

  -- Read WebSocket frames on this connection
  client:read_start(function(err, data)
    if err or not data then
      vim.schedule(function()
        self:remove_client(client)
      end)
      return
    end

    vim.schedule(function()
      self:_handle_ws_data(entry, data)
    end)
  end)
end

--- Process incoming WebSocket data (may contain multiple or partial frames).
---@param entry table {socket, buffer}
---@param data string raw bytes
function M:_handle_ws_data(entry, data)
  local ws = require('markdown-live-preview.server.websocket')
  entry.buffer = entry.buffer .. data

  while #entry.buffer > 0 do
    local frame, remaining = ws.decode_frame(entry.buffer)
    if not frame then
      break
    end

    entry.buffer = remaining

    if frame.opcode == ws.CLOSE then
      self:remove_client(entry.socket)
      return
    elseif frame.opcode == ws.PING then
      ws.send_pong(entry.socket, frame.payload)
    elseif frame.opcode == ws.PONG then
      -- ignore
    elseif frame.opcode == ws.TEXT then
      self:_handle_ws_message(frame.payload)
    end
  end
end

--- Dispatch a decoded WebSocket text message.
---@param payload string JSON string
function M:_handle_ws_message(payload)
  local ok, msg = pcall(vim.json.decode, payload)
  if not ok or type(msg) ~= 'table' then
    return
  end

  if msg.type == 'scroll' and self._on_scroll then
    self._on_scroll(msg.position)
  end
end

--- Register a callback for incoming scroll events from the browser.
---@param callback fun(position: number)
function M:on_scroll(callback)
  self._on_scroll = callback
end

--- Broadcast a message to all connected WebSocket clients.
---@param message string
function M:broadcast(message)
  local ws = require('markdown-live-preview.server.websocket')
  for i = #self.clients, 1, -1 do
    local entry = self.clients[i]
    local ok = pcall(function()
      ws.send(entry.socket, message)
    end)
    if not ok then
      table.remove(self.clients, i)
    end
  end
end

--- Remove and close a WebSocket client.
---@param socket userdata
function M:remove_client(socket)
  for i = #self.clients, 1, -1 do
    if self.clients[i].socket == socket then
      table.remove(self.clients, i)
      pcall(function()
        socket:read_stop()
      end)
      pcall(function()
        socket:close()
      end)
      return
    end
  end
end

--- Send close frames to all clients and shut down all connections.
function M:close_all()
  local ws = require('markdown-live-preview.server.websocket')
  for _, entry in ipairs(self.clients) do
    pcall(function()
      ws.send_close(entry.socket)
    end)
    pcall(function()
      entry.socket:read_stop()
    end)
    pcall(function()
      entry.socket:close()
    end)
  end
  self.clients = {}
end

return M
