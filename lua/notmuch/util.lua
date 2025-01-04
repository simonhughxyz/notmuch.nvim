local u = {}
local v = vim.api

-- there is a better way to do this !!!
-- Splits a string given a delimiter
--
-- This function takes in a string and splits it into a table of strings based
-- on some delimiter given by the caller, and returns the result table.
--
-- @param s string: input string
-- @param delim string: delimiter string (can be char or more complex)
--
-- @returns out table: table of strings as split by the function given delim
u.split = function(s, delim)
  local out = {}
  local i = 1
  for entry in string.gmatch(s, delim) do
    out[i] = entry
    i = i + 1
  end
  return out
end

-- Indents the header line of a message based on its depth
--
-- This function takes in the buffer and line number of a message header, and
-- the depth of the email message in the thread's reply chain. Accordingly the
-- function will prepend the header with special characters to signify its depth
-- to the user in a user friendly way.
--
-- @param buf int: id of the buffer containing the message header in question
-- @param lineno int: line number of the header which the user wants to indent
-- @param depth int: depth of the message in the reply chain of the thread
--
-- @usage
-- -- See u.process_msgs_in_thread() for invocation example
-- indent_depth(buf, lineno, msg.depth)
local indent_depth = function(buf, lineno, depth)
  local line = vim.fn.getline(lineno)
  local s = ''
  for _=0,depth-1 do s = '────' .. s end
  v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { s .. line })
end

-- Processes the output of `notmuch show` to user friendly buffer format
--
-- This function iterates over the lines of the buffer `buf`, identifying and
-- transforming lines matching certain patterns typically found in `notmuch`
-- message output. Relevant details of each message are extracted and headers
-- are modified for better readability and navigation through logical folds in
-- Neovim.
--
-- @param buf: The buffer id where the message content is located.
--
-- Behavior:
-- - Identifies lines starting with "message{", extracting metadata.
-- - Inserts structural navigation markers "{{{" and "}}}" for message folds.
-- - Deletes unnecessary line information such as envelope or parts detail,
-- 
-- Side Effects:
-- - Modifies the passed `buf` in place by adding, removing, or changing lines of text.
-- - Adds folding marks "{{{" and "}}}" for smooth folding and chaining.
-- - Indents (using `indent_depth()`) based on each msg's depth in reply chain
--
-- Usage Warning:
-- - Expects a valid Neovim buffer with `notmuch` formatted messages.
-- - Subject to change based on format of `notmuch-show` raw output
-- - Designed for synchronous message processing
--   - As of now this is fine, there is no notable performance degradation
--   - If threads are much larger, might need to explore async funcs
u.process_msgs_in_thread = function(buf)
  -- Loop over each line in the buffer and clean up the message output format
  local msg = {} -- Table which stores id, depth, file of a message
  local lineno = 1 -- Start from the top of the buffer
  local last = vim.fn.line('$') -- End at the bottom of the buffer

  while lineno <= last do
    -- Store line contents
    local line = vim.fn.getline(lineno)

    -- Message start : Store message details in `msg` and remove the line
    if string.match(line, "^message{") ~= nil then
      msg.id = string.match(line, 'id:%S+')
      msg.depth = tonumber(string.match(string.match(line, 'depth:%d+'), '%d+'))
      msg.filename = string.match(line, 'filename:%C+')
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      lineno = lineno - 1
      last = last - 1 -- Because we removed a line so buffer is shorter

    -- Header fields : Subject, From, To, etc. Indent based on `msg.depth`
    elseif string.match(line, '^header{') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {}) -- Remove "header("
      indent_depth(buf, lineno, msg.depth)
      line = vim.fn.getline(lineno) -- Add fold start identifier '{{{'
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { line, msg.id .. ' {{{' })

    -- Pass over "Subject" field and next header fields
    elseif string.match(line, '^Subject:') ~= nil then
      lineno = lineno + 2
      last = last + 1

    -- Closing header field : Delete
    elseif string.match(line, '^header}') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { '' })

    -- Closing message field : Replace with folding closing "}}}"
    elseif string.match(line, '^message}') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { '}}}', '' })
      lineno = lineno + 1
      last = last + 1

    -- Removes extra cruft like "parts", etc.
    elseif string.match(line, '^%a+[{}]') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      lineno = lineno - 1
      last = last - 1
    end

    -- Increment lineno to inspect the next line, next loop
    lineno = lineno + 1
  end
end

return u

-- vim: tabstop=2:shiftwidth=2:expandtab:foldmethod=indent
