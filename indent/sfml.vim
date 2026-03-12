" indent/sfml.vim
" Indentation rules for SFML
" Indent after: DO, THEN, ELSE
" Dedent on:    END, ELSE

if exists("b:did_indent_sfml")
  finish
endif
let b:did_indent_sfml = 1

setlocal indentexpr=SFMLIndent(v:lnum)
setlocal indentkeys=o,O,0=END,0=end,0=ELSE,0=else

function! SFMLIndent(lnum)
  " Find the previous non-empty line
  let prev_lnum = prevnonblank(a:lnum - 1)
  if prev_lnum == 0
    return 0
  endif

  let prev_line = getline(prev_lnum)
  let cur_line  = getline(a:lnum)
  let indent    = indent(prev_lnum)
  let sw        = shiftwidth()

  " Increase indent after lines ending with DO or THEN
  if prev_line =~? '\v<(DO|THEN)>\s*(--.*)?$'
    let indent += sw
  endif

  " ELSE: go back to the indent of the matching IF
  if cur_line =~? '\v^\s*<(ELSE|ELSE\s+IF)>'
    let indent -= sw
  endif

  " END: go back to the indent of the matching DO/THEN
  if cur_line =~? '\v^\s*<END>'
    let indent -= sw
  endif

  return indent
endfunction
