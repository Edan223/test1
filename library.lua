--[[
    Matcha Executor UI Library
    A comprehensive Roblox UI system with draggable windows, tabs, toggles, sliders, and more
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Library = {
    windows = {},
    notifications = {},
    theme = {
        accent = Color3.fromRGB(0, 120, 215),
        background = Color3.fromRGB(20, 20, 20),
        text = Color3.fromRGB(255, 255, 255),
        darkBackground = Color3.fromRGB(15, 15, 15),
        lightBackground = Color3.fromRGB(30, 30, 30),
        border = Color3.fromRGB(50, 50, 50),
    },
    keybinds = {},
    visibleKeybind = Enum.KeyCode.RightShift,
    toggleKeybindActive = true,
}

-- Utility Functions
local function CreateInstance(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        instance[prop] = value
    end
    return instance
end

local function GetTextSize(text, fontSize, fontFace, containerSize)
    local textService = game:GetService("TextService")
    local textParams = Instance.new("GetTextBoundsParams")
    textParams.Text = text
    textParams.Font = fontFace or Enum.Font.GothamPro
    textParams.TextSize = fontSize
    textParams.Size = containerSize or Vector2.new(999, 999)
    return textService:GetTextBoundsAsync(textParams)
end

local function Tween(instance, tweenInfo, properties)
    local tween = game:GetService("TweenService"):Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    
    return Color3.new(r + m, g + m, b + m)
end

local function RGBtoHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min
    
    local h = 0
    if delta > 0 then
        if max == r then h = 60 * (((g - b) / delta) % 6)
        elseif max == g then h = 60 * (((b - r) / delta) + 2)
        else h = 60 * (((r - g) / delta) + 4) end
    end
    
    local s = max == 0 and 0 or delta / max
    local v = max
    
    return h, s, v
end

-- Element Base Class
local Element = {}
Element.__index = Element

function Element:new(name, parent)
    local self = setmetatable({}, Element)
    self.name = name
    self.parent = parent
    self.container = nil
    self.visible = true
    self.dependencies = {}
    self.tooltip = nil
    return self
end

function Element:SetVisible(visible)
    self.visible = visible
    if self.container then
        self.container.Visible = visible
    end
    self:UpdateDependencies()
end

function Element:AddDependency(toggle, state)
    table.insert(self.dependencies, {toggle = toggle, state = state})
end

function Element:UpdateDependencies()
    local shouldBeVisible = self.visible
    for _, dep in ipairs(self.dependencies) do
        if dep.toggle.enabled ~= dep.state then
            shouldBeVisible = false
            break
        end
    end
    if self.container then
        self.container.Visible = shouldBeVisible
    end
end

function Element:SetTooltip(text)
    self.tooltip = text
end

-- Window Class
local Window = setmetatable({}, Element)
Window.__index = Window

function Window:new(title, size)
    local self = Element.new(self, title, nil)
    self.title = title
    self.size = size or UDim2.new(0, 500, 0, 400)
    self.position = UDim2.new(0.5, -250, 0.5, -200)
    self.dragging = false
    self.dragStart = nil
    self.tabs = {}
    self.currentTab = nil
    self.visible = true
    
    self:CreateWindow()
    table.insert(Library.windows, self)
    return self
end

function Window:CreateWindow()
    local screenGui = CreateInstance("ScreenGui", {
        Parent = CoreGui,
        ResetOnSpawn = false,
        Name = self.title .. "Gui",
    })
    
    -- Main window frame
    local mainFrame = CreateInstance("Frame", {
        Parent = screenGui,
        Name = "MainWindow",
        Size = self.size,
        Position = self.position,
        BackgroundColor3 = Library.theme.darkBackground,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        ClipsDescendants = true,
    })
    
    -- Title bar
    local titleBar = CreateInstance("Frame", {
        Parent = mainFrame,
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Library.theme.background,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local titleLabel = CreateInstance("TextLabel", {
        Parent = titleBar,
        Name = "Title",
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        TextSize = 14,
        Font = Enum.Font.GothamPro,
        Text = self.title,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    -- Close button
    local closeBtn = CreateInstance("TextButton", {
        Parent = titleBar,
        Name = "CloseBtn",
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundColor3 = Library.theme.accent,
        TextColor3 = Library.theme.text,
        Text = "×",
        TextSize = 20,
        Font = Enum.Font.GothamPro,
    })
    
    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- Tab bar
    local tabBar = CreateInstance("Frame", {
        Parent = mainFrame,
        Name = "TabBar",
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Library.theme.background,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local tabListLayout = CreateInstance("UIListLayout", {
        Parent = tabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 0),
    })
    
    -- Content area
    local contentArea = CreateInstance("Frame", {
        Parent = mainFrame,
        Name = "Content",
        Size = UDim2.new(1, 0, 1, -60),
        Position = UDim2.new(0, 0, 0, 60),
        BackgroundColor3 = Library.theme.darkBackground,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    
    self.container = mainFrame
    self.screenGui = screenGui
    self.titleBar = titleBar
    self.tabBar = tabBar
    self.contentArea = contentArea
    
    -- Dragging
    local dragStart, dragOffset
    titleBar.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.dragging = true
            dragStart = input.Position
            dragOffset = mainFrame.AbsolutePosition
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if self.dragging and input.UserInputType == Enum.UserInputType.Mouse then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                0, dragOffset.X + delta.X,
                0, dragOffset.Y + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.dragging = false
        end
    end)
    
    -- Keybind toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Library.visibleKeybind and Library.toggleKeybindActive then
            self:Toggle()
        end
    end)
end

function Window:Toggle()
    self.visible = not self.visible
    self.container.Visible = self.visible
end

function Window:CreateTab(name)
    local tab = {
        name = name,
        groups = {},
        container = nil,
    }
    
    -- Create tab button
    local tabBtn = CreateInstance("TextButton", {
        Parent = self.tabBar,
        Name = name .. "Tab",
        Size = UDim2.new(0, 100, 1, 0),
        BackgroundColor3 = Library.theme.background,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    -- Create tab content
    local tabContent = CreateInstance("Frame", {
        Parent = self.contentArea,
        Name = name .. "Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
    })
    
    local scrolling = CreateInstance("ScrollingFrame", {
        Parent = tabContent,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        CanvasSize = UDim2.new(1, 0, 0, 10),
    })
    
    local listLayout = CreateInstance("UIListLayout", {
        Parent = scrolling,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 5),
    })
    
    tab.container = scrolling
    tab.tabBtn = tabBtn
    tab.layout = listLayout
    
    tabBtn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)
    
    table.insert(self.tabs, tab)
    
    if not self.currentTab then
        self:SelectTab(name)
    end
    
    return tab
end

function Window:SelectTab(tabName)
    for _, tab in ipairs(self.tabs) do
        if tab.name == tabName then
            tab.container.Parent.Visible = true
            tab.tabBtn.BackgroundColor3 = Library.theme.accent
            self.currentTab = tab
        else
            tab.container.Parent.Visible = false
            tab.tabBtn.BackgroundColor3 = Library.theme.background
        end
    end
end

function Window:CreateGroupBox(parent, name, size, position)
    local groupBox = {
        name = name,
        elements = {},
        container = nil,
        visible = true,
    }
    
    local groupFrame = CreateInstance("Frame", {
        Parent = parent,
        Name = name,
        Size = size,
        Position = position,
        BackgroundColor3 = Library.theme.lightBackground,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local titleLabel = CreateInstance("TextLabel", {
        Parent = groupFrame,
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundColor3 = Library.theme.background,
        TextColor3 = Library.theme.accent,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local scrolling = CreateInstance("ScrollingFrame", {
        Parent = groupFrame,
        Name = "Content",
        Size = UDim2.new(1, 0, 1, -20),
        Position = UDim2.new(0, 0, 0, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(1, 0, 0, 10),
    })
    
    local listLayout = CreateInstance("UIListLayout", {
        Parent = scrolling,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 5),
    })
    
    groupBox.container = scrolling
    groupBox.frame = groupFrame
    groupBox.layout = listLayout
    
    return groupBox
end

-- Toggle/Checkbox
local Toggle = setmetatable({}, Element)
Toggle.__index = Toggle

function Toggle:new(parent, name, default)
    local self = Element.new(self, name, parent)
    self.enabled = default or false
    self.callback = nil
    
    self:Create(parent)
    return self
end

function Toggle:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local checkbox = CreateInstance("Frame", {
        Parent = container,
        Name = "Checkbox",
        Size = UDim2.new(0, 15, 0, 15),
        Position = UDim2.new(0, 5, 0.5, -7),
        BackgroundColor3 = self.enabled and Library.theme.accent or Library.theme.border,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local label = CreateInstance("TextLabel", {
        Parent = container,
        Name = "Label",
        Size = UDim2.new(1, -25, 1, 0),
        Position = UDim2.new(0, 25, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local clickArea = CreateInstance("TextButton", {
        Parent = container,
        Name = "ClickArea",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })
    
    self.container = container
    self.checkbox = checkbox
    
    clickArea.MouseButton1Click:Connect(function()
        self.enabled = not self.enabled
        checkbox.BackgroundColor3 = self.enabled and Library.theme.accent or Library.theme.border
        if self.callback then
            self.callback(self.enabled)
        end
        self:UpdateDependencies()
    end)
end

function Toggle:OnChanged(callback)
    self.callback = callback
end

-- Button
local Button = setmetatable({}, Element)
Button.__index = Button

function Button:new(parent, name)
    local self = Element.new(self, name, parent)
    self.callback = nil
    
    self:Create(parent)
    return self
end

function Button:Create(parent)
    local button = CreateInstance("TextButton", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, -10, 0, 30),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundColor3 = Library.theme.accent,
        TextColor3 = Library.theme.text,
        Text = self.name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    self.container = button
    
    button.MouseButton1Click:Connect(function()
        if self.callback then
            self.callback()
        end
    end)
    
    button.MouseEnter:Connect(function()
        Tween(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(
            math.min(Library.theme.accent.R + 0.1, 1),
            math.min(Library.theme.accent.G + 0.1, 1),
            math.min(Library.theme.accent.B + 0.1, 1)
        )})
    end)
    
    button.MouseLeave:Connect(function()
        Tween(button, TweenInfo.new(0.2), {BackgroundColor3 = Library.theme.accent})
    end)
end

function Button:OnClick(callback)
    self.callback = callback
end

-- Slider
local Slider = setmetatable({}, Element)
Slider.__index = Slider

function Slider:new(parent, name, min, max, default, rounding)
    local self = Element.new(self, name, parent)
    self.min = min
    self.max = max
    self.value = default or min
    self.rounding = rounding or 0
    self.callback = nil
    
    self:Create(parent)
    return self
end

function Slider:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local label = CreateInstance("TextLabel", {
        Parent = container,
        Name = "Label",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.name .. ": " .. (self.rounding > 0 and string.format("%." .. self.rounding .. "f", self.value) or self.value),
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local sliderBackground = CreateInstance("Frame", {
        Parent = container,
        Name = "Background",
        Size = UDim2.new(1, -10, 0, 5),
        Position = UDim2.new(0, 5, 0, 25),
        BackgroundColor3 = Library.theme.border,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local sliderFill = CreateInstance("Frame", {
        Parent = sliderBackground,
        Name = "Fill",
        Size = UDim2.new((self.value - self.min) / (self.max - self.min), 0, 1, 0),
        BackgroundColor3 = Library.theme.accent,
        BorderSizePixel = 0,
    })
    
    local sliderButton = CreateInstance("Frame", {
        Parent = sliderBackground,
        Name = "Thumb",
        Size = UDim2.new(0, 10, 0, 15),
        Position = UDim2.new((self.value - self.min) / (self.max - self.min), -5, 0.5, -7),
        BackgroundColor3 = Library.theme.accent,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    self.container = container
    self.sliderBg = sliderBackground
    self.sliderFill = sliderFill
    self.sliderBtn = sliderButton
    self.label = label
    
    local dragging = false
    
    sliderButton.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if dragging and input.UserInputType == Enum.UserInputType.Mouse then
            local sliderSize = sliderBackground.AbsoluteSize.X
            local sliderPos = sliderBackground.AbsolutePosition.X
            local mouseX = input.Position.X
            
            local percentage = math.max(0, math.min(1, (mouseX - sliderPos) / sliderSize))
            self.value = self.min + (self.max - self.min) * percentage
            
            if self.rounding > 0 then
                self.value = math.round(self.value * (10 ^ self.rounding)) / (10 ^ self.rounding)
            else
                self.value = math.floor(self.value + 0.5)
            end
            
            sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
            sliderButton.Position = UDim2.new(percentage, -5, 0.5, -7)
            label.Text = self.name .. ": " .. (self.rounding > 0 and string.format("%." .. self.rounding .. "f", self.value) or self.value)
            
            if self.callback then
                self.callback(self.value)
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function Slider:OnChanged(callback)
    self.callback = callback
end

-- Dropdown
local Dropdown = setmetatable({}, Element)
Dropdown.__index = Dropdown

function Dropdown:new(parent, name, options, multiSelect)
    local self = Element.new(self, name, parent)
    self.options = options or {}
    self.selected = {}
    self.multiSelect = multiSelect or false
    self.open = false
    self.callback = nil
    
    if not self.multiSelect and #options > 0 then
        self.selected = {options[1]}
    end
    
    self:Create(parent)
    return self
end

function Dropdown:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local label = CreateInstance("TextLabel", {
        Parent = container,
        Name = "Label",
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local dropdownBtn = CreateInstance("TextButton", {
        Parent = container,
        Name = "DropdownBtn",
        Size = UDim2.new(1, -85, 1, 0),
        Position = UDim2.new(0, 85, 0, 0),
        BackgroundColor3 = Library.theme.lightBackground,
        TextColor3 = Library.theme.text,
        Text = #self.selected > 0 and table.concat(self.selected, ", ") or "Select...",
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local optionsFrame = CreateInstance("Frame", {
        Parent = container,
        Name = "Options",
        Size = UDim2.new(1, -85, 0, 0),
        Position = UDim2.new(0, 85, 1, 0),
        BackgroundColor3 = Library.theme.lightBackground,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        ClipsDescendants = true,
        Visible = false,
    })
    
    local optionsLayout = CreateInstance("UIListLayout", {
        Parent = optionsFrame,
        FillDirection = Enum.FillDirection.Vertical,
    })
    
    self.container = container
    self.dropdownBtn = dropdownBtn
    self.optionsFrame = optionsFrame
    self.optionsLayout = optionsLayout
    
    local function updateOptions()
        for _, child in ipairs(optionsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for _, option in ipairs(self.options) do
            local optBtn = CreateInstance("TextButton", {
                Parent = optionsFrame,
                Size = UDim2.new(1, 0, 0, 25),
                BackgroundColor3 = self:IsSelected(option) and Library.theme.accent or Library.theme.lightBackground,
                TextColor3 = Library.theme.text,
                Text = option,
                TextSize = 12,
                Font = Enum.Font.GothamPro,
                BorderSizePixel = 0,
            })
            
            optBtn.MouseButton1Click:Connect(function()
                if self.multiSelect then
                    local idx = table.find(self.selected, option)
                    if idx then
                        table.remove(self.selected, idx)
                    else
                        table.insert(self.selected, option)
                    end
                else
                    self.selected = {option}
                end
                
                dropdownBtn.Text = #self.selected > 0 and table.concat(self.selected, ", ") or "Select..."
                updateOptions()
                
                if self.callback then
                    self.callback(self.selected)
                end
            end)
            
            optBtn.MouseEnter:Connect(function()
                if not self:IsSelected(option) then
                    optBtn.BackgroundColor3 = Library.theme.background
                end
            end)
            
            optBtn.MouseLeave:Connect(function()
                if not self:IsSelected(option) then
                    optBtn.BackgroundColor3 = Library.theme.lightBackground
                end
            end)
        end
    end
    
    updateOptions()
    
    dropdownBtn.MouseButton1Click:Connect(function()
        self.open = not self.open
        optionsFrame.Visible = self.open
        optionsFrame.Size = self.open and UDim2.new(1, -85, 0, math.min(#self.options * 25, 200)) or UDim2.new(1, -85, 0, 0)
    end)
end

function Dropdown:IsSelected(option)
    return table.find(self.selected, option) ~= nil
end

function Dropdown:OnChanged(callback)
    self.callback = callback
end

-- TextInput
local TextInput = setmetatable({}, Element)
TextInput.__index = TextInput

function TextInput:new(parent, name, placeholder)
    local self = Element.new(self, name, parent)
    self.value = ""
    self.placeholder = placeholder or ""
    self.callback = nil
    
    self:Create(parent)
    return self
end

function TextInput:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local label = CreateInstance("TextLabel", {
        Parent = container,
        Name = "Label",
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local textbox = CreateInstance("TextBox", {
        Parent = container,
        Name = "Input",
        Size = UDim2.new(1, -85, 1, 0),
        Position = UDim2.new(0, 85, 0, 0),
        BackgroundColor3 = Library.theme.lightBackground,
        TextColor3 = Library.theme.text,
        PlaceholderColor3 = Color3.new(1, 1, 1),
        PlaceholderText = self.placeholder,
        Text = "",
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        ClearTextOnFocus = false,
    })
    
    self.container = container
    self.textbox = textbox
    
    textbox.FocusLost:Connect(function(enterPressed)
        self.value = textbox.Text
        if self.callback then
            self.callback(self.value)
        end
    end)
end

function Dropdown:OnChanged(callback)
    self.callback = callback
end

-- Label
local Label = setmetatable({}, Element)
Label.__index = Label

function Label:new(parent, text, updatable)
    local self = Element.new(self, text, parent)
    self.text = text
    self.updatable = updatable or false
    
    self:Create(parent)
    return self
end

function Label:Create(parent)
    local label = CreateInstance("TextLabel", {
        Parent = parent,
        Name = self.text,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.text,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    self.container = label
end

function Label:SetText(text)
    if self.updatable then
        self.text = text
        self.container.Text = text
    end
end

-- ColorPicker (HSV-based)
local ColorPicker = setmetatable({}, Element)
ColorPicker.__index = ColorPicker

function ColorPicker:new(parent, name, default)
    local self = Element.new(self, name, parent)
    self.color = default or Color3.fromRGB(255, 255, 255)
    self.h, self.s, self.v = RGBtoHSV(self.color)
    self.callback = nil
    
    self:Create(parent)
    return self
end

function ColorPicker:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 100),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local label = CreateInstance("TextLabel", {
        Parent = container,
        Name = "Label",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local hueSlider = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(1, -10, 0, 5),
        Position = UDim2.new(0, 5, 0, 25),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local hueFill = CreateInstance("Frame", {
        Parent = hueSlider,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = HSVtoRGB(self.h, 1, 1),
        BorderSizePixel = 0,
    })
    
    local hueThumb = CreateInstance("Frame", {
        Parent = hueSlider,
        Size = UDim2.new(0, 5, 0, 15),
        Position = UDim2.new(self.h / 360, 0, 0.5, -7),
        BackgroundColor3 = Library.theme.accent,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    -- SV Square
    local svSquare = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(1, -10, 0, 50),
        Position = UDim2.new(0, 5, 0, 35),
        BackgroundColor3 = HSVtoRGB(self.h, 1, 1),
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local svGrad1 = CreateInstance("UIGradient", {
        Parent = svSquare,
        Rotation = 90,
    })
    svGrad1.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0))
    
    local svThumb = CreateInstance("Frame", {
        Parent = svSquare,
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(self.s, -4, 1 - self.v, -4),
        BackgroundColor3 = Library.theme.accent,
        BorderColor3 = Library.theme.text,
        BorderMode = Enum.BorderMode.Outline,
        BorderSizePixel = 2,
    })
    
    local colorDisplay = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(1, -10, 0, 15),
        Position = UDim2.new(0, 5, 0, 85),
        BackgroundColor3 = self.color,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    self.container = container
    
    local function updateColor()
        self.color = HSVtoRGB(self.h, self.s, self.v)
        hueFill.BackgroundColor3 = HSVtoRGB(self.h, 1, 1)
        svSquare.BackgroundColor3 = HSVtoRGB(self.h, 1, 1)
        colorDisplay.BackgroundColor3 = self.color
        
        if self.callback then
            self.callback(self.color)
        end
    end
    
    local hueDragging = false
    hueThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hueDragging = true
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if hueDragging and input.UserInputType == Enum.UserInputType.Mouse then
            local sliderSize = hueSlider.AbsoluteSize.X
            local sliderPos = hueSlider.AbsolutePosition.X
            self.h = math.max(0, math.min(360, (input.Position.X - sliderPos) / sliderSize * 360))
            hueThumb.Position = UDim2.new(self.h / 360, 0, 0.5, -7)
            updateColor()
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hueDragging = false
        end
    end)
    
    local svDragging = false
    svThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            svDragging = true
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if svDragging and input.UserInputType == Enum.UserInputType.Mouse then
            local squareSize = svSquare.AbsoluteSize
            local squarePos = svSquare.AbsolutePosition
            self.s = math.max(0, math.min(1, (input.Position.X - squarePos.X) / squareSize.X))
            self.v = math.max(0, math.min(1, 1 - (input.Position.Y - squarePos.Y) / squareSize.Y))
            svThumb.Position = UDim2.new(self.s, -4, 1 - self.v, -4)
            updateColor()
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            svDragging = false
        end
    end)
end

function ColorPicker:OnChanged(callback)
    self.callback = callback
end

-- KeyPicker
local KeyPicker = setmetatable({}, Element)
KeyPicker.__index = KeyPicker

function KeyPicker:new(parent, name, default)
    local self = Element.new(self, name, parent)
    self.key = default or Enum.KeyCode.Space
    self.callback = nil
    self.listening = false
    
    self:Create(parent)
    return self
end

function KeyPicker:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    
    local label = CreateInstance("TextLabel", {
        Parent = container,
        Name = "Label",
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = self.name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local keyBtn = CreateInstance("TextButton", {
        Parent = container,
        Name = "KeyBtn",
        Size = UDim2.new(1, -85, 1, 0),
        Position = UDim2.new(0, 85, 0, 0),
        BackgroundColor3 = Library.theme.lightBackground,
        TextColor3 = Library.theme.text,
        Text = tostring(self.key):match("KeyCode%.(.+)") or "Select Key",
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    self.container = container
    self.keyBtn = keyBtn
    
    keyBtn.MouseButton1Click:Connect(function()
        self.listening = true
        keyBtn.Text = "Listening..."
        keyBtn.BackgroundColor3 = Library.theme.accent
    end)
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if self.listening and input.UserInputType == Enum.UserInputType.Keyboard then
            self.key = input.KeyCode
            keyBtn.Text = tostring(self.key):match("KeyCode%.(.+)") or "Select Key"
            keyBtn.BackgroundColor3 = Library.theme.lightBackground
            self.listening = false
            
            if self.callback then
                self.callback(self.key)
            end
        end
    end)
end

function KeyPicker:OnChanged(callback)
    self.callback = callback
end

-- Notifications
function Library:Notify(message, title, duration)
    title = title or "Notification"
    duration = duration or 3
    
    local notification = CreateInstance("Frame", {
        Parent = CoreGui,
        Name = "Notification",
        Size = UDim2.new(0, 300, 0, 80),
        Position = UDim2.new(1, -320, 1, -100 - (#self.notifications * 100)),
        BackgroundColor3 = self.theme.darkBackground,
        BorderColor3 = self.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    CreateInstance("TextLabel", {
        Parent = notification,
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundColor3 = self.theme.background,
        TextColor3 = self.theme.accent,
        Text = title,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = self.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    CreateInstance("TextLabel", {
        Parent = notification,
        Name = "Message",
        Size = UDim2.new(1, 0, 1, -25),
        Position = UDim2.new(0, 0, 0, 25),
        BackgroundTransparency = 1,
        TextColor3 = self.theme.text,
        Text = message,
        TextSize = 11,
        Font = Enum.Font.GothamPro,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    
    table.insert(self.notifications, notification)
    
    task.wait(duration)
    
    Tween(notification, TweenInfo.new(0.3), {Position = notification.Position + UDim2.new(0, 320, 0, 0)})
    task.wait(0.3)
    
    local idx = table.find(self.notifications, notification)
    if idx then
        table.remove(self.notifications, idx)
    end
    notification:Destroy()
end

-- Watermark
function Library:CreateWatermark(text)
    local watermark = CreateInstance("TextLabel", {
        Parent = CoreGui,
        Name = "Watermark",
        Size = UDim2.new(0, 200, 0, 30),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = self.theme.background,
        TextColor3 = self.theme.accent,
        Text = text or "Matcha Executor",
        TextSize = 14,
        Font = Enum.Font.GothamPro,
        BorderColor3 = self.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    return watermark
end

-- TabBox (Tabs within a GroupBox)
local TabBox = setmetatable({}, Element)
TabBox.__index = TabBox

function TabBox:new(parent, name)
    local self = Element.new(self, name, parent)
    self.tabs = {}
    self.currentTab = nil
    
    self:Create(parent)
    return self
end

function TabBox:Create(parent)
    local container = CreateInstance("Frame", {
        Parent = parent,
        Name = self.name,
        Size = UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = Library.theme.lightBackground,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        ClipsDescendants = true,
    })
    
    local tabBar = CreateInstance("Frame", {
        Parent = container,
        Name = "TabBar",
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundColor3 = Library.theme.background,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local tabLayout = CreateInstance("UIListLayout", {
        Parent = tabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 0),
    })
    
    local contentArea = CreateInstance("Frame", {
        Parent = container,
        Name = "Content",
        Size = UDim2.new(1, 0, 1, -25),
        Position = UDim2.new(0, 0, 0, 25),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    
    self.container = container
    self.tabBar = tabBar
    self.contentArea = contentArea
end

function TabBox:CreateTab(name)
    local tab = {
        name = name,
        container = nil,
    }
    
    local tabBtn = CreateInstance("TextButton", {
        Parent = self.tabBar,
        Name = name .. "Tab",
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundColor3 = Library.theme.background,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 11,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })
    
    local tabContent = CreateInstance("Frame", {
        Parent = self.contentArea,
        Name = name .. "Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
    })
    
    local listLayout = CreateInstance("UIListLayout", {
        Parent = tabContent,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 5),
    })
    
    tab.container = tabContent
    tab.tabBtn = tabBtn
    
    tabBtn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)
    
    table.insert(self.tabs, tab)
    
    if not self.currentTab then
        self:SelectTab(name)
    end
    
    return tab
end

function TabBox:SelectTab(tabName)
    for _, tab in ipairs(self.tabs) do
        if tab.name == tabName then
            tab.container.Visible = true
            tab.tabBtn.BackgroundColor3 = Library.theme.accent
            self.currentTab = tab
        else
            tab.container.Visible = false
            tab.tabBtn.BackgroundColor3 = Library.theme.background
        end
    end
end

-- Theme System
function Library:SetTheme(accent, background, text)
    self.theme.accent = accent or self.theme.accent
    self.theme.background = background or self.theme.background
    self.theme.text = text or self.theme.text
end

-- Return Library with all classes
Library.Window = Window
Library.Toggle = Toggle
Library.Button = Button
Library.Slider = Slider
Library.Dropdown = Dropdown
Library.TextInput = TextInput
Library.Label = Label
Library.ColorPicker = ColorPicker
Library.KeyPicker = KeyPicker
Library.TabBox = TabBox
Library.Element = Element

-- Ensure proper export for loadstring
local function Init()
    return Library
end

return Init()
