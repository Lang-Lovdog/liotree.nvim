local parser   = require("liotree.parser")
local decor    = require("liotree.decor")
local summoner = require("liotree.summoner")
local executer = require("liotree.executer")

local M = {}

M.picker = "telescope"
-- Pattern list of files where the liotree should be concealed
M.liotree_affected_colorschemes = {}
-- [0] No, [1] Yes
M.open_non_existent_file = 1
-- [0] No, [1] Ask, [2] Yes
M.create_non_existent_dir = 1

local highlights   = {
  comments   = { fg="#66ddee",             italic=true , force=false,                },
  dirname    = { fg="#ffdd88", bold=true ,               force=true ,                },
  filename   = { fg="#ffffbb",                           force=true ,                },
  pipebar    = { fg="#00dd44",             italic=false, force=true ,                },
  branchend  = { fg="#00dd44", bold=true , italic=false, force=true ,                },
  branch     = { fg="#00dd44",             italic=false, force=true ,                },
  opendir    = { fg="#fb0bdb", bold=true , italic=false, force=true ,                },
  closedir   = { fg="#f72cf7", bold=false, italic=false, force=true ,                },
  error      = { fg="#ff4466", bold=true , italic=false, force=true , bg="#ffffff"   },
  conceal    = {
    opendir         = { fg="#88ff00", bold=true , italic=false, force=true ,                },
    closedir        = { fg="#00ff88", bold=true ,               force=true ,                },
    rootsymbol      = { fg="#ffffff",                                                       },
    entry           = { fg="#00dd44",                                                       },
    commentpipe     = { fg="#00dd44",                                                       },
    line            = { fg="#00dd44",                                                       },
    pipebar         = { fg="#00dd44",                                                       },
    dirsymbol       = { fg="#eeaa77",                                                       },
    filesymbol      = { fg="#aabb00",                                                       },
    opencomment     = {                                                                     },
    closecomment    = {                                                                     },
    formatspace     = { bg="#ffff00",                                                       },
    dirlimitname    = { fg="#bb88bb", bold=false, italic=true ,                             },
    dirlimiterror   = { fg="#ff4488", bold=false, italic=true ,       bg="#ffffff"          },
  
  }
}

M.keymaps = {
    ["<CR>"       ] = "openit"             ,
    ["<leader>lmk"] = "set_mark_copy_ref"   ,
    ["<leader>lmc"] = "clear_mark_copy_ref" ,
    ["<leader>lcp"] = "copy_path"           ,
    ["<leader>lx" ] = "execute"             ,
}

M.global_keymaps = {
    ["<leader>lt"] = "liotree_summon"      ,
}

M.functions = {
    ["LiotreeOpen"              ] = "openit"              ,
    ["LiotreeSetCopyReference"  ] = "set_mark_copy_ref"   ,
    ["LiotreeClearCopyReference"] = "clear_mark_copy_ref" ,
    ["LiotreeCopyPath"          ] = "copy_path"           ,
    ["LiotreeExecute"           ] = "execute"             ,
}

M.global_functions = {
    ["LiotreeSummon"] = "liotree_summon"      ,
}

M.executers = {
    ["Makefile"] = "cd __path__ && make __select__"  ,
    ["%.plt$"]   = "cd __path__ && gnuplot __this__" ,
}
M.select_methods = {
    ["Makefile"] = "make_targets",
}


local function set_comands()
    for k, v in pairs(M.functions) do
        if parser[v] ~= nil then
            vim.api.nvim_create_user_command(k, parser[v], {})
        elseif summoner[v] ~= nil then
            vim.api.nvim_create_user_command(k, summoner[v], {})
        end
    end
    for k, v in pairs(M.global_functions) do
        if parser[v] ~= nil then
            vim.api.nvim_create_user_command(k, parser[v], {})
        elseif summoner[v] ~= nil then
            vim.api.nvim_create_user_command(k, summoner[v], {})
        end
    end
end

local function set_filetype_stuff()
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "liotree",
        callback = function()
            for k, v in pairs(M.keymaps) do
                if parser[v] then
                    vim.keymap.set("n", k, parser[v], { buffer = true, silent = true })
                end
            end
        end,
    })

    vim.filetype.add({
        extension = {
            liotree = "liotree",
        },
    })

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "liotree",
        callback = function()
            vim.treesitter.start()
        end,
    })

    vim.api.nvim_create_autocmd("BufNewFile", {
        pattern = "*.liotree",
        command = "set filetype=liotree",
    })

    vim.api.nvim_create_autocmd("BufRead", {
        pattern = "*.liotree",
        command = "set filetype=liotree",
    })
end


M.setup = function(opts)

  local highlight_colorschemes = { "lovdog*", "lang*", "*" }

  set_filetype_stuff()

  if opts == nil then opts = {} end
  for k, v in pairs(opts) do
    M[k] = v
  end

  parser.set_conf({
      open_non_existent_file = M.open_non_existent_file,
      create_non_existent_dir = M.create_non_existent_dir,
  })

  executer.setup(M.executers, M.select_methods)

  for k, v in pairs(M.global_keymaps) do
      if parser[v] then
          vim.keymap.set("n", k, parser[v], { silent = true })
      elseif summoner[v] then
          vim.keymap.set("n", k, summoner[v], { silent = true })
      end
  end

  set_comands()
  vim.list_extend(highlight_colorschemes, M.liotree_affected_colorschemes)
  decor.set_colors(highlights, highlight_files)
end



return M
