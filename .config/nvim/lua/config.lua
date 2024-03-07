local mason = require("mason")
local mason_lsp_cfg = require("mason-lspconfig")
local lsp_cfg = require("lspconfig")
local cmp = require("cmp")
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

mason.setup({})
mason_lsp_cfg.setup({
  ensure_installed = { "lua_ls", "gopls", "golangci_lint_ls" },
})

lsp_cfg.lua_ls.setup({
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" }
      }
    }
  },
  capabilities = capabilities,
})

lsp_cfg.gopls.setup({
  capabilities = capabilities,
})

lsp_cfg.golangci_lint_ls.setup({
  capabilities = capabilities,
})

cmp.setup({
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end
  },
  sources = {
    { name = "path" },
    { name = "buffer" },
    { name = "luasnip" },
    { name = "bufname" },
    { name = "diag-codes" },
    { name = "nvim_lsp" },
    { name = "nvim_lsp_signature_help" },
    { name = "nvim_lsp_document_symbol" }
  },
  enabled = function()
    local context = require ("cmp.config.context")

    if vim.api.nvim_get_mode().mode == "c" then
      return true
    else
      return not context.in_treesitter_capture("comment")
        and not context.in_syntax_group("Comment")
    end

    end
})

cmp.event:on(
  "confirm_done",
  cmp_autopairs.on_confirm_done()
)

cmp.setup.cmdline("/", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = "buffer" }
  }
})

cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources(
    {
      { name = "path" }
    },
    {
      {
        name = "cmdline",
        option = {
          ignore_cmds = { "Man", "!" }
        }
      }
    })
})

