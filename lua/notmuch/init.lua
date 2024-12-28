local nm = {}
local v = vim.api

local default_cmd = 'mbsync -a'
if vim.g.NotmuchMaildirSyncCmd == nil then vim.g.NotmuchMaildirSyncCmd = default_cmd end

local default_open_cmd = 'xdg-open'
if vim.fn.has('mac') == 1 then default_open_cmd = 'open' end
if vim.fn.has('wsl') == 1 then default_open_cmd = 'wsl-open' end
if vim.g.NotmuchOpenCmd == nil then vim.g.NotmuchOpenCmd = default_open_cmd end


local db_path = os.getenv("HOME") .. '/Mail'
if vim.g.NotmuchDBPath == nil then vim.g.NotmuchDBPath = db_path end

local function indent_depth(buf, lineno, depth)
  local line = vim.fn.getline(lineno)
  local s = ''
  for i=0,depth-1 do s = '────' .. s end
  v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { s .. line })
end

local function process_msgs_in_thread(buf)
  local msg = {}
  local lineno = 1
  local last = vim.fn.line('$')
  while lineno <= last do
    local line = vim.fn.getline(lineno)
    if string.match(line, "^message{") ~= nil then
      msg.id = string.match(line, 'id:%S+')
      msg.depth = tonumber(string.match(string.match(line, 'depth:%d+'), '%d+'))
      msg.filename = string.match(line, 'filename:%C+')
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      lineno = lineno - 1
      last = last - 1
    elseif string.match(line, '^header{') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      indent_depth(buf, lineno, msg.depth)
      line = vim.fn.getline(lineno)
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { line, msg.id .. ' {{{' })
    elseif string.match(line, '^Subject:') ~= nil then
      lineno = lineno + 2
      last = last + 1
    elseif string.match(line, '^header}') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { '' })
    elseif string.match(line, '^message}') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, { '}}}', '' })
      lineno = lineno + 1
      last = last + 1
    elseif string.match(line, '^%a+[{}]') ~= nil then
      v.nvim_buf_set_lines(buf, lineno-1, lineno, true, {})
      lineno = lineno - 1
      last = last - 1
    end
    lineno = lineno + 1
  end
end

--- Opens the landing/homepage for Notmuch: the `hello` page
--
-- This function opens the main landing page for `notmuch.nvim`. It essentially
-- consists of all the tags in the `notmuch` database for the user to select or
-- count. They can also search from here etc.
--
-- @usage
-- nm.show_all_tags() -- opens the `hello` page
local function show_all_tags()
  local db = require'notmuch.cnotmuch'(vim.g.NotmuchDBPath, 0)

  -- Create dedicated buffer. Content is fetched using `db.get_all_tags()`
  local buf = v.nvim_create_buf(true, true)
  v.nvim_buf_set_name(buf, "Tags")
  v.nvim_win_set_buf(0, buf)
  v.nvim_buf_set_lines(buf, 0, 0, true, db.get_all_tags())

  -- Insert help hints at the top of the buffer
  local hint_text = "Hints: <Enter>: Show threads | q: Close | r: Refresh | %: Refresh maildir | c: Count messages"
  v.nvim_buf_set_lines(buf, 0, 0, false, { hint_text , "" })

  -- Clean up the buffer and set the cursor to the head
  v.nvim_win_set_cursor(0, { 3, 0})
  v.nvim_buf_set_lines(buf, -2, -1, true, {})
  vim.bo.filetype = "notmuch-hello"
  vim.bo.modifiable = false

  db.close()
end

nm.count = function(search)
  local db = require'notmuch.cnotmuch'(vim.g.NotmuchDBPath, 0)
  local q = db.create_query(search)
  local count_messages = q.count_messages()
  db.close()
  return count_messages
end

local function run_notmuch_search(search, buf, on_complete)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  local handle
  handle = vim.loop.spawn("notmuch", {
    args = {"search", search},
    stdio = {nil, stdout, stderr}
  }, vim.schedule_wrap(function()
    -- Close the pipes and handle
    stdout:close()
    stderr:close()
    handle:close()

    -- Call the completion callback
    on_complete()
  end))

  -- Helper variable for maintaining incomplete lines between reads
  local partial_data = ""

  -- Read data from stdout and write it to the buffer
  vim.loop.read_start(stdout, vim.schedule_wrap(function(_, data)
    if data then
      -- Combine earlier incomplete chunk with newest read
      partial_data = partial_data .. data
      local lines = vim.split(partial_data, '\n')
      -- collect incomplete line at the tail of lines
      partial_data = table.remove(lines)

      -- Paste lines into the tail of `buf`
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
      vim.bo[buf].modifiable = false
    end
  end))

  -- Log errors from stderr
  vim.loop.read_start(stderr, vim.schedule_wrap(function(err, _)
    if err then
      vim.notify("ERROR: " .. err)
    end
  end))
end

nm.search_terms = function(search)
  local num_threads_found = 0
  if search == '' then
    return nil
  elseif string.match(search, '^thread:%S+$') ~= nil then
    nm.show_thread(search)
    return true
  end
  local bufno = vim.fn.bufnr(search)
  if bufno ~= -1 then
    v.nvim_win_set_buf(0, bufno)
    return true
  end
  local buf = v.nvim_create_buf(true, true)
  v.nvim_buf_set_name(buf, search)
  v.nvim_win_set_buf(0, buf)

  local hint_text = "Hints: <Enter>: Open thread | q: Close | r: Refresh | %: Sync maildir | a: Archive | A: Archive and Read | +: Add tag | -: Remove tag | =: Toggle tag"
  v.nvim_buf_set_lines(buf, 0, 2, false, { hint_text , "" })

  -- Async notmuch search to make the UX non blocking
  run_notmuch_search(search, buf, function()
    -- Completion logic
    if vim.fn.getline(2) ~= '' then num_threads_found = vim.fn.line('$') - 1 end
    print('Found ' .. num_threads_found .. ' threads')
  end)

  v.nvim_win_set_cursor(0, { 1, 0 })
  v.nvim_buf_set_lines(buf, -2, -1, true, {})
  vim.bo.filetype = "notmuch-threads"
  vim.bo.modifiable = false
end

--- Opens a thread in the mail view with all messages in the thread
--
-- This function fetches all the messages in the input thread's ID from the
-- notmuch database and displays them in the mail.vim view.
--
-- @param s string: The string to fetch the threadid from (individual line, or
--                  thread full form)
-- @return true|nil: `true` for successful display, nil for any error
--
-- @usage
-- nm.show_thread("thread:00000000000003aa")
-- nm.show_thread(v.nvim_get_current_line())
nm.show_thread = function(s)
  -- Fetch the threadid from the input `s` or from current line
  local threadid = ''
  if s == nil then
    -- fetch from the current line since no input passed
    local line = v.nvim_get_current_line()
    if line:find("Hints:") == 1 then
      -- Skip if selected the Hints line
      print("Cannot open Hints :-)")
      return nil
    end
    threadid = string.match(line, "[0-9a-z]+", 7)
  else
    threadid = string.match(s, "[0-9a-z]+", 7)
  end

  -- Open buffer if already exists, otherwise create new `buf`
  local bufno = vim.fn.bufnr('thread:' .. threadid)
  if bufno ~= -1 then
    v.nvim_win_set_buf(0, bufno)
    return true
  end
  local buf = v.nvim_create_buf(true, true)
  v.nvim_buf_set_name(buf, "thread:" .. threadid)
  v.nvim_win_set_buf(0, buf)
  v.nvim_command("silent 0read! notmuch show --exclude=false thread:" .. threadid .. " | col")

  -- Clean up the messages in the thread to display in UI friendly way
  process_msgs_in_thread(buf)

  -- Insert hint message at the top of the buffer
  local hint_text = "Hints: <Enter>: Toggle fold message | <Tab>: Next message | <S-Tab>: Prev message | q: Close | a: See attachment parts"
  v.nvim_buf_set_lines(buf, 0, 0, false, { hint_text , "" })

  -- Place cursor at head of buffer and prepare display and disable modification
  v.nvim_buf_set_lines(buf, -3, -1, true, {})
  v.nvim_win_set_cursor(0, { 1, 0})
  vim.bo.filetype="mail"
  vim.bo.modifiable = false
end

nm.refresh_search_buffer = function()
  local search = string.match(v.nvim_buf_get_name(0), '%a+:%C+')
  v.nvim_command('bwipeout')
  nm.search_terms(search)
end

nm.refresh_thread_buffer = function()
  local thread = string.match(v.nvim_buf_get_name(0), 'thread:%C+')
  v.nvim_command('bwipeout')
  nm.show_thread(thread)
end

nm.refresh_hello_buffer = function()
  v.nvim_command('bwipeout')
  show_all_tags()
end

nm.notmuch_hello = function()
  local bufno = vim.fn.bufnr('Tags')
  if bufno ~= -1 then
    v.nvim_win_set_buf(0, bufno)
  else
    show_all_tags()
  end
  print("Welcome to Notmuch.nvim! Choose a tag to search it.")
end

return nm

-- vim: tabstop=2:shiftwidth=2:expandtab:foldmethod=indent
