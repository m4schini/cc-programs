--#region
local LIGHT_SLOT = 15
local LIGHT_ID = "minecraft:torch"

local FUEL_SLOT = 16
local FUEL_ID = "minecraft:coal"

--#region Turtle class
Turtle = {
    label = "name",
    __INV_CONFIG = {},
    __TIME_WAIT_INPUT = 1,

    log=nil,

    heading = 0,
    __HEADING = {
        NORTH = 0,
        EAST = 1,
        SOUTH = 2,
        WEST = 3,
    },

    position={
        x = 0,
        y = 0,
        z = 0
    },
}

-- Turtle constructor
function Turtle:new (o, heading, position, logger, INV_CONFIG)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.__INV_CONFIG = INV_CONFIG or Turtle.__INV_CONFIG
    self.log = logger or print

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
                        head = (Turtle.__HEADING.EAST - (i - 1)) % 4;
                    elseif x < position.x then
                        head = (Turtle.__HEADING.WEST - (i - 1)) % 4;
                    elseif z > position.z then
                        head = (Turtle.__HEADING.SOUTH - (i - 1)) % 4
                    elseif z < position.z then
                        head = (Turtle.__HEADING.NORTH - (i - 1)) % 4
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
    self.log("+++ booting turtle +++", "boot")

    local newTurtle = nil
    local function turtleFromInput()
        self.log("Turtle was started in Manual Mode", "warning")
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
    if WaitForEvent(Turtle.__TIME_WAIT_INPUT, "key") then
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
function Turtle.scan:get(direction)
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

function Turtle.scan:all()
    local _, up = turtle.inspectUp()
    local _, front = turtle.inspect()
    local _, down = turtle.inspectDown()

    return {
        up=up,
        front=front,
        down=down,
    }
end

function Turtle.scan:surroundings()
    local scanResults = self:scanAll()

    self.turn:right()
    _, scanResults.right = turtle.inspect()

    self.turn:right()
    _, scanResults.back = turtle.inspect()

    self.turn:right()
    _, scanResults.left = turtle.inspect()

    self.turn:right()
    return scanResults
end

function Turtle.scan:getName(direction)
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
        return details["name"]
    else
        return ""
    end
end

function Turtle.scan:isChestInFront()
    local foundChest = false; 
    foundChest = self.scan:getName():find("chest")
    return foundChest
end

---- data functions (update persistant and remote data)
local PERSITANT_DATA_FILE_NAME = "persistant.json"

function Turtle.data.persistant:update()
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

function Turtle.data.persistant:restore()
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
function Turtle.location.position:change(distance, vertical)
    vertical = vertical or false

    if vertical then
        self.position.y = self.position.y + distance
    else
        if self.heading == self.__HEADING.NORTH then
            self.position.z = self.position.z - distance
        elseif self.heading == self.__HEADING.EAST then
            self.position.x = self.position.x + distance
        elseif self.heading == self.__HEADING.SOUTH then
            self.position.z = self.position.z + distance
        elseif self.heading == self.__HEADING.WEST then
            self.position.x = self.position.x - distance
        end
    end

    --Log("New Position: " .. textutils.serialize(self.position):gsub("\n", ""):gsub(" ", ""))
    self:__localUpdate()
end

function Turtle.location.heading:change(rotation)
    self.heading = (self.heading + rotation) % 4

    --Log("New Heading: " .. textutils.serialize(self.heading))
    self:__localUpdate()
end

function Turtle.location:distanceTo(destination)
    local distances = {
        x = destination.x - self.position.x,
        y = destination.y - self.position.y,
        z = destination.z - self.position.z,
    }

    return math.abs(distances.x) + math.abs(distances.y) + math.abs(distances.z)
end

function Turtle.location:locate()
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

----#region movement functions

-- Derived class method move
function Turtle.move:forward()
    if turtle.forward() then
        self:changePosition(1, false)
        return true
    end
    return false
end

function Turtle.move:back()
    if turtle.back() then
        self:changePosition(-1, false)
        return true
    end
    return false
end

function Turtle.move:down()
    if turtle.down() then
        self:changePosition(-1, true)
        return true
    end
    return false
end

function Turtle.move:up()
    if turtle.up() then
        self:changePosition(1, true)
        return true
    end
    return false
end

-- moves to specified coords, returns true if successful
function Turtle.move:to(destination)
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

        Log("turning WEST")
        self.turn:To(self.__HEADING.WEST)
    elseif distances.x > 0 then

        Log("turning EAST")
        self.turn:To(self.__HEADING.EAST)
    end
    Log("Moving to x=" .. destination.x)
    for _ = 1, math.abs(distances.x), 1 do
        if not self:digMove() then
            return false
        end
    end

    -- move to Z coord
    if distances.z < 0 then
        Log("turning NORTH")
        self.turn:To(self.__HEADING.NORTH)

    elseif distances.z > 0 then
        Log("turning SOUTH")
        self.turn:To(self.__HEADING.SOUTH)

    end
    Log("Moving to z=" .. destination.z)

    for _ = 1, math.abs(distances.z), 1 do
            if not self:digMove() then
                return false
            end
    end

    return true
end

function Turtle.turn:right()
    if turtle.turnRight() then
        self:changeHeading(1)
    end
end

function Turtle.turn:left()
    if turtle.turnLeft() then
        self:changeHeading(-1)
    end
end

function Turtle.turn:to(facing)
    local diffrence = self.heading - facing
    print(diffrence)
    if diffrence == 0 then
        return
    elseif diffrence < 0 then
        for _ = 1, math.abs(diffrence), 1 do
            self.turn:Right()
        end
    elseif diffrence > 0 then
        for _ = 1, diffrence, 1 do
            self.turn:Left()
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
    return self.move:forward()
end

function Turtle:digMoveUp()
    self:digUp()
    return self.move:up()
end

function Turtle:digMoveDown()
    self:digDown()
    return self.move:down()
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
function Turtle.inv:getDetails(startslot, endslot)
    startslot = startslot or 1
    endslot = endslot or 16
    
    local inv = {}

    for i = startslot, endslot, 1 do
        inv[i] = turtle.getItemDetail(i)
    end

    return inv
end

function Turtle.inv:isFull(startSlot, endSlot)
    for i = startSlot, endSlot, 1 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    Log("Inventory is full")
    return true
end

function Turtle.inv:transferToChest(startSlot, endSlot)
    local empty = false;
    for _ = 1, 4, 1 do
        self.turn:left()
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
function Turtle.inv:find(id, startSlot, endSlot)
    for i = startSlot, endSlot, 1 do
        local slot = turtle.getItemDetail(i)
        if slot ~= nil and slot.name == id then
            return i, slot.count
        end
    end
    return -1, 0
end

function Turtle.inv:count(id)
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

function Turtle.inv.config:find(label, startSlot)
    for i = startSlot, #self.__INV_CONFIG, 1 do
        if self.__INV_CONFIG[i] == label then
            return i
        end
    end
    return -1;
end

function Turtle.inv.config:get(label)
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

function Turtle.inv.config:getFuel()
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

function Turtle.inv.config:getLight()
    
end

function Turtle.inv.config:getStorage()
    
end

---- Fuel functions

--checks if there is enough fuel to go back to the starting point
function Turtle.fuel:isTooLow()--:__isBelowMinFuelLevel()
    term.setCursorPos(1,1)
    print(turtle.getFuelLevel(), turtle.getFuelLevel() < 1000)
    return turtle.getFuelLevel() < 1000
    --return (distance + distance * 0.2) > turtle.getFuelLevel()
end

function Turtle.fuel:refuel(returnPosition)--:__handleRefuel(returnPosition)
    while self.fuel:isTooLow() do
        Log("Turtle need to be refuelled (" .. turtle.getFuelLevel() .. ")")

        local fuelDetails = turtle.getItemDetail(FUEL_SLOT)
        if fuelDetails ~= nil and fuelDetails["name"] == FUEL_ID then
            turtle.select(FUEL_SLOT)
            turtle.refuel(1)
            turtle.select(1)
        else
            if returnPosition ~= nil then
                self.move:to(returnPosition)
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
    self.move:forward()

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
            self.move:back()
            self:__placeTorch()
            self.move:forward()
        end
    end
end

function Turtle:__digTunnelMoveBack(length, placeTorch)
    self:digTunnel(length, placeTorch)
    for i = 1, length, 1 do
        self.move:back()
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
        self.turn:right()
        self:__digTunnelMoveBack(SIDE_TUNNEL_LENGTH, false)        
        
        -- left side tunnel
        self.turn:right()
        self.turn:right()
        self:__digTunnelMoveBack(SIDE_TUNNEL_LENGTH, false)

        -- back to main tunnel orientation
        self.turn:right()
        self:__handleRefuel(startPos)
    end
    Log("Mining Inventory Full")

    local stopPos = {x=self.position.x, y=self.position.y, z=self.position.z}
    self.move:to(startPos)
    self:invToChest(1, 14)
    self.move:to(stopPos)

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
                    self.turn:right()
                    self:digMove()
                    self.turn:right()
                    turnedLeft = false
                else
                    self.turn:left()
                    self:digMove()
                    self.turn:left()
                    turnedLeft = true
                end
            else
                self.turn:left()
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
                self.turn:left()
                self:digMove()
                self.turn:left()
                turnedRight = false;
            else
                self:digMove()
                self.turn:right()
                self:digMove()
                self.turn:right()
                turnedRight = true
            end
        end
    end

    self.move:to(origin)
    self.turn:to(oHeading)
    return 0, 0
end

return Turtle