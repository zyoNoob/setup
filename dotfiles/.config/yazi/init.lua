require("bunny"):setup({
    desc_strategy = "path",
    ephemeral = true,
    tabs = true,
    notify = false,
    fuzzy_cmd = "fzf",
    hops = {
        { key = "/", path = "/",           desc = "Root" },
        { key = "~", path = "~",           desc = "Home" },
        { key = "w", path = "~/workspace", desc = "Workspace" },
        { key = "s", path = "~/workspace/setup", desc = "Setup Repo" },
        { key = "d", path = "~/Downloads", desc = "Downloads" },
        { key = "D", path = "~/Documents", desc = "Documents" },
        { key = "p", path = "~/Pictures",  desc = "Pictures" },
        { key = "c", path = "~/.config",   desc = "Config" },
        { key = "t", path = "/tmp",        desc = "Tmp" },
        { key = "b", path = "~/bin",       desc = "Binaries" },
        { key = "B", path = "~/workspace/compiled-programs", desc = "Source Builds" },
        { key = "S", path = "~/.ssh",      desc = "SSH Keys" },
        { key = "m", path = "/media",      desc = "Media Mounts" },
    }
})

require("searchjump"):setup({
    unmatch_fg = "#6c7086",
    match_str_fg = "#1e1e2e",
    match_str_bg = "#a6e3a1",
    first_match_str_fg = "#1e1e2e",
    first_match_str_bg = "#a6e3a1",
    label_fg = "#1e1e2e",
    label_bg = "#fab387",
    only_current = false,
    show_search_in_statusbar = false,
    auto_exit_when_unmatch = false,
    enable_capital_label = true,
    -- mapdata = require("sjch").data,
    -- search_patterns = ({"hell[dk]d","%d+.1080p","第%d+集","第%d+话","%.E%d+","S%d+E%d+",})
})