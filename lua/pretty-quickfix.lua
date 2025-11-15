local M = {}

--- @class PrettyQuickfixConfig
--- @field show_line_numbers boolean|nil Whether to show line numbers in the quickfix list (default: true)
--- @field treesitter_highlighting boolean|nil Whether to use treesitter for syntax highlighting of content (default: true)
--- @field format 'filename'|'filepath'|nil Display entries with the file name or file path (default: 'filepath')
--- @field files_list_format 'filename'|'filepath'|nil Same as the above but when all entries are files (default: 'filepath')

--- @type PrettyQuickfixConfig
local DEFAULT_OPTIONS = {
  show_line_numbers = true,
  treesitter_highlighting = true,
  format = 'filepath',
  files_list_format = 'filepath',
}

--- Merge user options with default options
--- @param user_opts PrettyQuickfixConfig|nil
--- @param default_opts PrettyQuickfixConfig
--- @return PrettyQuickfixConfig opts
local function get_opts(user_opts, default_opts)
  if user_opts == nil then
    return default_opts
  end

  local opts = {}
  for k, v in pairs(default_opts) do
    if user_opts[k] == nil then
      opts[k] = v
    else
      opts[k] = user_opts[k]
    end
  end
  return opts
end

local devicons = require('nvim-web-devicons')

--- Cache for icons to avoid redundant lookups
--- @type table<string, { icon: string, icon_hl: string }>
local icons_cache = {}

--- Get icon and highlight group for a given filename and extension
--- @param filename string
--- @param ext string|nil
--- @return string icon, string icon_hl
local function get_icon(filename, ext)
  local key = filename .. '.' .. (ext or '')
  if not icons_cache[key] then
    local icon, icon_hl = devicons.get_icon(filename, ext, { default = true })
    icons_cache[key] = {
      icon = icon or '󰈚',
      icon_hl = icon_hl or 'DevIconDefault',
    }
  end
  return icons_cache[key].icon, icons_cache[key].icon_hl
end

--- Format quickfix list entries for display
--- @param opts PrettyQuickfixConfig
--- @return table<number, { icon: string, icon_hl: string, filename: string, line_part: string, content: string, bufnr: number, filetype: string|nil, content_start: integer }> formatted_entries
local function format_qf_entries(opts)
  local qf_list = vim.fn.getqflist()
  local formatted_entries = {}

  -- Check if all entries are files (lnum == 0, col == 0)
  -- to determine if we should show line numbers
  local is_files_list = true
  for i = 1, #qf_list do
    local item = qf_list[i]
    if item.lnum > 1 and item.col > 1 then
      is_files_list = false
      break
    end
  end

  for i = 1, #qf_list do
    local item = qf_list[i]
    if item.bufnr ~= 0 then
      local bufname = vim.fn.bufname(item.bufnr)

      if bufname ~= '' then
        local filename = vim.fn.fnamemodify(bufname, ':t:r')
        local ext = vim.fn.fnamemodify(bufname, ':e')

        -- Re-add extension if it exists
        if ext ~= '' then
          filename = filename .. '.' .. ext
        end

        local icon, icon_hl = get_icon(filename, ext)
        local line_part = ':' .. item.lnum
        local content = item.text and (' ' .. item.text:gsub('^%s+', '')) or ''

        -- Hide line numbers and content if all entries are files
        -- and show the filename as the filepath without leading space
        if is_files_list then
          line_part = ''
          content = ''
          filename = opts.files_list_format == 'filename' and filename or bufname
        else
          filename = opts.format == 'filename' and filename or bufname
        end

        local filetype = not is_files_list and vim.filetype.match({ filename = bufname })

        formatted_entries[i] = {
          icon = icon,
          icon_hl = icon_hl,
          filename = filename,
          line_part = line_part,
          content = content,
          bufnr = item.bufnr,
          filetype = filetype,
        }
      end
    end
  end

  return formatted_entries
end

--- Set up the pretty-quickfix.nvim plugin
--- @param opts PrettyQuickfixConfig|nil
--- @return nil
M.setup = function(opts)
  opts = get_opts(opts, DEFAULT_OPTIONS)

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'qf',
    group = vim.api.nvim_create_augroup('pretty-quickfix', { clear = true }),
    callback = function(event)
      local buf = event.buf

      -- Configure buffer options
      vim.api.nvim_buf_set_option(buf, 'cursorcolumn', false)
      vim.api.nvim_buf_set_option(buf, 'signcolumn', 'no')
      vim.api.nvim_buf_set_option(buf, 'number', opts.show_line_numbers)

      local ns = vim.api.nvim_create_namespace('pretty-quickfix')

      local function update_qf_display()
        local formatted_entries = format_qf_entries(opts)
        local new_lines = {}

        -- Build new buffer content with formatting
        for i, formatted in pairs(formatted_entries) do
          local line = formatted.icon .. ' ' .. formatted.filename .. formatted.line_part .. formatted.content
          new_lines[i] = line
        end

        -- Fill in any missing lines with original content
        local original_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        for i = 1, #original_lines do
          if not new_lines[i] then
            new_lines[i] = original_lines[i]
          end
        end

        -- Replace buffer content (disable LSP tracking to prevent sync errors)
        local clients = vim.lsp.get_active_clients({ bufnr = buf })
        for _, client in ipairs(clients) do
          vim.lsp.buf_detach_client(buf, client.id)
        end

        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        vim.api.nvim_buf_set_option(buf, 'modified', false)

        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

        for i, formatted in pairs(formatted_entries) do
          -- Icon highlighting
          vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
            end_col = #formatted.icon + 1,
            hl_group = formatted.icon_hl,
          })

          -- Filename highlighting
          local filename_start = #formatted.icon + 1
          vim.api.nvim_buf_set_extmark(buf, ns, i - 1, filename_start, {
            end_col = filename_start + #formatted.filename,
            hl_group = 'Function',
          })

          -- Line number highlighting
          if #formatted.line_part > 0 then
            local line_start = filename_start + #formatted.filename
            vim.api.nvim_buf_set_extmark(buf, ns, i - 1, line_start, {
              end_col = line_start + #formatted.line_part,
              hl_group = 'Comment',
            })
          end

          -- Store content position for batch treesitter highlighting
          if #formatted.content > 0 then
            local content_start = filename_start + #formatted.filename + #formatted.line_part
            formatted.content_start = content_start

            -- Fallback highlighting if treesitter is disabled or no filetype
            if not opts.treesitter_highlighting then
              vim.api.nvim_buf_set_extmark(buf, ns, i - 1, content_start, {
                end_col = content_start + #formatted.content,
                hl_group = 'Normal',
              })
            end
          end
        end

        -- Batch process treesitter highlighting by filetype
        if opts.treesitter_highlighting then
          local by_filetype = {}
          for i, formatted in pairs(formatted_entries) do
            if #formatted.content > 0 and formatted.filetype then
              if not by_filetype[formatted.filetype] then
                by_filetype[formatted.filetype] = {}
              end
              table.insert(by_filetype[formatted.filetype], {
                index = i,
                formatted = formatted,
              })
            end
          end

          -- Process each filetype group
          for filetype, entries in pairs(by_filetype) do
            local has_parser = pcall(vim.treesitter.language.get_lang, filetype)
            if has_parser then
              -- Get the highlight query once for this filetype
              local ok_query, query = pcall(vim.treesitter.query.get, filetype, 'highlights')
              if ok_query and query then
                -- Process each entry with this filetype
                for _, entry in ipairs(entries) do
                  local i = entry.index
                  local formatted = entry.formatted

                  -- Parse content using treesitter string parser
                  local content_text = formatted.content:match('^%s*(.*)$')
                  local ok, parser = pcall(vim.treesitter.get_string_parser, content_text, filetype)

                  if ok and parser then
                    local tree = parser:parse()[1]
                    if tree then
                      local root = tree:root()

                      -- Apply highlights from treesitter using theme colors
                      for id, node in query:iter_captures(root, content_text, 0, 1) do
                        local capture_name = query.captures[id]

                        -- Build highlight group name (Neovim 0.8+ style)
                        local hl_group = '@' .. capture_name .. '.' .. filetype

                        -- Fallback to generic @capture if filetype-specific doesn't exist
                        if vim.fn.hlexists(hl_group) == 0 then
                          hl_group = '@' .. capture_name
                        end

                        local start_row, start_col, _, end_col = node:range()
                        if start_row == 0 and vim.fn.hlexists(hl_group) ~= 0 then
                          -- Adjust for the position in the quickfix buffer
                          local hl_start = formatted.content_start + start_col + 1 -- +1 for leading space
                          local hl_end = formatted.content_start + end_col + 1

                          vim.api.nvim_buf_set_extmark(buf, ns, i - 1, hl_start, {
                            end_col = hl_end,
                            hl_group = hl_group,
                            priority = 100,
                          })
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          -- Apply fallback highlighting for content without treesitter
          for i, formatted in pairs(formatted_entries) do
            if #formatted.content > 0 and not formatted.filetype then
              vim.api.nvim_buf_set_extmark(buf, ns, i - 1, formatted.content_start, {
                end_col = formatted.content_start + #formatted.content,
                hl_group = 'Normal',
              })
            end
          end
        end
      end

      update_qf_display()

      -- Move cursor to avoid icon area
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = buf,
        callback = function()
          local cursor = vim.api.nvim_win_get_cursor(0)
          local line_content = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1] or ''

          -- Find where the actual filename starts (after icon and space)
          local icon_and_space_pattern = '^[^ ]* '
          local _, icon_end = line_content:find(icon_and_space_pattern)
          local min_col = icon_end or 2

          if cursor[2] < min_col then
            vim.api.nvim_win_set_cursor(0, { cursor[1], min_col })
          end
        end,
      })
    end,
  })
end

return M
