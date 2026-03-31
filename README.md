# 📝 markdown-live-preview

Browser-based markdown preview for Neovim with live updates and scroll sync.

<!-- TODO: screenshot -->

## Features

- **Live preview** — opens in your default browser, updates as you type
- **Scroll sync** — bidirectional scroll sync between Neovim and browser
- **GitHub-flavored** — rendered with [marked.js](https://marked.js.org/) for full GFM support
- **Syntax highlighting** — code blocks highlighted with [highlight.js](https://highlightjs.org/)
- **Mermaid diagrams** — rendered client-side with [mermaid.js](https://mermaid.js.org/)
- **Dark/light theme** — auto-detects system preference, manual toggle in browser
- **Zero dependencies** — pure Lua plugin, uses Neovim's built-in `vim.uv` (libuv) for networking
- **Offline capable** — JS/CSS assets downloaded and cached locally on first run

## Requirements

- Neovim ≥ 0.9
- `openssl` (for WebSocket handshake)
- `curl` (for downloading JS/CSS assets on first run)
- A web browser

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'rferiam/markdown-live-preview',
  cmd = { 'MarkdownPreview', 'MarkdownPreviewToggle' },
  ft = 'markdown',
  keys = {
    { '<leader>mp', '<cmd>MarkdownPreview<cr>', desc = 'Start Markdown Preview', ft = 'markdown' },
    { '<leader>ms', '<cmd>MarkdownPreviewStop<cr>', desc = 'Stop Markdown Preview', ft = 'markdown' },
    { '<leader>mt', '<cmd>MarkdownPreviewToggle<cr>', desc = 'Toggle Markdown Preview', ft = 'markdown' },
  },
  opts = {},
}
```

> **Note:** The `keys` spec above serves double duty — it registers the keybindings
> **and** triggers lazy-loading when any of them are pressed. The `ft = 'markdown'`
> on each key ensures the bindings only apply in markdown buffers.

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  'rferia/markdown-live-preview',
  config = function()
    require('markdown-live-preview').setup()
  end,
})
```

### [mini.deps](https://github.com/echasnovski/mini.deps)

```lua
MiniDeps.add({ source = 'rferia/markdown-live-preview' })
require('markdown-live-preview').setup()
```

## Configuration

All options are optional. Defaults shown below:

```lua
require('markdown-live-preview').setup({
  port = 8090,               -- HTTP server port
  host = '127.0.0.1',        -- Server bind address
  browser = '',              -- Browser command (auto-detect if empty)
  auto_close = true,         -- Close browser tab when preview stops
  auto_start = false,        -- Auto-start preview when opening .md files
  scroll_sync = true,        -- Bidirectional scroll sync
  theme = 'auto',            -- 'auto', 'light', or 'dark'
  debounce_ms = 100,         -- Debounce for content updates (ms)
  scroll_debounce_ms = 50,   -- Debounce for scroll sync (ms)
  keys = {
    preview = '<leader>mp',  -- Start preview (set to false to disable)
    stop = '<leader>ms',     -- Stop preview
    toggle = '<leader>mt',   -- Toggle preview
  },
})
```

### Browser Detection

If `browser` is empty, the plugin auto-detects based on your OS:

| OS | Command |
|----|---------|
| macOS | `open` |
| Linux | `xdg-open` |
| WSL | `wslview` or `cmd.exe /c start` |
| Windows | `cmd.exe /c start` |

## Commands

| Command | Description |
|---------|-------------|
| `:MarkdownPreview` | Start preview for current buffer |
| `:MarkdownPreviewStop` | Stop preview and close browser tab |
| `:MarkdownPreviewToggle` | Toggle preview on/off |

## Keybindings

Default keybindings (set in markdown buffers only):

| Key | Action |
|-----|--------|
| `<leader>mp` | Start preview |
| `<leader>ms` | Stop preview |
| `<leader>mt` | Toggle preview |

Disable individual keys by setting them to `false`:

```lua
opts = {
  keys = {
    preview = '<leader>mp',
    stop = false,       -- disable stop keybinding
    toggle = '<C-p>',   -- custom binding
  },
}
```

Disable all keybindings:

```lua
opts = {
  keys = false,
}
```

## Lua API

```lua
local mdp = require('markdown-live-preview')

mdp.setup({})      -- Initialize with config
mdp.start()        -- Start preview
mdp.stop()         -- Stop preview
mdp.toggle()       -- Toggle preview
mdp.is_running()   -- Check if preview is active
```

## How It Works

1. `:MarkdownPreview` downloads JS/CSS assets (first run only) and starts a local HTTP + WebSocket server using `vim.uv`
2. Your default browser opens at `http://127.0.0.1:8090`
3. The browser page establishes a WebSocket connection
4. Buffer changes (`TextChanged`, `TextChangedI`) push content via WebSocket
5. The browser renders markdown client-side with `marked.parse()`, highlights code with `hljs`, and renders mermaid diagrams
6. Scroll events sync bidirectionally between Neovim and the browser
7. `:MarkdownPreviewStop` sends a close signal — the browser tab closes automatically

## Health Check

Run `:checkhealth markdown-live-preview` to verify your setup:

- Neovim version
- `vim.uv` availability
- Browser command detection
- `curl` and `openssl` availability
- Cached asset status
- Server status

## License

MIT — see [LICENSE](LICENSE)
