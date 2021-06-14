local TERM_WIDTH, TERM_HEIGHT = term.getSize()

function printLine(line, color)
    local oldColor = term.getBackgroundColor()
    color = color or term.getBackgroundColor()
    paintutils.drawLine(1, line, TERM_WIDTH, line, color)

    term.setBackgroundColor(oldColor)
end

function write(text, textColor, backgroundColor)
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

function writeln(text, textColor, backgroundColor)
    write(text, textColor, backgroundColor)
    print()
end

function clear(height, start)
    height = height or TERM_HEIGHT-1
    start = start or 1
    term.setBackgroundColor(colors.black)

    for i = start, height, 1 do
        term.setCursorPos(1,i)
        term.clearLine()
    end
    term.setCursorPos(1,1)
end

function AbortBar()
    printLine(TERM_HEIGHT, colors.red)
    term.setCursorPos(math.ceil(TERM_WIDTH / 2) - 3, TERM_HEIGHT)
    term.setTextColor(colors.white)
    write("abort", colors.white, colors.red)

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1,1)
end

Ui = {
    internal={
        writeln=writeln,
        write=write,
        printLine=printLine
    },
    clear=clear,
    abortBar=AbortBar,
}

function LogToTerm(...)
    print(textutils.serialize({...}, {compact=true}))
end

function LogToCloud(...)
    
end

local LOG_FILE_PATH = "logs/" .. os.date("%F") .. ".log"
function LogToFile(...)
    local h, err = fs.open(LOG_FILE_PATH, fs.exists(LOG_FILE_PATH) and "a" or "w")

    if h ~= nil then
        h.write(os.date("%c") .. " > [INFO] " .. textutils.serializeJSON({...}) .. "\n")
        h.flush()
        h.close()
    else
        print(err)
    end
end

function TaskBar(programs)
    local color_background = colors.lightGray
    local color_text = colors.black

    printLine(TERM_HEIGHT, color_background)
    term.setCursorPos(1, TERM_HEIGHT)

    local buttons = {}

    for key, value in pairs(programs) do
        local startPos, _ = term.getCursorPos()
        local menuButtonText = " " .. key .. " |"

        --self:addTouchHandler(value.ui, value.cleanup, xOfCursor, TERM_HEIGHT, xOfCursor + menuButtonText:len() - 1, TERM_HEIGHT)
        write(menuButtonText, color_text, color_background)
        local endPos, _ = term.getCursorPos()
        buttons[key] = {
            xStart=startPos,
            yStart=TERM_HEIGHT,
            xEnd=endPos-1,
            yEnd=TERM_HEIGHT,
            action=value 
        }
        
    end
    term.setCursorPos(1, 1)

    return buttons
end

function Shell(system, log)
    log = log or LogToFile -- fallback logger

    term.clear()
    term.setCursorPos(1,1)

    local buttons = TaskBar(system.programs)

    local function waitForAbort()
        AbortBar()
        repeat
            local e, _, x, y = os.pullEvent()
            local aborted = false;
            if e == "mouse_click" or e == "monitor_touch" then
                if y == TERM_HEIGHT then
                    aborted = true
                end
            end
        until aborted
    end

    local TEMP_PATH = "temp.json"
    -- save program for autorestore
    local function rememberProgram(appname)
        local h, err = fs.open(TEMP_PATH, "w")

        if h ~= nil then
            h.write(appname == nil and "" or textutils.serializeJSON({["restore"] = appname}))
            h.flush()
            h.close()
        else
            print(err)
        end
    end

    local function executeProgram(action)
        parallel.waitForAny(
            function ()
                local callData = {pcall(action.exe, Ui, system, system.api.turtle)}

                -- error handling
                if not callData[1] then
                    print(table.unpack(callData, 2))
                end
            end,
            waitForAbort
        )

        -- if cleanup is provided, (eg. close sockets, etc)
        rememberProgram(nil)
        if action.cleanup ~= nil then
            action.cleanup()
        end
    end
    
    -- restores program after restart
    local function restoreProgram()
        local h, err = fs.open(TEMP_PATH, "r")
        if h ~= nil then
            local tempdata = textutils.unserialiseJSON(h.readAll())
            h.close()
            local appname = tempdata ~= nil and tempdata.restore or nil
            if appname ~= nil and buttons[appname] ~= nil then
                executeProgram(buttons[appname].action)
                buttons = TaskBar(system.programs)
            end
        end
    end

    restoreProgram()

    
    -- start program on menu input
    while true do
        local e, _, x, y = os.pullEvent()
        if e == "mouse_click" or e == "monitor_touch" then
            for appname, appdata in pairs(buttons) do

                -- if input was on registered button
                if x >= appdata.xStart and x <= appdata.xEnd and y >= appdata.yStart and y <= appdata.yEnd then
                    if appdata.action ~= nil then
                        rememberProgram(appname)
                        executeProgram(appdata.action)
                    end
                    buttons = TaskBar(system.programs)
                end
            end
        end
    end
end

return {
    ui=Ui,
    shell=Shell,
    log={
        file=LogToFile,
        cloud=LogToCloud,
        term=LogToTerm,
        null=function (...) end
    }
}