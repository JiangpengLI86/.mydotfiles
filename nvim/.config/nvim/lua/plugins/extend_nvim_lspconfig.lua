return {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
        local lsputil = require("lspconfig.util")
        local clangd_config = opts.servers.clangd
        if not clangd_config then return end

        clangd_config.root_dir = function(fname)
            return lsputil.root_pattern(
                "CMakeLists.txt",
                "Makefile",
                "configure.ac",
                "configure.in",
                "config.h.in",
                "meson.build",
                "meson_options.txt",
                "build.ninja"
            )(fname)
                or lsputil.root_pattern("compile_commands.json", "compile_flags.txt")(fname)
                or lsputil.find_git_ancestor(fname)
        end
    end,
}
