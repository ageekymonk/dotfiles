" Title:        Neocloud
" Description:  A plugin to handle cloud
" Last Change:  17 September 2022
" Maintainer:   ageekymonk <https://github.com/ageekymonk>

" Prevents the plugin from being loaded multiple times. If the loaded
" variable exists, do nothing more. Otherwise, assign the loaded
" variable and continue running this instance of the plugin.
if exists("g:loaded_neocloud")
    finish
endif
let g:loaded_neocloud = 1

" Defines a package path for Lua. This facilitates importing the
" Lua modules from the plugin's dependency directory.
let s:lua_rocks_deps_loc =  expand("<sfile>:h:r") . "/../lua/neocloud/deps"
exe "lua package.path = package.path .. ';" . s:lua_rocks_deps_loc . "/lua-?/init.lua'"

