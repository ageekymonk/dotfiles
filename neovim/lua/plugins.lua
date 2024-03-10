packer = require("packer")
return packer.startup(function(use)
	-- Packer can manage itself
	use("wbthomason/packer.nvim")
	use("vim-airline/vim-airline")

	--fold
	use({
		"kevinhwang91/nvim-ufo",
		opt = true,
		wants = { "promise-async" },
		requires = "kevinhwang91/promise-async",
		config = function()
			require("ufo").setup({
				provider_selector = function(bufnr, filetype)
					return { "lsp", "indent" }
				end,
			})
			vim.keymap.set("n", "zR", require("ufo").openAllFolds)
			vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
		end,
	})
	-- Snippet engine and snippet template
	use({ "SirVer/ultisnips", event = "InsertEnter" })
	use({ "honza/vim-snippets", after = "ultisnips" })

	use({ "onsails/lspkind-nvim", event = "VimEnter" })

	use({ "hrsh7th/nvim-cmp", after = "lspkind-nvim", config = [[require('config.cmp')]] })

	-- nvim-cmp completion sources
	use({ "hrsh7th/cmp-nvim-lsp", after = "nvim-cmp" })
	-- use {"hrsh7th/cmp-nvim-lua", after = "nvim-cmp"}
	use({ "hrsh7th/cmp-path", after = "nvim-cmp" })
	use({ "hrsh7th/cmp-buffer", after = "nvim-cmp" })
	use({ "hrsh7th/cmp-omni", after = "nvim-cmp" })

	-- use {"hrsh7th/cmp-cmdline", after = "nvim-cmp"}
	use({ "quangnguyen30192/cmp-nvim-ultisnips", after = { "nvim-cmp", "ultisnips" } })
	if vim.g.is_mac then
		use({ "hrsh7th/cmp-emoji", after = "nvim-cmp" })
	end

	-- nvim-lsp configuration (it relies on cmp-nvim-lsp, so it should be loaded after cmp-nvim-lsp).
	use({ "neovim/nvim-lspconfig", after = "cmp-nvim-lsp", config = [[require('config.lsp')]] })
	use("github/copilot.vim")

	-- treesitter
	-- use({
	-- 	"nvim-treesitter/nvim-treesitter",
	-- 	config = [[require('config.treesitter')]],
	-- })

	-- telescope
	use({ "nvim-lua/popup.nvim" })
	use({ "nvim-lua/plenary.nvim" })
	use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
	use({
		"nvim-telescope/telescope.nvim",
		config = [[require('config.telescope')]],
	})
	-- file explorer
	use({ "kyazdani42/nvim-web-devicons", event = "VimEnter" })
	use({
		"kyazdani42/nvim-tree.lua",
		requires = { "kyazdani42/nvim-web-devicons" },
		config = [[require('config.nvim-tree')]],
	})

	vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])

	use({
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v2.x",
		requires = {
			"nvim-lua/plenary.nvim",
			"kyazdani42/nvim-web-devicons", -- not strictly required, but recommended
			"MunifTanjim/nui.nvim",
		},
	})
	-- Super fast buffer jump
	use({
		"phaazon/hop.nvim",
		event = "VimEnter",
		config = function()
			vim.defer_fn(function()
				require("config.nvim-hop")
			end, 2000)
		end,
	})

	-- Show match number and index for searching
	use({
		"kevinhwang91/nvim-hlslens",
		branch = "main",
		keys = { { "n", "*" }, { "n", "#" }, { "n", "n" }, { "n", "N" } },
		config = [[require('config.hlslens')]],
	})
	-- Stay after pressing * and search selected text
	-- use({"haya14busa/vim-asterisk", event = 'VimEnter'})

	-- Terminal
	use({ "akinsho/toggleterm.nvim", tag = "v2.*", config = [[require('config.terminal')]] })

	-- git
	use({ "TimUntersberger/neogit", requires = "nvim-lua/plenary.nvim", config = [[require('config.git')]] })

	-- tabs
	use({
		"akinsho/bufferline.nvim",
		tag = "v2.*",
		requires = "kyazdani42/nvim-web-devicons",
		config = [[require('config.bufferline')]],
	})

	-- session
	use({ "olimorris/persisted.nvim", config = [[require('config.session')]] })

	-- tasks
	use({ "stevearc/overseer.nvim", config = [[require('config.tasks')]] })

	-- Themes
	use("EdenEast/nightfox.nvim")
	vim.cmd("colorscheme nightfox")

	-- copy
	use({ "ojroques/vim-oscyank", branch = "main" })

	-- comment
	use({ "numToStr/Comment.nvim", config = [[require('config.comment')]] })

	-- use({
	-- 	"danymat/neogen",
	-- 	config = function()
	-- 		require("neogen").setup({})
	-- 	end,
	-- 	requires = "nvim-treesitter/nvim-treesitter",
	-- 	-- Uncomment next line if you want to follow only stable versions
	-- 	-- tag = "*"
	-- })

	use({
		"folke/todo-comments.nvim",
		requires = "nvim-lua/plenary.nvim",
		config = function()
			require("todo-comments").setup({
				-- your configuration comes here
				-- or leave it empty to use the default settings
				-- refer to the configuration section below
			})
		end,
	})
	-- save
	use({
		"Pocco81/auto-save.nvim",
		config = function()
			require("auto-save").setup({
				-- your config goes here
				-- or just leave it empty :)
			})
		end,
	})

	--format
	use({ "mhartington/formatter.nvim", config = [[require('config.formatter')]] })

	--buffer management
	use("moll/vim-bbye")

	--multi cursor
	-- use("mg979/vim-visual-multi-cursor")

	use("~/projects/sw/repos/personal/dotfiles/neovim/neocloud")
end)
