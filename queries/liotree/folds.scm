(directory_entry
  (content_block) @fold)

(directory_entry
  (scope_delimiter_open) @fold
  (content_block) @fold
  (scope_delimiter_closed) @fold)

(directory_entry
  (directory_name) @fold
  (scope_delimiter_open) @fold
  (content_block) @fold
  (scope_delimiter_closed) @fold)

((comment_content) @fold)

(root
  (directory_name) @fold
  (content_block) @fold)
