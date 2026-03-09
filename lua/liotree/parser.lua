local lio_picker = require("liotree.picker").lio_picker
local copy_mode = false
local copy_relative_mark = false
local copy_reference = nil
local copy_base_dir = nil
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.liotree = {
  install_info = {
    url = "https://github.com/yourusername/tree-sitter-liotree",
    files = {"src/parser.c"},
    branch = "main",
  },
  filetype = "liotree",
}


local M = {}
M.conf = {
    create_non_existent_dir = 1,
    open_non_existent_file  = 1
}
M.set_conf = function(conf)
    if conf == nil then conf = {} end
    for k, v in pairs(conf) do
        M.conf[k] = v
    end
end




M.opener = function ()
    local ok, node = pcall(vim.treesitter.get_node)
    if not ok or not node then return end

    local current = node
    while current and not (current:type() == "file_entry" or current:type() == "directory_entry") do
        current = current:parent()
    end
    if not current then
        no_copy()
        no_copy_mark()
        return
    end

    local recovered_path = liotree_recover_path(current)

    resolve_step(
        recovered_path.buffer_dir,
        recovered_path.path_parts,
        recovered_path.type
    )
end

M.copy_path = function()
    copy_base_dir = vim.fn.expand("%:p:h")
    si_copy()
    M.opener()
    no_copy()
end

M.set_mark_copy_ref= function()
    copy_base_dir = vim.fn.expand("%:p:h")
    si_copy_mark()
    M.opener()
    no_copy_mark()
end

M.clear_mark_copy_ref = function()
    copy_reference = nil
end

local function liotree_recover_path(current)
    -- Buscar a qué elemento corresponde el cursor
    while current and not (current:type() == "file_entry" or current:type() == "directory_entry") do
        current = current:parent()
    end
    -- Si el cursor no corresponde a un directorio o un archivo, no hacemos nada
    if not current then return end

    local output = {}

    output.type = current:type()

    -- Recuperación de la dirección respecto a la raíz
    -- Se trepará elemento a elemento el árbol hasta llegar a la carpeta raíz
    local path_parts = {}
    local path_walker = current
    while path_walker do
        if path_walker:type() == "directory_entry" or path_walker:type() == "file_entry" then
            local name_nodes = path_walker:field("name")
            if name_nodes and #name_nodes > 0 then
                local text = vim.treesitter.get_node_text(name_nodes[1], 0)
                
                -- CLEANING: Strip trailing slashes and the ;pattern; markers
                text = text:gsub("/%s*$", ""):gsub("^%s*(.-)%s*$", "%1")
                
                table.insert(path_parts, 1, text)
            end
        end
        path_walker = path_walker:parent()
    end

    output.relative_path = table.concat(path_parts, "/")
    output.path_parts    = path_parts
    output.buffer_dir    = vim.fn.expand("%:p:h")

    return output
end


local function resolve_step(current_base, remaining_parts, type)
  -- 1. Grab the next part of the path
  local next_segment = table.remove(remaining_parts, 1)
  if not next_segment then return end -- Safety break


  if is_pattern(next_segment) then
      local matches = pattern_handler(next_segment, current_base)

      if #matches == 0 then
          print("No matches for: " .. next_segment)
      else
          handle_regex_element(matches, next_segment, remaining_parts, type)
      end
  else
      -- It's a literal, just M.proceed
      local target = current_base .. "/" .. next_segment
      proceed(target, remaining_parts, type)
  end
end



local function proceed(resolved_path, remaining_parts, type)
  if #remaining_parts ~= 0 then
      resolve_step(resolved_path, remaining_parts, type)
      return
  end
  if copy_mode then
      do_copy(resolved_path)
      no_copy()
      return
  end
  if copy_relative_mark then
      if copy_relative_mark then
          if type == "directory_entry" then
              copy_reference = resolved_path
          else -- file_entry
              copy_reference = vim.fn.fnamemodify(resolved_path, ":h")
          end
          print("Marked reference: " .. copy_reference)
          no_copy_mark()
          return
      end
  end
  if type == "directory_entry" then
      handle_directory(resolved_path)
      return
  end
  if type == "file_entry" then
      handle_file(resolved_path, remaining_parts, type)
      return
  end
end



local function is_pattern(segment)
    return segment:match("^;.*;$") ~= nil
end


local function pattern_handler(pattern_name, current_base)
    local elements = {}
    -- Remove semicolons
    local inner = pattern_name:gsub("^;", ""):gsub(";$", "")
    -- Expand any [a|b|c] constructs
    local expanded_patterns = permutable_pattern_expand(inner)
    for _, pat in ipairs(expanded_patterns) do
        -- pat may contain wildcards like * – vim.fn.glob handles them
        local matches = vim.fn.glob(current_base .. "/" .. pat, false, true)
        vim.list_extend(elements, matches)
    end
    return elements
end

local function permutable_pattern_expand(pattern_name)
    local results = { pattern_name }
    while true do
        local new_results = {}
        local expanded = false
        for _, s in ipairs(results) do
            local start, finish, content = s:find("%[(.-)%]")
            if start then
                expanded = true
                for choice in content:gmatch("([^|]+)") do
                    table.insert(new_results, s:sub(1, start-1) .. choice .. s:sub(finish+1))
                end
            else
                table.insert(new_results, s)
            end
        end
        results = new_results
        if not expanded then break end
    end
    return results
end


local function handle_directory(path)
  if vim.fn.isdirectory(path) == 1 then
      local matches = vim.fn.glob(path .. "/*", false, true)
      if #matches > 0 then
          lio_picker(matches, "Select File:", function(choice)
              if choice then 
                  if vim.fn.isdirectory(choice) == 1 then
                      handle_directory(choice)
                  else
                      handle_file(choice)
                  end
              end
          end)
      else
          print("Directory is empty: " .. path)
      end
  else
      local policy = conf.create_non_existent_dir or 1
      if policy == 0 then
          print("Directory does not exist: " .. path)
      elseif policy == 2 then
          vim.fn.mkdir(path, "p")
          print("Created directory: " .. path)
      elseif policy == 1 then
          local confirm = vim.fn.confirm("Directory does not exist. Create it?", "&Yes\n&No", 2)
          if confirm == 1 then
              vim.fn.mkdir(path, "p")
              print("Created directory: " .. path)
          end
      end
  end
end


local function handle_file(path)
  local open_non_existent = conf.open_non_existent_file or 1
  if open_non_existent == 0 then
      print("File does not exist: " .. path)
      return
  end
  vim.cmd.edit(path)
end

local function handle_regex_element(matches, element, remaining_parts, type)
  if #matches == 0 then
      print("No matches for: " .. element)
  else
      -- Trigger picker for the folder/file match
      local prompt = (#remaining_parts == 0) and "Select Final Match:" or "Select Path Segment:"
      lio_picker(matches, prompt, function(choice)
          if choice then proceed(choice, remaining_parts, type) end
      end)
  end
end



local function si_copy() copy_mode = true  end
local function no_copy() copy_mode = false end
local function si_copy_mark() copy_relative_mark = true end
local function no_copy_mark() copy_relative_mark = false end

local function do_copy(absolute_path)
    local result
    if copy_reference then
        -- Relative to the marked directory
        result = vim.fn.fnamemodify(absolute_path, ":~:" .. copy_reference)
    else
        -- Relative to the liotree file's directory
        result = vim.fn.fnamemodify(absolute_path, ":~:" .. copy_base_dir)
    end
    vim.fn.setreg('+', result)
    print("Copied: " .. result)
end





 return M
