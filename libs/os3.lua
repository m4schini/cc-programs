local expect = require("cc.expect").expect
local Log = print

local WEBSOCKET_RETRY_ATTEMPT_TIMER = 6

OS = {
    cid="C" .. os.getComputerID(),
    event_handlers={},
    programs={},
    appdata={},
}

function OS:new(o, cid, event_handlers)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.cid = cid or self.cid
    self.appdata = {
        websocket_url = nil,
        retry_timer_id = nil
    }

    self:addHandlers(event_handlers)
    self:addHandlers(Factory.makeWebsocketHandlers(self))

    self:loadPrograms()
    return o
end

-- adds an array of handlers
-- expects array of objects {event: string, handler: function}
function OS:addHandlers(handlers)
    expect(1, handlers, "table")
    
    -- add all given handlers to handler map
    for _, value in pairs(handlers) do
        self:addHandler(value.event, value.handler)
    end
end

-- adds a new handlers
--
-- handlers are being triggert by events 
-- in the global event loop
function OS:addHandler(event, handler)
    expect(1, event, "string")      -- event name
    expect(2, handler, "function")  -- event handler funtion

    -- Get saved handlers, then add new handler
    local eventHandlers = self.handlers[event] or {}
    table.insert(eventHandlers, handler)

    -- save handler array in global handlers
    Log("registered handler for " .. event, "SYSTEM STARTUP")
    self.handlers[event] = eventHandlers
end

function OS:loadPrograms()
    local programFiles = fs.list("programs");
    for index, programName in ipairs(programFiles) do
        Log("trying to install " .. programName)

        -- look for file end
        local index = string.find(programName, ".lua")
        -- remove file end, if exists
        if index ~= nil then
            programName = string.sub(programName, 0, index-1)
        end
        local program = require("programs/" .. programName)

        self.programs[programName] = {exe=program.exe, cleanup=program.cleanup}
        Log(programName .. " was installed")
    end
end

function OS:run(shell)
    -- first connection attempt with websocket
    http.websocketAsync(self.ws_url)

    -- tries to initate ui shell
    local function initiateShell()
        if shell ~= nil then
            shell(self)
        else
            Log("[WARN]", "OS running without shell")
        end
    end

    -- starts system loop that handles events
    local function systemLoop()
        while true do
            local event = {os.pullEvent()}
            local eventName = event[1]

            if eventName ~= "http_success" and eventName ~= "http_failure" then
                -- serialize events and send them to the websocket
                local success, result = pcall(textutils.serializeJSON, event)
                if success and self.socket ~= nil then
                    self.socket.send(result)
                end
            end

            -- run registered handlers on event
            for _, eventHandler in pairs(self.handlers[eventName] or {}) do
                eventHandler(unpack(event))
            end
        end
    end

    parallel.waitForAll(
        initiateShell,
        systemLoop
    )
end

Factory = {}

function Factory.makeWebsocketHandlers(system)
    local function retryHandshake()
        system.appdata.retry_timer_id = os.startTimer(WEBSOCKET_RETRY_ATTEMPT_TIMER)
    end

    local function completeHandshake(eventName, url, ws)
        system.socket = ws -- websocket
        system.socket.send(system.cid) -- computer id
    end

    local function startHandshake(eventName, id)
        if id == system.appdata.retry_timer_id then
            http.websocketAsync(system.appdata.websocket_url)
        end
    end
    
    local function handleMessage(eventName, url, message)
        message = textutils.unserializeJSON(message)
        os.queueEvent(table.unpack(message))
    end

    return {
        {event="websocket_success", handler=completeHandshake},
        {event="timer", handler=startHandshake},
        {event="websocket_failure", handler=retryHandshake},
        {event="websocket_closed", handler=retryHandshake},
        {event="websocket_message", handler=handleMessage}
    }
end


return OS