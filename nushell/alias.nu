# alias
alias j = z
alias ji = zi
alias pkill = pik
alias ps = pik

alias gst = git status


# profiles
def profiles [] {
    aws configure list-profiles | lines
}

def regions [] {
    ["us-east-1", "ap-southeast-2", "us-west-2"]
}

def s3-notification-targets [] {
    ["sqs", "sns", "lambda"]
}

# Account
def account-id [
    --profile: string@profiles  # AWS profile to use
] {
    aws sts get-caller-identity --profile $profile | from json | get Account
}

# ACM
def acm-list-expired-certificates [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let cmd = if ($profile | is-empty) {
        aws acm list-certificates --region $region
    } else {
        aws acm list-certificates --profile $profile --region $region
    }

    $cmd | from json | get CertificateSummaryList | where Status == "EXPIRED" | sk --format {get DomainName} --preview {}
}

# AWS Generic List Command
def aws-list-cmd [
    servicename: string # AWS service name
    actionname: string # AWS action name
    ResponseKey: string # JSON response key to extract
    PrimaryKey: string # Json Primary key in the array
    --profile: string@profiles = "" # AWS profile to use
    --region: string@regions = "us-east-1" # AWS region to use
] {
    let cmd = if ($profile | is-empty) {
        aws $servicename $actionname --region $region
    } else {
        aws $servicename $actionname --profile $profile --region $region
    }

    $cmd | from json | get $ResponseKey | sk --format {get $PrimaryKey} --preview {}
}

alias acm-list-certificates = aws-list-cmd acm list-certificates CertificateSummaryList DomainName
def acm-import-cert [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1" # AWS Region to use
] {
    let certfile = (gum file)
    let certfilepem = ($certfile) | str replace ".crt" ".pem"
    let key = (gum file)
    # Extract lines between first Begin and End
    ^sed '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/!d;/-----END CERTIFICATE-----/q' $certfile | save -f ($certfilepem)

    let cmd = if ($profile | is-empty) {
        aws acm import-certificate --certificate fileb://($certfilepem) --private-key fileb://($key) --region $region
    } else {
        aws acm import-certificate --certificate fileb://($certfilepem) --private-key fileb://($key) --profile $profile --region $region
    }

    $cmd | from json
}
alias s3-list-buckets = aws-list-cmd s3api list-buckets Buckets Name
# Extended S3 commands
def show-bucket-versioning [] {
    let bucket = (s3-list-buckets | sk | get 0)
    aws s3api get-bucket-versioning --bucket $bucket | from json
}

def enable-bucket-versioning [] {
    let bucket = (s3-list-buckets | sk | get 0)
    aws s3api put-bucket-versioning --bucket $bucket --versioning-configuration Status=Enabled | from json
}

def bucket-policy [] {
    let bucket = (s3-list-buckets | sk | get 0)
    aws s3api get-bucket-policy --bucket $bucket | from json | get Policy | from json
}

def edit-bucket-policy [
    bucketname?: string,  # Optional bucket name (selected from list if not provided)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let bucket = if $bucketname == null {
        s3-list-buckets --profile $profile --region $region | get Name
    } else {
        $bucketname
    }

    let cmd_get = if ($profile | is-empty) {
        aws s3api get-bucket-policy --bucket $bucket --region $region
    } else {
        aws s3api get-bucket-policy --bucket $bucket --profile $profile --region $region
    }

    $env.EDITOR = "code -w"
    let policy = (
        $cmd_get |
        from json |
        get Policy |
        from json |
        to json -i 2 |
        vipe
    )

    let cmd_put = if ($profile | is-empty) {
        aws s3api put-bucket-policy --bucket $bucket --policy $policy --region $region | from json
    } else {
        aws s3api put-bucket-policy --bucket $bucket --policy $policy --profile $profile --region $region | from json
    }

    $cmd_put
}

def bucket-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let buckets = (s3-list-buckets | sk)

    $buckets | each {|bucket|
        let bucket_name = $bucket.Name
        let temp_file = (mktemp)

        # Check if bucket has tags already
        let tags = do {
            try {
                aws s3api get-bucket-tagging --bucket $bucket_name | from json | get TagSet
            } catch {
                []
            }
        }

        # Filter out existing tag with same key
        let filtered_tags = ($tags | where Key != $name)

        # Add new tag
        let new_tags = ($filtered_tags | append {Key: $name, Value: $value})

        # Save tags to temp file
        {TagSet: $new_tags} | to json | save -f $temp_file

        # Apply tags
        aws s3api put-bucket-tagging --bucket $bucket_name --tagging $"file://($temp_file)" | from json

        # Delete temp file
        rm $temp_file
    }
}

def s3-create-notification [
--name: string = "",    # Name of the notification configuration
--bucket: string = "",   # S3 bucket name (if empty, will prompt selection)
--events: string = "s3:ObjectCreated:*",   # Event types to monitor (comma-separated)
--prefix: string = "",   # Optional prefix filter
--suffix: string = "",   # Optional suffix filter
--target-type: string@s3-notification-targets = "sns",   # Notification target type
--target-arn: string = "",   # ARN of the target (if empty, will prompt selection)
--profile: string@profiles = "",   # AWS profile to use
--region: string@regions = "us-east-1"   # AWS region to use
] {
    # Select bucket if not provided
    let bucket_name = if $bucket == "" {
        s3-list-buckets --profile $profile --region $region | get Name
    } else {
        $bucket
    }

    # Get target ARN if not provided
    let target = if $target_arn == "" {
        if $target_type == "sns" {
            sns-list-topics --profile $profile --region $region | get TopicArn
        } else if $target_type == "sqs" {
            sqs-list-queues --profile $profile --region $region | get 0
        } else if $target_type == "lambda" {
            lambda-list-functions --profile $profile --region $region | get FunctionName
        } else {
            error make {msg: "Invalid target type"}
        }
    } else {
        $target_arn
    }

    # Build configuration JSON
    mut config = {
        Events: ($events | split row "," | each {|e| $e | str trim}),
        Id: $name
    }

    # Add filters if provided
    if $prefix != "" or $suffix != "" {
        $config.Filter = {
            Key: {
                FilterRules: []
            }
        }

        if $prefix != "" {
            $config.Filter.Key.FilterRules = ($config.Filter.Key.FilterRules | append {
                Name: "prefix"
                Value: $prefix
            })
        }

        if $suffix != "" {
            $config.Filter.Key.FilterRules = ($config.Filter.Key.FilterRules | append {
                Name: "suffix"
                Value: $suffix
            })
        }
    }

    # Add target configuration
    let cmd = if ($profile | is-empty) {
        aws s3api get-bucket-notification-configuration --bucket $bucket_name --region $region
    } else {
        aws s3api get-bucket-notification-configuration --bucket $bucket_name --profile $profile --region $region
    }
    mut configrecord = $cmd | from json
    if $target_type == "sns" {
        $config.TopicArn = $target
        let topicconfig = $configrecord | get -i TopicConfigurations
        $configrecord = if $topicconfig == null {
            $configrecord | insert TopicConfigurations  [$config]
        } else {
            $configrecord.TopicConfigurations = ($configrecord.TopicConfigurations | append $config)
        }
    } else if $target_type == "sqs" {
        $config.QueueArn = $target
        let topicconfig = $configrecord | get -i QueueConfigurations
        $configrecord = if $topicconfig == null {
            print "Adding Queue"
            $configrecord | insert QueueConfigurations  $config
        } else {
            $configrecord.QueueConfigurations = ($configrecord.QueueConfigurations | append $config)
        }
    } else if $target_type == "lambda" {
        $config.LambdaFunctionArn = $target
        let topicconfig = $configrecord | get -i LambdaFunctionConfigurations
        $configrecord = if $topicconfig == null {
            $configrecord | insert LambdaFunctionConfigurations  [$config]
        } else {
            $configrecord.LambdaFunctionConfigurations = ($configrecord.LambdaFunctionConfigurations | append $config)
        }
    }

    # Create notification configuration
    let temp_file = mktemp
    $configrecord | to json | save -f $temp_file

    cat $temp_file
    # Apply the notification configuration
    # let cmd = if ($profile | is-empty) {
    #     aws s3api put-bucket-notification-configuration --bucket $bucket_name --notification-configuration $"file://($temp_file)" --region $region --skip-destination-validation
    # } else {
    #     aws s3api put-bucket-notification-configuration --bucket $bucket_name --notification-configuration $"file://($temp_file)" --profile $profile --region $region --skip-destination-validation
    # }

    # Delete the temporary file
    rm $temp_file

    # Return the result
    # $cmd | from json
}

alias appsync-list-graphql-apis = aws-list-cmd appsync list-graphql-apis graphqlApis name
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

# AWS Config
def aws-noncompliant-resources [] {
    let rtype = (aws configservice describe-compliance-by-resource --compliance-types NON_COMPLIANT | from json | get ComplianceByResources | each {|r| $r.ResourceType} | uniq | sk)
    if $rtype != null {
        aws configservice describe-compliance-by-resource --compliance-types NON_COMPLIANT --resource-type $rtype | from json
    }
}
alias cloudwatch-list-dashboards = aws-list-cmd cloudwatch list-dashboards DashboardEntries DashboardName
# DataSync
def datasync-tasks-running [] {
    aws datasync list-tasks | from json |
    get Tasks |
    where Status == "RUNNING" |
    each {|task| [$task.Name, $task.TaskArn, $task.Status, $task.Options.SourceLocationArn, $task.Options.DestinationLocationArn]}
}

def datasync-task-executions-failed [] {
    aws datasync list-task-executions |
    from json |
    get TaskExecutions |
    where Status == "ERROR"
}
alias cloudwatch-list-metrics = aws-list-cmd cloudwatch list-metrics Metrics MetricName
# CloudFront
def cloudfronts [] {
    aws cloudfront list-distributions |
    from json |
    get DistributionList.Items |
    each {|dist| [
        ($dist.Aliases.Items | if $in == null { "No Alias" } else { $in | get 0 }),
        $dist.Status,
        $dist.ARN
    ]}
}

def cloudfront-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let dist_arn = (cloudfronts | sk | get 2)
    aws cloudfront tag-resource --resource $dist_arn --tags $"Items=[{Key=($name),Value=($value)}]" | from json
}
alias dynamodb-list-tables = aws-list-cmd dynamodb list-tables TableNames .
alias ec2-describe-instances = aws-list-cmd ec2 describe-instances Reservations InstanceId
alias ec2-describe-vpcs = aws-list-cmd ec2 describe-vpcs Vpcs VpcId
alias ec2-describe-subnets = aws-list-cmd ec2 describe-subnets Subnets SubnetId
# Extended EC2 commands
def list-ec2-instances [] {
    gum spin --title "Fetching EC2 Instances" -- aws ec2 describe-instances |
    from json |
    get Reservations |
    flatten |
    get Instances |
    each {|instance| [
        $instance.InstanceId,
        ($instance.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value }),
        $instance.State.Name,
        $instance.InstanceType,
        $instance.PublicIpAddress,
        $instance.PrivateIpAddress
    ]}
}

def list-ec2-snapshots [] {
    aws ec2 describe-snapshots --owner self |
    from json |
    get Snapshots |
    each {|snap| [
        $snap.SnapshotId,
        ($snap.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value }),
        $snap.State,
        $snap.Encrypted,
        $snap.StartTime,
        $snap.Description
    ]}
}

def instance-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let instance = (list-ec2-instances | sk | get 0)
    aws ec2 create-tags --resources $instance --tags $"Key=($name),Value=($value)" | from json
}

def volumes [] {
    aws ec2 describe-volumes |
    from json |
    get Volumes |
    each {|vol| [
        $vol.VolumeId,
        ($vol.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value }),
        $vol.VolumeType,
        $vol.State,
        $vol.Encrypted
    ]}
}

def albs [] {
    aws elbv2 describe-load-balancers |
    from json |
    get LoadBalancers |
    each {|lb| [
        $lb.LoadBalancerName,
        $lb.DNSName,
        $lb.Scheme,
        $lb.Type,
        $lb.LoadBalancerArn
    ]}
}

def alb-update-certificate [] {
    let certarn = (acm-list-certificates | sk | split row " " | get 0)
    let alb = (albs | sk | get 4)
    let listener_arn = (aws elbv2 describe-listeners --load-balancer-arn $alb | from json | get Listeners.0.ListenerArn)
    aws elbv2 add-listener-certificates --listener-arn $listener_arn --certificates $"CertificateArn=($certarn)" | from json
}

def volume-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let volume = (volumes | sk | get 0)
    aws ec2 create-tags --resources $volume --tags $"Key=($name),Value=($value)" | from json
}

def elbv2-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let lb_arn = (albs | sk | get 4)
    aws elbv2 add-tags --resource-arns $lb_arn --tags $"Key=($name),Value=($value)" | from json
}

def delete-snapshots [] {
    let snapshot = (list-ec2-snapshots | sk | get 0)
    aws ec2 delete-snapshot --snapshot-id $snapshot | from json
}

def efs [] {
    aws efs describe-file-systems |
    from json |
    get FileSystems |
    each {|fs| [
        $fs.FileSystemId,
        $fs.Name,
        $fs.PerformanceMode,
        $fs.Encrypted
    ]}
}

def efs-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let fsid = (efs | sk | get 0)
    aws efs tag-resource --resource-id $fsid --tags $"Key=($name),Value=($value)" | from json
}

def efs-add-lifecycle [] {
    let fsid = (efs | sk | get 0)
    aws efs put-lifecycle-configuration --file-system-id $fsid --lifecycle-policies "TransitionToIA=AFTER_7_DAYS" | from json
}

def efs-recovery-points [] {
    let accountid = (account-id)
    let region = (aws configure get region | str trim)
    let efsid = (efs | sk | get 0)

    aws backup list-recovery-points-by-resource --resource-arn $"arn:aws:elasticfilesystem:($region):($accountid):file-system/($efsid)" |
    from json |
    get RecoveryPoints |
    each {|point| [
        $point.RecoveryPointArn,
        ($point.CreationDate | into datetime | format date "%Y-%m-%d %H:%M:%S"),
        $point.BackupSizeBytes,
        $point.Status,
        $point.BackupVaultName
    ]}
}
alias ecr-describe-repositories = aws-list-cmd ecr describe-repositories repositories repositoryName
alias ecs-list-clusters = aws-list-cmd ecs list-clusters clusterArns .
alias efs-describe-file-systems = aws-list-cmd efs describe-file-systems FileSystems FileSystemId
alias eks-list-clusters = aws-list-cmd eks list-clusters clusters .
alias elasticbeanstalk-describe-applications = aws-list-cmd elasticbeanstalk describe-applications Applications ApplicationName
# Elastic Beanstalk
def ebs-environments [] {
    aws elasticbeanstalk describe-environments |
    from json |
    get Environments |
    each {|env| [$env.EnvironmentName, $env.Status, $env.Health, $env.SolutionStackName, $env.DateCreated, $env.DateUpdated]}
}

def update-ebs-certs [] {
    let cert = (acm-list-certificates | sk | split row " " | get 0)
    let envname = (ebs-environments | sk | split row " " | get 0)
    aws elasticbeanstalk update-environment --environment-name $envname --option-settings "Namespace=aws:elb:listener:443,OptionName=SSLCertificateId,Value=$cert" | from json
}
alias elasticache-describe-cache-clusters = aws-list-cmd elasticache describe-cache-clusters CacheClusters CacheClusterId
alias elb-describe-load-balancers = aws-list-cmd elb describe-load-balancers LoadBalancerDescriptions LoadBalancerName
alias elbv2-describe-load-balancers = aws-list-cmd elbv2 describe-load-balancers LoadBalancers LoadBalancerName
alias iam-list-roles = aws-list-cmd iam list-roles Roles RoleName
alias iam-list-users = aws-list-cmd iam list-users Users UserName
# Extended IAM commands
def create-iam-policy [
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

def attach-iam-policy [
    rolename?: string    # Role name
    policyname?: string  # Policy name
    --profile: string    # AWS profile to use
] {
    let role_name = if $rolename == null { iam-list-roles --profile $profile | sk | split row " " | get 0 } else { $rolename }
    let policy_name = if $policyname == null { list-iam-policy | sk | split row " " | get 0 } else { $policyname }

    let policy_arn = if $profile == null {
        aws iam list-policies --query $"Policies[?PolicyName=='($policy_name)'].Arn" --output text | str trim
    } else {
        aws iam list-policies --profile $profile --query $"Policies[?PolicyName=='($policy_name)'].Arn" --output text | str trim
    }

    if $profile == null {
        aws iam attach-role-policy --role-name $role_name --policy-arn $policy_arn | from json
    } else {
        aws iam attach-role-policy --role-name $role_name --policy-arn $policy_arn --profile $profile | from json
    }
}

def list-iam-policy [] {
    gum spin --title "Fetching IAM Policies" -- aws iam list-policies |
    from json |
    get Policies |
    each {|policy| [
        $policy.PolicyName,
        $policy.Arn
    ]} |
    sort-by PolicyName
}

def edit-iam-role-inline-policy [
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

    $env.EDITOR = "code -w"
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

def edit-iam-policy [] {
    let policyarn = (list-iam-policy | sk | get 1)
    let version_id = (aws iam get-policy --policy-arn $policyarn | from json | get Policy.DefaultVersionId)

    let policy = (aws iam get-policy-version --policy-arn $policyarn --version-id $version_id |
        from json |
        get PolicyVersion.Document |
        to json -i 2 |
        ^code - |
        from json |
        to json -r)

    aws iam create-policy-version --policy-arn $policyarn --policy-document $policy --set-as-default | from json
}

def clone-iam-role [] {
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

def clone-iam-role-cross-account [
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

def edit-iam-role-trust-policy [
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
alias lambda-list-functions = aws-list-cmd lambda list-functions Functions FunctionName
# Organizations
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

def list-permission-sets [] {
    let instance_store_id = (bkt --ttl=1y -- aws sso-admin list-instances --query "Instances[0].IdentityStoreId" | str trim)
    let instance_store_arn = (bkt --ttl=1y -- aws sso-admin list-instances | from json | get Instances.0.InstanceArn)
    let permission_sets = (bkt --ttl=5m -- aws sso-admin list-permission-sets --instance-arn $instance_store_arn | from json | get PermissionSets)

    $permission_sets | each {|ps|
        bkt --ttl=1d -- aws sso-admin describe-permission-set --instance-arn $instance_store_arn --permission-set-arn $ps |
        from json |
        get PermissionSet |
        select Name PermissionSetArn
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

def list-groups [] {
    let instance_store_id = (bkt --ttl=1y -- aws sso-admin list-instances | from json | get Instances.0.IdentityStoreId)
    let instance_store_arn = (bkt --ttl=1y -- aws sso-admin list-instances | from json | get Instances.0.InstanceArn)
    let groups = (bkt --ttl=1w -- aws identitystore list-groups --identity-store-id $instance_store_id | from json | get Groups)

    $groups | each {|group| [$group.DisplayName, $group.GroupId]}
}
alias rds-describe-db-instances = aws-list-cmd rds describe-db-instances DBInstances DBInstanceIdentifier
# Extended RDS commands
def rds-instance-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let db_arn = (aws-list-cmd rds describe-db-instances DBInstances DBInstanceArn | sk | get 5)
    aws rds add-tags-to-resource --resource-name $db_arn --tags $"Key=($name),Value=($value)" | from json
}

def rds-cluster-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let cluster_arn = (aws rds describe-db-clusters | from json | get DBClusters | each {|c| [$c.DBClusterIdentifier, $c.DBClusterArn]} | sk | get 1)
    aws rds add-tags-to-resource --resource-name $cluster_arn --tags $"Key=($name),Value=($value)" | from json
}
alias route53-list-hosted-zones = aws-list-cmd route53 list-hosted-zones HostedZones Name
# Extended Route53 commands
def disable-health-check [] {
    let health_check_id = (
        aws route53 list-health-checks |
        from json |
        get HealthChecks |
        each {|check| [
            $check.Id,
            $check.HealthCheckConfig.FullyQualifiedDomainName
        ]} |
        sk |
        get 0
    )

    aws route53 update-health-check --health-check-id $health_check_id --disabled true | from json
}
alias sns-list-topics = aws-list-cmd sns list-topics Topics TopicArn
# Extended SNS commands
def list-subscriptions-for-topics [] {
    let topic_arn = (aws-list-cmd sns list-topics Topics TopicArn | sk | get 0)
    aws sns list-subscriptions-by-topic --topic-arn $topic_arn | from json
}

def list-subscriptions [] {
    gum spin --title "Fetching Subscriptions" -- aws sns list-subscriptions |
    from json |
    get Subscriptions |
    each {|sub| [
        $sub.SubscriptionArn,
        $sub.Protocol,
        $sub.Endpoint
    ]}
}

def add-email-subscription [] {
    let email = (gum input --placeholder "Email")
    let topic_arn = (aws-list-cmd sns list-topics Topics TopicArn | sk | get 0)
    aws sns subscribe --topic-arn $topic_arn --protocol email --notification-endpoint $email | from json
}

def confirm-subscription [] {
    let confirmlink = (gum input --char-limit 4000 --placeholder "Confirmation Link")
    let token = ($confirmlink | python3 -c "import sys; from urllib.parse import unquote; print(unquote(sys.stdin.read()).split('&')[1].split('=')[-1]);")

    let topic_arn = (aws-list-cmd sns list-topics Topics TopicArn | sk | get 0)
    aws sns confirm-subscription --topic-arn $topic_arn --token $token | from json
}

def delete-subscriptions [] {
    let subscription_arn = (list-subscriptions | sk | get 0)
    aws sns unsubscribe --subscription-arn $subscription_arn | from json
}

# SageMaker
alias sagemaker-list-notebooks = aws-list-cmd sagemaker list-notebook-instances NotebookInstances NotebookInstanceName

alias sagemaker-list-notebooks = aws-list-cmd sagemaker list-notebook-instances NotebookInstances NotebookInstanceName

def sagemaker-clone-notebook [
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1",  # AWS region to use
    --name: string = "",  # New notebook name (optional)
    --type: string = ""  # Instance type (optional)
    --platform-identifier: string = "" # Platform Identifier (optional)
] {
    let source_notebook = (sagemaker-list-notebooks --profile $profile --region $region | get NotebookInstanceName)

    # Get source notebook details
    let cmd_desc = if ($profile | is-empty) {
        aws sagemaker describe-notebook-instance --notebook-instance-name $source_notebook --region $region
    } else {
        aws sagemaker describe-notebook-instance --notebook-instance-name $source_notebook --profile $profile --region $region
    }

    let details = ($cmd_desc | from json)

    # Prepare new notebook name
    let new_name = if $name == "" {
        $source_notebook + "-clone"
    } else {
        $name
    }

    # Prepare instance type
    let instance_type = if $type == "" {
        $details.InstanceType
    } else {
        $type
    }

    let platform_identifier = if $type == "" {
        $details.PlatformIdentifier
    } else {
        $platform_identifier
    }
    print $details
    # Create clone notebook
    let cmd_create = if ($profile | is-empty) {
        (aws sagemaker create-notebook-instance
            --notebook-instance-name $new_name
            --instance-type $instance_type
            --role-arn $details.RoleArn
            --subnet-id ($details.SubnetId | default "")
            --security-group-ids ($details.SecurityGroups | default [])
            --volume-size-in-gb $details.VolumeSizeInGB
            --root-access $details.RootAccess
            --kms-key-id $details.KmsKeyId
            --direct-internet-access $details.DirectInternetAccess
            --platform-identifier $platform_identifier
            --region $region)
    } else {
        (aws sagemaker create-notebook-instance
            --notebook-instance-name $new_name
            --instance-type $instance_type
            --role-arn $details.RoleArn
            --subnet-id ($details.SubnetId | default "")
            --security-group-ids ...($details.SecurityGroups | default [])
            --volume-size-in-gb $details.VolumeSizeInGB
            --root-access $details.RootAccess
            --kms-key-id $details.KmsKeyId
            --direct-internet-access $details.DirectInternetAccess
            --platform-identifier $platform_identifier
            --profile $profile
            --region $region)
    }

    $cmd_create | from json | echo $"Cloned notebook ($source_notebook) to ($new_name)"
}

def sagemaker-notebook-stop [] {
    let notebook_name = (sagemaker-notebooks | sk | get 0)
    aws sagemaker stop-notebook-instance --notebook-instance-name $notebook_name | from json
}

def sagemaker-notebook-start [] {
    let notebook_name = (sagemaker-notebooks | sk | get 0)
    aws sagemaker start-notebook-instance --notebook-instance-name $notebook_name | from json
}

# def sagemaker-notebook-resize [] {
#     let instance_size = (
#         aws --region us-east-1 pricing get-products --service-code AmazonSageMaker --filters "Type=TERM_MATCH,Field=regionCode,Value=us-east-1" |
#         from json |
#         get PriceList |
#         each {|item| try { from json $item } catch { {} }} |
#         where product.productFamily == "ML Instance" |
#         get product.attributes.instanceName |
#         uniq |
#         sort |
#         sk
#     )

#     let notebook_name = (sagemaker-notebooks | sk | get 0)
#     aws sagemaker update-notebook-instance --notebook-instance-name $notebook_name --instance-type $instance_size | from json
# }
alias sqs-list-queues = aws-list-cmd sqs list-queues QueueUrls .
# VPC
def subnet-add-tag [
    name: string,  # Tag name
    value: string  # Tag value
] {
    let subnet_id = (aws-list-cmd ec2 describe-subnets Subnets SubnetId | sk | get 0)
    aws ec2 create-tags --resources $subnet_id --tags $"Key=($name),Value=($value)" | from json
}

# Transit Gateway commands
def tgw-show-route-tables [] {
    aws ec2 describe-transit-gateway-route-tables |
    from json |
    get TransitGatewayRouteTables |
    each {|table| [
        $table.TransitGatewayRouteTableId,
        $table.TransitGatewayId,
        $table.State,
        ($table.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value })
    ]}
}

def tgw-show-static-routes [] {
    let tgw_route = (tgw-show-route-tables | sk | get 0)

    aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id $tgw_route --filters "Name=type,Values=static" |
    from json |
    get Routes |
    where TransitGatewayAttachments != null |
    each {|route| [
        $route.DestinationCidrBlock,
        $route.TransitGatewayAttachments.0.TransitGatewayAttachmentId
    ]}
}

def tgw-show-attachments [] {
    aws ec2 describe-transit-gateway-attachments |
    from json |
    get TransitGatewayAttachments |
    each {|attach| [
        $attach.TransitGatewayAttachmentId,
        $attach.ResourceType,
        $attach.ResourceOwnerId,
        $attach.ResourceRegion,
        $attach.State,
        ($attach.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value })
    ]}
}

def tgw-add-static-route [] {
    let tgw_route = (tgw-show-route-tables | sk | get 0)
    let tgw_attach = (tgw-show-attachments | sk | get 0)
    let cidr = (gum input --placeholder "CIDR")

    echo $"aws ec2 create-transit-gateway-route --transit-gateway-route-table-id ($tgw_route) --destination-cidr-block ($cidr) --transit-gateway-attachment-id ($tgw_attach)"
    aws ec2 create-transit-gateway-route --transit-gateway-route-table-id $tgw_route --destination-cidr-block $cidr --transit-gateway-attachment-id $tgw_attach | from json
}

# def cloudfront-add-ip [] {
#     let prefix_list = (
#         aws ec2 describe-managed-prefix-lists |
#         from json |
#         get PrefixLists |
#         each {|pl| [
#             $pl.PrefixListName,
#             $pl.PrefixListId,
#             $pl.AddressFamily
#         ]} |
#         sk |
#         get 1
#     )

#     mut p_version = (aws ec2 describe-managed-prefix-lists --prefix-list-ids $prefix_list | from json | get PrefixLists.0.Version)
#     echo $p_version

#     let ips = (http get http://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips | from json | get CLOUDFRONT_GLOBAL_IP_LIST | sk)

#     $ips | each {|ip|
#         aws ec2 modify-managed-prefix-list --prefix-list-id $prefix_list --add-entries $"Cidr=($ip)" --current-version $p_version | from json
#         $p_version = $p_version + 1
#     }
# }
alias ssm-describe-parameters = aws-list-cmd ssm describe-parameters Parameters Name
# Security Groups
def list-sg [
    --profile: string = "",  # AWS profile to use
    --region: string = "us-east-1"  # AWS region to use
] {
    let cmd = if ($profile | is-empty) {
        (aws ec2 describe-security-groups --region $region)
    } else {
        (aws ec2 describe-security-groups --profile $profile --region $region)
    }

    $cmd | from json |
    get SecurityGroups |
    each {|sg| [
        $sg.GroupId,
        $sg.GroupName,
        $sg.Description
    ]}
}

def list-sg-rules [
    --profile: string = "",  # AWS profile to use
    --region: string = "us-east-1"  # AWS region to use
] {
    let sg_id = (list-sg --profile $profile --region $region | sk | get 0)

    echo $"Ingress Rules for Security Group: ($sg_id)"
    echo "-----------------------------------------"

    let cmd = if ($profile | is-empty) {
        (aws ec2 describe-security-group-rules --filters $"Name=group-id,Values=($sg_id)" --region $region)
    } else {
        (aws ec2 describe-security-group-rules --profile $profile --filters $"Name=group-id,Values=($sg_id)" --region $region)
    }

    $cmd | from json |
    get SecurityGroupRules |
    where IsEgress == false |
    select Description IpProtocol FromPort ToPort CidrIpv4 CidrIpv6 ReferencedGroupId |
    each {|rule|
        {
            Description: ($rule.Description | default "N/A"),
            IpProtocol: $rule.IpProtocol,
            FromPort: ($rule.FromPort | default "N/A"),
            ToPort: ($rule.ToPort | default "N/A"),
            CidrIpv4: ($rule.CidrIpv4 | default "N/A"),
            CidrIpv6: ($rule.CidrIpv6 | default "N/A"),
            ReferencedGroupId: ($rule.ReferencedGroupId | default "N/A")
        }
    } | table

    echo ""
    echo $"Egress Rules for Security Group: ($sg_id)"
    echo "----------------------------------------"

    $cmd | from json |
    get SecurityGroupRules |
    where IsEgress == true |
    select IsEgress Description IpProtocol FromPort ToPort CidrIpv4 CidrIpv6 ReferencedGroupId |
    each {|rule|
        {
            IsEgress: $rule.IsEgress,
            Description: ($rule.Description | default "N/A"),
            IpProtocol: $rule.IpProtocol,
            FromPort: ($rule.FromPort | default "N/A"),
            ToPort: ($rule.ToPort | default "N/A"),
            CidrIpv4: ($rule.CidrIpv4 | default "N/A"),
            CidrIpv6: ($rule.CidrIpv6 | default "N/A"),
            ReferencedGroupId: ($rule.ReferencedGroupId | default "N/A")
        }
    } | table
}

def list-vpc [
    --profile: string = ""  # AWS profile to use
] {
    let cmd = if ($profile | is-empty) {
        (aws ec2 describe-vpcs)
    } else {
        (aws ec2 describe-vpcs --profile $profile)
    }

    $cmd | from json |
    get Vpcs |
    each {|vpc| [
        $vpc.VpcId,
        $vpc.CidrBlock,
        $vpc.IsDefault
    ]}
}

def copy-sg-cross-account [
    src_account?: string,     # Source AWS profile
    dest_account?: string,    # Destination AWS profile
    src_region?: string,      # Source AWS region
    dest_region?: string      # Destination AWS region
] {
    # Get inputs if not provided
    let source_profile = if $src_account == null { gum input --placeholder "Input profile" } else { $src_account }
    let dest_profile = if $dest_account == null { gum input --placeholder "Output profile" } else { $dest_account }
    let source_region = if $src_region == null { gum input --placeholder "Source region" } else { $src_region }
    let dest_region = if $dest_region == null { gum input --placeholder "Destination region" } else { $dest_region }

    # Get source security group
    let sg_id = ($env.AWS_DEFAULT_REGION = $source_region
        aws ec2 describe-security-groups --profile $source_profile |
        from json |
        get SecurityGroups |
        each {|sg| [$sg.GroupId, $sg.GroupName, $sg.Description]} |
        sk |
        get 0)

    # Get security group details
    $env.AWS_DEFAULT_REGION = $source_region
    let sg_name = (aws ec2 describe-security-groups --group-ids $sg_id --profile $source_profile | from json | get SecurityGroups.0.GroupName)
    let sg_desc = (aws ec2 describe-security-groups --group-ids $sg_id --profile $source_profile | from json | get SecurityGroups.0.Description)

    echo $"Copying security group ($sg_name)"

    # Get VPC info
    $env.AWS_DEFAULT_REGION = $source_region
    let source_vpc = (aws ec2 describe-security-groups --group-ids $sg_id --profile $source_profile | from json | get SecurityGroups.0.VpcId)

    $env.AWS_DEFAULT_REGION = $dest_region
    let dest_vpc = (list-vpc --profile $dest_profile | sk | get 0)

    echo $"Source VPC: ($source_vpc) Destination VPC: ($dest_vpc)"

    # Check if security group exists in destination
    $env.AWS_DEFAULT_REGION = $dest_region
    let dest_sg_id = (aws ec2 describe-security-groups --filters $"Name=vpc-id,Values=($dest_vpc)" $"Name=group-name,Values=($sg_name)" --profile $dest_profile | from json | get SecurityGroups.0.GroupId | default "")
    echo $"Destination SG ID: ($dest_sg_id)"

    # Create security group if it doesn't exist
    if ($dest_sg_id | is-empty) {
        echo $"Creating security group ($sg_name) in ($dest_region)"
        $env.AWS_DEFAULT_REGION = $dest_region
        let dest_sg_id = (aws ec2 create-security-group --group-name $sg_name --description $sg_desc --vpc-id $dest_vpc --profile $dest_profile --output text --query 'GroupId')
    }

    # Select destination security group
    $env.AWS_DEFAULT_REGION = $dest_region
    let dest_sg_id = (list-sg --profile $dest_profile --region $dest_region | sk | get 0)
    echo $"Destination SG ID: ($dest_sg_id) source SG ID: ($sg_id)"

    # Copy ingress rules
    $env.AWS_DEFAULT_REGION = $source_region
    let ingress_rules = (aws ec2 describe-security-groups --group-ids $sg_id --profile $source_profile | from json | get SecurityGroups.0.IpPermissions)

    $ingress_rules | each {|rule|
        $env.AWS_DEFAULT_REGION = $dest_region
        aws ec2 authorize-security-group-ingress --group-id $dest_sg_id --profile $dest_profile --ip-permissions ($rule | to json) | from json
    }

    # Copy egress rules
    $env.AWS_DEFAULT_REGION = $source_region
    let egress_rules = (aws ec2 describe-security-groups --group-ids $sg_id --profile $source_profile | from json | get SecurityGroups.0.IpPermissionsEgress)

    $egress_rules | each {|rule|
        $env.AWS_DEFAULT_REGION = $dest_region
        aws ec2 authorize-security-group-egress --group-id $dest_sg_id --profile $dest_profile --ip-permissions ($rule | to json) | from json
    }
}

# SSM
def ssm-connect [] {
    let instance_id = (list-ec2-instances | sk | get 0)
    aws ssm start-session --target $instance_id
}

# IAM Role Trust Policy
def get-iam-role-trust-policy [
    --profile: string = "" # AWS profile to use
    --region: string = "us-east-1" # AWS region to use
] {

    let role_name = iam-list-roles --profile $profile --region $region | get RoleName

    if ($role_name | is-empty) {
        return "No role selected"
    }

    let cmd = if ($profile | is-empty) {
        aws iam get-role --role-name $role_name --region $region | from json | get Role.AssumeRolePolicyDocument
    } else {
        aws iam get-role --role-name $role_name --profile $profile --region $region | from json | get Role.AssumeRolePolicyDocument
    }

    $cmd
}
