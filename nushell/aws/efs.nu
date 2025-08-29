# EFS
alias efs-list-file-systems = aws-list-cmd efs describe-file-systems FileSystems Name

def efs-add-lifecycle-ia [
    fsid?: string,  # Optional list of filesystem IDs (selected from list if not provided)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let filesystems = if $fsid == null {
        aws efs describe-file-systems --profile $profile --region $region | from json | get FileSystems |  sk --format {get Name} --multi | each {|fs| $fs.FileSystemId }
    } else {
        [$fsid]
    }

    # Create lifecycle configuration for IA transition after 30 days
    $filesystems | each {|fsid|
        let cmd = if ($profile | is-empty) {
            aws efs put-lifecycle-configuration --file-system-id $fsid --lifecycle-policies "TransitionToIA=AFTER_30_DAYS" --region $region
        } else {
            aws efs put-lifecycle-configuration --file-system-id $fsid --lifecycle-policies "TransitionToIA=AFTER_30_DAYS" --profile $profile --region $region
        }

        $cmd | from json
        print $"Applied IA lifecycle policy to filesystem ($fsid)"
    }
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
