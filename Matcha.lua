--[[
    MatchaLib - A Drawing API-based UI Library for Matcha Executor
    
    Usage:
        local UI = loadstring(game:HttpGet("..."))()
        local Window = UI:CreateWindow({ Title = "My Script", Keybind = Enum.KeyCode.RightShift })
        local Tab = Window:AddTab("Combat")
        local Box = Tab:AddLeftGroupbox("Aimbot")
        Box:AddToggle("AimbotEnabled", { Text = "Enable Aimbot", Default = false, Callback = function(v) end })
        Box:AddSlider("AimbotFOV", { Text = "FOV", Min = 1, Max = 360, Default = 90, Rounding = 0 })
        Window:Show()
]]

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
--  THEME
-- ============================================================
local Theme = {
    Background      = Color3.fromRGB(18, 18, 24),
    Surface         = Color3.fromRGB(26, 26, 34),
    SurfaceAlt      = Color3.fromRGB(32, 32, 42),
    Accent          = Color3.fromRGB(100, 140, 255),
    AccentDark      = Color3.fromRGB(60, 95, 200),
    Border          = Color3.fromRGB(50, 50, 65),
    BorderLight     = Color3.fromRGB(70, 70, 90),
    Text            = Color3.fromRGB(220, 220, 235),
    TextDim         = Color3.fromRGB(130, 130, 155),
    TextDisabled    = Color3.fromRGB(80, 80, 100),
    Enabled         = Color3.fromRGB(80, 200, 120),
    Disabled        = Color3.fromRGB(200, 80, 80),
    SliderFill      = Color3.fromRGB(100, 140, 255),
    Notification    = Color3.fromRGB(26, 26, 34),
    NotifBorder     = Color3.fromRGB(100, 140, 255),
}

-- ============================================================
--  DRAWING HELPERS
-- ============================================================
local Draw = {}

function Draw.Square(props)
    local s = Drawing.new("Square")
    s.Filled = props.Filled ~= nil and props.Filled or true
    s.Color = props.Color or Color3.new(1,1,1)
    s.Transparency = props.Transparency or 1
    s.Position = props.Position or Vector2.new(0,0)
    s.Size = props.Size or Vector2.new(100,20)
    s.ZIndex = props.ZIndex or 1
    s.Visible = props.Visible ~= nil and props.Visible or true
    if props.Corner then s.Corner = props.Corner end
    return s
end

function Draw.Line(props)
    local l = Drawing.new("Line")
    l.Color = props.Color or Color3.new(1,1,1)
    l.Transparency = props.Transparency or 1
    l.From = props.From or Vector2.new(0,0)
    l.To = props.To or Vector2.new(100,0)
    l.Thickness = props.Thickness or 1
    l.ZIndex = props.ZIndex or 1
    l.Visible = props.Visible ~= nil and props.Visible or true
    return l
end

function Draw.Text(props)
    local t = Drawing.new("Text")
    t.Text = props.Text or ""
    t.Color = props.Color or Color3.new(1,1,1)
    t.Transparency = props.Transparency or 1
    t.Position = props.Position or Vector2.new(0,0)
    t.Size = props.Size or 14
    t.ZIndex = props.ZIndex or 2
    t.Outline = props.Outline ~= nil and props.Outline or false
    t.Center = props.Center ~= nil and props.Center or false
    t.Font = props.Font or Drawing.Fonts.UI
    t.Visible = props.Visible ~= nil and props.Visible or true
    return t
end

function Draw.Circle(props)
    local c = Drawing.new("Circle")
    c.Color = props.Color or Color3.new(1,1,1)
    c.Transparency = props.Transparency or 1
    c.Position = props.Position or Vector2.new(0,0)
    c.Radius = props.Radius or 5
    c.Filled = props.Filled ~= nil and props.Filled or true
    c.NumSides = props.NumSides or 32
    c.Thickness = props.Thickness or 1
    c.ZIndex = props.ZIndex or 1
    c.Visible = props.Visible ~= nil and props.Visible or true
    return c
end

-- Remove a list of drawing objects
local function RemoveAll(tbl)
    for _, obj in ipairs(tbl) do
        pcall(function() obj:Remove() end)
    end
end

-- ============================================================
--  INPUT HELPERS
-- ============================================================
local function MouseInBox(pos, size)
    local mx, my = Mouse.X, Mouse.Y
    return mx >= pos.X and mx <= pos.X + size.X
       and my >= pos.Y and my <= pos.Y + size.Y
end

local function Clamp(v, mn, mx)
    return math.max(mn, math.min(mx, v))
end

local function Round(v, dec)
    local m = 10^(dec or 0)
    return math.floor(v * m + 0.5) / m
end

-- ============================================================
--  FONT SIZE CONSTANTS
-- ============================================================
local FONT       = Drawing.Fonts.UI
local FONT_SIZE  = 13
local FONT_TITLE = 15

-- ============================================================
--  LAYOUT CONSTANTS
-- ============================================================
local WIN_W         = 560
local WIN_H         = 420
local TITLE_H       = 32
local TAB_BAR_H     = 28
local CONTENT_PAD   = 8
local COL_GAP       = 6
local ELEM_H        = 22
local ELEM_GAP      = 5
local GROUPBOX_PAD  = 8
local GROUPBOX_TITLE_H = 20
local TOGGLE_SIZE   = 12
local SCROLLBAR_W   = 5

-- ============================================================
--  NOTIFICATION SYSTEM
-- ============================================================
local NotifQueue = {}
local NOTIF_W = 260
local NOTIF_H = 52
local NOTIF_PAD = 8
local NOTIF_X_MARGIN = 16
local NOTIF_Y_START = 60
local NOTIF_GAP = 8

local function CreateNotification(title, message, duration)
    local vp = workspace.CurrentCamera.ViewportSize
    local startX = vp.X - NOTIF_W - NOTIF_X_MARGIN
    local idx = #NotifQueue + 1
    local startY = NOTIF_Y_START + (idx-1)*(NOTIF_H + NOTIF_GAP)

    local objs = {}
    local function add(fn, props) local o = fn(props); table.insert(objs, o); return o end

    -- BG
    local bg = add(Draw.Square, {
        Color = Theme.Notification, Position = Vector2.new(startX, startY),
        Size = Vector2.new(NOTIF_W, NOTIF_H), ZIndex = 200, Corner = 4,
    })
    -- Border
    add(Draw.Square, {
        Filled = false, Color = Theme.NotifBorder,
        Position = Vector2.new(startX, startY),
        Size = Vector2.new(NOTIF_W, NOTIF_H), ZIndex = 201, Corner = 4, Thickness = 1,
    })
    -- Accent bar
    add(Draw.Square, {
        Color = Theme.Accent,
        Position = Vector2.new(startX, startY),
        Size = Vector2.new(3, NOTIF_H), ZIndex = 202, Corner = 0,
    })
    -- Title
    add(Draw.Text, {
        Text = title, Color = Theme.Text,
        Position = Vector2.new(startX + 10, startY + 8),
        Size = 13, ZIndex = 202, Font = FONT,
    })
    -- Message
    add(Draw.Text, {
        Text = message, Color = Theme.TextDim,
        Position = Vector2.new(startX + 10, startY + 24),
        Size = 12, ZIndex = 202, Font = FONT,
    })

    local entry = { objs = objs, bg = bg, y = startY, targetY = startY }
    table.insert(NotifQueue, entry)

    -- Auto-remove
    task.delay(duration or 3, function()
        for i, e in ipairs(NotifQueue) do
            if e == entry then
                table.remove(NotifQueue, i)
                break
            end
        end
        RemoveAll(objs)
        -- Restack remaining
        for j, e in ipairs(NotifQueue) do
            e.targetY = NOTIF_Y_START + (j-1)*(NOTIF_H + NOTIF_GAP)
        end
    end)
end

-- Animate notif positions
RunService.RenderStepped:Connect(function()
    local vp = workspace.CurrentCamera.ViewportSize
    for _, entry in ipairs(NotifQueue) do
        if math.abs(entry.y - entry.targetY) > 0.5 then
            entry.y = entry.y + (entry.targetY - entry.y) * 0.2
            for _, obj in ipairs(entry.objs) do
                pcall(function()
                    local ox = vp.X - NOTIF_W - NOTIF_X_MARGIN
                    obj.Position = Vector2.new(ox, entry.y + (obj.Position.Y - entry.bg.Position.Y))
                end)
            end
            entry.bg.Position = Vector2.new(vp.X - NOTIF_W - NOTIF_X_MARGIN, entry.y)
        end
    end
end)

-- ============================================================
--  WATERMARK
-- ============================================================
local WatermarkObjs = {}
local WatermarkVisible = false

local function SetWatermark(text, visible)
    RemoveAll(WatermarkObjs)
    WatermarkObjs = {}
    WatermarkVisible = visible ~= false
    if not WatermarkVisible or not text or text == "" then return end

    local x, y = 12, 12
    local w = #text * 7 + 20
    local h = 22

    table.insert(WatermarkObjs, Draw.Square({
        Color = Theme.Surface, Position = Vector2.new(x, y),
        Size = Vector2.new(w, h), ZIndex = 50, Corner = 4,
    }))
    table.insert(WatermarkObjs, Draw.Square({
        Filled = false, Color = Theme.Accent,
        Position = Vector2.new(x, y), Size = Vector2.new(w, h),
        ZIndex = 51, Corner = 4,
    }))
    table.insert(WatermarkObjs, Draw.Text({
        Text = text, Color = Theme.Text,
        Position = Vector2.new(x + 10, y + 5),
        Size = 12, ZIndex = 52, Font = FONT,
    }))
end

-- ============================================================
--  MAIN LIBRARY TABLE
-- ============================================================
local Library = {}
Library.__index = Library

function Library:CreateWindow(config)
    config = config or {}
    local win = setmetatable({}, Library)
    win.Title       = config.Title or "UI Library"
    win.Keybind     = config.Keybind or Enum.KeyCode.RightShift
    win.Watermark   = config.Watermark or ""
    win.Visible     = false
    win.Tabs        = {}
    win.TabOrder    = {}
    win.ActiveTab   = nil
    win.Connections = {}
    win.AllObjects  = {} -- every drawing object ever created

    -- Window position (draggable)
    local vp = workspace.CurrentCamera.ViewportSize
    win.X = math.floor(vp.X / 2 - WIN_W / 2)
    win.Y = math.floor(vp.Y / 2 - WIN_H / 2)

    -- Dragging state
    local dragging = false
    local dragOffX, dragOffY = 0, 0

    -- --------------------------------------------------------
    --  DRAWING LAYERS
    -- --------------------------------------------------------
    -- All drawn per-frame in :Render()

    -- Store all permanent bg objects for the window chrome
    win._chrome = {}

    local function addChrome(fn, props)
        local o = fn(props)
        table.insert(win._chrome, o)
        table.insert(win.AllObjects, o)
        return o
    end

    -- Outer border
    win._outerBorder = addChrome(Draw.Square, {
        Filled = false, Color = Theme.Border,
        Position = Vector2.new(win.X, win.Y),
        Size = Vector2.new(WIN_W, WIN_H),
        ZIndex = 1, Corner = 6,
    })
    -- Main background
    win._bg = addChrome(Draw.Square, {
        Color = Theme.Background,
        Position = Vector2.new(win.X, win.Y),
        Size = Vector2.new(WIN_W, WIN_H),
        ZIndex = 2, Corner = 6,
    })
    -- Title bar
    win._titleBar = addChrome(Draw.Square, {
        Color = Theme.Surface,
        Position = Vector2.new(win.X, win.Y),
        Size = Vector2.new(WIN_W, TITLE_H),
        ZIndex = 3, Corner = 6,
    })
    -- Title bar bottom fill (cover rounded corner)
    win._titleBarFill = addChrome(Draw.Square, {
        Color = Theme.Surface,
        Position = Vector2.new(win.X, win.Y + TITLE_H - 6),
        Size = Vector2.new(WIN_W, 6),
        ZIndex = 3,
    })
    -- Accent line under title
    win._titleAccent = addChrome(Draw.Line, {
        Color = Theme.Accent,
        From = Vector2.new(win.X, win.Y + TITLE_H),
        To = Vector2.new(win.X + WIN_W, win.Y + TITLE_H),
        Thickness = 1, ZIndex = 4,
    })
    -- Title text
    win._titleText = addChrome(Draw.Text, {
        Text = win.Title, Color = Theme.Text,
        Position = Vector2.new(win.X + 12, win.Y + 9),
        Size = FONT_TITLE, ZIndex = 5, Font = FONT,
    })
    -- Close button "×"
    win._closeBtn = addChrome(Draw.Text, {
        Text = "×", Color = Theme.TextDim,
        Position = Vector2.new(win.X + WIN_W - 20, win.Y + 7),
        Size = FONT_TITLE + 2, ZIndex = 5, Font = FONT,
    })
    -- Tab bar background
    win._tabBarBg = addChrome(Draw.Square, {
        Color = Theme.Surface,
        Position = Vector2.new(win.X, win.Y + TITLE_H),
        Size = Vector2.new(WIN_W, TAB_BAR_H),
        ZIndex = 3,
    })
    -- Content area
    win._contentBg = addChrome(Draw.Square, {
        Color = Theme.Background,
        Position = Vector2.new(win.X, win.Y + TITLE_H + TAB_BAR_H),
        Size = Vector2.new(WIN_W, WIN_H - TITLE_H - TAB_BAR_H),
        ZIndex = 2,
    })

    -- --------------------------------------------------------
    --  RENDER FUNCTION (called every frame)
    -- --------------------------------------------------------
    function win:Render()
        local x, y = self.X, self.Y
        local vis = self.Visible

        self._outerBorder.Visible = vis
        self._bg.Visible = vis
        self._titleBar.Visible = vis
        self._titleBarFill.Visible = vis
        self._titleAccent.Visible = vis
        self._titleText.Visible = vis
        self._closeBtn.Visible = vis
        self._tabBarBg.Visible = vis
        self._contentBg.Visible = vis

        if not vis then
            for _, tab in ipairs(self.TabOrder) do
                tab:SetVisible(false)
            end
            return
        end

        -- Update positions
        self._outerBorder.Position = Vector2.new(x, y)
        self._outerBorder.Size = Vector2.new(WIN_W, WIN_H)
        self._bg.Position = Vector2.new(x, y)
        self._bg.Size = Vector2.new(WIN_W, WIN_H)
        self._titleBar.Position = Vector2.new(x, y)
        self._titleBar.Size = Vector2.new(WIN_W, TITLE_H)
        self._titleBarFill.Position = Vector2.new(x, y + TITLE_H - 6)
        self._titleBarFill.Size = Vector2.new(WIN_W, 6)
        self._titleAccent.From = Vector2.new(x, y + TITLE_H)
        self._titleAccent.To = Vector2.new(x + WIN_W, y + TITLE_H)
        self._titleText.Position = Vector2.new(x + 12, y + 9)
        self._closeBtn.Position = Vector2.new(x + WIN_W - 20, y + 7)
        self._tabBarBg.Position = Vector2.new(x, y + TITLE_H)
        self._tabBarBg.Size = Vector2.new(WIN_W, TAB_BAR_H)
        self._contentBg.Position = Vector2.new(x, y + TITLE_H + TAB_BAR_H)
        self._contentBg.Size = Vector2.new(WIN_W, WIN_H - TITLE_H - TAB_BAR_H)

        -- Tab buttons
        local tabX = x + 10
        local tabY = y + TITLE_H + 4
        for _, tab in ipairs(self.TabOrder) do
            tab:RenderButton(tabX, tabY, self.ActiveTab == tab)
            tabX = tabX + tab._btnW + 4
        end

        -- Active tab content
        for _, tab in ipairs(self.TabOrder) do
            tab:SetVisible(self.ActiveTab == tab)
            if self.ActiveTab == tab then
                tab:Render(x + CONTENT_PAD, y + TITLE_H + TAB_BAR_H + CONTENT_PAD,
                    WIN_W - CONTENT_PAD*2, WIN_H - TITLE_H - TAB_BAR_H - CONTENT_PAD*2)
            end
        end
    end

    -- --------------------------------------------------------
    --  TOGGLE VISIBILITY
    -- --------------------------------------------------------
    function win:Show()
        self.Visible = true
        if self.Watermark and self.Watermark ~= "" then
            SetWatermark(self.Watermark, true)
        end
    end

    function win:Hide()
        self.Visible = false
    end

    function win:Toggle()
        if self.Visible then self:Hide() else self:Show() end
    end

    -- --------------------------------------------------------
    --  ADD TAB
    -- --------------------------------------------------------
    function win:AddTab(name)
        local tab = CreateTab(name, self)
        self.Tabs[name] = tab
        table.insert(self.TabOrder, tab)
        if not self.ActiveTab then
            self.ActiveTab = tab
        end
        return tab
    end

    -- --------------------------------------------------------
    --  WATERMARK / NOTIF PASSTHROUGH
    -- --------------------------------------------------------
    function win:SetWatermark(text)
        self.Watermark = text
        SetWatermark(text, self.Visible)
    end

    function win:Notify(title, message, duration)
        CreateNotification(title, message, duration)
    end

    function win:SetTheme(newTheme)
        for k, v in pairs(newTheme) do
            Theme[k] = v
        end
    end

    -- --------------------------------------------------------
    --  INPUT
    -- --------------------------------------------------------
    local conn1 = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end

        -- Toggle keybind
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == win.Keybind then
                win:Toggle()
                return
            end
        end

        if not win.Visible then return end

        -- Left click
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mx, my = Mouse.X, Mouse.Y

            -- Close button
            if mx >= win.X + WIN_W - 24 and mx <= win.X + WIN_W - 4
            and my >= win.Y + 4 and my <= win.Y + TITLE_H - 4 then
                win:Hide()
                return
            end

            -- Title bar drag
            if mx >= win.X and mx <= win.X + WIN_W
            and my >= win.Y and my <= win.Y + TITLE_H then
                dragging = true
                dragOffX = mx - win.X
                dragOffY = my - win.Y
                return
            end

            -- Tab click
            local tabX = win.X + 10
            local tabY = win.Y + TITLE_H + 4
            for _, tab in ipairs(win.TabOrder) do
                if mx >= tabX and mx <= tabX + tab._btnW
                and my >= tabY and my <= tabY + TAB_BAR_H - 8 then
                    win.ActiveTab = tab
                    return
                end
                tabX = tabX + tab._btnW + 4
            end

            -- Delegate to active tab
            if win.ActiveTab then
                local cx = win.X + CONTENT_PAD
                local cy = win.Y + TITLE_H + TAB_BAR_H + CONTENT_PAD
                local cw = WIN_W - CONTENT_PAD*2
                local ch = WIN_H - TITLE_H - TAB_BAR_H - CONTENT_PAD*2
                win.ActiveTab:OnClick(mx, my, cx, cy, cw, ch)
            end
        end
    end)

    local conn2 = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            if win.Visible and win.ActiveTab then
                win.ActiveTab:OnRelease()
            end
        end
    end)

    table.insert(win.Connections, conn1)
    table.insert(win.Connections, conn2)

    -- --------------------------------------------------------
    --  MAIN RENDER LOOP
    -- --------------------------------------------------------
    local renderConn = RunService.RenderStepped:Connect(function()
        if dragging then
            win.X = Mouse.X - dragOffX
            win.Y = Mouse.Y - dragOffY
        end

        -- Delegate mouse move to active tab (sliders)
        if win.Visible and win.ActiveTab then
            local cx = win.X + CONTENT_PAD
            local cy = win.Y + TITLE_H + TAB_BAR_H + CONTENT_PAD
            local cw = WIN_W - CONTENT_PAD*2
            local ch = WIN_H - TITLE_H - TAB_BAR_H - CONTENT_PAD*2
            win.ActiveTab:OnMouseMove(Mouse.X, Mouse.Y, cx, cy, cw, ch)
        end

        win:Render()
    end)
    table.insert(win.Connections, renderConn)

    -- --------------------------------------------------------
    --  DESTROY
    -- --------------------------------------------------------
    function win:Destroy()
        for _, c in ipairs(self.Connections) do c:Disconnect() end
        RemoveAll(self.AllObjects)
        RemoveAll(WatermarkObjs)
    end

    return win
end

-- ============================================================
--  TAB
-- ============================================================
function CreateTab(name, window)
    local tab = {}
    tab._name = name
    tab._window = window
    tab._leftGroups = {}
    tab._rightGroups = {}
    tab._allObjs = {}
    tab._draggingElem = nil

    -- Measure button width
    tab._btnW = math.max(#name * 7 + 16, 50)

    -- Tab button drawing objects
    local function addObj(fn, props)
        local o = fn(props)
        table.insert(tab._allObjs, o)
        table.insert(window.AllObjects, o)
        return o
    end

    tab._btnBg = addObj(Draw.Square, {
        Color = Theme.SurfaceAlt, Position = Vector2.new(0,0),
        Size = Vector2.new(tab._btnW, TAB_BAR_H - 8),
        ZIndex = 5, Corner = 4, Visible = false,
    })
    tab._btnText = addObj(Draw.Text, {
        Text = name, Color = Theme.TextDim,
        Position = Vector2.new(0, 0),
        Size = FONT_SIZE, ZIndex = 6, Font = FONT, Visible = false,
    })
    tab._btnUnderline = addObj(Draw.Square, {
        Color = Theme.Accent, Position = Vector2.new(0,0),
        Size = Vector2.new(tab._btnW, 2),
        ZIndex = 6, Visible = false,
    })

    function tab:RenderButton(bx, by, active)
        self._btnBg.Position = Vector2.new(bx, by)
        self._btnBg.Size = Vector2.new(self._btnW, TAB_BAR_H - 8)
        self._btnBg.Color = active and Theme.Surface or Theme.SurfaceAlt
        self._btnBg.Visible = true

        self._btnText.Position = Vector2.new(bx + 8, by + 4)
        self._btnText.Color = active and Theme.Text or Theme.TextDim
        self._btnText.Visible = true

        self._btnUnderline.Position = Vector2.new(bx, by + TAB_BAR_H - 10)
        self._btnUnderline.Size = Vector2.new(self._btnW, 2)
        self._btnUnderline.Visible = active
    end

    function tab:SetVisible(v)
        for _, g in ipairs(self._leftGroups) do g:SetVisible(v) end
        for _, g in ipairs(self._rightGroups) do g:SetVisible(v) end
        if not v then
            self._btnBg.Visible = false
            self._btnText.Visible = false
            self._btnUnderline.Visible = false
        end
    end

    function tab:Render(cx, cy, cw, ch)
        local colW = math.floor((cw - COL_GAP) / 2)
        local leftX = cx
        local rightX = cx + colW + COL_GAP

        local leftY = cy
        for _, g in ipairs(self._leftGroups) do
            local gh = g:Render(leftX, leftY, colW)
            leftY = leftY + gh + GROUPBOX_PAD
        end

        local rightY = cy
        for _, g in ipairs(self._rightGroups) do
            local gh = g:Render(rightX, rightY, colW)
            rightY = rightY + gh + GROUPBOX_PAD
        end
    end

    function tab:OnClick(mx, my, cx, cy, cw, ch)
        local colW = math.floor((cw - COL_GAP) / 2)
        local leftX, rightX = cx, cx + colW + COL_GAP
        local leftY, rightY = cy, cy

        for _, g in ipairs(self._leftGroups) do
            local gh = g:GetHeight()
            g:OnClick(mx, my, leftX, leftY, colW)
            leftY = leftY + gh + GROUPBOX_PAD
        end
        for _, g in ipairs(self._rightGroups) do
            local gh = g:GetHeight()
            g:OnClick(mx, my, rightX, rightY, colW)
            rightY = rightY + gh + GROUPBOX_PAD
        end
    end

    function tab:OnRelease()
        for _, g in ipairs(self._leftGroups) do g:OnRelease() end
        for _, g in ipairs(self._rightGroups) do g:OnRelease() end
    end

    function tab:OnMouseMove(mx, my, cx, cy, cw, ch)
        local colW = math.floor((cw - COL_GAP) / 2)
        local leftX, rightX = cx, cx + colW + COL_GAP
        local leftY, rightY = cy, cy

        for _, g in ipairs(self._leftGroups) do
            local gh = g:GetHeight()
            g:OnMouseMove(mx, my, leftX, leftY, colW)
            leftY = leftY + gh + GROUPBOX_PAD
        end
        for _, g in ipairs(self._rightGroups) do
            local gh = g:GetHeight()
            g:OnMouseMove(mx, my, rightX, rightY, colW)
            rightY = rightY + gh + GROUPBOX_PAD
        end
    end

    function tab:AddLeftGroupbox(name)
        local g = CreateGroupbox(name, window)
        table.insert(self._leftGroups, g)
        return g
    end

    function tab:AddRightGroupbox(name)
        local g = CreateGroupbox(name, window)
        table.insert(self._rightGroups, g)
        return g
    end

    function tab:AddLeftTabbox()
        local tb = CreateTabbox(window, "left")
        table.insert(self._leftGroups, tb)
        return tb
    end

    function tab:AddRightTabbox()
        local tb = CreateTabbox(window, "right")
        table.insert(self._rightGroups, tb)
        return tb
    end

    return tab
end

-- ============================================================
--  TABBOX (tabs-within-a-column)
-- ============================================================
function CreateTabbox(window, side)
    local tb = {}
    tb._tabs = {}
    tb._tabOrder = {}
    tb._activeTab = nil
    tb._allObjs = {}
    tb._window = window

    local function addObj(fn, props)
        local o = fn(props)
        table.insert(tb._allObjs, o)
        table.insert(window.AllObjects, o)
        return o
    end

    tb._bg = addObj(Draw.Square, { Color = Theme.Surface, Position = Vector2.new(0,0), Size = Vector2.new(100, 40), ZIndex = 6, Corner = 4, Visible = false })
    tb._border = addObj(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(100, 40), ZIndex = 7, Corner = 4, Visible = false })

    function tb:AddTab(name)
        local t = CreateGroupbox(name, window, true) -- isTabboxTab = true
        t._tabboxTabName = name
        self._tabs[name] = t
        table.insert(self._tabOrder, t)
        if not self._activeTab then self._activeTab = t end
        return t
    end

    function tb:GetHeight()
        local TAB_BTN_H = 22
        local inner = self._activeTab and self._activeTab:GetHeight() or 0
        return TAB_BTN_H + inner + GROUPBOX_PAD * 2
    end

    function tb:SetVisible(v)
        self._bg.Visible = v
        self._border.Visible = v
        for _, t in ipairs(self._tabOrder) do t:SetVisible(false) end
        if v and self._activeTab then self._activeTab:SetVisible(true) end
    end

    function tb:Render(x, y, w)
        local TAB_BTN_H = 20
        local h = self:GetHeight()

        self._bg.Position = Vector2.new(x, y)
        self._bg.Size = Vector2.new(w, h)
        self._bg.Visible = true
        self._border.Position = Vector2.new(x, y)
        self._border.Size = Vector2.new(w, h)
        self._border.Visible = true

        -- Tab buttons
        local btnW = math.floor(w / math.max(#self._tabOrder, 1))
        for i, t in ipairs(self._tabOrder) do
            local bx = x + (i-1)*btnW
            local active = self._activeTab == t
            -- Render simple tab button inline
            if t._tabBtnBg then
                t._tabBtnBg.Position = Vector2.new(bx, y)
                t._tabBtnBg.Size = Vector2.new(btnW, TAB_BTN_H)
                t._tabBtnBg.Color = active and Theme.SurfaceAlt or Theme.Surface
                t._tabBtnBg.Visible = true
                t._tabBtnText.Position = Vector2.new(bx + 6, y + 4)
                t._tabBtnText.Color = active and Theme.Text or Theme.TextDim
                t._tabBtnText.Visible = true
                t._tabBtnLine.Position = Vector2.new(bx, y + TAB_BTN_H - 2)
                t._tabBtnLine.Size = Vector2.new(btnW, 2)
                t._tabBtnLine.Color = active and Theme.Accent or Theme.Border
                t._tabBtnLine.Visible = true
            end

            if active then
                t:Render(x + CONTENT_PAD, y + TAB_BTN_H + 4, w - CONTENT_PAD*2)
            else
                t:SetVisible(false)
            end
        end

        return h
    end

    function tb:OnClick(mx, my, x, y, w)
        local TAB_BTN_H = 20
        local btnW = math.floor(w / math.max(#self._tabOrder, 1))
        for i, t in ipairs(self._tabOrder) do
            local bx = x + (i-1)*btnW
            if mx >= bx and mx <= bx+btnW and my >= y and my <= y+TAB_BTN_H then
                self._activeTab = t
                return
            end
        end
        if self._activeTab then
            self._activeTab:OnClick(mx, my, x + CONTENT_PAD, y + TAB_BTN_H + 4, w - CONTENT_PAD*2)
        end
    end

    function tb:OnRelease()
        for _, t in ipairs(self._tabOrder) do t:OnRelease() end
    end

    function tb:OnMouseMove(mx, my, x, y, w)
        if self._activeTab then
            local TAB_BTN_H = 20
            self._activeTab:OnMouseMove(mx, my, x + CONTENT_PAD, y + TAB_BTN_H + 4, w - CONTENT_PAD*2)
        end
    end

    return tb
end

-- ============================================================
--  GROUPBOX
-- ============================================================
function CreateGroupbox(name, window, isTabboxTab)
    local g = {}
    g._name = name
    g._window = window
    g._elements = {}
    g._allObjs = {}
    g._visible = true
    g._isTabboxTab = isTabboxTab

    local function addObj(fn, props)
        local o = fn(props)
        table.insert(g._allObjs, o)
        table.insert(window.AllObjects, o)
        return o
    end

    -- Background and border
    g._bg = addObj(Draw.Square, { Color = Theme.Surface, Position = Vector2.new(0,0), Size = Vector2.new(100, 40), ZIndex = 6, Corner = 4, Visible = false })
    g._border = addObj(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(100, 40), ZIndex = 7, Corner = 4, Visible = false })
    g._titleBg = addObj(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(100, GROUPBOX_TITLE_H), ZIndex = 7, Corner = 4, Visible = false })
    g._titleFill = addObj(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(100, 6), ZIndex = 7, Visible = false })
    g._titleAccent = addObj(Draw.Square, { Color = Theme.Accent, Position = Vector2.new(0,0), Size = Vector2.new(3, GROUPBOX_TITLE_H), ZIndex = 8, Visible = false })
    g._titleText = addObj(Draw.Text, { Text = name, Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 8, Font = FONT, Visible = false })
    g._divider = addObj(Draw.Line, { Color = Theme.Border, From = Vector2.new(0,0), To = Vector2.new(100,0), Thickness = 1, ZIndex = 7, Visible = false })

    -- Tab button objects (only used when inside a Tabbox)
    if isTabboxTab then
        g._tabBtnBg   = addObj(Draw.Square, { Color = Theme.Surface, Position = Vector2.new(0,0), Size = Vector2.new(60,20), ZIndex = 7, Visible = false })
        g._tabBtnText  = addObj(Draw.Text, { Text = name, Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 8, Font = FONT, Visible = false })
        g._tabBtnLine  = addObj(Draw.Square, { Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(60,2), ZIndex = 8, Visible = false })
    end

    function g:GetHeight()
        if not self._visible then return 0 end
        local h = GROUPBOX_TITLE_H + GROUPBOX_PAD
        for _, elem in ipairs(self._elements) do
            if elem._visible ~= false then
                h = h + elem:GetHeight() + ELEM_GAP
            end
        end
        return h + GROUPBOX_PAD
    end

    function g:SetVisible(v)
        self._visible = v
        self._bg.Visible = v
        self._border.Visible = v
        self._titleBg.Visible = v
        self._titleFill.Visible = v
        self._titleAccent.Visible = v
        self._titleText.Visible = v
        self._divider.Visible = v
        for _, elem in ipairs(self._elements) do
            elem:SetVisible(v)
        end
    end

    function g:Render(x, y, w)
        if not self._visible then return 0 end
        local h = self:GetHeight()

        self._bg.Position = Vector2.new(x, y)
        self._bg.Size = Vector2.new(w, h)
        self._bg.Visible = true

        self._border.Position = Vector2.new(x, y)
        self._border.Size = Vector2.new(w, h)
        self._border.Visible = true

        -- Title bar
        self._titleBg.Position = Vector2.new(x, y)
        self._titleBg.Size = Vector2.new(w, GROUPBOX_TITLE_H)
        self._titleBg.Visible = true

        self._titleFill.Position = Vector2.new(x, y + GROUPBOX_TITLE_H - 6)
        self._titleFill.Size = Vector2.new(w, 6)
        self._titleFill.Visible = true

        self._titleAccent.Position = Vector2.new(x, y)
        self._titleAccent.Size = Vector2.new(3, GROUPBOX_TITLE_H)
        self._titleAccent.Visible = true

        self._titleText.Position = Vector2.new(x + 10, y + 4)
        self._titleText.Visible = true

        self._divider.From = Vector2.new(x, y + GROUPBOX_TITLE_H)
        self._divider.To = Vector2.new(x + w, y + GROUPBOX_TITLE_H)
        self._divider.Visible = true

        -- Elements
        local ey = y + GROUPBOX_TITLE_H + GROUPBOX_PAD
        for _, elem in ipairs(self._elements) do
            if elem._visible ~= false then
                elem:Render(x + GROUPBOX_PAD, ey, w - GROUPBOX_PAD*2)
                ey = ey + elem:GetHeight() + ELEM_GAP
            end
        end

        return h
    end

    function g:OnClick(mx, my, x, y, w)
        if not self._visible then return end
        local ey = y + GROUPBOX_TITLE_H + GROUPBOX_PAD
        for _, elem in ipairs(self._elements) do
            if elem._visible ~= false then
                local eh = elem:GetHeight()
                elem:OnClick(mx, my, x + GROUPBOX_PAD, ey, w - GROUPBOX_PAD*2)
                ey = ey + eh + ELEM_GAP
            end
        end
    end

    function g:OnRelease()
        for _, elem in ipairs(self._elements) do
            if elem.OnRelease then elem:OnRelease() end
        end
    end

    function g:OnMouseMove(mx, my, x, y, w)
        if not self._visible then return end
        local ey = y + GROUPBOX_TITLE_H + GROUPBOX_PAD
        for _, elem in ipairs(self._elements) do
            if elem._visible ~= false then
                local eh = elem:GetHeight()
                if elem.OnMouseMove then elem:OnMouseMove(mx, my, x + GROUPBOX_PAD, ey, w - GROUPBOX_PAD*2) end
                ey = ey + eh + ELEM_GAP
            end
        end
    end

    -- --------------------------------------------------------
    --  ELEMENT FACTORIES
    -- --------------------------------------------------------

    -- Shared element setup
    local function newElem()
        local e = {}
        e._visible = true
        e._allObjs = {}
        local function addO(fn, props)
            local o = fn(props)
            table.insert(e._allObjs, o)
            table.insert(window.AllObjects, o)
            return o
        end
        e._addO = addO
        function e:SetVisible(v)
            self._visible = v
            for _, o in ipairs(self._allObjs) do o.Visible = false end
        end
        return e
    end

    -- ======================================================
    --  LABEL
    -- ======================================================
    function g:AddLabel(text)
        local e = newElem()
        e._text = text

        local lbl = e._addO(Draw.Text, {
            Text = text, Color = Theme.TextDim,
            Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false,
        })

        function e:GetHeight() return 14 end

        function e:Render(x, y, w)
            lbl.Position = Vector2.new(x, y)
            lbl.Visible = true
        end

        function e:OnClick() end

        function e:SetText(t)
            self._text = t
            lbl.Text = t
        end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  BUTTON
    -- ======================================================
    function g:AddButton(config)
        config = type(config) == "string" and { Text = config } or config
        local e = newElem()
        e._text = config.Text or "Button"
        e._callback = config.Callback or function() end
        e._disabled = config.Disabled or false
        e._x, e._y, e._w = 0, 0, 100

        local bg = e._addO(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(100, ELEM_H), ZIndex = 10, Corner = 3, Visible = false })
        local border = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(100, ELEM_H), ZIndex = 11, Corner = 3, Visible = false })
        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 12, Font = FONT, Center = true, Visible = false })

        function e:GetHeight() return ELEM_H end

        function e:Render(x, y, w)
            self._x, self._y, self._w = x, y, w
            local hover = MouseInBox(Vector2.new(x,y), Vector2.new(w, ELEM_H))
            bg.Color = self._disabled and Theme.Surface or (hover and Theme.Surface or Theme.SurfaceAlt)
            border.Color = hover and Theme.Accent or Theme.Border
            bg.Position = Vector2.new(x,y); bg.Size = Vector2.new(w, ELEM_H); bg.Visible = true
            border.Position = Vector2.new(x,y); border.Size = Vector2.new(w, ELEM_H); border.Visible = true
            lbl.Position = Vector2.new(x + w/2, y + 5); lbl.Color = self._disabled and Theme.TextDisabled or Theme.Text; lbl.Visible = true
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            if MouseInBox(Vector2.new(x,y), Vector2.new(w, ELEM_H)) then
                pcall(self._callback)
            end
        end

        function e:SetDisabled(v) self._disabled = v end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  TOGGLE
    -- ======================================================
    function g:AddToggle(id, config)
        config = config or {}
        local e = newElem()
        e._id = id
        e._text = config.Text or id
        e._value = config.Default ~= nil and config.Default or false
        e._callback = config.Callback or function() end
        e._disabled = config.Disabled or false

        local box = e._addO(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(TOGGLE_SIZE, TOGGLE_SIZE), ZIndex = 10, Corner = 2, Visible = false })
        local boxBorder = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(TOGGLE_SIZE, TOGGLE_SIZE), ZIndex = 11, Corner = 2, Visible = false })
        local check = e._addO(Draw.Square, { Color = Theme.Accent, Position = Vector2.new(0,0), Size = Vector2.new(TOGGLE_SIZE-4, TOGGLE_SIZE-4), ZIndex = 12, Corner = 1, Visible = false })
        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })

        -- Expose value
        window.AllObjects["toggle_"..id] = e -- allow external ref

        function e:GetHeight() return ELEM_H end

        function e:Render(x, y, w)
            local cx, cy = x, y + math.floor((ELEM_H - TOGGLE_SIZE)/2)
            box.Position = Vector2.new(cx, cy); box.Size = Vector2.new(TOGGLE_SIZE, TOGGLE_SIZE)
            box.Color = self._disabled and Theme.Surface or Theme.SurfaceAlt
            box.Visible = true
            boxBorder.Position = Vector2.new(cx, cy); boxBorder.Size = Vector2.new(TOGGLE_SIZE, TOGGLE_SIZE)
            boxBorder.Color = self._value and Theme.Accent or Theme.Border
            boxBorder.Visible = true
            check.Position = Vector2.new(cx+2, cy+2); check.Size = Vector2.new(TOGGLE_SIZE-4, TOGGLE_SIZE-4)
            check.Visible = self._value and not self._disabled
            lbl.Position = Vector2.new(cx + TOGGLE_SIZE + 7, y + 4)
            lbl.Color = self._disabled and Theme.TextDisabled or Theme.Text
            lbl.Text = self._text
            lbl.Visible = true
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            if MouseInBox(Vector2.new(x, y), Vector2.new(w, ELEM_H)) then
                self._value = not self._value
                pcall(self._callback, self._value)
            end
        end

        function e:SetValue(v)
            self._value = v
            pcall(self._callback, self._value)
        end

        function e:SetDisabled(v) self._disabled = v end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  SLIDER
    -- ======================================================
    function g:AddSlider(id, config)
        config = config or {}
        local e = newElem()
        e._id = id
        e._text = config.Text or id
        e._min = config.Min or 0
        e._max = config.Max or 100
        e._value = Clamp(config.Default or e._min, e._min, e._max)
        e._rounding = config.Rounding or 0
        e._suffix = config.Suffix or ""
        e._callback = config.Callback or function() end
        e._disabled = config.Disabled or false
        e._dragging = false
        e._rx, e._ry, e._rw = 0, 0, 100

        local trackBg = e._addO(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(100,6), ZIndex = 10, Corner = 3, Visible = false })
        local trackFill = e._addO(Draw.Square, { Color = Theme.Accent, Position = Vector2.new(0,0), Size = Vector2.new(0,6), ZIndex = 11, Corner = 3, Visible = false })
        local thumb = e._addO(Draw.Circle, { Color = Theme.Text, Position = Vector2.new(0,0), Radius = 5, ZIndex = 12, Filled = true, Visible = false })
        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })
        local valLbl = e._addO(Draw.Text, { Text = tostring(e._value), Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })

        local TRACK_Y_OFFSET = 17
        local TRACK_H = 6

        function e:GetHeight() return TRACK_Y_OFFSET + TRACK_H + 4 end

        function e:_getFrac()
            return (self._value - self._min) / (self._max - self._min)
        end

        function e:Render(x, y, w)
            self._rx, self._ry, self._rw = x, y, w
            local tx = x
            local ty = y + TRACK_Y_OFFSET
            local frac = self:_getFrac()
            local fillW = math.max(6, math.floor(frac * w))

            lbl.Position = Vector2.new(x, y); lbl.Visible = true
            valLbl.Text = Round(self._value, self._rounding) .. self._suffix
            valLbl.Position = Vector2.new(x + w - #valLbl.Text * 7, y); valLbl.Visible = true

            trackBg.Position = Vector2.new(tx, ty); trackBg.Size = Vector2.new(w, TRACK_H); trackBg.Visible = true
            trackFill.Position = Vector2.new(tx, ty); trackFill.Size = Vector2.new(fillW, TRACK_H)
            trackFill.Color = self._disabled and Theme.TextDisabled or Theme.Accent
            trackFill.Visible = true
            thumb.Position = Vector2.new(tx + fillW, ty + TRACK_H/2)
            thumb.Color = self._disabled and Theme.TextDisabled or Theme.Text
            thumb.Visible = true
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            local ty = y + TRACK_Y_OFFSET
            if MouseInBox(Vector2.new(x, ty-4), Vector2.new(w, TRACK_H+8)) then
                self._dragging = true
                self:_updateFromMouse(mx, x, w)
            end
        end

        function e:OnRelease()
            self._dragging = false
        end

        function e:OnMouseMove(mx, my, x, y, w)
            if self._dragging then
                self:_updateFromMouse(mx, x, w)
            end
        end

        function e:_updateFromMouse(mx, x, w)
            local frac = Clamp((mx - x) / w, 0, 1)
            local raw = self._min + frac * (self._max - self._min)
            self._value = Round(raw, self._rounding)
            self._value = Clamp(self._value, self._min, self._max)
            pcall(self._callback, self._value)
        end

        function e:SetValue(v)
            self._value = Clamp(v, self._min, self._max)
            pcall(self._callback, self._value)
        end

        function e:SetDisabled(v) self._disabled = v end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  DROPDOWN
    -- ======================================================
    function g:AddDropdown(id, config)
        config = config or {}
        local e = newElem()
        e._id = id
        e._text = config.Text or id
        e._values = config.Values or {}
        e._value = config.Default
        e._multi = config.Multi or false
        e._multiValues = {}
        e._callback = config.Callback or function() end
        e._disabled = config.Disabled or false
        e._open = false
        e._hoverIdx = nil

        -- Validate default
        if e._multi then
            e._multiValues = {}
            if type(config.Default) == "table" then
                for _, v in ipairs(config.Default) do e._multiValues[v] = true end
            end
        else
            if config.Default and not table.find(e._values, config.Default) then
                e._value = nil
            end
        end

        local DROPDOWN_H = ELEM_H
        local ITEM_H = 18

        -- Static objects
        local bg = e._addO(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(100, DROPDOWN_H), ZIndex = 10, Corner = 3, Visible = false })
        local border = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(100, DROPDOWN_H), ZIndex = 11, Corner = 3, Visible = false })
        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })
        local valLbl = e._addO(Draw.Text, { Text = "--", Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 12, Font = FONT, Visible = false })
        local arrow = e._addO(Draw.Text, { Text = "▾", Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 12, Font = FONT, Visible = false })

        -- Dropdown list (max 8 items, scrollable via hover)
        local MAX_VIS = 6
        local listObjs = {}
        for i = 1, MAX_VIS do
            local row = {}
            row.bg = e._addO(Draw.Square, { Color = Theme.Surface, Position = Vector2.new(0,0), Size = Vector2.new(100, ITEM_H), ZIndex = 20, Visible = false })
            row.border = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(100, ITEM_H), ZIndex = 21, Visible = false })
            row.text = e._addO(Draw.Text, { Text = "", Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 22, Font = FONT, Visible = false })
            row.check = e._addO(Draw.Text, { Text = "✓", Color = Theme.Accent, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 22, Font = FONT, Visible = false })
            table.insert(listObjs, row)
        end

        -- List bg
        local listBg = e._addO(Draw.Square, { Color = Theme.Surface, Position = Vector2.new(0,0), Size = Vector2.new(100,10), ZIndex = 19, Corner = 3, Visible = false })
        local listBorder = e._addO(Draw.Square, { Filled = false, Color = Theme.Accent, Position = Vector2.new(0,0), Size = Vector2.new(100,10), ZIndex = 20, Corner = 3, Visible = false })

        e._scroll = 0 -- scroll offset (item index)

        function e:_getDisplayValue()
            if self._multi then
                local parts = {}
                for v, on in pairs(self._multiValues) do
                    if on then table.insert(parts, tostring(v)) end
                end
                return #parts > 0 and table.concat(parts, ", ") or "--"
            else
                return self._value and tostring(self._value) or "--"
            end
        end

        function e:GetHeight()
            if self._open then
                local itemCount = math.min(#self._values, MAX_VIS)
                return ELEM_H + 17 + itemCount * ITEM_H + 4
            end
            return ELEM_H + 17
        end

        function e:Render(x, y, w)
            self._rx, self._ry, self._rw = x, y, w
            local LABEL_H = 14
            lbl.Position = Vector2.new(x, y); lbl.Text = self._text; lbl.Visible = true

            local by = y + LABEL_H + 2
            bg.Position = Vector2.new(x, by); bg.Size = Vector2.new(w, DROPDOWN_H); bg.Visible = true
            border.Position = Vector2.new(x, by); border.Size = Vector2.new(w, DROPDOWN_H)
            border.Color = self._open and Theme.Accent or Theme.Border; border.Visible = true
            valLbl.Text = self:_getDisplayValue()
            valLbl.Position = Vector2.new(x+6, by+4); valLbl.Color = self._disabled and Theme.TextDisabled or Theme.Text; valLbl.Visible = true
            arrow.Text = self._open and "▴" or "▾"
            arrow.Position = Vector2.new(x+w-14, by+4); arrow.Visible = true

            -- List
            if self._open then
                local lx, ly = x, by + DROPDOWN_H + 2
                local visCount = math.min(#self._values, MAX_VIS)
                local lh = visCount * ITEM_H + 4
                listBg.Position = Vector2.new(lx, ly); listBg.Size = Vector2.new(w, lh); listBg.Visible = true
                listBorder.Position = Vector2.new(lx, ly); listBorder.Size = Vector2.new(w, lh); listBorder.Visible = true

                for i = 1, MAX_VIS do
                    local idx = i + self._scroll
                    local row = listObjs[i]
                    local val = self._values[idx]
                    if val then
                        local iy = ly + 2 + (i-1)*ITEM_H
                        local hover = self._hoverIdx == idx
                        local selected = self._multi and self._multiValues[val] or self._value == val
                        row.bg.Position = Vector2.new(lx, iy); row.bg.Size = Vector2.new(w, ITEM_H)
                        row.bg.Color = hover and Theme.SurfaceAlt or Theme.Surface; row.bg.Visible = true
                        row.border.Position = Vector2.new(lx, iy); row.border.Size = Vector2.new(w, ITEM_H)
                        row.border.Color = selected and Theme.Accent or Theme.Border; row.border.Visible = true
                        row.text.Text = tostring(val); row.text.Position = Vector2.new(lx+6, iy+3)
                        row.text.Color = selected and Theme.Accent or Theme.Text; row.text.Visible = true
                        row.check.Position = Vector2.new(lx+w-14, iy+3); row.check.Visible = selected
                    else
                        row.bg.Visible = false; row.border.Visible = false
                        row.text.Visible = false; row.check.Visible = false
                    end
                end
            else
                listBg.Visible = false; listBorder.Visible = false
                for _, row in ipairs(listObjs) do
                    row.bg.Visible = false; row.border.Visible = false
                    row.text.Visible = false; row.check.Visible = false
                end
            end
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            local LABEL_H = 14
            local by = y + LABEL_H + 2

            -- Click on header
            if MouseInBox(Vector2.new(x, by), Vector2.new(w, DROPDOWN_H)) then
                self._open = not self._open
                return
            end

            -- Click on list item
            if self._open then
                local ly = by + DROPDOWN_H + 2
                local visCount = math.min(#self._values, MAX_VIS)
                for i = 1, visCount do
                    local idx = i + self._scroll
                    local val = self._values[idx]
                    if val then
                        local iy = ly + 2 + (i-1)*ITEM_H
                        if MouseInBox(Vector2.new(x, iy), Vector2.new(w, ITEM_H)) then
                            if self._multi then
                                self._multiValues[val] = not self._multiValues[val] or nil
                            else
                                self._value = self._value == val and nil or val
                                self._open = false
                            end
                            pcall(self._callback, self._multi and self._multiValues or self._value)
                            return
                        end
                    end
                end
                -- Click outside = close
                self._open = false
            end
        end

        function e:OnMouseMove(mx, my, x, y, w)
            if not self._open then self._hoverIdx = nil; return end
            local LABEL_H = 14
            local by = y + LABEL_H + 2
            local ly = by + DROPDOWN_H + 2
            local visCount = math.min(#self._values, MAX_VIS)
            self._hoverIdx = nil
            for i = 1, visCount do
                local idx = i + self._scroll
                local iy = ly + 2 + (i-1)*ITEM_H
                if MouseInBox(Vector2.new(x, iy), Vector2.new(w, ITEM_H)) then
                    self._hoverIdx = idx
                    break
                end
            end
        end

        function e:SetValue(v)
            if self._multi then
                if type(v) == "table" then
                    self._multiValues = {}
                    for _, val in ipairs(v) do self._multiValues[val] = true end
                end
            else
                self._value = v
            end
            pcall(self._callback, self._multi and self._multiValues or self._value)
        end

        function e:SetValues(vals)
            self._values = vals
            self._value = nil
            self._multiValues = {}
        end

        function e:SetDisabled(v)
            self._disabled = v
            if v then self._open = false end
        end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  INPUT (TextBox approximation — click to type)
    -- ======================================================
    function g:AddInput(id, config)
        config = config or {}
        local e = newElem()
        e._id = id
        e._text = config.Text or id
        e._value = config.Default or ""
        e._placeholder = config.Placeholder or "Type here..."
        e._callback = config.Callback or function() end
        e._numeric = config.Numeric or false
        e._disabled = config.Disabled or false
        e._focused = false
        e._cursor = true
        e._cursorTimer = 0

        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })
        local bg = e._addO(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(100, ELEM_H), ZIndex = 10, Corner = 3, Visible = false })
        local border = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(100, ELEM_H), ZIndex = 11, Corner = 3, Visible = false })
        local valLbl = e._addO(Draw.Text, { Text = "", Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 12, Font = FONT, Visible = false })

        -- Key input connection
        local kconn = UIS.InputBegan:Connect(function(input, gp)
            if not e._focused or e._disabled then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

            local kc = input.KeyCode
            if kc == Enum.KeyCode.Backspace then
                e._value = e._value:sub(1, -2)
                pcall(e._callback, e._value)
            elseif kc == Enum.KeyCode.Return then
                e._focused = false
            elseif kc == Enum.KeyCode.Escape then
                e._focused = false
            end
        end)

        local charConn = UIS.InputBegan:Connect(function(input, gp)
            if not e._focused or e._disabled then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local kc = input.KeyCode
            -- Convert KeyCode to character
            local char = ""
            local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
            local name = kc.Name
            if #name == 1 then
                char = shift and name:upper() or name:lower()
            elseif name == "Space" then char = " "
            elseif name == "Period" then char = shift and ">" or "."
            elseif name == "Comma" then char = shift and "<" or ","
            elseif name == "Minus" then char = shift and "_" or "-"
            elseif name == "Equals" then char = shift and "+" or "="
            elseif name:match("^%d$") then char = name
            end
            if char ~= "" then
                if e._numeric and not tonumber(e._value .. char) and char ~= "-" then return end
                e._value = e._value .. char
                pcall(e._callback, e._value)
            end
        end)

        table.insert(e._allObjs, { Remove = function() kconn:Disconnect(); charConn:Disconnect() end })

        function e:GetHeight() return 14 + ELEM_H + 2 end

        function e:Render(x, y, w)
            self._cursorTimer = self._cursorTimer + 1
            if self._cursorTimer > 30 then self._cursor = not self._cursor; self._cursorTimer = 0 end

            lbl.Position = Vector2.new(x, y); lbl.Visible = true
            local by = y + 16
            bg.Position = Vector2.new(x, by); bg.Size = Vector2.new(w, ELEM_H); bg.Visible = true
            border.Position = Vector2.new(x, by); border.Size = Vector2.new(w, ELEM_H)
            border.Color = self._focused and Theme.Accent or Theme.Border; border.Visible = true
            local display = self._value ~= "" and self._value or self._placeholder
            local cursorStr = (self._focused and self._cursor) and "|" or ""
            valLbl.Text = display .. cursorStr
            valLbl.Color = self._value ~= "" and Theme.Text or Theme.TextDim
            valLbl.Position = Vector2.new(x+6, by+4); valLbl.Visible = true
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            local by = y + 16
            self._focused = MouseInBox(Vector2.new(x, by), Vector2.new(w, ELEM_H))
        end

        function e:SetValue(v)
            self._value = tostring(v)
            pcall(self._callback, self._value)
        end

        function e:SetDisabled(v)
            self._disabled = v
            if v then self._focused = false end
        end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  KEYBIND PICKER
    -- ======================================================
    function g:AddKeyPicker(id, config)
        config = config or {}
        local e = newElem()
        e._id = id
        e._text = config.Text or id
        e._value = config.Default -- KeyCode enum or nil
        e._callback = config.Callback or function() end
        e._listening = false
        e._disabled = config.Disabled or false
        e._mode = config.Mode or "Toggle" -- Toggle / Hold / Always
        e._toggled = false

        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })
        local bg = e._addO(Draw.Square, { Color = Theme.SurfaceAlt, Position = Vector2.new(0,0), Size = Vector2.new(60, ELEM_H), ZIndex = 10, Corner = 3, Visible = false })
        local border = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(60, ELEM_H), ZIndex = 11, Corner = 3, Visible = false })
        local keyLbl = e._addO(Draw.Text, { Text = "None", Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 12, Font = FONT, Center = true, Visible = false })

        -- Listen for key press while listening
        local listenConn = UIS.InputBegan:Connect(function(input, gp)
            if not e._listening or e._disabled then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    e._value = nil
                    e._listening = false
                else
                    e._value = input.KeyCode
                    e._listening = false
                end
            end
        end)

        -- Keybind active logic
        local bindConn = UIS.InputBegan:Connect(function(input, gp)
            if e._disabled or e._listening or not e._value then return end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == e._value then
                if e._mode == "Toggle" then
                    e._toggled = not e._toggled
                    pcall(e._callback, e._toggled)
                elseif e._mode == "Hold" then
                    e._toggled = true
                    pcall(e._callback, true)
                elseif e._mode == "Always" then
                    pcall(e._callback, true)
                end
            end
        end)

        local bindConnEnd = UIS.InputEnded:Connect(function(input)
            if e._disabled or not e._value then return end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == e._value then
                if e._mode == "Hold" then
                    e._toggled = false
                    pcall(e._callback, false)
                end
            end
        end)

        table.insert(e._allObjs, { Remove = function() listenConn:Disconnect(); bindConn:Disconnect(); bindConnEnd:Disconnect() end })

        function e:GetHeight() return ELEM_H end

        function e:_getKeyName()
            if self._listening then return "..." end
            if not self._value then return "None" end
            return tostring(self._value.Name):gsub("KeyCode.", "")
        end

        function e:Render(x, y, w)
            local BTN_W = 70
            lbl.Position = Vector2.new(x, y + 4); lbl.Visible = true
            local bx = x + w - BTN_W
            bg.Position = Vector2.new(bx, y); bg.Size = Vector2.new(BTN_W, ELEM_H)
            bg.Color = self._listening and Theme.AccentDark or Theme.SurfaceAlt; bg.Visible = true
            border.Position = Vector2.new(bx, y); border.Size = Vector2.new(BTN_W, ELEM_H)
            border.Color = self._listening and Theme.Accent or (self._toggled and Theme.Enabled or Theme.Border); border.Visible = true
            keyLbl.Text = self:_getKeyName(); keyLbl.Position = Vector2.new(bx + BTN_W/2, y+5); keyLbl.Visible = true
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            local BTN_W = 70
            local bx = x + w - BTN_W
            if MouseInBox(Vector2.new(bx, y), Vector2.new(BTN_W, ELEM_H)) then
                self._listening = true
            end
        end

        function e:GetState()
            if self._mode == "Always" then return true end
            if self._mode == "Hold" then return self._value and UIS:IsKeyDown(self._value) or false end
            return self._toggled
        end

        function e:SetValue(kc)
            self._value = kc
        end

        function e:SetDisabled(v) self._disabled = v end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  COLOR PICKER
    -- ======================================================
    function g:AddColorPicker(id, config)
        config = config or {}
        local e = newElem()
        e._id = id
        e._text = config.Text or id
        e._value = config.Default or Color3.fromRGB(255, 255, 255)
        e._callback = config.Callback or function() end
        e._open = false
        e._disabled = config.Disabled or false

        -- HSV from initial
        local h, s, v = Color3.toHSV(e._value)
        e._h, e._s, e._v = h, s, v
        e._dragMode = nil -- "sv", "h", nil

        local SWATCH_SIZE = 16
        local PICKER_W = 150
        local PICKER_H = 110
        local HUE_W = 10
        local SV_W = PICKER_W - HUE_W - 4

        local lbl = e._addO(Draw.Text, { Text = e._text, Color = Theme.TextDim, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 10, Font = FONT, Visible = false })
        local swatch = e._addO(Draw.Square, { Color = e._value, Position = Vector2.new(0,0), Size = Vector2.new(SWATCH_SIZE, SWATCH_SIZE), ZIndex = 10, Corner = 2, Visible = false })
        local swatchBorder = e._addO(Draw.Square, { Filled = false, Color = Theme.Border, Position = Vector2.new(0,0), Size = Vector2.new(SWATCH_SIZE, SWATCH_SIZE), ZIndex = 11, Corner = 2, Visible = false })

        -- Picker panel
        local panelBg = e._addO(Draw.Square, { Color = Theme.Surface, Position = Vector2.new(0,0), Size = Vector2.new(PICKER_W+8, PICKER_H+8), ZIndex = 25, Corner = 4, Visible = false })
        local panelBorder = e._addO(Draw.Square, { Filled = false, Color = Theme.Accent, Position = Vector2.new(0,0), Size = Vector2.new(PICKER_W+8, PICKER_H+8), ZIndex = 26, Corner = 4, Visible = false })

        -- SV square (drawn as gradient approximation with rows of squares)
        -- We'll draw a simplified 8x8 grid of squares
        local SV_ROWS = 8
        local SV_COLS = 8
        local svCells = {}
        for row = 1, SV_ROWS do
            svCells[row] = {}
            for col = 1, SV_COLS do
                local cell = e._addO(Draw.Square, { Color = Color3.new(1,1,1), Position = Vector2.new(0,0), Size = Vector2.new(1,1), ZIndex = 27, Visible = false })
                svCells[row][col] = cell
            end
        end
        local svCursor = e._addO(Draw.Circle, { Color = Color3.new(1,1,1), Position = Vector2.new(0,0), Radius = 4, Filled = false, Thickness = 2, ZIndex = 28, Visible = false })

        -- Hue bar (8 segments)
        local HUE_SEGS = 12
        local hueCells = {}
        for i = 1, HUE_SEGS do
            local cell = e._addO(Draw.Square, { Color = Color3.new(1,1,1), Position = Vector2.new(0,0), Size = Vector2.new(1,1), ZIndex = 27, Visible = false })
            hueCells[i] = cell
        end
        local hueCursor = e._addO(Draw.Square, { Filled = false, Color = Color3.new(1,1,1), Position = Vector2.new(0,0), Size = Vector2.new(HUE_W+2, 4), ZIndex = 28, Visible = false })

        -- Hex input label
        local hexLbl = e._addO(Draw.Text, { Text = "#FFFFFF", Color = Theme.Text, Position = Vector2.new(0,0), Size = FONT_SIZE, ZIndex = 28, Font = FONT, Visible = false })

        function e:_updateColor()
            self._value = Color3.fromHSV(self._h, self._s, self._v)
            swatch.Color = self._value
            pcall(self._callback, self._value)
        end

        function e:GetHeight()
            if self._open then return SWATCH_SIZE + PICKER_H + 14 end
            return SWATCH_SIZE
        end

        function e:Render(x, y, w)
            self._rx, self._ry, self._rw = x, y, w
            lbl.Position = Vector2.new(x + SWATCH_SIZE + 6, y + 1); lbl.Visible = true
            swatch.Position = Vector2.new(x, y); swatch.Size = Vector2.new(SWATCH_SIZE, SWATCH_SIZE); swatch.Color = self._value; swatch.Visible = true
            swatchBorder.Position = Vector2.new(x, y); swatchBorder.Size = Vector2.new(SWATCH_SIZE, SWATCH_SIZE); swatchBorder.Visible = true

            if self._open then
                local px = x
                local py = y + SWATCH_SIZE + 4
                local svX = px + 4
                local svY = py + 4
                local svCellW = math.floor(SV_W / SV_COLS)
                local svCellH = math.floor((PICKER_H - 8) / SV_ROWS)
                local hX = svX + SV_W + 4
                local hY = svY
                local hSegH = math.floor((PICKER_H - 8) / HUE_SEGS)

                panelBg.Position = Vector2.new(px, py); panelBg.Size = Vector2.new(PICKER_W+8, PICKER_H+8); panelBg.Visible = true
                panelBorder.Position = Vector2.new(px, py); panelBorder.Size = Vector2.new(PICKER_W+8, PICKER_H+8); panelBorder.Visible = true

                -- SV Grid
                for row = 1, SV_ROWS do
                    for col = 1, SV_COLS do
                        local cs = (col-1)/(SV_COLS-1)
                        local cv = 1 - (row-1)/(SV_ROWS-1)
                        local cell = svCells[row][col]
                        cell.Position = Vector2.new(svX + (col-1)*svCellW, svY + (row-1)*svCellH)
                        cell.Size = Vector2.new(svCellW+1, svCellH+1)
                        cell.Color = Color3.fromHSV(self._h, cs, cv)
                        cell.Visible = true
                    end
                end

                -- SV Cursor
                local cursorX = svX + self._s * SV_W
                local cursorY = svY + (1-self._v) * (PICKER_H-8)
                svCursor.Position = Vector2.new(cursorX, cursorY); svCursor.Visible = true

                -- Hue Bar
                for i = 1, HUE_SEGS do
                    local hue = (i-1)/(HUE_SEGS-1)
                    local cell = hueCells[i]
                    cell.Position = Vector2.new(hX, hY + (i-1)*hSegH)
                    cell.Size = Vector2.new(HUE_W, hSegH+1)
                    cell.Color = Color3.fromHSV(hue, 1, 1)
                    cell.Visible = true
                end

                -- Hue cursor
                local hCY = hY + self._h * (PICKER_H-8)
                hueCursor.Position = Vector2.new(hX-1, hCY-2); hueCursor.Size = Vector2.new(HUE_W+2, 4); hueCursor.Visible = true

                -- Hex label
                hexLbl.Text = "#"..string.format("%02X%02X%02X",
                    math.floor(self._value.R*255),
                    math.floor(self._value.G*255),
                    math.floor(self._value.B*255))
                hexLbl.Position = Vector2.new(px+4, py+PICKER_H-2); hexLbl.Visible = true
            else
                panelBg.Visible = false; panelBorder.Visible = false
                hexLbl.Visible = false; svCursor.Visible = false; hueCursor.Visible = false
                for row = 1, SV_ROWS do for col = 1, SV_COLS do svCells[row][col].Visible = false end end
                for i = 1, HUE_SEGS do hueCells[i].Visible = false end
            end
        end

        function e:OnClick(mx, my, x, y, w)
            if self._disabled then return end
            -- Swatch click
            if MouseInBox(Vector2.new(x,y), Vector2.new(SWATCH_SIZE, SWATCH_SIZE)) then
                self._open = not self._open
                self._dragMode = nil
                return
            end
            if not self._open then return end

            local px = x
            local py = y + SWATCH_SIZE + 4
            local svX = px + 4
            local svY = py + 4
            local hX = svX + SV_W + 4
            local hY = svY

            -- SV area
            if MouseInBox(Vector2.new(svX, svY), Vector2.new(SV_W, PICKER_H-8)) then
                self._dragMode = "sv"
                self._s = Clamp((mx - svX) / SV_W, 0, 1)
                self._v = 1 - Clamp((my - svY) / (PICKER_H-8), 0, 1)
                self:_updateColor()
                return
            end
            -- Hue bar
            if MouseInBox(Vector2.new(hX, hY), Vector2.new(HUE_W, PICKER_H-8)) then
                self._dragMode = "h"
                self._h = Clamp((my - hY) / (PICKER_H-8), 0, 1)
                self:_updateColor()
                return
            end
            -- Close if outside panel
            if not MouseInBox(Vector2.new(px, py), Vector2.new(PICKER_W+8, PICKER_H+8)) then
                self._open = false
                self._dragMode = nil
            end
        end

        function e:OnRelease()
            self._dragMode = nil
        end

        function e:OnMouseMove(mx, my, x, y, w)
            if not self._open or not self._dragMode then return end
            local px = x
            local py = y + SWATCH_SIZE + 4
            local svX = px + 4
            local svY = py + 4
            local hX = svX + SV_W + 4
            local hY = svY

            if self._dragMode == "sv" then
                self._s = Clamp((mx - svX) / SV_W, 0, 1)
                self._v = 1 - Clamp((my - svY) / (PICKER_H-8), 0, 1)
                self:_updateColor()
            elseif self._dragMode == "h" then
                self._h = Clamp((my - hY) / (PICKER_H-8), 0, 1)
                self:_updateColor()
            end
        end

        function e:SetValue(c)
            self._value = c
            self._h, self._s, self._v = Color3.toHSV(c)
            swatch.Color = c
            pcall(self._callback, c)
        end

        function e:SetDisabled(v) self._disabled = v end

        table.insert(g._elements, e)
        return e
    end

    -- ======================================================
    --  DEPENDENCY BOX
    -- ======================================================
    function g:AddDependencyBox()
        local depbox = CreateGroupbox("", window, false)
        depbox._isDependencyBox = true
        depbox._dependencies = {} -- { {elem, expectedValue} }
        depbox._titleBg.Visible = false
        depbox._titleFill.Visible = false
        depbox._titleAccent.Visible = false
        depbox._titleText.Visible = false
        depbox._divider.Visible = false
        depbox._bg.Visible = false
        depbox._border.Visible = false

        function depbox:SetupDependencies(deps)
            self._dependencies = deps
        end

        local originalRender = depbox.Render
        function depbox:Render(x, y, w)
            -- Check dependencies
            local show = true
            for _, dep in ipairs(self._dependencies) do
                local elem, expected = dep[1], dep[2]
                local actual = elem._value
                if actual ~= expected then show = false; break end
            end
            self._visible = show
            if not show then return 0 end
            -- Render just elements, no chrome
            local h = GROUPBOX_PAD
            for _, elem in ipairs(self._elements) do
                if elem._visible ~= false then
                    elem:Render(x, y + h, w)
                    h = h + elem:GetHeight() + ELEM_GAP
                end
            end
            return h + GROUPBOX_PAD
        end

        function depbox:GetHeight()
            local show = true
            for _, dep in ipairs(self._dependencies) do
                local elem, expected = dep[1], dep[2]
                if elem._value ~= expected then show = false; break end
            end
            if not show then return 0 end
            local h = GROUPBOX_PAD * 2
            for _, elem in ipairs(self._elements) do
                if elem._visible ~= false then
                    h = h + elem:GetHeight() + ELEM_GAP
                end
            end
            return h
        end

        table.insert(g._elements, depbox)
        return depbox
    end

    return g
end

-- ============================================================
--  RETURN
-- ============================================================
return Library
