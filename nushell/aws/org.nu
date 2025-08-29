# Organizations
#
def list-org-root [
--profile: string = ""  # aws profile to use
] {
    aws organizations list-roots --profile $profile |
    from json |
    get Roots |
    each {|root| [$root.Id, $root.Name]} |
    get 0.0
}

def list-ous [
    --profile: string = ""  # aws profile to use
] {
    aws organizations list-organizational-units-for-parent --profile $profile --parent-id (list-org-root --profile $profile) |
    from json |
    get OrganizationalUnits |
    each {|ou| [$ou.Id, $ou.Name]} |
    sk |
    split row " " |
    get 0
}

def list-accounts [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd = if ($profile | is-empty) {
        aws organizations list-accounts --region $region
    } else {
        aws organizations list-accounts --profile $profile --region $region
    }

    $cmd | from json | get Accounts | each {|account| [
        $account.Id,
        $account.Name,
    ]}
}

def list-scps [
    --profile: string = ""  # aws profile to use
] {
    aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile $profile |
    from json |
    get Policies |
    each {|policy| [$policy.Id, $policy.Name]} |
    sk |
    split row " " |
    get 0
}

def detach-scp [
    --profile: string@profiles = "",  # aws profile to use
    --policyid: string = "", # Optional SCP policy ID
    --policyname: string = "", # Optional SCP policy name
    --ouname: string = "" # Optional OU name
] {
    let scp = if $policyid != "" {
        $policyid
    } else if $policyname != "" {
        aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile $profile |
        from json |
        get Policies |
        where Name == $policyname |
        get 0.Id
    } else {
        list-scps --profile $profile
    }

    let roots = if $ouname != "" {
        aws organizations list-organizational-units-for-parent --profile $profile --parent-id (list-org-root --profile $profile) |
        from json |
        get OrganizationalUnits |
        where Name == $ouname |
        get 0.Id
    } else {
        list-ous --profile $profile
    }

    $roots | each {|root|
        aws organizations detach-policy --profile $profile --policy-id $scp --target-id $root | from json
    }
}
def attach-scp [
    --profile: string@profiles = "",  # aws profile to use
    --policyid: string = "", # Optional SCP policy ID
    --policyname: string = "", # Optional SCP policy name
    --ouname: string = "" # Optional OU name
] {
    let scp = if $policyid != "" {
        $policyid
    } else if $policyname != "" {
        aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile $profile |
        from json |
        get Policies |
        where Name == $policyname |
        get 0.Id
    } else {
        list-scps --profile $profile
    }

    let roots = if $ouname != "" {
        aws organizations list-organizational-units-for-parent --profile $profile --parent-id (list-org-root --profile $profile) |
        from json |
        get OrganizationalUnits |
        where Name == $ouname |
        get 0.Id
    } else {
        list-ous --profile $profile
    }

    $roots | each {|root|
        aws organizations attach-policy --profile $profile --policy-id $scp --target-id $root | from json
    }
}
