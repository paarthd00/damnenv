require('nvim-treesitter').install({
  'c',
  'cpp',
  'go',
  'lua',
  'python',
  'php',
  'rust',
  'tsx',
  'javascript',
  'typescript',
  'vimdoc',
  'vim',
  'bash',
  'haskell',
})

vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    local ok = pcall(vim.treesitter.start, ev.buf)
    if ok then
      vim.bo[ev.buf].indentexpr = 'v:lua.vim.treesitter.indentexpr()'
    end
  end,
})

vim.defer_fn(function()
  local ok, to = pcall(require, 'nvim-treesitter-textobjects.select')
  if not ok then return end
  local sel = function(q) return function() to.select_textobject(q, 'textobjects') end end
  vim.keymap.set({ 'x', 'o' }, 'aa', sel('@parameter.outer'))
  vim.keymap.set({ 'x', 'o' }, 'ia', sel('@parameter.inner'))
  vim.keymap.set({ 'x', 'o' }, 'af', sel('@function.outer'))
  vim.keymap.set({ 'x', 'o' }, 'if', sel('@function.inner'))
  vim.keymap.set({ 'x', 'o' }, 'ac', sel('@class.outer'))
  vim.keymap.set({ 'x', 'o' }, 'ic', sel('@class.inner'))

  local mov_ok, mv = pcall(require, 'nvim-treesitter-textobjects.move')
  if not mov_ok then return end
  local goto_next_start = function(q) return function() mv.goto_next_start(q, 'textobjects') end end
  local goto_next_end = function(q) return function() mv.goto_next_end(q, 'textobjects') end end
  local goto_prev_start = function(q) return function() mv.goto_previous_start(q, 'textobjects') end end
  local goto_prev_end = function(q) return function() mv.goto_previous_end(q, 'textobjects') end end
  vim.keymap.set('n', ']m', goto_next_start('@function.outer'))
  vim.keymap.set('n', ']]', goto_next_start('@class.outer'))
  vim.keymap.set('n', ']M', goto_next_end('@function.outer'))
  vim.keymap.set('n', '][', goto_next_end('@class.outer'))
  vim.keymap.set('n', '[m', goto_prev_start('@function.outer'))
  vim.keymap.set('n', '[[', goto_prev_start('@class.outer'))
  vim.keymap.set('n', '[M', goto_prev_end('@function.outer'))
  vim.keymap.set('n', '[]', goto_prev_end('@class.outer'))

  local swap_ok, sw = pcall(require, 'nvim-treesitter-textobjects.swap')
  if not swap_ok then return end
  vim.keymap.set('n', '<leader>a', function() sw.swap_next('@parameter.inner') end)
  vim.keymap.set('n', '<leader>A', function() sw.swap_previous('@parameter.inner') end)
end, 0)
