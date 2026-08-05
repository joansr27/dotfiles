-- Set line numbers
vim.opt.number = true
-- vim.opt.relativenumber = true

-- Use system clipboard
vim.opt.clipboard = "unnamedplus"

-- Transparent background
-- This clears the main background so Kitty's glass shows through
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

-- This keeps the line numbers and sidebar slightly tinted
-- vim.api.nvim_set_hl(0, "LineNr", { bg = "#181825", fg = "#585b70"})
-- vim.api.nvim_set_hl(0, "SignColumn", { bg = "#181825"})

-- Hide the ~ characters at the end of the buffer
vim.opt.fillchars:append({ eob = " " })
