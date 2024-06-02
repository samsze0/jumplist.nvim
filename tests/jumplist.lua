local jumplist = require("jumplist")

jumplist.setup({
  notifier = {
    error = function(msg) print("Error: " .. msg) end,
    warn = function(msg) print("Warn: " .. msg) end,
    info = function(msg) print("Info: " .. msg) end,
  },
})

vim.cmd("edit tests/test-file.txt")

-- Double check if test file has the expected content
T.assert_deep_eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "line 1", "line 2", "line 3", "line 4", "line 5", "line 6", "line 7", "line 8", "line 9", "line 10" })

local win_id = vim.api.nvim_get_current_win()
jumplist.save()

T.assert(jumplist.current_jump[win_id] ~= nil)
T.assert(jumplist.current_jump[win_id].value ~= nil)
T.assert(jumplist.current_jump[win_id].value.time ~= nil)

-- Set time to nil to make the test deterministic
local _time = jumplist.current_jump[win_id].value.time
jumplist.current_jump[win_id].value.time = nil
T.assert_deep_eq(jumplist.current_jump, {
  [win_id] = {
    next = {},
    value = {
      filename = "tests/test-file.txt",
      line = 1,
      col = 0,
      text = "line 1",
    },
    pinned = true
  }
})
jumplist.current_jump[win_id].value.time = _time

---@params opts { current_line: string, prev_line?: string, next_lines?: string[] }
local function assert_jumplist(opts)
  T.assert_eq(jumplist.current_jump[win_id].value.text, opts.current_line)
  if opts.prev_line then
    T.assert_eq(jumplist.current_jump[win_id].prev.value.text, opts.prev_line)
  else
    T.assert_not(jumplist.current_jump[win_id].prev)
  end
  if opts.next_lines then
    local actual_next_lines = {}
    for _, next_jump in ipairs(jumplist.current_jump[win_id].next) do
      table.insert(actual_next_lines, next_jump.value.text)
    end
    T.assert_deep_eq(actual_next_lines, opts.next_lines)
  else
    T.assert_eq(#jumplist.current_jump[win_id].next, 0)
  end
end

-- Understanding the notations:
-- x: current jump
-- <-: current cursor position
-- ?: not a jump. Not present in jumplist
-- |: separator between jumps. For representing a list of jumps

-- save
-- x a(line 1, pinned) <-

-- navigate
--  ?b(line 6) <-
-- x a(line 1, pinned)

vim.cmd("normal! 5j3l")  -- Move to line 6
T.assert_eq(vim.api.nvim_get_current_line(), "line 6")
assert_jumplist({ current_line = "line 1" })

-- jump back
--   b(line 6)
-- x a(line 1, pinned) <-

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 1")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6" } })

-- navigate
--   b(line 6) |  ?c(line 2) <-
-- x a(line 1, pinned)

vim.cmd("normal! 1j")  -- Move to line 2
T.assert_eq(vim.api.nvim_get_current_line(), "line 2")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6" } })

-- jump back
--   b(line 6) | c(line 2)
-- x a(line 1) <-

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 1")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6", "line 2" } })

-- jump forward
--   b(line 6) |  ?c(line 2) <-
-- x a(line 1, pinned)

jumplist.jump_forward()
T.assert_eq(vim.api.nvim_get_current_line(), "line 2")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6" } })

-- navigate to a
--   b(line 6)
-- x a(line 1, pinned) <-

vim.cmd("normal! 1k")  -- Move to line 1
T.assert_eq(vim.api.nvim_get_current_line(), "line 1")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6" } })

-- jump forward
--   ?b(line 6) <-
-- x a(line 1, pinned)

jumplist.jump_forward()
T.assert_eq(vim.api.nvim_get_current_line(), "line 6")
assert_jumplist({ current_line = "line 1" })

-- jump back
--   b(line 6)
-- x a(line 1, pinned) <-

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 1")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6" } })

-- navigate
--   b(line 6) |  ?j(line 4) <-
-- x a(line 1)

vim.cmd("normal! 3j")  -- Move to line 4
T.assert_eq(vim.api.nvim_get_current_line(), "line 4")
assert_jumplist({ current_line = "line 1", next_lines = { "line 6" } })

-- jump forward
--                ?b(line 6) <-
--   b(line 6) | x j(line 4)
--   a(line 1, pinned)

jumplist.jump_forward()
T.assert_eq(vim.api.nvim_get_current_line(), "line 6")
assert_jumplist({ current_line = "line 4", prev_line = "line 1" })

-- navigate
--                ?e(line 7) <-
--   b(line 6) | x j(line 4)
--   a(line 1, pinned)

vim.cmd("normal! 1j")  -- Move to line 7
T.assert_eq(vim.api.nvim_get_current_line(), "line 7")
assert_jumplist({ current_line = "line 4", prev_line = "line 1" })

-- save
--                x e(line 7, pinned) <-
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.save()
T.assert_eq(vim.api.nvim_get_current_line(), "line 7")
assert_jumplist({ current_line = "line 7", prev_line = "line 4" })

-- navigate
--                 ?f(line 10) <-
--                x e(line 7, pinned)
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

vim.cmd("normal! 3j")  -- Move to line 10
T.assert_eq(vim.api.nvim_get_current_line(), "line 10")
assert_jumplist({ current_line = "line 7", prev_line = "line 4" })

-- jump back
--                  f(line 10)
--                x e(line 7, pinned) <-
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 7")
assert_jumplist({ current_line = "line 7", prev_line = "line 4", next_lines = { "line 10" } })

-- navigate
--                  f(line 10) |  ?g(line 9) <-
--                x e(line 7, pinned)
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

vim.cmd("normal! 2j")  -- Move to line 9
T.assert_eq(vim.api.nvim_get_current_line(), "line 9")
assert_jumplist({ current_line = "line 7", prev_line = "line 4", next_lines = { "line 10" } })

-- jump back
--                  f(line 10) |  g(line 9)
--                x e(line 7, pinned) <-
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 7")
assert_jumplist({ current_line = "line 7", prev_line = "line 4", next_lines = { "line 10", "line 9" } })

-- navigate
--                  f(line 10) |  g(line 9) |  ?h(line 8) <-
--                x e(line 7, pinned)
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

vim.cmd("normal! 1j")  -- Move to line 8
T.assert_eq(vim.api.nvim_get_current_line(), "line 8")
assert_jumplist({ current_line = "line 7", prev_line = "line 4", next_lines = { "line 10", "line 9" } })

-- jump forward
--                                             ?g(line 9) <-
--                  f(line 10) |  g(line 9) | x h(line 8)
--                  e(line 7, pinned)
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_forward()
T.assert_eq(vim.api.nvim_get_current_line(), "line 9")
assert_jumplist({ current_line = "line 8", prev_line = "line 7" })

-- navigate
--                                              ?k(line 5) <-
--                  f(line 10) |  g(line 9) | x h(line 8)
--                  e(line 7, pinned)
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

vim.cmd("normal! 4k")  -- Move to line 5
T.assert_eq(vim.api.nvim_get_current_line(), "line 5")
assert_jumplist({ current_line = "line 8", prev_line = "line 7" })

-- jump back
--                                              k(line 5)
--                  f(line 10) |  g(line 9) | x h(line 8) <-
--                  e(line 7, pinned)
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 8")
assert_jumplist({ current_line = "line 8", prev_line = "line 7", next_lines = { "line 5" } })

-- jump back
--                                              k(line 5)
--                  f(line 10) |  g(line 9) |   h(line 8)
--                x e(line 7, pinned) <-
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_back()
T.assert_eq(vim.api.nvim_get_current_line(), "line 7")
assert_jumplist({ current_line = "line 7", prev_line = "line 4", next_lines = { "line 10", "line 9", "line 8" } })

-- jump forward
--                                              k(line 5)
--                  f(line 10) |  g(line 9) | x h(line 8) <-
--                  e(line 7, pinned) <-
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_forward()
T.assert_eq(vim.api.nvim_get_current_line(), "line 8")
assert_jumplist({ current_line = "line 8", prev_line = "line 7", next_lines = { "line 5" } })

-- jump forward
--                                             ?k(line 5) <-
--                  f(line 10) |  g(line 9) | x h(line 8)
--                  e(line 7, pinned) <-
--   b(line 6)  |   j(line 4)
--   a(line 1, pinned)

jumplist.jump_forward()
T.assert_eq(vim.api.nvim_get_current_line(), "line 5")
assert_jumplist({ current_line = "line 8", prev_line = "line 7" })