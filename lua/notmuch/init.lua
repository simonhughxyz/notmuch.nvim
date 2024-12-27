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

local function show_all_tags()
  local db = require'notmuch.cnotmuch'(vim.g.NotmuchDBPath, 0)
  local buf = v.nvim_create_buf(true, true)
  v.nvim_buf_set_name(buf, "Tags")
  v.nvim_win_set_buf(0, buf)
  v.nvim_buf_set_lines(buf, 0, 0, true, db.get_all_tags())
  v.nvim_win_set_cursor(0, { 1, 0})
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

  -- Read data from stdout and write it to the buffer
  vim.loop.read_start(stdout, vim.schedule_wrap(function(_, data)
    if data then
      local lines = vim.split(data, '\n')
      lines[#lines] = nil -- Remove trailing empty element
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 1, -1, false, lines)
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

  -- Async notmuch search to make the UX non blocking
  run_notmuch_search(search, buf, function()
    -- Completion logic
    if vim.fn.getline(1) ~= '' then num_threads_found = vim.fn.line('$') end
    print('Found ' .. num_threads_found .. ' threads')
    vim.bo.modifiable = true
    v.nvim_buf_set_lines(buf, 0, 1, false, { "Here is a hint" })
    vim.bo.modifiable = false
  end)

  v.nvim_win_set_cursor(0, { 1, 0 })
  v.nvim_buf_set_lines(buf, -2, -1, true, {})
  vim.bo.filetype = "notmuch-threads"
  vim.bo.modifiable = false
end

nm.show_thread = function(s)
  local threadid = ''
  if s == nil then
    local line = v.nvim_get_current_line()
    threadid = string.match(line, "[0-9a-z]+", 7)
  else
    threadid = string.match(s, "[0-9a-z]+", 7)
  end
  local bufno = vim.fn.bufnr('thread:' .. threadid)
  if bufno ~= -1 then
    v.nvim_win_set_buf(0, bufno)
    return true
  end
  local buf = v.nvim_create_buf(true, true)
  v.nvim_buf_set_name(buf, "thread:" .. threadid)
  v.nvim_win_set_buf(0, buf)
  --v.nvim_command("silent 0read! notmuch show --exclude=false thread:" .. threadid .. " | sed 's///g'")
  v.nvim_command("silent 0read! notmuch show --exclude=false thread:" .. threadid .. " | col")
  process_msgs_in_thread(buf)
  v.nvim_win_set_cursor(0, { 1, 0})
  v.nvim_buf_set_lines(buf, -3, -1, true, {})
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
