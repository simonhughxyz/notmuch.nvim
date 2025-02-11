local s = {}
local u = require('notmuch.util')
local v = vim.api

local config = require('notmuch.config')

-- Prompt confirmation for sending an email
--
-- This function utilizes vim's builtin `confirm()` to prompt the user and
-- confirm the action of sending an email. This is applicable for sending newly
-- composed mails or replies by passing the mail file path.
--
-- @param filename string: path to the email message you would like to send
--
-- @usage
--   -- See reply() or compose()
--   vim.keymap.set('n', '<C-c><C-c>', function()
--     confirm_sendmail(reply_filename)
--   end, { buffer = true })
local confirm_sendmail = function(filename)
  local choice = v.nvim_call_function('confirm', {
    'Send email?',
    '&Yes\n&No',
    2 -- Default to no
  })

  if choice == 1 then
    vim.cmd.write()
    s.sendmail(filename)
  end
end

-- Send a completed message
--
-- This function takes a file containing a completed message and send it to the
-- recipient(s) using `msmtp`. Typically you will invoke this function after
-- confirming from a reply or newly composed email message
--
-- @param filename string: path to the email message you would like to send
--
-- @usage
--   require('notmuch.send').sendmail('/tmp/my_new_email.eml')
s.sendmail = function(filename)
  os.execute('msmtp -t <' .. filename)
  print('Successfully sent email: ' .. filename)
end

-- Reply to an email message
--
-- This function uses `notmuch reply` to generate and prepare a reply draft to a
-- message by scanning for the `id` of the message you want to reply to. The
-- draft file will be stored in `tmp/` and a keymap (default `<C-c><C-c>`) to
-- allow sending directly from within nvim
--
-- @usage
--   -- Typically you would just press `R` on a message in a thread
--   require('notmuch.send').reply()
s.reply = function()
  -- Get msg id of the mail to be replied to
  local id = u.find_cursor_msg_id()
  if not id then return end

  -- Create new draft mail to hold reply
  local reply_filename = '/tmp/reply-' .. id .. '.eml'

  -- Create and edit buffer containing reply file
  local buf = v.nvim_create_buf(true, false)
  v.nvim_win_set_buf(0, buf)
  vim.cmd.edit(reply_filename)

  -- If first time replying, generate draft. Otherwise, no need to duplicate
  if not u.file_exists(reply_filename) then
    vim.cmd('silent 0read! notmuch reply id:' .. id)
  end

  vim.bo.bufhidden = "wipe" -- Automatically wipe buffer when closed
  v.nvim_win_set_cursor(0, { 1, 0 }) -- Return cursor to top of file

  -- Set keymap for sending
  vim.keymap.set('n', config.options.keymaps.sendmail, function()
    confirm_sendmail(reply_filename)
  end, { buffer = true })
end

-- Compose a new email
--
-- This function creates a new email for the user to edit, with the standard
-- message headers and body. The mail content is stored in `/tmp/` so the user
-- can come back to it later if needed.
--
-- @usage
--   -- Typically you can run this with `:ComposeMail` or pressing `C`
--   require('notmuch.send').compose()
s.compose = function()
  local compose_filename = '/tmp/compose.eml'

  -- TODO: Add ability to modify default body message and signature
  local headers = {
    'To: ',
    'Cc: ',
    'Subject: ',
    '',
    'Message body goes here',
  }

  -- Create new buffer
  local buf = v.nvim_create_buf(true, false)
  v.nvim_win_set_buf(0, buf)
  vim.cmd.edit(compose_filename)

  -- Populate with header fields (date, to, subject)
  v.nvim_buf_set_lines(buf, 0, -1, false, headers)

  -- Keymap for sending the email
  vim.keymap.set('n', config.options.keymaps.sendmail, function()
    confirm_sendmail(compose_filename)
  end, { buffer = true })
end

s.example_mime = {
  version = "Mime-Version: 1.0",
  type = "multipart/mixed", -- or multipart/alternative
  encoding = "8 bit",
  attributes = {
    from = "example@exmple.com",
    to = "example@example.com",
    subject = "This is an example",
  },
  mime = {{
    type = "multipart/alternative",
    attachment = false,
    mime = {
      {
        file = "/path/to/example.txt",
        type = "text/plain; charset=utf-8",
      },
      {
        file = "/path/to/example.html",
        type = "text/html; charset=utf-8",
      },
    }
  },
    {
      file = "/path/to/example.pdf",
      encoding = "base64",
      attachment = true,
    },
  }
}

-- Uses the system file command to return mime type
s.mime_type = function(filename)
  local output = vim.fn.system({'file', '--brief', '--mime-type', filename})
  return vim.fn.trim(output)
end

-- generates a random boundary string
s.boundary = function(length)
  if length > 0 then
    return s.boundary(length - 1) .. string.char(math.random(65, 65 + 25))
  else
    return ""
  end
end


-- A recursive function that goes over a mime table
-- see s.example_mime
-- and builds a mime message from it
s.make_mime = function(opts)
  local mime = {}
  if opts.mime then
    local boundary = s.boundary(32)
    table.insert(mime, "Content-Type: " .. opts.type .. ";")
    table.insert(mime, " boundary=" .. boundary)

    if opts.encoding then
      table.insert(mime, "Content-Transfer-Encoding: " .. opts.encoding)
    else
      table.insert(mime, "Content-Transfer-Encoding: 7bit")
    end

    for key, value in pairs(opts.attributes or {}) do
      table.insert(mime, key .. ": " .. value)
    end

    table.insert(mime, "")

    for _,value in ipairs(opts.mime) do
      table.insert(mime, "--" .. boundary)
      for _,value2 in ipairs(s.make_mime(value) or {}) do
        table.insert(mime, value2)
      end
    end
    table.insert(mime, "--" .. boundary .. "--")
    table.insert(mime, "")
  else
    if opts.type then
      table.insert(mime, "Content-Type: " .. opts.type)
    else
      table.insert(mime, "Content-Type: " .. s.mime_type(opts.file))
    end

    if opts.encoding then
      table.insert(mime, "Content-Transfer-Encoding: " .. opts.encoding)
    else
      table.insert(mime, "Content-Transfer-Encoding: 7bit")
    end

    local filename = ""
    if opts.filename then
      filename = opts.filename
    else
      filename = opts.file:match("^.+/(.+)$")
    end

    if opts.attachment then
      table.insert(mime, [[Content-Disposition: attachment; filename="]] .. filename .. [["]])
    else
      table.insert(mime, "Content-Disposition: inline")
    end

    local file, err = io.open(opts.file, "r")

    table.insert(mime, "")
    local content = {}
    local base64 = require("notmuch.base64")

    if file ~= nil then
      if opts.encoding == "base64" then
        content = base64.encode(file:read("*a"))

        -- RFC 2045 defines that the maximum line length for encoded base64 is 76 chars
        local split = u.split_string({ str = content, length = 76 })
        for _,value in ipairs(split) do
          table.insert(mime, value)
        end
      else
        for line in file:lines() do
          table.insert(mime, line)
        end
      end
    end

    table.insert(mime, "")

  end
  return mime
end

-- a temporary testing function
-- writes the final mime email to the buffer
-- so you can see what the result looks like
s.mime_test = function()
  local lines = s.make_mime(s.example_mime)

  local buf = v.nvim_create_buf(true, false)
  v.nvim_win_set_buf(0, buf)
  v.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return s
