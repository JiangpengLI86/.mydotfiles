local has_tex_compiler = vim.fn.executable("latexmk") == 1 or vim.fn.executable("tectonic") == 1

return {
  {
    "lervag/vimtex",
    enabled = has_tex_compiler,
  },
}
