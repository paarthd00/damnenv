local null_ls = require('null-ls')
null_ls.setup({
  sources = {
    null_ls.builtins.formatting.prettier.with({
      filetypes = {
        'javascript',
        'typescript',
        'css',
        'scss',
        'html',
        'json',
        'yaml',
        'markdown',
        'javascriptreact',
        'typescriptreact',
      },
    }),
    null_ls.builtins.formatting.stylua,
  },
  on_attach = function(_, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
      vim.lsp.buf.format()
    end, { desc = 'Format current buffer with LSP' })
  end,
})
