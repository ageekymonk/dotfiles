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

local function show_selected_buckets(prompt_bufnr)
	local selected = action_state.get_selected_entry()
	print(selected[1])
	actions.close(prompt_bufnr)
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
