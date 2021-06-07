local TERM_WIDTH, TERM_HEIGHT = term.getSize()
--local ui = require("libs.ui")

OS = {
    out=nil,
    __menu__ = {
        {name="", ui=nil}
    },
    __touchHandlers__ = {},
    __runningProcess__ = nil,
    __TOUCH_EVENT__ = ""
}

function OS:new (o, menu, ui_lib, touchEvent)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.__TOUCH_EVENT__ = touchEvent or "mouse_click"
    self.__touchHandlers__ = {}
    self.__menu__ = menu or {{name="Debug", ui=UiDebug}}
    self.__runningProcess__ = nil

    self.out = ui_lib
    return o
end

function OS:addTouchHandler(handler, cleanup, xStart, yStart, xEnd, yEnd)
    table.insert(self.__touchHandlers__, {
        handler = handler,
        cleanup = cleanup,
        xStart = xStart,
        xEnd = xEnd,
        yStart = yStart,
        yEnd = yEnd
    })
end

function OS:removeTouchHandler(handler)
    for pos, value in ipairs(self.__touchHandlers__) do
        if value.handler == handler then
            table.remove(self.__touchHandlers__, pos)
        end
    end
end

function OS:resetTouchHandlers()
    self.__touchHandlers__ = {}
end

function OS:addButton(upperLeftCorner, lowerRightCorner, content, action, cleanup, borderColor)
    local width = math.abs(upperLeftCorner.x - lowerRightCorner.x)
    local height = math.abs(upperLeftCorner.y - lowerRightCorner.y)

    local widthCenter = upperLeftCorner.x + (math.ceil(width / 2) - math.floor(content:len() / 2))
    local heightCenter = upperLeftCorner.y + math.floor(height/2)

    if borderColor ~= nil then
        paintutils.drawBox(upperLeftCorner.x, upperLeftCorner.y, lowerRightCorner.x, lowerRightCorner.y, borderColor)
    end

    self.out.setCursorPos(heightCenter, widthCenter)
    self.out.print(content, nil, colors.black)

    self:addTouchHandler(action, cleanup, upperLeftCorner.x, upperLeftCorner.y, lowerRightCorner.x, lowerRightCorner.y)
end

function OS:printTaskBar()
    local color_background = colors.lightGray
    local color_text = colors.black

    self:resetTouchHandlers()

    self.out.drawLine(TERM_HEIGHT, color_background)
    self.out.setCursorPos(TERM_HEIGHT)

    for _, value in ipairs(self.__menu__) do
        local xOfCursor, _ = term.getCursorPos()
        local menuButtonText = " " .. value.name .. " |"

        self:addTouchHandler(value.ui, value.cleanup, xOfCursor, TERM_HEIGHT, xOfCursor + menuButtonText:len() - 1, TERM_HEIGHT)
        self.out.print(menuButtonText, color_text, color_background)
    end

    self.out.setCursorPos(1, 1)
end

function OS:runProcess(f, cleanup)
    local function processRunner()
        f(self)
        
        --reprint menu
        self:printTaskBar()
    end
    --function waiting for kill signal
    local function processHandler()
        self.out.drawAbort()

        repeat
            local _, _, x, y = os.pullEvent(self.__TOUCH_EVENT__)
        until y == TERM_HEIGHT

        --run cleanup function
        if cleanup ~= nil then
            cleanup(self)
        end

        --reprint menu
        self:printTaskBar()
    end

    --finishes if program is finished or kill signal is send
    parallel.waitForAny(processRunner, processHandler)
end

function OS:handleTouch(x, y)
    local function DisplayError(_, _)
        Error("Missing handler for registered touch input field")
    end

    for i, touch in ipairs(self.__touchHandlers__) do
        if x >= touch.xStart and x <= touch.xEnd and y >= touch.yStart and y <= touch.yEnd then
            self:runProcess(touch.handler or DisplayError, touch.cleanup)
        end
    end
end

function OS:awaitTouch()
    local _, _, x, y = os.pullEvent(self.__TOUCH_EVENT__)
    self:handleTouch(x, y)
end

function OS:run(startpage, startpageCleanup, ...)
    --add stop button
    --table.insert(self.menu, 1, {name="Stop", nil})

    self:printTaskBar()
    if startpage ~= nil then
        self:runProcess(startpage, startpageCleanup)
    end
    while true do
        -- self:awaitTouch()
        -- sleep(0.1)
        local event = {os.pullEvent()}
        self:handleTouch(event[3], event[4])
    end
end



return OS