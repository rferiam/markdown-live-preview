--- markdown-live-preview plugin entry point
--- Guard against double-load, register user commands, optional auto-setup.

if vim.g.loaded_markdown_live_preview then
  return
end
vim.g.loaded_markdown_live_preview = true

vim.api.nvim_create_user_command('MarkdownPreview', function()
  require('markdown-live-preview').start()
end, { desc = 'Start markdown live preview in browser' })

vim.api.nvim_create_user_command('MarkdownPreviewStop', function()
  require('markdown-live-preview').stop()
end, { desc = 'Stop markdown live preview' })

vim.api.nvim_create_user_command('MarkdownPreviewToggle', function()
  require('markdown-live-preview').toggle()
end, { desc = 'Toggle markdown live preview' })

-- Auto-setup if global config variable is set
if vim.g.markdown_live_preview then
  local cfg = type(vim.g.markdown_live_preview) == 'table' and vim.g.markdown_live_preview or {}
  require('markdown-live-preview').setup(cfg)
end
