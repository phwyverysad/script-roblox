local cloneref = cloneref or function(s) return s end
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local UIS          = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local CoreGui      = cloneref(game:GetService("CoreGui"))
local Stats        = cloneref(game:GetService("Stats"))
local Lighting     = cloneref(game:GetService("Lighting"))
local HttpService  = cloneref(game:GetService("HttpService"))
local VirtualUser  = nil
pcall(function() VirtualUser = cloneref(game:GetService("VirtualUser")) end)

local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- [ SAVE ORIGINALS on first run, RESTORE on re-run ]
do
    local _SaveOriginals = function()
        if _G._PwyvOrig then return end  -- already saved
        _G._PwyvOrig = {}
        local o = _G._PwyvOrig
        -- Camera
        pcall(function()
            o.FOV        = workspace.CurrentCamera.FieldOfView
            o.MaxZoom    = Players.LocalPlayer.CameraMaxZoomDistance
            o.MinZoom    = Players.LocalPlayer.CameraMinZoomDistance
        end)
        -- Lighting
        pcall(function()
            o.GlobalShadows = Lighting.GlobalShadows
            o.FogEnd        = Lighting.FogEnd
        end)
        -- Rendering
        pcall(function() o.Quality = settings().Rendering.QualityLevel end)
        -- Character humanoid
        local lpc = Players.LocalPlayer.Character
        if lpc then
            local h = lpc:FindFirstChildOfClass("Humanoid")
            if h then
                o.WalkSpeed        = h.WalkSpeed
                o.JumpPower        = h.JumpPower
                o.UseJumpPower     = h.UseJumpPower
                o.MaxHealth        = h.MaxHealth
                o.BreakJoints      = h.BreakJointsOnDeath
                pcall(function() o.RequiresNeck = h.RequiresNeck end)
            end
        end
        -- Other players' HRP sizes (for hitbox restore)
        o.HRPSizes = {}
        for _, p in ipairs(Players:GetPlayers()) do
            pcall(function()
                if p ~= Players.LocalPlayer and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then o.HRPSizes[p.Name] = hrp.Size end
                end
            end)
        end
    end

    local alreadyRan = CoreGui:FindFirstChild("PhwyverysadModMenu") ~= nil
    if not alreadyRan then
        -- First run: just save originals
        _SaveOriginals()
    else
        -- Re-run: restore everything to exact originals
        pcall(function()
            local o = _G._PwyvOrig or {}
            local lpc = Players.LocalPlayer.Character
            if lpc then
                local h = lpc:FindFirstChildOfClass("Humanoid")
                if h then
                    h.WalkSpeed           = o.WalkSpeed or 16
                    h.UseJumpPower        = (o.UseJumpPower ~= nil) and o.UseJumpPower or true
                    h.JumpPower           = o.JumpPower or 50
                    h.MaxHealth           = o.MaxHealth or 100
                    h.Health              = math.min(h.Health, o.MaxHealth or 100)
                    h.BreakJointsOnDeath  = (o.BreakJoints ~= nil) and o.BreakJoints or true
                    pcall(function() h.RequiresNeck   = (o.RequiresNeck ~= nil) and o.RequiresNeck or true end)
                    h.PlatformStand       = false
                end
                -- Restore CanCollide
                for _, p in ipairs(lpc:GetDescendants()) do
                    pcall(function() if p:IsA("BasePart") then p.CanCollide = true end end)
                end
                -- Remove Fly forces
                local hrp = lpc:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bg = hrp:FindFirstChildOfClass("BodyGyro")
                    local bv = hrp:FindFirstChildOfClass("BodyVelocity")
                    if bg then bg:Destroy() end
                    if bv then bv:Destroy() end
                end
                pcall(function() lpc.Animate.Disabled = false end)
                -- Restore camera subject
                local hum = lpc:FindFirstChildOfClass("Humanoid")
                if hum then workspace.CurrentCamera.CameraSubject = hum end
            end
            -- Camera restore
            workspace.CurrentCamera.FieldOfView = o.FOV or 70
            pcall(function() Players.LocalPlayer.CameraMaxZoomDistance = o.MaxZoom or 400 end)
            pcall(function() Players.LocalPlayer.CameraMinZoomDistance = o.MinZoom or 5 end)
            -- Lighting restore
            pcall(function() Lighting.GlobalShadows = (o.GlobalShadows ~= nil) and o.GlobalShadows or true end)
            pcall(function() Lighting.FogEnd = o.FogEnd or 1e6 end)
            -- Rendering quality restore
            pcall(function() settings().Rendering.QualityLevel = o.Quality or Enum.QualityLevel.Automatic end)
            -- Restore other players' hitboxes
            for _, p in ipairs(Players:GetPlayers()) do
                pcall(function()
                    if p ~= Players.LocalPlayer and p.Character then
                        local hrp2 = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp2 then
                            local origSz = (o.HRPSizes and o.HRPSizes[p.Name]) or Vector3.new(2,2,1)
                            hrp2.Size          = origSz
                            hrp2.Transparency  = 1
                            hrp2.Material      = Enum.Material.SmoothPlastic
                            hrp2.CanCollide    = true
                        end
                    end
                end)
            end
            -- Destroy ESP folder
            local espF = workspace:FindFirstChild("NexusESP_Folder") or workspace:FindFirstChild("PhwyverysadESP")
            if espF then espF:Destroy() end
            -- Remove old FOV Drawing circle
            if _G._PwyvCircle then
                pcall(function() _G._PwyvCircle.Visible=false; _G._PwyvCircle:Remove() end)
                _G._PwyvCircle = nil
            end
        end)
        -- Clear saved originals so they're re-captured fresh this run
        _G._PwyvOrig = nil
    end
end
for _, n in ipairs({"PhwyverysadModMenu","PhwyverysadDropdowns","PhwyverysadCPicker","NexusESP_Folder"}) do
    local g = CoreGui:FindFirstChild(n); if g then g:Destroy() end
end

-- [ CONFIG ]
local Config = {
    Aimlock = false, AimMode = "HOLD", FOV = 20, AimSmooth = 1,
    WallCheck = true,
    -- TargetMode: 1=PLAYERS ONLY  2=NPCs ONLY  3=PLAYERS & NPCs
    TargetMode = 1,
    EnemyOnly = false, BindType = "Keyboard", BindKey = nil,

    ESPMaster = false, ESPShowName = false, ESPShowHealth = false,
    ESPShowDistance = false, ESPHighlight = false,
    ESPTeamCheck = false, ESPTeamColor = false, ESPXray = false,
    ESPTextSize = 10, ESPFillTrans = 0.5, ESPOutlineTrans = 0.1,
    ESPColor_C3 = Color3.new(1,1,1),

    P_Master = false, P_ShowName = false, P_ShowHealth = false,
    P_ShowDist = false, P_Highlight = false,
    P_TeamCheck = false, P_TeamColor = false, P_Xray = false,
    P_TextSize = 10, P_FillTrans = 0.5, P_OutlineTrans = 0.1,
    P_HitboxToggle = false, P_HitboxSize = 32, HitboxTargetMode = "PLAYERS ONLY",
    P_Color_C3 = Color3.new(1,1,1),
    P_ESPInFOVOnly = false,

    WalkSpeed = 100, WSToggle = false,
    JumpPower = 100, JPToggle = false,
    InfJump = false, FlyToggle = false, FlySpeed = 100,
    Noclip = false, InfZoom = false, InvisToggle = false,
    FOVToggle = false, FOVView = 70,
    FOVColor_C3 = Color3.fromRGB(30,161,255),

    GodMode = false, AntiAFK = true,
    FPSBooster = false, FPS_NoShadows = true,
    FPS_NoParticles = true, FPS_NoClothes = true, FPS_LowQuality = true,

    ShowFPSPing = "FPS & Ping", ShowStatsToggle = false, HUDPosition = "TopRight",
    TPTarget = "-", TPMode = "Warp", TPFlightSens = 80, TPGOSwitch = false,
    SpecTarget = "-", SpecToggle = false,
    ClickTPToggle = false, ClickTPBindType = "Keyboard", ClickTPBindKey = nil,
    MenuToggleBindType = "Keyboard", MenuToggleBindKey = Enum.KeyCode.G, MenuVisible = true,
    Theme = "Midnight",
}

-- [ STATE ]
local State = {
    Running = true, ToggleAiming = false, Binding = nil,
    isMinimized = false, isMaximized = false, isHidden = false,
    preHideSize = nil,
    originalSize = UDim2.new(0,880,0,570),
    originalPos  = UDim2.new(0.5,-440,0.5,-285),
}

local Connections = {}; local ESP_Cache = {}; local NPCCache = {}
local XrayCache_M = {}; local XrayCache_P = {}; local HitboxOriginalSizes = {}
local OriginalInteractData = {}
local LockedTarget = nil; local FlyBG, FlyBV = nil, nil
local WS_Loop,JP_Loop,NC_Conn,IJ_Conn = nil,nil,nil,nil
local GM_Conn,AFK_Conn,FPS_DescConn,SafeTP_Conn = nil,nil,nil,nil
local lastFPS,frameCount,pingValue = 0,0,0
local lastWarpTick = 0
local AllRowFrames = {}; local ThemeRefs = {}
local Tabs = {}; local currentTab = nil; local AllRows = {}
local ESP_Folder
-- ValidTargets: populated by target scanner (same as AIMLOCK.lua pattern)
local ValidTargets = {}  -- char -> displayName

local function AddConn(c) table.insert(Connections,c); return c end
local function RegTR(obj,key,prop) table.insert(ThemeRefs,{obj=obj,key=key,prop=prop}); return obj end

-- [ THEMES ]
local Themes = {
    Dark     = { Primary=Color3.fromRGB(30,161,255),  Accent=Color3.fromRGB(80,190,255),  WinBg=Color3.fromRGB(20,20,24),   TitleBg=Color3.fromRGB(28,28,34),  SideBar=Color3.fromRGB(24,24,30),  Content=Color3.fromRGB(17,17,22),  Row=Color3.fromRGB(32,32,40),  RowH=Color3.fromRGB(44,44,54),  Element=Color3.fromRGB(46,46,58),  Stroke=Color3.fromRGB(60,60,78),  Toggle_Off=Color3.fromRGB(55,55,68),  TextSub=Color3.fromRGB(120,120,140) },
    Midnight = { Primary=Color3.fromRGB(100,120,255), Accent=Color3.fromRGB(150,180,255), WinBg=Color3.fromRGB(10,10,18),   TitleBg=Color3.fromRGB(16,16,25),  SideBar=Color3.fromRGB(12,12,20),  Content=Color3.fromRGB(8,8,15),    Row=Color3.fromRGB(18,18,30),  RowH=Color3.fromRGB(28,28,44),  Element=Color3.fromRGB(30,30,48),  Stroke=Color3.fromRGB(48,48,70),  Toggle_Off=Color3.fromRGB(44,44,65),  TextSub=Color3.fromRGB(110,110,150) },
    Neon     = { Primary=Color3.fromRGB(0,255,120),   Accent=Color3.fromRGB(100,255,180), WinBg=Color3.fromRGB(8,14,10),    TitleBg=Color3.fromRGB(12,20,15),  SideBar=Color3.fromRGB(10,16,12),  Content=Color3.fromRGB(6,11,8),    Row=Color3.fromRGB(16,26,20),  RowH=Color3.fromRGB(22,38,28),  Element=Color3.fromRGB(25,40,30),  Stroke=Color3.fromRGB(38,65,48),  Toggle_Off=Color3.fromRGB(35,55,42),  TextSub=Color3.fromRGB(100,145,115) },
    Rose     = { Primary=Color3.fromRGB(255,80,150),  Accent=Color3.fromRGB(255,140,190), WinBg=Color3.fromRGB(22,12,17),   TitleBg=Color3.fromRGB(32,18,25),  SideBar=Color3.fromRGB(26,14,20),  Content=Color3.fromRGB(16,9,13),   Row=Color3.fromRGB(38,20,29),  RowH=Color3.fromRGB(52,28,40),  Element=Color3.fromRGB(50,26,37),  Stroke=Color3.fromRGB(75,38,56),  Toggle_Off=Color3.fromRGB(62,35,50),  TextSub=Color3.fromRGB(150,100,125) },
    Gold     = { Primary=Color3.fromRGB(255,200,50),  Accent=Color3.fromRGB(255,235,130), WinBg=Color3.fromRGB(18,14,8),    TitleBg=Color3.fromRGB(28,22,12),  SideBar=Color3.fromRGB(22,18,10),  Content=Color3.fromRGB(14,10,6),   Row=Color3.fromRGB(32,26,14),  RowH=Color3.fromRGB(44,36,19),  Element=Color3.fromRGB(42,34,18),  Stroke=Color3.fromRGB(65,52,28),  Toggle_Off=Color3.fromRGB(55,45,25),  TextSub=Color3.fromRGB(145,125,80) },
    Purple   = { Primary=Color3.fromRGB(180,80,255),  Accent=Color3.fromRGB(215,145,255), WinBg=Color3.fromRGB(14,10,22),   TitleBg=Color3.fromRGB(22,16,33),  SideBar=Color3.fromRGB(18,12,28),  Content=Color3.fromRGB(10,7,17),   Row=Color3.fromRGB(30,20,45),  RowH=Color3.fromRGB(42,28,63),  Element=Color3.fromRGB(40,26,60),  Stroke=Color3.fromRGB(62,42,90),  Toggle_Off=Color3.fromRGB(52,36,75),  TextSub=Color3.fromRGB(130,100,160) },
}

local Colors = {}
local function CopyTheme(t)
    Colors.PrimaryBlue=t.Primary; Colors.AccentGlow=t.Accent; Colors.WindowBg=t.WinBg; Colors.TitleBg=t.TitleBg
    Colors.SidebarBg=t.SideBar; Colors.ContentBg=t.Content; Colors.RowBg=t.Row; Colors.RowHover=t.RowH
    Colors.DarkElement=t.Element; Colors.Stroke=t.Stroke; Colors.Toggle_Off=t.Toggle_Off; Colors.TextSub=t.TextSub
    Colors.TextMain=Color3.fromRGB(240,240,240); Colors.Green=Color3.fromRGB(50,220,90); Colors.Red=Color3.fromRGB(220,60,60)
end
CopyTheme(Themes.Dark)

-- [ TWEEN HELPERS ]
local function Tw(obj,t,props,style,dir)
    TweenService:Create(obj,TweenInfo.new(t,style or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),props):Play()
end
local function TwSpring(obj,t,props) TweenService:Create(obj,TweenInfo.new(t,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),props):Play() end
local function TwBack(obj,t,props)   TweenService:Create(obj,TweenInfo.new(t,Enum.EasingStyle.Back,Enum.EasingDirection.Out),props):Play()   end
local function Corner(obj,r) Instance.new("UICorner",obj).CornerRadius=UDim.new(0,r or 10); return obj end
local function Stroke(obj,col,th) local s=Instance.new("UIStroke",obj); s.Color=col; s.Thickness=th or 1; return s end

-- [ SCREEN GUI + MAIN FRAME ]
local ScreenGui = Instance.new("ScreenGui",CoreGui)
ScreenGui.Name="PhwyverysadModMenu"; ScreenGui.ResetOnSpawn=false; ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local W,H = State.originalSize.X.Offset, State.originalSize.Y.Offset

local MainFrame = Instance.new("Frame",ScreenGui)
MainFrame.Size=UDim2.new(0,W*0.55,0,H*0.55)
MainFrame.Position=UDim2.new(0.5,-W*0.275,0.5,-H*0.275)
MainFrame.BackgroundTransparency=1; MainFrame.BorderSizePixel=0; MainFrame.Active=true; MainFrame.ClipsDescendants=false

local BgContainer = Instance.new("Frame", MainFrame)
BgContainer.Size = UDim2.new(1,0,1,0)
BgContainer.BackgroundColor3 = Themes.Dark.WinBg
BgContainer.BackgroundTransparency = 0.05
BgContainer.BorderSizePixel = 0
BgContainer.ClipsDescendants = true
RegTR(BgContainer,"WinBg","BackgroundColor3")
local MainCorner=Corner(BgContainer,12)
local MainStroke=Stroke(BgContainer,Themes.Dark.Stroke,1.2); RegTR(MainStroke,"Stroke","Color")

-- Spring entrance
task.delay(0.04, function()
    TweenService:Create(MainFrame,TweenInfo.new(0.72,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),{
        Size=State.originalSize, Position=State.originalPos }):Play()
end)

-- [ TITLE BAR ]
local TitleBar=Instance.new("Frame",BgContainer)
TitleBar.Size=UDim2.new(1,0,0,46); TitleBar.BackgroundColor3=Themes.Dark.TitleBg; TitleBar.ZIndex=5
RegTR(TitleBar,"TitleBg","BackgroundColor3")

local TitleLine=Instance.new("Frame",TitleBar)
TitleLine.Size=UDim2.new(0,0,0,2); TitleLine.Position=UDim2.new(0,0,1,-2)
TitleLine.BackgroundColor3=Themes.Dark.Primary; TitleLine.BorderSizePixel=0; TitleLine.ZIndex=6
Corner(TitleLine,2); task.delay(0.76,function() Tw(TitleLine,0.6,{Size=UDim2.new(1,0,0,2)}) end)

-- LEFT: Mac dots + Logo
local TitleLeft=Instance.new("Frame",TitleBar)
TitleLeft.Size=UDim2.new(0.48,0,1,0); TitleLeft.Position=UDim2.new(0,0,0,0)
TitleLeft.BackgroundTransparency=1; TitleLeft.ZIndex=5

local MacDots=Instance.new("Frame",TitleLeft)
MacDots.Size=UDim2.new(0,62,1,0); MacDots.Position=UDim2.new(0,14,0,0); MacDots.BackgroundTransparency=1
local DLyt=Instance.new("UIListLayout",MacDots)
DLyt.FillDirection=Enum.FillDirection.Horizontal; DLyt.VerticalAlignment=Enum.VerticalAlignment.Center; DLyt.Padding=UDim.new(0,8)
local function MakeDot(col, icon)
    local d=Instance.new("TextButton",MacDots); d.Size=UDim2.new(0,13,0,13); d.BackgroundColor3=col; d.Text=""; d.ZIndex=6; d.AutoButtonColor=false
    Corner(d,99)
    local ict=Instance.new("TextLabel",d); ict.Size=UDim2.new(1,0,1,0); ict.BackgroundTransparency=1
    ict.Text=icon; ict.TextColor3=Color3.new(0,0,0); ict.TextTransparency=1; ict.Font=Enum.Font.GothamBold; ict.TextSize=8; ict.ZIndex=7
    d.MouseEnter:Connect(function() Tw(d,0.13,{Size=UDim2.new(0,15,0,15)}); Tw(ict,0.13,{TextTransparency=0.4}) end)
    d.MouseLeave:Connect(function() Tw(d,0.13,{Size=UDim2.new(0,13,0,13)}); Tw(ict,0.13,{TextTransparency=1}) end)
    d.MouseButton1Down:Connect(function() Tw(d,0.07,{Size=UDim2.new(0,11,0,11)}) end)
    d.MouseButton1Up:Connect(function() TwSpring(d,0.4,{Size=UDim2.new(0,13,0,13)}) end)
    return d
end
local DotRed=MakeDot(Color3.fromRGB(255,95,86), "✕")
local DotYellow=MakeDot(Color3.fromRGB(255,189,46), "−")
local DotGreen=MakeDot(Color3.fromRGB(39,201,63), "＋")

local TitleText=Instance.new("TextLabel",TitleLeft)
TitleText.Size=UDim2.new(1,-82,1,0); TitleText.Position=UDim2.new(0,80,0,0)
TitleText.BackgroundTransparency=1; TitleText.Text="phwyverysad"
TitleText.TextColor3=Color3.fromRGB(185,185,210); TitleText.Font=Enum.Font.GothamBold
TitleText.TextSize=15; TitleText.ZIndex=5; TitleText.TextXAlignment=Enum.TextXAlignment.Left
TitleText.TextTruncate=Enum.TextTruncate.AtEnd

-- RIGHT: Controls group (UIListLayout, right-aligned)
local TitleRight=Instance.new("Frame",TitleBar)
TitleRight.Size=UDim2.new(0.52,-10,0,32); TitleRight.Position=UDim2.new(0.48,0,0.5,-16)
TitleRight.BackgroundTransparency=1; TitleRight.ZIndex=6
local TRLyt=Instance.new("UIListLayout",TitleRight)
TRLyt.FillDirection=Enum.FillDirection.Horizontal
TRLyt.HorizontalAlignment=Enum.HorizontalAlignment.Right
TRLyt.VerticalAlignment=Enum.VerticalAlignment.Center
TRLyt.Padding=UDim.new(0,7)
Instance.new("UIPadding",TitleRight).PaddingRight=UDim.new(0,10)

-- Search box (LayoutOrder=3, rightmost)
local SearchFrame=Instance.new("Frame",TitleRight)
SearchFrame.Size=UDim2.new(0,180,0,30); SearchFrame.LayoutOrder=3
SearchFrame.BackgroundColor3=Color3.fromRGB(18,18,26); SearchFrame.ZIndex=6
Corner(SearchFrame,12); Stroke(SearchFrame,Themes.Dark.Stroke,1)
local SearchStk=SearchFrame:FindFirstChildOfClass("UIStroke")
local SearchIcon=Instance.new("TextLabel",SearchFrame)
SearchIcon.Size=UDim2.new(0,28,1,0); SearchIcon.Position=UDim2.new(0,2,0,0)
SearchIcon.BackgroundTransparency=1; SearchIcon.Text="🔍"; SearchIcon.TextSize=13; SearchIcon.ZIndex=7
local GlobalSearchBox=Instance.new("TextBox",SearchFrame)
GlobalSearchBox.Size=UDim2.new(1,-32,1,0); GlobalSearchBox.Position=UDim2.new(0,30,0,0)
GlobalSearchBox.BackgroundTransparency=1; GlobalSearchBox.PlaceholderText="ค้นหาเมนู..."
GlobalSearchBox.Text=""; GlobalSearchBox.TextColor3=Color3.fromRGB(215,215,235)
GlobalSearchBox.PlaceholderColor3=Color3.fromRGB(75,75,100); GlobalSearchBox.Font=Enum.Font.Gotham
GlobalSearchBox.TextSize=14; GlobalSearchBox.TextXAlignment=Enum.TextXAlignment.Left
GlobalSearchBox.ZIndex=7; GlobalSearchBox.ClearTextOnFocus=false
GlobalSearchBox.Focused:Connect(function() Tw(SearchStk,0.2,{Color=Colors.PrimaryBlue,Thickness=1.5}); TwSpring(SearchFrame,0.4,{Size=UDim2.new(0,230,0,30)}) end)
GlobalSearchBox.FocusLost:Connect(function() Tw(SearchStk,0.2,{Color=Colors.Stroke,Thickness=1}); TwSpring(SearchFrame,0.4,{Size=UDim2.new(0,180,0,30)}) end)

-- Hide / Show button (LayoutOrder=2)
local HideBtn=Instance.new("TextButton",TitleRight)
HideBtn.Size=UDim2.new(0,66,0,30); HideBtn.LayoutOrder=2
HideBtn.BackgroundColor3=Color3.fromRGB(38,38,52); HideBtn.Text="ซ่อน"; HideBtn.AutoButtonColor=false
HideBtn.TextColor3=Color3.fromRGB(195,195,215); HideBtn.Font=Enum.Font.GothamBold; HideBtn.TextSize=13; HideBtn.ZIndex=6
Corner(HideBtn,12); Stroke(HideBtn,Themes.Dark.Stroke,1)
local HideBtnStk=HideBtn:FindFirstChildOfClass("UIStroke")
HideBtn.MouseEnter:Connect(function() Tw(HideBtn,0.15,{BackgroundColor3=Color3.fromRGB(54,54,72)}); Tw(HideBtnStk,0.15,{Color=Colors.PrimaryBlue}) end)
HideBtn.MouseLeave:Connect(function() Tw(HideBtn,0.15,{BackgroundColor3=Color3.fromRGB(38,38,52)}); Tw(HideBtnStk,0.15,{Color=Colors.Stroke}) end)
HideBtn.MouseButton1Down:Connect(function() Tw(HideBtn,0.07,{BackgroundColor3=Color3.fromRGB(26,26,40)}) end)
HideBtn.MouseButton1Up:Connect(function() Tw(HideBtn,0.15,{BackgroundColor3=Color3.fromRGB(38,38,52)}) end)

-- Menu hotkey bind button (LayoutOrder=1, leftmost of group)
local MenuBindBtn=Instance.new("TextButton",TitleRight)
MenuBindBtn.Size=UDim2.new(0,90,0,30); MenuBindBtn.LayoutOrder=1
MenuBindBtn.BackgroundColor3=Color3.fromRGB(28,34,52); MenuBindBtn.AutoButtonColor=false
MenuBindBtn.TextColor3=Color3.fromRGB(145,180,240); MenuBindBtn.Font=Enum.Font.GothamBold; MenuBindBtn.TextSize=12; MenuBindBtn.ZIndex=6
Corner(MenuBindBtn,12); Stroke(MenuBindBtn,Themes.Dark.Stroke,1)
local MBBStroke=MenuBindBtn:FindFirstChildOfClass("UIStroke")

local function UpdateMenuBindLabel()
    if Config.MenuToggleBindType=="Mouse" and Config.MenuToggleBindKey then
        MenuBindBtn.Text="⌨  MB"..tostring(Config.MenuToggleBindKey)
    else
        MenuBindBtn.Text="⌨  "..(Config.MenuToggleBindKey and Config.MenuToggleBindKey.Name or "ตั้งปุ่ม")
    end
end
UpdateMenuBindLabel()
MenuBindBtn.MouseEnter:Connect(function() Tw(MenuBindBtn,0.15,{BackgroundColor3=Color3.fromRGB(40,50,80)}); Tw(MBBStroke,0.15,{Color=Colors.PrimaryBlue}) end)
MenuBindBtn.MouseLeave:Connect(function() if not State.Binding then Tw(MenuBindBtn,0.15,{BackgroundColor3=Color3.fromRGB(28,34,52)}); Tw(MBBStroke,0.15,{Color=Colors.Stroke}) end end)
MenuBindBtn.MouseButton1Click:Connect(function()
    MenuBindBtn.Text="[ กดปุ่ม ]"; Tw(MenuBindBtn,0.15,{BackgroundColor3=Colors.PrimaryBlue})
    State.Binding=function(io,k)
        Config.MenuToggleBindType=io; Config.MenuToggleBindKey=k
        Tw(MenuBindBtn,0.2,{BackgroundColor3=Color3.fromRGB(28,34,52)}); UpdateMenuBindLabel()
    end
end)

-- [ DRAG ]
local dragging,dragStart,dragStartPos
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 and not State.isMaximized then dragging=true; dragStart=i.Position; dragStartPos=MainFrame.Position end
end)
UIS.InputChanged:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseMovement and dragging then
        MainFrame.Position=UDim2.new(dragStartPos.X.Scale,dragStartPos.X.Offset+(i.Position.X-dragStart.X),dragStartPos.Y.Scale,dragStartPos.Y.Offset+(i.Position.Y-dragStart.Y))
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

-- [ RESIZE ]
local Resizer=Instance.new("Frame",BgContainer); Resizer.Size=UDim2.new(0,22,0,22); Resizer.Position=UDim2.new(1,-22,1,-22)
Resizer.BackgroundTransparency=1; Resizer.ZIndex=10; Resizer.Active=true
local RszIcon=Instance.new("TextLabel",Resizer); RszIcon.Size=UDim2.new(1,0,1,0); RszIcon.BackgroundTransparency=1
RszIcon.Text=""; RszIcon.TextColor3=Color3.fromRGB(55,55,72); RszIcon.TextSize=18
Resizer.MouseEnter:Connect(function() Tw(RszIcon,0.15,{TextColor3=Colors.PrimaryBlue}) end)
Resizer.MouseLeave:Connect(function() Tw(RszIcon,0.15,{TextColor3=Color3.fromRGB(55,55,72)}) end)

local BottomEdge=Instance.new("Frame",BgContainer); BottomEdge.Size=UDim2.new(1,-44,0,8); BottomEdge.Position=UDim2.new(0,22,1,-8)
BottomEdge.BackgroundTransparency=1; BottomEdge.ZIndex=9; BottomEdge.Active=true
local EL=Instance.new("Frame",BottomEdge); EL.Size=UDim2.new(1,0,0,2); EL.Position=UDim2.new(0,0,0.5,-1)
EL.BackgroundColor3=Color3.fromRGB(40,40,55); EL.BorderSizePixel=0; Corner(EL,2)
BottomEdge.MouseEnter:Connect(function() Tw(EL,0.15,{BackgroundColor3=Colors.PrimaryBlue,Size=UDim2.new(1,0,0,3)}) end)
BottomEdge.MouseLeave:Connect(function() Tw(EL,0.15,{BackgroundColor3=Color3.fromRGB(40,40,55),Size=UDim2.new(1,0,0,2)}) end)

local resizing,rStart,rStartSz; local bresizing,brStart,brStartSz
Resizer.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 and not State.isMinimized and not State.isHidden and not State.isMaximized then resizing=true; rStart=i.Position; rStartSz=MainFrame.Size end
end)
BottomEdge.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 and not State.isMinimized and not State.isHidden and not State.isMaximized then bresizing=true; brStart=i.Position; brStartSz=MainFrame.Size end
end)
UIS.InputChanged:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseMovement then
        if resizing then MainFrame.Size=UDim2.new(0,math.clamp(rStartSz.X.Offset+(i.Position.X-rStart.X),620,1500),0,math.clamp(rStartSz.Y.Offset+(i.Position.Y-rStart.Y),400,1000)) end
        if bresizing then MainFrame.Size=UDim2.new(0,brStartSz.X.Offset,0,math.clamp(brStartSz.Y.Offset+(i.Position.Y-brStart.Y),400,1000)) end
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then resizing=false; bresizing=false end end)

-- [ BODY / SIDEBAR / CONTENT ]
local Body=Instance.new("Frame",BgContainer); Body.Size=UDim2.new(1,0,1,-46); Body.Position=UDim2.new(0,0,0,46); Body.BackgroundTransparency=1

local Sidebar=Instance.new("Frame",Body); Sidebar.Size=UDim2.new(0,210,1,0); Sidebar.BackgroundColor3=Themes.Dark.SideBar; Sidebar.BorderSizePixel=0
RegTR(Sidebar,"SideBar","BackgroundColor3")
local SidebarLine=Instance.new("Frame",Sidebar); SidebarLine.Size=UDim2.new(0,1,1,0); SidebarLine.Position=UDim2.new(1,-1,0,0); SidebarLine.BackgroundColor3=Themes.Dark.Stroke; SidebarLine.BorderSizePixel=0
RegTR(SidebarLine,"Stroke","BackgroundColor3")

local SidebarTitle=Instance.new("TextLabel",Sidebar); SidebarTitle.Size=UDim2.new(1,0,0,22); SidebarTitle.Position=UDim2.new(0,16,0,18)
SidebarTitle.BackgroundTransparency=1; SidebarTitle.Text="NAVIGATION"; SidebarTitle.TextColor3=Color3.fromRGB(80,80,110); SidebarTitle.Font=Enum.Font.GothamBold; SidebarTitle.TextSize=11; SidebarTitle.TextXAlignment=Enum.TextXAlignment.Left

local MenuList=Instance.new("ScrollingFrame",Sidebar); MenuList.Size=UDim2.new(1,0,1,-112); MenuList.Position=UDim2.new(0,0,0,52)
MenuList.BackgroundTransparency=1; MenuList.ScrollBarThickness=2; MenuList.BorderSizePixel=0; MenuList.ScrollBarImageColor3=Colors.PrimaryBlue
local MenuLyt=Instance.new("UIListLayout",MenuList); MenuLyt.Padding=UDim.new(0,4); MenuLyt.HorizontalAlignment=Enum.HorizontalAlignment.Center
Instance.new("UIPadding",MenuList).PaddingTop=UDim.new(0,4)

-- Profile Section (Bottom Left Sidebar)
local ProfileContainer=Instance.new("Frame",Sidebar)
ProfileContainer.Size=UDim2.new(1,0,0,60); ProfileContainer.Position=UDim2.new(0,0,1,-60)
ProfileContainer.BackgroundTransparency=1; ProfileContainer.BorderSizePixel=0

local PLine=Instance.new("Frame",ProfileContainer); PLine.Size=UDim2.new(1,-32,0,1); PLine.Position=UDim2.new(0,16,0,0)
PLine.BackgroundColor3=Themes.Dark.Stroke; PLine.BorderSizePixel=0; RegTR(PLine,"Stroke","BackgroundColor3")

local AvatarImg=Instance.new("ImageLabel",ProfileContainer)
AvatarImg.Size=UDim2.new(0,34,0,34); AvatarImg.Position=UDim2.new(0,16,0.5,-17)
AvatarImg.BackgroundColor3=Color3.fromRGB(40,40,55); Corner(AvatarImg,99)
local AvStk=Stroke(AvatarImg,Colors.PrimaryBlue,1.2); RegTR(AvStk,"Primary","Color")
pcall(function() AvatarImg.Image=Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)

local DispLbl=Instance.new("TextLabel",ProfileContainer)
DispLbl.Size=UDim2.new(1,-68,0,16); DispLbl.Position=UDim2.new(0,62,0,14)
DispLbl.BackgroundTransparency=1; DispLbl.Text=LocalPlayer.DisplayName; DispLbl.TextColor3=Color3.new(1,1,1)
DispLbl.Font=Enum.Font.GothamBold; DispLbl.TextSize=14; DispLbl.TextXAlignment=Enum.TextXAlignment.Left; DispLbl.TextTruncate=Enum.TextTruncate.AtEnd

local UserLbl=Instance.new("TextLabel",ProfileContainer)
UserLbl.Size=UDim2.new(1,-68,0,14); UserLbl.Position=UDim2.new(0,62,0,31)
UserLbl.BackgroundTransparency=1; UserLbl.Text="@"..LocalPlayer.Name; UserLbl.TextColor3=Color3.fromRGB(150,150,170)
UserLbl.Font=Enum.Font.GothamMedium; UserLbl.TextSize=12; UserLbl.TextXAlignment=Enum.TextXAlignment.Left; UserLbl.TextTruncate=Enum.TextTruncate.AtEnd

local MainContent=Instance.new("Frame",Body); MainContent.Size=UDim2.new(1,-210,1,0); MainContent.Position=UDim2.new(0,210,0,0)
MainContent.BackgroundColor3=Themes.Dark.Content; MainContent.BorderSizePixel=0; RegTR(MainContent,"Content","BackgroundColor3")
-- Subtle inner corner on left side of content
local ContentCornerL=Instance.new("Frame",MainContent); ContentCornerL.Size=UDim2.new(0,8,1,0); ContentCornerL.BackgroundColor3=Themes.Dark.Content; ContentCornerL.BorderSizePixel=0
RegTR(ContentCornerL,"Content","BackgroundColor3")

-- [ FLOATING LAYERS (Dropdown + Color Picker) ]
local FloatingLayer=Instance.new("ScreenGui",CoreGui)
FloatingLayer.Name="PhwyverysadDropdowns"; FloatingLayer.DisplayOrder=200; FloatingLayer.ResetOnSpawn=false

-- Dropdown dim + container
local DDDim=Instance.new("TextButton",FloatingLayer); DDDim.Size=UDim2.new(1,0,1,0); DDDim.BackgroundTransparency=1; DDDim.Text=""; DDDim.ZIndex=98; DDDim.Visible=false

local DDContainer=Instance.new("Frame",FloatingLayer); DDContainer.Visible=false; DDContainer.BackgroundColor3=Color3.fromRGB(22,22,32)
DDContainer.BorderSizePixel=0; DDContainer.ZIndex=100; DDContainer.ClipsDescendants=true; DDContainer.Size=UDim2.new(0,200,0,0)
Corner(DDContainer,15)
local DDStroke=Stroke(DDContainer,Colors.PrimaryBlue,1.2)

local DDScroll=Instance.new("ScrollingFrame",DDContainer); DDScroll.Size=UDim2.new(1,-4,1,-4); DDScroll.Position=UDim2.new(0,2,0,2)
DDScroll.BackgroundTransparency=1; DDScroll.ScrollBarThickness=2; DDScroll.BorderSizePixel=0; DDScroll.ZIndex=101
DDScroll.ScrollBarImageColor3=Colors.PrimaryBlue
Instance.new("UIListLayout",DDScroll).Padding=UDim.new(0,2)

local DDTargetH=0
local function ShowDD() DDDim.Visible=true; DDContainer.Visible=true; DDContainer.Size=UDim2.new(0,200,0,0); TwBack(DDContainer,0.22,{Size=UDim2.new(0,200,0,DDTargetH)}) end
local function HideDD() DDDim.Visible=false; Tw(DDContainer,0.14,{Size=UDim2.new(0,200,0,0)}); task.delay(0.15,function() DDContainer.Visible=false end) end
DDDim.MouseButton1Click:Connect(HideDD)

-- [ COLOR PICKER (Floating singleton) ]
local CPGui=Instance.new("ScreenGui",CoreGui); CPGui.Name="PhwyverysadCPicker"; CPGui.DisplayOrder=210; CPGui.ResetOnSpawn=false

local CPPanel=Instance.new("Frame",CPGui); CPPanel.Size=UDim2.new(0,252,0,340); CPPanel.BackgroundColor3=Color3.fromRGB(10,10,15)
CPPanel.BackgroundTransparency=0.45; CPPanel.BorderSizePixel=0; CPPanel.Visible=false; CPPanel.ZIndex=110; Corner(CPPanel,20)
local CPPanelStroke=Instance.new("UIStroke",CPPanel); CPPanelStroke.Color=Colors.PrimaryBlue; CPPanelStroke.Thickness=1.5
CPPanel.ClipsDescendants=false

-- CP shadow
local CPS=Instance.new("ImageLabel",CPPanel); CPS.Size=UDim2.new(1,60,1,60); CPS.Position=UDim2.new(0,-30,0,-30)
CPS.BackgroundTransparency=1; CPS.Image="rbxassetid://6015897843"; CPS.ImageColor3=Color3.new(0,0,0); CPS.ImageTransparency=0.55
CPS.SliceCenter=Rect.new(49,49,450,450); CPS.ScaleType=Enum.ScaleType.Slice; CPS.ZIndex=-1

-- CP Title bar
local CPTitle=Instance.new("Frame",CPPanel); CPTitle.Size=UDim2.new(1,0,0,36); CPTitle.BackgroundTransparency=1; CPTitle.BorderSizePixel=0
local CPTitleFix=Instance.new("Frame",CPTitle); CPTitleFix.Size=UDim2.new(1,0,0,1); CPTitleFix.Position=UDim2.new(0,0,1,-1); CPTitleFix.BackgroundColor3=Color3.new(1,1,1); CPTitleFix.BackgroundTransparency=0.85; CPTitleFix.BorderSizePixel=0
local CPTitleLbl=Instance.new("TextLabel",CPTitle); CPTitleLbl.Size=UDim2.new(1,-42,1,0); CPTitleLbl.Position=UDim2.new(0,14,0,0)
CPTitleLbl.BackgroundTransparency=1; CPTitleLbl.Text="🎨  Color Picker"; CPTitleLbl.TextColor3=Color3.fromRGB(220,220,240); CPTitleLbl.Font=Enum.Font.GothamBold; CPTitleLbl.TextSize=14; CPTitleLbl.TextXAlignment=Enum.TextXAlignment.Left
local CPCloseBtn=Instance.new("TextButton",CPTitle); CPCloseBtn.Size=UDim2.new(0,24,0,24); CPCloseBtn.Position=UDim2.new(1,-32,0.5,-12)
CPCloseBtn.BackgroundColor3=Color3.fromRGB(220,60,60); CPCloseBtn.Text="✕"; CPCloseBtn.TextColor3=Color3.new(1,1,1); CPCloseBtn.Font=Enum.Font.GothamBold; CPCloseBtn.TextSize=13; CPCloseBtn.AutoButtonColor=false
CPCloseBtn.Visible=false -- Hidden to force Apply & Close
Corner(CPCloseBtn,10)

-- CP Preview box — placed BELOW all sliders at y=198
-- Layout: Title(0-36) H(44-88) S(96-140) V(148-192) Preview(198-244) Presets(248-274) Apply(282-310)
local CPPreview=Instance.new("Frame",CPPanel); CPPreview.Size=UDim2.new(1,-28,0,46); CPPreview.Position=UDim2.new(0,14,0,198)
CPPreview.BackgroundColor3=Color3.new(1,1,1); Corner(CPPreview,16); Stroke(CPPreview,Color3.new(1,1,1),0.6)
local CPPreviewLbl=Instance.new("TextLabel",CPPreview); CPPreviewLbl.Size=UDim2.new(1,0,1,0); CPPreviewLbl.BackgroundTransparency=1
CPPreviewLbl.TextColor3=Color3.new(1,1,1); CPPreviewLbl.Font=Enum.Font.GothamBold; CPPreviewLbl.TextSize=14; CPPreviewLbl.TextStrokeTransparency=0.25

local CP={H=0,S=1,V=1,callback=nil}

local function CPGetColor() return Color3.fromHSV(CP.H,CP.S,CP.V) end

local function CPUpdateUI()
    local col=CPGetColor(); CPPreview.BackgroundColor3=col
    local r,g,b=math.floor(col.R*255),math.floor(col.G*255),math.floor(col.B*255)
    CPPreviewLbl.Text=string.format("RGB(%d, %d, %d)", r,g,b)
    CPPreviewLbl.TextColor3=(col.R*0.299+col.G*0.587+col.B*0.114>0.5) and Color3.new(0,0,0) or Color3.new(1,1,1)
    if CP.callback then CP.callback(col) end
end

-- Helper: create CP slider
local function MakeCPSlider(parent,yPos,label,startVal,onPct)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,-24,0,42); row.Position=UDim2.new(0,12,0,yPos)
    row.BackgroundColor3=Color3.new(1,1,1); row.BackgroundTransparency=0.92; row.BorderSizePixel=0; row.ZIndex=110; Corner(row,12)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(0,18,0,16); lbl.Position=UDim2.new(0,8,0,4)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.new(1,1,1); lbl.Font=Enum.Font.GothamBold; lbl.TextSize=13; lbl.ZIndex=111
    local val=Instance.new("TextLabel",row); val.Size=UDim2.new(0,40,0,16); val.Position=UDim2.new(1,-44,0,4)
    val.BackgroundTransparency=1; val.TextColor3=Colors.PrimaryBlue; val.Font=Enum.Font.GothamBold; val.TextSize=13; val.TextXAlignment=Enum.TextXAlignment.Right; val.ZIndex=111
    local track=Instance.new("Frame",row); track.Size=UDim2.new(1,-16,0,8); track.Position=UDim2.new(0,8,0,26)
    track.BackgroundColor3=Color3.new(1,1,1); track.BackgroundTransparency=0; track.BorderSizePixel=0; track.ZIndex=111; track.ClipsDescendants=false
    Corner(track,4)
    local fill=Instance.new("Frame",track); fill.Size=UDim2.new(startVal,0,1,0); fill.BackgroundColor3=Color3.new(1,1,1); fill.BackgroundTransparency=1; fill.BorderSizePixel=0; Corner(fill,5)
    fill.ZIndex=111
    local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,15,0,15); knob.Position=UDim2.new(startVal,-7.5,0.5,-7.5)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=112; Corner(knob,99)
    Stroke(knob,Colors.PrimaryBlue,1.5)
    local pct=startVal
    local function SetPct(px)
        pct=math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,-7.5,0.5,-7.5)
        onPct(pct,val)
    end
    local sliding=false
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=true; SetPct(i.Position.X); TwSpring(knob,0.3,{Size=UDim2.new(0,17,0,17)}) end end)
    UIS.InputChanged:Connect(function(i) if sliding and i.UserInputType==Enum.UserInputType.MouseMovement then SetPct(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and sliding then sliding=false; Tw(knob,0.15,{Size=UDim2.new(0,15,0,15)}) end end)
    -- Returns an update function so external code can sync the knob
    local function UpdatePos(newPct)
        pct=newPct
        fill.Size=UDim2.new(pct,0,1,0)
        knob.Position=UDim2.new(pct,-7.5,0.5,-7.5)
        onPct(pct,val)
    end
    return fill,val,UpdatePos
end

-- Sliders: H(y=44), S(y=96), V(y=148) — each 44px tall inside 340px panel
local CPHFill,CPHVal,UpdateHSlider=MakeCPSlider(CPPanel,44,"H",CP.H,function(p,vl)
    CP.H=p; vl.Text=math.floor(p*360).."°"; CPUpdateUI()
end)
CPHVal.Text="0°"
-- Rainbow gradient on hue track
local HueG=Instance.new("UIGradient",CPHFill.Parent)
HueG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(1/6,Color3.fromHSV(1/6,1,1)),ColorSequenceKeypoint.new(2/6,Color3.fromHSV(2/6,1,1)),ColorSequenceKeypoint.new(3/6,Color3.fromHSV(3/6,1,1)),ColorSequenceKeypoint.new(4/6,Color3.fromHSV(4/6,1,1)),ColorSequenceKeypoint.new(5/6,Color3.fromHSV(5/6,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))})
local CPHFillReal=Instance.new("Frame",CPHFill.Parent); CPHFillReal.Size=UDim2.new(1,0,1,0); CPHFillReal.BackgroundTransparency=1; CPHFillReal.ZIndex=109

local CPSFill,CPSVal,UpdateSSlider=MakeCPSlider(CPPanel,96,"S",CP.S,function(p,vl)
    CP.S=p; vl.Text=math.floor(p*100).."%"; CPUpdateUI()
end)
CPSVal.Text="100%"
local SatGrad=Instance.new("UIGradient",CPSFill.Parent)
SatGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(CP.H,1,1))}

local CPVFill,CPVVal,UpdateVSlider=MakeCPSlider(CPPanel,148,"V",CP.V,function(p,vl)
    CP.V=p; vl.Text=math.floor(p*100).."%"; CPUpdateUI()
end)
CPVVal.Text="100%"
local ValGrad=Instance.new("UIGradient",CPVFill.Parent)
ValGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.fromHSV(CP.H,CP.S,1))}

-- Update sat/val gradients when H changes (via RunService)
AddConn(RunService.RenderStepped:Connect(function()
    if CPPanel.Visible then
        SatGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(CP.H,1,1))}
        ValGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.fromHSV(CP.H,CP.S,1))}
    end
end))

-- Quick presets row: y=248 (after Preview at y=198+46+4=248)
local PresetRow=Instance.new("Frame",CPPanel); PresetRow.Size=UDim2.new(1,-28,0,26); PresetRow.Position=UDim2.new(0,14,0,248)
PresetRow.BackgroundTransparency=1
local PLyt=Instance.new("UIListLayout",PresetRow); PLyt.FillDirection=Enum.FillDirection.Horizontal; PLyt.Padding=UDim.new(0,5); PLyt.VerticalAlignment=Enum.VerticalAlignment.Center
local PresetColors={Color3.new(1,1,1),Color3.fromRGB(255,60,60),Color3.fromRGB(255,180,50),Color3.fromRGB(50,220,80),Color3.fromRGB(30,161,255),Color3.fromRGB(180,80,255),Color3.fromRGB(255,80,150),Color3.fromRGB(50,255,255),Color3.new(0,0,0)}
for _,pc in ipairs(PresetColors) do
    local pb=Instance.new("TextButton",PresetRow); pb.Size=UDim2.new(0,21,0,21); pb.BackgroundColor3=pc; pb.Text=""; pb.AutoButtonColor=false
    Corner(pb,99); Stroke(pb,Color3.fromRGB(80,80,100),1)
    pb.MouseButton1Click:Connect(function()
        local h,s,v=Color3.toHSV(pc); CP.H=h; CP.S=s; CP.V=v
        UpdateHSlider(h); UpdateSSlider(s); UpdateVSlider(v); CPUpdateUI()
    end)
end

-- Apply button: y=282
local CPApply=Instance.new("TextButton",CPPanel); CPApply.Size=UDim2.new(1,-28,0,28); CPApply.Position=UDim2.new(0,14,0,282)
CPApply.BackgroundColor3=Colors.PrimaryBlue; CPApply.Text="✓  Apply & Close"; CPApply.TextColor3=Color3.new(1,1,1); CPApply.Font=Enum.Font.GothamBold; CPApply.TextSize=13; CPApply.AutoButtonColor=false
Corner(CPApply,13)
CPApply.MouseEnter:Connect(function() Tw(CPApply,0.15,{BackgroundColor3=Colors.AccentGlow}) end)
CPApply.MouseLeave:Connect(function() Tw(CPApply,0.15,{BackgroundColor3=Colors.PrimaryBlue}) end)
CPApply.MouseButton1Down:Connect(function() Tw(CPApply,0.07,{BackgroundColor3=Colors.PrimaryBlue:Lerp(Color3.new(0,0,0),0.2)}) end)
CPApply.MouseButton1Up:Connect(function() Tw(CPApply,0.12,{BackgroundColor3=Colors.AccentGlow}) end)

local function CloseCPicker()
    Tw(CPPanel,0.22,{BackgroundTransparency=1})
    task.delay(0.23,function() CPPanel.Visible=false; CPPanel.BackgroundTransparency=0.45 end)
end

CPApply.MouseButton1Click:Connect(CloseCPicker)

local function OpenCPicker(c3Key, anchorPos, callback)
    local h,s,v=Color3.toHSV(Config[c3Key] or Color3.new(1,1,1))
    CP.H=h; CP.S=s; CP.V=v
    CP.callback=function(col) Config[c3Key]=col; if callback then callback(col) end end
    UpdateHSlider(h); UpdateSSlider(s); UpdateVSlider(v)
    CPUpdateUI()
    local vp=Camera.ViewportSize; local pW,pH=252,320
    local px=math.clamp(anchorPos.X-4, 4, vp.X-pW-4)
    local py=anchorPos.Y+36
    if py+pH > vp.Y-8 then py=anchorPos.Y-pH-8 end
    py=math.clamp(py, 4, vp.Y-pH-4)
    CPPanel.Position=UDim2.new(0,px,0,py)
    CPPanel.Size=UDim2.new(0,pW,0,pH)
    CPPanel.BackgroundTransparency=1; CPPanel.Visible=true
    Tw(CPPanel,0.26,{BackgroundTransparency=0.45})
end

-- [ STATS HUD ]
local StatHUD=Instance.new("TextLabel",ScreenGui); StatHUD.Size=UDim2.new(0,165,0,32); StatHUD.BackgroundColor3=Color3.fromRGB(12,12,18)
StatHUD.BackgroundTransparency=1; StatHUD.TextColor3=Color3.fromRGB(0,240,150); StatHUD.Font=Enum.Font.GothamBold; StatHUD.TextStrokeTransparency=0; StatHUD.TextStrokeColor3 = Color3.new(0,0,0)
StatHUD.TextSize=16; StatHUD.Visible=false; Instance.new("UIPadding",StatHUD).PaddingLeft=UDim.new(0,10)
StatHUD.TextXAlignment=Enum.TextXAlignment.Left

local HUDPositions={TopLeft=UDim2.new(0,10,0,10),TopRight=UDim2.new(1,-175,0,10),BottomLeft=UDim2.new(0,10,1,-42),BottomRight=UDim2.new(1,-175,1,-42)}
local function UpdateHUDPos() StatHUD.Position=HUDPositions[Config.HUDPosition] or HUDPositions.TopLeft end

-- Toast
local Toast=Instance.new("Frame",ScreenGui); Toast.Size=UDim2.new(0,240,0,42); Toast.Position=UDim2.new(0.5,-120,1,10)
Toast.BackgroundColor3=Color3.fromRGB(18,18,28); Toast.ZIndex=200; Toast.Visible=false; Corner(Toast,16)
Stroke(Toast,Colors.PrimaryBlue,1.2)
local ToastLbl=Instance.new("TextLabel",Toast); ToastLbl.Size=UDim2.new(1,0,1,0); ToastLbl.BackgroundTransparency=1; ToastLbl.Font=Enum.Font.GothamBold; ToastLbl.TextSize=15; ToastLbl.ZIndex=201
local function ShowToast(msg,col)
    ToastLbl.Text=msg; ToastLbl.TextColor3=col or Colors.PrimaryBlue; Toast.Visible=true; Toast.Position=UDim2.new(0.5,-120,1,10)
    TwBack(Toast,0.32,{Position=UDim2.new(0.5,-120,1,-54)}); task.delay(2.2,function() Tw(Toast,0.25,{Position=UDim2.new(0.5,-120,1,10)}); task.delay(0.26,function() Toast.Visible=false end) end)
end

-- FOV Circle
local Circle=Drawing.new("Circle"); Circle.Thickness=1.5; Circle.NumSides=64; Circle.Filled=false; Circle.Transparency=0.75; Circle.Color=Colors.PrimaryBlue; Circle.Visible=false
_G._PwyvCircle = Circle  -- stored so re-run can remove it

-- [ SAVE / LOAD ]
local SAVE_FILE="phwyverysad_v8.json"
local function SaveSettings()
    local data={}
    for k,v in pairs(Config) do
        local t=type(v)
        if t=="boolean" or t=="number" or t=="string" then data[k]=v
        elseif typeof(v)=="EnumItem" then data[k]="ENUM:"..tostring(v)
        elseif typeof(v)=="Color3" then data[k]="C3:"..v.R..","..v.G..","..v.B end
    end
    local ok=pcall(function() writefile(SAVE_FILE,HttpService:JSONEncode(data)) end)
    ShowToast(ok and "✅ บันทึกแล้ว!" or "❌ ล้มเหลว",ok and Colors.Green or Colors.Red)
end
local function LoadSettings()
    local ok,content=pcall(readfile,SAVE_FILE); if not ok then ShowToast("❌ ไม่พบไฟล์ save",Colors.Red); return end
    local ok2,data=pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 then ShowToast("❌ ไฟล์เสียหาย",Colors.Red); return end
    for k,v in pairs(data) do
        if Config[k]~=nil then
            if type(v)=="string" and v:sub(1,5)=="ENUM:" then
                pcall(function() local p=v:sub(6):split("."); if #p==3 then Config[k]=Enum[p[2]][p[3]] end end)
            elseif type(v)=="string" and v:sub(1,3)=="C3:" then
                pcall(function() local rgb=v:sub(4):split(","); Config[k]=Color3.new(tonumber(rgb[1]),tonumber(rgb[2]),tonumber(rgb[3])) end)
            elseif type(Config[k])==type(v) then Config[k]=v end
        end
    end
    ShowToast("✅ โหลดแล้ว!",Colors.Green)
end

-- [ APPLY THEME ]
local function ApplyTheme(themeName)
    Config.Theme=themeName; local t=Themes[themeName] or Themes.Dark; CopyTheme(t)
    for _,ref in ipairs(ThemeRefs) do
        if ref.obj and ref.obj.Parent then local val=t[ref.key]; if val then Tw(ref.obj,0.45,{[ref.prop]=val}) end end
    end
    for _,rr in ipairs(AllRowFrames) do
        if rr.frame and rr.frame.Parent then Tw(rr.frame,0.45,{BackgroundColor3=t.Row}); Tw(rr.stroke,0.45,{Color=t.Stroke}) end
    end
    for _,tab in pairs(Tabs) do if tab.Btn.BackgroundTransparency<0.5 then Tw(tab.Btn,0.45,{BackgroundColor3=t.Primary}) end end
    Circle.Color=t.Primary
    Tw(StatHUD,0.45,{TextColor3=t.Primary}); Tw(TitleLine,0.45,{BackgroundColor3=t.Primary}); Tw(DDStroke,0.45,{Color=t.Primary})
    Tw(CPApply,0.45,{BackgroundColor3=t.Primary}); Tw(CPPanelStroke,0.45,{Color=t.Primary})
end

-- [ WINDOW CONTROLS ]
local function RestoreAll()
    local lpc=LocalPlayer.Character
    if lpc then
        local h=lpc:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed=16; h.UseJumpPower=true; h.JumpPower=50; h.MaxHealth=100; h.Health=100; h.BreakJointsOnDeath=true end); pcall(function() h.RequiresNeck=true; h.PlatformStand=false end) end
        pcall(function() lpc.Animate.Disabled=false end)
    end
    if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG=nil end; if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV=nil end
    if lpc then local h=lpc:FindFirstChildOfClass("Humanoid"); if h then pcall(function() Camera.CameraSubject=h end) end end
    pcall(function() Camera.FieldOfView=70 end); pcall(function() LocalPlayer.CameraMaxZoomDistance=400 end)
    for p,o in pairs(XrayCache_M) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=o end end) end
    for p,o in pairs(XrayCache_P) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=o end end) end
    for char,sz in pairs(HitboxOriginalSizes) do pcall(function() local hrp=char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.Size=sz; hrp.Transparency=1; hrp.Material=Enum.Material.SmoothPlastic; hrp.CanCollide=true end end) end
    if SafeTP_Conn then SafeTP_Conn:Disconnect(); SafeTP_Conn=nil end
    pcall(function() Lighting.GlobalShadows=true end); pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end)
    if ESP_Folder and ESP_Folder.Parent then pcall(function() ESP_Folder:Destroy() end) end
end

local function FullUnload()
    State.Running=false; RestoreAll(); Circle.Visible=false
    for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _,cn in pairs({WS_Loop,JP_Loop,NC_Conn,IJ_Conn,GM_Conn,AFK_Conn,FPS_DescConn,SafeTP_Conn}) do if cn then pcall(function() cn:Disconnect() end) end end
    Tw(MainFrame,0.22,{Size=UDim2.new(0,W*0.45,0,H*0.45),Position=UDim2.new(0.5,-W*0.225,0.5,-H*0.225)})
    task.delay(0.23,function() pcall(function() FloatingLayer:Destroy() end); pcall(function() CPGui:Destroy() end); pcall(function() ScreenGui:Destroy() end) end)
end

DotRed.MouseButton1Click:Connect(FullUnload)
DotYellow.MouseButton1Click:Connect(function()
    if State.isMaximized then return end; State.isMinimized=not State.isMinimized
    if State.isMinimized then State.preHideSize=MainFrame.Size; Tw(MainFrame,0.28,{Size=UDim2.new(0,State.preHideSize.X.Offset,0,46)}); task.delay(0.1,function() Body.Visible=false end)
    else Body.Visible=true; TwBack(MainFrame,0.35,{Size=State.preHideSize or State.originalSize}) end
end)
DotGreen.MouseButton1Click:Connect(function()
    if State.isMinimized or State.isHidden then return end; State.isMaximized=not State.isMaximized
    if State.isMaximized then State.originalPos=MainFrame.Position; State.originalSize=MainFrame.Size; Tw(MainFrame,0.35,{Size=UDim2.new(0,Camera.ViewportSize.X,0,Camera.ViewportSize.Y),Position=UDim2.new(0,0,0,0)}); MainCorner.CornerRadius=UDim.new(0,0)
    else TwBack(MainFrame,0.35,{Size=State.originalSize,Position=State.originalPos}); task.delay(0.1,function() MainCorner.CornerRadius=UDim.new(0,12) end) end
end)
HideBtn.MouseButton1Click:Connect(function()
    if State.isMaximized then return end; State.isHidden=not State.isHidden
    if State.isHidden then HideBtn.Text="แสดง"; State.preHideSize=MainFrame.Size; Tw(MainFrame,0.25,{Size=UDim2.new(0,State.preHideSize.X.Offset,0,46)}); task.delay(0.12,function() Body.Visible=false end)
    else HideBtn.Text="ซ่อน"; Body.Visible=true; TwBack(MainFrame,0.3,{Size=State.preHideSize or State.originalSize}) end
end)
UIS.InputBegan:Connect(function(input,gp)
    if gp then return end
    if State.Binding then
        if input.UserInputType==Enum.UserInputType.Keyboard then State.Binding("Keyboard",input.KeyCode); State.Binding=nil
        elseif input.UserInputType==Enum.UserInputType.MouseButton1 then State.Binding("Mouse",1); State.Binding=nil
        elseif input.UserInputType==Enum.UserInputType.MouseButton2 then State.Binding("Mouse",2); State.Binding=nil end
    end
end)

-- [ UI LIBRARY ]
local function SwitchTab(targetTab)
    for _,t in pairs(Tabs) do
        Tw(t.Btn,0.2,{BackgroundTransparency=1,TextColor3=Color3.fromRGB(145,145,165)}); t.Btn.Font=Enum.Font.GothamMedium; t.Page.Visible=false
        local ind=t.Btn:FindFirstChild("Ind"); if ind then Tw(ind,0.2,{BackgroundTransparency=1}) end
    end
    currentTab=targetTab.Btn; Tw(targetTab.Btn,0.2,{BackgroundColor3=Colors.PrimaryBlue,BackgroundTransparency=0,TextColor3=Colors.TextMain})
    targetTab.Btn.Font=Enum.Font.GothamBold; targetTab.Page.Visible=true
    local ind=targetTab.Btn:FindFirstChild("Ind"); if ind then Tw(ind,0.2,{BackgroundTransparency=0}) end
end

local function BuildTab(name)
    local TabBtn=Instance.new("TextButton",MenuList)
    TabBtn.Size=UDim2.new(1,-16,0,38); TabBtn.BackgroundColor3=Colors.PrimaryBlue; TabBtn.BackgroundTransparency=1
    TabBtn.Text="  "..name; TabBtn.TextColor3=Color3.fromRGB(145,145,165); TabBtn.Font=Enum.Font.GothamMedium
    TabBtn.TextSize=14; TabBtn.TextXAlignment=Enum.TextXAlignment.Left; TabBtn.AutoButtonColor=false
    TabBtn.TextTruncate=Enum.TextTruncate.AtEnd
    Corner(TabBtn,12)
    local Ind=Instance.new("Frame",TabBtn); Ind.Name="Ind"; Ind.Size=UDim2.new(0,3,0,20); Ind.Position=UDim2.new(0,0,0.5,-10)
    Ind.BackgroundColor3=Colors.PrimaryBlue; Ind.BackgroundTransparency=1; Ind.BorderSizePixel=0; Corner(Ind,3)
    TabBtn.MouseEnter:Connect(function() if currentTab~=TabBtn then Tw(TabBtn,0.18,{BackgroundColor3=Color3.fromRGB(38,38,52),BackgroundTransparency=0,TextColor3=Colors.TextMain}) end end)
    TabBtn.MouseLeave:Connect(function() if currentTab~=TabBtn then Tw(TabBtn,0.18,{BackgroundTransparency=1,TextColor3=Color3.fromRGB(145,145,165)}) end end)

    local TabPage=Instance.new("ScrollingFrame",MainContent)
    TabPage.Size=UDim2.new(1,0,1,0); TabPage.BackgroundTransparency=1; TabPage.ScrollBarThickness=3
    TabPage.ScrollBarImageColor3=Colors.PrimaryBlue; TabPage.BorderSizePixel=0; TabPage.Visible=false
    local PL=Instance.new("UIListLayout",TabPage); PL.Padding=UDim.new(0,8)
    local Pd=Instance.new("UIPadding",TabPage); Pd.PaddingTop=UDim.new(0,22); Pd.PaddingLeft=UDim.new(0,24); Pd.PaddingRight=UDim.new(0,24); Pd.PaddingBottom=UDim.new(0,36)

    local tabEntry={Btn=TabBtn,Page=TabPage}
    TabBtn.MouseButton1Click:Connect(function() SwitchTab(tabEntry) end)
    if not currentTab then
        currentTab=TabBtn; TabBtn.BackgroundTransparency=0; TabBtn.TextColor3=Colors.TextMain; TabBtn.Font=Enum.Font.GothamBold; TabPage.Visible=true; Ind.BackgroundTransparency=0
    end
    table.insert(Tabs,tabEntry)

    local E={}

    function E:Section(title,sub)
        local hasDesc = sub and sub~=""
        local S=Instance.new("Frame",TabPage)
        S.Size=UDim2.new(1,0,0,hasDesc and 58 or 42)
        S.BackgroundColor3=Color3.fromRGB(26,28,42); S.BorderSizePixel=0
        Corner(S,12)
        local SS=Stroke(S,Color3.fromRGB(50,54,80),1.4)
        -- Accent bar — INSIDE the frame (x=0) so it is never clipped
        local AccBar=Instance.new("Frame",S)
        AccBar.Size=UDim2.new(0,4,1,-14); AccBar.Position=UDim2.new(0,0,0,7)
        AccBar.BackgroundColor3=Colors.PrimaryBlue; AccBar.BorderSizePixel=0; Corner(AccBar,4)
        -- Gradient on accent bar (top = bright, bottom = dim)
        local Grad=Instance.new("UIGradient",AccBar)
        Grad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,140,200))}
        Grad.Rotation=90
        -- Icon dot (small circle)
        local IconDot=Instance.new("Frame",S)
        IconDot.Size=UDim2.new(0,7,0,7); IconDot.Position=UDim2.new(0,16,0.5,-3)
        IconDot.BackgroundColor3=Colors.PrimaryBlue; IconDot.BorderSizePixel=0; Corner(IconDot,99)
        -- Title label
        local T1=Instance.new("TextLabel",S)
        T1.Size=UDim2.new(1,-32,0,22); T1.Position=UDim2.new(0,28,0,hasDesc and 7 or 10)
        T1.BackgroundTransparency=1; T1.Text=title
        T1.TextColor3=Color3.fromRGB(235,235,250); T1.Font=Enum.Font.GothamBold
        T1.TextSize=15; T1.TextXAlignment=Enum.TextXAlignment.Left
        T1.TextTruncate=Enum.TextTruncate.AtEnd
        if hasDesc then
            local T2=Instance.new("TextLabel",S)
            T2.Size=UDim2.new(1,-32,0,14); T2.Position=UDim2.new(0,28,0,32)
            T2.BackgroundTransparency=1; T2.Text=sub
            T2.TextColor3=Colors.TextSub; T2.Font=Enum.Font.Gotham
            T2.TextSize=12; T2.TextXAlignment=Enum.TextXAlignment.Left
            T2.TextTruncate=Enum.TextTruncate.AtEnd
        end
        -- Register accent bar for theme updates
        table.insert(ThemeRefs,{obj=AccBar,key="Primary",prop="BackgroundColor3"})
        table.insert(ThemeRefs,{obj=IconDot,key="Primary",prop="BackgroundColor3"})
    end

    local function Row(t,st)
        local R=Instance.new("Frame",TabPage); R.Size=UDim2.new(1,0,0,60); R.BackgroundColor3=Colors.RowBg
        Corner(R,8); local RS=Stroke(R,Color3.fromRGB(42,42,58),1)
        local Pd=Instance.new("UIPadding",R); Pd.PaddingLeft=UDim.new(0,16); Pd.PaddingRight=UDim.new(0,16)
        local Acc=Instance.new("Frame",R); Acc.Size=UDim2.new(0,3,0,28); Acc.Position=UDim2.new(0,-3,0.5,-14)
        Acc.BackgroundColor3=Colors.PrimaryBlue; Acc.BackgroundTransparency=1; Acc.BorderSizePixel=0; Corner(Acc,3)
        local T1=Instance.new("TextLabel",R); T1.Size=UDim2.new(0.52,0,0,24); T1.Position=UDim2.new(0,0,0,10)
        T1.BackgroundTransparency=1; T1.Text=t; T1.TextColor3=Color3.fromRGB(228,228,238); T1.Font=Enum.Font.GothamMedium
        T1.TextSize=14; T1.TextXAlignment=Enum.TextXAlignment.Left; T1.TextTruncate=Enum.TextTruncate.AtEnd
        local T2=Instance.new("TextLabel",R); T2.Size=UDim2.new(0.7,0,0,16); T2.Position=UDim2.new(0,0,0,33)
        T2.BackgroundTransparency=1; T2.Text=st; T2.TextColor3=Colors.TextSub; T2.Font=Enum.Font.Gotham
        T2.TextSize=12; T2.TextXAlignment=Enum.TextXAlignment.Left; T2.TextTruncate=Enum.TextTruncate.AtEnd
        local C=Instance.new("Frame",R); C.Size=UDim2.new(0.48,0,1,0); C.Position=UDim2.new(0.52,0,0,0); C.BackgroundTransparency=1
        local L=Instance.new("UIListLayout",C); L.FillDirection=Enum.FillDirection.Horizontal; L.HorizontalAlignment=Enum.HorizontalAlignment.Right; L.VerticalAlignment=Enum.VerticalAlignment.Center; L.Padding=UDim.new(0,8)
        R.MouseEnter:Connect(function() Tw(R,0.18,{BackgroundColor3=Colors.RowHover}); Tw(RS,0.18,{Color=Color3.fromRGB(60,60,80)}); Tw(Acc,0.18,{BackgroundTransparency=0}) end)
        R.MouseLeave:Connect(function() Tw(R,0.18,{BackgroundColor3=Colors.RowBg}); Tw(RS,0.18,{Color=Color3.fromRGB(42,42,58)}); Tw(Acc,0.18,{BackgroundTransparency=1}) end)
        table.insert(AllRows,{UI=R,T=string.lower(t),ST=string.lower(st)})
        table.insert(AllRowFrames,{frame=R,stroke=RS})
        return R,C
    end

    -- Toggle
    function E:Toggle(t,st,key,onChange,customText)
        local _,C=Row(t,st); local isOn=Config[key]
        local Stat=Instance.new("TextLabel",C); Stat.Size=UDim2.new(0,30,1,0); Stat.BackgroundTransparency=1
        Stat.Text=isOn and(customText and customText[1] or "On")or(customText and customText[2] or "Off")
        Stat.TextColor3=isOn and Colors.Green or Color3.fromRGB(120,120,140); Stat.Font=Enum.Font.GothamBold; Stat.TextSize=13; Stat.TextXAlignment=Enum.TextXAlignment.Right
        local Track=Instance.new("TextButton",C); Track.Size=UDim2.new(0,46,0,26); Track.Text=""
        Track.BackgroundColor3=isOn and Colors.PrimaryBlue or Colors.Toggle_Off; Track.AutoButtonColor=false; Corner(Track,99)
        local TS=Stroke(Track,isOn and Colors.AccentGlow or Color3.fromRGB(70,70,90),0.8)
        local Circ=Instance.new("Frame",Track); Circ.Size=UDim2.new(0,20,0,20)
        Circ.Position=isOn and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)
        Circ.BackgroundColor3=Color3.new(1,1,1); Corner(Circ,99)
        local CG=Instance.new("Frame",Circ); CG.Size=UDim2.new(0,7,0,7); CG.Position=UDim2.new(0.5,-3.5,0.5,-3.5)
        CG.BackgroundColor3=Colors.PrimaryBlue; CG.BackgroundTransparency=isOn and 0.2 or 1; CG.BorderSizePixel=0; Corner(CG,99)
        Track.MouseEnter:Connect(function() Tw(TS,0.2,{Thickness=1.3,Color=Config[key] and Colors.PrimaryBlue or Color3.fromRGB(100,100,120)}) end)
        Track.MouseLeave:Connect(function() Tw(TS,0.2,{Thickness=0.8,Color=Config[key] and Colors.AccentGlow or Color3.fromRGB(70,70,90)}) end)
        Track.MouseButton1Click:Connect(function()
            Config[key]=not Config[key]; local on=Config[key]
            Stat.Text=on and(customText and customText[1] or "On")or(customText and customText[2] or "Off")
            Tw(Stat,0.2,{TextColor3=on and Colors.Green or Color3.fromRGB(120,120,140)})
            Tw(Track,0.25,{BackgroundColor3=on and Colors.PrimaryBlue or Colors.Toggle_Off})
            Tw(TS,0.25,{Color=on and Colors.AccentGlow or Color3.fromRGB(70,70,90),Thickness=0.8})
            
            -- Stretch Animation
            Tw(Circ,0.15,{Size=UDim2.new(0,26,0,20)})
            task.delay(0.12, function() TwSpring(Circ,0.35,{Size=UDim2.new(0,20,0,20),Position=on and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)}) end)
            
            Tw(CG,0.25,{BackgroundTransparency=on and 0.2 or 1})
            if onChange then onChange(on) end
        end)
        return Track
    end

    -- Slider
    function E:Slider(t,st,key,minV,maxV,suffix,isDecimal,onChange)
        local _,C=Row(t,st)
        local W2=Instance.new("Frame",C); W2.Size=UDim2.new(0,138,0,44); W2.BackgroundTransparency=1
        local VLbl=Instance.new("TextLabel",W2); VLbl.Size=UDim2.new(1,0,0,16); VLbl.BackgroundTransparency=1
        VLbl.Text=tostring(Config[key])..(suffix or ""); VLbl.TextColor3=Colors.PrimaryBlue; VLbl.Font=Enum.Font.GothamBold; VLbl.TextSize=14; VLbl.TextXAlignment=Enum.TextXAlignment.Right
        local TrackBg=Instance.new("Frame",W2); TrackBg.Size=UDim2.new(1,0,0,10); TrackBg.Position=UDim2.new(0,0,0,24)
        TrackBg.BackgroundColor3=Color3.fromRGB(32,32,48); TrackBg.BorderSizePixel=0; Corner(TrackBg,6)
        local pct0=math.clamp((Config[key]-minV)/(maxV-minV),0,1)
        local Fill=Instance.new("Frame",TrackBg); Fill.Size=UDim2.new(pct0,0,1,0); Fill.BackgroundColor3=Colors.PrimaryBlue; Fill.BorderSizePixel=0; Corner(Fill,6)
        local Knob=Instance.new("Frame",TrackBg); Knob.Size=UDim2.new(0,16,0,16); Knob.Position=UDim2.new(pct0,-8,0.5,-8)
        Knob.BackgroundColor3=Color3.new(1,1,1); Knob.BorderSizePixel=0; Knob.ZIndex=5; Corner(Knob,99)
        local KS=Stroke(Knob,Colors.PrimaryBlue,1.2)
        TrackBg.MouseEnter:Connect(function() Tw(Knob,0.15,{Size=UDim2.new(0,20,0,20),Position=UDim2.new(pct0,-10,0.5,-10)}); Tw(KS,0.15,{Thickness=2}); Tw(Fill,0.15,{BackgroundColor3=Colors.AccentGlow}) end)
        TrackBg.MouseLeave:Connect(function() Tw(Knob,0.15,{Size=UDim2.new(0,16,0,16),Position=UDim2.new(pct0,-8,0.5,-8)}); Tw(KS,0.15,{Thickness=1.2}); Tw(Fill,0.15,{BackgroundColor3=Colors.PrimaryBlue}) end)
        local slid=false
        local function SetVal(px)
            local p=math.clamp((px-TrackBg.AbsolutePosition.X)/TrackBg.AbsoluteSize.X,0,1)
            local val=minV+p*(maxV-minV); val=isDecimal and (math.floor(val*100)/100) or math.floor(val)
            Fill.Size=UDim2.new(p,0,1,0); Knob.Position=UDim2.new(p,Knob.Size.X.Offset/-2,0.5,Knob.Size.Y.Offset/-2); pct0=p
            Config[key]=val; VLbl.Text=tostring(val)..(suffix or ""); if onChange then onChange(val) end
        end
        TrackBg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then slid=true; SetVal(i.Position.X); TwSpring(Knob,0.3,{Size=UDim2.new(0,22,0,22),Position=UDim2.new(pct0,-11,0.5,-11)}) end end)
        UIS.InputChanged:Connect(function(i) if slid and i.UserInputType==Enum.UserInputType.MouseMovement then SetVal(i.Position.X) end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and slid then slid=false; Tw(Knob,0.15,{Size=UDim2.new(0,16,0,16),Position=UDim2.new(pct0,-8,0.5,-8)}) end end)
        VLbl.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                local TB=Instance.new("TextBox",ScreenGui); TB.ZIndex=999; TB.Size=UDim2.new(0,90,0,28)
                TB.Position=UDim2.new(0,VLbl.AbsolutePosition.X-20,0,VLbl.AbsolutePosition.Y-34)
                TB.BackgroundColor3=Color3.fromRGB(24,24,36); TB.TextColor3=Colors.PrimaryBlue; TB.Font=Enum.Font.GothamBold; TB.TextSize=15; TB.Text=tostring(Config[key]); Corner(TB,12); Stroke(TB,Colors.PrimaryBlue,1.2); TB:CaptureFocus()
                TB.FocusLost:Connect(function()
                    local v=tonumber(TB.Text); if v then v=math.clamp(isDecimal and (math.floor(v*100)/100) or math.floor(v),minV,maxV); Config[key]=v; local p=(v-minV)/(maxV-minV); Fill.Size=UDim2.new(p,0,1,0); Knob.Position=UDim2.new(p,-7,0.5,-7); pct0=p; VLbl.Text=tostring(v)..(suffix or ""); if onChange then onChange(v) end end; TB:Destroy()
                end)
            end
        end)
    end

    -- Dropdown (wider for long names)
    function E:Dropdown(t,st,key,opts,hasPlayerSearch,onChange)
        local _,C=Row(t,st); local SearchBox,SS2=nil,nil
        if hasPlayerSearch then
            local SF=Instance.new("Frame",C); SF.Size=UDim2.new(0,132,0,30); SF.BackgroundColor3=Colors.DarkElement; Corner(SF,13); SS2=Stroke(SF,Colors.Stroke,1)
            SearchBox=Instance.new("TextBox",SF); SearchBox.Size=UDim2.new(1,-30,1,0); SearchBox.BackgroundTransparency=1
            SearchBox.PlaceholderText="ชื่อผู้เล่น..."; SearchBox.PlaceholderColor3=Color3.fromRGB(80,80,100)
            SearchBox.Text=""; SearchBox.TextColor3=Colors.TextMain; SearchBox.Font=Enum.Font.Gotham; SearchBox.TextSize=13
            SearchBox.TextXAlignment=Enum.TextXAlignment.Left; Instance.new("UIPadding",SearchBox).PaddingLeft=UDim.new(0,6)
            local SI=Instance.new("TextLabel",SF); SI.Size=UDim2.new(0,26,1,0); SI.Position=UDim2.new(1,-28,0,0); SI.BackgroundTransparency=1; SI.Text="🔍"; SI.TextColor3=Color3.fromRGB(130,130,150); SI.TextSize=13
            SearchBox.Focused:Connect(function() Tw(SS2,0.2,{Color=Colors.PrimaryBlue,Thickness=1.5}) end)
            SearchBox.FocusLost:Connect(function() Tw(SS2,0.2,{Color=Colors.Stroke,Thickness=1}) end)
        end
        local B=Instance.new("TextButton",C); B.Size=UDim2.new(0,135,0,30); B.BackgroundColor3=Colors.DarkElement; B.Text=""; B.AutoButtonColor=false; Corner(B,8); local BStk=Stroke(B,Colors.Stroke,1)
        local BLbl=Instance.new("TextLabel",B); BLbl.Size=UDim2.new(1,-24,1,0); BLbl.Position=UDim2.new(0,9,0,0)
        BLbl.BackgroundTransparency=1; BLbl.Text=tostring(Config[key]); BLbl.TextColor3=Colors.TextMain; BLbl.Font=Enum.Font.GothamBold; BLbl.TextSize=13; BLbl.TextXAlignment=Enum.TextXAlignment.Left; BLbl.TextTruncate=Enum.TextTruncate.AtEnd
        local BArr=Instance.new("TextLabel",B); BArr.Size=UDim2.new(0,20,1,0); BArr.Position=UDim2.new(1,-22,0,0); BArr.BackgroundTransparency=1; BArr.Text="▾"; BArr.TextColor3=Colors.PrimaryBlue; BArr.TextSize=15
        B.MouseEnter:Connect(function() Tw(B,0.15,{BackgroundColor3=Color3.fromRGB(58,58,75)}); Tw(BStk,0.15,{Color=Colors.PrimaryBlue,Thickness=1.5}); Tw(BArr,0.15,{Position=UDim2.new(1,-22,0,2)}) end)
        B.MouseLeave:Connect(function() if not DDContainer.Visible then Tw(B,0.15,{BackgroundColor3=Colors.DarkElement}); Tw(BStk,0.15,{Color=Colors.Stroke,Thickness=1}); Tw(BArr,0.15,{Position=UDim2.new(1,-22,0,0)}) end end)
        local liveOpts=opts
        local function Populate(filter)
            for _,v in ipairs(DDScroll:GetChildren()) do if v:IsA("TextButton") or v:IsA("Frame") then v:Destroy() end end
            local count=0
            for _,opt in ipairs(liveOpts) do
                local f=filter and filter~="" and not string.find(string.lower(tostring(opt)),string.lower(filter))
                if not f then
                    count=count+1
                    local ob=Instance.new("TextButton",DDScroll); ob.Size=UDim2.new(1,0,0,33)
                    ob.BackgroundColor3=Color3.fromRGB(25,25,36); ob.BackgroundTransparency=1; ob.Text=""; ob.AutoButtonColor=false; ob.ZIndex=102; Corner(ob,12)
                    local oL=Instance.new("TextLabel",ob); oL.Size=UDim2.new(1,-28,1,0); oL.Position=UDim2.new(0,10,0,0)
                    oL.BackgroundTransparency=1; oL.Text=tostring(opt); oL.Font=Enum.Font.GothamMedium; oL.TextSize=13
                    oL.TextXAlignment=Enum.TextXAlignment.Left; oL.ZIndex=103; oL.TextTruncate=Enum.TextTruncate.AtEnd
                    oL.TextColor3=tostring(opt)==tostring(Config[key]) and Colors.PrimaryBlue or Color3.fromRGB(205,205,220)
                    if tostring(opt)==tostring(Config[key]) then
                        oL.Font=Enum.Font.GothamBold
                        local ck=Instance.new("TextLabel",ob); ck.Size=UDim2.new(0,22,1,0); ck.Position=UDim2.new(1,-24,0,0); ck.BackgroundTransparency=1; ck.Text="✓"; ck.TextColor3=Colors.PrimaryBlue; ck.TextSize=14; ck.ZIndex=103
                    end
                    ob.MouseEnter:Connect(function() Tw(ob,0.1,{BackgroundColor3=Color3.fromRGB(32,72,118),BackgroundTransparency=0}); Tw(oL,0.1,{TextColor3=Colors.TextMain,TextSize=14}) end)
                    ob.MouseLeave:Connect(function() Tw(ob,0.1,{BackgroundTransparency=1}); if tostring(opt)~=tostring(Config[key]) then Tw(oL,0.1,{TextColor3=Color3.fromRGB(205,205,220),TextSize=13}) else Tw(oL,0.1,{TextSize=13}) end end)
                    ob.MouseButton1Click:Connect(function()
                        Config[key]=opt; BLbl.Text=tostring(opt); HideDD(); if onChange then onChange(opt) end
                    end)
                end
            end
            DDScroll.CanvasSize=UDim2.new(0,0,0,count*35+4); DDTargetH=math.min(count*35+8,240)
        end
        local function OpenDD()
            if hasPlayerSearch then liveOpts={"-"}; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(liveOpts,p.Name) end end end
            Populate(SearchBox and SearchBox.Text or nil)
            local bp=B.AbsolutePosition; DDContainer.Position=UDim2.new(0,bp.X-2,0,bp.Y+34); ShowDD(); Tw(BArr,0.2,{Rotation=180})
        end
        B.MouseButton1Click:Connect(function() if DDContainer.Visible then HideDD(); Tw(BArr,0.2,{Rotation=0}) else OpenDD() end end)
        AddConn(RunService.RenderStepped:Connect(function() if not DDContainer.Visible and BArr.Rotation~=0 then BArr.Rotation=0 end end))
        if SearchBox then SearchBox.Changed:Connect(function(p2) if p2=="Text" and DDContainer.Visible then Populate(SearchBox.Text) end end); SearchBox.Focused:Connect(function() if not DDContainer.Visible then OpenDD() end end) end
        return B
    end

    -- ColorPicker (new element type)
    function E:ColorPicker(t,st,c3Key,onChange)
        local R,C=Row(t,st)
        -- Swatch button showing current color
        local SwatchFrame=Instance.new("Frame",C); SwatchFrame.Size=UDim2.new(0,60,0,30); SwatchFrame.BackgroundColor3=Colors.DarkElement; Corner(SwatchFrame,8); Stroke(SwatchFrame,Colors.Stroke,1)
        local SwatchPreview=Instance.new("Frame",SwatchFrame); SwatchPreview.Size=UDim2.new(0,26,1,-8); SwatchPreview.Position=UDim2.new(0,4,0,4)
        SwatchPreview.BackgroundColor3=Config[c3Key] or Color3.new(1,1,1); Corner(SwatchPreview,10)
        local SwatchLbl=Instance.new("TextLabel",SwatchFrame); SwatchLbl.Size=UDim2.new(1,-36,1,0); SwatchLbl.Position=UDim2.new(0,34,0,0)
        SwatchLbl.BackgroundTransparency=1; SwatchLbl.Text="🎨"; SwatchLbl.TextSize=15; SwatchLbl.TextColor3=Colors.TextSub
        local SwatchBtn=Instance.new("TextButton",SwatchFrame); SwatchBtn.Size=UDim2.new(1,0,1,0); SwatchBtn.BackgroundTransparency=1; SwatchBtn.Text=""
        SwatchBtn.MouseEnter:Connect(function() Tw(SwatchFrame,0.15,{BackgroundColor3=Color3.fromRGB(58,58,75)}) end)
        SwatchBtn.MouseLeave:Connect(function() Tw(SwatchFrame,0.15,{BackgroundColor3=Colors.DarkElement}) end)
        SwatchBtn.MouseButton1Click:Connect(function()
            local ap=SwatchFrame.AbsolutePosition
            OpenCPicker(c3Key, ap, function(col)
                SwatchPreview.BackgroundColor3=col
                if onChange then onChange(col) end
            end)
        end)
        -- Keep swatch in sync
        AddConn(RunService.RenderStepped:Connect(function()
            if Config[c3Key] then SwatchPreview.BackgroundColor3=Config[c3Key] end
        end))
        return SwatchBtn
    end

    -- Bind
    function E:Bind(t,st,typeKey,valKey)
        local _,C=Row(t,st)
        local function GetLbl() if Config[typeKey]=="Mouse" then return "MB"..(Config[valKey] or 2) end; return Config[valKey] and Config[valKey].Name or "กด..." end
        local B=Instance.new("TextButton",C); B.Size=UDim2.new(0,90,0,30); B.BackgroundColor3=Colors.DarkElement; B.Text=GetLbl()
        B.TextColor3=Colors.TextMain; B.Font=Enum.Font.GothamBold; B.TextSize=13; B.AutoButtonColor=false; Corner(B,13); local BS=Stroke(B,Colors.Stroke,1)
        B.TextTruncate=Enum.TextTruncate.AtEnd
        B.MouseEnter:Connect(function() Tw(B,0.15,{BackgroundColor3=Color3.fromRGB(58,58,75)}); Tw(BS,0.15,{Color=Colors.PrimaryBlue}) end)
        B.MouseLeave:Connect(function() if not State.Binding then Tw(B,0.15,{BackgroundColor3=Colors.DarkElement}); Tw(BS,0.15,{Color=Colors.Stroke}) end end)
        B.MouseButton1Click:Connect(function()
            B.Text="[ กดปุ่ม ]"; Tw(B,0.15,{BackgroundColor3=Colors.PrimaryBlue})
            State.Binding=function(io,k) Config[typeKey]=io; Config[valKey]=k; B.Text=io=="Mouse" and ("MB"..tostring(k)) or k.Name; Tw(B,0.2,{BackgroundColor3=Colors.DarkElement}); Tw(BS,0.2,{Color=Colors.Stroke}) end
        end)
        return B
    end

    -- Button
    function E:Button(label,col,onClick)
        local Btn=Instance.new("TextButton",TabPage); Btn.Size=UDim2.new(1,0,0,42); Btn.BackgroundColor3=col or Colors.PrimaryBlue
        Btn.Text=label; Btn.TextColor3=Colors.TextMain; Btn.Font=Enum.Font.GothamBold; Btn.TextSize=15; Btn.AutoButtonColor=false; Corner(Btn,16)
        Btn.MouseEnter:Connect(function() Tw(Btn,0.15,{BackgroundColor3=(col or Colors.PrimaryBlue):Lerp(Color3.new(1,1,1),0.14)}) end)
        Btn.MouseLeave:Connect(function() Tw(Btn,0.15,{BackgroundColor3=col or Colors.PrimaryBlue}) end)
        Btn.MouseButton1Down:Connect(function() Tw(Btn,0.08,{BackgroundColor3=(col or Colors.PrimaryBlue):Lerp(Color3.new(0,0,0),0.18)}) end)
        Btn.MouseButton1Up:Connect(function() Tw(Btn,0.18,{BackgroundColor3=col or Colors.PrimaryBlue}) end)
        Btn.MouseButton1Click:Connect(function() if onClick then onClick() end end)
        return Btn
    end

    PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TabPage.CanvasSize=UDim2.new(0,0,0,PL.AbsoluteContentSize.Y+40) end)
    return E
end

-- [ GLOBAL SEARCH ]
GlobalSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local txt=string.lower(GlobalSearchBox.Text); local fm=nil
    for _,rd in ipairs(AllRows) do
        local vis=(txt=="" or string.find(rd.T,txt) or string.find(rd.ST,txt)); rd.UI.Visible=vis
        if vis and not fm then fm=rd.UI.Parent end
    end
    if txt~="" and fm then for _,tab in pairs(Tabs) do if tab.Page==fm then SwitchTab(tab); break end end end
end)

-- [ BACKEND HELPERS ]
local function GetESPColor(c3val, hpPct)
    -- c3val is now always a Color3
    if hpPct and typeof(c3val)=="Color3" and c3val==Color3.new(0,0,0) then
        hpPct=hpPct or 100
        if hpPct>=70 then return Color3.fromRGB(50,255,50) elseif hpPct>=35 then return Color3.fromRGB(255,200,50) else return Color3.fromRGB(255,50,50) end
    end
    return c3val or Color3.new(1,1,1)
end

ESP_Folder=Instance.new("Folder",CoreGui); ESP_Folder.Name="NexusESP_Folder"
local function GetESP(char)
    if ESP_Cache[char] then return ESP_Cache[char] end
    local bGui=Instance.new("BillboardGui",ESP_Folder); bGui.AlwaysOnTop=true; bGui.Size=UDim2.new(0,220,0,75); bGui.StudsOffset=Vector3.new(0,4,0); bGui.Enabled=false
    local lbl=Instance.new("TextLabel",bGui); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold; lbl.TextStrokeTransparency=0.3; lbl.TextStrokeColor3=Color3.new(0,0,0); lbl.TextWrapped=true
    local hlt=Instance.new("Highlight",ESP_Folder); hlt.OutlineTransparency=0.1; hlt.Enabled=false
    ESP_Cache[char]={Gui=bGui,Label=lbl,Highlight=hlt}; return ESP_Cache[char]
end
local function ClearESP(char)
    if not ESP_Cache[char] then return end
    pcall(function() ESP_Cache[char].Gui:Destroy() end); pcall(function() ESP_Cache[char].Highlight:Destroy() end); ESP_Cache[char]=nil
end
local function IsVisible(tp)
    if not Config.WallCheck then return true end
    local lpc=LocalPlayer.Character; if not lpc then return true end
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={lpc,Camera}
    local res=workspace:Raycast(Camera.CFrame.Position,tp.Position-Camera.CFrame.Position,params)
    if res then return res.Instance:IsDescendantOf(tp.Parent) end; return true
end
local function CacheNPC(obj)
    if not obj:IsA("Humanoid") then return end; local char=obj.Parent
    if char and char:IsA("Model") and char~=LocalPlayer.Character then
        task.delay(0.1,function()
            if char.Parent and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and not Players:GetPlayerFromCharacter(char) then
                NPCCache[char]=true
            end
        end)
    end
end
task.spawn(function() for i,v in ipairs(workspace:GetDescendants()) do CacheNPC(v); if i%2000==0 then task.wait() end end end)
AddConn(workspace.DescendantAdded:Connect(CacheNPC))

-- Target Scanner Loop (mirrors AIMLOCK.lua ValidTargets pattern)
task.spawn(function()
    while State.Running do
        local newTargets = {}
        local mode = Config.TargetMode  -- 1=Players, 2=NPCs, 3=Both
        local camPos = Camera.CFrame.Position
        -- Players
        if mode==1 or mode==3 then
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    local hrp=p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position-camPos).Magnitude<=2000 then
                        newTargets[p.Character]=p.DisplayName or p.Name
                    end
                end
            end
        end
        -- NPCs
        if mode==2 or mode==3 then
            for char in pairs(NPCCache) do
                local hum=char:FindFirstChild("Humanoid")
                local hrp=char:FindFirstChild("HumanoidRootPart")
                if char.Parent and hum and hrp and hum.Health>0 then
                    if (hrp.Position-camPos).Magnitude<=2000 then
                        newTargets[char]=char.Name
                    end
                else
                    NPCCache[char]=nil
                end
            end
        end
        -- Cleanup stale ESP
        for char in pairs(ESP_Cache) do
            if not newTargets[char] then ClearESP(char) end
        end
        ValidTargets=newTargets
        task.wait(0.5)
    end
end)

-- Feature functions

local Invis_CharAdded = nil
local function SetInvisibility(on)
    if Invis_CharAdded then Invis_CharAdded:Disconnect(); Invis_CharAdded=nil end
    local function applyInvis(lpc)
        if not lpc then return end
        for _, part in pairs(lpc:GetDescendants()) do if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then pcall(function() part.Transparency = 0.75 end) end end
        local hrp = lpc:FindFirstChild("HumanoidRootPart")
        if hrp then
            local ppos = hrp.CFrame; task.wait(0.1)
            pcall(function() lpc:MoveTo(Vector3.new(-25.95, 400, 3537.55)) end); task.wait(0.1)
            if (not lpc:FindFirstChild("HumanoidRootPart")) or (lpc.HumanoidRootPart.Position.Y < -50) then
                pcall(function() lpc:MoveTo(ppos.Position) end)
                for _, part in pairs(lpc:GetDescendants()) do if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then pcall(function() part.Transparency = 0 end) end end
                return
            end
            local Seat = Instance.new("Seat"); Seat.Parent = workspace; Seat.Anchored = false; Seat.CanCollide = false
            Seat.Name = "invischair_pwy"; Seat.Transparency = 1; Seat.Position = Vector3.new(-25.95, 400, 3537.55)
            local Weld = Instance.new("Weld"); Weld.Part0 = Seat
            local t = lpc:FindFirstChild("Torso") or lpc:FindFirstChild("UpperTorso")
            if t then
                Weld.Part1 = t; Weld.Parent = Seat; task.wait()
                pcall(function() Seat.CFrame = ppos end)
            else Seat:Destroy() end
        end
    end
    if on then
        applyInvis(LocalPlayer.Character)
        Invis_CharAdded = LocalPlayer.CharacterAdded:Connect(function(char)
            if Config.InvisToggle then task.wait(1); applyInvis(char) end
        end)
    else
        local lpc = LocalPlayer.Character
        if lpc then for _, part in pairs(lpc:GetDescendants()) do if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then pcall(function() part.Transparency = 0 end) end end end
        local inv = workspace:FindFirstChild("invischair_pwy"); if inv then pcall(function() inv:Destroy() end) end
    end
end

local function SetWalkSpeed(on)
    if WS_Loop then WS_Loop:Disconnect(); WS_Loop=nil end
    if on then
        WS_Loop=RunService.RenderStepped:Connect(function(dt)
            local lpc = LocalPlayer.Character
            if not lpc then return end
            local h = lpc:FindFirstChildOfClass("Humanoid")
            local hrp = lpc:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.MoveDirection.Magnitude > 0 then
                hrp.Velocity = Vector3.new(h.MoveDirection.X * Config.WalkSpeed, hrp.Velocity.Y, h.MoveDirection.Z * Config.WalkSpeed)
            end
        end)
    else
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed=16 end) end
    end
end
local function SetJumpPower(on) if JP_Loop then JP_Loop:Disconnect(); JP_Loop=nil end; if on then JP_Loop=RunService.Heartbeat:Connect(function() local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h.UseJumpPower=true; h.JumpPower=Config.JumpPower end end) else local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h.UseJumpPower=true; h.JumpPower=50 end end end
local function SetNoclip(on) if NC_Conn then NC_Conn:Disconnect(); NC_Conn=nil end; if on then NC_Conn=RunService.Stepped:Connect(function() local lpc=LocalPlayer.Character; if lpc then for _,p in ipairs(lpc:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end) else local lpc=LocalPlayer.Character; if lpc then for _,p in ipairs(lpc:GetDescendants()) do pcall(function() if p:IsA("BasePart") then p.CanCollide=true end end) end end end end
local function SetInfJump(on) if IJ_Conn then IJ_Conn:Disconnect(); IJ_Conn=nil end; if on then IJ_Conn=UIS.JumpRequest:Connect(function() local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end) end end
local GM_CharAdded = nil
local function SetGodMode(on)
    if GM_Conn then GM_Conn:Disconnect(); GM_Conn=nil end
    if GM_CharAdded then GM_CharAdded:Disconnect(); GM_CharAdded=nil end
    local function applyGod(char)
        local h = char:WaitForChild("Humanoid", 3)
        if not h then return end
        h.MaxHealth = 9e9; h.Health = 9e9; h.BreakJointsOnDeath = false; pcall(function() h.RequiresNeck = false end)
        if GM_Conn then GM_Conn:Disconnect() end
        GM_Conn = h.HealthChanged:Connect(function() if Config.GodMode and h.Health < 9e9 then h.Health = 9e9 end end)
    end
    if on then
        if LocalPlayer.Character then applyGod(LocalPlayer.Character) end
        GM_CharAdded = LocalPlayer.CharacterAdded:Connect(function(char) if Config.GodMode then task.wait(0.5); applyGod(char) end end)
    else
        local lpc=LocalPlayer.Character
        if lpc then
            local h=lpc:FindFirstChildOfClass("Humanoid")
            if h then h.MaxHealth=100; h.Health=100; h.BreakJointsOnDeath=true; pcall(function() h.RequiresNeck=true end) end
        end
    end
end
local function SetAntiAFK(on) if AFK_Conn then AFK_Conn:Disconnect(); AFK_Conn=nil end; if on and VirtualUser then AFK_Conn=LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end end
local _origMaxZoom = LocalPlayer.CameraMaxZoomDistance
local function SetInfZoom(on)
    if on then
        _origMaxZoom = LocalPlayer.CameraMaxZoomDistance -- save current
        LocalPlayer.CameraMaxZoomDistance = math.huge    -- unlimited
        LocalPlayer.CameraMinZoomDistance = 0            -- also allow zoom in
    else
        LocalPlayer.CameraMaxZoomDistance = _origMaxZoom -- restore
    end
end
local function UpdateXray(cache,enabled) if enabled then for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("BasePart") then local ic=v.Parent:FindFirstChildWhichIsA("Humanoid") or (v.Parent.Parent and v.Parent.Parent:FindFirstChildWhichIsA("Humanoid")); if not ic then if not cache[v] then cache[v]=v.LocalTransparencyModifier end; v.LocalTransparencyModifier=0.5 end end end else for p,o in pairs(cache) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=o end end) end; table.clear(cache) end end
local CFly_Loop = nil
local function SetFly(on) 
    local lpc=LocalPlayer.Character; if not lpc then return end
    local hum=lpc:FindFirstChildOfClass("Humanoid")
    local hrp=lpc:FindFirstChild("HumanoidRootPart")
    if on and hrp then 
        if FlyBG then pcall(function() FlyBG:Destroy() end) end
        if FlyBV then pcall(function() FlyBV:Destroy() end) end
        FlyBG=Instance.new("BodyGyro",hrp); FlyBG.P=9e4; FlyBG.MaxTorque=Vector3.new(9e9,9e9,9e9); FlyBG.CFrame=hrp.CFrame
        FlyBV=Instance.new("BodyVelocity",hrp); FlyBV.Velocity=Vector3.new(0,0,0); FlyBV.MaxForce=Vector3.new(9e9,9e9,9e9)
        if hum then hum.PlatformStand=true end
        pcall(function() lpc.Animate.Disabled=true end)
        
        if CFly_Loop then CFly_Loop:Disconnect() end
        local cam = workspace.CurrentCamera
        CFly_Loop = RunService.RenderStepped:Connect(function()
            if not lpc or not lpc:FindFirstChild("HumanoidRootPart") then return end
            if not Config.FlyToggle then return end
            local speed = Config.FlySpeed or 50
            local vel = Vector3.new(0,0,0)
            if UIS:IsKeyDown(Enum.KeyCode.W) then vel = vel + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then vel = vel - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then vel = vel - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then vel = vel + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end
            FlyBV.Velocity = vel.Magnitude > 0 and (vel.Unit * speed) or Vector3.new(0,0,0)
            FlyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
            for _,p in ipairs(lpc:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
        end)
    else 
        if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG=nil end
        if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV=nil end
        if hum then hum.PlatformStand=false end
        pcall(function() lpc.Animate.Disabled=false end)
        if CFly_Loop then CFly_Loop:Disconnect(); CFly_Loop=nil end
        for _,p in ipairs(lpc:GetDescendants()) do pcall(function() if p:IsA("BasePart") then p.CanCollide=true end end) end
    end 
end
local function ApplyFPSBoost() if Config.FPS_NoShadows then pcall(function() Lighting.GlobalShadows=false; Lighting.FogEnd=9e9 end) end; if Config.FPS_LowQuality then pcall(function() settings().Rendering.QualityLevel=1 end) end; if FPS_DescConn then FPS_DescConn:Disconnect(); FPS_DescConn=nil end; local function Proc(inst) if inst:IsDescendantOf(Players) then return end; if Config.FPS_NoParticles and (inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles")) then inst.Enabled=false end; if Config.FPS_NoClothes and (inst:IsA("Clothing") or inst:IsA("SurfaceAppearance") or inst:IsA("BaseWrap")) then pcall(function() inst:Destroy() end); return end; if Config.FPS_LowQuality then if inst:IsA("BasePart") then pcall(function() inst.Material=Enum.Material.Plastic; inst.Reflectance=0 end) end end; if inst:IsA("PostEffect") then pcall(function() inst.Enabled=false end) end end; task.spawn(function() for i,v in ipairs(game:GetDescendants()) do pcall(function() Proc(v) end); if i%1000==0 then task.wait() end end end); FPS_DescConn=game.DescendantAdded:Connect(function(v) task.wait(0.3); pcall(function() Proc(v) end) end) end
local function DisableFPSBoost() if FPS_DescConn then FPS_DescConn:Disconnect(); FPS_DescConn=nil end; pcall(function() Lighting.GlobalShadows=true end); pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end) end
local function StartSafeTP(tp) if SafeTP_Conn then SafeTP_Conn:Disconnect(); SafeTP_Conn=nil end; SafeTP_Conn=RunService.Heartbeat:Connect(function(dt) if not Config.TPGOSwitch then SafeTP_Conn:Disconnect(); SafeTP_Conn=nil; return end; local myHRP=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); local tHRP=tp.Character and tp.Character:FindFirstChild("HumanoidRootPart"); if not(myHRP and tHRP) then return end; if (tHRP.Position-myHRP.Position).Magnitude>4 then myHRP.CFrame=myHRP.CFrame:Lerp(CFrame.new(tHRP.Position+tHRP.CFrame.LookVector*3+Vector3.new(0,2,0)),math.clamp(dt*math.clamp(Config.TPFlightSens,10,500)*0.12,0.01,0.4)) end end) end
local function StopSafeTP() if SafeTP_Conn then SafeTP_Conn:Disconnect(); SafeTP_Conn=nil end end

local function ProcessInteractObj(obj)
    if obj:IsA("ProximityPrompt") then
        if not OriginalInteractData[obj] then OriginalInteractData[obj]={Duration=obj.HoldDuration,Distance=obj.MaxActivationDistance,LOS=obj.RequiresLineOfSight} end
        obj.HoldDuration = Config.InstantPress and 0 or OriginalInteractData[obj].Duration
        obj.MaxActivationDistance = Config.AuraRange and 50 or OriginalInteractData[obj].Distance
        if Config.AuraRange then obj.RequiresLineOfSight = false else obj.RequiresLineOfSight = OriginalInteractData[obj].LOS end
    elseif obj:IsA("ClickDetector") then
        if not OriginalInteractData[obj] then OriginalInteractData[obj]={Distance=obj.MaxActivationDistance} end
        obj.MaxActivationDistance = Config.AuraRange and math.huge or OriginalInteractData[obj].Distance
    end
end
local function UpdateInteractables()
    for _,obj in ipairs(workspace:GetDescendants()) do pcall(ProcessInteractObj,obj) end
end
AddConn(workspace.DescendantAdded:Connect(function(obj) task.wait(0.1); pcall(ProcessInteractObj,obj) end))

LocalPlayer.CharacterAdded:Connect(function() task.wait(0.7); FlyBG=nil; FlyBV=nil; if Config.GodMode then SetGodMode(true) end; if Config.WSToggle then SetWalkSpeed(true) end; if Config.JPToggle then SetJumpPower(true) end; if Config.Noclip then SetNoclip(true) end; if Config.InfJump then SetInfJump(true) end; if Config.FlyToggle then SetFly(true) end; if Config.InfZoom then SetInfZoom(true) end end)
AddConn(RunService.RenderStepped:Connect(function() frameCount=frameCount+1 end))
task.spawn(function() while State.Running do task.wait(1); lastFPS=frameCount; frameCount=0; pcall(function() pingValue=math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end) end end)

-- TAB 1: AIMLOCK
local T1=BuildTab("Aimlock")
T1:Section("AIMLOCK","ล็อกเป้าอัตโนมัติ")
T1:Toggle("AIMLOCK","เปิดใช้งาน Aimlock","Aimlock",function(v) if not v then LockedTarget=nil; State.ToggleAiming=false end end)

T1:Dropdown("MODE","TOGGLE | HOLD | ALWAYS ON","AimMode",{"TOGGLE","HOLD","ALWAYS ON"})

local TargetModeNames = {"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"}
local TargetCycleBtn
do
    local tNames = TargetModeNames
    local function GetLabel() return "🎯 เป้าหมาย: " .. tNames[Config.TargetMode] end
    TargetCycleBtn = T1:Button(GetLabel(), Colors.PrimaryBlue, function()
        Config.TargetMode = (Config.TargetMode % 3) + 1
        LockedTarget = nil; ValidTargets = {}
        TargetCycleBtn.Text = GetLabel()
        Tw(TargetCycleBtn,0.15,{BackgroundColor3=Colors.AccentGlow})
        task.delay(0.4,function() Tw(TargetCycleBtn,0.35,{BackgroundColor3=Colors.PrimaryBlue}) end)
    end)
end
T1:Toggle("ENEMY ONLY","ล็อกเฉพาะฝั่งตรงข้าม","EnemyOnly")
T1:Bind("BIND","ปุ่มสำหรับ Aimlock","BindType","BindKey")
T1:Slider("FOV SIZE","ขนาดวง FOV","FOV",1,200,"%",false)
T1:Slider("SMOOTHNESS","น้อย = ช้า เยอะ = เร็ว","AimSmooth",0.01,1,"",true)
T1:ColorPicker("FOV COLOR","สี FOV","FOVColor_C3")
T1:Toggle("WALL CHECK","ตรวจกำแพง","WallCheck")



-- TAB 2: ESP PLAYER
local T2=BuildTab("ESP Player")
T2:Section("ESP Player","ESP Player & NPCs")
T2:Toggle("Enable Player ESP","เปิด ESP เฉพาะผู้เล่น","P_Master")
T2:Toggle("ESP In FOV Only","แสดง ESP เฉพาะใน FOV","P_ESPInFOVOnly")
T2:Toggle("Show Name","แสดงชื่อบนหัว","P_ShowName"); T2:Toggle("Show Health","แสดง HP %","P_ShowHealth")
T2:Toggle("Show Distance","แสดงระยะห่าง","P_ShowDist"); T2:Toggle("Highlight","สีระบายตัวละคร","P_Highlight")
T2:Toggle("Team Color","ใช้สีฝ่าย","P_TeamColor"); T2:Toggle("Team Check","ซ่อนทีมเดียวกัน","P_TeamCheck")
T2:Toggle("Xray","มองทะลุ","P_Xray",function() UpdateXray(XrayCache_P,Config.P_Xray) end)
T2:Section("Setting","ปรับค่า ESP สำหรับผู้เล่น")
T2:ColorPicker("Player Color","สีของ ESP Player (เลือกเองได้)","P_Color_C3")
T2:Slider("Text Size","ขนาดตัวอักษร","P_TextSize",8,30,"px",false)
T2:Slider("Fill Trans","ความทึบ Fill","P_FillTrans",0,1,"",true)
T2:Slider("Outline Trans","ความทึบ Outline","P_OutlineTrans",0,1,"",true)
T2:Section("Hitbox","ขยาย HitBox")
T2:Toggle("Enable Hitbox","เปิด Hitbox Expander","P_HitboxToggle",function(v) if not v then for char,sz in pairs(HitboxOriginalSizes) do pcall(function() local hrp=char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.Size=sz; hrp.Transparency=1; hrp.Material=Enum.Material.SmoothPlastic; hrp.CanCollide=true end end) end; HitboxOriginalSizes={} end end)
T2:Dropdown("Hitbox Targets","เลือกเป้าหมายที่จะขยาย","HitboxTargetMode",{"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"})
T2:Slider("Hitbox Size","ขนาด Hitbox (studs)","P_HitboxSize",4,200,"",false)

-- TAB 3: SETTING PLAYER
local T3=BuildTab("Setting Player")
T3:Section("Appearance","ธีมและรูปลักษณ์ของเมนู")
T3:Dropdown("GUI Theme","เลือกธีม — เปลี่ยนทันที","Theme",{"Dark","Midnight","Neon","Rose","Gold","Purple"},false,function(v) ApplyTheme(v) end)
T3:Section("Movement","ปรับการเคลื่อนที่")
T3:Toggle("Walk Speed","เปิดความเร็วเดิน","WSToggle",function(v) SetWalkSpeed(v) end)
T3:Slider("Walk Speed","ค่าความเร็ว","WalkSpeed",16,1000,"",false,function() if Config.WSToggle then SetWalkSpeed(true) end end)
T3:Toggle("Jump Power","เปิดพลังกระโดด","JPToggle",function(v) SetJumpPower(v) end)
T3:Slider("Jump Power","ค่าพลังกระโดด","JumpPower",10,1000,"",false,function() if Config.JPToggle then SetJumpPower(true) end end)
T3:Toggle("Infinity Jump","กระโดดได้ไม่จำกัด","InfJump",function(v) SetInfJump(v) end)
T3:Toggle("Fly","Space=ขึ้น Shift=ลง WASD=ทิศทาง","FlyToggle",function(v) SetFly(v) end)
T3:Slider("Fly Speed","ความเร็วบิน","FlySpeed",5,500,"",false)
T3:Toggle("No Clip","เดินทะลุกำแพง","Noclip",function(v) SetNoclip(v) end)
    T3:Toggle("Invisibility","ล่องหน (ใช้ได้บางแมพ)","InvisToggle",function(v) SetInvisibility(v) end)
T3:Toggle("Infinite Zoom","ซูมได้ไม่จำกัด","InfZoom",function(v) SetInfZoom(v) end)
T3:Section("Camera","ปรับมุมมองกล้อง")
T3:Toggle("Custom FOV","ปรับ FieldOfView","FOVToggle",function(v)
    if v then pcall(function() workspace.CurrentCamera.FieldOfView=Config.FOVView end)
    else pcall(function() workspace.CurrentCamera.FieldOfView=70 end) end
end)
T3:Slider("FOV Angle","มุมกล้อง (70 = ปกติ)","FOVView",30,360,"°",false,function(v)
    if Config.FOVToggle then pcall(function() workspace.CurrentCamera.FieldOfView=v end) end
end)
T3:Section("Lighting","ปรับแสงสว่าง")
T3:Toggle("Fullbright","แมพสว่าง","Fullbright_Toggle")
T3:Toggle("Remove Fog","ลบหมอก","RemoveFog_Toggle")
T3:Section("Facilities","สิ่งอำนวยความสะดวก")
T3:Toggle("Instant Press","กด E ไม่ต้องรอหลอดเต็ม","InstantPress",function() UpdateInteractables() end)
T3:Toggle("Aura Range","เพิ่มระยะกดให้ไกลขึ้น","AuraRange",function() UpdateInteractables() end)
T3:Toggle("God Mode","อมตะ (ใช้ได้บางแมพ)","GodMode",function(v) SetGodMode(v) end)
T3:Toggle("Anti-AFK","ป้องกัน AFK","AntiAFK",function(v) SetAntiAFK(v) end)
T3:Section("Performance","เพิ่ม FPS")
T3:Toggle("Booster FPS","เปิด FPS Booster","FPSBooster",function(v) if v then ApplyFPSBoost() else DisableFPSBoost() end end)
T3:Toggle("No Shadows","ปิดเงา","FPS_NoShadows"); T3:Toggle("No Particles","ปิด Particle / Fire / Smoke","FPS_NoParticles")
T3:Toggle("No Clothes","ปิดเสื้อผ้าตัวละคร","FPS_NoClothes"); T3:Toggle("Low Quality","ลด Material Quality","FPS_LowQuality")
T3:Section("Stats HUD","แสดง FPS / Ping บนจอ")
T3:Dropdown("Show Stats","เลือกข้อมูลที่จะแสดง","ShowFPSPing",{"FPS","Ping","FPS & Ping"})
T3:Toggle("Enable Stats HUD","แสดง HUD","ShowStatsToggle",function(v) StatHUD.Visible=v end)
T3:Dropdown("HUD Position","ตำแหน่ง HUD","HUDPosition",{"TopLeft","TopRight","BottomLeft","BottomRight"},false,function() UpdateHUDPos() end)
T3:Section("Settings","บันทึก / โหลดการตั้งค่า")
T3:Button("💾  Save Settings",Colors.PrimaryBlue,SaveSettings)
T3:Button("📂  Load Settings",Color3.fromRGB(52,52,72),LoadSettings)

-- TAB 4: TELEPORT
local T4=BuildTab("Player Teleport")
T4:Section("Teleport Player","วาปหรือบินตามผู้เล่น")
T4:Dropdown("Name Player","เลือกผู้เล่น (ค้นหาได้)","TPTarget",{"-"},true)
T4:Dropdown("TP Mode","Safe Fly = บิน  |  Warp = วาป","TPMode",{"Safe Fly","Warp"})
T4:Slider("Fly Speed","ความเร็ว Safe Fly","TPFlightSens",10,500,"",false)
T4:Toggle("Activate TP","START = เริ่ม  ·  STOP = หยุด","TPGOSwitch",function(v)
    if v and Config.TPTarget~="-" then local tp=Players:FindFirstChild(Config.TPTarget)
        if tp then if Config.TPMode=="Safe Fly" then StartSafeTP(tp) else local tHRP=tp.Character and tp.Character:FindFirstChild("HumanoidRootPart"); if tHRP and LocalPlayer.Character then pcall(function() LocalPlayer.Character:PivotTo(tHRP.CFrame*CFrame.new(0,0,3)) end) end end end
    else StopSafeTP() end
end,{"STOP","GO"})
T4:Section("Spectate","ดูมุมกล้องผู้เล่นอื่น")
T4:Dropdown("Spectate Player","เลือกผู้เล่น","SpecTarget",{"-"},true)
T4:Toggle("Enable Spectate","เปิดดูจอผู้เล่น","SpecToggle",function(v) if not v then local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then Camera.CameraSubject=h end end end)
T4:Section("Click Teleport","กดปุ่มที่กำหนด + คลิกซ้าย")
T4:Bind("Click TP Key","กดปุ่มนี้ค้างไว้ขณะคลิก","ClickTPBindType","ClickTPBindKey")
T4:Toggle("Enable Click TP","เปิด Click Teleport","ClickTPToggle")

-- TAB 5: SERVER
local T5=BuildTab("Server")

local nameBtn = T5:Button("🎮 Name: Loading...", Colors.PrimaryBlue, function()
    -- Copy everything after "🎮 Name: "
    local name = nameBtn.Text:sub(11)
    if setclipboard then setclipboard(name); ShowToast("✅ คัดลอกชื่อเกมแล้ว!", Colors.Green) end
end)
task.spawn(function()
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then nameBtn.Text = "🎮 Name: " .. info.Name
        else nameBtn.Text = "🎮 Name: " .. game.Name end
    end)
end)

T5:Button("👤 Creator ID: "..tostring(game.CreatorId), Color3.fromRGB(52,52,72), function()
    if setclipboard then setclipboard(tostring(game.CreatorId)); ShowToast("✅ คัดลอก Creator ID แล้ว!", Colors.Green) end
end)

T5:Button("🆔 Place ID: "..tostring(game.PlaceId), Color3.fromRGB(52,52,72), function()
    if setclipboard then setclipboard(tostring(game.PlaceId)); ShowToast("✅ คัดลอก Place ID แล้ว!", Colors.Green) end
end)

T5:Button("🔑 Job ID: "..tostring(game.JobId), Color3.fromRGB(52,52,72), function()
    if setclipboard then setclipboard(tostring(game.JobId)); ShowToast("✅ คัดลอก Job ID แล้ว!", Colors.Green) end
end)

T5:Button("🔗 Direct Join Link", Colors.PrimaryBlue, function()
    local link = "roblox://experiences/start?placeId="..tostring(game.PlaceId).."&gameInstanceId="..tostring(game.JobId)
    if setclipboard then setclipboard(link); ShowToast("✅ คัดลอก Link แบบเข้าอัตโนมัติแล้ว!", Colors.Green) end
end)

T5:Button("💻 JS Join Script (Browser Console)", Color3.fromRGB(52,52,72), function()
    local code = "Roblox.GameLauncher.joinGameInstance("..tostring(game.PlaceId)..", '"..tostring(game.JobId).."');"
    if setclipboard then setclipboard(code); ShowToast("✅ คัดลอก JS Script แล้ว!", Colors.Green) end
end)

T5:Button("🔄 Rejoin Server", Color3.fromRGB(46, 204, 113), function()
    ShowToast("กำลังเชื่อมต่อใหม่...", Colors.PrimaryBlue)
    local ts = game:GetService("TeleportService")
    if #Players:GetPlayers() <= 1 then
        LocalPlayer:Kick("\nRejoining...")
        task.wait()
        ts:Teleport(game.PlaceId, LocalPlayer)
    else
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end)

T5:Button("🚪 Server Hop", Colors.Green, function()
    ShowToast("กำลังเปลี่ยนเซิร์ฟเวอร์...", Colors.PrimaryBlue)
    local ts = game:GetService("TeleportService")
    ts:Teleport(game.PlaceId, LocalPlayer)
end)

-- [ INPUT HANDLERS ]
AddConn(UIS.InputBegan:Connect(function(input,gp)
    if gp or State.Binding then return end
    if Config.MenuToggleBindType=="Keyboard" and Config.MenuToggleBindKey then
        if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Config.MenuToggleBindKey then Config.MenuVisible=not Config.MenuVisible; MainFrame.Visible=Config.MenuVisible; return end
    elseif Config.MenuToggleBindType=="Mouse" and Config.MenuToggleBindKey then
        local mb=Config.MenuToggleBindKey==1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
        if input.UserInputType==mb then Config.MenuVisible=not Config.MenuVisible; MainFrame.Visible=Config.MenuVisible; return end
    end
    if Config.Aimlock and Config.AimMode=="TOGGLE" then
        local hit=false
        if Config.BindType=="Mouse" then local mb=Config.BindKey==1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2; hit=(input.UserInputType==mb)
        elseif Config.BindType=="Keyboard" and Config.BindKey then hit=(input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Config.BindKey) end
        if hit then State.ToggleAiming=not State.ToggleAiming; if not State.ToggleAiming then LockedTarget=nil end end
    end
    if Config.ClickTPToggle and input.UserInputType==Enum.UserInputType.MouseButton1 and Config.ClickTPBindType=="Keyboard" and Config.ClickTPBindKey then
        if UIS:IsKeyDown(Config.ClickTPBindKey) then local lpc=LocalPlayer.Character; if lpc and Mouse.Hit then pcall(function() lpc:PivotTo(Mouse.Hit*CFrame.new(0,3,0)) end) end
    end end
end))

local function IsAimKeyHeld()
    if Config.BindType=="Mouse" then local mb=Config.BindKey==1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2; return UIS:IsMouseButtonPressed(mb)
    elseif Config.BindType=="Keyboard" and Config.BindKey then return UIS:IsKeyDown(Config.BindKey) end; return false
end

-- [ MAIN RENDER LOOP ]
AddConn(RunService.RenderStepped:Connect(function()
    if not State.Running then return end
    Camera = workspace.CurrentCamera
    if Config.ShowStatsToggle then StatHUD.Visible=true
        if Config.ShowFPSPing=="FPS" then StatHUD.Text="FPS: "..lastFPS
        elseif Config.ShowFPSPing=="Ping" then StatHUD.Text="Ping: "..pingValue.."ms"
        else StatHUD.Text="FPS: "..lastFPS.." | "..pingValue.."ms" end
    else StatHUD.Visible=false end

    local LPChar=LocalPlayer.Character; local LPHum=LPChar and LPChar:FindFirstChildOfClass("Humanoid"); local LPHRP=LPChar and LPChar:FindFirstChild("HumanoidRootPart")

    -- Lighting
    if Config.Fullbright_Toggle then
        pcall(function() Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 9e9; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128) end)
    elseif Config.RemoveFog_Toggle then
        pcall(function() Lighting.FogEnd = 9e9 end)
    end

    -- Custom FOV: force every frame when enabled
    if Config.FOVToggle then
        pcall(function() Camera.FieldOfView = Config.FOVView end)
    end

    -- Fly
    if Config.FlyToggle and FlyBV and FlyBG and LPHRP then
        local cam=Camera.CoordinateFrame
        local fwd=(UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)+(UIS:IsKeyDown(Enum.KeyCode.S) and -1 or 0)
        local rgt=(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)+(UIS:IsKeyDown(Enum.KeyCode.A) and -1 or 0)
        local up=(UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)+(UIS:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 0)
        FlyBV.Velocity=(fwd~=0 or rgt~=0 or up~=0) and (cam.LookVector*fwd+cam.RightVector*rgt+Vector3.new(0,up,0))*Config.FlySpeed or Vector3.new(0,0,0)
        FlyBG.CFrame=Camera.CFrame
    elseif not Config.FlyToggle and (FlyBG or FlyBV) then SetFly(false) end

    -- Spectate
    if Config.SpecToggle and Config.SpecTarget~="-" then local sp=Players:FindFirstChild(Config.SpecTarget); if sp and sp.Character then local sh=sp.Character:FindFirstChildOfClass("Humanoid"); if sh and Camera.CameraSubject~=sh then Camera.CameraSubject=sh end end
    elseif not Config.SpecToggle and LPHum and Camera.CameraSubject~=LPHum then Camera.CameraSubject=LPHum end

    -- Warp TP
    if Config.TPGOSwitch and Config.TPTarget~="-" and Config.TPMode=="Warp" and LPChar then
        local now=tick(); if now-lastWarpTick>=0.5 then lastWarpTick=now; local tp=Players:FindFirstChild(Config.TPTarget); if tp and tp.Character then local tHRP=tp.Character:FindFirstChild("HumanoidRootPart"); if tHRP then pcall(function() LPChar:PivotTo(tHRP.CFrame*CFrame.new(0,0,3)) end) end end end
    end

    -- Hitbox
    if Config.P_HitboxToggle then
        local chars = {}
        local hMode = Config.HitboxTargetMode

        if hMode == "PLAYERS ONLY" or hMode == "PLAYERS & NPCs" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then table.insert(chars, p.Character) end
            end
        end
        if hMode == "NPCs ONLY" or hMode == "PLAYERS & NPCs" then
            for char, _ in pairs(NPCCache) do table.insert(chars, char) end
        end

        local currentHitboxed = {}
        for _, char in ipairs(chars) do
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                currentHitboxed[char] = true
                if not HitboxOriginalSizes[char] then HitboxOriginalSizes[char] = hrp.Size end
                hrp.Size = Vector3.new(Config.P_HitboxSize, Config.P_HitboxSize, Config.P_HitboxSize)
                hrp.Transparency = 0.6
                hrp.Material = Enum.Material.Neon
                hrp.Color = Colors.PrimaryBlue
                hrp.CanCollide = false
            end
        end

        for char, origSize in pairs(HitboxOriginalSizes) do
            if not currentHitboxed[char] then
                pcall(function()
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Size = origSize; hrp.Transparency = 1; hrp.Material = Enum.Material.SmoothPlastic; hrp.CanCollide = true
                    end
                end)
                HitboxOriginalSizes[char] = nil
            end
        end
    end

    -- FOV Circle
    local vp=Camera.ViewportSize
    if vp.X>0 then
        Circle.Radius=(math.min(vp.X,vp.Y)/2)*(Config.FOV/100)
        Circle.Position=Vector2.new(vp.X/2,vp.Y/2)
        Circle.Color=Config.FOVColor_C3 or Colors.PrimaryBlue
        Circle.Visible=Config.Aimlock
    end

    -- Aimlock state
    local isAimingNow=false
    if Config.Aimlock then
        if Config.AimMode=="ALWAYS ON" then isAimingNow=true
        elseif Config.AimMode=="HOLD" then isAimingNow=IsAimKeyHeld()
        else isAimingNow=State.ToggleAiming end
    end
    if not isAimingNow then LockedTarget=nil end

    local center=Vector2.new(vp.X/2,vp.Y/2); local bestHead,bestScore=nil,math.huge
    local LPHRP2=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- ── ESP + Aimlock using ValidTargets (same as AIMLOCK.lua pattern) ──
    for char, nameStr in pairs(ValidTargets) do
        local head=char:FindFirstChild("Head")
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not(head and hrp and hum and hum.Health>0 and char.Parent) then
            local e=ESP_Cache[char]; if e then e.Gui.Enabled=false; e.Highlight.Enabled=false end
            continue
        end
        local esp=GetESP(char)
        local rPos,rVis=Camera:WorldToViewportPoint(hrp.Position)
        local scr2D=Vector2.new(rPos.X,rPos.Y)
        local inFOV=rVis and (scr2D-center).Magnitude<=Circle.Radius
        local hpPct=math.floor((hum.Health/math.max(hum.MaxHealth,1))*100)

        -- Determine if this is a Player or NPC
        local ownerPlayer=Players:GetPlayerFromCharacter(char)
        local isPlayer=(ownerPlayer~=nil)

        -- ── ESP Display ──
        -- only use ESP Player settings
        local useP   = isPlayer and Config.P_Master
        local showESP = useP and rVis and rPos.Z>0 and rPos.Z<2000

        if useP and Config.P_ESPInFOVOnly and not inFOV then showESP=false end
        if showESP and isPlayer then
            local p=ownerPlayer
            local skipTeam=(Config.P_TeamCheck) and (p.Team==LocalPlayer.Team)
            if skipTeam then showESP=false end
        end

        if showESP then
            local col
            if isPlayer then
                local p=ownerPlayer
                col=(Config.P_TeamColor) and p.TeamColor.Color or Config.P_Color_C3
            else
                col=Color3.new(1,1,1)
            end
            esp.Gui.Adornee=head; esp.Gui.Enabled=true
            local info={}
            if Config.P_ShowName then table.insert(info, ownerPlayer.DisplayName or ownerPlayer.Name) end
            if Config.P_ShowHealth then table.insert(info,"HP: "..hpPct.."%") end
            if Config.P_ShowDist then table.insert(info,"["..math.floor(rPos.Z).."m]") end
            esp.Label.Text=table.concat(info,"\n"); esp.Label.TextColor3=col
            esp.Label.TextSize=Config.P_TextSize
            esp.Highlight.Adornee=char; esp.Highlight.Enabled=Config.P_Highlight; esp.Highlight.FillColor=col
            esp.Highlight.FillTransparency=Config.P_FillTrans; esp.Highlight.OutlineColor=col; esp.Highlight.OutlineTransparency=Config.P_OutlineTrans
        else
            esp.Gui.Enabled=false; esp.Highlight.Enabled=false
        end

        -- ── Aimlock Candidate: combined screen + world distance score ──
        if isAimingNow and not LockedTarget and inFOV and rVis and rPos.Z>0 then
            local isEnemy=true
            if isPlayer and Config.EnemyOnly then
                if ownerPlayer.Team ~= nil and LocalPlayer.Team ~= nil then
                    isEnemy=(ownerPlayer.Team~=LocalPlayer.Team)
                else
                    isEnemy=true
                end
            end
            if isEnemy and IsVisible(head) then
                local scrDist=(scr2D-center).Magnitude                    -- px distance to FOV center
                local wldDist=LPHRP2 and (hrp.Position-LPHRP2.Position).Magnitude or 0  -- 3D world studs
                -- Normalize: scrDist already in px (0..Circle.Radius), wldDist in studs (0..2000)
                local normScr=scrDist/(Circle.Radius+0.001)
                local normWld=wldDist/2000
                -- Combined score: screen dist weighted 70%, world dist 30%
                local score=normScr*0.7 + normWld*0.3
                if score<bestScore then bestHead=head; bestScore=score end
            end
        end
        -- Invalidate locked target if dead or behind wall
        if LockedTarget==head and (hum.Health<=0 or not IsVisible(head)) then LockedTarget=nil end
    end

    -- ── Lock & Aim ──
    if isAimingNow and not LockedTarget and bestHead then LockedTarget=bestHead end
    if isAimingNow and LockedTarget then
        if LockedTarget and LockedTarget.Parent then
            local lhum=LockedTarget.Parent:FindFirstChildOfClass("Humanoid")
            if lhum and lhum.Health>0 and IsVisible(LockedTarget) then
                Camera.CFrame=Camera.CFrame:Lerp(
                    CFrame.lookAt(Camera.CFrame.Position,LockedTarget.Position),
                    math.clamp(Config.AimSmooth,0.01,1))
            else LockedTarget=nil end
        else LockedTarget=nil end
    end
end))

-- [ POST INIT ]
task.spawn(function()
    task.wait(0.75); LoadSettings(); UpdateHUDPos()
    if Themes[Config.Theme] then ApplyTheme(Config.Theme) end
    UpdateMenuBindLabel()
end)

-- Pulse title line
task.spawn(function()
    while State.Running do
        Tw(TitleLine,1.6,{BackgroundColor3=Colors.AccentGlow}); task.wait(1.7)
        Tw(TitleLine,1.6,{BackgroundColor3=Colors.PrimaryBlue}); task.wait(1.7)
    end
end)
