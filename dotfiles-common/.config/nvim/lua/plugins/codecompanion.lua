return {
	"olimorris/codecompanion.nvim",
	config = function()
		require("codecompanion").setup({
			adapters = {
				gemini = function()
					return require("codecompanion.adapters").extend("gemini", {
						env = {
							api_key = vim.fn.getenv("GOOGLE_API_KEY"),
						},
					})
				end,
			},
			strategies = {
				chat = { adapter = "gemini" },
				inline = { adapter = "gemini" },
			},
		})
	end,
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
}
