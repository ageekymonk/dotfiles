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

    let platform_identifier = if $platform_identifier == "" {
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
            --kms-key-id ($details.KmsKeyId? | default "")
            --lifecycle-config-name $details.NotebookInstanceLifecycleConfigName
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
            --kms-key-id ($details.KmsKeyId? | default "")
            --lifecycle-config-name $details.NotebookInstanceLifecycleConfigName
            --direct-internet-access $details.DirectInternetAccess
            --platform-identifier $platform_identifier
            --profile $profile
            --region $region)
    }

    $cmd_create | from json | echo $"Cloned notebook ($source_notebook) to ($new_name)"
}

def sagemaker-notebook-stop [
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1",  # AWS region to use
] {
    let notebook_name = (sagemaker-list-notebooks --profile $profile --region $region | get NotebookInstanceName)
    aws sagemaker stop-notebook-instance --notebook-instance-name $notebook_name | from json
}

def sagemaker-notebook-start [
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1",  # AWS region to use
] {
    let notebook_name = (sagemaker-list-notebooks --profile $profile --region $region | get NotebookInstanceName)
    aws sagemaker start-notebook-instance --notebook-instance-name $notebook_name | from json
}

def sagemaker-notebook-delete [
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1",  # AWS region to use
] {
    let notebook_name = (sagemaker-list-notebooks --profile $profile --region $region | get NotebookInstanceName)
    aws sagemaker delete-notebook-instance --notebook-instance-name $notebook_name --profile $profile --region $region | from json
}       