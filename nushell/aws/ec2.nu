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
