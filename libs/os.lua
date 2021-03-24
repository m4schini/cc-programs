local ui = require("ui")
local TERM_WIDTH, TERM_HEIGHT = term.getSize()

OS = {
    menu = {
        {name="", ui=nil}
    },
    touchHandlers = {},
    runningProcess = nil,
    __TOUCH_EVENT = "mouse_click"
}

function OS:new (o, menu, touchEvent)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.__TOUCH_EVENT = touchEvent or "mouse_click"

    self.touchHandlers = {}
    self.menu = menu or {{name="Debug", ui=UiDebug}}

    self.runningProcess = nil
    return o
end

function OS:addTouchHandler(handler, cleanup, xStart, yStart, xEnd, yEnd)
    table.insert(self.touchHandlers, {
        handler = handler,
        cleanup = cleanup,
        xStart = xStart,
        xEnd = xEnd,
        yStart = yStart,
        yEnd = yEnd
    })
end

function OS:addButton(upperLeftCorner, lowerRightCorner, content, action, cleanup, borderColor)
    
    local width = math.abs(upperLeftCorner.x - lowerRightCorner.x)
    local height = math.abs(upperLeftCorner.y - lowerRightCorner.y)

    local widthCenter = upperLeftCorner.x + (math.ceil(width / 2) - math.floor(content:len() / 2))
    local heightCenter = upperLeftCorner.y + math.floor(height/2)

    if borderColor ~= nil then
        paintutils.drawBox(upperLeftCorner.x, upperLeftCorner.y, lowerRightCorner.x, lowerRightCorner.y, borderColor)
    end

    ui.setCursorPos(heightCenter, widthCenter)
    ui.write(content, nil, colors.black)

    self:addTouchHandler(action, cleanup, upperLeftCorner.x, upperLeftCorner.y, lowerRightCorner.x, lowerRightCorner.y)
end

function OS:printTaskBar()
    local color_background = colors.lightGray
    local color_text = colors.black

    self.touchHandlers = {} --clean touch handlers

    ui.printLine(TERM_HEIGHT, color_background)
    ui.setCursorPos(TERM_HEIGHT)

    for _, value in ipairs(self.menu) do
        local xOfCursor, _ = term.getCursorPos()
        local menuButtonText = " " .. value.name .. " |"

        self:addTouchHandler(value.ui, value.cleanup, xOfCursor, TERM_HEIGHT, xOfCursor + menuButtonText:len() - 1, TERM_HEIGHT)
        ui.write(menuButtonText, color_text, color_background)
    end

    ui.setCursorPos()
end

function OS:runProcess(f, cleanup)
    local function processRunner()
        f(ui)
        
        --reprint menu
        self:printTaskBar()
    end
    --function waiting for kill signal
    local function processHandler()
        ui.printStopLine()

        repeat
            local _, _, x, y = os.pullEvent(self.__TOUCH_EVENT)
        until y == TERM_HEIGHT

        --run cleanup function
        if cleanup ~= nil then
            cleanup()
        end

        --reprint menu
        self:printTaskBar()
    end

    --finishes if program is finished or kill signal is send
    parallel.waitForAny(processRunner, processHandler)
end

function OS:__handleTouch(x, y)
    local function DisplayError(_, _)
        Error("Missing handler for registered touch input field")
    end

    for i, touch in ipairs(self.touchHandlers) do
        if x >= touch.xStart and x <= touch.xEnd and y >= touch.yStart and y <= touch.yEnd then
            self:runProcess(touch.handler or DisplayError, touch.cleanup)
        end
    end
end

function OS:awaitTouch()
    local _, _, x, y = os.pullEvent(self.__TOUCH_EVENT)
    self:__handleTouch(x, y)
end

function OS:run(startpage, startpageCleanup, ...)
    --add stop button
    --table.insert(self.menu, 1, {name="Stop", nil})

    self:printTaskBar()
    if startpage ~= nil then
        self:runProcess(startpage, startpageCleanup)
    end
    while true do
        self:awaitTouch()
        sleep(0.1)
    end
end




return OS