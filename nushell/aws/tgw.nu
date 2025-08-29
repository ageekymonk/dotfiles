# Transit Gateway commands
def tgw-show-route-tables [] {
    aws ec2 describe-transit-gateway-route-tables |
    from json |
    get TransitGatewayRouteTables |
    each {|table| [
        $table.TransitGatewayRouteTableId,
        $table.TransitGatewayId,
        $table.State,
        ($table.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value })
    ]}
}

def tgw-show-static-routes [] {
    let tgw_route = (tgw-show-route-tables | sk | get 0)

    aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id $tgw_route --filters "Name=type,Values=static" |
    from json |
    get Routes |
    where TransitGatewayAttachments != null |
    each {|route| [
        $route.DestinationCidrBlock,
        $route.TransitGatewayAttachments.0.TransitGatewayAttachmentId
    ]}
}

def tgw-show-attachments [] {
    aws ec2 describe-transit-gateway-attachments |
    from json |
    get TransitGatewayAttachments |
    each {|attach| [
        $attach.TransitGatewayAttachmentId,
        $attach.ResourceType,
        $attach.ResourceOwnerId,
        $attach.ResourceRegion,
        $attach.State,
        ($attach.Tags | where Key == "Name" | if $in == [] { "No Name" } else { $in.0.Value })
    ]}
}

def tgw-add-static-route [] {
    let tgw_route = (tgw-show-route-tables | sk | get 0)
    let tgw_attach = (tgw-show-attachments | sk | get 0)
    let cidr = (gum input --placeholder "CIDR")

    echo $"aws ec2 create-transit-gateway-route --transit-gateway-route-table-id ($tgw_route) --destination-cidr-block ($cidr) --transit-gateway-attachment-id ($tgw_attach)"
    aws ec2 create-transit-gateway-route --transit-gateway-route-table-id $tgw_route --destination-cidr-block $cidr --transit-gateway-attachment-id $tgw_attach | from json
}
