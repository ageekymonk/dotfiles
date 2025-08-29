alias kms-list-keys = aws-list-cmd kms list-keys Keys KeyId
# Extended KMS commands
def list-kms-keys [] {
    aws kms list-aliases |
    from json |
    get Aliases |
    each {|alias| [
        $alias.AliasName,
        $alias.TargetKeyId
    ]}
}

def edit-kms-key-policy [] {
    let keyid = (list-kms-keys | sk | get 1)

    let policy = (aws kms get-key-policy --key-id $keyid --policy-name default |
        from json |
        get Policy |
        to json -i 2 |
        ^code - |
        from json |
        to json -r)

    aws kms put-key-policy --key-id $keyid --policy-name default --policy $policy | from json
}
