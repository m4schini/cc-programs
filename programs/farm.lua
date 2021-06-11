local expect = require("cc.expect").expect

function exe(ui, system, t)
    expect(1, ui, "table")
    expect(2, system, "table")
    expect(3, t, "table")

    local function isFullyGrown(blockData)
        if blockData ~= nil and blockData.state ~= nil and blockData.state.age ~= nil then
            if blockData.state.age >= 7 then
                return true;
            end
        end
        return false;
    end

    local function waitForGrowth()
        repeat
            local _, data = t:scanDown()
            local isGrown = false

            if isFullyGrown(data) then
                isGrown = true;
            end
        until isGrown
    end


    local function determineFarmSize()
        length = 0
        width = 0

        while not t:scan() do
            t:moveForward()
            length = length + 1
        end
        t:turnRight()
        while not t:scan() do
            t:moveForward()
            width = width + 1
        end

        t:turnRight()
        t:turnRight()
        for i = 1, width, 1 do
            t:moveForward()
        end
        t:turnLeft()
        for i = 1, length, 1 do
            t:moveForward()
        end
        t:turnLeft()
        t:turnLeft()

        return length, width
    end
    ui.clear()
    print("determining farm size...")
    local farmLength, farmWidth = determineFarmSize()

    while true do
        ui.clear()
        term.setCursorPos(1,1)
        print("Farm ( " .. farmLength .. "x" .. farmWidth .. " | ~" .. farmLength * farmWidth .. " fields )")
        print("Fuel:", t.getFuelLevel() / turtle.getFuelLimit() * 100, "%")

        waitForGrowth()
        local turnedRight = false
        repeat
            while not t:scan() do
                local _, data = t:scanDown()
                if isFullyGrown(data) then
                    t:digDown()
                    t:placeDown(1)
                end
                t:moveForward()
            end

            local moved = false;
            if turnedRight then
                t:turnLeft()
                moved = t:moveForward()
                if moved then
                    t:turnLeft()
                    turnedRight = false
                end
            else
                t:turnRight()
                moved = t:moveForward()
                if moved then 
                    t:turnRight()
                    turnedRight = true
                end
            end
            

        until not moved

        t:turnRight()
        t:turnRight()
        for i = 1, farmWidth, 1 do
            t:moveForward()
        end
        t:turnLeft()
        for i = 1, farmLength, 1 do
            t:moveForward()
        end
        t.dropInv(1, 16)
        t:turnLeft()
        t:turnLeft()

    end
end

return {
    dependencies=nil,
    exe=exe,
}