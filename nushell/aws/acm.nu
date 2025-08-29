# ACM
alias acm-list-certificates = aws-list-cmd acm list-certificates CertificateSummaryList DomainName

def acm-list-expired-certificates [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions  = "us-east-1" # AWS Region to use
] {
    let cmd = if ($profile | is-empty) {
        aws acm list-certificates --region $region
    } else {
        aws acm list-certificates --profile $profile --region $region
    }

    $cmd | from json | get CertificateSummaryList | where Status == "EXPIRED" | sk --format {get DomainName} --preview {}
}

def acm-import-cert [
    --profile: string@profiles = ""  # AWS profile to use
    --region: string@regions = "us-east-1" # AWS Region to use
] {
    let certfile = (gum file)
    let certfilepem = ($certfile) | str replace ".crt" ".pem"
    let key = (gum file)
    # Extract lines between first Begin and End
    ^sed '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/!d;/-----END CERTIFICATE-----/q' $certfile | save -f ($certfilepem)

    let cmd = if ($profile | is-empty) {
        aws acm import-certificate --certificate fileb://($certfilepem) --private-key fileb://($key) --region $region
    } else {
        aws acm import-certificate --certificate fileb://($certfilepem) --private-key fileb://($key) --profile $profile --region $region
    }

    $cmd | from json
}
