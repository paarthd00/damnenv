local specs = {}

local function extend(list)
  for _, item in ipairs(list) do
    specs[#specs + 1] = item
  end
end

extend(require('paarth.plugins.specs.git'))
extend(require('paarth.plugins.specs.ui'))
extend(require('paarth.plugins.specs.misc'))
extend(require('paarth.plugins.specs.lsp'))
extend(require('paarth.plugins.specs.cmp'))
extend(require('paarth.plugins.specs.none_ls'))
extend(require('paarth.plugins.specs.telescope'))
extend(require('paarth.plugins.specs.copilot'))
extend(require('paarth.plugins.specs.treesitter'))

require('lazy').setup(specs, {})

require('paarth.plugins.config.telescope')
require('paarth.plugins.config.treesitter')
require('paarth.plugins.config.lsp')
require('paarth.plugins.config.none_ls')
require('paarth.plugins.config.cmp')
require('paarth.plugins.config.colors')
