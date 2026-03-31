--- Server lifecycle management for markdown-live-preview.
--- Coordinates the HTTP server and WebSocket router.

local M = {}

---@type userdata|nil TCP server handle
local _server = nil

---@type table|nil Router instance
local _router = nil

---@type table|nil Active config
local _config = nil

--- Start the preview server.
---@param config table plugin config
---@return boolean success
function M.start(config)
  if _server then
    return true
  end
  _config = config

  local http = require('markdown-live-preview.server.http')
  local Router = require('markdown-live-preview.server.router')

  _router = Router.new(config)

  -- Auto-stop when all browser tabs close (guarded by auto_close config)
  if config.auto_close then
    _router:on_empty(function()
      vim.schedule(function()
        if M.is_running() then
          require('markdown-live-preview').stop()
        end
      end)
    end)
  end

  _server = http.create_server(config.host, config.port, function(client, method, path, headers, body)
    _router:handle_request(client, method, path, headers, body)
  end)

  if not _server then
    _router = nil
    _config = nil
    return false
  end

  return true
end

--- Stop the preview server and close all connections.
function M.stop()
  if not _server then
    return
  end

  if _router then
    _router:close_all()
    _router = nil
  end

  pcall(function()
    _server:close()
  end)
  _server = nil
  _config = nil
end

--- Broadcast a message to all connected WebSocket clients.
---@param msg string
function M.broadcast(msg)
  if _router then
    _router:broadcast(msg)
  end
end

--- Register a callback for incoming scroll events from the browser.
---@param callback fun(position: number)
function M.on_scroll(callback)
  if _router then
    _router:on_scroll(callback)
  end
end

--- Check if the server is currently running.
---@return boolean
function M.is_running()
  return _server ~= nil
end

--- Get the server URL.
---@return string|nil
function M.get_url()
  if not _config then
    return nil
  end
  return string.format('http://%s:%d', _config.host, _config.port)
end

return M
