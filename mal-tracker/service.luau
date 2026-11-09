local CLIENT_ID_FILE = "clientId.json"
local CLIENT_ID = nil

local function clientIdPath()
    local dir = noctalia.pluginDataDir()
    if not dir then
        return nil
    end
    return dir .. "/" .. CLIENT_ID_FILE
end

local function getClientId()
    local path = clientIdPath()
    if not path then return nil end

    local fileContent = noctalia.readFile(path)
    if fileContent then
        local config = noctalia.json.decode(fileContent)
        if config and config.mal_client_id then
            CLIENT_ID = config.mal_client_id
            noctalia.state.set("mal:client_id", CLIENT_ID)
            return CLIENT_ID
        end
    end
    return nil
end


getClientId()
