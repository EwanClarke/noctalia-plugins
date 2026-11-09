local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-._~"
local DATA_DIR = noctalia.pluginDataDir()
local render

local currentView = "login" -- "login" | "code" | "list" | "item"
local clientId
local pendingVerifier = nil
local enteredCode = ""

type animeListItem = {name : string}
type mangaListItem = {name : string}

local function generateCodeVerifier()
    local characters = {}

    for _ = 1, 128 do
        local randIndex = math.random(1, #charset)
        local randChar = string.sub(charset, randIndex, randIndex)
        table.insert(characters, randChar)
    end

    return table.concat(characters, "")
end


local function onLoginClicked()
     pendingVerifier = generateCodeVerifier()
     clientId = noctalia.state.get("mal:client_id")
     local authUrl = "https://myanimelist.net/v1/oauth2/authorize"
        .. "?response_type=code"
        .. "&client_id=" .. clientId
        .. "&code_challenge=" .. pendingVerifier
        .. "&code_challenge_method=plain"

    noctalia.runAsync({"xdg-open", authUrl})

    -- update view to accept code
    currentView = "code"
    render()
end

local function logout()
    -- clear login token and list contents
    noctalia.readFile(DATA_DIR .. "/auth.json")

    currentView = "login"
    render()
end

local function onSubmitCode()
    -- confirm that code is valid
    local code = noctalia.string.trim(enteredCode)

    if string.find(code, "code=") then
        local matched = string.match(code, "code=([^&]+)")
        if matched then
            code = matched
        end
    end
    -- obtain access token
    if #code == 0 or not pendingVerifier then
        noctalia.notifyError("MAL", "Authorisation code is invalid")
        return
    end

    local body = "client_id=" .. clientId
        .. "&grant_type=authorization_code"
        .. "&code=" .. noctalia.string.urlEncode(code)
        .. "&code_verifier=" .. pendingVerifier

    noctalia.http({
        url = "https://myanimelist.net/v1/oauth2/token",
        method = "POST",
        headers = {
            "Content-Type: application/x-www-form-urlencoded"
        },
        body = body
    }, function(response)
        if response.ok and response.status == 200 then
            noctalia.writeFile(DATA_DIR .. "/auth.json", response.body)

            currentView = "list"
            render()
        else
            noctalia.notifyError("MAL login failed", "Status: " .. tostring(response.status))
        end
    end)

end

local function getAccessToken(): string?
    if not DATA_DIR then return nil end

    local content = noctalia.readFile(DATA_DIR .. "/auth.json")
    if not content then return nil end

    local auth = noctalia.json.decode(content)
    return auth and auth.access_token
end

local function fetchUserProfile(onDone: (any) -> ())
    local token = getAccessToken()
    if not token then
        noctalia.notifyError("MAL", "Not logged in")
        return
    end

    noctalia.http({
        url = "https://api.myanimelist.net/v2/users/@me?fields=anime_statistics",
        method = "GET",
        headers = {
            "Authorization: Bearer " .. token,
            "Accept: application/json"
        }
    }, function(response)
        if response.ok and response.status == 200 then
            local userProfile = noctalia.json.decode(response.body)
            onDone(userProfile)
        else
            noctalia.notifyError("MAL", "Failed to fetch profile: " .. tostring(response.status))
        end
    end)
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
            ui.button({text = "Login with MAL", variant = "primary", onClick = onLoginClicked})
        })
    })
end

local function buildCode()
    return ui.column({justify = "center", align = "stretch"}, {
        ui.row({justify = "start"}, {
            ui.button({text = "back", onClick = logout}),
        }),
        ui.row({gap = 30}, {
            ui.label({
                text = "Paste token here: ",
                height = 36,
            }),
            ui.input({
                width = 200,
                height = 36,
                onChange = function(text)
                    enteredCode = text
                end,
                onSubmit = function(text)
                    onSubmitCode()
                end
            })
        }),
        ui.row({justify = "end"}, {
            ui.button({text = "Submit", variant = "primary", onClick = onSubmitCode})
        })
    })
end

local function buildList()

    -- get user information
    fetchUserProfile(function(profile)
        local username = profile.name

        noctalia.state.set("mal:username", username)
    end)

    return ui.column({}, {
        ui.button({text = "back", onClick = logout}),
        ui.row({}, {
            ui.label({text = "Hello, " .. noctalia.state.get("mal:username")})
        })

    })
end

local function buildItem()

end

render = function()
    if currentView == "login" then
        panel.render(buildLogin())
    elseif currentView == "list" then
        panel.render(buildList())
    elseif currentView == "code" then
        panel.render(buildCode())
    end
end

function onOpen()
    local authenticated = DATA_DIR and (DATA_DIR .. "/auth.json")

    if authenticated then
        currentView = "list"
    else
        currentView = "login"
    end

    render()
end

function onClose()

end
