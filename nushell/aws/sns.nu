alias sns-list-topics = aws-list-cmd sns list-topics Topics TopicArn
# Extended SNS commands
def list-subscriptions-for-topics [] {
    let topic_arn = (aws-list-cmd sns list-topics Topics TopicArn | sk | get 0)
    aws sns list-subscriptions-by-topic --topic-arn $topic_arn | from json
}

def list-subscriptions [] {
    gum spin --title "Fetching Subscriptions" -- aws sns list-subscriptions |
    from json |
    get Subscriptions |
    each {|sub| [
        $sub.SubscriptionArn,
        $sub.Protocol,
        $sub.Endpoint
    ]}
}

def add-email-subscription [] {
    let email = (gum input --placeholder "Email")
    let topic_arn = (aws-list-cmd sns list-topics Topics TopicArn | sk | get 0)
    aws sns subscribe --topic-arn $topic_arn --protocol email --notification-endpoint $email | from json
}

def confirm-subscription [] {
    let confirmlink = (gum input --char-limit 4000 --placeholder "Confirmation Link")
    let token = ($confirmlink | python3 -c "import sys; from urllib.parse import unquote; print(unquote(sys.stdin.read()).split('&')[1].split('=')[-1]);")

    let topic_arn = (aws-list-cmd sns list-topics Topics TopicArn | sk | get 0)
    aws sns confirm-subscription --topic-arn $topic_arn --token $token | from json
}

def delete-subscriptions [] {
    let subscription_arn = (list-subscriptions | sk | get 0)
    aws sns unsubscribe --subscription-arn $subscription_arn | from json
}
