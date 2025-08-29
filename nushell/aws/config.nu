# AWS Config
def aws-noncompliant-resources [] {
    let rtype = (aws configservice describe-compliance-by-resource --compliance-types NON_COMPLIANT | from json | get ComplianceByResources | each {|r| $r.ResourceType} | uniq | sk)
    if $rtype != null {
        aws configservice describe-compliance-by-resource --compliance-types NON_COMPLIANT --resource-type $rtype | from json
    }
}
