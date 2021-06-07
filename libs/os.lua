-- TODOs
--  -> install
--  -> import

local expect = require("cc.expect").expect
local ui = require("libs/ui2")

local Log = ui.log.file

OS = {
    cid="C" .. os.getComputerID(), -- Computer ID ([Turtle/Computer/Pocket][CC ID])
    handlers={},
    programs={},
    websocket=nil,
    http_url=nil,
    ws_url=nil,
    turtle=nil,
    __controller_map={},
    __conTimer = 0;
}

-- constructor
-- - `o` Turtle Object
-- - `cid` Computer ID
-- - `handlers` Array of event handlers to be added
-- - `websocket` websocket with server connection
-- - `controllerMap` Map of string instructions and corresponding functions
function OS:new(o, cid, handlers, turtle, http_url, ws_url, controller_map)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.turtle = turtle or self.turtle
    self.cid = cid or self.cid
    self.http_url = http_url or self.http_url
    self.ws_url = ws_url or self.ws_url
    self.__controller_map = controller_map or self.__controller_map

    -- register given Handlers
    self:addHandlers(handlers)

    -- register websocket handlers
    self:addHandlers(BuildWebsocketHandlers(self))
    
    self:loadPrograms()
    return o
end

function OS:loadPrograms()
    local programFiles = fs.list("programs");
    Log(programFiles)
    for index, pName in ipairs(programFiles) do
        Log("trying to install " .. pName)

        -- look for file end
        local index = string.find(pName, ".lua")
        -- remove file end, if exists
        if index ~= nil then
            pName = string.sub(pName, 0, index-1)
        end
        local program = require("programs/" .. pName)

        -- install program dependencies
        if program.dependencies ~= nil then
            self:addHandlers(program.dependencies.handlers or {})
        end

        self.programs[pName] = {exe=program.exe, cleanup=program.cleanup}
        Log(pName .. " was installed")
    end
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

function OS:wsSendJSON(data)
    if self.websocket ~= nil then
        self.websocket.send(textutils.serializeJSON({source=self.cid, data=textutils.serializeJSON(data)}))
    else
        Log("[WARN] NO WEBSOCKET FOUND")
    end
end

-- Main program loop. Executes registered event handlers
function OS:run(shell)
    http.websocketAsync(self.ws_url)

    parallel.waitForAll(
        -- user interface
        function ()
            if shell ~= nil then
                shell(self)
            else
                print("WARNING! RUNNING WITHOUT SHELL")
            end
        end,

        -- background process loop
        function ()
            while true do
                -- pack event
                local event = {os.pullEvent()}
                local eventName = event[1]
                if eventName ~= "http_success" and eventName ~= "http_success" and eventName ~= "http_success" then 
                    ui.log.cloud(event, "EVENT") 
                end
        
                -- run registered handlers on event
                for _, eventHandler in pairs(self.handlers[eventName] or {}) do
                    if event ~= nil then
                        eventHandler(unpack(event))
                    else
                        eventHandler()
                    end
                end
                
            end
        end
    )

    
end

--#region FACTORIES
-- used to build certain components in runtime

-- websocket connection handler factory
-- - `operatingSystem` OS instance
-- - **@returns** `Array`<{event: `string`, handler: `function`}
function BuildWebsocketHandlers(operatingSystem) 
    -- websocket timer querer
    local function retryHandshake(_,_,e)
        Log("websocket failed " .. (e or ""))
        Log("starting reconnection attempts")
        operatingSystem.__conTimer = os.startTimer(6)
    end

    -- complete websocket handshake and save connection
    local function completeHandshake(e,url,ws)
        Log("New WebSocket established")

            -- only execute on turtle startup
            if operatingSystem.websocket == nil then
                operatingSystem.websocket=ws -- saving websocket
                operatingSystem.websocket.send(operatingSystem.cid) -- sending identification to server

                -- building the controller with the websocket connection
                -- TODO: remove duplicate controllers
                if operatingSystem.__controller_map ~= nil then
                    local controller = BuildController(operatingSystem.ws_url, operatingSystem.__controller_map, function (data)
                        Log("SENDING: data")
                        operatingSystem.websocket.send(textutils.serializeJSON({source=operatingSystem.cid, data=data}))
                    end)
                    operatingSystem:addHandler("websocket_message", controller)
                end
            else
                operatingSystem.websocket=ws -- saving websocket
                operatingSystem.websocket.send(operatingSystem.cid) -- sending identification to server
            end
    end

    -- retry websocket connection on timer event
    local function startHandshake(_, id)
        if id == operatingSystem.__conTimer then
            http.websocketAsync(operatingSystem.ws_url)
        end
    end

    return {
        {event="websocket_success", handler=completeHandshake},
        {event="timer", handler=startHandshake},
        {event="websocket_failure", handler=retryHandshake},
        {event="websocket_closed", handler=retryHandshake}
    }
end

function BuildController(ctrl_url, instructionMap, responder)
    -- websocket_message event paramters
    return function (_, url, msg)
        Log("[C] CONTROLLER CALLED")
        if url == ctrl_url then
            Log("[C] INSTR:", msg)
            msg = textutils.unserialiseJSON(msg)

            local instructionMap = instructionMap

            local runner = instructionMap[msg.instruction]
            if runner ~= nil then
                local response = runner()
                Log("[C] RUNNER EXECUTED; SENDING RESPONSE")
                Log("R:", response)
                responder({instruction=msg.instruction, response=response})
            end
        end
        Log("[C] CONTROLLER FINISHED")
    end
end
--#endregion

--@OBSOLETE
-- websocket connection handler factory
-- - **@returns** `Array`<{event: `string`, handler: `function`}
--function OS:buildWebsocketHandlers() 
--    -- websocket timer querer
--    local function retryHandshake(_,_,e)
--        Log("websocket failed " .. (e or ""))
--        Log("starting reconnection attempts")
--        self.__conTimer = os.startTimer(6)
--    end
--
--    -- complete websocket handshake and save connection
--    local function completeHandshake(e,url,ws)
--        Log("New WebSocket established")
--
--            -- only execute on turtle startup
--            if self.websocket == nil then
--                self.websocket=ws -- saving websocket
--                self.websocket.send(self.cid) -- sending identification to server
--
--                -- building the controller with the websocket connection
--                -- TODO: remove duplicate controllers
--                if self.__controller_map ~= nil then
--                    local controller = BuildController(self.ws_url, self.__controller_map, function (data)
--                        Log("SENDING: data")
--                        self.websocket.send(textutils.serializeJSON({source=self.cid, data=data}))
--                    end)
--                    self:addHandler("websocket_message", controller)
--                end
--            else
--                self.websocket=ws -- saving websocket
--                self.websocket.send(self.cid) -- sending identification to server
--            end
--    end
--
--    -- retry websocket connection on timer event
--    local function startHandshake(_, id)
--        if id == self.__conTimer then
--            http.websocketAsync(self.ws_url)
--        end
--    end
--
--    return {
--        {event="websocket_success", handler=completeHandshake},
--        {event="timer", handler=startHandshake},
--        {event="websocket_failure", handler=retryHandshake},
--        {event="websocket_closed", handler=retryHandshake}
--    }
--end

return OS