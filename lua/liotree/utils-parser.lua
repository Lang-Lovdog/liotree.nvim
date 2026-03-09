local M = {}

M.path_relative_to = function(from_dir, to_path)
    -- from_dir and to_path are absolute paths
    -- Returns a relative path from from_dir to to_path
    local function split(p)
        local parts = {}
        for part in p:gsub("/$", ""):gmatch("[^/]+") do
            table.insert(parts, part)
        end
        return parts
    end

    local from_parts = split(from_dir)
    local to_parts = split(to_path)

    -- Find common prefix length
    local i = 1
    while from_parts[i] and to_parts[i] and from_parts[i] == to_parts[i] do
        i = i + 1
    end

    -- Add ".." for each remaining part in from_dir
    local result_parts = {}
    for _ = i, #from_parts do
        table.insert(result_parts, "..")
    end
    -- Add remaining parts from to_path
    for j = i, #to_parts do
        table.insert(result_parts, to_parts[j])
    end

    if #result_parts == 0 then
        return "."
    end
    return table.concat(result_parts, "/")
end

return M
