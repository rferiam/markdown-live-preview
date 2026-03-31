--- HTTP server built on vim.uv TCP for markdown-live-preview.
--- Parses a single HTTP request per connection, then delegates to a handler.
--- WebSocket upgrade connections are handed off (kept alive); all others close.

local M = {}

local STATUS_TEXT = {
  [101] = 'Switching Protocols',
  [200] = 'OK',
  [304] = 'Not Modified',
  [400] = 'Bad Request',
  [404] = 'Not Found',
  [500] = 'Internal Server Error',
}

--- Create and bind an HTTP server.
---@param host string
---@param port integer
---@param on_request fun(client: userdata, method: string, path: string, headers: table, body: string)
---@return userdata|nil server handle, or nil on error
function M.create_server(host, port, on_request)
  local server = vim.uv.new_tcp()

  local ret, bind_err = server:bind(host, port)
  if not ret then
    vim.schedule(function()
      vim.notify(
        '[markdown-live-preview] Failed to bind ' .. host .. ':' .. port .. ': ' .. tostring(bind_err),
        vim.log.levels.ERROR
      )
    end)
    pcall(function()
      server:close()
    end)
    return nil
  end

  server:listen(128, function(listen_err)
    if listen_err then
      vim.schedule(function()
        vim.notify('[markdown-live-preview] Listen error: ' .. listen_err, vim.log.levels.ERROR)
      end)
      return
    end

    local client = vim.uv.new_tcp()
    server:accept(client)

    local buffer = ''
    local handled = false

    client:read_start(function(read_err, data)
      if handled then
        return
      end

      if read_err then
        pcall(function()
          client:close()
        end)
        return
      end

      if not data then
        pcall(function()
          client:close()
        end)
        return
      end

      buffer = buffer .. data

      -- Wait for complete HTTP headers
      local header_end = buffer:find('\r\n\r\n')
      if not header_end then
        return
      end

      handled = true
      client:read_stop()

      local header_str = buffer:sub(1, header_end - 1)
      local body = buffer:sub(header_end + 4)
      buffer = ''

      local lines = vim.split(header_str, '\r\n')
      local request_line = lines[1] or ''
      local method, path = request_line:match('^(%S+)%s+(%S+)')

      if not method then
        pcall(function()
          client:close()
        end)
        return
      end

      local headers = {}
      for i = 2, #lines do
        local key, value = lines[i]:match('^([^:]+):%s*(.+)')
        if key then
          headers[key:lower()] = value
        end
      end

      vim.schedule(function()
        on_request(client, method, path, headers, body)
      end)
    end)
  end)

  return server
end

--- Format and send an HTTP response.
--- Automatically closes the connection after sending, unless status is 101
--- (WebSocket upgrade — connection stays alive for frame I/O).
---@param client userdata TCP handle
---@param status integer HTTP status code
---@param headers table<string, string> response headers
---@param body? string response body
function M.send_response(client, status, headers, body)
  headers = headers or {}

  if body and #body > 0 then
    headers['Content-Length'] = tostring(#body)
  end

  local parts = {
    string.format('HTTP/1.1 %d %s\r\n', status, STATUS_TEXT[status] or 'OK'),
  }

  for key, value in pairs(headers) do
    parts[#parts + 1] = key .. ': ' .. value .. '\r\n'
  end
  parts[#parts + 1] = '\r\n'

  if body then
    parts[#parts + 1] = body
  end

  local response = table.concat(parts)

  local ok = pcall(function()
    client:write(response, function(write_err)
      if write_err then
        pcall(function()
          client:close()
        end)
      elseif status ~= 101 then
        pcall(function()
          client:shutdown(function()
            pcall(function()
              client:close()
            end)
          end)
        end)
      end
    end)
  end)

  if not ok then
    pcall(function()
      client:close()
    end)
  end
end

return M
