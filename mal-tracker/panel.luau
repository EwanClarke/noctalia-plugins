local DATA_DIR = noctalia.pluginDataDir()
local render

local currentView = "login" -- "login" | "code" | "list" | "entry"
local currentList = "anime" -- "anime" | "manga"
local clientId
local pendingVerifier = nil
local enteredCode = ""
local animeList = {}
local mangaList = {}
local listLoaded = false
local currentEntry = nil

local function generateCodeVerifier()
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-._~"
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
    noctalia.removeFile(DATA_DIR .. "/auth.json")



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

local function fetchAnimeList(offset: number, limit: number, onDone : (any) -> ())
    local token = getAccessToken()
    if not token then
        noctalia.notifyError("MAL", "Not logged in")
        return
    end

    -- add loading state

    noctalia.http({
        url = "https://api.myanimelist.net/v2/users/@me/animelist?fields=list_status,num_episodes,alternative_titles"
            .. "&offset=" .. tostring(offset)
            .. "&limit=" .. tostring(limit),
        method = "GET",
        headers = {
            "Authorization: Bearer " .. token,
            "Accept: application/json"
        }
    }, function(response)
        if response.ok and response.status == 200 then
            local decoded = noctalia.json.decode(response.body)
            onDone(decoded.data)
        else
            noctalia.notifyError("MAL", "Failed to fetch anime list")
        end
    end)


end

local function fetchMangaList(offset: number, limit: number, onDone : (any) -> ())
    local token = getAccessToken()
    if not token then
        noctalia.notifyError("MAL", "Not logged in")
        return
    end

    noctalia.http({
        url = "https://api.myanimelist.net/v2/users/@me/mangalist?fields=list_status,num_chapters,alternative_titles"
            .. "&offset=" .. tostring(offset)
            .. "&limit=" .. tostring(limit),
        method = "GET",
        headers = {
            "Authorization: Bearer " .. token,
            "Accept: application/json"
        }
    }, function(response)
        if response.ok and response.status == 200 then
            local decoded = noctalia.json.decode(response.body)
            onDone(decoded.data)
        else
            noctalia.notifyError("MAL", "Failed to fetch manga list")
        end
    end)
end

local function loadCurrentList()
    if currentList == "anime" then
        if #animeList == 0 or not listLoaded then
            fetchAnimeList(0, 10, function(decoded)
                animeList = decoded
                listLoaded = true
                render()
            end)
        end
    else
        if #mangaList == 0 or not listLoaded then
            fetchMangaList(0, 10, function(decoded)
                mangaList = decoded
                listLoaded = true
                render()
            end)
        end
    end
end

local function onSelectEntry(entry)
    currentView = "entry"
    currentEntry = entry
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
        ui.row({height = 36, align = "center", justify = "end"}, {
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

local function getDisplayTitle(node)
    local alt = node.alternative_titles
    if alt and alt.en and alt.en ~= "" then
        return alt.en
    else
        return node.title
    end
end

local function buildAnimeRow(entry)
    local anime = entry.node
    local status = entry.list_status

    local currentEp = (status and status.num_episodes_watched) or 0
    local totalEp = anime.num_episodes or 0

    local isCompleted = (status and status.status == "completed") or (totalEp > 0 and currentEp >= totalEp)
    local totalEpDisplay = (totalEp > 0) and tostring(totalEp) or "?"

    local title = getDisplayTitle(anime)

    local rowContent = {
        ui.column({
            flexGrow = 1,
            gap = 4,
            align = "start",
        }, {
            ui.label({
                text = title,
                fontWeight = "semibold",
                maxWidth = 320,
            }),
            ui.label({
                text = string.format("Ep %d / %s", currentEp, totalEpDisplay),
                fontSize = 12,
                opacity = 0.7
            }),
        }),
    }

    if not isCompleted then
        table.insert(rowContent, ui.button({
                text = "+1",
                variant = "secondary",
                controlSize = "sm",
                onClick = function()
                    -- Update episode count
                    noctalia.notify("MAL", "Incremented " .. title)
                end
            })
        )
    end

    return ui.row({
        padding = 8,
        gap = 12,
        align = "center",
        justify = "space_between",
        onClick = function()
            onSelectEntry(entry)
        end
    }, rowContent)
end

local function buildMangaRow(entry)
    local manga = entry.node
    local status = entry.list_status

    local currentChptr = (status and status.num_chapters_read) or 0
    local totalChptr = manga.num_chapters or 0

    local isCompleted = (status and status.status == "completed") or (totalChptr > 0 and currentChptr >= totalChptr)
    local totalChptrDisplay = (totalChptr > 0) and tostring(totalChptr) or "?"

    local title = getDisplayTitle(manga)

    local rowContent = {
        ui.column({
            flexGrow = 1,
            gap = 4,
            align = "start",
        }, {
            ui.label({
                text = title,
                fontWeight = "semibold",
                maxWidth = 320,
            }),
            ui.label({
                text = string.format("Ch %d / %s", currentChptr, totalChptrDisplay),
                fontSize = 12,
                opacity = 0.7
            }),
        }),
    }

    if not isCompleted then
        table.insert(rowContent, ui.button({
                text = "+1",
                variant = "secondary",
                controlSize = "sm",
                onClick = function()
                    -- Update episode count
                    noctalia.notify("MAL", "Incremented " .. title)
                end
            })
        )
    end

    return ui.row({
        padding = 8,
        gap = 12,
        align = "center",
        justify = "space_between",
        onClick = function()
            onSelectEntry(entry)
        end
    }, rowContent)
end

local function buildList()
    local username = noctalia.state.get("mal:username") or "User"

    local rowElements = {}

    if not listLoaded then
        table.insert(rowElements, ui.row({padding = 16, justify = "center"}, {
            ui.label({text = "Loading " .. currentList .. " list...", opacity = 0.6})
        }))
    else
        if currentList == "anime" then
            for index, item in ipairs(animeList) do
                table.insert(rowElements, buildAnimeRow(item))
                table.insert(rowElements, ui.separator({ opacity = 0.3 }))
            end
        else
            for index, item in ipairs(mangaList) do
                table.insert(rowElements, buildMangaRow(item))
                table.insert(rowElements, ui.separator({ opacity = 0.3 }))
            end
        end
    end

    return ui.column({align = "stretch"}, {
        ui.row({align = "center"}, {
            ui.button({
                text = "anime",
                variant = "ghost",
                contentAlign = "center",
                flexGrow = 1,
                selected = (currentList == "anime"),
                onClick = function()
                    if currentList == "manga" then
                        currentList = "anime"
                        listLoaded = false
                        loadCurrentList()
                        render()
                    end
                end
            }),
            ui.separator({orientation = "vertical"}),
            ui.button({
                text = "manga",
                variant = "ghost",
                contentAlign = "center",
                flexGrow = 1,
                selected = (currentList == "manga"),
                onClick = function()
                    if currentList == "anime" then
                        currentList = "manga"
                        listLoaded = false
                        loadCurrentList()
                        render()
                    end
                end
            })
        }),
        ui.separator({orientation = "horizontal"}),
        ui.row({height = 352}, {
            ui.scroll({
                flexGrow = 1,
                align = "stretch",
                gap = 4,
            }, rowElements)
        }),
        ui.row({justify = "space_between", align = "center"}, {
            ui.button({text = "logout", onClick = logout}),
            ui.label({text = username})
        })
    })
end

local function buildEntry(entry, entryType)
    local info = entry.node
    local status = entry.list_status

    local mainContent = {}

    if entryType == "anime" then
        local currentEp = (status and status.num_episodes_watched) or 0
        local totalEp = info.num_episodes or 0

        local isCompleted = (status and status.status == "completed") or (totalEp > 0 and currentEp >= totalEp)
        local totalEpDisplay = (totalEp > 0) and tostring(totalEp) or "?"

        table.insert(mainContent, ui.column({}, {
            ui.label({text = info.title}),
            ui.label({text = currentEp .. "/" .. totalEpDisplay .. " episodes watched"}),
            ui.label({text = ""})
        }))

    elseif entryType == "manga" then
        local currentChptr = (status and status.num_chapters_read) or 0
        local totalChptr = info.num_chapters or 0

        local isCompleted = (status and status.status == "completed") or (totalChptr > 0 and currentChptr >= totalChptr)
        local totalChptrDisplay = (totalChptr > 0) and tostring(totalChptr) or "?"

        table.insert(mainContent, ui.column({}, {
            ui.label({text = info.title}),
            ui.label({text = currentChptr .. "/" .. totalChptrDisplay .. " chapters read"}),
            ui.label({text = ""})
        }))
    end

    return ui.column({}, {
        ui.row({}, {
            ui.button({
                text = "back",
                onClick = function()
                    currentView = "list"
                    render()
                end
            })
        }),
        ui.row({}, mainContent)
    })
end

render = function()
    if currentView == "login" then
        panel.render(buildLogin())
    elseif currentView == "list" then
        panel.render(buildList())
    elseif currentView == "code" then
        panel.render(buildCode())
    elseif currentView == "entry" then
        panel.render(buildEntry(currentEntry, currentList))
    end
end

function onOpen()
    local authenticated = DATA_DIR and (DATA_DIR .. "/auth.json")

    if authenticated and noctalia.fileExists(authenticated) then
        currentView = "list"
        if not noctalia.state.get("mal:username") then
            fetchUserProfile(function(profile)
                local username = profile.name

                noctalia.state.set("mal:username", username)
            end)
        end
        loadCurrentList()
    end

    render()
end

function onClose()

end
