local TERM_WIDTH, TERM_HEIGHT = term.getSize()
term.clear()
term.setCursorPos(1, 1)

local function clear(height, start)
    height = height or TERM_HEIGHT
    start = start or 1
    term.setBackgroundColor(colors.black)

    for i = start, height, 1 do
        term.setCursorPos(1,i)
        term.clearLine()
    end
    term.setCursorPos(1,1)
end

local function writeOnLine(line, text)
    term.setCursorPos(1,line)
    term.write(text)
    term.setCursorPos(1,1)
end

local function write(text, textColor, backgroundColor)
    local beforeTextColor = term.getTextColor()
    local beforeBgColor = term.getBackgroundColor()
    textColor = textColor or colors.white
    backgroundColor = backgroundColor or colors.black
    
    term.setTextColor(textColor)
    term.setBackgroundColor(backgroundColor)

    term.write(text)

    term.setTextColor(beforeTextColor)
    term.setBackgroundColor(beforeBgColor)
end

local function writeln(text, textColor, backgroundColor)
    write(text, textColor, backgroundColor)
    print()
end

local function printLine(line, color)
    local oldColor = term.getBackgroundColor()
    color = color or term.getBackgroundColor()
    paintutils.drawLine(1, line, TERM_WIDTH, line, color)

    term.setBackgroundColor(oldColor)
end

local function printStopLine()
    printLine(TERM_HEIGHT, colors.red)
    term.setCursorPos(math.ceil(TERM_WIDTH / 2) - 3, TERM_HEIGHT)
    term.setTextColor(colors.white)
    write("abort", colors.white, colors.red)

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1,1)
end

-- Sets cursor position to specified position
-- If the value isn't given, defaults to 1
local function setCursorPos(row, column)
    row = row or 1
    column = column or 1

    term.setCursorPos(column, row)
end

return {
    clear=clear,
    print=write,
    println=writeln,

    setCursorPos=setCursorPos,

    drawLine=printLine,
    drawAbort=printStopLine,
}