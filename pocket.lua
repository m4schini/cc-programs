local MODEM_SIDE = "back"
local PROTOCOL_RC = "RC"

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

function Import(modname)
    if not fs.exists("/libs/" .. modname) then
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

local function UiRemoteControl(ui)
    rednet.open(MODEM_SIDE)

    local availableReceivers = rednet.lookup(PROTOCOL_RC)
    local id = -1

    local arType = type(availableReceivers)
    if arType == "nil" then
        rednet.close()
        print("No receivers were found")
        return;
    elseif arType == "number" then
        id = availableReceivers
    else
        for i, receiver in ipairs(availableReceivers) do
            print(receiver)
        end

        print("Enter ID of Turtle")
        id = tonumber(read())
    end


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

        local action = keyBindings[key] or nil
        if action ~=  nil then
            rednet.send(id, {type="cmd", payload=action}, "RC")

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