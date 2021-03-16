local SERVER_URL = "http://malteschink.de:51337"

local HEIGHT = 13
local WIDTH = 39
local RUNNING = true;

-- consts
local NORTH = 0
local EAST = 1
local SOUTH = 2
local WEST = 3

local FUEL_SLOT = 16
local FUEL_ID = "minecraft:coal"

local LIGHT_SLOT = 15
local LIGHT_ID = "minecraft:torch"

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


    self.heading = heading
    self.position = position
    self.origin = {x = position.x, y=position.y, z=position.z}
    return o
end

function Turtle:init()
    print("Starting turtle...")
    --TODO print("Press a key if you want to override location")

    local newTurtle = nil --self:__loadLocal()

    if newTurtle == nil then
        print("Enter coordinates of Turtle:")

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

        newTurtle = Turtle:new(nil, heading, {x = xInput, y = yInput, z = zInput})
    end   

    return newTurtle
end

---- helper functions
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
local FILE_NAME = "persistant.data"

function Turtle:__updateLocal()
    local h = fs.open(FILE_NAME, "w")
    h.write(
        textutils.serializeJSON({
            heading=self.heading,
            position=self.position,
        })
    )
    h.flush()
    h.close()
end

function Turtle:__loadLocal()
    if fs.exists(FILE_NAME) then
        local h = fs.open(FILE_NAME, "r")
        local json = h.readAll()
        local data = textutils.unserializeJSON(json)
    
        return Turtle:new(nil, data.heading, data.position);
    end
    return nil
end

function Turtle:__updateRemote()
    local response, err = http.post(SERVER_URL .. "/v1/turtle", "name=" .. os.getComputerLabel()
                .. "&X=" .. self.position.x
                .. "&Y=" .. self.position.y
                .. "&Z=" .. self.position.z)

    if response == nil then
        print("position update failed")
        print(err)
    end
end

---- position functions

--changes current position data of turtle
--distance: distance in blocks 
--vertical: true, if movement is on vertical axis
function Turtle:addToPosition(distance, vertical)
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

    self:__updateLocal()
    self:__updateRemote()
end

function Turtle:changeHeading(rotation)
    self.heading = (self.heading + rotation) % 4

    self:__updateLocal()
end

function Turtle:distanceTo(destination)
    local distances = {
        x = destination.x - self.position.x,
        y = destination.y - self.position.y,
        z = destination.z - self.position.z,
    }

    return math.abs(distances.x) + math.abs(distances.y) + math.abs(distances.z)
end

---- movement functions

-- Derived class method move
function Turtle:moveForward()
    if turtle.forward() then
        self:addToPosition(1, false)
        return true
    end
    return false
end

function Turtle:moveBack()
    if turtle.back() then
        self:addToPosition(-1, false)
        return true
    end
    return false
end

function Turtle:moveDown()
    if turtle.down() then
        self:addToPosition(-1, true)
        return true
    end
    return false
end

function Turtle:moveUp()
    if turtle.up() then
        self:addToPosition(1, true)
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

    -- move to Y coord
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
    if distances.x <= 0 then
        for _ = 1, ((WEST + self.heading) % 4), 1 do
            self:turnRight()
        end
    else
        for _ = 1, ((EAST + self.heading) % 4), 1 do
            self:turnRight()
        end
    end
    for _ = 1, math.abs(distances.x), 1 do
        if not self:digMove() then
            return false
        end
    end

    -- move to Z coord
    if distances.z <= 0 then
        for _ = 1, ((SOUTH + self.heading) % 4), 1 do
            self:turnRight()
        end
    else
        for _ = 1, ((NORTH + self.heading) % 4), 1 do
            self:turnRight()
        end
    end
    for _ = 1, math.abs(distances.z), 1 do
            if not self:digMove() then
                return false
            end
    end

    return true
end

function Turtle:moveToOrigin()
    self:moveTo(self.origin)
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
    for _ = 1, ((facing + self.heading) % 4), 1 do
        self:turnRight()
    end
end

---- Place functions
function Turtle:place(slot)
    turtle.select(slot or 1)
    return turtle.place()
end

function Turtle:placeUp(slot)
    turtle.select(slot or 1)
    return turtle.placeUp()
end

function Turtle:placeDown(slot)
    turtle.select(slot or 1)
    return turtle.placeDown()
end

---- Digging functions

--TODO calc fuel consumption?
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

---- Inventory functions

-- true, if the specified inventory space is full
function Turtle:isInventoryFull(startSlot, endSlot)
    for i = startSlot, endSlot, 1 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end

function Turtle:emptyInv(startSlot, endSlot)
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
    
    return empty
end

--searches turtle inventory from startSlot to endSlot
--returns slot and count of item in slot if found.
--        if not found, return -1 and 0
function Turtle:findInv(id, startSlot, endSlot)
    for i = startSlot, endSlot, 1 do
        local slot = turtle.getItemDetail(i)
        if slot ~= nil and slot.name == id then
            return i, slot.count
        end
    end
    return -1, 0
end

function Turtle:countItem(id)
    local offset = 1
    local slot, count = 1, 0

    local amount = 0;

    repeat
        slot, count = self:findInv(id, offset, 16)
        if slot ~= -1 then
            amount = amount + count
            offset = slot + 1
        end
    until slot == -1 or offset == 17

    return amount
end

---- Fuel functions

--checks if there is enough fuel to go back to the starting point
function Turtle:__isBelowMinFuelLevel()
    term.setCursorPos(1,1)
    print(turtle.getFuelLevel(), turtle.getFuelLevel() < 1000)
    return turtle.getFuelLevel() < 1000
    --local distance = self:distanceTo(self.origin)
    --return (distance + distance * 0.2) > turtle.getFuelLevel()
end

function Turtle:__handleRefuel()
    while self:__isBelowMinFuelLevel() do
        local fuelDetails = turtle.getItemDetail(FUEL_SLOT)
        if fuelDetails ~= nil and fuelDetails["name"] == FUEL_ID then
            turtle.select(FUEL_SLOT)
            turtle.refuel(1)
            turtle.select(1)
            --TODO SEARCH INV
        else
            self:moveTo(self.origin)
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

function Turtle:digSlice()
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
        self:digSlice()

        if placeTorch and i == math.ceil(length/2) + 1 then
            self:moveBack()
            self:__placeTorch()
            self:moveForward()
        end
    end
end

function Turtle:digTunnelMoveBack(length, placeTorch)
    self:digTunnel(length, placeTorch)
    for i = 1, length, 1 do
        self:moveBack()
    end
end

function Turtle:stripMine()
    local MAIN_UNIT_LENGTH = 3;
    local SIDE_TUNNEL_LENGTH = 5;

    while not self:isInventoryFull(1, 14) do
        -- part of main tunnel
        self:digTunnel(MAIN_UNIT_LENGTH, true)
        self:digSlice()
        
        -- right side tunnel
        self:turnRight()
        self:digTunnelMoveBack(SIDE_TUNNEL_LENGTH, false)        
        
        -- left side tunnel
        self:turnRight()
        self:turnRight()
        self:digTunnelMoveBack(SIDE_TUNNEL_LENGTH, false)

        -- back to main tunnel orientation
        self:turnRight()
        self:__handleRefuel()
    end

    local stopPos = {x=self.position.x, y=self.position.y, z=self.position.z}
    self:moveToOrigin()
    self:emptyInv(1, 14)
    self:moveTo(stopPos)

    self:stripMine()
end



---- Build Functions

function Turtle:buildBridge(material, length, width)
    local neededMaterial = length * width
    print("Needed Material: " .. neededMaterial)

    local materialAmount = self:countItem(material)
    print("Stored Material: " .. materialAmount)

    if neededMaterial > materialAmount then
        DisplayError(HEIGHT - 1, _, "Not enough material. \n"
                        .. "Needed: " .. neededMaterial .. "\nAvailable: " .. materialAmount)
        return --TODO return type? (return needed as method break)
    end

    local slot, count = self:findInv(material, 1 ,16)
    local turnedRight = false;
    for w = 1, width, 1 do
        for l = 1, length, 1 do
            self:digMove()
            self:digUp()

            if count > 0 then
                if self:placeDown(slot) then
                    count = count - 1;
                end
            else
                slot, count = self:findInv(material, slot + 1, 16)
                if self:placeDown(slot) then
                    count = count - 1;
                end
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
end

--#endregion

---- TURTLE OBJECT!
local this = Turtle:init()

--#region ui

function ClearTerm(height)
    term.setBackgroundColor(colors.black)

    for i = 1, height, 1 do
        term.setCursorPos(1,i)
        term.clearLine()
    end
    term.setCursorPos(1,1)
end

function WriteOnLine(line, text)
    term.setCursorPos(1,line)
    term.write(text)
    term.setCursorPos(1,1)
end

function Dashboard(height, width)
    while true do
        ClearTerm(height)

        --paintutils.drawFilledBox(1, 1, math.ceil(width/2), height, colors.blue)
        --term.setTextColor(colors.white)
        WriteOnLine(1, "*" .. os.getComputerLabel() .. "* Dashboard")

        WriteOnLine(3, "Fuel: " .. turtle.getFuelLevel())
        WriteOnLine(5, "Position: " .. "{" .. this.position.x .. ", " .. this.position.y .. ", " .. this.position.z .. "}")
        
        term.setCursorPos(1,6)
        term.write("Heading: ")
        if this.heading == 0 then
            term.write("NORTH")
        elseif this.heading == 1 then
            term.write("EAST")
        elseif this.heading == 2 then
            term.write("SOUTH")
        elseif this.heading == 3 then
            term.write("WEST")
        end


        FuelLevel(width - 2, 1, height, 2)

        sleep(1)
    end
end

function FuelLevel(x, y, height, width)
    paintutils.drawFilledBox(x, y, x + width, y + height - 1, colors.gray)

    local normFuelLevel = ((turtle.getFuelLimit() - turtle.getFuelLevel()) % 100) % height
    paintutils.drawFilledBox(
        x, 
        height,  
        x + width,
        height - normFuelLevel,
        colors.green)
end

function DisplayError(height, _, err)
    ClearTerm(height)

    term.setCursorPos(1,1)
    term.setTextColor(colors.red)

    print(err or "Something went wrong :(")
end

Ui = {
    menu = {
        {name="start", ui=handleDashboard}
    },
    touchHandlers = {}, --{{name=funcName, handler=handleFunc, xStart=0, xEnd=0, y=0}}
    term = {
        height=13,
        width=39
    },
    runningProcess = nil
}

function Ui:new (o, menu, height, width)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.touchHandlers = {}
    self.menu = menu or {{name="start", ui=handleDashboard}, {name="stop", ui=self.stop}}
    self.term = {
        height=height,
        width=width,
    }

    self.runningProcess = nil
    return o
end

function Ui:printColor(str, color)
    local oldColor = term.getTextColor()
    term.setTextColor(color)
    term.write(str)
    term.setTextColor(oldColor)
end

function Ui:__resetCursor()
    term.setCursorPos(1,1)
end

function Ui:__printLine(color, line)
    paintutils.drawLine(1, line, self.term.width, line, color)
end

function Ui:__printStopLine()
    self:__printLine(colors.red, self.term.height)
    term.setCursorPos(math.ceil(self.term.width / 2) - 2, self.term.height)
    term.setTextColor(colors.white)
    term.write("Stop")

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1,1)
end

function Ui:printMenu()
    self.touchHandlers = {} --clean touch handlers

    self:__printLine(colors.lightGray, self.term.height)
    term.setCursorPos(1, self.term.height)

    
    for i, value in ipairs(self.menu) do
        local xC, yC = term.getCursorPos()
        local menuButton = " " .. value.name .. " |"

        table.insert(self.touchHandlers, i, {
            handler = value.ui,
            xStart = xC,
            xEnd = xC + menuButton:len() - 1,
            y = self.term.height
        })

        self:printColor(menuButton, colors.black)
    end

    term.setTextColor(colors.white)
end

function Ui:__runProcess(f)
    local function executeF()
        self:__printStopLine()
        f(self.term.height - 1, self.term.width)
        self:printMenu()
    end
    --function waiting for kill signal
    local function waitForTerminateSignal()
        repeat
            local event, button, x, y = os.pullEvent("mouse_click")
        until y == self.term.height

        --reprint menu
        self:printMenu()
    end

    --finishes if program is finished or kill signal is send
    parallel.waitForAny(executeF, waitForTerminateSignal)
end

--function Ui:__killRunningProcess()
--    term.setCursorPos(1,4)
--    print("trigged kill")
--    if self.runningProcess ~= nil then
--        os.queueEvent("kill_process", self.runningProcess)
--    end
--end

function Ui:__handleTouch(x, y)
    for i, touch in ipairs(self.touchHandlers) do        
        if x >= touch.xStart and x <= touch.xEnd and y == touch.y then
            self:__runProcess(touch.handler or DisplayError)
        end
    end
end

function Ui:run()
    RUNNING = true;
    --add stop button
    --table.insert(self.menu, 1, {name="Stop", nil})

    self:printMenu()
    while RUNNING do
        local event, button, x, y = os.pullEvent("mouse_click")
        self:__handleTouch(x, y)
        sleep(0.1)
    end
end


term.clear()



--#endregion


--#region main program
term.clear()
term.setCursorPos(1,1)

--local this = Turtle:new(nil, NORTH, {x=0,y=0,z=0})


function HandleStripmine()
    this:stripMine()
end

function HandleBuildBridge()
    ClearTerm(HEIGHT - 1)
    term.setCursorPos(1,1)
    print("Bridge Specifications: ")

    term.write("length: ")
    local length = tonumber(read())

    term.write("width: ")
    local width = tonumber(read())

    print("material (def.: minecraft:cobblestone): ")
    local material = read()
    if material == "" then
        material = "minecraft:cobblestone"
    end

    ClearTerm(HEIGHT - 1)
    term.setCursorPos(1,1)
    this:buildBridge(material , length, width)


end

local ui = Ui:new(nil, {
    {
        name="Stats",
        ui=Dashboard,
    },
    {
        name="Mine",
        ui=HandleStripmine
    },
    {
        name="Bridge",
        ui=HandleBuildBridge
    }
}, HEIGHT, WIDTH)
ui:run()

--#endregion
