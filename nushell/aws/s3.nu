# S3 commands

def s3-notification-targets [] {
    ["sqs", "sns", "lambda"]
}

alias s3-list-buckets = aws-list-cmd s3api list-buckets Buckets Name

def s3-get-bucket-versioning [] {
    let bucket = (s3-list-buckets | sk | get 0)
    aws s3api get-bucket-versioning --bucket $bucket | from json
}

def s3-enable-bucket-versioning [] {
    let bucket = (s3-list-buckets | sk | get 0)
    aws s3api put-bucket-versioning --bucket $bucket --versioning-configuration Status=Enabled | from json
}

def s3-get-bucket-policy [] {
    let bucket = (s3-list-buckets | sk | get 0)
    aws s3api get-bucket-policy --bucket $bucket | from json | get Policy | from json
}

def s3-add-clean-lifecycle-policy [
    bucketname?: string,  # Optional bucket name (selected from list if not provided)
    --profile: string@profiles = "",  # AWS profile to use
    --region: string@regions = "us-east-1"  # AWS region to use
] {
    let buckets = if $bucketname == null {
        aws s3api list-buckets --profile $profile --region $region | from json | get Buckets | sk --format {get Name} --multi | each {|bucket| $bucket.Name}

    } else {
        [$bucketname]
    }
    # Create lifecycle configuration JSON
    let lifecycle_config = {
        Rules: [
            {
                ID: "cleanup-noncurrent-versions",
                Status: "Enabled",
                Filter: {},
                NoncurrentVersionExpiration: {
                    NoncurrentDays: 1
                }
                Expiration: {
                    ExpiredObjectDeleteMarker: true
                }
                AbortIncompleteMultipartUpload: {
                    DaysAfterInitiation: 1
                }
            }
        ]
    }

    # Save configuration to temporary file
    let temp_file = mktemp
    $lifecycle_config | to json | save -f $temp_file

    # Apply lifecycle configuration to each bucket
    $buckets | each {|bucket|
        let cmd = if ($profile | is-empty) {
            aws s3api put-bucket-lifecycle-configuration --bucket $bucket --lifecycle-configuration $"file://($temp_file)" --region $region
        } else {
            aws s3api put-bucket-lifecycle-configuration --bucket $bucket --lifecycle-configuration $"file://($temp_file)" --profile $profile --region $region
        }
        $cmd | from json
    }

    # Delete temporary file
    rm $temp_file
}


def s3-edit-bucket-policy [
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

def s3-add-bucket-tag [
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
        let topicconfig = $configrecord | get -o TopicConfigurations
        $configrecord = if $topicconfig == null {
            $configrecord | insert TopicConfigurations  [$config]
        } else {
            $configrecord.TopicConfigurations = ($configrecord.TopicConfigurations | append $config)
        }
    } else if $target_type == "sqs" {
        $config.QueueArn = $target
        let topicconfig = $configrecord | get -o QueueConfigurations
        $configrecord = if $topicconfig == null {
            print "Adding Queue"
            $configrecord | insert QueueConfigurations  $config
        } else {
            $configrecord.QueueConfigurations = ($configrecord.QueueConfigurations | append $config)
        }
    } else if $target_type == "lambda" {
        $config.LambdaFunctionArn = $target
        let topicconfig = $configrecord | get -o LambdaFunctionConfigurations
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
