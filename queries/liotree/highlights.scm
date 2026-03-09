;; highlights.scm
;; extends

; --- 1. Structural Conceals ---
((root_bar) @conceal.root
(#set! @conceal.root "conceal" ""))

((entry_bar) @conceal.entry
(#set! @conceal.entry "conceal" "├"))

((scope_delimiter_open) @conceal.delimiter.open
 (#set! @conceal.delimiter.open "conceal" "┢"))

((scope_delimiter_closed) @conceal.delimiter.closed
 (#set! @conceal.delimiter.closed "conceal" "┡"))


; Handle every dash/plus individually 
; We apply the line icon to ALL of them first
;((depth_mark) @conceal.line @operator
;(#set! @conceal.line "conceal" "─"))

((depth_mark) @conceal.line @operator
(#set! @conceal.line "conceal" "─"))

; --- 2. Smart Icons (The "Overlays") ---
; If a depth_mark is the last child of a depth_marker, it's our icon candidate
; Note: Older TS engines may need the simple version:
; 1. DEFAULT LINE (The Fallback)
; We put this first so specific icon rules can override it
((file_entry 
  bridge: (depth_mark) @conceal.line)
(#set! @conceal.line "conceal" "┼"))

((directory_entry 
  bridge: (depth_mark) @conceal.line)
(#set! @conceal.line "conceal" "┼"))

; 2. LEAF (The Icons)
; If the leaf belongs to a directory entry
((directory_entry 
    leaf: (depth_mark) @conceal.dir
    name: (directory_name))
 (#set! @conceal.dir "conceal" ""))

; If the leaf belongs to a file entry
((file_entry 
    leaf: (depth_mark) @conceal.file
    name: (file_name))
 (#set! @conceal.file "conceal" ""))


; --- 3. Comment Logic ---

((comment_open) @conceal.comment.open @liotree.bar
 (#set! @conceal.comment.open "conceal" "▶"))

((comment_text) @liotree.comment.text @spell)

((comment_closed) @conceal.comment.closed @liotree.bar
 (#set! @conceal.comment.closed "conceal" "█"))

((comment_bar) @conceal.comment.bar @liotree.bar
(#set! @conceal.comment.bar "conceal" "┃"))

; ┃

((format_space) @liotree.formatspace)
(directory_entry bridge: (depth_mark) @liotree.bridge)
(directory_entry leaf: (depth_mark) @liotree.leaf)
(file_entry bridge: (depth_mark) @liotree.bridge)
(file_entry leaf: (depth_mark) @liotree.leaf)
((directory_name) @liotree.directory @nospell)
((file_name) @liotree.file @nospell)
(root_bar) @liotree.bar
(entry_bar) @liotree.bar
(scope_delimiter_open) @punctuation.section.bracket.open
(scope_delimiter_closed) @punctuation.section.bracket.closed
