" Mappings that insert matching curly braces and star comment completion
runtime shared/brace_mapping.vim
runtime shared/c_comment_mapping.vim

" Remove trailing spaces
auto BufWrite *.scala,*.sc call spaces#StripTrailingNormal()
