return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function ()
			require("nvim-treesitter.configs").setup({
				ensure_installed = { "hyprlang", "go", "lua" },
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = "gnn",
						node_incremental = "grn",
						scope_incremental = "grc",
						node_decremental = "grm",
					},
				},
				indent = {
					enable = true
				},
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
			})
		end
	}
}
