-- TODO Auto Continue after reboot
-- TODO Search Inventory for fuel if nothing left in fuel slot

-- Config
local INV_CONFIG = {
    nil,nil, nil, nil,
    nil,nil, nil, nil,
    nil,nil, nil, nil,
    "storage", "light", "light", "fuel",
}

local LIGHT_SLOT = 15
local LIGHT_ID = "minecraft:torch"

local FUEL_SLOT = 16
local FUEL_ID = "minecraft:coal"

-- rednet globals
local MODEM_SIDE = "left"
local PROTOCOL_LOG = "LOG"
local PROTOCOL_RC = "RC"

-- UI globals
local TOUCH_EVENT = "mouse_click"
local PROCESS_IS_RUNNING = false;
local LOG_FILE_PATH = "logs/" .. os.date("%F") .. ".log"
local LOGS = {}

-- [DONT CHANGE] CONSTANTS [DONT CHANGE]
local NORTH = 0
local EAST = 1
local SOUTH = 2
local WEST = 3

local HEIGHT = 13
local WIDTH = 39
local WAIT_FOR_INPUT = 1;

--#region Imports
function Import(modname)
    if not fs.exists("/libs/" .. modname .. ".lua") then
        local request = http.get("https://raw.githubusercontent.com/m4schini/cc-programs/main/libs/" .. modname .. ".lua")
        if request ~= nil then 
            local handler = fs.open("/libs/" .. modname .. ".lua", "w");
            handler.write(request.readAll())
            handler.close()
        end
    end
    return require("/libs/" .. modname)
end

local uiLib = Import("ui")
local osLib = Import("os")

--#region Misc stuff


--true, if event happened
function WaitForEvent(seconds, inputEvent)
    local function timeout()
        os.sleep(seconds)
    end
    
    local eventHappened = false;
    local function waitForEvent()
        repeat
            local event, _ = os.pullEvent(inputEvent)
        until event == inputEvent
        eventHappened = true;
    end

    parallel.waitForAny(timeout, waitForEvent)
    return eventHappened
end

function Log(msg, level)
    level = level or "info"
    table.insert(LOGS, 1, {time=os.time("utc"), clock=os.clock(), level=level, log=msg})

    local function logLocal()
        local h, err = fs.open(LOG_FILE_PATH, fs.exists(LOG_FILE_PATH) and "a" or "w")

        if h ~= nil then
            h.write(os.date("%c") .. " > [" .. level .. "] " .. msg .. "\n")
            h.flush()
            h.close()
        else
            print(err)
        end

    end

    local function logRemote()
        if peripheral.isPresent(MODEM_SIDE) then
            rednet.open(MODEM_SIDE)
            rednet.broadcast({sender=os.getComputerLabel(), time=os.time("utc"), clock=os.clock(), level=level, log=msg}, PROTOCOL_LOG)
            rednet.close()
        end
    end

    parallel.waitForAll(logLocal, logRemote)
end

function Error(msg)
    msg = msg or "Something went wrong"
    local pos = HEIGHT - 1
    Log(msg, "error")

    paintutils.drawLine(1, pos, WIDTH, pos, colors.red)
    term.setCursorPos(1, pos)
    term.setTextColor(colors.black)
    term.write(os.time("utc") .. "> " .. msg)

    term.setTextColor(colors.white)
end

--#region Turtle class
Turtle = {
    label = "name",
    heading = 0,
    position={x = 0, y = 0, z = 0}
}

-- Turtle constructor
function Turtle:new (o, heading, position)
    o = o or {}
    setmetatable(o, self)
    self.__index = self


    self.position = position
    

    local function determineHeading()
        local head = -1;

        for i = 1, 4, 1 do
            if head == -1 and turtle.forward() then
                local success, x, y, z = self:gpsLocate()

                if not success then
                    return 0;
                else
                    if x > position.x then
                        head = (EAST - (i - 1)) % 4;
                    elseif x < position.x then
                        head = (WEST - (i - 1)) % 4;
                    elseif z > position.z then
                        head = (SOUTH - (i - 1)) % 4
                    elseif z < position.z then
                        head = (NORTH - (i - 1)) % 4
                    end
                end

                turtle.back()
            end
            turtle.turnRight()
        end
        if head == -1 then
            head = 0
        end

        return head
    end

    self.heading = heading or determineHeading()
    o:__localUpdate()
    return o
end

function Turtle:init()
    Log("+++ booting turtle +++", "boot")

    local newTurtle = nil
    local function turtleFromInput()
        Log("Turtle was started in Manual Mode", "warning")
        print("You entered manual mode, if this was an accident, reboot turtle (CTRL + R)")
        print("\nEnter coordinates of Turtle:")

        print("x:")
        local xInput = tonumber(read())
        print("y:")
        local yInput = tonumber(read())
        print("z:")
        local zInput = tonumber(read())

        print("Enter the direction the turtle is heading")
        print("NORTH=0, EAST=1, SOUTH=2, WEST=3")
        local heading = tonumber(read())
        term.clear()

        return Turtle:new(nil, heading, {x = xInput, y = yInput, z = zInput})
    end
    
    print("Booting turtle...")
    if WaitForEvent(WAIT_FOR_INPUT, "key") then
        newTurtle = turtleFromInput()
    else
        if self:gpsLocate() then
            --coordinates
            local _, x, y, z = self:gpsLocate()
            local position = {x = x, y = y, z = z}

            --heading = nil => determine on your own
            newTurtle = Turtle:new(nil, nil, position)
        else
            newTurtle = self:__localRestore()
            if newTurtle == nil then
                newTurtle = turtleFromInput()
            end
        end
    end

    Log("turtle ready", "boot")
    return newTurtle
end

---- helper functions
function Turtle:scan(direction)
    direction = direction or "front"

    local scanned, details;
    if direction == "front" then
        scanned, details = turtle.inspect()
    elseif direction == "up" then
        scanned, details = turtle.inspectUp()
    elseif direction == "down" then
        scanned, details = turtle.inspectDown()
    end

    if scanned then
        return true, details
    else
        return false, nil
    end
end

function Turtle:scanAll()
    local _, up = turtle.inspectUp()
    local _, front = turtle.inspect()
    local _, down = turtle.inspectDown()

    return {
        up=up,
        front=front,
        down=down,
    }
end

function Turtle:scanSurroundings()
    local scanResults = self:scanAll()

    self:turnRight()
    _, scanResults.right = self:scan()

    self:turnRight()
    _, scanResults.back = self:scan()

    self:turnRight()
    _, scanResults.left = self:scan()

    self:turnRight()
    return scanResults
end

function Turtle:__blockInFront()
    local scan = nil;
    local block = false;

    block, scan = turtle.inspect()
    if block then
        return scan["name"]
    else
        return ""
    end
end

function Turtle:__isChestInFront()
    local foundChest = false; 
    foundChest = self:__blockInFront():find("chest")
    return foundChest
end

---- data functions (update persistant and remote data)
local PERSITANT_DATA_FILE_NAME = "persistant.json"

function Turtle:__localUpdate()
    local h = fs.open(PERSITANT_DATA_FILE_NAME, "w")
    h.write(
        textutils.serializeJSON({
            heading=self.heading,
            position=self.position,
        })
    )
    h.flush()
    h.close()
end

function Turtle:__localRestore()
    if fs.exists(PERSITANT_DATA_FILE_NAME) then
        local h = fs.open(PERSITANT_DATA_FILE_NAME, "r")
        local json = h.readAll()
        local data = textutils.unserializeJSON(json)
    
        return Turtle:new(nil, data.heading, data.position);
    end
    return nil
end

---- position functions

--changes current position data of turtle
--distance: distance in blocks 
--vertical: true, if movement is on vertical axis
function Turtle:changePosition(distance, vertical)
    if vertical then
        self.position.y = self.position.y + distance
    else
        if self.heading == NORTH then
            self.position.z = self.position.z - distance
        elseif self.heading == EAST then
            self.position.x = self.position.x + distance
        elseif self.heading == SOUTH then
            self.position.z = self.position.z + distance
        elseif self.heading == WEST then
            self.position.x = self.position.x - distance
        end
    end

    --Log("New Position: " .. textutils.serialize(self.position):gsub("\n", ""):gsub(" ", ""))
    self:__localUpdate()
end

function Turtle:changeHeading(rotation)
    self.heading = (self.heading + rotation) % 4

    --Log("New Heading: " .. textutils.serialize(self.heading))
    self:__localUpdate()
end

function Turtle:distanceTo(destination)
    local distances = {
        x = destination.x - self.position.x,
        y = destination.y - self.position.y,
        z = destination.z - self.position.z,
    }

    return math.abs(distances.x) + math.abs(distances.y) + math.abs(distances.z)
end

function Turtle:gpsLocate()
    local x, y, z = gps.locate()
    if x == nil then
        return false, 0, 0, 0
    else 
        return true, x, y, z
    end
end

-- function Turtle:getSignalStrength()
    -- rednet.open(peripheral.getNames()[1])
    -- local echoChambers = rednet.lookup(ECHO_PROTOCOL)
    -- local strength = 0
-- 
    -- if echoChambers ~= nil then
        -- rednet.broadcast("PING", ECHO_PROTOCOL)
        -- local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        -- strength = math.floor((1 - (distance / 380)) * 100)                
    -- end
    -- 
    -- rednet.close()
    -- return strength
-- end

---- movement functions

-- Derived class method move
function Turtle:moveForward()
    if turtle.forward() then
        self:changePosition(1, false)
        return true
    end
    return false
end

function Turtle:moveBack()
    if turtle.back() then
        self:changePosition(-1, false)
        return true
    end
    return false
end

function Turtle:moveDown()
    if turtle.down() then
        self:changePosition(-1, true)
        return true
    end
    return false
end

function Turtle:moveUp()
    if turtle.up() then
        self:changePosition(1, true)
        return true
    end
    return false
end

-- moves to specified coords, returns true if successful
function Turtle:moveTo(destination)
    local distances = {
        x = destination.x - self.position.x,
        y = destination.y - self.position.y,
        z = destination.z - self.position.z,
    }
    Log("Moving to: " .. destination.x .. " " .. destination.y .. " " .. destination.z)

    -- move to Y coord
    Log("Moving to y=" .. destination.y)
    if distances.y <= 0 then
        for _ = 1, math.abs(distances.y), 1 do
            if not self:digMoveDown() then
                return false
            end
        end
    else
        for _ = 1, distances.y, 1 do
            if not self:digMoveUp() then
                return false
            end
        end
    end
    
    -- move to X coord
    if distances.x < 0 then
        --for _ = 1, ((WEST + self.heading) % 4), 1 do
        --    self:turnRight()
        --end
        Log("turning WEST")
        self:turnTo(WEST)
    elseif distances.x > 0 then
        --for _ = 1, ((EAST + self.heading) % 4), 1 do
        --    self:turnRight()
        --end
        Log("turning EAST")
        self:turnTo(EAST)
    end
    Log("Moving to x=" .. destination.x)
    for _ = 1, math.abs(distances.x), 1 do
        if not self:digMove() then
            return false
        end
    end

    -- move to Z coord
    if distances.z < 0 then
        --for _ = 1, ((SOUTH + self.heading) % 4), 1 do
        --    self:turnRight()
        --end
        Log("turning NORTH")
        self:turnTo(NORTH)
    elseif distances.z > 0 then
        --for _ = 1, ((NORTH + self.heading) % 4), 1 do
        --    self:turnRight()
        --end
        Log("turning SOUTH")
        self:turnTo(SOUTH)
    end
    Log("Moving to z=" .. destination.z)
    for _ = 1, math.abs(distances.z), 1 do
            if not self:digMove() then
                return false
            end
    end

    return true
end

function Turtle:turnRight()
    if turtle.turnRight() then
        self:changeHeading(1)
    end
end

function Turtle:turnLeft()
    if turtle.turnLeft() then
        self:changeHeading(-1)
    end
end

function Turtle:turnTo(facing)
    --for _ = 1, ((facing + self.heading) % 4), 1 do
    --    self:turnRight()
    --end

    local diffrence = self.heading - facing
    print(diffrence)
    if diffrence == 0 then
        return
    elseif diffrence < 0 then
        for _ = 1, math.abs(diffrence), 1 do
            self:turnRight()
        end
    elseif diffrence > 0 then
        for _ = 1, diffrence, 1 do
            self:turnLeft()
        end
    end
end

---- Place functions
function Turtle:place(slot)
    turtle.select(slot or turtle.getSelectedSlot())
    return turtle.place()
end

function Turtle:placeUp(slot)
    turtle.select(slot or turtle.getSelectedSlot())
    return turtle.placeUp()
end

function Turtle:placeDown(slot)
    turtle.select(slot or turtle.getSelectedSlot())
    return turtle.placeDown()
end

---- Digging functions

function Turtle:dig()
    while turtle.detect() do
        turtle.dig()
    end
end

function Turtle:digDown()
    while turtle.detectDown() do
        turtle.digDown()
    end
end

function Turtle:digUp()
    while turtle.detectUp() do
        turtle.digUp()
    end
end

function Turtle:digMove()
    self:dig()
    return self:moveForward()
end

function Turtle:digMoveUp()
    self:digUp()
    return self:moveUp()
end

function Turtle:digMoveDown()
    self:digDown()
    return self:moveDown()
end

function Turtle:dropTnt()
    local slot, count = self:invFindItem("minecraft:tnt", 1, 16)
    if slot > 0 then
        self:place(slot)
        sleep(0.1)
        redstone.setOutput("front", true)
        sleep(0.1)
        redstone.setOutput("front", false)
    else
        Error("No TNT in Inventory")
    end
end

---- Inventory functions

-- true, if the specified inventory space is full
function Turtle:getInventory(startslot, endslot)
    startslot = startslot or 1
    endslot = endslot or 16
    
    local inv = {}

    for i = startslot, endslot, 1 do
        inv[i] = turtle.getItemDetail(i)
    end

    return inv
end

function Turtle:invIsFull(startSlot, endSlot)
    for i = startSlot, endSlot, 1 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    Log("Inventory is full")
    return true
end

function Turtle:invToChest(startSlot, endSlot)
    local empty = false;
    for _ = 1, 4, 1 do
        self:turnLeft()
        if self:__isChestInFront() then
            for i = startSlot, endSlot, 1 do
                turtle.select(i)
                turtle.drop(turtle.getItemCount(i))
            end
            empty = true
            turtle.select(1)
        end
    end
    
    Log("Emptied inventory: " .. tostring(empty))
    return empty
end

--searches turtle inventory from startSlot to endSlot
--returns slot and count of item in slot if found.
--        if not found, return -1 and 0
function Turtle:invFindItem(id, startSlot, endSlot)
    for i = startSlot, endSlot, 1 do
        local slot = turtle.getItemDetail(i)
        if slot ~= nil and slot.name == id then
            return i, slot.count
        end
    end
    return -1, 0
end

function Turtle:invGetItemCount(id)
    local offset = 1
    local slot, count = 1, 0

    local amount = 0;

    repeat
        slot, count = self:invFindItem(id, offset, 16)
        if slot ~= -1 then
            amount = amount + count
            offset = slot + 1
        end
    until slot == -1 or offset == 17

    return amount
end

function Turtle:__findInInvConfig(label, startSlot)
    for i = startSlot, #INV_CONFIG, 1 do
        if INV_CONFIG[i] == label then
            return i
        end
    end
    return -1;
end

function Turtle:getSlotWithLabel(label)
    local slot = 0
    repeat
        slot = self:__findInInvConfig(label, slot + 1)
        local empty = true
        if slot ~= -1 then
            empty = turtle.getItemCount(slot) > 0
        else
            Error(label .. " slots are empty")
            return -1
        end
    until not empty
    
    return slot
end

function Turtle:getInvFuelSlot()
    local LABEL = "fuel"
    local slot = 1
    repeat
        slot = self:__findInInvConfig(LABEL)
        local empty = true
        if slot ~= -1 then
            empty = turtle.getItemCount(slot) > 0
        else
            Error(LABEL .. " slots are empty")
            return -1
        end
    until not empty 
    
    return slot
end

function Turtle:getInvLightSlot()
    
end

function Turtle:getInvStorageSlot()
    
end

---- Fuel functions

--checks if there is enough fuel to go back to the starting point
function Turtle:__isBelowMinFuelLevel()
    term.setCursorPos(1,1)
    print(turtle.getFuelLevel(), turtle.getFuelLevel() < 1000)
    return turtle.getFuelLevel() < 1000
    --return (distance + distance * 0.2) > turtle.getFuelLevel()
end

function Turtle:__handleRefuel(returnPosition)
    while self:__isBelowMinFuelLevel() do
        Log("Turtle need to be refuelled (" .. turtle.getFuelLevel() .. ")")

        local fuelDetails = turtle.getItemDetail(FUEL_SLOT)
        if fuelDetails ~= nil and fuelDetails["name"] == FUEL_ID then
            turtle.select(FUEL_SLOT)
            turtle.refuel(1)
            turtle.select(1)
        else
            if returnPosition ~= nil then
                self:moveTo(returnPosition)
            else
                Error("[No Fuel] No return pos provided")
            end
            break
        end
    end
end

---- Tunnel functions

--digs a tunnel slice of height 2 and width 1
function Turtle:__placeTorch()
    if turtle.detectUp() then
        turtle.digUp()
    end

    local slotDetails = turtle.getItemDetail(LIGHT_SLOT)
    if slotDetails ~= nil and slotDetails["name"] == LIGHT_ID then
        turtle.select(LIGHT_SLOT)
        turtle.placeUp()
    end
    
    turtle.select(1)
end

function Turtle:__digSlice()
    self:dig()
    self:moveForward()

    --place block under turtle
    if not turtle.detectDown() then
        turtle.select(1)
        turtle.placeDown()
    end

    self:digUp()
end

function Turtle:digTunnel(length, placeTorch)
    for i = 1, length, 1 do
        self:__digSlice()

        if placeTorch and i == math.ceil(length/2) + 1 then
            self:moveBack()
            self:__placeTorch()
            self:moveForward()
        end
    end
end

function Turtle:__digTunnelMoveBack(length, placeTorch)
    self:digTunnel(length, placeTorch)
    for i = 1, length, 1 do
        self:moveBack()
    end
end

function Turtle:stripMine(startPos)
    startPos = startPos or {x=self.position.x, y=self.position.y, z=self.position.z, heading=self.heading}
    local MAIN_UNIT_LENGTH = 3;
    local SIDE_TUNNEL_LENGTH = 5;

    while not self:invIsFull(1, 14) do
        -- part of main tunnel
        self:digTunnel(MAIN_UNIT_LENGTH, true)
        self:__digSlice()
        
        -- right side tunnel
        self:turnRight()
        self:__digTunnelMoveBack(SIDE_TUNNEL_LENGTH, false)        
        
        -- left side tunnel
        self:turnRight()
        self:turnRight()
        self:__digTunnelMoveBack(SIDE_TUNNEL_LENGTH, false)

        -- back to main tunnel orientation
        self:turnRight()
        self:__handleRefuel(startPos)
    end
    Log("Mining Inventory Full")

    local stopPos = {x=self.position.x, y=self.position.y, z=self.position.z}
    self:moveTo(startPos)
    self:invToChest(1, 14)
    self:moveTo(stopPos)

    self:stripMine(startPos)
end

function Turtle:chunkMine(depth, length)
    local DEPTH = depth or 16
    local LENGTH = length or 16
    local turnedLeft = false

    for _ = 1, DEPTH, 1 do
        for i = 1, LENGTH, 1 do
            for _ = 1, LENGTH-1, 1 do
                self:digMove()
            end

            if i < LENGTH then
                if turnedLeft then
                    self:turnRight()
                    self:digMove()
                    self:turnRight()
                    turnedLeft = false
                else
                    self:turnLeft()
                    self:digMove()
                    self:turnLeft()
                    turnedLeft = true
                end
            else
                self:turnLeft()
                self:digMoveDown()
                turnedLeft = false;
            end
        end
    end
end

---- Build Functions

function Turtle:placeHorizontalFlat(material, length, width, replace, placeUp)
    local origin = {x=self.position.x, y=self.position.y, z=self.position.z}
    local oHeading = self.heading
    placeUp = placeUp or false --usual usecase: build roof
    replace = replace or false; --digging down before place floor
    
    

    local slot, count = self:invFindItem(material, 1 ,16)
    local turnedRight = false;
    local function place(slot)
        local placeFunction;

        if placeUp then
            placeFunction = self.placeUp
        else
            placeFunction = self.placeDown
        end

        if count > 0 then
            if placeFunction(slot) then
                count = count - 1;
            end
        else
            slot, count = self:invFindItem(material, slot + 1, 16)
            if placeFunction(slot) then
                count = count - 1;
            end
        end
    end

    for w = 1, width, 1 do
        for l = 1, length, 1 do
            self:digMove()
            self:digUp()

            if replace then
                if placeUp then
                    self:digUp()
                else
                    self:digDown()
                end
            end

            if count > 0 then
                place(slot)
            else
                slot, count = self:invFindItem(material, slot + 1, 16)
                place(slot)
            end
        end

        if w < width then
            if turnedRight then
                self:digMove()
                self:turnLeft()
                self:digMove()
                self:turnLeft()
                turnedRight = false;
            else
                self:digMove()
                self:turnRight()
                self:digMove()
                self:turnRight()
                turnedRight = true
            end
        end
    end

    self:moveTo(origin)
    self:turnTo(oHeading)
    return 0, 0
end

--#endregion

---- TURTLE OBJECT!
local this = Turtle:init()

--#region ui

function UiDebug(system, openLogs)
    openLogs = openLogs or false
    system.out.clear()

    --line 1
    local headingStr = "ERR"
    if this.heading == 0 then
        headingStr = "NORTH"
    elseif this.heading == 1 then
        headingStr = "EAST"
    elseif this.heading == 2 then
        headingStr = "SOUTH"
    elseif this.heading == 3 then
        headingStr = "WEST"
    end
    system.out.setCursorPos(1)
    system.out.println("Pos: " .. "{" .. this.position.x .. ", " .. this.position.y .. ", " .. this.position.z .. "} " .. "Heading: " .. headingStr)        

    --line 2
    system.out.setCursorPos(2)
    system.out.println("Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit())

    --line 3
    paintutils.drawLine(1, 3, WIDTH, 3, colors.gray)
    system.out.setCursorPos(3)
    system.out.println("Logs (" .. table.maxn(LOGS) .. ")", nil, colors.gray)
    local function showLogs()
        --line 4 to height-1
        term.setBackgroundColor(colors.black)
        for i = 1, HEIGHT-5, 1 do
            local msg = LOGS[i] or ""
            if msg ~= "" then
                msg = "[" .. msg.level .. "] " .. msg.clock .. "s:" .. msg.log
            end
            system.out.setCursorPos(i+3)
            system.out.println(msg)
        end
    end    
    system:addButton({x=WIDTH/2 - 5, y=3}, {x=WIDTH/2 + 7, y=3}, "show logs", showLogs, nil, colors.lightGray)
    showLogs()
    --ui:awaitTouch()
end


--#endregion

--#region Remote Control
RemoteControl = {
    actions = {}
}

function RemoteControl:new(o, actions)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function RemoteControl:run()
    if peripheral.isPresent(MODEM_SIDE) then
        rednet.host(PROTOCOL_RC, os.getComputerLabel())
        rednet.open(MODEM_SIDE)
        while true do
            local event, sender, message, protocol = os.pullEvent("rednet_message")
            if protocol == PROTOCOL_RC then
                if false then
                    rednet.send(sender, {type="error", payload="Turtle is busy"}, PROTOCOL_RC)
                else
                    local response = "no response";
                    local responseType = nil
                    if message.type == "cmd" then
                        if message.payload == "moveForward" then
                            response = this:moveForward()
                        elseif message.payload == "moveUp" then
                            response = this:moveUp()
                        elseif message.payload == "moveDown" then
                            response = this:moveDown()
                        elseif message.payload == "moveBack" then
                            response = this:moveBack()
                        elseif message.payload == "turnLeft" then
                            response = this:turnLeft()
                        elseif message.payload == "turnRight" then
                            response = this:turnRight()
                        elseif message.payload == "digForward" then
                            response = this:dig()
                        elseif message.payload == "digUp" then
                            response = this:digUp()
                        elseif message.payload == "digDown" then
                            response = this:digDown()
                        elseif message.payload == "inventory" then
                            response = this:getInventory()
                            responseType = "INV"
                        elseif message.payload == "scan" then
                            response = this:scanSurroundings()
                            responseType = "SCAN"
                        end
                    end

                    rednet.send(sender, {
                        type="response", 
                        payload=response,
                        payloadType=responseType,
                        position={
                            x=this.position.x, 
                            y=this.position.y,
                            z=this.position.z,
                            heading=this.heading
                        }, 
                        scan=this:scanAll()
                    }, PROTOCOL_RC)
                end
            end
        end
    end
    
end
--#endregion

--#region Builder Programs
function BuildBridge(system)
    system.out.clear()
    print("Bridge Specifications: ")

    term.write("length: ")
    local length = tonumber(read())

    term.write("width: ")
    local width = tonumber(read())

    term.write("replace ground [y/N]: ")
    local replace = read() == "y"
    
    term.write("build roof [y/N]: ")
    local roof = read() == "y"

    print("material (def.: minecraft:cobblestone): ")
    local material = read()
    if material == "" then
        material = "minecraft:cobblestone"
    end

    local neededMaterial = 0
    if roof then
        neededMaterial = length * width * 2
    else
        neededMaterial = length * width
    end
    local materialAmount = this:invGetItemCount(material)

    if neededMaterial > materialAmount then
        Error("Not enough material. \n"
                        .. "Needed: " .. neededMaterial .. "\nAvailable: " .. materialAmount)
        return neededMaterial, materialAmount
    end

    system.out.clear()
    this:placeHorizontalFlat(material , length, width, replace)
    if roof then
        this:moveUp()
        this:placeHorizontalFlat(material , length, width, replace, true)
        this:moveDown()
    end
end

function BuildLadder(system)
    system.out.clear()
    term.write("Down or up? [D/u]: ")
    local goup = read() == "u"

    term.write("Distance: ")
    local distance = tonumber(read())

    print("Line 3: Filler")
    print("Line 4: Ladder")


    local function down()
        this:digMoveDown()
    end
    local function up()
        this:digMoveUp()
    end

    local digF = up
    if not goup then
        digF = down
    end
    local returnF = down
    if not goup then
        returnF = up
    end

    local function getSlot(slot, limit)
        if slot > limit then
            return -1
        end
        if turtle.getItemCount(slot) <= 0 then
            return getSlot(slot + 1, limit)
        end

        return slot
    end


    for i = 1, distance, 1 do
        digF()
        this:place(getSlot(9, 12))
    end
    for _ = 1, distance, 1 do
        returnF()
        if goup then
            this:placeUp(getSlot(13, 16))
        else
            this:placeDown(getSlot(13, 16))
        end
    end
end

function UiHandleBuild(system)
    system.out.clear()
    system:addButton({x=0, y=0}, {x=WIDTH/2, y=HEIGHT-1}, "Bridge", BuildBridge, nil, colors.red)
    system:addButton({x=WIDTH/2, y=0}, {x=WIDTH, y=HEIGHT-1}, "Ladder", BuildLadder, nil, colors.lightGray)
    system:awaitTouch()
end
--#endregion


function UiHandleMine(system)
    local function stripMine()
        this:stripMine()
    end

    local function chunkMine()
        this:chunkMine()
    end

    system.out.clear()
    system:addButton({x=0, y=0}, {x=WIDTH/2, y=HEIGHT-1}, "Stripmine", stripMine)
    system:addButton({x=WIDTH/2, y=0}, {x=WIDTH, y=HEIGHT-1}, "ChunkMine", chunkMine)
    system:awaitTouch()
end

function UiHandleRefuel(system)
    system.out.clear()
    print("Coming Soon")
end

function UiHandleMove(system)
    local function moveManually()
        system.out.clear()
        print("w = forward")
        print("a = turn left")
        print("s = back")
        print("d = turn right")
        print("space = up")
        print("ctrl = down")
        print()
        print("r = dig up")
        print("f = dig")
        print("v = dig down")
        print("g = attack")
        print("b = drop tnt")

        while true do
            local event, key, is_held = os.pullEvent("key") 
            if key == keys.w then
                this:moveForward()
            elseif key == keys.a then
                this:turnLeft()
            elseif key == keys.s then
                this:moveBack()
            elseif key == keys.d then
                this:turnRight()
            elseif key == keys.space then
                this:moveUp()
            elseif key == keys.leftCtrl or key == keys.rightCtrl then
                this:moveDown()
            elseif key == keys.r then
                this:digUp()
            elseif key == keys.f then
                this:dig()
            elseif key == keys.v then
                this:digDown()
            elseif key == keys.v then
                turtle.attack()
            elseif key == keys.b then
                this:dropTnt()
            end
        end
    end

    local function moveAuto()
        system.out.clear()
        print("WARNING!")
        print("This auto navigation is pretty dumb. It will go through everything, if it thinks it has to!")
        print("Enter Taget Coordinates")
        term.write("x: ")
        local ix = tonumber(read())
        term.write("y: ")
        local iy = tonumber(read())
        term.write("z: ")
        local iz = tonumber(read())

        system.out.clear()
        print("IM WALKING HERE!")
        print("Distance to target: ", this:distanceTo({x=ix,y=iy,z=iz}))
        this:moveTo({x=ix,y=iy,z=iz})

        system.out.clear()
        print("Arrived at destination")
    end

    system.out.clear()
    local firstLine = "Current Pos:"
    local seconLine =  this.position.x .. ", " .. this.position.y .. ", " .. this.position.z
    term.setCursorPos(math.ceil(WIDTH/2) - math.floor(firstLine:len()/2), 1)
    print(firstLine)
    term.setCursorPos(math.ceil(WIDTH/2) - math.floor(seconLine:len()/2), 2)
    print(seconLine)

    system:addButton({x=0, y=0}, {x=WIDTH/2, y=HEIGHT-1}, "manual", moveManually)
    system:addButton({x=WIDTH/2, y=0}, {x=WIDTH, y=HEIGHT-1}, "auto", moveAuto)
    system:awaitTouch()
end

function UiRemoteControl(system)
    system.out.clear()
    RUNNING = true;

    print("Remote Control | ID: " .. os.getComputerID())
    RemoteControl:new(nil):run()
end

function CuRemoteControl()
    rednet.unhost(PROTOCOL_RC, os.getComputerLabel())
    rednet.close()
    RUNNING = false
end

function CleanUpUi(system)
    system.out.clear()
end

--#region main program
local operatingSystem = osLib:new(nil, {
    {
        name="Debug",
        ui=UiDebug,
    },
    {
        name="Move",
        ui=UiHandleMove,
        cleanup=CleanUpUi
    },
    {
        name="Mine",
        ui=UiHandleMine,
        cleanup=CleanUpUi
    },
    {
        name="Build",
        ui=UiHandleBuild,
        cleanup=CleanUpUi
    },
    {
        name="Remote",
        ui=UiRemoteControl,
        cleanup=CuRemoteControl,
    },
}, 
uiLib)

operatingSystem:run(UiDebug)



--#endregion
