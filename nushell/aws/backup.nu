# AWS Backups
def backup-delete-recovery-points-by-resource [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    # Get list of protected resources
    let cmd_list_resources = if ($profile | is-empty) {
        aws backup list-protected-resources --region $region
    } else {
        aws backup list-protected-resources --profile $profile --region $region
    }

    let resource_arn = ($cmd_list_resources | from json | get Results | each {|resource| [
        $resource.ResourceArn,
        $resource.ResourceType,
        ($resource.LastBackupTime | into datetime | format date "%Y-%m-%d %H:%M:%S")
    ]} | sk | get 0)

    # Get recovery points for the selected resource
    let cmd_list_recovery = if ($profile | is-empty) {
        aws backup list-recovery-points-by-resource --resource-arn $resource_arn --region $region
    } else {
        aws backup list-recovery-points-by-resource --resource-arn $resource_arn --profile $profile --region $region
    }

    let recovery_points = ($cmd_list_recovery | from json | get RecoveryPoints | each {|point| [
        $point.RecoveryPointArn,
        ($point.CreationDate | into datetime | format date "%Y-%m-%d %H:%M:%S"),
        $point.Status,
        $point.ResourceName
    ]} | sk --multi)

    let cmd_list_vaults = if ($profile | is-empty) {
        aws backup list-backup-vaults --region $region
    } else {
        aws backup list-backup-vaults --profile $profile --region $region
    }

    let vault_name = ($cmd_list_vaults | from json | get BackupVaultList | each {|vault| $vault.BackupVaultName} | sk)

    $recovery_points | each {|recovery_point|
        let recovery_arn = $recovery_point.0

        let cmd_delete = if ($profile | is-empty) {
            aws backup delete-recovery-point --backup-vault-name $vault_name --recovery-point-arn $recovery_arn --region $region
        } else {
            aws backup delete-recovery-point --backup-vault-name $vault_name --recovery-point-arn $recovery_arn --profile $profile --region $region
        }

        $cmd_delete | from json
    }
}

def backup-delete-recovery-point [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let cmd_list_vaults = if ($profile | is-empty) {
        aws backup list-backup-vaults --region $region
    } else {
        aws backup list-backup-vaults --profile $profile --region $region
    }

    let vault_name = ($cmd_list_vaults | from json | get BackupVaultList | each {|vault| $vault.BackupVaultName} | sk)

    let cmd_list_recovery = if ($profile | is-empty) {
        aws backup list-recovery-points-by-backup-vault --backup-vault-name $vault_name --region $region
    } else {
        aws backup list-recovery-points-by-backup-vault --backup-vault-name $vault_name --profile $profile --region $region
    }

    let recovery_points = ($cmd_list_recovery | from json | get RecoveryPoints | each {|point| [
        $point.RecoveryPointArn,
        ($point.CreationDate | into datetime | format date "%Y-%m-%d %H:%M:%S"),
        $point.Status,
        $point.ResourceType
    ]} | sk --multi)

    $recovery_points | each {|recovery_point|
        let recovery_arn = $recovery_point.0

        let cmd_delete = if ($profile | is-empty) {
            aws backup delete-recovery-point --backup-vault-name $vault_name --recovery-point-arn $recovery_arn --region $region
        } else {
            aws backup delete-recovery-point --backup-vault-name $vault_name --recovery-point-arn $recovery_arn --profile $profile --region $region
        }

        $cmd_delete | from json
    }
}
