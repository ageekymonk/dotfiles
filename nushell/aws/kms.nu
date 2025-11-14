alias kms-list-keys = aws-list-cmd kms list-aliases Aliases AliasName
alias kms-select-keys = aws-list-cmd kms list-aliases Aliases AliasName --multiple "true"
# Extended KMS commands

def kms-edit-key-policy [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let keyid = (kms-list-keys --profile $profile --region $region | get TargetKeyId)

    let policy = (aws kms get-key-policy --key-id $keyid --policy-name default --profile $profile --region $region |
        from json |
        get Policy |
        vipe)
    aws kms put-key-policy --key-id $keyid --policy-name default --policy $policy --profile $profile --region $region | from json
}
