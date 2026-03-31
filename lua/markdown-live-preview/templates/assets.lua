--- Asset management for markdown-live-preview.
--- Downloads, caches, and serves JS/CSS dependencies.

local M = {}

--- CDN URLs for each asset.
M.cdn_urls = {
  ['marked.min.js'] = 'https://cdn.jsdelivr.net/npm/marked/marked.min.js',
  ['highlight.min.js'] = 'https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js',
  ['github.min.css'] = 'https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github.min.css',
  ['github-dark.min.css'] = 'https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github-dark.min.css',
  ['mermaid.min.js'] = 'https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js',
}

--- Get the data directory for cached assets.
---@return string
function M.get_data_dir()
  return vim.fn.stdpath('data') .. '/markdown-live-preview'
end

--- Get the full path to a cached asset file.
---@param name string asset filename
---@return string
function M.get_asset_path(name)
  return M.get_data_dir() .. '/' .. name
end

--- Read a cached asset file. Returns nil if the file doesn't exist.
---@param name string asset filename
---@return string|nil
function M.read_asset(name)
  local path = M.get_asset_path(name)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local content = f:read('*a')
  f:close()
  return content
end

--- Check whether all required assets are cached.
---@return boolean
function M.assets_exist()
  for name, _ in pairs(M.cdn_urls) do
    local path = M.get_asset_path(name)
    local f = io.open(path, 'r')
    if not f then
      return false
    end
    f:close()
  end
  return true
end

--- Ensure all assets are downloaded. Calls callback(success) when done.
--- Downloads missing assets in parallel via curl.
---@param callback? fun(ok: boolean)
function M.ensure_assets(callback)
  if M.assets_exist() then
    if callback then
      callback(true)
    end
    return
  end

  local dir = M.get_data_dir()
  vim.fn.mkdir(dir, 'p')

  local remaining = 0
  local failed = false

  for name, url in pairs(M.cdn_urls) do
    local path = M.get_asset_path(name)
    local f = io.open(path, 'r')
    if f then
      f:close()
    else
      remaining = remaining + 1
      vim.fn.jobstart({ 'curl', '-sL', '--connect-timeout', '15', '-o', path, url }, {
        on_exit = function(_, code)
          remaining = remaining - 1
          if code ~= 0 then
            failed = true
            -- Clean up partial file
            pcall(os.remove, path)
          end
          if remaining == 0 and callback then
            vim.schedule(function()
              callback(not failed)
            end)
          end
        end,
      })
    end
  end

  -- All assets already existed individually
  if remaining == 0 and callback then
    callback(true)
  end
end

return M
