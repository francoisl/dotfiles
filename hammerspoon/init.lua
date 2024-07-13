hs.hotkey.bind({"cmd"}, "`", function()
    wez = hs.application.find("Wezterm")
    if wez then
        if wez:isFrontmost() then
            wez:hide()
        else
            wez:activate()
        end
    end
end)
