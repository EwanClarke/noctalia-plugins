
function update()
    noctalia.setUpdateInterval(1000)
    barWidget.setGlyph("device-tv")
    barWidget.setText("MAL")
end

function onClick()
    noctalia.notify("MyAnimeList Tracker", "clicked")
end
