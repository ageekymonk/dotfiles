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
