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

> [!IMPORTANT]
> This plugin requires NeoVim 0.5 or later to leverage its LuaJIT capabilities.
> You also need to have `telescope.nvim` for this plugin to work.

## Feature Overview

- 📧 **Email Browsing**: Navigate emails with Vim-like movements.
- 🔍 **Search Your Email**: Leverage `notmuch` to search your email interactively.
- 🔗 **Thread Viewing**: Messages are loaded with folding and threading intact.
- 📎 **Attachment Management**: View and save attachments easily.
- ⬇️ **Offline Mail Sync**: Supports `mbsync` for efficient sync processes.
- 🔓 **Async Search**: Large mailboxes with thousands of email? No problem.
- 🏷️ **Tag Management**: Conveniently add, remove, or toggle email tags.
- 🔭 **Telescope.nvim Integration**: Search interactively, extract URL's, jump
  efficiently, with the powerful file picker of choice.

## Requirements

- **[NeoVim](https://github.com/neovim/neovim)**: Version 0.5 or later is
  required due to LuaJIT support.
- **[Notmuch](https://notmuchmail.org)**: Ensure Notmuch and libnotmuch library
  are installed
- **[Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)**: File
  picker of choice for many use cases.

## Installation

You can install Notmuch.nvim using your favorite NeoVim plugin manager.

#### Using `lazy.nvim`:
```lua
{
    'yousefakbar/notmuch.nvim',
    config = function()
        -- Configuration goes here
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

<!-- TODO: Convert this to a table -->

You can configure several global options to tailor the plugin's behavior:

- `g:NotmuchDBPath` (default `'$HOME/Mail'`): Path to your Notmuch database.
  
- `g:NotmuchMaildirSyncCmd` (default `mbsync -c $XDG_CONFIG_HOME/isync/mbsyncrc -a`): Customize this command for mail synchronization with remote servers.
  
- `g:NotmuchOpenCmd` : Define a command to open email attachments, with
  OS-specific defaults set initially to `open(1)` on macOS and `xdg_open(1)`
  otherwise.

## License

This project is licensed under the MIT License, granting you the freedom to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies. The
MIT License's full text can be found in the `LICENSE` section of the project's
documentation.

For more details on usage and advanced configuration options, please refer to
the in-depth plugin help within NeoVim: `:help notmuch`.
