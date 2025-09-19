alias iam-list-roles = aws-list-cmd iam list-roles Roles RoleName
alias iam-list-users = aws-list-cmd iam list-users Users UserName
alias iam-list-policies = aws-list-cmd iam list-policies Policies PolicyName

# Extended IAM commands
def iam-create-policy [
    policyname?: string  # Policy name
    fname?: string       # Filename with policy JSON
    --profile: string    # AWS profile to use
] {
    let policy_name = if $policyname == null { gum input --placeholder "Policy Name" } else { $policyname }
    let file_name = if $fname == null { gum file } else { $fname }

    if $profile == null {
        aws iam create-policy --policy-name $policy_name --policy-document (open $file_name | str join) | from json
    } else {
        aws iam create-policy --policy-name $policy_name --policy-document (open $file_name | str join) --profile $profile | from json
    }
}

def iam-edit-role-inline-policy [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let rolename = (iam-list-roles --profile $profile | get RoleName)
    print $rolename

    let cmd_list = if ($profile | is-empty) {
        aws iam list-role-policies --role-name $rolename --region $region
    } else {
        aws iam list-role-policies --role-name $rolename --profile $profile --region $region
    }
    let inline_policy = ($cmd_list | from json | get PolicyNames | sk)

    let cmd_get = if ($profile | is-empty) {
        aws iam get-role-policy --role-name $rolename --policy-name $inline_policy --region $region
    } else {
        aws iam get-role-policy --role-name $rolename --policy-name $inline_policy --profile $profile --region $region
    }

    let policy = ($cmd_get |
        from json |
        get PolicyDocument |
        to json -i 2 |
        vipe)

    if ($profile | is-empty) {
        aws iam put-role-policy --role-name $rolename --policy-name $inline_policy --policy-document $policy --region $region | from json
    } else {
        aws iam put-role-policy --role-name $rolename --policy-name $inline_policy --policy-document $policy --profile $profile --region $region | from json
    }
}

def iam-edit-policy [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let policyarn = (iam-list-policies --profile $profile --region $region | get Arn)

    let cmd_get_policy = if ($profile | is-empty) {
        aws iam get-policy --policy-arn $policyarn --region $region
    } else {
        aws iam get-policy --policy-arn $policyarn --profile $profile --region $region
    }
    let version_id = ($cmd_get_policy | from json | get Policy.DefaultVersionId)

    let cmd_get_version = if ($profile | is-empty) {
        aws iam get-policy-version --policy-arn $policyarn --version-id $version_id --region $region
    } else {
        aws iam get-policy-version --policy-arn $policyarn --version-id $version_id --profile $profile --region $region
    }

    let policy = ($cmd_get_version |
        from json |
        get PolicyVersion.Document |
        to json -i 2 |
        vipe)

    let cmd_create = if ($profile | is-empty) {
        aws iam create-policy-version --policy-arn $policyarn --policy-document $policy --set-as-default --region $region
    } else {
        aws iam create-policy-version --policy-arn $policyarn --policy-document $policy --set-as-default --profile $profile --region $region
    }

    $cmd_create | from json
}

def iam-clone-role [] {
    let rolename = (list-iam-roles | sk | get 0)
    let newrolename = (gum input --placeholder "New Role Name")

    # Create new role with same trust policy
    let trust_policy = (get-iam-role-trust-policy | to json -r)
    aws iam create-role --role-name $newrolename --assume-role-policy-document $trust_policy | from json

    # Copy inline policies
    let inline_policies = (aws iam list-role-policies --role-name $rolename | from json | get PolicyNames)
    $inline_policies | each {|policy_name|
        let policy_doc = (aws iam get-role-policy --role-name $rolename --policy-name $policy_name | from json | get PolicyDocument | to json -r)
        aws iam put-role-policy --role-name $newrolename --policy-name $policy_name --policy-document $policy_doc | from json
    }

    # Copy managed policies
    let attached_policies = (aws iam list-attached-role-policies --role-name $rolename | from json | get AttachedPolicies | each {|p| $p.PolicyArn})
    $attached_policies | each {|policy_arn|
        aws iam attach-role-policy --role-name $newrolename --policy-arn $policy_arn | from json
    }
}

def iam-clone-role-cross-account [
    src_account?: string  # Source AWS profile
    dest_account?: string # Destination AWS profile
] {
    let src_profile = if $src_account == null { gum input --placeholder "Input profile" } else { $src_account }
    let dest_profile = if $dest_account == null { gum input --placeholder "Output profile" } else { $dest_account }

    let rolename = (iam-list-roles --profile $src_profile | sk | get 0)
    let newrolename = (gum input --placeholder "New Role Name")

    # Create new role with same trust policy
    let trust_policy = (get-iam-role-trust-policy --profile $src_profile | to json -r)
    aws iam create-role --role-name $newrolename --assume-role-policy-document $trust_policy --profile $dest_profile | from json

    # Copy inline policies
    let inline_policies = (aws iam list-role-policies --role-name $rolename --profile $src_profile | from json | get PolicyNames)
    $inline_policies | each {|policy_name|
        let policy_doc = (aws iam get-role-policy --role-name $rolename --policy-name $policy_name --profile $src_profile | from json | get PolicyDocument | to json -r)
        aws iam put-role-policy --role-name $newrolename --policy-name $policy_name --policy-document $policy_doc --profile $dest_profile | from json
    }

    # Copy managed policies
    let attached_policies = (aws iam list-attached-role-policies --role-name $rolename --profile $src_profile | from json | get AttachedPolicies | each {|p| $p.PolicyArn})
    $attached_policies | each {|policy_arn|
        aws iam attach-role-policy --role-name $newrolename --policy-arn $policy_arn --profile $dest_profile | from json
    }
}

def iam-edit-role-trust-policy [
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let rolename = (iam-list-roles --profile $profile --region $region | get RoleName )

    let cmd_get = if ($profile | is-empty) {
        aws iam get-role --role-name $rolename --region $region
    } else {
        aws iam get-role --role-name $rolename --profile $profile --region $region
    }

    $env.EDITOR = "code -w"
    let policy = ($cmd_get |
        from json |
        get Role.AssumeRolePolicyDocument |
        to json -i 2 |
        vipe)

    if ($profile | is-empty) {
        aws iam update-assume-role-policy --role-name $rolename --policy-document $policy --region $region | from json
    } else {
        aws iam update-assume-role-policy --role-name $rolename --policy-document $policy --profile $profile --region $region | from json
    }
}

def add-policy-to-role [
    --role-name: string = "",  # Role name (optional, will prompt if not provided)
    --policy-arn: string = "",  # Policy ARN (optional, will prompt if not provided)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let role = if $role_name == "" {
        iam-list-roles --profile $profile --region $region | get RoleName
    } else {
        $role_name
    }

    let policy = if $policy_arn == "" {
        # List AWS managed policies and customer managed policies
        let cmd_list = if ($profile | is-empty) {
            aws iam list-policies --max-items 1000 --region $region
        } else {
            aws iam list-policies --max-items 1000 --profile $profile --region $region
        }

        ($cmd_list | from json | get Policies | each {|p| [
            $p.PolicyName,
            $p.Arn,
        ]} | sk | get 1)
    } else {
        $policy_arn
    }

    # Attach the policy to the role
    let cmd = if ($profile | is-empty) {
        aws iam attach-role-policy --role-name $role --policy-arn $policy --region $region
    } else {
        aws iam attach-role-policy --role-name $role --policy-arn $policy --profile $profile --region $region
    }

    $cmd | from json
    print $"Successfully attached policy ($policy) to role ($role)"
}

def add-inline-policy-to-role [
    --role-name: string = "",  # Role name (optional, will prompt if not provided)
    --policy-name: string = "",  # Policy name (optional, will prompt if not provided)
    --policy-document: string = "",  # Policy document as JSON string (optional, will prompt for file if not provided)
    --policy-file: string = "",  # Path to policy file (optional)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let role = if $role_name == "" {
        iam-list-roles --profile $profile --region $region | get RoleName
    } else {
        $role_name
    }

    let policy_name_final = if $policy_name == "" {
        gum input --placeholder "Policy Name"
    } else {
        $policy_name
    }

    let policy_doc = if $policy_document != "" {
        # Validate JSON string before using it
        #
        print $policy_document
        if ($policy_document | from json | to json) != null {
            $policy_document
        } else {
            error make {msg: "Invalid JSON in policy document"}
        }
    } else if $policy_file != "" {
        open $policy_file | to json -r
    } else {
        let file_path = (gum file)
        open $file_path | to json -r
    }

    # Add the inline policy to the role
    let cmd = if ($profile | is-empty) {
        aws iam put-role-policy --role-name $role --policy-name $policy_name_final --policy-document $policy_doc --region $region
    } else {
        aws iam put-role-policy --role-name $role --policy-name $policy_name_final --policy-document $policy_doc --profile $profile --region $region
    }

    $cmd | from json
    print $"Successfully added inline policy ($policy_name_final) to role ($role)"
}

def create-iam-role-with-role-trust [
    role_name?: string,  # Role name
    trusted_role_arn?: string,  # ARN of the role to trust
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let role = if $role_name == null {
        gum input --placeholder "Role Name"
    } else {
        $role_name
    }

    let trusted_arn = if $trusted_role_arn == null {
        gum input --placeholder "Trusted Role ARN"
    } else {
        $trusted_role_arn
    }

    # Create trust policy JSON for role-based trust
    let trust_policy = {
        Version: "2012-10-17",
        Statement: [
            {
                Effect: "Allow",
                Principal: {
                    AWS: $trusted_arn
                },
                Action: "sts:AssumeRole"
            }
        ]
    }

    # Save trust policy to temporary file
    let temp_file = mktemp
    $trust_policy | to json | save -f $temp_file

    # Create the role
    let cmd = if ($profile | is-empty) {
        aws iam create-role --role-name $role --assume-role-policy-document $"file://($temp_file)" --region $region
    } else {
        aws iam create-role --role-name $role --assume-role-policy-document $"file://($temp_file)" --profile $profile --region $region
    }

    # Clean up temporary file
    rm $temp_file

    $cmd | from json
}

def create-iam-role-with-service-trust [
    role_name?: string,  # Role name
    service_name?: string,  # AWS service name (e.g., lambda, ec2, ecs-tasks)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let role = if $role_name == null {
        gum input --placeholder "Role Name"
    } else {
        $role_name
    }

    let service = if $service_name == null {
        gum input --placeholder "AWS Service Name (e.g., lambda, ec2, ecs-tasks)"
    } else {
        $service_name
    }

    # Create trust policy JSON
    let trust_policy = {
        Version: "2012-10-17",
        Statement: [
            {
                Effect: "Allow",
                Principal: {
                    Service: $"($service).amazonaws.com"
                },
                Action: "sts:AssumeRole"
            }
        ]
    }

    # Save trust policy to temporary file
    let temp_file = mktemp
    $trust_policy | to json | save -f $temp_file

    # Create the role
    let cmd = if ($profile | is-empty) {
        aws iam create-role --role-name $role --assume-role-policy-document $"file://($temp_file)" --region $region
    } else {
        aws iam create-role --role-name $role --assume-role-policy-document $"file://($temp_file)" --profile $profile --region $region
    }

    # Clean up temporary file
    rm $temp_file

    $cmd | from json
}

def iam-policy [] {
    let ENV_PAGER = $nu.env.AWS_PAGER
    # $nu.env.AWS_PAGER = ""

    let selected = (aws iam list-policies |
        from json |
        get Policies |
        each {|policy| [
            $policy.PolicyName,
            $policy.Arn,
            $policy.DefaultVersionId
        ]} |
        sk)

    if $selected != null {
        let policy_arn = ($selected | split row " " | get 1)
        let version_id = ($selected | split row " " | get 2)
        aws iam get-policy-version --policy-arn $policy_arn --version-id $version_id | from json
    }

    # $nu.env.AWS_PAGER = $ENV_PAGER
}

def iam-instance-profiles [] {
    aws iam list-instance-profiles |
    from json |
    get InstanceProfiles |
    each {|profile| [
        $profile.InstanceProfileName,
        $profile.Arn
    ]}
}

def delete-instance-profiles [] {
    let profile_name = (iam-instance-profiles | sk | get 0)
    aws iam delete-instance-profile --instance-profile-name $profile_name | from json
}
