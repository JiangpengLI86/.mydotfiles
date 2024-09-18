-- Function to ensure tools are installed
local function ensure_mason_tools_installed(tools)
    -- This function is needed since Mason does not actually provide "ensure_installed" functionality.
    -- LazyVim is actually writing a custom function in the mason's config to ensure some default packages are installed (Check https://www.lazyvim.org/plugins/lsp#masonnvim-1)
    -- However, that function cannot be called outside that mason's setup, which is not good for modulization.
    local mason_registry = require("mason-registry")

    for _, tool in ipairs(tools) do
        local package_available, package = pcall(mason_registry.get_package, tool)

        -- Check if the package is available in the registry
        if package_available then
            if not package:is_installed() then
                -- Install the package if it's not installed
                package:install()
                vim.notify("Installing " .. tool)
            else
                -- Do nothing
            end
        else
            vim.notify("Package " .. tool .. " not found in Mason registry", vim.log.levels.ERROR)
        end
    end
end

return {
    "nvimtools/none-ls.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = function(_, opts)
        local tools = {
            "black",
            "clang-format",
            "stylua",
            "shfmt",
            "mypy",
        }

        -- Ensure tools are installed via Mason
        -- Ensure Mason is installed
        opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, tools) -- opts.ensure_installed or {}: "Use opts.ensure_installed if it exists, otherwise use an empty list"
        local status_ok, _ = pcall(require, "mason")
        if not status_ok then
            vim.notify("Mason is not installed", vim.log.levels.ERROR)
            return
        end
        -- Installing tools
        ensure_mason_tools_installed(tools)

        -- Null-ls setup
        local null_ls = require("null-ls")
        local function setup_null_ls_sources(nls)
            return {
                nls.builtins.formatting.stylua,
                nls.builtins.formatting.shfmt,
                nls.builtins.formatting.black,
                nls.builtins.diagnostics.mypy,
                nls.builtins.formatting.clang_format,
            }
        end

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities.offsetEncoding = { "utf-16" }
        require("lspconfig").clangd.setup({
            capabilities = capabilities,
        })

        -- opts.root_dir tells null-ls how to determine the root directory of a project, which is crucial for some tools like linters and formatters.
        -- root.patterns function searches for theses specific files (in order) in the current directory and its parents. As soon as one of theses files is found, the directory is considered the root of the project.
        opts.root_dir = opts.root_dir
            or require("null-ls.utils").root_pattern(
                ".null-ls-root", -- Custom marker for null-ls
                ".git", -- Git version-controlled projects
                "requirements.txt", -- Python projects
                "enviroment.yaml", -- Python projects
                "CMakeLists.txt", -- C/C++ projects
                ".vscode", -- VSCode configuration files
                "Dockerfile", -- Docker files (Might not be a good idea as it might not be the root of the project)
                "Cargo.toml", -- Rust projects
                "composer.json", -- PHP projects
                "go.mod" -- Go projects
            )
        opts.sources = vim.list_extend(opts.sources or {}, setup_null_ls_sources(null_ls))
    end,
}
