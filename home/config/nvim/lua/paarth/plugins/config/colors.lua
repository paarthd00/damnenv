local ok, theme = pcall(require, 'paarth.theme')
if not ok then
  theme = {
    colorscheme = 'night-owl',
    transparent = true,
  }
end

vim.cmd.colorscheme(theme.colorscheme)

if theme.transparent ~= false then
  vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
end
