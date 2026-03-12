" after/ftplugin/sfml.vim
" Registers undo_ftplugin so settings are cleaned up when changing filetypes

let b:undo_ftplugin = "setl et< sw< ts< sts< cms< fdm< fde< foldlevel<"
  \ . " | setl omnifunc<"
  \ . " | unlet! b:did_ftplugin_sfml"
