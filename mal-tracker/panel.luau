local currentView = "login" -- "login" | "list" | "item"
local render


type animeListItem = {name : string, }
type mangaListItem = {name : string, }

local function onSubmitLogin()
    -- wait for login token
    currentView = "list"
    render()
end

local function logout()
    -- clear login token and list contents
    currentView = "login"
    render()
end

local function onSelectItem()
    currentView = "item"
    render()
end

local function buildLogin()
    return ui.column({
        padding = 16,
        gap = 12,
        align = "stretch"
    }, {
        -- header
        ui.row({ gap = 8, align = "center", justify = "center"}, {
            ui.label({text = "Login"})
        }),
        ui.separator({}),
        ui.row({height = 36, align = "center"}, {
            ui.label({text = "Connect to your MAL account to start tracking!"})
        }),
        ui.row({height = 36, align = "center", justify = "space_between"}, {
            ui.label({text = ""}),
            ui.button({text = "Login with MAL", variant = "primary", onClick = onSubmitLogin})
        })
    })
end

local function buildList()
    return ui.column({}, {ui.button({text = "back", onClick = logout})})
end

local function buildItem()

end

render = function()
    if currentView == "login" then
        panel.render(buildLogin())
    elseif currentView == "list" then
        panel.render(buildList())
    end
end

function onOpen()
    render()
end

function onClose()
    currentView = "login"
end
