local uiLib = require("libs.ui")
local osLib = require("libs.os")

local MODEM_SIDE = "back"

function toHeading(number)
    local headingStr = "ERR"
    if number == 0 then
        headingStr = "NORTH"
    elseif number == 1 then
        headingStr = "EAST"
    elseif number == 2 then
        headingStr = "SOUTH"
    elseif number == 3 then
        headingStr = "WEST"
    end

    return headingStr
end

function cutModId(name)
    return string.sub(name, string.find(name, ":") + 1, name:len() )
end

local function UiPlaceholder(ui)
    ui.write("PLATZHALTER " .. os.clock(), colors.red)
end

local keyBindings = {}
keyBindings[keys.w] = "moveForward"
keyBindings[keys.a] = "turnLeft"
keyBindings[keys.s] = "moveBack"
keyBindings[keys.d] = "turnRight"
keyBindings[keys.space] = "moveUp"
keyBindings[keys.leftCtrl] = "moveDown"
keyBindings[keys.rightCtrl] = "moveDown"
keyBindings[keys.r] = "digUp"
keyBindings[keys.f] = "digForward"
keyBindings[keys.v] = "digDown"
keyBindings[keys.e] = "inventory"
keyBindings[keys.t] = "scan"

local function UiRemoteControl(ui)
    rednet.open(MODEM_SIDE)

    print("Enter ID of Turtle")
    local id = tonumber(read())

    ui.clear()
    print("You're in control of the turtle")
    print()
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

    while true do
        local event, key, is_held = os.pullEvent("key")

        local action = keyBindings[key]
        if action ~=  nil then
            rednet.send(id, {type="cmd", payload=action}, "RC")
        end

        
        local sender, message, protocol = rednet.receive()
        
        ui.clear()
        ui.write("x=" .. message.position.x)
        ui.write(" y=" .. message.position.y)
        ui.write(" z=" .. message.position.z)

        local heading = toHeading(message.position.heading or -1)
        ui.write(" h=" .. heading)

        ui.printLine(2, colors.lightGray)
        ui.setCursorPos(3)

        ui.print("above: ", colors.lightGray)
        ui.print(message.scan.up.name or "air")

        ui.print("infront: ", colors.lightGray)
        ui.print(message.scan.front.name or "air")

        ui.print("below: ", colors.lightGray)
        ui.print(message.scan.down.name or "air")

        ui.printLine(9, colors.lightGray)
        ui.setCursorPos(10)

        if message.payloadType == "INV" then
            for i, slot in ipairs(message.payload) do
                ui.write(slot.count)

                local _, cY = term.getCursorPos()
                term.setCursorPos(3, cY)

                ui.write(" | ", colors.gray)
                ui.print(cutModId(slot.name))
            end
        elseif message.payloadType == "SCAN" then
            for location, scan in pairs(message.payload) do
                ui.write(location, colors.lightGray)
                ui.write(": ", colors.lightGray)

                local _, cY = term.getCursorPos()
                term.setCursorPos(8, cY)
                ui.print(cutModId(scan.name or "minecraft:air"))
            end
        else
            ui.write("response: ")
            print(textutils.serialize(message.payload))
        end
    end
end


local operatingSystem = osLib:new(nil, {
    {
        name="Debug",
        ui=UiPlaceholder,
    },
    {
        name="Remote",
        ui=UiRemoteControl,
    },
},
uiLib)

operatingSystem:run()