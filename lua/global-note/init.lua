local preset = require("global-note.preset")
local utils = require("global-note.utils")
local loop = vim.loop

local M = {
  _inited = false,

  _default_preset_default_values = {
    filename = "global.md",
    ---@diagnostic disable-next-line: param-type-mismatch
    directory = utils.joinpath(vim.fn.stdpath("data"), "global-note"),
    title = "Global note",
    window_config = function()
      local window_height = vim.api.nvim_list_uis()[1].height
      local window_width = vim.api.nvim_list_uis()[1].width
      return {
        relative = "editor",
        border = "single",
        title = "Note",
        title_pos = "center",
        width = math.floor(0.7 * window_width),
        height = math.floor(0.85 * window_height),
        row = math.floor(0.05 * window_height),
        col = math.floor(0.15 * window_width),
      }
    end,
    post_open = function(_, _) end,
    autosave = true,
  },
}

---@class GlobalNote_UserPreset
---@field filename? string|fun(): string? Filename of the note.
---@field directory? string|fun(): string? Directory to keep notes.
---@field title? string|fun(): string? Floating window title.
---@field window_config? table|fun(): table A nvim_open_win config.
---@field post_open? fun(buffer_id: number, window_id: number) It's called after the window creation.
---@field autosave? boolean Whether to use autosave.

---@class GlobalNote_UserConfig: GlobalNote_UserPreset
---@field additional_presets? { [string]: GlobalNote_UserPreset }

local _default_preset = nil
local function get_default_preset()
  if _default_preset == nil then
    if not M._inited then
      M.setup()
    end

    local options = vim.deepcopy(M.options)

    options.additional_presets = nil
    options.name = ""

    _default_preset = preset.new(options)
  end
  return _default_preset
end

local _presets = nil
local function get_presets()
  if _presets == nil then
    if not M._inited then
      M.setup()
    end

    _presets = {}

    local disk_notes = {}

    local dir = M.options.directory

    if not loop.fs_stat(dir) then
      return _presets
    end

    local handle = loop.fs_scandir(dir)
    if handle then
      while true do
        local name, type = loop.fs_scandir_next(handle)
        if not name then
          break
        end
        if type == "file" then
          local base_name = vim.fn.fnamemodify(name, ":t:r")
          local is_global = (base_name .. ".md") == M.options.filename

          disk_notes[base_name] = {
            filename = base_name .. ".md",
            title = is_global and M.options.title or base_name,
          }
        end
      end
    else
      print("Failed to open directory: " .. dir)
    end

    local additional_presets =
      vim.tbl_deep_extend("force", {}, disk_notes, M.options.additional_presets)

    for key, value in pairs(additional_presets) do
      local preset_options =
        vim.tbl_extend("force", get_default_preset(), value)
      preset_options.name = key
      _presets[key] = preset.new(preset_options)
    end
  end
  return _presets
end

local cwd = loop.cwd()
local cwd_basename = vim.fn.fnamemodify(cwd, ":t:r")
local path_separator = package.config:sub(1, 1)
local local_dir = nil

local _local_presets = nil
local function get_local_presets()
  if _local_presets == nil then
    if not M._inited then
      M.setup()
    end

    _local_presets = {}
    local disk_notes = {}

    if not loop.fs_stat(local_dir) then
      return _local_presets
    end

    local handle = loop.fs_scandir(local_dir)
    if handle then
      while true do
        local name, type = loop.fs_scandir_next(handle)
        if not name then
          break
        end
        if type == "file" then
          local base_name = vim.fn.fnamemodify(name, ":t:r")

          disk_notes[base_name] = {
            filename = base_name .. ".md",
            title = base_name,
            directory = local_dir,
          }
        end
      end
    else
      print("Failed to open directory: " .. local_dir)
    end

    for key, value in pairs(disk_notes) do
      local preset_options =
        vim.tbl_extend("force", get_default_preset(), value)
      preset_options.name = key
      _local_presets[key] = preset.new(preset_options)
    end
  end
  return _local_presets
end

---@param options? GlobalNote_UserConfig
M.setup = function(options)
  local user_options = vim.deepcopy(options or {})
  user_options.additional_presets = user_options.additional_presets or {}

  M.options =
    vim.tbl_extend("force", M._default_preset_default_values, user_options)

  local_dir = M.options.directory .. path_separator .. cwd_basename

  vim.api.nvim_create_user_command("GlobalNote", function(opts)
    local note_name = opts.fargs[1] or ""
    local scope = opts.fargs[2] or "global"
    local local_scope = scope == "local"

    M.toggle_note(note_name, local_scope)
  end, {
    nargs = "*",
    desc = "Toggle global note",
  })

  vim.api.nvim_create_user_command("GlobalNoteCreate", function(opts)
    local is_local = opts.args == "local"
    M.create_note({ local_scope = is_local })
  end, {
    nargs = "?",
    desc = "Create new note",
    complete = function(arglead, cmdline, cursorpos)
      return { "local", "global" }
    end,
  })

  vim.api.nvim_create_user_command("GlobalNotePick", function(opts)
    local is_local = opts.args == "local"
    M.pick_note({ local_scope = is_local })
  end, {
    nargs = "?",
    desc = "Create new note",
    complete = function(arglead, cmdline, cursorpos)
      return { "local", "global" }
    end,
  })

  M._inited = true
end

---Opens or closes a note in a floating window.
---@param preset_name? string preset to use. If it's not set, use default preset.
---@param local_scope? boolean whether to use local scope.
M.toggle_note = function(preset_name, local_scope)
  local p = get_default_preset()
  if preset_name ~= nil and preset_name ~= "" then
    p = (local_scope and get_local_presets() or get_presets())[preset_name]
    if p == nil then
      local template = "The preset with the name %s doesn't exist"
      local message = string.format(template, preset_name)
      vim.notify(message, vim.log.levels.WARN)
    end
  end

  p:toggle()
end

---Creates a new note.
---@param opts? table # A table with a key 'local_scope' set to true if the note should be local.
M.create_note = function(opts)
  local local_scope = opts ~= nil and opts.local_scope

  local name = vim.fn.input("Note name: ")

  if name == "" then
    return
  end

  local dir = local_scope and local_dir or M.options.directory

  if not loop.fs_stat(dir) then
    loop.fs_mkdir(dir, 493)
  end

  local destination = dir .. name .. ".md"

  if loop.fs_stat(destination) then
    local template = "Another note with the name %s already exists"
    local message = string.format(template, name)
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  local preset_options = vim.tbl_extend("force", get_default_preset(), {
    filename = name .. ".md",
    title = name,
    directory = dir,
  })
  preset_options.name = name

  if local_scope then
    get_local_presets()[name] = preset.new(preset_options)
  else
    get_presets()[name] = preset.new(preset_options)
  end

  M.toggle_note(name, local_scope)
end

---Picks a note to open.
---@param opts? table # A table with a key 'local_scope' set to true if the note should be local.
M.pick_note = function(opts)
  local local_scope = opts ~= nil and opts.local_scope
  local presets = local_scope and get_local_presets() or get_presets()
  local items = {}

  for key, _ in pairs(presets) do
    table.insert(items, key)
  end

  vim.ui.select(items, {
    prompt = "Pick a note",
    format_item = function(item)
      return presets[item].title or item
    end,
  }, function(item)
    if item then
      M.toggle_note(item, local_scope)
    end
  end)
end

return M
