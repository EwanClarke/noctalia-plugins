local PANEL_ID = "tetrasquared/mal-tracker:list-ui"

function update()
    noctalia.setUpdateInterval(1000)
    barWidget.setGlyph("device-tv")
    barWidget.setText("MAL")
end

function onClick()
    noctalia.togglePanel(PANEL_ID)
end
