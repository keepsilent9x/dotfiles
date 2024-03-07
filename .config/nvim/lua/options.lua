local set = vim.opt

set.nu = true
set.et = true
set.ic = true
set.sr = true
set.si = true
set.scs = true
set.cul = true
set.tgc = true
set.bri = true
set.udf = true
set.title = true
set.sc = false
set.smd = false
set.swf = false
set.ts = 2
set.sw = 2
set.sts = 2
set.nuw = 3
set.ut = 250
set.tm = 250
set.cb = "unnamedplus"
set.cot = "noinsert,menuone,noselect"

vim.cmd([[
  filetype plugin indent on
  syntax on
  colorscheme gruvbox
]])

vim.filetype.add({
  pattern = { [".*/hypr/.*%.conf"] = "hyprlang" },
})

