# carapace
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu

zoxide init nushell | save -f ~/.zoxide.nu

$env.ATUIN_NOBIND = true
mkdir ~/.local/share/atuin
atuin init nu | save -f ~/.local/share/atuin/init.nu #make sure you created the directory beforehand with `mkdir ~/.local/share/atuin/init.nu`

let mise_path = $nu.default-config-dir | path join mise.nu
^mise activate nu | save $mise_path --force
