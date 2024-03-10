local NuiTree = require("nui.tree")
local Split = require("nui.split")
local NuiLine = require("nui.line")

local M = {}

function M.set_profile(profile)
	vim.g.aws_profile = profile
	vim.cmd('let $AWS_PROFILE = "' .. profile .. '"')
end

function M.get_aws_credentials()
	local aws_credentials = vim.fn.system("aws sts get-caller-identity")
	return vim.fn.json_decode(aws_credentials)
end

function M.get_aws_account_id()
	local aws_credentials = M.get_aws_credentials()
	return aws_credentials.Account
end

function M.get_aws_region()
	local aws_credentials = M.get_aws_credentials()
	return aws_credentials.Arn:match("arn:aws:iam::%d+:user/(.*)"):match("(.*)%:")
end

function M.get_aws_user()
	local aws_credentials = M.get_aws_credentials()
	return aws_credentials.Arn:match("arn:aws:iam::%d+:user/(.*)")
end

require("telescope")
pickers = require("telescope.pickers")
finders = require("telescope.finders")
actions = require("telescope.actions")
action_state = require("telescope.actions.state")
sorters = require("telescope.sorters")
previewers = require("telescope.previewers")

local function set_selected_profile(prompt_bufnr)
	local selected = action_state.get_selected_entry()
	M.set_profile(selected[1])
	actions.close(prompt_bufnr)
end

function M.ui_select_aws_profile()
	local profiles = {}
	local output = vim.fn.system("aws configure list-profiles")
	for line in output:gmatch("[^\r\n]+") do
		table.insert(profiles, line)
	end
	pickers
		.new({
			finder = finders.new_table({ results = profiles }),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", set_selected_profile)
				return true
			end,
		})
		:find()
end

local function get_s3_files(bucket)
	local files = {}
	local output = vim.fn.system("aws s3api list-objects --bucket " .. bucketname)
	local bucketfiles = vim.fn.json_decode(output)

	for line in bucketfiles.Contents do
		table.insert(files, line:match("%d%d%d%d-%d%d-%d%d %d%d:%d%d:%d%d (.*)"))
	end
	return files
end

local function set_s3_browser(bucketname)
	local split = Split({
		relative = "win",
		position = "left",
		size = 30,
	})

	split:mount()

	-- quit
	split:map("n", "q", function()
		split:unmount()
	end, { noremap = true })

	local tree = NuiTree({
		winid = split.winid,
		nodes = {
			NuiTree.Node({ text = "a" }),
			NuiTree.Node({ text = "b" }, {
				NuiTree.Node({ text = "b-1" }),
				NuiTree.Node({ text = "b-2" }, {
					NuiTree.Node({ text = "b-1-a" }),
					NuiTree.Node({ text = "b-2-b" }),
				}),
			}),
			NuiTree.Node({ text = "c" }, {
				NuiTree.Node({ text = "c-1" }),
				NuiTree.Node({ text = "c-2" }),
			}),
		},
		prepare_node = function(node)
			local line = NuiLine()

			line:append(string.rep("  ", node:get_depth() - 1))

			if node:has_children() then
				line:append(node:is_expanded() and " " or " ", "SpecialChar")
			else
				line:append("  ")
			end

			line:append(node.text)

			return line
		end,
	})

	local map_options = { noremap = true, nowait = true }

	-- print current node
	split:map("n", "<CR>", function()
		local node = tree:get_node()
		print(vim.inspect(node))
	end, map_options)

	-- collapse current node
	split:map("n", "h", function()
		local node = tree:get_node()

		if node:collapse() then
			tree:render()
		end
	end, map_options)

	-- collapse all nodes
	split:map("n", "H", function()
		local updated = false

		for _, node in pairs(tree.nodes.by_id) do
			updated = node:collapse() or updated
		end

		if updated then
			tree:render()
		end
	end, map_options)

	-- expand current node
	split:map("n", "l", function()
		local node = tree:get_node()

		if node:expand() then
			tree:render()
		end
	end, map_options)

	-- expand all nodes
	split:map("n", "L", function()
		local updated = false

		for _, node in pairs(tree.nodes.by_id) do
			updated = node:expand() or updated
		end

		if updated then
			tree:render()
		end
	end, map_options)

	-- add new node under current node
	split:map("n", "a", function()
		local node = tree:get_node()
		tree:add_node(
			NuiTree.Node({ text = "d" }, {
				NuiTree.Node({ text = "d-1" }),
			}),
			node:get_id()
		)
		tree:render()
	end, map_options)

	-- delete current node
	split:map("n", "d", function()
		local node = tree:get_node()
		tree:remove_node(node:get_id())
		tree:render()
	end, map_options)

	tree:render()
end

local function show_selected_buckets(prompt_bufnr)
	local selected = action_state.get_selected_entry()
	actions.close(prompt_bufnr)
	print(selected[1])
	set_s3_browser()
end

function M.ui_select_s3_bucket()
	local buckets = {}
	local output = vim.fn.system("aws s3api list-buckets")
	local buckets_json = vim.fn.json_decode(output)
	for _, bucket in pairs(buckets_json.Buckets) do
		table.insert(buckets, bucket.Name)
	end
	pickers
		.new({
			finder = finders.new_table({ results = buckets }),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", show_selected_buckets)
				return true
			end,
		})
		:find()
end
return M
