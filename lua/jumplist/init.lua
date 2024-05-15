---@alias JumpSubscriber fun(win_id: number)

---@type JumpSubscriber[]
local jumps_subscribers = {}

local M = {}

---@param callback JumpSubscriber
M.subscribe = function(callback) table.insert(jumps_subscribers, callback) end

---@alias Jump { filename: string, line: number, col: number, time: number, text: string }
---@alias _JumpNode { value: Jump, next: _JumpNode[], prev: _JumpNode | nil }

-- Map of window id to jump node
---@type table<number, _JumpNode>
M.current_jump = {}

-- TODO: move to config
local debug = true

-- FIX: Quickly jumping back and forward crashes window, regardless of whether there is a next node

local ag = vim.api.nvim_create_augroup("Jump", { clear = true })

---@param opts? { }
M.setup = function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})
  vim.api.nvim_create_autocmd("WinClosed", {
    group = ag,
    callback = function(ctx)
      local win_id = ctx.match
      M.current_jump[win_id] = nil
    end,
  })
end

---@param value Jump
---@return _JumpNode
local function new_node(value) return { value = value, next = {}, prev = nil } end

---@param win_id number
---@return Jump
local function create_jump(win_id)
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local line, col = unpack(vim.api.nvim_win_get_cursor(win_id))
  local filename = vim.api.nvim_buf_get_name(bufnr)
  filename = vim.fn.fnamemodify(filename, ":~:.")
  local t = os.time()
  local text =
    vim.trim(vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1])
  local jump = {
    filename = filename,
    line = line,
    col = col,
    time = t,
    text = text,
  }
  return jump
end

---@param win_id number
---@return boolean
local function cursor_on_current_jump(win_id)
  local current_jump_node = M.current_jump[win_id]
  if not current_jump_node then return false end
  local current_jump = current_jump_node.value
  local jump = create_jump(win_id)
  return jump.filename == current_jump.filename
    and jump.line == current_jump.line
    and jump.col == current_jump.col
end

---@param win_id number
local function notify_subscribers(win_id)
  for _, sub in ipairs(jumps_subscribers) do
    sub(win_id)
  end
end

---@param jump Jump
local function jump_to(jump)
  vim.cmd("e " .. jump.filename)
  vim.api.nvim_win_set_cursor(0, { jump.line, jump.col })
end

---@param win_id number
local function jump_to_current(win_id)
  local jump = M.current_jump[win_id].value
  jump_to(jump)
end

-- Get jumps as list
--
---@param win_id number
---@param opts? { max_num_entries?: number }
---@return Jump[] jumps, number? current_jump_idx
function M.get_jumps_as_list(win_id, opts)
  opts = vim.tbl_extend("force", { max_num_entries = 100 }, opts or {})

  win_id = win_id or vim.api.nvim_get_current_win()

  local node = M.get_latest_jump(win_id)
  if node == nil then return {}, nil end

  local current_jump_idx = nil
  local current_jumpnode = M.current_jump[win_id]

  local entries = {}
  for i = 1, opts.max_num_entries do
    if node == nil then break end
    if node == current_jumpnode then current_jump_idx = i end
    table.insert(entries, node.value)
    node = node.prev
  end
  return entries, current_jump_idx
end

-- Save current position as jump
--
---@param win_id? number
function M.save(win_id)
  win_id = win_id or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win_id)

  if
    cursor_on_current_jump(win_id)
    or vim.bo[buf].buftype ~= "" -- Special buf
    or vim.fn.bufname(buf) == "" -- Unnamed buf
  then
    return
  end

  local jump = create_jump(win_id)

  local node = new_node(jump)
  if not M.current_jump[win_id] then
    M.current_jump[win_id] = node
  else
    table.insert(M.current_jump[win_id].next, node)
    node.prev = M.current_jump[win_id]
    M.current_jump[win_id] = node
  end

  notify_subscribers(win_id)
end

-- Jump back
--
---@param win_id? number
function M.jump_back(win_id)
  win_id = win_id or vim.api.nvim_get_current_win()
  if debug then
    vim.info(
      ("Jumping back from\n%s"):format(vim.inspect(M.current_jump[win_id]))
    )
  end
  if not M.current_jump[win_id] then
    vim.info("No jumps for window " .. win_id)
    return
  end
  if cursor_on_current_jump(win_id) then
    if M.current_jump[win_id].prev == nil then
      vim.info("No previous jump")
      return
    end

    M.current_jump[win_id] = M.current_jump[win_id].prev
    jump_to_current(win_id)
  else
    local jump = create_jump(win_id)
    local node = new_node(jump)
    table.insert(M.current_jump[win_id].next, node)
    node.prev = M.current_jump[win_id]
    jump_to_current(win_id)
  end

  notify_subscribers(win_id)
end

-- Jump forward
--
---@param win_id? number
function M.jump_forward(win_id)
  win_id = win_id or vim.api.nvim_get_current_win()
  if debug then
    vim.info(
      ("Jumping forward from\n%s"):format(vim.inspect(M.current_jump[win_id]))
    )
  end
  if not M.current_jump[win_id] then
    vim.warn("No jumps for window", win_id)
    return
  end
  local next = M.current_jump[win_id].next
  if #next == 0 then
    vim.warn("No next jump")
    return
  end
  if not cursor_on_current_jump(win_id) then
    M.current_jump[win_id].value = create_jump(win_id) -- Update current jump
  end

  local node = next[#next]
  if #node.next == 0 then
    local jump = node.value
    jump_to(jump)
    table.remove(next, #next)
  else
    M.current_jump[win_id] = node
    jump_to_current(win_id)
  end

  notify_subscribers(win_id)
end

-- Get the latest jump node for a window
--
---@param win_id number
---@return _JumpNode?
function M.get_latest_jump(win_id)
  win_id = win_id or vim.api.nvim_get_current_win()
  if not M.current_jump[win_id] then return nil end
  local latest = M.current_jump[win_id]
  while #latest.next > 0 do
    latest = latest.next[#latest.next]
  end
  return latest
end

return M
