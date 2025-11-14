$env.EDITOR = "nvim"
# profiles
def profiles [] {
    aws configure list-profiles | lines
}

def regions [] {
    ["us-east-1", "ap-southeast-2", "us-west-2"]
}

# Account
def account-id [
    --profile: string@profiles  # AWS profile to use
] {
    aws sts get-caller-identity --profile $profile | from json | get Account
}

# AWS Generic List Command
def aws-list-cmd [
    servicename: string # AWS service name
    actionname: string # AWS action name
    ResponseKey: string # JSON response key to extract
    PrimaryKey: string # Json Primary key in the array
    --profile: string@profiles = "" # AWS profile to use
    --region: string@regions = "us-east-1" # AWS region to use
    --multiple: string = ""
] {
    let cmd = if ($profile | is-empty) {
        aws $servicename $actionname --region $region
    } else {
        aws $servicename $actionname --profile $profile --region $region
    }

    if ($multiple | is-empty) {
        $cmd | from json | get $ResponseKey | sk --format {get $PrimaryKey} --preview {}
    } else {
        $cmd | from json | get $ResponseKey | sk -m --format {get $PrimaryKey} --preview {}
    }
}
