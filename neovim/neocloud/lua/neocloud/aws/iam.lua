local NuiTree = require("nui.tree")
local Split = require("nui.split")
local NuiLine = require("nui.line")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")

local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.status.ui")
local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local common = require("neogit.buffers.common")
local List = common.List
local col = Ui.col
local row = Ui.row
local text = Ui.text
local async = require("plenary.async")
local Job = require("plenary.job")
local tx, rx = async.control.channel.oneshot()

local M = {}

local IAMPolicyComponent = Component.new(function(policy)
	return List({
		separator = " ",
		items = {
			col({
				row({
					text("Statement: "),
					text(policy.Statement),
				}),
			}),
		},
	})
end)
local IAMRoleComponent = Component.new(function(role)
	local policy = IAMPolicyComponent(role.AssumeRolePolicyDocument)

	return List({
		separator = " ",
		items = {
			col({
				row({
					text("Role: "),
					text(role.RoleName),
				}),
				row({
					text("ARN: "),
					text(role.Arn),
				}),
				row.tag("AssumePolicy")({
					text("Trust: "),
					text(vim.fn.json_encode(role.AssumeRolePolicyDocument.Statement), { hidden = true }),
				}, { hidden = true }),
			}),
		},
	})
end)

local function show_role(prompt_bufnr)
	local role = action_state.get_selected_entry()[1]
	actions.close(prompt_bufnr)
	local output = vim.fn.system("aws iam get-role --role-name " .. role)
	local role_json = vim.fn.json_decode(output).Role

	M.buffer = Buffer.create({
		name = "NeocloudIAMRole",
		filetype = "NoecloudIAMRole",
		kind = "tab",
		render = function()
			return {
				List({
					separator = "",
					items = {
						IAMRoleComponent(role_json),
					},
				}),
			}
		end,
	})
end

function M.ui_select_aws_iam_role()
	local roles = {}
	local output = vim.fn.system("aws iam list-roles")
	local roles_json = vim.fn.json_decode(output).Roles

	for _, role in pairs(roles_json) do
		table.insert(roles, role.RoleName)
	end

	pickers
		.new({
			prompt_title = "AWS IAM Roles",
			finder = finders.new_table({ results = roles }),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", show_role)
				return true
			end,
		})
		:find()
end

return M
