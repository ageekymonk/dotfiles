# alias
alias j = z
alias ji = zi
alias pkill = pik
alias ps = pik

# Account
def account-id [
    --profile: string  # AWS profile to use
] {
    aws sts get-caller-identity --profile $profile | from json | get Account
}

# ACM
def acm-list-expired-certificates [
    --profile: string = ""  # AWS profile to use
    --region: string  = "us-east-1" # AWS Region to use
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
    --profile: string = "" # AWS profile to use
    --region: string = "us-east-1" # AWS region to use
] {
    let cmd = if ($profile | is-empty) {
        aws $servicename $actionname --region $region
    } else {
        aws $servicename $actionname --profile $profile --region $region
    }

    $cmd | from json | get $ResponseKey | sk --format {get $PrimaryKey} --preview {}
}

alias acm-list-certificates = aws-list-cmd acm list-certificates CertificateSummaryList DomainName
alias s3-list-buckets = aws-list-cmd s3api list-buckets Buckets Name
alias appsync-list-graphql-apis = aws-list-cmd appsync list-graphql-apis graphqlApis name
alias cloudformation-list-stacks = aws-list-cmd cloudformation list-stacks StackSummaries StackName
alias cloudwatch-list-dashboards = aws-list-cmd cloudwatch list-dashboards DashboardEntries DashboardName
alias cloudwatch-list-metrics = aws-list-cmd cloudwatch list-metrics Metrics MetricName
alias dynamodb-list-tables = aws-list-cmd dynamodb list-tables TableNames .
alias ec2-describe-instances = aws-list-cmd ec2 describe-instances Reservations InstanceId
alias ec2-describe-vpcs = aws-list-cmd ec2 describe-vpcs Vpcs VpcId
alias ec2-describe-subnets = aws-list-cmd ec2 describe-subnets Subnets SubnetId
alias ecr-describe-repositories = aws-list-cmd ecr describe-repositories repositories repositoryName
alias ecs-list-clusters = aws-list-cmd ecs list-clusters clusterArns .
alias efs-describe-file-systems = aws-list-cmd efs describe-file-systems FileSystems FileSystemId
alias eks-list-clusters = aws-list-cmd eks list-clusters clusters .
alias elasticbeanstalk-describe-applications = aws-list-cmd elasticbeanstalk describe-applications Applications ApplicationName
alias elasticache-describe-cache-clusters = aws-list-cmd elasticache describe-cache-clusters CacheClusters CacheClusterId
alias elb-describe-load-balancers = aws-list-cmd elb describe-load-balancers LoadBalancerDescriptions LoadBalancerName
alias elbv2-describe-load-balancers = aws-list-cmd elbv2 describe-load-balancers LoadBalancers LoadBalancerName
alias iam-list-roles = aws-list-cmd iam list-roles Roles RoleName
alias iam-list-users = aws-list-cmd iam list-users Users UserName
alias kms-list-keys = aws-list-cmd kms list-keys Keys KeyId
alias lambda-list-functions = aws-list-cmd lambda list-functions Functions FunctionName
alias rds-describe-db-instances = aws-list-cmd rds describe-db-instances DBInstances DBInstanceIdentifier
alias route53-list-hosted-zones = aws-list-cmd route53 list-hosted-zones HostedZones Name
alias sns-list-topics = aws-list-cmd sns list-topics Topics TopicArn
alias sqs-list-queues = aws-list-cmd sqs list-queues QueueUrls .
alias ssm-describe-parameters = aws-list-cmd ssm describe-parameters Parameters Name
