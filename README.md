# 📨 Notmuch.nvim

A powerful and flexible mail reader interface for NeoVim. This plugin bridges
your email and text editing experiences directly within NeoVim by interfacing
with the [Notmuch mail indexer](https://notmuchmail.org).

## Table of Contents

1. [Introduction](#introduction)
2. [Feature Overview](#feature-overview)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Usage](#usage)
6. [Configuration Options](#configuration-options)
7. [License](#license)

## Introduction

**Notmuch.nvim** is a NeoVim plugin that serves as a front-end for the Notmuch
mail indexer, enabling users to read, compose, and manage their emails from
within NeoVim. It facilitates a streamlined workflow for handling emails using
the familiar Vim interface and motions.

<!--
> [!IMPORTANT]
> This plugin requires NeoVim 0.5 or later to leverage its LuaJIT capabilities.
> You also need to have `telescope.nvim` for this plugin to work.
-->

## Feature Overview

- 📧 **Email Browsing**: Navigate emails with Vim-like movements.
- 🔍 **Search Your Email**: Leverage `notmuch` to search your email interactively.
- 🔗 **Thread Viewing**: Messages are loaded with folding and threading intact.
- 📎 **Attachment Management**: View, open and save attachments easily.
- ⬇️ **Offline Mail Sync**: Supports `mbsync` for efficient sync processes.
- 🔓 **Async Search**: Large mailboxes with thousands of email? No problem.
- 🏷️ **Tag Management**: Conveniently add, remove, or toggle email tags.
- 🔭 (WIP) ~~**Telescope.nvim Integration**: Search interactively, extract URL's, jump
  efficiently, with the powerful file picker of choice.~~

## Requirements

- **[NeoVim](https://github.com/neovim/neovim)**: Version 0.5 or later is
  required due to LuaJIT support.
- **[Notmuch](https://notmuchmail.org)**: Ensure Notmuch and libnotmuch library
  are installed
- (WIP) ~~**[Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)**: File
  picker of choice for many use cases.~~

## Installation

You can install Notmuch.nvim using your favorite NeoVim plugin manager.

#### Using `lazy.nvim`:
```lua
{
    'yousefakbar/notmuch.nvim',
    config = function()
        -- Configuration goes here
        local opts = {}
        require('notmuch').setup(opts)
    end,
}
```

#### Manual Installation:
Clone the repository and add the directory to your `runtimepath`:
```bash
git clone https://github.com/yousefakbar/notmuch.nvim.git
```

## Usage

Here are the core commands within Notmuch.nvim:

- **`:Notmuch`**: Lists available tags in your Notmuch database in a buffer.
  Setup key bindings for easy access. Example: 

  ```lua
  -- Define a keymap to run `:Notmuch` and launch the plugin landing page
  vim.keymap.set("n", "<leader>n", "<CMD>Notmuch<CR>")
  ```

- **`:NmSearch <query>`**: Executes an asynchronous search based on provided
  Notmuch query terms.

  ```vim
  " Loads the threads in your inbox received today
  :NmSearch tag:inbox and date:today
  ```

## Configuration Options

You can configure several global options to tailor the plugin's behavior:

| Option             | Description                              | Default       |
| :----------------- | :--------------------------------------: | :------------       |
| `notmuch_db_path`  | Directory containing the `.notmuch/` dir | `$HOME/Mail`        |
| `maildir_sync_cmd` | Bash command to run for syncing maildir  | `mbsync -a`         |
| `open_handler`         | Callback function for opening attachments     | By default runs `xdg-open`          |
| `view_handler`         | Callback function for converting attachments to text to view in vim buffer     | By default runs `view-handler`          |
| `keymaps`          | Configure any (WIP) command's keymap     | See `config.lua`[1] |

[1]: https://github.com/yousefakbar/notmuch.nvim/blob/main/lua/notmuch/config.lua

Example in plugin manager (lazy.nvim):

```lua
{
    "yousefakbar/notmuch.nvim",
    opts = {
        notmuch_db_path = "/home/xxx/Documents/Mail"
        maildir_sync_cmd = "mbsync personal"
        keymaps = {
            sendmail = "<C-g><C-g>",
        },
    },
},
```

Example `view-handler`:  
*make sure the `view-handler` is available in your PATH*

``` sh
#!/bin/sh

case "$1" in
  *.html ) cat "$1" | w3m -T "text/html" -dump | col ;;
  # *.pdf ) pdftohtml "$1" - | w3m -T "text/html" -dump | col ;;
  *.pdf ) mutool draw -F html -o - "$1" | w3m -T "text/html" -dump | col ;;
  *) echo "Unable to convert to text!" ;;
esac
```

## License

This project is licensed under the MIT License, granting you the freedom to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies. The
MIT License's full text can be found in the `LICENSE` section of the project's
documentation.

For more details on usage and advanced configuration options, please refer to
the in-depth plugin help within NeoVim: `:help notmuch`.
