# alias
alias j = z
alias ji = zi
alias pkill = pik
alias ps = pik

alias gst = git status

# ACR
def acr-get-repo-size [
    --registry: string
] {
    let repos = (az acr repository list -n $registry | from json)
    $repos | each {|repo|
        let reposize = (az acr repository show-manifests -n $registry --repository $repo --detail | from json | each {|img| $img.imageSize} |
                        math sum | $in / 1000000000)
        {'repo': $repo, 'reposize': $reposize }
    }
}
