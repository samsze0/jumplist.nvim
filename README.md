# jumplist.nvim

A neovim plugin that provides window-local jumplists

Vim's built-in jumplist is tedious to use. Every other plugins you have installed have access to it. This plugin allows you to have full control over the jumplist's state for each window.

## Usage

```lua
{
    "samsze0/jumplist.nvim",
    config = function()
        require("jumplist").setup({})
    end
}
```

```lua
local jumplist = require("jumplist")

jumplist.save()  -- Save current cursor position to the window-local jumplist
jumplist.jump_back()
jumplist.jump_forward()
```

## License

MIT