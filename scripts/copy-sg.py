def copy_security_group_rules(
    src_account, dest_account, src_region, dest_region, src_sg_name
):
    """
    Copy security group rules from source to destination account.
    Creates the security group in the destination if it doesn't exist.

    Args:
        src_account: Source AWS profile name
        dest_account: Destination AWS profile name
        src_region: Source AWS region
        dest_region: Destination AWS region
        src_sg_name: Name of the security group to copy
    """
    import boto3

    # Create boto3 clients with profile names
    src_session = boto3.Session(profile_name=src_account, region_name=src_region)
    src_ec2 = src_session.client("ec2")

    dest_session = boto3.Session(profile_name=dest_account, region_name=dest_region)
    dest_ec2 = dest_session.client("ec2")

    # Get source security group details
    sg_filter = [{"Name": "group-name", "Values": [src_sg_name]}]
    src_sg_response = src_ec2.describe_security_groups(Filters=sg_filter)

    if not src_sg_response["SecurityGroups"]:
        raise ValueError(f"Security group '{src_sg_name}' not found in source account")

    src_sg = src_sg_response["SecurityGroups"][0]
    src_sg_description = src_sg.get("Description", "")

    # Check if security group exists in destination
    dest_sg_response = dest_ec2.describe_security_groups(Filters=sg_filter)

    if dest_sg_response["SecurityGroups"]:
        dest_sg_id = dest_sg_response["SecurityGroups"][0]["GroupId"]
        print(
            f"Security group '{src_sg_name}' already exists in destination account with ID: {dest_sg_id}"
        )
    else:
        # Create security group in destination
        dest_vpc_response = dest_ec2.describe_vpcs(
            Filters=[{"Name": "isDefault", "Values": ["true"]}]
        )
        if not dest_vpc_response["Vpcs"]:
            # If default VPC doesn't exist, get the first available VPC instead
            dest_vpc_response = dest_ec2.describe_vpcs()
            if not dest_vpc_response["Vpcs"]:
                raise ValueError("No VPCs found in destination account")

        dest_vpc_id = dest_vpc_response["Vpcs"][0]["VpcId"]

        create_response = dest_ec2.create_security_group(
            GroupName=src_sg_name, Description=src_sg_description, VpcId=dest_vpc_id
        )
        dest_sg_id = create_response["GroupId"]
        print(
            f"Created security group '{src_sg_name}' in destination account with ID: {dest_sg_id}"
        )

    # Copy inbound rules
    if src_sg.get("IpPermissions"):
        dest_ec2.authorize_security_group_ingress(
            GroupId=dest_sg_id, IpPermissions=src_sg["IpPermissions"]
        )
        print(f"Copied {len(src_sg['IpPermissions'])} inbound rules")

    # Copy outbound rules
    if src_sg.get("IpPermissionsEgress"):
        # First, remove the default outbound rule if it exists
        try:
            dest_ec2.revoke_security_group_egress(
                GroupId=dest_sg_id,
                IpPermissions=[
                    {"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
                ],
            )
        except Exception as e:
            print(f"Warning when removing default outbound rule: {str(e)}")

        # Add the source outbound rules
        dest_ec2.authorize_security_group_egress(
            GroupId=dest_sg_id, IpPermissions=src_sg["IpPermissionsEgress"]
        )
        print(f"Copied {len(src_sg['IpPermissionsEgress'])} outbound rules")

    print(
        f"Security group '{src_sg_name}' successfully copied from source to destination account"
    )
    return dest_sg_id
