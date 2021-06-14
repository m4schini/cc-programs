local ops = require("/libs/os")
local ui = require("/libs/ui")
local expect = require("cc.expect").expect

local Log = ui.log.file


Turtle = {
    label = "T" .. os.getComputerID(),
    position = {
        x=0,
        y=0,
        z=0,
        heading = 0
    }
}

local _DIR = {
    NORTH = 0,
    EAST = 1,
    SOUTH = 2,
    WEST = 3
}

-- @constructor
function Turtle:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self:loadPosition()

    return o
end

function Turtle:loadPosition()
    local function getPos()
        local POS_FILE_PATH = "position.json";
        local h, err = fs.open(POS_FILE_PATH, "w")

        local gpsWorked, x, y ,z = Turtle.getGpsPosition()
        if gpsWorked then
            h.write(textutils.serializeJSON({x=x,y=y,z=z}))
            --h.flush()
            h.close()

            return x, y ,z
        elseif fs.exists("position.json") then
            local content = h.readAll()
            if content ~= nil then
                local pos = textutils.unserialiseJSON(content)
                return pos.x, pos.y, pos.z
            end
        else
            return 0,0,0
        end
    end

    local x,y,z = getPos()
    self.position = {
        x=x,
        y=y,
        z=z,
        heading = 0
    }
    Log("Using Coordinates as current Position", self.position)
    os.queueEvent('position', x, y ,z)
    return x, y, z
end


--
--#region MOVEMENT
--

function Turtle.getGpsPosition()
    local x, y, z = gps.locate()
    if x == nil then
        return false, 0, 0, 0
    else 
        return true, x, y, z
    end
end

-- - `horizontal` (optional) horizontal offset
-- - `vertical` (optional) vertical offset
function Turtle:getCoordinate(horizontal, vertical)
    horizontal = horizontal or 1
    vertical = vertical or 0

    local x = self.position.x
    local y = self.position.y + vertical
    local z = self.position.z

    if self.position.heading == _DIR.NORTH then
        z = self.position.z - horizontal
    elseif self.position.heading == _DIR.EAST then
        x = self.position.x + horizontal
    elseif self.position.heading == _DIR.SOUTH then
        z = self.position.z + horizontal
    elseif self.position.heading == _DIR.WEST then
        x = self.position.x - horizontal
    end

    return x, y, z
end

function Turtle:changePosition(horizontal, vertical)
    local x, y, z = self:getCoordinate(horizontal, vertical)

    self.position = {
        x=x,
        y=y,
        z=z,
        heading=self.position.heading
    }
    os.queueEvent('position', x, y ,z)
    return x, y, z
end

function Turtle:changeHeading(rotation)
    self.position.heading = (self.position.heading + rotation) % 4
    os.queueEvent("turtle_turn", rotation)
    return self.position.heading
end

-- Move turtle forward
-- - **@returns** `true` if turtle moved forward
function Turtle:moveForward()
    if turtle.forward() then
        self:changePosition(1, 0)
        return true
    end
    return false
end

-- Move turtle back
-- - **@returns** `true` if turtle moved back
function Turtle:moveBack()
    if turtle.back() then
        self:changePosition(-1, 0)
        return true
    end
    return false
end

-- Move turtle down
-- - **@returns** `true` if turtle moved down
function Turtle:moveDown()
    if turtle.down() then
        self:changePosition(0, -1)
        return true
    end
    return false
end

-- Move turtle up
-- - **@returns** `true` if turtle moved up
function Turtle:moveUp()
    if turtle.up() then
        self:changePosition(0, 1)
        return true
    end
    return false
end

-- Turn turtle right
-- Queues turtle_turn event
function Turtle:turnRight()
    if turtle.turnRight() then
        self:changeHeading(1)
    end
end

-- Turn turtle left.
-- Queues turtle_turn event
function Turtle:turnLeft()
    if turtle.turnLeft() then
        self:changeHeading(-1)
    end
end

--
--#endregion MOVEMENT
--

--[[
    #region UTILITY
]]--

function Turtle.getFuelLevel()
    local fuellevel = turtle.getFuelLevel()
    os.queueEvent("fuel", fuellevel)
    return fuellevel
end

-- inspects the block in front of the turtle
-- - **@event** `"front"` | `data table`
-- - **@returns** `true`, if scanned a block | `data table`
function Turtle:scan()
    local EVENT_NAME = "turtle_scan"
    local SIDE = "front"

    local has_block, data = turtle.inspect()

    local x, y, z = self:getCoordinate(1, 0)
    local pos = {
        x=x,
        y=y,
        z=z
    }

    if has_block then
        os.queueEvent(EVENT_NAME, pos, data)
        return true, data
    else
        os.queueEvent(EVENT_NAME, pos, {name = "minecraft:air"})
        return false, nil
    end
end

-- inspects the block above the turtle
-- - **@event** `"up"` | `data table`
-- - **@returns** `true`, if scanned a block | `data table`
function Turtle:scanUp()
    local EVENT_NAME = "turtle_scan"
    local SIDE = "up"

    local has_block, data = turtle.inspectUp()

    local x, y, z = self:getCoordinate(0, 1)
    local pos = {
        x=x,
        y=y,
        z=z
    }

    if has_block then
        os.queueEvent(EVENT_NAME, pos, data)
        return true, data
    else
        os.queueEvent(EVENT_NAME, pos, {name = "minecraft:air"})
        return false, nil
    end
end

-- inspects the block below the turtle 
-- - **@event** `"down"` | `data table`
-- - **@returns** `true`, if scanned a block | `data table`
function Turtle:scanDown()
    local EVENT_NAME = "turtle_scan"
    local SIDE = "down"

    local has_block, data = turtle.inspectDown()

    local x, y, z = self:getCoordinate(0, -1)
    local pos = {
        x=x,
        y=y,
        z=z
    }

    if has_block then
        os.queueEvent(EVENT_NAME, pos, data)
        return true, data
    else
        os.queueEvent(EVENT_NAME, pos, {name = "minecraft:air"})
        return false, nil
    end
end

--[[
    #endregion UTILITY
]]--

--[[
    #region PLACE
]]--

-- places block in front of turtle
-- - **@param** *slot* slot number of block
-- - **@returns** `true` if block was placed
function Turtle:place(slot)
    turtle.select(slot or turtle.getSelectedSlot())
    return turtle.place()
end

-- places block above the turtle
-- - **@param** *slot* slot number of block
-- - **@returns** `true` if block was placed
function Turtle:placeUp(slot)
    turtle.select(slot or turtle.getSelectedSlot())
    return turtle.placeUp()
end

-- places block below the turtle
-- - **@param** *slot* slot number of block
-- - **@returns** `true` if block was placed
function Turtle:placeDown(slot)
    turtle.select(slot or turtle.getSelectedSlot())
    return turtle.placeDown()
end

--[[
    #endregion PLACE
]]--

--[[
    #region DIGGING
]]--

-- Digs the block in front of the turtle. 
-- **Keeps Digging** until there is no block in front of turtle
function Turtle:dig()
    while turtle.detect() do
        turtle.dig()
    end
end

-- Digs the block below the turtle. 
-- **Keeps Digging** until there is no block below the turtle
function Turtle:digDown()
    while turtle.detectDown() do
        turtle.digDown()
    end
end

-- Digs the block in above the turtle. 
-- **Keeps Digging** until there is no block above the turtle
function Turtle:digUp()
    while turtle.detectUp() do
        turtle.digUp()
    end
end

-- Move one block forward. Will destroy block in front of turtle.
-- - **@returns** `true` if turtle moved forward
function Turtle:digMove()
    self:dig()
    return self:moveForward()
end

-- Move one block up. Will destroy block above turtle.
-- - **@returns** `true` if turtle moved up
function Turtle:digMoveUp()
    self:digUp()
    return self:moveUp()
end

-- Move one block down. Will destroy block below turtle.
-- - **@returns** `true` if turtle moved down
function Turtle:digMoveDown()
    self:digDown()
    return self:moveDown()
end

--[[
    #endregion DIGGING
]]--

---- Inventory functions
function Turtle.getInventory(startslot, endslot)
    startslot = startslot or 1
    endslot = endslot or 16
    
    local inv = {}

    for i = startslot, endslot, 1 do
        inv[i] = turtle.getItemDetail(i) or {}
    end

    return inv
end

function Turtle.invIsFull(startSlot, endSlot)
    for i = startSlot or 1, endSlot or 16, 1 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    Log("Inventory is full")
    return true
end

function Turtle.dropInv(startSlot, endSlot)
    local empty = false;
    for i = startSlot or 1, endSlot or 16, 1 do
        turtle.select(i)
        turtle.drop(turtle.getItemCount(i))
    end
    empty = true
    turtle.select(1)
    
    Log("Emptied inventory: " .. tostring(empty))
    return empty
end



local t = Turtle:new()

-- map of instructions than can be triggered remotly (eq. rednet, websocket)
local controller_map = {
    moveForward=function ()
        t:moveForward()
    end,
    moveUp=function ()
        t:moveUp()
    end,
    moveBack=function ()
        t:moveBack()
    end,
    moveDown=function ()
        t:moveDown()
    end,
    turnRight=function ()
        t:turnRight()
    end,
    turnLeft=function ()
        t:turnLeft()
    end,
    dig=t.dig,
}

Factory = {}

function Factory.makeControllerHandlers(robot)
    local function handleTurtleInstruction(eventName, instruction, ...)
        local runner = robot[instruction]
        runner(robot, ...)
    end
    
    return {
        {event="instruction", handler=handleTurtleInstruction}
    }
end

-- creating underlying os
local system = ops:new(
    nil, 
    t.label, 
    handlers, 
    t,
    "ws://malteschink.de:5050", 
    "ws://malteschink.de:5051", 
    controller_map)
system:run(ui.shell)