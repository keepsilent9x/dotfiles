local M = {
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "neovim/nvim-lspconfig",
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp"
  },
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-path",
  "hrsh7th/cmp-buffer",
  "hrsh7th/cmp-cmdline",
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/cmp-nvim-lsp-signature-help",
  "hrsh7th/cmp-nvim-lsp-document-symbol",
  "saadparwaiz1/cmp_luasnip",
  "rasulomaroff/cmp-bufname",
  "JMarkin/cmp-diag-codes",
}

return M
