--[[
    Matcha Executor UI Library v2
    Refactored with tree-based architecture and fluent API
    Based on drawing library patterns
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local Library = {
    _tree = {},
    _windows = {},
    _notifications = {},
    _dragging = nil,
    _focus = nil,
    theme = {
        accent = Color3.fromRGB(0, 120, 215),
        background = Color3.fromRGB(20, 20, 20),
        text = Color3.fromRGB(255, 255, 255),
        surface0 = Color3.fromRGB(24, 24, 24),
        surface1 = Color3.fromRGB(42, 42, 42),
        border = Color3.fromRGB(40, 40, 40),
    },
    title = "Matcha UI",
    menuKey = Enum.KeyCode.RightShift,
    menuOpen = true,
}

-- Utility Functions
local function CreateInstance(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        pcall(function() instance[prop] = value end)
    end
    return instance
end

local function Tween(instance, tweenInfo, properties)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Create a window with fluent API
function Library:Window(title, size)
    size = size or UDim2.new(0, 600, 0, 500)
    
    local windowData = {
        _title = title,
        _size = size,
        _position = UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2),
        _tabs = {},
        _currentTab = nil,
        _container = nil,
        _visible = true,
        _dragging = false,
    }

    -- Create GUI
    local screenGui = CreateInstance("ScreenGui", {
        Parent = CoreGui,
        ResetOnSpawn = false,
        Name = title .. "Gui",
    })

    local mainFrame = CreateInstance("Frame", {
        Parent = screenGui,
        Size = size,
        Position = windowData._position,
        BackgroundColor3 = Library.theme.background,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        ClipsDescendants = true,
    })

    local titleBar = CreateInstance("Frame", {
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Library.theme.surface0,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    CreateInstance("TextLabel", {
        Parent = titleBar,
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        TextSize = 14,
        Font = Enum.Font.GothamPro,
        Text = title,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local closeBtn = CreateInstance("TextButton", {
        Parent = titleBar,
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundColor3 = Library.theme.accent,
        TextColor3 = Library.theme.text,
        Text = "×",
        TextSize = 20,
        Font = Enum.Font.GothamPro,
    })

    closeBtn.MouseButton1Click:Connect(function()
        windowData._visible = not windowData._visible
        mainFrame.Visible = windowData._visible
    end)

    local tabBar = CreateInstance("Frame", {
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Library.theme.surface0,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    CreateInstance("UIListLayout", {
        Parent = tabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 0),
    })

    local contentArea = CreateInstance("Frame", {
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 1, -60),
        Position = UDim2.new(0, 0, 0, 60),
        BackgroundColor3 = Library.theme.surface0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })

    -- Dragging
    local dragStart, dragOffset
    titleBar.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            windowData._dragging = true
            dragStart = input.Position
            dragOffset = mainFrame.AbsolutePosition
        end
    end)

    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if windowData._dragging and input.UserInputType == Enum.UserInputType.Mouse then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                0, dragOffset.X + delta.X,
                0, dragOffset.Y + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            windowData._dragging = false
        end
    end)

    windowData._container = mainFrame
    windowData._tabBar = tabBar
    windowData._contentArea = contentArea

    -- Return window object with methods
    return {
        Tab = function(_, tabName)
            return Library:_CreateTab(windowData, tabName)
        end,
        SetVisible = function(_, visible)
            windowData._visible = visible
            mainFrame.Visible = visible
        end,
        Show = function(_)
            windowData._visible = true
            mainFrame.Visible = true
        end,
        Hide = function(_)
            windowData._visible = false
            mainFrame.Visible = false
        end,
    }
end

-- Tab creation
function Library:_CreateTab(windowData, tabName)
    local tabData = {
        _name = tabName,
        _groups = {},
        _container = nil,
    }

    local tabBtn = CreateInstance("TextButton", {
        Parent = windowData._tabBar,
        Size = UDim2.new(0, 100, 1, 0),
        BackgroundColor3 = Library.theme.surface0,
        TextColor3 = Library.theme.text,
        Text = tabName,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    local tabContent = CreateInstance("Frame", {
        Parent = windowData._contentArea,
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

    CreateInstance("UIListLayout", {
        Parent = scrolling,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 5),
    })

    tabData._container = scrolling
    tabData._tabBtn = tabBtn
    tabData._tabContent = tabContent

    tabBtn.MouseButton1Click:Connect(function()
        Library:_SelectTab(windowData, tabName)
    end)

    if not windowData._currentTab then
        Library:_SelectTab(windowData, tabName)
    end

    windowData._tabs[tabName] = tabData

    return {
        Group = function(_, groupName)
            return Library:_CreateGroup(tabData, groupName)
        end,
    }
end

function Library:_SelectTab(windowData, tabName)
    for name, tab in pairs(windowData._tabs) do
        if name == tabName then
            tab._tabContent.Visible = true
            tab._tabBtn.BackgroundColor3 = Library.theme.accent
            windowData._currentTab = tab
        else
            tab._tabContent.Visible = false
            tab._tabBtn.BackgroundColor3 = Library.theme.surface0
        end
    end
end

-- Group/Section creation
function Library:_CreateGroup(tabData, groupName)
    local groupData = {
        _name = groupName,
        _items = {},
        _container = nil,
    }

    local groupFrame = CreateInstance("Frame", {
        Parent = tabData._container,
        Size = UDim2.new(1, -10, 0, 200),
        BackgroundColor3 = Library.theme.surface1,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    CreateInstance("TextLabel", {
        Parent = groupFrame,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundColor3 = Library.theme.background,
        TextColor3 = Library.theme.accent,
        Text = groupName,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    local scrolling = CreateInstance("ScrollingFrame", {
        Parent = groupFrame,
        Size = UDim2.new(1, 0, 1, -20),
        Position = UDim2.new(0, 0, 0, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(1, 0, 0, 10),
    })

    CreateInstance("UIListLayout", {
        Parent = scrolling,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 5),
    })

    groupData._container = scrolling

    return {
        Toggle = function(_, name, default, callback)
            return Library:_CreateToggle(groupData, name, default, callback)
        end,
        Slider = function(_, name, min, max, default, rounding, callback)
            return Library:_CreateSlider(groupData, name, min, max, default, rounding, callback)
        end,
        Button = function(_, name, callback)
            return Library:_CreateButton(groupData, name, callback)
        end,
        Dropdown = function(_, name, options, multiSelect, callback)
            return Library:_CreateDropdown(groupData, name, options, multiSelect, callback)
        end,
        TextInput = function(_, name, placeholder, callback)
            return Library:_CreateTextInput(groupData, name, placeholder, callback)
        end,
        ColorPicker = function(_, name, default, callback)
            return Library:_CreateColorPicker(groupData, name, default, callback)
        end,
    }
end

-- Toggle Element
function Library:_CreateToggle(groupData, name, default, callback)
    local itemData = {
        _type = "toggle",
        _name = name,
        _value = default or false,
        _callback = callback,
        _container = nil,
    }

    local container = CreateInstance("Frame", {
        Parent = groupData._container,
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local checkbox = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(0, 15, 0, 15),
        Position = UDim2.new(0, 5, 0.5, -7),
        BackgroundColor3 = itemData._value and Library.theme.accent or Library.theme.border,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    CreateInstance("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, -25, 1, 0),
        Position = UDim2.new(0, 25, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local clickArea = CreateInstance("TextButton", {
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })

    itemData._container = container
    itemData._checkbox = checkbox

    clickArea.MouseButton1Click:Connect(function()
        itemData._value = not itemData._value
        checkbox.BackgroundColor3 = itemData._value and Library.theme.accent or Library.theme.border
        if itemData._callback then
            itemData._callback(itemData._value)
        end
    end)

    table.insert(groupData._items, itemData)

    return {
        Set = function(_, newValue)
            itemData._value = newValue
            checkbox.BackgroundColor3 = itemData._value and Library.theme.accent or Library.theme.border
            if itemData._callback then
                itemData._callback(newValue)
            end
        end,
        Get = function(_)
            return itemData._value
        end,
    }
end

-- Slider Element
function Library:_CreateSlider(groupData, name, min, max, default, rounding, callback)
    local itemData = {
        _type = "slider",
        _name = name,
        _value = default or min,
        _min = min,
        _max = max,
        _rounding = rounding or 0,
        _callback = callback,
    }

    local container = CreateInstance("Frame", {
        Parent = groupData._container,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local label = CreateInstance("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = name .. ": " .. itemData._value,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sliderBg = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(1, -10, 0, 5),
        Position = UDim2.new(0, 5, 0, 25),
        BackgroundColor3 = Library.theme.border,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    local sliderFill = CreateInstance("Frame", {
        Parent = sliderBg,
        Size = UDim2.new((itemData._value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Library.theme.accent,
        BorderSizePixel = 0,
    })

    local sliderThumb = CreateInstance("Frame", {
        Parent = sliderBg,
        Size = UDim2.new(0, 10, 0, 15),
        Position = UDim2.new((itemData._value - min) / (max - min), -5, 0.5, -7),
        BackgroundColor3 = Library.theme.accent,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    local dragging = false

    sliderThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)

    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if dragging and input.UserInputType == Enum.UserInputType.Mouse then
            local percentage = math.max(0, math.min(1, (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X))
            itemData._value = min + (max - min) * percentage

            if rounding and rounding > 0 then
                itemData._value = math.round(itemData._value * (10 ^ rounding)) / (10 ^ rounding)
            else
                itemData._value = math.floor(itemData._value + 0.5)
            end

            itemData._value = math.max(min, math.min(max, itemData._value))

            sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
            sliderThumb.Position = UDim2.new(percentage, -5, 0.5, -7)
            label.Text = name .. ": " .. (rounding and rounding > 0 and string.format("%." .. rounding .. "f", itemData._value) or itemData._value)

            if itemData._callback then
                itemData._callback(itemData._value)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    table.insert(groupData._items, itemData)

    return {
        Set = function(_, newValue)
            itemData._value = math.max(min, math.min(max, newValue))
            local percentage = (itemData._value - min) / (max - min)
            sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
            sliderThumb.Position = UDim2.new(percentage, -5, 0.5, -7)
            label.Text = name .. ": " .. (rounding and rounding > 0 and string.format("%." .. rounding .. "f", itemData._value) or itemData._value)
            if itemData._callback then
                itemData._callback(itemData._value)
            end
        end,
        Get = function(_)
            return itemData._value
        end,
    }
end

-- Button Element
function Library:_CreateButton(groupData, name, callback)
    local itemData = {
        _type = "button",
        _name = name,
        _callback = callback,
    }

    local button = CreateInstance("TextButton", {
        Parent = groupData._container,
        Size = UDim2.new(1, -10, 0, 30),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundColor3 = Library.theme.accent,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    button.MouseButton1Click:Connect(function()
        if itemData._callback then
            itemData._callback()
        end
    end)

    table.insert(groupData._items, itemData)

    return {
        Click = function(_)
            if itemData._callback then
                itemData._callback()
            end
        end,
    }
end

-- Dropdown Element
function Library:_CreateDropdown(groupData, name, options, multiSelect, callback)
    local itemData = {
        _type = "dropdown",
        _name = name,
        _options = options or {},
        _selected = multiSelect and {} or {options[1]},
        _multiSelect = multiSelect,
        _callback = callback,
        _open = false,
    }

    local container = CreateInstance("Frame", {
        Parent = groupData._container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local label = CreateInstance("TextLabel", {
        Parent = container,
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local dropdownBtn = CreateInstance("TextButton", {
        Parent = container,
        Size = UDim2.new(1, -85, 1, 0),
        Position = UDim2.new(0, 85, 0, 0),
        BackgroundColor3 = Library.theme.surface0,
        TextColor3 = Library.theme.text,
        Text = #itemData._selected > 0 and table.concat(itemData._selected, ", ") or "Select...",
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local optionsFrame = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(1, -85, 0, 0),
        Position = UDim2.new(0, 85, 1, 0),
        BackgroundColor3 = Library.theme.surface0,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 10,
    })

    CreateInstance("UIListLayout", {
        Parent = optionsFrame,
        FillDirection = Enum.FillDirection.Vertical,
    })

    local function updateOptions()
        for _, child in ipairs(optionsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for _, option in ipairs(options) do
            local optBtn = CreateInstance("TextButton", {
                Parent = optionsFrame,
                Size = UDim2.new(1, 0, 0, 25),
                BackgroundColor3 = table.find(itemData._selected, option) and Library.theme.accent or Library.theme.surface0,
                TextColor3 = Library.theme.text,
                Text = option,
                TextSize = 12,
                Font = Enum.Font.GothamPro,
                BorderSizePixel = 0,
            })

            optBtn.MouseButton1Click:Connect(function()
                if multiSelect then
                    local idx = table.find(itemData._selected, option)
                    if idx then
                        table.remove(itemData._selected, idx)
                    else
                        table.insert(itemData._selected, option)
                    end
                else
                    itemData._selected = {option}
                end

                dropdownBtn.Text = #itemData._selected > 0 and table.concat(itemData._selected, ", ") or "Select..."
                updateOptions()

                if itemData._callback then
                    itemData._callback(itemData._selected)
                end
            end)
        end
    end

    updateOptions()

    dropdownBtn.MouseButton1Click:Connect(function()
        itemData._open = not itemData._open
        optionsFrame.Visible = itemData._open
        optionsFrame.Size = itemData._open and UDim2.new(1, -85, 0, math.min(#options * 25, 200)) or UDim2.new(1, -85, 0, 0)
    end)

    table.insert(groupData._items, itemData)

    return {
        Set = function(_, newValue)
            itemData._selected = newValue
            dropdownBtn.Text = #itemData._selected > 0 and table.concat(itemData._selected, ", ") or "Select..."
            updateOptions()
            if itemData._callback then
                itemData._callback(itemData._selected)
            end
        end,
        Get = function(_)
            return itemData._selected
        end,
    }
end

-- TextInput Element
function Library:_CreateTextInput(groupData, name, placeholder, callback)
    local itemData = {
        _type = "textinput",
        _name = name,
        _value = "",
        _placeholder = placeholder,
        _callback = callback,
    }

    local container = CreateInstance("Frame", {
        Parent = groupData._container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local label = CreateInstance("TextLabel", {
        Parent = container,
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local textbox = CreateInstance("TextBox", {
        Parent = container,
        Size = UDim2.new(1, -85, 1, 0),
        Position = UDim2.new(0, 85, 0, 0),
        BackgroundColor3 = Library.theme.surface0,
        TextColor3 = Library.theme.text,
        PlaceholderColor3 = Color3.new(0.5, 0.5, 0.5),
        PlaceholderText = placeholder or "Enter text...",
        Text = "",
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    textbox.FocusLost:Connect(function()
        itemData._value = textbox.Text
        if itemData._callback then
            itemData._callback(itemData._value)
        end
    end)

    table.insert(groupData._items, itemData)

    return {
        Set = function(_, newValue)
            itemData._value = newValue
            textbox.Text = newValue
            if itemData._callback then
                itemData._callback(newValue)
            end
        end,
        Get = function(_)
            return itemData._value
        end,
    }
end

-- ColorPicker Element
function Library:_CreateColorPicker(groupData, name, default, callback)
    local itemData = {
        _type = "colorpicker",
        _name = name,
        _value = default or Color3.fromRGB(255, 255, 255),
        _callback = callback,
    }

    local container = CreateInstance("Frame", {
        Parent = groupData._container,
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local label = CreateInstance("TextLabel", {
        Parent = container,
        Size = UDim2.new(0, 80, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Library.theme.text,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.GothamPro,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local colorDisplay = CreateInstance("Frame", {
        Parent = container,
        Size = UDim2.new(1, -85, 0, 25),
        Position = UDim2.new(0, 85, 0, 0),
        BackgroundColor3 = itemData._value,
        BorderColor3 = Library.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    local clickBox = CreateInstance("TextButton", {
        Parent = colorDisplay,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 10,
    })

    clickBox.MouseButton1Click:Connect(function()
        Library:Notify("Color picker spawned (gradient UI needed)", "Matcha", 2)
    end)

    table.insert(groupData._items, itemData)

    return {
        Set = function(_, newValue)
            itemData._value = newValue
            colorDisplay.BackgroundColor3 = newValue
            if itemData._callback then
                itemData._callback(newValue)
            end
        end,
        Get = function(_)
            return itemData._value
        end,
    }
end

-- Notification System
function Library:Notify(message, title, duration)
    title = title or "Notification"
    duration = duration or 3

    local notification = CreateInstance("Frame", {
        Parent = CoreGui,
        Size = UDim2.new(0, 300, 0, 80),
        Position = UDim2.new(1, -320, 1, -100 - (#self._notifications * 100)),
        BackgroundColor3 = self.theme.surface0,
        BorderColor3 = self.theme.border,
        BorderMode = Enum.BorderMode.Outline,
    })

    CreateInstance("TextLabel", {
        Parent = notification,
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

    table.insert(self._notifications, notification)

    task.wait(duration)

    Tween(notification, TweenInfo.new(0.3), {Position = notification.Position + UDim2.new(0, 320, 0, 0)})
    task.wait(0.3)

    local idx = table.find(self._notifications, notification)
    if idx then
        table.remove(self._notifications, idx)
    end
    notification:Destroy()
end

-- Watermark
function Library:Watermark(text)
    local watermark = CreateInstance("TextLabel", {
        Parent = CoreGui,
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

return Library
