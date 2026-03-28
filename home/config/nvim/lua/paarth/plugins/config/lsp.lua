local on_attach = function(_, bufnr)
  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end

    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
  nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
  nmap('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
  nmap('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
  nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
  nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, '[W]orkspace [L]ist Folders')

  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    vim.lsp.buf.format()
  end, { desc = 'Format current buffer with LSP' })
end

local wk = require('which-key')
if wk.add then
  wk.add {
    { '<leader>c', group = '[C]ode' },
    { '<leader>d', group = '[D]ocument' },
    { '<leader>g', group = '[G]it' },
    { '<leader>h', group = 'More git' },
    { '<leader>r', group = '[R]ename' },
    { '<leader>s', group = '[S]earch' },
    { '<leader>w', group = '[W]orkspace' },
  }
elseif wk.register then
  wk.register {
    ['<leader>c'] = { name = '[C]ode' },
    ['<leader>d'] = { name = '[D]ocument' },
    ['<leader>g'] = { name = '[G]it' },
    ['<leader>h'] = { name = 'More git' },
    ['<leader>r'] = { name = '[R]ename' },
    ['<leader>s'] = { name = '[S]earch' },
    ['<leader>w'] = { name = '[W]orkspace' },
  }
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()
local servers = {
  lua_ls = {
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
  },
  html = {
    filetypes = { 'html', 'php', 'twig', 'hbs' },
  },
}

if vim.lsp.config and vim.lsp.enable then
  vim.lsp.config('*', {
    capabilities = capabilities,
    on_attach = on_attach,
  })

  for server, config in pairs(servers) do
    vim.lsp.config(server, config)
  end
else
  local lspconfig = require('lspconfig')
  for server, config in pairs(servers) do
    lspconfig[server].setup(vim.tbl_extend('force', {
      capabilities = capabilities,
      on_attach = on_attach,
    }, config))
  end
end

require('mason').setup()
require('mason-lspconfig').setup {
  ensure_installed = { 'clangd', 'phpactor', 'gopls', 'pyright', 'rust_analyzer', 'ts_ls', 'html', 'lua_ls' },
}

if vim.lsp.enable then
  vim.lsp.enable('hls')
else
  require('lspconfig').hls.setup {
    capabilities = capabilities,
    on_attach = on_attach,
  }
end
