# Global-note.nvim

It's a simple Neovim plugin that provides a global note in a float window.
It could also provide other global, project local, file local notes (if it's required).

![global-note](https://github.com/backdround/global-note.nvim/assets/17349169/0981e267-aa95-407e-bc6d-a23aee9ecac5)

### Simple configuration

```lua
local global_note = require("global-note")
global_note.setup()

vim.keymap.set("n", "<leader>n", global_note.toggle_note, {
  desc = "Toggle global note",
})
```

### Options

<details><summary>click</summary>
All options here are default:

```lua
{
  -- Filename to use for default note (preset).
  -- string or fun(): string
  filename = "global.md",

  -- Directory to keep default note (preset).
  -- string or fun(): string
  directory = vim.fn.stdpath("data") .. "/global-note/",

  -- Floating window title.
  -- string or fun(): string
  title = "Global note",

  -- A nvim_open_win config to show float window.
  -- table or fun(): table
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

  -- It's called after the window creation.
  -- fun(buffer_id: number, window_id: number)
  post_open = function(_, _) end,

  -- Whether to use autosave. Autosave saves buffer on closing window
  -- or exiting Neovim.
  -- boolean
  autosave = true,

  -- Additional presets to create other global, project local, file local
  -- and other notes.
  -- { [name]: table } - tables there have the same fields as the current table.
  additional_presets = {},
}
```

</details>

<!-- panvimdoc-ignore-start -->

---

<!-- panvimdoc-ignore-end -->

### Additional presets

You can use additional presets to have other global notes, project
local notes, file local notes or anything you can come up with.

A preset is a list of options that can be used during opening a note.
All additional presets inherit `default` preset. `default` preset is a
list of options that are in the setup's root).

Simple example:

```lua
require("global-note").setup({
  filename = "global.md",
  directory = "~/notes/",

  additional_presets = {
    projects = {
      filename = "projects-to-do.md",
      title = "List of projects",
      -- All not specified options are used from the root.
    },

    food = {
      filename = "want-to-eat.md",
      title = "List of food",
      -- All not specified options are used from the root.
    },
  },
})

-- Functions to toggle notes:
require("global-note").toggle_note()
require("global-note").toggle_note("projects")
require("global-note").toggle_note("food")

-- Commands to toggle notes (they are generated field name):
-- :GlobalNote -- default global note
-- :GlobalNote projects
-- :GlobalNote food

-- Command to pick a note:
-- :GlobalNotePick
```

### Dynamically managing notes with scopes

A note can have a **global** or project **local** scope, and can be created dynamically without having to predefine them.

A local note is a note that is specific to a project. And they are stored as `<global-note-directory>/<project_name>/<note_name>.md`.

#### Create note

To create a note, use the following function:

```lua
require('global-note').create_note(opts)
```

`opts?`: table, with the following fields:

- `local_scope?: boolean` if true, create a local note, otherwise, create a global note

<details><summary>Examples</summary>

```lua
-- create a global note
require('global-note').create_note()
--or
require('global-note').create_note({local_scope=false})

-- create a local note
require('global-note').create_note({local_scope=true})
```

</details>

#### Toggle note

To open a note, use the following function:

```lua
require('global-note').toggle_note(preset_name, local_scope)
```

`preset_name?: string` if not provided, open the default global note

`local_scope?: boolean` if true, look for a local note with name `<preset_name>`, otherwise, look for a global note with name `<preset_name>`

<details><summary>Examples</summary>

```lua
-- toggle the default global note
require('global-note').toggle_note()

-- toggle the global note `projects`
require('global-note').toggle_note('projects')
--or
require('global-note').toggle_note('projects', {local_scope=false})

-- toggle the local note `projects`
require('global-note').toggle_note('projects', {local_scope=true})
```

</details>

#### Pick note

To pick a note, use the following function:

```lua
require('global-note').pick_note(opts)
```

`opts?`: table, with the following fields:

- `local_scope: boolean` if true, pick a local note, otherwise, pick a global note

<details><summary>Examples</summary>

```lua
-- pick a global note
require('global-note').pick_note()
--or
require('global-note').pick_note({local_scope=false})

-- pick a local note
require('global-note').pick_note({local_scope=true})
```

</details>

#### Commands

`:GlobalNoteCreate <scope>`: create a note, `<scope>` is optional, if it is `local`, create a local note, otherwise global note

<details><summary>Examples</summary>

```lua
-- create a global note
-- :GlobalNoteCreate
-- or
-- :GlobalNoteCreate global

-- create a local note
-- :GlobalNoteCreate local
```

</details>

`:GlobalNote <preset_name> <scope>`: open global note, if `<preset_name>` is not provided, open the default global note, otherwise, open the note with name `<preset_name>` and the given scope

<details><summary>Examples</summary>

```lua
-- open the default global note
-- :GlobalNote
-- or
-- :GlobalNote global

-- open the global note `projects`
-- :GlobalNote projects
-- or
-- :GlobalNote projects global

-- open the local note `projects`
-- :GlobalNote projects local
```

</details>

`:GlobalNotePick <scope>`: pick a note to open, `<scope>` is optional, if it is `local`, select a local note, otherwise global note

<details><summary>Examples</summary>

```lua
-- pick a global note
-- :GlobalNotePick
-- or
-- :GlobalNotePick global

-- pick a local note
-- :GlobalNotePick local
```

</details>

<!-- panvimdoc-ignore-start -->

---

<!-- panvimdoc-ignore-end -->

### Configuration usecases

:warning: **Usecases require some functions from below!**

<details><summary>Project local notes</summary>

```lua
local global_note = require("global-note")
global_note.setup({
  additional_presets = {
    project_local = {

      filename = function()
        return get_project_name() .. ".md"
      end,

      title = "Project note",
    },
  }
})

vim.keymap.set("n", "<leader>n", function()
  global_note.toggle_note("project_local")
end, {
  desc = "Toggle project note",
})
```

</details>

<details><summary>Git branch local notes</summary>

```lua
local global_note = require("global-note")
global_note.setup({
  additional_presets = {
    git_branch_local = {
      directory = function()
        return vim.fn.stdpath("data") .. "/global-note/" .. get_project_name()
      end,

      filename = function()
        local git_branch = get_git_branch()
        if git_branch == nil then
          return nil
        end
        return get_git_branch():gsub("[^%w-]", "-") .. ".md"
      end,

      title = get_git_branch,
    },
  }
})

vim.keymap.set("n", "<leader>n", function()
  global_note.toggle_note("git_branch_local")
end, {
  desc = "Toggle git branch note",
})
```

</details>

<!-- panvimdoc-ignore-start -->

---

<!-- panvimdoc-ignore-end -->

Functions for usecases above!:

<details><summary>get_project_name() by cwd</summary>

```lua
local get_project_name = function()
  local project_directory, err = vim.loop.cwd()
  if project_directory == nil then
    vim.notify(err, vim.log.levels.WARN)
    return nil
  end

  local project_name = vim.fs.basename(project_directory)
  if project_name == nil then
    vim.notify("Unable to get the project name", vim.log.levels.WARN)
    return nil
  end

  return project_name
end
```

</details>

<details><summary>get_project_name() by git</summary>

```lua
local get_project_name = function()
  local result = vim.system({
    "git",
    "rev-parse",
    "--show-toplevel",
  }, {
    text = true,
  }):wait()

  if result.stderr ~= "" then
    vim.notify(result.stderr, vim.log.levels.WARN)
    return nil
  end

  local project_directory = result.stdout:gsub("\n", "")

  local project_name = vim.fs.basename(project_directory)
  if project_name == nil then
    vim.notify("Unable to get the project name", vim.log.levels.WARN)
    return nil
  end

  return project_name
end
```

</details>

<details><summary>get_git_branch()</summary>

```lua
local get_project_name = function()
  local result = vim.system({
    "git",
    "symbolic-ref",
    "--short",
    "HEAD",
  }, {
    text = true,
  }):wait()

  if result.stderr ~= "" then
    vim.notify(result.stderr, vim.log.levels.WARN)
    return nil
  end

  return result.stdout:gsub("\n", "")
end
```

</details>
