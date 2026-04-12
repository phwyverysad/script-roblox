local cloneref = cloneref or function(service) return service end
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UIS = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local CoreGui = cloneref(game:GetService("CoreGui"))

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Config = {
    Aimlock = false,
    UseHoldMode = false,
    FOV = 20,
    ESPMaster = false,
    ESPColorMode = "Health",
    BoundKey = nil,
    BoundInput = Enum.UserInputType.MouseButton2,

    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    ShowHighlight = true,
    Xray = false
}

local State = {
    isAiming = false,
    isBinding = false,
    isMenuOpen = true,
    snapSide = "Right",
    isDragging = false
}

local ESPColors = {"Health", "Red", "Blue", "Green", "White", "Yellow", "Pink", "Cyan"}
local colorIndex = 1

local Theme = {
    Main = Color3.fromRGB(0, 200, 255),
    Bg = Color3.fromRGB(15, 15, 18),
    BtnOff = Color3.fromRGB(30, 30, 38),
    Text = Color3.fromRGB(240, 240, 240)
}

local Circle = Drawing.new("Circle")
Circle.Thickness = 1.5
Circle.NumSides = 60
Circle.Filled = false
Circle.Transparency = 0.7
Circle.Color = Theme.Main
Circle.Visible = false

local function UpdateCircle()
    local vp = Camera.ViewportSize
    if vp.X == 0 or vp.Y == 0 then return end
    Circle.Radius = (math.min(vp.X, vp.Y) / 2) * (Config.FOV / 100)
    Circle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
end

local ESP_Cache = {}
local ESP_Folder = Instance.new("Folder", CoreGui)
ESP_Folder.Name = "NexusESP_Folder"

local function GetColorLogic(hpPercent)
    if Config.ESPColorMode == "Health" then
        if hpPercent >= 70 then return Color3.fromRGB(50, 255, 50)
        elseif hpPercent >= 35 then return Color3.fromRGB(255, 200, 50)
        else return Color3.fromRGB(255, 50, 50) end
    elseif Config.ESPColorMode == "Red" then return Color3.fromRGB(255, 50, 50)
    elseif Config.ESPColorMode == "Blue" then return Color3.fromRGB(50, 150, 255)
    elseif Config.ESPColorMode == "Green" then return Color3.fromRGB(50, 255, 50)
    elseif Config.ESPColorMode == "White" then return Color3.fromRGB(255, 255, 255)
    elseif Config.ESPColorMode == "Yellow" then return Color3.fromRGB(255, 255, 50)
    elseif Config.ESPColorMode == "Pink" then return Color3.fromRGB(255, 100, 200)
    elseif Config.ESPColorMode == "Cyan" then return Color3.fromRGB(50, 255, 255)
    end
    return Color3.new(1,1,1)
end

local function CreateESP(plr)
    if ESP_Cache[plr] then return end
    local bGui = Instance.new("BillboardGui", ESP_Folder)
    bGui.Name = plr.Name .. "_Gui"
    bGui.AlwaysOnTop = true
    bGui.Size = UDim2.new(0, 200, 0, 70)
    bGui.StudsOffset = Vector3.new(0, 4, 0)
    bGui.Enabled = false

    local label = Instance.new("TextLabel", bGui)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 12
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)

    local highlight = Instance.new("Highlight", ESP_Folder)
    highlight.Name = plr.Name .. "_Highlight"
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.1
    highlight.Enabled = false

    ESP_Cache[plr] = { Gui = bGui, Label = label, Highlight = highlight }
end

local function RemoveESP(plr)
    if ESP_Cache[plr] then
        ESP_Cache[plr].Gui:Destroy()
        ESP_Cache[plr].Highlight:Destroy()
        ESP_Cache[plr] = nil
    end
end

Players.PlayerRemoving:Connect(RemoveESP)
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then CreateESP(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then CreateESP(p) end end)

if CoreGui:FindFirstChild("UltimateAimHub") then CoreGui.UltimateAimHub:Destroy() end

local Gui = Instance.new("ScreenGui", CoreGui)
Gui.Name = "AIMLOCK by phwyverysad"
Gui.ResetOnSpawn = false

local SideTab = Instance.new("TextButton", Gui)
SideTab.Size = UDim2.new(0, 12, 0, 80)
SideTab.Position = UDim2.new(1, -12, 0.5, -40)
SideTab.BackgroundColor3 = Theme.Bg
SideTab.Text = ""
SideTab.Visible = false
SideTab.AutoButtonColor = false
Instance.new("UICorner", SideTab).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", SideTab).Color = Theme.Main
local SideLine = Instance.new("Frame", SideTab)
SideLine.Size = UDim2.new(0, 2, 0, 40)
SideLine.Position = UDim2.new(0.5, -1, 0.5, -20)
SideLine.BackgroundColor3 = Theme.Text
SideLine.BorderSizePixel = 0
Instance.new("UICorner", SideLine).CornerRadius = UDim.new(1, 0)

local Main = Instance.new("CanvasGroup", Gui)
Main.Size = UDim2.fromOffset(280, 420)
Main.Position = UDim2.new(0.5, -140, 0.5, -210)
Main.BackgroundColor3 = Theme.Bg
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", Main).Color = Theme.Main; Instance.new("UIStroke", Main).Thickness = 1.5
local MainScale = Instance.new("UIScale", Main)

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Theme.Bg
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -20, 1, 0); Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1; Title.Text = "AIMLOCK by phwyverysad"
Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Theme.Main
Title.TextSize = 14; Title.TextXAlignment = "Left"

local Line = Instance.new("Frame", Header)
Line.Size = UDim2.new(1, 0, 0, 1); Line.Position = UDim2.new(0, 0, 1, 0); Line.BackgroundColor3 = Theme.Main; Line.BorderSizePixel = 0

local Content = Instance.new("ScrollingFrame", Main)
Content.Size = UDim2.new(1, -12, 1, -55); Content.Position = UDim2.new(0, 6, 0, 50); Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 2; Content.ScrollBarImageColor3 = Theme.Main
Content.CanvasSize = UDim2.new(0, 0, 0, 650)
local Layout = Instance.new("UIListLayout", Content)
Layout.Padding = UDim.new(0, 8); Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function CreateButton(text, isToggle, configKey, callback)
    local Btn = Instance.new("TextButton", Content)
    Btn.Size = UDim2.new(0, 240, 0, 34)
    Btn.BackgroundColor3 = (isToggle and Config[configKey]) and Theme.Main or Theme.BtnOff
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextColor3 = (isToggle and Config[configKey]) and Color3.new(1,1,1) or Theme.Text
    Btn.TextSize = 11
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", Btn)
    stroke.Color = (isToggle and Config[configKey]) and Color3.new(1,1,1) or Color3.fromRGB(50, 50, 60)
    stroke.Thickness = 1

    Btn.MouseButton1Click:Connect(function()
        callback(Btn)
        local active = (isToggle and Config[configKey])
        local color = active and Theme.Main or Theme.BtnOff
        local txtColor = active and Color3.new(1,1,1) or Theme.Text
        stroke.Color = active and Color3.new(1,1,1) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = color, TextColor3 = txtColor}):Play()
    end)
    return Btn
end

local function UpdateXray()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Parent:FindFirstChildWhichIsA("Humanoid") and not v.Parent.Parent:FindFirstChildWhichIsA("Humanoid") then
            v.LocalTransparencyModifier = (Config.Xray and 0.5 or 0)
        end
    end
end

CreateButton("AIMLOCK: OFF", true, "Aimlock", function(btn)
    Config.Aimlock = not Config.Aimlock
    btn.Text = "AIMLOCK: " .. (Config.Aimlock and "ON" or "OFF")
end)

CreateButton("MODE: TOGGLE", true, "UseHoldMode", function(btn)
    Config.UseHoldMode = not Config.UseHoldMode
    btn.Text = "MODE: " .. (Config.UseHoldMode and "HOLD" or "TOGGLE")
    State.isAiming = false
end)

local BindBtn = CreateButton("BIND: MouseButton2", false, nil, function(btn)
    if State.isBinding then return end
    State.isBinding = true
    btn.Text = "... PRESS ANY KEY ..."
    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 100, 0)}):Play()
end)

local FovContainer = Instance.new("Frame", Content)
FovContainer.Size = UDim2.new(0, 240, 0, 45); FovContainer.BackgroundTransparency = 1
local FovText = Instance.new("TextLabel", FovContainer)
FovText.Size = UDim2.new(1, 0, 0, 20); FovText.BackgroundTransparency = 1; FovText.Text = "FOV SIZE: " .. Config.FOV .. "%"
FovText.TextColor3 = Theme.Text; FovText.Font = Enum.Font.GothamBold; FovText.TextSize = 11; FovText.TextXAlignment = "Left"
local Bar = Instance.new("Frame", FovContainer)
Bar.Size = UDim2.new(1, 0, 0, 8); Bar.Position = UDim2.new(0, 0, 0, 25); Bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40); Instance.new("UICorner", Bar).CornerRadius = UDim.new(1,0)
local Fill = Instance.new("Frame", Bar)
Fill.Size = UDim2.new(Config.FOV/100, 0, 1, 0); Fill.BackgroundColor3 = Theme.Main; Instance.new("UICorner", Fill).CornerRadius = UDim.new(1,0)

local draggingFov = false
Bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingFov = true end end)
UIS.InputChanged:Connect(function(i)
    if draggingFov and i.UserInputType == Enum.UserInputType.MouseMovement then
        local pct = math.clamp((i.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0.05, 1)
        Config.FOV = math.floor(pct * 100)
        Fill.Size = UDim2.new(pct, 0, 1, 0)
        FovText.Text = "FOV SIZE: " .. Config.FOV .. "%"
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingFov = false end end)

CreateButton("MASTER ESP: OFF", true, "ESPMaster", function(btn)
    Config.ESPMaster = not Config.ESPMaster
    btn.Text = "MASTER ESP: " .. (Config.ESPMaster and "ON" or "OFF")
end)

CreateButton("SHOW NAME: ON", true, "ShowName", function(btn)
    Config.ShowName = not Config.ShowName
    btn.Text = "SHOW NAME: " .. (Config.ShowName and "ON" or "OFF")
end)

CreateButton("SHOW HEALTH: ON", true, "ShowHealth", function(btn)
    Config.ShowHealth = not Config.ShowHealth
    btn.Text = "SHOW HEALTH: " .. (Config.ShowHealth and "ON" or "OFF")
end)

CreateButton("SHOW DISTANCE: ON", true, "ShowDistance", function(btn)
    Config.ShowDistance = not Config.ShowDistance
    btn.Text = "SHOW DISTANCE: " .. (Config.ShowDistance and "ON" or "OFF")
end)

CreateButton("HIGHLIGHT: ON", true, "ShowHighlight", function(btn)
    Config.ShowHighlight = not Config.ShowHighlight
    btn.Text = "HIGHLIGHT: " .. (Config.ShowHighlight and "ON" or "OFF")
end)

CreateButton("XRAY: OFF", true, "Xray", function(btn)
    Config.Xray = not Config.Xray
    btn.Text = "XRAY: " .. (Config.Xray and "ON" or "OFF")
    UpdateXray()
end)

CreateButton("ESP COLOR: HEALTH", false, nil, function(btn)
    colorIndex = colorIndex + 1
    if colorIndex > #ESPColors then colorIndex = 1 end
    Config.ESPColorMode = ESPColors[colorIndex]
    btn.Text = "ESP COLOR: " .. string.upper(Config.ESPColorMode)
    local activeColor = GetColorLogic(100)
    TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = activeColor}):Play()
end)

-- Window Logic
local function CloseMenu()
    if not State.isMenuOpen then return end
    State.isMenuOpen = false
    local twScale = TweenService:Create(MainScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0.8})
    local twFade = TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {GroupTransparency = 1})
    twScale:Play(); twFade:Play()
    twScale.Completed:Connect(function()
        if not State.isMenuOpen then
            Main.Visible = false
            SideTab.Visible = true
            local yPos = Main.AbsolutePosition.Y
            if State.snapSide == "Left" then
                SideTab.Position = UDim2.new(0, 0, 0, yPos + (Main.AbsoluteSize.Y/2) - 40)
            else
                SideTab.Position = UDim2.new(1, -12, 0, yPos + (Main.AbsoluteSize.Y/2) - 40)
            end
            SideTab.BackgroundTransparency = 1
            TweenService:Create(SideTab, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
        end
    end)
end

local function OpenMenu()
    if State.isMenuOpen then return end
    State.isMenuOpen = true
    SideTab.Visible = false
    Main.Visible = true
    MainScale.Scale = 0.8
    Main.GroupTransparency = 1
    local vp = Camera.ViewportSize
    local mSize = Main.AbsoluteSize
    local targetY = SideTab.AbsolutePosition.Y - (mSize.Y/2) + 40
    targetY = math.clamp(targetY, 10, vp.Y - mSize.Y - 10)
    if State.snapSide == "Left" then
        Main.Position = UDim2.new(0, 20, 0, targetY)
    else
        Main.Position = UDim2.new(0, vp.X - mSize.X - 20, 0, targetY)
    end
    TweenService:Create(MainScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {GroupTransparency = 0}):Play()
end

SideTab.MouseButton1Click:Connect(OpenMenu)

local function MakeDraggable(TopBar, Object)
    local dragStart, startPos
    TopBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            State.isDragging = true
            dragStart = i.Position
            startPos = Object.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if State.isDragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - dragStart
            Object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 and State.isDragging then
            State.isDragging = false
            local vp = Camera.ViewportSize
            local mPos = Main.AbsolutePosition
            local mSize = Main.AbsoluteSize
            if mPos.X < 60 then State.snapSide = "Left"; CloseMenu()
            elseif mPos.X + mSize.X > vp.X - 60 then State.snapSide = "Right"; CloseMenu() end
        end 
    end)
end
MakeDraggable(Header, Main)

local function IsCorrectInput(input)
    if Config.BoundInput == Enum.UserInputType.Keyboard then
        return input.KeyCode == Config.BoundKey
    else
        return input.UserInputType == Config.BoundInput
    end
end

UIS.InputBegan:Connect(function(input, processed)
    if State.isBinding then
        State.isBinding = false
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Config.BoundKey = input.KeyCode; Config.BoundInput = Enum.UserInputType.Keyboard
            BindBtn.Text = "BIND: " .. input.KeyCode.Name
        else
            Config.BoundKey = nil; Config.BoundInput = input.UserInputType
            BindBtn.Text = "BIND: " .. input.UserInputType.Name
        end
        TweenService:Create(BindBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.BtnOff}):Play()
        return
    end
    if processed then return end
    if IsCorrectInput(input) then 
        if Config.UseHoldMode then State.isAiming = true else State.isAiming = not State.isAiming end
    end
end)

UIS.InputEnded:Connect(function(input)
    if Config.UseHoldMode and IsCorrectInput(input) then State.isAiming = false end
end)

RunService.RenderStepped:Connect(function()
    UpdateCircle()
    Circle.Visible = Config.Aimlock or Config.ESPMaster

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local targetHead = nil
    local shortestDistance = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        local esp = ESP_Cache[p]
        
        if char and char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
            local head = char.Head
            local hrp = char.HumanoidRootPart
            local hum = char.Humanoid
            
            if hum.Health > 0 then
                local rootPos, rootOnScreen = Camera:WorldToViewportPoint(hrp.Position)
                local inFOV = false
                local mag = 0
                
                if rootOnScreen and rootPos.Z > 0 then
                    mag = (Vector2.new(rootPos.X, rootPos.Y) - center).Magnitude
                    if mag <= Circle.Radius then inFOV = true end
                end

                if esp then
                    if Config.ESPMaster and inFOV then
                        local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                        local hpPct = math.floor((hum.Health / hum.MaxHealth) * 100)
                        local statusColor = GetColorLogic(hpPct)

                        esp.Gui.Adornee = head
                        esp.Gui.Enabled = true
                        
                        local info = {}
                        if Config.ShowName then table.insert(info, p.DisplayName) end
                        if Config.ShowHealth then table.insert(info, "HP: " .. hpPct .. "%") end
                        if Config.ShowDistance then table.insert(info, "[" .. dist .. "m]") end
                        esp.Label.Text = table.concat(info, "\n")
                        esp.Label.TextColor3 = statusColor

                        esp.Highlight.Adornee = char
                        esp.Highlight.Enabled = Config.ShowHighlight
                        esp.Highlight.FillColor = statusColor
                        esp.Highlight.OutlineColor = Color3.new(1, 1, 1) 
                    else
                        esp.Gui.Enabled = false
                        esp.Highlight.Enabled = false
                    end
                end

                if inFOV and mag < shortestDistance then
                    targetHead = head
                    shortestDistance = mag
                end
            else
                if esp then esp.Gui.Enabled = false; esp.Highlight.Enabled = false end
            end
        else
            if esp then esp.Gui.Enabled = false; esp.Highlight.Enabled = false end
        end
    end

    if Config.Aimlock and State.isAiming and targetHead then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetHead.Position)
    end
end)
