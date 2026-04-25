" Highlight Git word-diffs
syntax region diffRemoved matchgroup=diffRemoved start="\[-" end="-\]"
syntax region diffAdded matchgroup=diffAdded start="{+" end="+}"
