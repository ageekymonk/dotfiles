# starship
mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

# carapace
source ~/.cache/carapace/init.nu

# atuin
source ~/.local/share/atuin/init.nu

# zoxide
source ~/.zoxide.nu

# Plugins
plugin add ~/.cargo/bin/nu_plugin_skim

$env.config = {
    ls: {
        use_ls_colors: true # use the LS_COLORS environment variable to colorize output
        clickable_links: true # enable or disable clickable links. Your terminal has to support links.
    }

    menus: [
        {
            name: zoxide_menu
            only_buffer_difference: true
            marker: "| "
            type: {
                layout: columnar
                page_size: 20
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
            source: { |buffer, position|
                zoxide query -ls $buffer
                | parse -r '(?P<description>[0-9]+) (?P<value>.+)'
            }
          }
          {
                  name: vars_menu
                  only_buffer_difference: true
                  marker: "# "
                  type: {
                      layout: list
                      page_size: 10
                  }
                  style: {
                      text: green
                      selected_text: green_reverse
                      description_text: yellow
                  }
                  source: { |buffer, position|
                      scope variables
                      | where name =~ $buffer
                      | sort-by name
                      | each { |row| {value: $row.name description: $row.type} }
                  }
                }
    ]

    keybindings: [
        {
            name: atuin
            modifier: control
            keycode: char_r
            mode: [emacs, vi_normal, vi_insert]
            event: { send: executehostcommand cmd: (_atuin_search_cmd) }
        }
    ]
}

#bind to ctrl-r in emacs, vi_normal and vi_insert modes, add any other bindings you want here too
# $env.config = (
#     $env.config | upsert keybindings (
#         $env.config.keybindings
#         | append {
#             name: atuin
#             modifier: control
#             keycode: char_r
#             mode: [emacs, vi_normal, vi_insert]
#             event: { send: executehostcommand cmd: (_atuin_search_cmd) }
#         }
#     )

# )
$env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD | append (source hooks/direnv.nu)
)

use ($nu.default-config-dir | path join mise.nu)
$env.PATH = ($env.PATH | split row (char esep) | append "~/.nix-profile/bin")
source alias.nu
