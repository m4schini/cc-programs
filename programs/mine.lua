local expect = require("cc.expect").expect

function exe(ui, system, t)
    expect(1, ui, "table")
    expect(2, system, "table")
    expect(3, t, "table")

    local gap = 3
    local depth = 5
    local torch_slot = 16

    function digSlice()
        t:digMove()
        t:digUp()
    end

    repeat

        for i = 1, gap + 1, 1 do
            if i == math.ceil(gap / 2) then
                if turtle.getItemDetail(torch_slot).name == 'minecraft:torch' then
                    t:placeUp(torch_slot)
                    turtle.select(1)
                end
            end
            digSlice()
        end
    
        t:turnRight()
        for i = 1, depth, 1 do
            digSlice()
        end
        t:turnRight()
        t:turnRight()
        for i = 1, depth, 1 do
            digSlice()
        end
        for i = 1, depth, 1 do
            digSlice()
        end
        t:turnRight()
        t:turnRight()
        for i = 1, depth, 1 do
            digSlice()
        end
        t:turnLeft()

    until t.invIsFull(1, 16)
    t:turnLeft()
    t:turnLeft()
    while t:moveForward() do end
    t.dropInv(1, 15)
    t:turnLeft()
    t:turnLeft()
end

return {
    dependencies=nil,
    exe=exe,
}