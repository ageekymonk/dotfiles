alias cloudformation-list-stacks = aws-list-cmd cloudformation list-stacks StackSummaries StackName
alias cloudformation-list-stacksets = aws-list-cmd cloudformation list-stack-sets Summaries StackSetName

def get-stackset-details [] {
    let stackset = (list-stacksets | sk | get StackSetName)
    aws cloudformation describe-stack-set --stack-set-name $stackset | from json
}

def cloudformation-update-stackset [
    --profile: string = ""  # AWS profile to use
    --region: string  = "us-east-1" # AWS Region to use
] {
    let fname = (gum file)
    if $fname != null {
        let stackset = cloudformation-list-stacksets --profile $profile --region $region
        aws cloudformation update-stack-set  --profile $profile --region $region --stack-set-name $stackset.StackSetName --template-body file://($fname) --capabilities CAPABILITY_NAMED_IAM | from json
    }
}

def delete-stack-from-stackset [] {
    let stackset = (list-stacksets | sk | get StackSetName)
    let instances = (get-stackset-instances | sk | split row " " | get 0 | str join " ")
    let region = (gum input --placeholder "Region")
    echo "Verify and run the following command"
    echo $"aws cloudformation delete-stack-instances --stack-set-name ($stackset) --accounts ($instances) --regions ($region) --no-retain-stacks"
}

def delete-stackset [] {
    let stackset = (list-stacksets | sk | get StackSetName)
    aws cloudformation delete-stack-set --stack-set-name $stackset | from json
}

def cloudformation-get-stackset-instances [
    --profile: string = ""  # AWS profile to use
    --region: string  = "us-east-1" # AWS Region to use
] {
    let stackset = cloudformation-list-stacksets --profile $profile --region $region
    aws cloudformation list-stack-instances --profile $profile --region $region --stack-set-name $stackset.StackSetName |
    from json |
    get Summaries | sk --format {get Account} --preview {}
}

def update-stack [] {
    let fname = (gum file)
    if $fname != null {
        let stack = (cloudformation-list-stacks | sk | get StackName)
        aws cloudformation update-stack --stack-name $stack --template-body (open $fname | str join) --capabilities CAPABILITY_NAMED_IAM | from json
    }
}

def create-stack [] {
    let fname = (gum file)
    if $fname != null {
        let stackname = (gum input --placeholder "Stack Name")
        aws cloudformation create-stack --stack-name $stackname --template-body (open $fname | str join) --capabilities CAPABILITY_NAMED_IAM | from json
    }
}

def delete-stack [] {
    let stack = (cloudformation-list-stacks | sk | get StackName)
    aws cloudformation delete-stack --stack-name $stack | from json
}

def get-stack-details [] {
    let stack = (cloudformation-list-stacks | sk | get StackName)
    aws cloudformation describe-stacks --stack-name $stack | from json
}
