local a = {}
local u = require('notmuch.util')
local v = vim.api

local config = require('notmuch.config')

local function show_github_patch(link)
  local buf = v.nvim_create_buf(true, true)
  v.nvim_buf_set_name(buf, link)
  v.nvim_win_set_buf(0, buf)
  v.nvim_command("silent 0read! curl -Ls " .. link)
  v.nvim_win_set_cursor(0, { 1, 0})
  v.nvim_buf_set_lines(buf, -2, -1, true, {})
  vim.bo.filetype = "gitsendemail"
  vim.bo.modifiable = false
end

-- TODO generalize this: <dontcare>/<extension part
a.open_attachment_part = function()
  local f = a.save_attachment_part('/tmp')
  -- os.execute(config.options.open_handler .. ' ' .. f)
  config.options.open_handler({path = f})
end

a.view_attachment_part = function()
  local f = a.save_attachment_part('/tmp')
  -- local output = vim.fn.system({config.options.view_handler, f})
  local output = config.options.view_handler({path = f})

  local lines = u.split(output, "[^\r\n]+")

  local buf = v.nvim_create_buf(true, true)


  -- calculate the position to center the window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
      border = "rounded",
      relative = "editor",
      style = "minimal",
      height = height,
      width = width,
      row = row,
      col = col,
  })

  v.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(win, false) end, { buffer = buf })
end

-- TODO generalize this: <dontcare>/<extension part
a.save_attachment_part = function(savedir)
  if savedir then dir = savedir else dir = '.' end
  local n = v.nvim_win_get_cursor(0)[1]
  local l = vim.fn.getline(n)
  local id = string.match(v.nvim_buf_get_name(0), 'id:%C+')
  local ext = string.match(l, '%w+/(%w+)')
  if ext == 'plain' then ext = 'txt' end
  local f = dir .. '/notmuch.' .. ext
  os.execute('notmuch show --exclude=false --part=' .. n .. ' ' .. id .. '>' .. f)
  print('Saved to: ' .. f)
  return f
end

a.get_attachments_from_cursor_msg = function()
  local id = u.find_cursor_msg_id()
  if id == nil then return end
  local bufnr = vim.fn.bufnr('id:' .. id)
  if id == nil then return nil end
  if bufnr ~= -1 then
    print('Attachment list for this msg is already open in buffer: ' .. bufnr)
    return nil
  end
  v.nvim_command('belowright 8new')
  v.nvim_buf_set_name(0, 'id:' .. id)
  vim.bo.buftype = "nofile"
  v.nvim_command('silent 0read! notmuch show --part=0 --exclude=false id:' .. id .. ' | grep -E "^Content-[Tt]ype:"')
  v.nvim_win_set_cursor(0, { 1, 0 })
  v.nvim_buf_set_lines(0, -2, -1, true, {})
  vim.bo.filetype="notmuch-attach"
  vim.bo.modifiable = false
end

a.get_urls_from_cursor_msg = function()
  if vim.fn.exists(':YTerm') == 0 then
    print("Can't launch URL selector (:YTerm command not found)")
    return nil
  end
  local id = u.find_cursor_msg_id()
  if id == nil then return nil end
  v.nvim_command('YTerm "notmuch show id:' .. id .. ' | urlextract"')
end

a.follow_github_patch = function(line)
  -- https://github.com/neomutt/neomutt/pull/2774.patch
  local link = string.match(line, 'http[s]://github%.com/.+/.+/pull/%d+%.patch')
  if link == nil then
    return nil
  end
  local bufno = vim.fn.bufnr(link)
  if bufno ~= -1 then
    v.nvim_win_set_buf(0, bufno)
  else
    show_github_patch(link)
  end
end

return a

-- vim: tabstop=2:shiftwidth=2:expandtab:foldmethod=indent
