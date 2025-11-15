## pretty-quickfix.nvim

I wanted a prettier quickfix window, without any extra features. This plugin does just that.

- Uses `nvim-web-devicons` to display an icon for each entries
- De-cluttered output with optional treesitter syntax and matches highlighting
- When all entries are files, de-duplicate the content

|      | Before | After |
|------|--------|-------|
| Default view | ![Before](https://github.com/QuiiBz/pretty-quickfix.nvim/blob/main/imgs/before.png) | ![After](https://github.com/QuiiBz/pretty-quickfix.nvim/blob/main/imgs/after.png) |
| Files only | ![Before](https://github.com/QuiiBz/pretty-quickfix.nvim/blob/main/imgs/files-before.png) | ![After](https://github.com/QuiiBz/pretty-quickfix.nvim/blob/main/imgs/files-after.png) |

## Installation

### Lazy.nvim

```lua
{
  'QuiiBz/pretty-quickfix.nvim',
  dependencies = { 'nvim-web-devicons' },
  ft = { 'qf' }, -- lazy load
  opts = {}, -- view options below
}
```

## Options

```lua
{
  show_line_numbers = true, -- Whether to show line numbers in the quickfix list
  treesitter_highlighting = true, -- Whether to use treesitter for syntax highlighting
  highlight_matches =  true, -- Whether to highlight the matched text in each entry
  format = 'filepath', -- Display entries with the file name or file path
  files_list_format = 'filepath', -- Same as the above but when all entries are files
}
```

## Sponsors

![Sponsors](https://github.com/QuiiBz/dotfiles/blob/main/sponsors.png?raw=true)

## License

[MIT](./LICENSE)

