local expect = require("cc.expect").expect



local _DIR = {
    NORTH = 0,
    EAST = 1,
    SOUTH = 2,
    WEST = 3
}

Turtle = {
    label = "T" .. os.getComputerID(),
    position = {
        x=0,
        y=0,
        z=0,
        heading = 0
    }
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
    local _, x, y ,z = Turtle.getGpsPosition()
    self.position = {
        x=x,
        y=y,
        z=z,
        heading = 0
    }
    os.queueEvent('position', x, y ,z)
    return x, y, z
end

function Turtle.getGpsPosition()
    local x, y, z = gps.locate()
    if x == nil then
        return false, 0, 0, 0
    else 
        return true, x, y, z
    end
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