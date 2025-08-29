def list-permission-sets [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_instances = if ($profile | is-empty) {
        aws sso-admin list-instances --region $region
    } else {
        aws sso-admin list-instances --profile $profile --region $region
    }

    let instance_store_arn = ($cmd_list_instances | from json | get Instances.0.InstanceArn)

    let cmd_list_permission_sets = if ($profile | is-empty) {
        aws sso-admin list-permission-sets --instance-arn $instance_store_arn --region $region
    } else {
        aws sso-admin list-permission-sets --instance-arn $instance_store_arn --profile $profile --region $region
    }

    let permission_sets = ($cmd_list_permission_sets | from json | get PermissionSets)

    $permission_sets | par-each {|ps|
        let desc_cmd = if ($profile | is-empty) {
            aws sso-admin describe-permission-set --instance-arn $instance_store_arn --permission-set-arn $ps --region $region
        } else {
            aws sso-admin describe-permission-set --instance-arn $instance_store_arn --permission-set-arn $ps --profile $profile --region $region
        }

        let desc = ($desc_cmd | from json | get PermissionSet)
        [$desc.Name, $ps]
    }
}

def show-permission-sets-inline-policy [] {
    let instance_store_id = (bkt --ttl=1y -- aws sso-admin list-instances --query "Instances[0].IdentityStoreId" | str trim)
    let instance_store_arn = (bkt --ttl=1y -- aws sso-admin list-instances | from json | get Instances.0.InstanceArn)
    let permission_set = (list-permission-sets | sk | split row " " | get 1)

    aws sso-admin get-inline-policy-for-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set |
    from json |
    get InlinePolicy |
    from json |
    to json -i 2 |
    ^code -
}

def edit-permission-sets-inline-policy [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_instances = if ($profile | is-empty) {
        aws sso-admin list-instances --region $region
    } else {
        aws sso-admin list-instances --profile $profile --region $region
    }

    let instance_store_id = (bkt --ttl=1y -- $cmd_list_instances --query "Instances[0].IdentityStoreId" | str trim)
    let instance_store_arn = (bkt --ttl=1y -- $cmd_list_instances | from json | get Instances.0.InstanceArn)
    let permission_set = (list-permission-sets | sk | split row " " | get 1)

    let cmd_get = if ($profile | is-empty) {
        aws sso-admin get-inline-policy-for-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --region $region
    } else {
        aws sso-admin get-inline-policy-for-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --profile $profile --region $region
    }

    $env.EDITOR = "code -w"
    let policy = ($cmd_get |
        from json |
        get InlinePolicy |
        from json |
        to json -i 2 |
        vipe)

    let cmd_put = if ($profile | is-empty) {
        aws sso-admin put-inline-policy-to-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --inline-policy $policy --region $region
    } else {
        aws sso-admin put-inline-policy-to-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --inline-policy $policy --profile $profile --region $region
    }

    let cmd_provision = if ($profile | is-empty) {
        aws sso-admin provision-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --target-type ALL_PROVISIONED_ACCOUNTS --region $region
    } else {
        aws sso-admin provision-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --target-type ALL_PROVISIONED_ACCOUNTS --profile $profile --region $region
    }

    $cmd_put | from json
    $cmd_provision | from json
}

def create-permission-set [
    --name: string = "",  # Permission set name
    --description: string = "",  # Permission set description
    --duration: int = 3600,  # Session duration in seconds (1-12 hours)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_instances = if ($profile | is-empty) {
        aws sso-admin list-instances --region $region
    } else {
        aws sso-admin list-instances --profile $profile --region $region
    }

    let instance_store_arn = ($cmd_list_instances | from json | get Instances.0.InstanceArn)

    let permission_set_name = if $name == "" {
        gum input --placeholder "Permission Set Name"
    } else {
        $name
    }

    let permission_set_description = if $description == "" {
        gum input --placeholder "Permission Set Description"
    } else {
        $description
    }

    # Convert duration to ISO 8601 format (PT<duration>S)
    let session_duration = $"PT($duration)S"

    let cmd_create = if ($profile | is-empty) {
        aws sso-admin create-permission-set --instance-arn $instance_store_arn --name $permission_set_name --description $permission_set_description --session-duration $session_duration --region $region
    } else {
        aws sso-admin create-permission-set --instance-arn $instance_store_arn --name $permission_set_name --description $permission_set_description --session-duration $session_duration --profile $profile --region $region
    }

    $cmd_create | from json
}

def assign-group-permission-set-to-account [
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_instances = if ($profile | is-empty) {
        aws sso-admin list-instances --region $region
    } else {
        aws sso-admin list-instances --profile $profile --region $region
    }

    let instance_store_id = ($cmd_list_instances | from json | get Instances.0.IdentityStoreId)
    let instance_store_arn = ($cmd_list_instances | from json | get Instances.0.InstanceArn)

    # Get group ID
    let group_id = (list-groups --profile $profile --region $region | sk | get 1)
    # Get permission set ARN
    let permission_set = ( list-permission-sets --profile $profile --region $region | sk | get 1)

    # Get target account ID
    let target_account = (list-accounts --profile $profile --region $region | sk | get 0)

    # Create account assignment
    let cmd_assign = if ($profile | is-empty) {
        aws sso-admin create-account-assignment --instance-arn $instance_store_arn --target-id $target_account --target-type AWS_ACCOUNT --permission-set-arn $permission_set --principal-type GROUP --principal-id $group_id --region $region
    } else {
        aws sso-admin create-account-assignment --instance-arn $instance_store_arn --target-id $target_account --target-type AWS_ACCOUNT --permission-set-arn $permission_set --principal-type GROUP --principal-id $group_id --profile $profile --region $region
    }

    $cmd_assign | from json
    print $"Assigned group ($group_id) with permission set to account ($target_account)"
}

def attach-policy-to-permission-set [
    --policy-name: string = "",  # AWS managed policy name
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_instances = if ($profile | is-empty) {
        aws sso-admin list-instances --region $region
    } else {
        aws sso-admin list-instances --profile $profile --region $region
    }

    let instance_store_arn = ($cmd_list_instances | from json | get Instances.0.InstanceArn)

    # Get permission set ARN
    let permission_set = ( list-permission-sets --profile $profile --region $region| sk | split row " " | get 1)
    # Get policy ARN
    let policy_arn_final = if $policy_name != "" {
        $"arn:aws:iam::aws:policy/($policy_name)"
    } else {
        # List AWS managed policies
        let policies_cmd = if ($profile | is-empty) {
            aws iam list-policies --scope AWS --max-items 1000 --region $region
        } else {
            aws iam list-policies --scope AWS --max-items 1000 --profile $profile --region $region
        }

        ($policies_cmd | from json | get Policies | each {|policy| [
            $policy.PolicyName,
            $policy.Arn
        ]} | sk | get 1)
    }

    # Attach the policy to the permission set
    let cmd_attach = if ($profile | is-empty) {
        aws sso-admin attach-managed-policy-to-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --managed-policy-arn $policy_arn_final --region $region
    } else {
        aws sso-admin attach-managed-policy-to-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --managed-policy-arn $policy_arn_final --profile $profile --region $region
    }

    # Provision the permission set to apply changes
    let cmd_provision = if ($profile | is-empty) {
        aws sso-admin provision-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --target-type ALL_PROVISIONED_ACCOUNTS --region $region
    } else {
        aws sso-admin provision-permission-set --instance-arn $instance_store_arn --permission-set-arn $permission_set --target-type ALL_PROVISIONED_ACCOUNTS --profile $profile --region $region
    }

    $cmd_attach | from json
    $cmd_provision | from json
    print $"Attached policy ($policy_arn_final) to permission set"
}

def list-groups [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_instances = if ($profile | is-empty) {
        aws sso-admin list-instances --region $region
    } else {
        aws sso-admin list-instances --profile $profile --region $region
    }

    let instance_store_id = ($cmd_list_instances | from json | get Instances.0.IdentityStoreId)
    let instance_store_arn = ($cmd_list_instances | from json | get Instances.0.InstanceArn)

    let cmd_list_groups = if ($profile | is-empty) {
        aws identitystore list-groups --identity-store-id $instance_store_id --region $region
    } else {
        aws identitystore list-groups --identity-store-id $instance_store_id --profile $profile --region $region
    }

    let groups = ($cmd_list_groups | from json | get Groups)

    $groups | each {|group| [$group.DisplayName, $group.GroupId]}
}
