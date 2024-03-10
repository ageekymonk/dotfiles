-- Creates an object for the module. All of the module's
-- functions are associated with this object, which is
-- returned when the module is called with `require`.

-- local aws = require("neocloud.aws")
local aws_iam = require("neocloud.aws.iam")

local M = {}
-- M.get_aws_account_id = aws.get_aws_account_id
-- M.AWSProfile = aws.ui_select_aws_profile
-- M.S3Bucket = aws.ui_select_s3_bucket
M.IAMRoles = aws_iam.ui_select_aws_iam_role
return M
