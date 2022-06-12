# configuration file

# popup window key
set ::activateKey "Alt-j"

# hide window key
bind all <Alt-J> {after 50 {hide [winfo toplevel %W]}}

bind all <Alt-O> {}
bind all <Key-Escape> "cancel"
bind all <Control-g> "after 50 clear"
bind all <Control-q> "after 50 exit"
bind all <Alt-Key-0> "directMode %W"
bind all <Alt-Key-1> "hiraganaMode %W"
bind all <Alt-Key-2> "katakanaMode %W"
bind all <Alt-Key-3> "cangjieMode %W"
bind all <Alt-Key-4> "skkdicMode %W"
