alias cloudformation-list-stacks = aws-list-cmd cloudformation list-stacks StackSummaries StackName
alias cloudformation-list-stacksets = aws-list-cmd cloudformation list-stack-sets Summaries StackSetName

def cloudformation-get-stackset-details [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1" # AWS Region to use
] {
    let stackset = (cloudformation-list-stacksets --profile $profile --region $region | get StackSetName)
    aws cloudformation describe-stack-set --profile $profile --region $region --stack-set-name $stackset | from json
}

def cloudformation-update-stackset [
    --profile: string@profiles = ""  # aws profile to use
    --region: string@regions = "us-east-1" # aws region to use
] {
    let fname = (gum file)
    if $fname != null {
        let stackset = cloudformation-list-stacksets --profile $profile --region $region
        aws cloudformation update-stack-set  --profile $profile --region $region --stack-set-name $stackset.StackSetName --template-body file://($fname) --capabilities CAPABILITY_NAMED_IAM | from json
    }
}

def cloudformation-delete-stack-from-stackset [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let stackset = (cloudformation-list-stacksets --profile $profile --region $region | sk | get StackSetName)
    let instances = (cloudformation-get-stackset-instances --profile $profile --region $region | sk | split row " " | get 0 | str join " ")
    let target_region = (gum input --placeholder "Region")
    echo "Verify and run the following command"
    echo $"aws cloudformation delete-stack-instances --profile ($profile) --region ($region) --stack-set-name ($stackset) --accounts ($instances) --regions ($target_region) --no-retain-stacks"
}

def cloudformation-delete-stackset [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let stackset = (cloudformation-list-stacksets --profile $profile --region $region | sk | get StackSetName)
    aws cloudformation delete-stack-set --profile $profile --region $region --stack-set-name $stackset | from json
}

def cloudformation-get-stackset-instances [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let stackset = cloudformation-list-stacksets --profile $profile --region $region
    aws cloudformation list-stack-instances --profile $profile --region $region --stack-set-name $stackset.StackSetName |
    from json |
    get Summaries | sk --format {get Account} --preview {}
}

def cloudformation-update-stack [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let fname = (gum file)
    if $fname != null {
        let stack = (cloudformation-list-stacks --profile $profile --region $region | sk | get StackName)
        aws cloudformation update-stack --profile $profile --region $region --stack-name $stack --template-body (open $fname | str join) --capabilities CAPABILITY_NAMED_IAM | from json
    }
}

def cloudformation-create-stack [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let fname = (gum file)
    if $fname != null {
        let stackname = (gum input --placeholder "Stack Name")
        aws cloudformation create-stack --profile $profile --region $region --stack-name $stackname --template-body file://($fname) --capabilities CAPABILITY_NAMED_IAM | from json
    }
}

def cloudformation-delete-stack [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let stack = (cloudformation-list-stacks --profile $profile --region $region | sk | get StackName)
    aws cloudformation delete-stack --profile $profile --region $region --stack-name $stack | from json
}

def cloudformation-get-stack-details [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let stack = (cloudformation-list-stacks --profile $profile --region $region | sk | get StackName)
    aws cloudformation describe-stacks --profile $profile --region $region --stack-name $stack | from json
}
