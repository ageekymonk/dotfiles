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
