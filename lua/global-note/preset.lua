local utils = require("global-note.utils")

---@class GlobalNote_PresetOptions
---@field filename string|fun(): string Filename of the note.
---@field directory string|fun(): string Directory to keep notes.
---@field title string|fun(): string Floating window title.
---@field command_name? string Ex command name.
---@field window_config table|fun(): table A nvim_open_win config.
---@field post_open fun() It's called after the window creation.
---@field autosave boolean Whether to use autosave.

---@class GlobalNote_ExpandedPreset
---@field filename string Filename of the note.
---@field directory string Directory to keep notes.
---@field window_config table A nvim_open_win config.
---@field post_open function It's called after the window creation.
---@field autosave boolean Whether to use autosave.

---@class GlobalNote_Preset: GlobalNote_PresetOptions

---Creates a new preset from data.
---@param name? string
---@param options GlobalNote_PresetOptions
---@return GlobalNote_Preset
local new = function(name, options)
  vim.validate({
    ["options.filename"] = {
      options.filename,
      { "string", "function" },
    },
    ["options.directory"] = {
      options.directory,
      { "string", "function" },
    },
    ["options.title"] = {
      options.title,
      { "string", "function" },
    },
    ["options.command_name"] = {
      options.command_name,
      { "string", "nil" },
    },
    ["options.window_config"] = {
      options.window_config,
      { "table", "function" },
    },
    ["options.post_open"] = {
      options.post_open,
      { "function" },
    },
    ["options.autosave"] = {
      options.autosave,
      { "boolean" },
    },
  })

  ---@class GlobalNote_Preset
  local p = vim.deepcopy(options)

  if type(p.command_name) == "string" and p.command_name ~= "" then
    local desc = "Open note in a floating window"
    if name ~= nil then
      desc = string.format("Open %s note in a floating window", name)
    end

    vim.api.nvim_create_user_command(p.command_name, function()
      p:open()
    end, {
      nargs = 0,
      desc = desc
    })
  end

  ---Expands preset fields to a finite values.
  ---@return GlobalNote_ExpandedPreset
  function p:_expand_options()
    local filename = self.filename
    if type(filename) == "function" then
      filename = filename()
      if type(filename) ~= "string" or filename == "" then
        error("Filename function should return a non empty string")
      end
    end

    local directory = self.directory
    if type(directory) == "function" then
      directory = directory()
      if type(directory) ~= "string" or directory == "" then
        error("Directory function should return a non empty string")
      end
    end
    directory = vim.fn.expand(directory)

    local window_config = self.window_config
    if type(window_config) == "function" then
      window_config = window_config()
      if type(window_config) ~= "table" then
        error("Window_config should return a table")
      end
    end

    local title = self.title
    if type(title) == "function" then
      title = title()
      if type(title) ~= "string" and title ~= nil then
        error("Title function should return a string or a nil")
      end
    end

    if title ~= nil then
      window_config.title = title
    end

    return {
      filename = filename,
      directory = directory,
      window_config = window_config,
      post_open = self.post_open,
      autosave = self.autosave,
    }
  end

  ---Expands a preset.
  ---@param expanded_preset GlobalNote_ExpandedPreset
  function p:_open_in_float_window(expanded_preset)
    local filepath =
      vim.fs.joinpath(expanded_preset.directory, expanded_preset.filename)
    utils.ensure_directory_exists(expanded_preset.directory)
    utils.ensure_file_exists(filepath)

    local buffer_id = vim.fn.bufadd(filepath)
    if buffer_id == nil then
      error("Unreachable: The file should exist, but it doesn't: " .. filepath)
    end

    vim.api.nvim_open_win(buffer_id, true, expanded_preset.window_config)

    if expanded_preset.autosave then
      vim.api.nvim_create_autocmd({ "BufWinLeave", "ExitPre" }, {
        callback = function(event)
          if event.buf ~= buffer_id then
            return
          end
          if vim.bo[buffer_id].modified then
            vim.cmd.write({ mods = { silent = true } })
          end
          return true
        end,
      })
    end

    expanded_preset.post_open()
  end

  ---Opens the preset in a floating window
  function p:open()
    local expanded_preset = self:_expand_options()
    self:_open_in_float_window(expanded_preset)
  end

  return p
end

return {
  new = new,
}