require("relative-motions"):setup({
    show_numbers = "relative_absolute",
    show_motion = true,
    enter_mode = "cache_or_first"
})

ps.sub_remote("ind-app-title", function()
	return "Yazi: " .. tostring(cx.active.current.cwd)
end)
