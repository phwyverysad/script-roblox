local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

local function ColorToHex(c)
    return string.format("#%02x%02x%02x", math.round(c.R*255), math.round(c.G*255), math.round(c.B*255))
end

local function HexToColor(hex)
    local success, result = pcall(function()
        hex = hex:gsub("#", "")
        return Color3.fromRGB(tonumber(hex:sub(1,2), 16), tonumber(hex:sub(3,4), 16), tonumber(hex:sub(5,6), 16))
    end)
    return success and result or nil
end

local function GetUIContainer()
    if game:GetService("RunService"):IsStudio() then
        return Player:WaitForChild("PlayerGui")
    end
    local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if success and coreGui:FindFirstChild("RobloxGui") then
        return coreGui.RobloxGui
    end
    return Player:WaitForChild("PlayerGui")
end

local SettingsUI = Instance.new("ScreenGui")
SettingsUI.Name = "7yd7-Settings"
SettingsUI.ResetOnSpawn = false
SettingsUI.IgnoreGuiInset = true
SettingsUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SettingsUI.DisplayOrder = 999
SettingsUI.Parent = GetUIContainer()

local UIScale = Instance.new("UIScale")
UIScale.Parent = SettingsUI

local function UpdateUIScale()
    local ViewportSize = workspace.CurrentCamera.ViewportSize
    local rawScale = math.min(ViewportSize.X / 1000, ViewportSize.Y / 800)
    if ViewportSize.Y < 500 then
        rawScale = rawScale * 1.2
    end
    UIScale.Scale = math.clamp(rawScale, 0.55, 1.25)
end

UpdateUIScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateUIScale)

local Theme = {
    Background = Color3.fromRGB(20, 21, 25),
    Surface = Color3.fromRGB(30, 32, 37),
    SurfaceElevated = Color3.fromRGB(38, 41, 47),
    Border = Color3.fromRGB(52, 55, 62),
    Accent = Color3.fromRGB(0, 230, 180),
    AccentDim = Color3.fromRGB(0, 180, 140),
    Text = Color3.fromRGB(240, 240, 245),
    TextDim = Color3.fromRGB(130, 135, 145),
    Error = Color3.fromRGB(255, 85, 95),
    Success = Color3.fromRGB(0, 230, 150),
    CornerMain = UDim.new(0, 20),
    CornerCard = UDim.new(0, 14),
    CornerPill = UDim.new(1, 0),
    CornerInput = UDim.new(0, 10),
    FontBold = Enum.Font.GothamBold,
    FontRegular = Enum.Font.Gotham
}

local Lib = {}
local ColorHistory = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255),
    Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 255), Color3.fromRGB(120, 120, 120)
}

function Lib:Tween(obj, info, goal)
    local tween = TweenService:Create(obj, info, goal)
    tween:Play()
    return tween
end

function Lib:Create(className, properties, children)
    local obj = Instance.new(className)
    for k, v in pairs(properties) do
        obj[k] = v
    end
    if children then
        for _, child in pairs(children) do
            child.Parent = obj
        end
    end
    return obj
end

local function Shadow(props)
    return Lib:Create("Frame", {
        Name = "Shadow",
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 4, 0, 4),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = -1
    }, {
        Lib:Create("UICorner", {CornerRadius = props.CornerRadius or Theme.CornerMain})
    })
end

local PickerFrame = nil
local currentPickerCallback = nil
local pickerColor = Color3.new(1, 1, 1)
local pickerAlpha = 1

function Lib:OpenPicker(default, callback, includeAlpha)
    if PickerFrame then PickerFrame:Destroy() end
    currentPickerCallback = callback
    if typeof(default) == "table" then
        pickerColor = default.Color or Color3.new(1,1,1)
        pickerAlpha = default.Alpha or 1
    else
        pickerColor = default or Theme.Accent
        pickerAlpha = 1
    end
    local h, s, v = pickerColor:ToHSV()
    local alpha = pickerAlpha

    PickerFrame = Lib:Create("Frame", {
        Name = "AdvancedColorPicker",
        Parent = SettingsUI,
        BackgroundColor3 = Theme.Surface,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 5000,
        ClipsDescendants = true
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerCard}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1.5}),
        Lib:Create("TextLabel", {
            Position = UDim2.fromOffset(20, 14),
            Size = UDim2.fromOffset(220, 22),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = "COLOR SELECTOR",
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })
    })

    Lib:Tween(PickerFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(320, includeAlpha and 490 or 470)})

    local closeBtn = Lib:Create("TextButton", {
        Parent = PickerFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -38, 0, 8),
        Size = UDim2.fromOffset(30, 30),
        Font = Theme.FontBold,
        Text = "×",
        TextColor3 = Theme.TextDim,
        TextSize = 24
    })

    local MainArea = Lib:Create("Frame", {
        Parent = PickerFrame,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 46),
        Size = UDim2.new(1, -40, 0, 160)
    })

    local Wheel = Lib:Create("ImageButton", {
        Name = "Wheel",
        Parent = MainArea,
        Size = UDim2.fromOffset(160, 160),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6020299385",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 10
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })

    local WheelCursor = Lib:Create("Frame", {
        Parent = Wheel,
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 11
    }, {
        Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Lib:Create("UIStroke", {Thickness = 2, Color = Color3.new(0,0,0)})
    })

    local ValueSlider = Lib:Create("ImageButton", {
        Name = "ValueSlider",
        Parent = MainArea,
        Position = UDim2.fromOffset(180, 0),
        Size = UDim2.fromOffset(28, 160),
        BackgroundColor3 = Color3.new(1,1,1),
        ZIndex = 10
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })

    local ValGradient = Lib:Create("UIGradient", {
        Parent = ValueSlider,
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0))
    })

    local ValCursor = Lib:Create("Frame", {
        Parent = ValueSlider,
        Size = UDim2.new(1.3, 0, 0, 6),
        AnchorPoint = Vector2.new(0.15, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 11
    }, {
        Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Lib:Create("UIStroke", {Thickness = 1, Color = Color3.new(0,0,0)})
    })

    local AlphaSlider = Lib:Create("ImageButton", {
        Name = "AlphaSlider",
        Parent = MainArea,
        Position = UDim2.fromOffset(220, 0),
        Size = UDim2.fromOffset(28, 160),
        BackgroundColor3 = Color3.new(1,1,1),
        Visible = includeAlpha == true,
        ZIndex = 10
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })

    local AlphaGradient = Lib:Create("UIGradient", {
        Parent = AlphaSlider,
        Rotation = 90,
        Transparency = NumberSequence.new(0, 1)
    })

    local AlphaCursor = Lib:Create("Frame", {
        Parent = AlphaSlider,
        Size = UDim2.new(1.3, 0, 0, 6),
        AnchorPoint = Vector2.new(0.15, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 11
    }, {
        Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Lib:Create("UIStroke", {Thickness = 1, Color = Color3.new(0,0,0)})
    })

    if not includeAlpha then
        ValueSlider.Position = UDim2.fromOffset(200, 0)
        ValueSlider.Size = UDim2.fromOffset(44, 160)
    end

    local ActionArea = Lib:Create("Frame", {
        Parent = PickerFrame,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 216),
        Size = UDim2.new(1, -40, 0, 44)
    })

    local Preview = Lib:Create("Frame", {
        Parent = ActionArea,
        Size = UDim2.fromOffset(40, 40),
        Position = UDim2.fromOffset(0, 2),
        BackgroundColor3 = pickerColor
    }, {
        Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Lib:Create("UIStroke", {Thickness = 2, Color = Theme.Border})
    })

    local Hex = Lib:Create("TextBox", {
        Parent = ActionArea,
        Position = UDim2.fromOffset(52, 4),
        Size = UDim2.fromOffset(110, 32),
        BackgroundColor3 = Theme.Background,
        Font = Theme.FontRegular,
        Text = ColorToHex(pickerColor),
        TextColor3 = Theme.Text,
        TextSize = 13
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerInput}) })

    local function CreateBtn(img, x, parent, color)
        local btn = Lib:Create("ImageButton", {
            Parent = parent,
            Position = UDim2.fromOffset(x, 4),
            Size = UDim2.fromOffset(32, 32),
            BackgroundColor3 = Theme.SurfaceElevated,
            Image = img,
            ImageColor3 = color or Theme.Text,
            ScaleType = Enum.ScaleType.Fit
        }, {
            Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
            Lib:Create("UIPadding", {
                PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
                PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)
            })
        })
        return btn
    end

    local Apply = CreateBtn("rbxassetid://17790428935", 175, ActionArea, Theme.Success)
    local Cancel = CreateBtn("rbxassetid://102910221413931", 215, ActionArea, Theme.Error)

    local Grid = Lib:Create("Frame", {
        Parent = PickerFrame,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 270),
        Size = UDim2.new(1, -40, 0, 90)
    })

    local function CreateInput(label, x, y, parent, default)
        local container = Lib:Create("Frame", {
            Parent = parent,
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(84, 36),
            BackgroundColor3 = Theme.Background
        }, {
            Lib:Create("UICorner", {CornerRadius = Theme.CornerInput}),
            Lib:Create("TextLabel", {
                Position = UDim2.new(0, 8, 0, -11),
                Size = UDim2.fromOffset(28, 14),
                BackgroundTransparency = 1,
                Font = Theme.FontBold,
                Text = label,
                TextColor3 = Theme.TextDim,
                TextSize = 10
            })
        })
        local box = Lib:Create("TextBox", {
            Parent = container,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Font = Theme.FontRegular,
            Text = tostring(default),
            TextColor3 = Theme.Text,
            TextSize = 13,
            ClearTextOnFocus = false
        })
        return box
    end

    local rI = CreateInput("R", 0, 4, Grid, math.round(pickerColor.R*255))
    local gI = CreateInput("G", 94, 4, Grid, math.round(pickerColor.G*255))
    local bI = CreateInput("B", 188, 4, Grid, math.round(pickerColor.B*255))
    local hI = CreateInput("H", 0, 50, Grid, math.round(h*360))
    local sI = CreateInput("S", 94, 50, Grid, string.format("%.2f", s))
    local vI = CreateInput("V", 188, 50, Grid, string.format("%.2f", v))

    local Palette = Lib:Create("Frame", {
        Parent = PickerFrame,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 370),
        Size = UDim2.new(1, -40, 0, 42)
    }, {
        Lib:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 8),
            HorizontalAlignment = Enum.HorizontalAlignment.Center
        })
    })

    local function SyncAll(source)
        pickerColor = Color3.fromHSV(h, s, v)
        Preview.BackgroundColor3 = pickerColor
        Preview.BackgroundTransparency = 1 - alpha
        ValGradient.Color = ColorSequence.new(Color3.fromHSV(h, s, 1), Color3.new(0, 0, 0))
        AlphaGradient.Color = ColorSequence.new(pickerColor, pickerColor)
        if source ~= "Wheel" then
            local angle = math.rad(180 - h * 360)
            local dist = s * 80
            WheelCursor.Position = UDim2.fromOffset(80 + math.cos(angle) * dist, 80 + math.sin(angle) * dist)
        end
        ValCursor.Position = UDim2.fromScale(0, 1-v)
        AlphaCursor.Position = UDim2.fromScale(0, 1-alpha)
        if source ~= "Hex" then Hex.Text = ColorToHex(pickerColor) end
        if source ~= "RGB" then
            rI.Text = math.round(pickerColor.R * 255)
            gI.Text = math.round(pickerColor.G * 255)
            bI.Text = math.round(pickerColor.B * 255)
        end
        if source ~= "HSV" then
            hI.Text = math.round(h * 360)
            sI.Text = string.format("%.2f", s)
            vI.Text = string.format("%.2f", v)
        end
    end

    for i, color in ipairs(ColorHistory) do
        local swatch = Lib:Create("TextButton", {
            Parent = Palette,
            Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = color,
            Text = ""
        }, { Lib:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
        swatch.MouseButton1Click:Connect(function()
            h, s, v = color:ToHSV()
            SyncAll("Palette")
        end)
    end

    local function UpdateWheel(input)
        local pos = input.Position
        local rel = Vector2.new(pos.X - Wheel.AbsolutePosition.X, pos.Y - Wheel.AbsolutePosition.Y)
        local radius = Wheel.AbsoluteSize.X / 2
        local center = Vector2.new(radius, radius)
        local diff = rel - center
        local angle = math.atan2(diff.Y, diff.X)
        local dist = math.min(diff.Magnitude, radius)
        h = (180 - math.deg(angle)) % 360 / 360
        s = dist / radius
        SyncAll("Wheel")
    end

    local function UpdateValue(input)
        local pos = input.Position
        local size = ValueSlider.AbsoluteSize
        local absPos = ValueSlider.AbsolutePosition
        local relY = math.clamp((pos.Y - absPos.Y) / size.Y, 0, 1)
        v = 1 - relY
        SyncAll("Slider")
    end

    local function UpdateAlpha(input)
        local pos = input.Position
        local size = AlphaSlider.AbsoluteSize
        local absPos = AlphaSlider.AbsolutePosition
        local relY = math.clamp((pos.Y - absPos.Y) / size.Y, 0, 1)
        alpha = 1 - relY
        SyncAll("Alpha")
    end

    local wheelDown, valDown, alphaDown = false, false, false

    Wheel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wheelDown = true; UpdateWheel(input)
        end
    end)
    ValueSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            valDown = true; UpdateValue(input)
        end
    end)
    AlphaSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            alphaDown = true; UpdateAlpha(input)
        end
    end)

    local connections = {}
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if wheelDown then UpdateWheel({Position = input.Position})
            elseif valDown then UpdateValue({Position = input.Position})
            elseif alphaDown then UpdateAlpha({Position = input.Position}) end
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wheelDown, valDown, alphaDown = false, false, false
        end
    end))

    local function Cleanup()
        for _, conn in ipairs(connections) do
            if conn.Connected then conn:Disconnect() end
        end
        if PickerFrame then PickerFrame:Destroy(); PickerFrame = nil end
    end

    closeBtn.MouseButton1Click:Connect(Cleanup)
    Cancel.MouseButton1Click:Connect(Cleanup)

    Hex.FocusLost:Connect(function()
        local c = HexToColor(Hex.Text)
        if c then h, s, v = c:ToHSV(); SyncAll("Hex") else Hex.Text = ColorToHex(pickerColor) end
    end)

    local function HandleRGB()
        local r, g, b = tonumber(rI.Text) or 0, tonumber(gI.Text) or 0, tonumber(bI.Text) or 0
        local c = Color3.fromRGB(math.clamp(r,0,255), math.clamp(g,0,255), math.clamp(b,0,255))
        h, s, v = c:ToHSV(); SyncAll("RGB")
    end
    rI.FocusLost:Connect(HandleRGB); gI.FocusLost:Connect(HandleRGB); bI.FocusLost:Connect(HandleRGB)

    local function HandleHSV()
        local nh, ns, nv = tonumber(hI.Text) or 0, tonumber(sI.Text) or 0, tonumber(vI.Text) or 0
        h, s, v = (nh%360)/360, math.clamp(ns,0,1), math.clamp(nv,0,1)
        SyncAll("HSV")
    end
    hI.FocusLost:Connect(HandleHSV); sI.FocusLost:Connect(HandleHSV); vI.FocusLost:Connect(HandleHSV)

    Apply.MouseButton1Click:Connect(function()
        table.insert(ColorHistory, 1, pickerColor)
        table.remove(ColorHistory, 9)
        Cleanup()
        if includeAlpha then
            callback({Color = pickerColor, Alpha = alpha})
        else
            callback(pickerColor)
        end
    end)

    SyncAll()
end

local MainShadow = Lib:Create("Frame", {
    Name = "Shadow",
    Parent = SettingsUI,
    BackgroundColor3 = Color3.new(0,0,0),
    BackgroundTransparency = 0.8,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(364, 464),
    Visible = false
}, { Lib:Create("UICorner", {CornerRadius = Theme.CornerMain}) })

local MainFrame = Lib:Create("Frame", {
    Name = "MainFrame",
    Parent = SettingsUI,
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(360, 460),
    ClipsDescendants = true
}, {
    Lib:Create("UICorner", {CornerRadius = Theme.CornerMain}),
    Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1.2, Transparency = 0.3})
})
MainFrame.Visible = false

local Dragging, DragStart, StartPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = input.Position
        StartPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then Dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and Dragging then
        local Delta = (input.Position - DragStart) / UIScale.Scale
        MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        MainShadow.Position = MainFrame.Position
    end
end)

local Header = Lib:Create("Frame", {
    Name = "Header",
    Parent = MainFrame,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 54)
})

local NavContainer = Lib:Create("ScrollingFrame", {
    Name = "NavContainer",
    Parent = Header,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.04, 0, 0.18, 0),
    Size = UDim2.new(1, -58, 0, 34),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Accent,
    ScrollBarImageTransparency = 0.5,
    ScrollingDirection = Enum.ScrollingDirection.X,
    ClipsDescendants = true
}, {
    Lib:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center
    }),
    Lib:Create("UIPadding", {PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2)})
})

local CloseBtn = Lib:Create("TextButton", {
    Name = "Close",
    Parent = Header,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -36, 0, 12),
    Size = UDim2.fromOffset(26, 26),
    Font = Theme.FontBold,
    Text = "×",
    TextColor3 = Theme.TextDim,
    TextSize = 22
}, { Lib:Create("UICorner", {CornerRadius = UDim.new(0, 8)}) })

CloseBtn.MouseEnter:Connect(function()
    Lib:Tween(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Theme.Error})
end)
CloseBtn.MouseLeave:Connect(function()
    Lib:Tween(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Theme.TextDim})
end)
CloseBtn.MouseButton1Click:Connect(function()
    Lib:Tween(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(360, 0)})
    Lib:Tween(MainFrame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
    task.delay(0.26, function()
        MainFrame.Visible = false
        MainFrame.BackgroundTransparency = 0
        MainFrame.Size = UDim2.fromOffset(360, 460)
        MainShadow.Visible = false
    end)
end)

local TabContainers = {}
local ActiveTab = nil
local Components = {}

function Components:AddItem(parent, title, description)
    local hasDesc = description and description ~= ""
    local ItemContainer = Lib:Create("Frame", {
        Name = title,
        Parent = parent,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0.95, 0, 0, hasDesc and 62 or 46),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerCard}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1, Transparency = 0.6}),
        Lib:Create("UIPadding", {PaddingBottom = UDim.new(0, 10)})
    })

    Lib:Create("TextLabel", {
        Name = "Title",
        Parent = ItemContainer,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, hasDesc and 10 or 0),
        Size = UDim2.new(0.55, 0, hasDesc and 0 or 1, hasDesc and 18 or 0),
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })

    if hasDesc then
        Lib:Create("TextLabel", {
            Name = "Desc",
            Parent = ItemContainer,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 30),
            Size = UDim2.new(0.55, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            Font = Theme.FontRegular,
            Text = description,
            TextColor3 = Theme.TextDim,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top
        })
    end

    ItemContainer.MouseEnter:Connect(function()
        Lib:Tween(ItemContainer, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceElevated})
        Lib:Tween(ItemContainer:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Transparency = 0.2, Color = Theme.Accent})
    end)
    ItemContainer.MouseLeave:Connect(function()
        Lib:Tween(ItemContainer, TweenInfo.new(0.25), {BackgroundColor3 = Theme.Surface})
        Lib:Tween(ItemContainer:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), {Transparency = 0.6, Color = Theme.Border})
    end)

    return ItemContainer
end

function Components:AddToggle(container, title, description, default, callback)
    local item = self:AddItem(container, title, description)
    local state = default or false

    local ToggleBg = Lib:Create("TextButton", {
        Parent = item,
        BackgroundColor3 = state and Theme.Success or Theme.SurfaceElevated,
        Position = UDim2.new(1, -56, 0.5, -11),
        Size = UDim2.new(0, 44, 0, 22),
        Text = "",
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}) })

    local Knob = Lib:Create("Frame", {
        Parent = ToggleBg,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Position = UDim2.new(state and 1 or 0, state and -20 or 3, 0.5, -9),
        Size = UDim2.new(0, 18, 0, 18),
        AnchorPoint = Vector2.new(state and 1 or 0, 0.5)
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}) })

    local function updateVisuals(newState)
        state = newState
        Lib:Tween(ToggleBg, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            BackgroundColor3 = state and Theme.Success or Theme.SurfaceElevated
        })
        Lib:Tween(Knob, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(state and 1 or 0, state and -20 or 3, 0.5, -9),
            AnchorPoint = Vector2.new(state and 1 or 0, 0.5)
        })
    end

    ToggleBg.MouseButton1Click:Connect(function()
        updateVisuals(not state)
        callback(state)
    end)

    return {
        SetState = function(newState)
            updateVisuals(newState)
        end
    }
end

function Components:AddDropdown(container, title, options, default, callback)
    local item = self:AddItem(container, title, nil)
    local selected = default or options[1]

    local DropBtn = Lib:Create("TextButton", {
        Parent = item,
        BackgroundColor3 = Theme.Background,
        Position = UDim2.new(1, -120, 0.5, -13),
        Size = UDim2.new(0, 108, 0, 26),
        Font = Theme.FontRegular,
        Text = selected .. "  ▾",
        TextColor3 = Theme.Text,
        TextSize = 12,
        AutoButtonColor = false
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1})
    })

    local IsOpen = false
    local DropList = Lib:Create("Frame", {
        Parent = SettingsUI,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.fromOffset(120, 0),
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 200
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerCard}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1}),
        Lib:Create("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)})
    })

    local ListScroll = Lib:Create("ScrollingFrame", {
        Parent = DropList,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 34),
        Size = UDim2.new(1, -12, 1, -40),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, { Lib:Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}) })

    local SearchBox = Lib:Create("TextBox", {
        Parent = DropList,
        BackgroundColor3 = Theme.Background,
        Position = UDim2.fromOffset(8, 6),
        Size = UDim2.new(1, -16, 0, 24),
        Font = Theme.FontRegular,
        PlaceholderText = "Search...",
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 11
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}) })

    local function RefreshOptions(filter)
        for _, v in pairs(ListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for _, opt in pairs(options) do
            if not filter or string.find(string.lower(opt), string.lower(filter)) then
                local b = Lib:Create("TextButton", {
                    Parent = ListScroll,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 26),
                    Font = Theme.FontRegular,
                    Text = opt,
                    TextColor3 = Theme.Text,
                    TextSize = 11,
                    AutoButtonColor = false
                }, { Lib:Create("UICorner", {CornerRadius = UDim.new(0, 6)}) })
                b.MouseEnter:Connect(function()
                    Lib:Tween(b, TweenInfo.new(0.15), {BackgroundTransparency = 0.85, BackgroundColor3 = Theme.SurfaceElevated})
                end)
                b.MouseLeave:Connect(function()
                    Lib:Tween(b, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                end)
                b.MouseButton1Click:Connect(function()
                    selected = opt
                    DropBtn.Text = opt .. "  ▾"
                    IsOpen = false
                    Lib:Tween(DropList, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(120, 0)})
                    task.delay(0.2, function() if not IsOpen then DropList.Visible = false end end)
                    callback(opt)
                end)
            end
        end
    end

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function() RefreshOptions(SearchBox.Text) end)

    local Dropdown = {
        Button = DropBtn,
        Refresh = function(newOptions)
            if newOptions then options = newOptions end
            RefreshOptions(SearchBox.Text)
        end
    }

    RefreshOptions()

    DropBtn.MouseButton1Click:Connect(function()
        IsOpen = not IsOpen
        if IsOpen then
            local scale = UIScale.Scale
            local btnPos = DropBtn.AbsolutePosition
            local btnSize = DropBtn.AbsoluteSize
            local listHeight = math.min(#options * 26 + 42, 210)
            DropList.Size = UDim2.fromOffset(120, 0)
            DropList.Position = UDim2.new(0, btnPos.X / scale, 0, (btnPos.Y + btnSize.Y + 6) / scale)
            DropList.Visible = true
            Lib:Tween(DropList, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(120, listHeight)})
            RefreshOptions(SearchBox.Text)
        else
            Lib:Tween(DropList, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(120, 0)})
            task.delay(0.2, function() if not IsOpen then DropList.Visible = false end end)
        end
    end)

    return Dropdown
end

function Components:AddSection(container, title)
    return Lib:Create("TextLabel", {
        Parent = container,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.95, 0, 0, 28),
        Font = Theme.FontBold,
        Text = title:upper(),
        TextColor3 = Theme.Accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    })
end

function Components:AddButton(container, title, callback)
    local item = self:AddItem(container, title, nil)
    local Btn = Lib:Create("TextButton", {
        Parent = item,
        BackgroundColor3 = Theme.Accent,
        Position = UDim2.new(1, -80, 0.5, -13),
        Size = UDim2.new(0, 68, 0, 26),
        Font = Theme.FontBold,
        Text = "Click",
        TextColor3 = Theme.Background,
        TextSize = 12,
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}) })

    Btn.MouseEnter:Connect(function()
        Lib:Tween(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.AccentDim, Size = UDim2.new(0, 70, 0, 28), Position = UDim2.new(1, -81, 0.5, -14)})
    end)
    Btn.MouseLeave:Connect(function()
        Lib:Tween(Btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Accent, Size = UDim2.new(0, 68, 0, 26), Position = UDim2.new(1, -80, 0.5, -13)})
    end)
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

function Components:AddInput(container, title, placeholder, default, callback)
    local item = self:AddItem(container, title, nil)
    local Input = Lib:Create("TextBox", {
        Parent = item,
        BackgroundColor3 = Theme.Background,
        Position = UDim2.new(1, -115, 0.5, -13),
        Size = UDim2.new(0, 100, 0, 26),
        Font = Theme.FontRegular,
        PlaceholderText = placeholder or "...",
        Text = default or "",
        TextColor3 = Theme.Text,
        TextSize = 12,
        ClearTextOnFocus = false
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1})
    })

    Input.Focused:Connect(function()
        Lib:Tween(Input:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Color = Theme.Accent})
    end)
    Input.FocusLost:Connect(function()
        Lib:Tween(Input:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), {Color = Theme.Border})
        callback(Input.Text)
    end)

    local Reset = Lib:Create("ImageButton", {
        Parent = item,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -140, 0.5, -10),
        Size = UDim2.new(0, 20, 0, 20),
        Image = "rbxassetid://127493377027615",
        ImageColor3 = Theme.TextDim,
        ScaleType = Enum.ScaleType.Fit
    })
    Reset.MouseEnter:Connect(function()
        Lib:Tween(Reset, TweenInfo.new(0.15), {ImageColor3 = Theme.Text})
    end)
    Reset.MouseLeave:Connect(function()
        Lib:Tween(Reset, TweenInfo.new(0.15), {ImageColor3 = Theme.TextDim})
    end)
    Reset.MouseButton1Click:Connect(function()
        Input.Text = default or ""
        callback(Input.Text)
    end)

    return { SetValue = function(val) Input.Text = val end }
end

function Components:AddTextArea(container, title, placeholder, default, callback)
    local item = self:AddItem(container, title, nil)
    item.Size = UDim2.new(0.95, 0, 0, 130)

    local TextArea = Lib:Create("TextBox", {
        Parent = item,
        BackgroundColor3 = Theme.Background,
        Position = UDim2.new(0, 12, 0, 32),
        Size = UDim2.new(1, -24, 0, 88),
        Font = Theme.FontRegular,
        PlaceholderText = placeholder or "...",
        Text = default or "",
        TextColor3 = Theme.Text,
        TextSize = 12,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerInput}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1}),
        Lib:Create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)})
    })

    TextArea.Focused:Connect(function()
        Lib:Tween(TextArea:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Color = Theme.Accent})
    end)
    TextArea.FocusLost:Connect(function()
        Lib:Tween(TextArea:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), {Color = Theme.Border})
        callback(TextArea.Text)
    end)
    return TextArea
end

function Components:AddIconButton(container, imageId, callback)
    local BtnHolder = Lib:Create("TextButton", {
        Parent = container,
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 38, 0, 38),
        Text = "",
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(0, 12)}) })

    local Btn = Lib:Create("ImageLabel", {
        Parent = BtnHolder,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 22, 0, 22),
        Image = "rbxassetid://" .. tostring(imageId):gsub("rbxassetid://", ""),
        ImageColor3 = Color3.fromRGB(180, 180, 180),
        ScaleType = Enum.ScaleType.Fit,
        Active = false
    })

    BtnHolder.MouseEnter:Connect(function()
        Lib:Tween(BtnHolder, TweenInfo.new(0.2), {BackgroundTransparency = 0})
        Lib:Tween(Btn, TweenInfo.new(0.2), {ImageColor3 = Color3.new(1, 1, 1)})
    end)
    BtnHolder.MouseLeave:Connect(function()
        Lib:Tween(BtnHolder, TweenInfo.new(0.2), {BackgroundTransparency = 1})
        Lib:Tween(Btn, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(180, 180, 180)})
    end)
    BtnHolder.MouseButton1Click:Connect(callback)
    return BtnHolder
end

function Components:AddFolder(container, title)
    local FolderContainer = Lib:Create("Frame", {
        Name = title .. "_Folder",
        Parent = container,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.95, 0, 0, 38),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true
    }, {
        Lib:Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0)})
    })

    local IsOpen = false
    local FolderBtn = Lib:Create("TextButton", {
        Parent = FolderContainer,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 38),
        LayoutOrder = 0,
        Font = Theme.FontBold,
        Text = "  ▶  " .. title,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerCard}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1, Transparency = 0.6})
    })

    local Arrow = Lib:Create("TextLabel", {
        Parent = FolderBtn,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0.5, -8),
        Size = UDim2.fromOffset(16, 16),
        Font = Enum.Font.GothamBold,
        Text = "▶",
        TextColor3 = Theme.Accent,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center
    })
    FolderBtn.Text = "   " .. title

    local Content = Lib:Create("Frame", {
        Parent = FolderContainer,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ClipsDescendants = true
    }, {
        Lib:Create("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}),
        Lib:Create("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4)})
    })

    FolderBtn.MouseEnter:Connect(function()
        Lib:Tween(FolderBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceElevated})
        Lib:Tween(FolderBtn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Color = Theme.Accent, Transparency = 0.3})
    end)
    FolderBtn.MouseLeave:Connect(function()
        Lib:Tween(FolderBtn, TweenInfo.new(0.25), {BackgroundColor3 = Theme.Surface})
        Lib:Tween(FolderBtn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), {Color = Theme.Border, Transparency = 0.6})
    end)

    FolderBtn.MouseButton1Click:Connect(function()
        IsOpen = not IsOpen
        Lib:Tween(Arrow, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Rotation = IsOpen and 90 or 0})
        Content.Visible = true
        if IsOpen then
            local targetSize = Content.AbsoluteSize.Y
            Content.Size = UDim2.new(1, 0, 0, 0)
            Lib:Tween(Content, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, targetSize)})
        else
            Lib:Tween(Content, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, 0)})
            task.delay(0.25, function() if not IsOpen then Content.Visible = false end end)
        end
    end)

    return Content
end

function Components:AddColorPicker(container, title, default, callback)
    local item = self:AddItem(container, title, nil)
    local color = default or Theme.Accent

    local ColorBtn = Lib:Create("TextButton", {
        Parent = item,
        BackgroundColor3 = color,
        Position = UDim2.new(1, -44, 0.5, -11),
        Size = UDim2.fromOffset(24, 24),
        Text = "",
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(0, 8)}) })

    ColorBtn.MouseEnter:Connect(function()
        Lib:Tween(ColorBtn, TweenInfo.new(0.15), {Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -45, 0.5, -12)})
    end)
    ColorBtn.MouseLeave:Connect(function()
        Lib:Tween(ColorBtn, TweenInfo.new(0.2), {Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -44, 0.5, -11)})
    end)

    ColorBtn.MouseButton1Click:Connect(function()
        Lib:OpenPicker(color, function(newC)
            color = newC
            ColorBtn.BackgroundColor3 = color
            callback(color)
        end)
    end)

    local Reset = Lib:Create("ImageButton", {
        Parent = item,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -72, 0.5, -10),
        Size = UDim2.fromOffset(20, 20),
        Image = "rbxassetid://127493377027615",
        ImageColor3 = Theme.TextDim,
        ScaleType = Enum.ScaleType.Fit
    })
    Reset.MouseEnter:Connect(function()
        Lib:Tween(Reset, TweenInfo.new(0.15), {ImageColor3 = Theme.Text})
    end)
    Reset.MouseLeave:Connect(function()
        Lib:Tween(Reset, TweenInfo.new(0.15), {ImageColor3 = Theme.TextDim})
    end)
    Reset.MouseButton1Click:Connect(function()
        color = default or Theme.Accent
        ColorBtn.BackgroundColor3 = color
        callback(color)
    end)

    return { SetValue = function(c) color = c; ColorBtn.BackgroundColor3 = color end }
end

local function CreateTab(name, order)
    local TabContainer = Lib:Create("ScrollingFrame", {
        Name = name .. "Page",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 60),
        Size = UDim2.new(1, -24, 1, -68),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.3,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = order == 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, {
        Lib:Create("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}),
        Lib:Create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)})
    })

    local TabBtn = Lib:Create("TextButton", {
        Name = name,
        Parent = NavContainer,
        BackgroundColor3 = order == 1 and Theme.Accent or Theme.Surface,
        BackgroundTransparency = order == 1 and 0 or 0.4,
        Size = UDim2.new(0, 0, 0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Theme.FontBold,
        Text = "  " .. name:gsub("%d", "") .. "  ",
        TextColor3 = order == 1 and Theme.Background or Theme.TextDim,
        TextSize = 13,
        LayoutOrder = order,
        AutoButtonColor = false
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}),
        Lib:Create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
    })

    TabBtn.MouseEnter:Connect(function()
        if ActiveTab ~= name then
            Lib:Tween(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceElevated, BackgroundTransparency = 0.1, TextColor3 = Theme.Text})
        end
    end)
    TabBtn.MouseLeave:Connect(function()
        if ActiveTab ~= name then
            Lib:Tween(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0.4, TextColor3 = Theme.TextDim})
        end
    end)

    TabBtn.MouseButton1Click:Connect(function()
        if ActiveTab == name then return end
        for tName, container in pairs(TabContainers) do
            container.Visible = (tName == name)
        end
        for _, btn in pairs(NavContainer:GetChildren()) do
            if btn:IsA("TextButton") then
                Lib:Tween(btn, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
                    BackgroundColor3 = Theme.Surface,
                    BackgroundTransparency = 0.4,
                    TextColor3 = Theme.TextDim
                })
            end
        end
        Lib:Tween(TabBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0,
            TextColor3 = Theme.Background
        })
        ActiveTab = name
    end)

    TabContainers[name] = TabContainer
    if order == 1 then ActiveTab = name end
    return TabContainer
end

function Components:AddInputWithColor(container, title, placeholder, defaultText, defaultColor, callback)
    local item = self:AddItem(container, title, nil)
    local color = defaultColor or Color3.new(1, 1, 1)
    local text = defaultText or ""

    local Input = Lib:Create("TextBox", {
        Parent = item,
        BackgroundColor3 = Theme.Background,
        Position = UDim2.new(1, -145, 0.5, -13),
        Size = UDim2.fromOffset(90, 26),
        Font = Theme.FontRegular,
        PlaceholderText = placeholder or "...",
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 12
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1})
    })

    Input.Focused:Connect(function()
        Lib:Tween(Input:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Color = Theme.Accent})
    end)
    Input.FocusLost:Connect(function()
        Lib:Tween(Input:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), {Color = Theme.Border})
        text = Input.Text; callback(text, color)
    end)

    local ColorBtn = Lib:Create("TextButton", {
        Parent = item,
        BackgroundColor3 = color,
        Position = UDim2.new(1, -44, 0.5, -11),
        Size = UDim2.fromOffset(24, 24),
        Text = "",
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(0, 8)}) })

    ColorBtn.MouseEnter:Connect(function()
        Lib:Tween(ColorBtn, TweenInfo.new(0.15), {Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -45, 0.5, -12)})
    end)
    ColorBtn.MouseLeave:Connect(function()
        Lib:Tween(ColorBtn, TweenInfo.new(0.2), {Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -44, 0.5, -11)})
    end)
    ColorBtn.MouseButton1Click:Connect(function()
        Lib:OpenPicker(color, function(newC)
            color = newC
            ColorBtn.BackgroundColor3 = color
            callback(text, color)
        end)
    end)

    local Reset = Lib:Create("ImageButton", {
        Parent = item,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -170, 0.5, -10),
        Size = UDim2.fromOffset(20, 20),
        Image = "rbxassetid://127493377027615",
        ImageColor3 = Theme.TextDim,
        ScaleType = Enum.ScaleType.Fit
    })
    Reset.MouseEnter:Connect(function()
        Lib:Tween(Reset, TweenInfo.new(0.15), {ImageColor3 = Theme.Text})
    end)
    Reset.MouseLeave:Connect(function()
        Lib:Tween(Reset, TweenInfo.new(0.15), {ImageColor3 = Theme.TextDim})
    end)
    Reset.MouseButton1Click:Connect(function()
        text, color = defaultText or "", defaultColor or Color3.new(1,1,1)
        Input.Text = text
        ColorBtn.BackgroundColor3 = color
        callback(text, color)
    end)

    return {
        SetValue = function(t, c) text, color = t or "", c or color; Input.Text, ColorBtn.BackgroundColor3 = text, color end,
        Button = ColorBtn,
        Item = item
    }
end

function Components:AddAssetColor(container, title, placeholder, defaultText, defaultColor, callback)
    local item = self:AddItem(container, title, nil)
    local color = defaultColor or Color3.new(1, 1, 1)
    local text = defaultText or ""

    local ColorBtn = Lib:Create("TextButton", {
        Parent = item,
        BackgroundColor3 = color,
        Position = UDim2.new(1, -44, 0.5, -11),
        Size = UDim2.fromOffset(24, 24),
        Text = "",
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = UDim.new(0, 8)}) })

    ColorBtn.MouseEnter:Connect(function()
        Lib:Tween(ColorBtn, TweenInfo.new(0.15), {Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -45, 0.5, -12)})
    end)
    ColorBtn.MouseLeave:Connect(function()
        Lib:Tween(ColorBtn, TweenInfo.new(0.2), {Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -44, 0.5, -11)})
    end)

    local EditBtn = Lib:Create("ImageButton", {
        Parent = item,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -76, 0.5, -10),
        Size = UDim2.fromOffset(20, 20),
        Image = "rbxassetid://117761881427472",
        ImageColor3 = Theme.TextDim,
        ScaleType = Enum.ScaleType.Fit
    })
    EditBtn.MouseEnter:Connect(function()
        Lib:Tween(EditBtn, TweenInfo.new(0.15), {ImageColor3 = Theme.Text})
    end)
    EditBtn.MouseLeave:Connect(function()
        Lib:Tween(EditBtn, TweenInfo.new(0.15), {ImageColor3 = Theme.TextDim})
    end)

    local InputPanel = Lib:Create("Frame", {
        Parent = SettingsUI,
        BackgroundColor3 = Theme.Surface,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        ZIndex = 1100,
        ClipsDescendants = true
    }, {
        Lib:Create("UICorner", {CornerRadius = Theme.CornerCard}),
        Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1.5})
    })

    local In = Lib:Create("TextBox", {
        Parent = InputPanel,
        Size = UDim2.new(0.88, 0, 0, 30),
        Position = UDim2.new(0.06, 0, 0.18, 0),
        BackgroundColor3 = Theme.Background,
        TextColor3 = Color3.new(1,1,1),
        PlaceholderText = placeholder or "Asset ID...",
        Text = text,
        Font = Theme.FontRegular,
        TextSize = 12
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}), Lib:Create("UIStroke", {Color = Theme.Border, Thickness = 1}) })

    local Save = Lib:Create("TextButton", {
        Parent = InputPanel,
        Size = UDim2.new(0.4, 0, 0, 26),
        Position = UDim2.new(0.06, 0, 0.6, 0),
        BackgroundColor3 = Theme.Accent,
        Text = "Apply",
        Font = Theme.FontBold,
        TextColor3 = Theme.Background,
        TextSize = 12,
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}) })

    Save.MouseEnter:Connect(function()
        Lib:Tween(Save, TweenInfo.new(0.15), {BackgroundColor3 = Theme.AccentDim})
    end)
    Save.MouseLeave:Connect(function()
        Lib:Tween(Save, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Accent})
    end)

    local Cancel = Lib:Create("TextButton", {
        Parent = InputPanel,
        Size = UDim2.new(0.4, 0, 0, 26),
        Position = UDim2.new(0.54, 0, 0.6, 0),
        BackgroundColor3 = Theme.SurfaceElevated,
        Text = "Cancel",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 12,
        AutoButtonColor = false
    }, { Lib:Create("UICorner", {CornerRadius = Theme.CornerPill}) })

    EditBtn.MouseButton1Click:Connect(function()
        InputPanel.Visible = true
        InputPanel.Size = UDim2.fromOffset(0, 0)
        Lib:Tween(InputPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(220, 88)})
        In.Text = text
    end)
    Cancel.MouseButton1Click:Connect(function()
        Lib:Tween(InputPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(0, 0)})
        task.delay(0.2, function() InputPanel.Visible = false end)
    end)
    Save.MouseButton1Click:Connect(function()
        text = In.Text
        Lib:Tween(InputPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(0, 0)})
        task.delay(0.2, function() InputPanel.Visible = false end)
        callback(text, color)
    end)

    ColorBtn.MouseButton1Click:Connect(function()
        Lib:OpenPicker(color, function(newC)
            color = newC
            ColorBtn.BackgroundColor3 = color
            callback(text, color)
        end)
    end)

    return {
        SetValue = function(t, c) text, color = t or "", c or color; In.Text, ColorBtn.BackgroundColor3 = text, color end,
        Button = ColorBtn,
        Item = item
    }
end

local Library = {
    UI = SettingsUI,
    CreateTab = CreateTab,
    AddToggle = function(...) return Components:AddToggle(...) end,
    AddDropdown = function(...) return Components:AddDropdown(...) end,
    AddColorPicker = function(...) return Components:AddColorPicker(...) end,
    AddButton = function(...) return Components:AddButton(...) end,
    AddInput = function(...) return Components:AddInput(...) end,
    AddSection = function(...) return Components:AddSection(...) end,
    AddTextArea = function(...) return Components:AddTextArea(...) end,
    AddIconButton = function(...) return Components:AddIconButton(...) end,
    AddFolder = function(...) return Components:AddFolder(...) end,
    AddItem = function(...) return Components:AddItem(...) end,
    AddInputWithColor = function(...) return Components:AddInputWithColor(...) end,
    AddAssetColor = function(...) return Components:AddAssetColor(...) end,
    OpenPicker = function(...) return Lib:OpenPicker(...) end,
    Create = function(self, ...) return Lib:Create(...) end
}

return Library
