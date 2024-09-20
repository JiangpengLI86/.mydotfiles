return {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
        -- For Clangd configuration >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        local clangd_config = opts.servers.clangd
        clangd_config.root_dir = function(fname)
            return require("lspconfig.util").root_pattern(
                "CMakeLists.txt", -- Added to the default list
                "Makefile",
                "configure.ac",
                "configure.in",
                "config.h.in",
                "meson.build",
                "meson_options.txt",
                "build.ninja"
            )(fname) or require("lspconfig.util").root_pattern("compile_commands.json", "compile_flags.txt")(
                fname
            ) or require("lspconfig.util").find_git_ancestor(fname)
        end
        -- For Clangd configuration <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    end,
}
