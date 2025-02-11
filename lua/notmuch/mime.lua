local m = {}
local u = require('notmuch.util')
local v = vim.api


-- Generates a mime attachment table
--
-- This function takes in a list of paths and get's the mime type and sets the encoding
--
-- @param paths string: input string
--
-- @returns out table: table of mime attachments
m.create_mime_attachments = function (paths)
  local mimes = {}
  for _, path in ipairs(paths) do
    table.insert(mimes, {
      file = path,
      type = m.get_mime_type(path),
      attachment = true,
      encoding = "base64",
    })
  end
  return mimes
end



-- Extracts `Key: Value` pair from a list of lines
--
-- This function takes in a list of lines and extracts the `Key: Value` pair if present,
-- it then adds them to a table as { key = value }
--
-- @param lines string: input string
--
-- @returns out table: table of key and values
m.get_msg_attributes = function(lines)
  local attributes = {}
  local msg = {}
  for _, line in ipairs(lines) do
    if string.find(line, ":") then
      local sep = u.split_string(line, ":")
      attributes[sep[1]] = sep[2]
    else
      table.insert(msg, line)
    end
  end
  return attributes, msg
end



m.example_mime = {
  version = "Mime-Version: 1.0",
  type = "multipart/mixed",
  encoding = "8 bit",
  attributes = {
    from = "example@exmple.com", -- results in "from: examle@example.com" in email header
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
      attachment = true, -- if not true, then create an inline mime
    },
  }
}

-- Returns mime type of given file
--
-- This function gets the mime type of a given file
--
-- @param path string: input string
--
-- @returns out string: string of mime type of file given
m.get_mime_type = function(path)
  local output = vim.fn.system({'file', '--brief', '--mime-type', path})
  return vim.fn.trim(output)
end

-- Returns a pseudo random character string of given length
--
-- This function generates a pseudo random character string of given lenth
--
-- @param length int: input int
--
-- @returns out string: string of pseudo random characters
m.get_boundary = function(length)
  if length > 0 then
    return m.get_boundary(length - 1) .. string.char(math.random(65, 65 + 25))
  else
    return ""
  end
end


-- Returns a mime compatible message
--
-- This function returns a mime compatible message with parameters given by the mime_table
--
-- @param mime_table table: input table
--
-- @returns out table: list of string
m.make_mime_msg = function(mime_table)
  local mime = {}
  if mime_table.mime then
    local boundary = m.get_boundary(32)
    table.insert(mime, "Content-Type: " .. mime_table.type .. ";")
    table.insert(mime, " boundary=" .. boundary)

    if mime_table.encoding then
      table.insert(mime, "Content-Transfer-Encoding: " .. mime_table.encoding)
    else
      table.insert(mime, "Content-Transfer-Encoding: 7bit")
    end

    for key, value in pairs(mime_table.attributes or {}) do
      table.insert(mime, key .. ": " .. value)
    end

    table.insert(mime, "")

    for _,value in ipairs(mime_table.mime) do
      table.insert(mime, "--" .. boundary)
      for _,value2 in ipairs(m.make_mime_msg(value) or {}) do
        table.insert(mime, value2)
      end
    end
    table.insert(mime, "--" .. boundary .. "--")
    table.insert(mime, "")
  else
    if mime_table.type then
      table.insert(mime, "Content-Type: " .. mime_table.type)
    else
      table.insert(mime, "Content-Type: " .. m.get_mime_type(mime_table.file))
    end

    if mime_table.encoding then
      table.insert(mime, "Content-Transfer-Encoding: " .. mime_table.encoding)
    else
      table.insert(mime, "Content-Transfer-Encoding: 7bit")
    end

    local filename = ""
    if mime_table.filename then
      filename = mime_table.filename
    else
      filename = mime_table.file:match("^.+/(.+)$")
    end

    if mime_table.attachment then
      table.insert(mime, [[Content-Disposition: attachment; filename="]] .. filename .. [["]])
    else
      table.insert(mime, "Content-Disposition: inline")
    end

    local file, err = io.open(mime_table.file, "r")

    table.insert(mime, "")
    local content = {}
    local base64 = require("notmuch.base64")

    if file ~= nil then
      if mime_table.encoding == "base64" then
        content = base64.encode(file:read("*a"))

        -- RFC 2045 defines that the maximum line length for encoded base64 is 76 chars
        local split = u.split_string_length({ str = content, length = 76 })
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
m.mime_test = function()
  local lines = m.make_mime_msg(m.example_mime)

  local buf = v.nvim_create_buf(true, false)
  v.nvim_win_set_buf(0, buf)
  v.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return s
