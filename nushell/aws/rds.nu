alias rds-describe-db-instances = aws-list-cmd rds describe-db-instances DBInstances DBInstanceIdentifier
# Extended RDS commands

def rds-stop-instances [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let instances = if ($profile | is-empty) {
        aws rds describe-db-instances --region $region | from json | get DBInstances | where DBInstanceStatus == "available"
    } else {
        aws rds describe-db-instances --profile $profile --region $region | from json | get DBInstances | where DBInstanceStatus == "available"
    }

    let selected_instances = ($instances | each {|instance| [
        $instance.DBInstanceIdentifier,
        $instance.Engine,
        $instance.DBInstanceClass,
        $instance.DBInstanceStatus
    ]} | sk --multi)

    $selected_instances | each {|instance|
        let db_id = $instance.0
        print $"Stopping RDS instance: ($db_id)"

        let cmd = if ($profile | is-empty) {
            aws rds stop-db-instance --db-instance-identifier $db_id --region $region
        } else {
            aws rds stop-db-instance --db-instance-identifier $db_id --profile $profile --region $region
        }

        $cmd | from json
    }
}

def rds-stop-clusters [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let clusters = if ($profile | is-empty) {
        aws rds describe-db-clusters --region $region | from json | get DBClusters | where Status == "available"
    } else {
        aws rds describe-db-clusters --profile $profile --region $region | from json | get DBClusters | where Status == "available"
    }

    let selected_clusters = ($clusters | each {|cluster| [
        $cluster.DBClusterIdentifier,
        $cluster.Engine,
        $cluster.EngineVersion,
        $cluster.Status
    ]} | sk --multi)

    $selected_clusters | each {|cluster|
        let cluster_id = $cluster.0
        print $"Stopping RDS cluster: ($cluster_id)"

        let cmd = if ($profile | is-empty) {
            aws rds stop-db-cluster --db-cluster-identifier $cluster_id --region $region
        } else {
            aws rds stop-db-cluster --db-cluster-identifier $cluster_id --profile $profile --region $region
        }

        $cmd | from json
    }
}

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
