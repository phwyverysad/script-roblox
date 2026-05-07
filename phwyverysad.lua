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

-- [ COMPREHENSIVE CLEANUP - ลบทุกอย่างที่สคริปสร้างไว้ ]
local function ComprehensiveCleanup()
    -- 1. ลบ GUI ทั้งหมดใน CoreGui
    local guiNames = {
        "PhwyverysadModMenu",
        "PhwyverysadDropdowns", 
        "PhwyverysadCPicker",
        "NexusESP_Folder",
        "PhwyverysadESP",
        "PhwyToastContainer",
        "AimlockFOVCircle",
        "PhwyHUD"
    }
    for _, name in ipairs(guiNames) do
        pcall(function()
            local gui = CoreGui:FindFirstChild(name)
            if gui then gui:Destroy() end
        end)
        pcall(function()
            local gui = workspace:FindFirstChild(name)
            if gui then gui:Destroy() end
        end)
    end
    
    -- 2. ลบ Objects ที่สร้างใน Workspace
    pcall(function()
        local hipPlatform = workspace:FindFirstChild("HipHeightPlatform")
        if hipPlatform then hipPlatform:Destroy() end
    end)
    pcall(function()
        local invisSeat = workspace:FindFirstChild("invischair_pwy")
        if invisSeat then invisSeat:Destroy() end
    end)
    
    -- 3. Disconnect ทุก Connection ที่เก็บไว้
    if _G._PwyvConnections then
        for _, conn in ipairs(_G._PwyvConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G._PwyvConnections = {}
    end
    
    -- 4. ลบ Caches ทั้งหมด
    if _G._PwyvCaches then
        for char, cache in pairs(_G._PwyvCaches.ESP or {}) do
            pcall(function()
                if cache.Gui then cache.Gui:Destroy() end
                if cache.Highlight then cache.Highlight:Destroy() end
            end)
        end
        _G._PwyvCaches = nil
    end
    
    -- 5. คืนค่า Character ทั้งหมด
    pcall(function()
        local lpc = Players.LocalPlayer.Character
        if lpc then
            -- คืนค่า CanCollide
            for _, p in ipairs(lpc:GetDescendants()) do
                pcall(function() if p:IsA("BasePart") then p.CanCollide = true end end)
            end
            -- ลบ Fly forces
            local hrp = lpc:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, child in ipairs(hrp:GetChildren()) do
                    if child:IsA("BodyGyro") or child:IsA("BodyVelocity") then
                        child:Destroy()
                    end
                end
            end
            -- คืนค่า Animate
            local animate = lpc:FindFirstChild("Animate")
            if animate then animate.Disabled = false end
            -- คืนค่า CameraSubject
            local hum = lpc:FindFirstChildOfClass("Humanoid")
            if hum then
                workspace.CurrentCamera.CameraSubject = hum
                hum.PlatformStand = false
            end
        end
    end)
    
    -- 6. คืนค่าผู้เล่นอื่น (Hitbox, ESP)
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                    hrp.Material = Enum.Material.SmoothPlastic
                    hrp.CanCollide = true
                end
            end
        end
    end)
    
    -- 7. คืนค่า Camera
    pcall(function()
        workspace.CurrentCamera.FieldOfView = 70
    end)
    pcall(function()
        Players.LocalPlayer.CameraMaxZoomDistance = 400
        Players.LocalPlayer.CameraMinZoomDistance = 5
    end)
    
    -- 8. คืนค่า Lighting
    pcall(function()
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 1
    end)
    
    -- 9. คืนค่า Rendering
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)
    
    -- 10. ลบ FOV Circle
    if _G._PwyvCircle then
        pcall(function()
            _G._PwyvCircle.Visible = false
            _G._PwyvCircle:Remove()
        end)
        _G._PwyvCircle = nil
    end
    
    -- 11. ลบ State ทั้งหมด
    _G._PwyvState = nil
    _G._PwyvRuntime = nil
    
    -- 12. รอให้ RenderStepped จบก่อน (Roblox จัดการ GC เอง)
    task.wait()
end

-- รัน Cleanup ก่อนเริ่มทำงาน (กรณีรันซ้ำ)
ComprehensiveCleanup()

-- ลบ GUI เดิมอีกครั้งเพื่อความชัวร์
for _, n in ipairs({"PhwyverysadModMenu","PhwyverysadDropdowns","PhwyverysadCPicker","NexusESP_Folder"}) do
    local g = CoreGui:FindFirstChild(n); if g then g:Destroy() end
end

-- [ CONFIG ]
-- [ UNIFIED APPLICATION CORE ]
-- Logic: Encapsulate all script data into a single root object to prevent global leaks
-- Algorithm: Use a Proxy Metatable for Config to handle data validation and future signal dispatching
local Phwy = {
    Settings = {},
    State    = {},
    Runtime  = {
        Memory = {
            Connections = {}, ThemeRefs = {}, 
            AllRows = {}, AllRowFrames = {}, Tabs = {}
        },
        Caches = {
            ESP = {}, NPCs = {}, XrayM = {}, XrayP = {}, 
            HitboxOrig = {}, InteractOrig = {}, ValidTargets = {}
        },
        Handles = {
            LockedTarget = nil, FlyBG = nil, FlyBV = nil,
            Loops = {} -- Handles for WS, JP, NC, etc.
        },
        Stats = {
            frameCount = 0, lastFPS = 0, pingValue = 0, lastWarpTick = 0
        }
    }
}

-- [ ENCAPSULATION: Settings Proxy ]
setmetatable(Phwy.Settings, {
    __newindex = function(t, k, v)
        -- Logic: We can add change listeners or validation here in the future
        rawset(t, k, v)
    end
})

-- [ DATA INITIALIZATION ]
local initialConfig = {
    Aimlock = false, AimMode = "HOLD", FOV = 20, AimSmooth = 1, WallCheck = true, TargetMode = 1, EnemyOnly = false, AimTargetPart = "Head", BindType = "Keyboard", BindKey = nil,
    ESPMaster = false, ESPShowName = false, ESPShowHealth = false, ESPShowDistance = false, ESPHighlight = false, ESPTeamCheck = false, ESPTeamColor = false, ESPXray = false, ESPTextSize = 10, ESPFillTrans = 0.5, ESPOutlineTrans = 0.1, ESPColor_C3 = Color3.new(1,1,1),
    P_Master = false, P_ShowName = true, P_ShowHealth = true, P_ShowDist = true, P_Highlight = true, P_TeamCheck = false, P_TeamColor = false, P_Xray = false, P_TextSize = 10, P_FillTrans = 0.5, P_OutlineTrans = 0.1, P_HitboxToggle = false, P_HitboxSize = 32, HitboxTargetMode = "PLAYERS ONLY", P_Color_C3 = Color3.new(1,1,1), P_ESPInFOVOnly = false,
    WalkSpeed = 100, WSToggle = false, JumpPower = 100, JPToggle = false, InfJump = false, FlyToggle = false, FlySpeed = 100, Noclip = false, InfZoom = true, InvisToggle = false, FOVToggle = false, FOVView = 70, FOVColor_C3 = Color3.fromRGB(30,161,255),
AntiAFK = true, FPSBooster = false, FPS_NoShadows = true, FPS_NoParticles = true, FPS_NoClothes = true, FPS_LowQuality = true, HipHeightToggle = false, HipHeightValue = 50, InstantPress = true, AuraRange = false,
    RTX_Enabled = false, ChangeSky_Enabled = false, ChangeSky_Selected = "Anime-sky",
    ShowFPSPing = "FPS & Ping", ShowStatsToggle = true, HUDPosition = "TopRight", TPTarget = "-", TPMode = "Warp", TPFlightSens = 80, TPGOSwitch = false, SpecTarget = "-", SpecToggle = false, ClickTPToggle = false, ClickTPBindType = "Keyboard", ClickTPBindKey = nil, MenuToggleBindType = "Keyboard", MenuToggleBindKey = Enum.KeyCode.G, MenuVisible = true, Theme = "Midnight", 
    GithubURL = "https://github.com/phwyverysad",
    -- Keybinds System: เก็บการตั้งค่าปุ่มสำหรับแต่ละฟีเจอร์
    Keybinds = {
        -- Aimlock Tab
        Aimlock = {Type="Keyboard", Key=Enum.KeyCode.Q, Enabled=false},
        -- ESP Tab  
        P_Master = {Type="Keyboard", Key=Enum.KeyCode.Z, Enabled=false},
        P_HitboxToggle = {Type="Keyboard", Key=Enum.KeyCode.X, Enabled=false},
        -- Player Tab
        WSToggle = {Type="Keyboard", Key=Enum.KeyCode.LeftShift, Enabled=false},
        JPToggle = {Type="Keyboard", Key=Enum.KeyCode.Space, Enabled=false},
        FlyToggle = {Type="Keyboard", Key=Enum.KeyCode.F, Enabled=false},
        Noclip = {Type="Keyboard", Key=Enum.KeyCode.N, Enabled=false},
        InfJump = {Type="Keyboard", Key=Enum.KeyCode.V, Enabled=false},
        InvisToggle = {Type="Keyboard", Key=Enum.KeyCode.I, Enabled=false},
        InfZoom = {Type="Keyboard", Key=Enum.KeyCode.M, Enabled=false},
        FOVToggle = {Type="Keyboard", Key=Enum.KeyCode.P, Enabled=false},
        Fullbright_Toggle = {Type="Keyboard", Key=Enum.KeyCode.B, Enabled=false},
        RemoveFog_Toggle = {Type="Keyboard", Key=Enum.KeyCode.End, Enabled=false},
        AntiAFK = {Type="Keyboard", Key=Enum.KeyCode.Home, Enabled=false},
        FPSBooster = {Type="Keyboard", Key=Enum.KeyCode.Insert, Enabled=false},
        HipHeightToggle = {Type="Keyboard", Key=Enum.KeyCode.PageUp, Enabled=false},
        -- Teleport Tab
        TPGOSwitch = {Type="Keyboard", Key=Enum.KeyCode.T, Enabled=false},
        ClickTPToggle = {Type="Keyboard", Key=Enum.KeyCode.C, Enabled=false},
    }
}
for k, v in pairs(initialConfig) do Phwy.Settings[k] = v end

local initialState = {
    Running = true, ToggleAiming = false, Binding = nil, isMinimized = false, isMaximized = false, isHidden = false, preHideSize = nil,
    originalSize = UDim2.new(0,880,0,570), originalPos = UDim2.new(0.5,-440,0.5,-285),
}
for k, v in pairs(initialState) do Phwy.State[k] = v end

-- [ COMPATIBILITY & ALIASES ]
-- Algorithm: Provide local pointers to internal tables to keep external code functional (100% logic preservation)
local Config        = Phwy.Settings
local State         = Phwy.State
local Runtime       = Phwy.Runtime
local Connections   = Runtime.Memory.Connections
local ESP_Cache     = Runtime.Caches.ESP
local NPCCache      = Runtime.Caches.NPCs
local XrayCache_M   = Runtime.Caches.XrayM
local XrayCache_P   = Runtime.Caches.XrayP
local HitboxOriginalSizes = Runtime.Caches.HitboxOrig
local OriginalInteractData = Runtime.Caches.InteractOrig
local ValidTargets  = Runtime.Caches.ValidTargets
local ThemeRefs     = Runtime.Memory.ThemeRefs
local AllRows       = Runtime.Memory.AllRows
local AllRowFrames  = Runtime.Memory.AllRowFrames
local Tabs          = Runtime.Memory.Tabs
local Stats         = Runtime.Stats -- local reference for HUD variables

local function AddConn(c) 
    table.insert(Connections,c) 
    -- เก็บใน _G เพื่อ cleanup ตอนรันซ้ำ
    if not _G._PwyvConnections then _G._PwyvConnections = {} end
    table.insert(_G._PwyvConnections, c)
    return c 
end
local function RegTR(obj,key,prop) table.insert(ThemeRefs,{obj=obj,key=key,prop=prop}); return obj end
local function TwSpring(obj,t,props) TweenService:Create(obj,TweenInfo.new(t,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),props):Play() end
local function TwBack(obj,t,props)   TweenService:Create(obj,TweenInfo.new(t,Enum.EasingStyle.Back,Enum.EasingDirection.Out),props):Play()   end

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
local MainCorner=Instance.new("UICorner",BgContainer); MainCorner.CornerRadius=UDim.new(0,12)
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
TitleLeft.Size=UDim2.new(0.5,0,1,0); TitleLeft.BackgroundTransparency=1; TitleLeft.ZIndex=5
local TLlyt=Instance.new("UIListLayout",TitleLeft)
TLlyt.FillDirection=Enum.FillDirection.Horizontal; TLlyt.VerticalAlignment=Enum.VerticalAlignment.Center; TLlyt.Padding=UDim.new(0,10)
Instance.new("UIPadding",TitleLeft).PaddingLeft=UDim.new(0,14)

local MacDots=Instance.new("Frame",TitleLeft)
MacDots.Size=UDim2.new(0,62,0,13); MacDots.BackgroundTransparency=1; MacDots.LayoutOrder=1
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
TitleText.Size=UDim2.new(0,100,1,0); TitleText.BackgroundTransparency=1; TitleText.Text="phwyverysad"; TitleText.LayoutOrder=2
TitleText.TextColor3=Color3.fromRGB(185,185,210); TitleText.Font=Enum.Font.GothamBold; TitleText.TextSize=15; TitleText.ZIndex=5
TitleText.TextXAlignment=Enum.TextXAlignment.Left; TitleText.AutomaticSize=Enum.AutomaticSize.X

-- [ GITHUB BUTTON (TAG DESIGN) ]
-- Logic: Redesign as a branded badge with versioning
local GithubBtn = Instance.new("TextButton", TitleLeft)
GithubBtn.Name = "GithubButton"; GithubBtn.LayoutOrder = 3
GithubBtn.Size = UDim2.new(0, 92, 0, 26); GithubBtn.BackgroundColor3 = Colors.PrimaryBlue
GithubBtn.Text = ""; GithubBtn.AutoButtonColor = false; GithubBtn.ZIndex = 10
Corner(GithubBtn, 8); Stroke(GithubBtn, Color3.new(0,0,0), 0.1)

local GBlyt = Instance.new("UIListLayout", GithubBtn)
GBlyt.FillDirection = Enum.FillDirection.Horizontal; GBlyt.Padding = UDim.new(0, 6)
GBlyt.HorizontalAlignment = Enum.HorizontalAlignment.Center; GBlyt.VerticalAlignment = Enum.VerticalAlignment.Center

local GBIcon = Instance.new("ImageLabel", GithubBtn)
GBIcon.Size = UDim2.new(0, 18, 0, 18); GBIcon.BackgroundTransparency = 1
GBIcon.Image = "rbxthumb://type=Asset&id=104260392338381&w=150&h=150"
GBIcon.ImageColor3 = Color3.new(0,0,0); GBIcon.ScaleType = Enum.ScaleType.Fit; GBIcon.ZIndex = 11

local GBText = Instance.new("TextLabel", GithubBtn)
GBText.Size = UDim2.new(0, 45, 1, 0); GBText.BackgroundTransparency = 1
GBText.Text = "v0.0.1"; GBText.TextColor3 = Color3.new(0,0,0)
GBText.Font = Enum.Font.GothamBold; GBText.TextSize = 13; GBText.ZIndex = 11

-- Interactivity Logic
GithubBtn.MouseEnter:Connect(function() 
    Tw(GithubBtn, 0.2, {BackgroundColor3 = Color3.fromRGB(80, 200, 255), Rotation = 2}) 
end)
GithubBtn.MouseLeave:Connect(function() 
    Tw(GithubBtn, 0.2, {BackgroundColor3 = Colors.PrimaryBlue, Rotation = 0}) 
end)
GithubBtn.MouseButton1Down:Connect(function() 
    Tw(GithubBtn, 0.1, {Size = UDim2.new(0, 88, 0, 24)}) 
end)
GithubBtn.MouseButton1Up:Connect(function() 
    TwSpring(GithubBtn, 0.3, {Size = UDim2.new(0, 92, 0, 26)}) 
    if setclipboard then
        setclipboard(Config.GithubURL)
        ShowToast("🔗 คัดลอกลิงก์ GitHub แล้ว!", Colors.Green)
    else
        ShowToast("❌ Executor ไม่รองรับ clipboard", Colors.Red)
    end
end)

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
        MenuBindBtn.Text="  MB"..tostring(Config.MenuToggleBindKey)
    else
        MenuBindBtn.Text="  "..(Config.MenuToggleBindKey and Config.MenuToggleBindKey.Name or "ตั้งปุ่ม")
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

-- [ ULTIMATE HUE RING + SV SQUARE COLOR PICKER ]
local GuiService = game:GetService("GuiService")
local CPGui = Instance.new("ScreenGui", CoreGui); CPGui.Name = "PhwyverysadUltimateCP"; CPGui.DisplayOrder = 2000; CPGui.ResetOnSpawn = false

local DismissBtn = Instance.new("TextButton", CPGui); DismissBtn.Size = UDim2.new(1, 0, 1, 0); DismissBtn.BackgroundTransparency = 1; DismissBtn.Text = ""; DismissBtn.ZIndex = 0; DismissBtn.Visible = false

local CPMain = Instance.new("Frame", CPGui); CPMain.Size = UDim2.new(0, 220, 0, 220); CPMain.BackgroundColor3 = Color3.new(1, 1, 1); CPMain.Visible = false; Corner(CPMain, 999)
local CPStroke = Stroke(CPMain, Color3.fromRGB(200, 200, 210), 1)

local HueRing = Instance.new("ImageLabel", CPMain); HueRing.Size = UDim2.new(1, -10, 1, -10); HueRing.Position = UDim2.new(0.5, 0, 0.5, 0); HueRing.AnchorPoint = Vector2.new(0.5, 0.5)
HueRing.Image = "rbxassetid://6020299385"; HueRing.BackgroundTransparency = 1; HueRing.Active = true

local HueCursor = Instance.new("Frame", HueRing); HueCursor.Size = UDim2.new(0, 14, 0, 14); HueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
HueCursor.BackgroundColor3 = Color3.new(1, 1, 1); Corner(HueCursor, 99); Stroke(HueCursor, Color3.new(0,0,0), 2)

local SVMap = Instance.new("ImageLabel", CPMain); SVMap.Size = UDim2.new(0, 100, 0, 100); SVMap.Position = UDim2.new(0.5, 0, 0.5, 0); SVMap.AnchorPoint = Vector2.new(0.5, 0.5)
SVMap.Image = "rbxassetid://4155801252"; Corner(SVMap, 4); Stroke(SVMap, Color3.fromRGB(200, 200, 210), 1); SVMap.Active = true

local SVCursor = Instance.new("Frame", SVMap); SVCursor.Size = UDim2.new(0, 10, 0, 10); SVCursor.AnchorPoint = Vector2.new(0.5, 0.5)
SVCursor.BackgroundColor3 = Color3.new(1, 1, 1); Corner(SVCursor, 99); Stroke(SVCursor, Color3.new(0,0,0), 1.5)

local CP_D = {H = 0, S = 1, V = 1, callback = nil, dragMode = nil}

local function UpdateCP()
    local color = Color3.fromHSV(CP_D.H, CP_D.S, CP_D.V)
    SVMap.BackgroundColor3 = Color3.fromHSV(CP_D.H, 1, 1)
    if CP_D.callback then CP_D.callback(color) end
end

local function TrackInput()
    if not CP_D.dragMode then return end
    local inset = GuiService:GetGuiInset()
    local mouseLoc = UIS:GetMouseLocation()
    local mousePos = Vector2.new(mouseLoc.X, mouseLoc.Y - inset.Y)
    
    if CP_D.dragMode == "H" then
        local center = HueRing.AbsolutePosition + (HueRing.AbsoluteSize / 2)
        local delta = Vector2.new(mousePos.X - center.X, mousePos.Y - center.Y)
        local angle = math.atan2(delta.Y, delta.X)
        local deg = math.deg(angle)
        local h = (180 - deg) / 360
        CP_D.H = h % 1
        
        local dist = math.clamp(delta.Magnitude, 66, 104)
        HueCursor.Position = UDim2.new(0.5, math.cos(angle) * dist, 0.5, math.sin(angle) * dist)
    elseif CP_D.dragMode == "SV" then
        local pos = SVMap.AbsolutePosition
        local size = SVMap.AbsoluteSize
        local x = math.clamp((mousePos.X - pos.X) / size.X, 0, 1)
        local y = math.clamp((mousePos.Y - pos.Y) / size.Y, 0, 1)
        CP_D.S = x; CP_D.V = 1 - y
        SVCursor.Position = UDim2.new(x, 0, y, 0)
    end
    UpdateCP()
end

HueRing.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        local inset = GuiService:GetGuiInset()
        local mouseLoc = UIS:GetMouseLocation()
        local mousePos = Vector2.new(mouseLoc.X, mouseLoc.Y - inset.Y)
        local center = HueRing.AbsolutePosition + (HueRing.AbsoluteSize / 2)
        local dist = (mousePos - center).Magnitude
        if dist > 65 then 
            CP_D.dragMode = "H"; TrackInput()
        end
    end
end)

SVMap.InputBegan:Connect(function(i) 
    if i.UserInputType == Enum.UserInputType.MouseButton1 then 
        CP_D.dragMode = "SV"; TrackInput() 
    end 
end)

UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then CP_D.dragMode = nil end end)
AddConn(RunService.RenderStepped:Connect(TrackInput))

DismissBtn.MouseButton1Click:Connect(function() 
    if CP_D.dragMode then return end 
    CPMain.Visible = false; DismissBtn.Visible = false
end)

function OpenCPicker(key, pos, cb)
    local c = Config[key] or Color3.new(1,1,1); local h, s, v = c:ToHSV()
    CP_D.H, CP_D.S, CP_D.V = h, s, v
    CP_D.callback = function(nc) Config[key] = nc; if cb then cb(nc) end end
    
    -- Calibrated Restore: h = (180 - deg)/360  => deg = 180 - (h * 360)
    local angle = math.rad(180 - (h * 360))
    HueCursor.Position = UDim2.new(0.5, math.cos(angle) * 85, 0.5, math.sin(angle) * 85)
    SVCursor.Position = UDim2.new(s, 0, 1-v, 0)
    SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    
    local vp = Camera.ViewportSize
    CPMain.Position = UDim2.new(0, math.clamp(pos.X + 80, 10, vp.X - 230), 0, math.clamp(pos.Y - 110, 10, vp.Y - 230))
    CPMain.Visible = true; DismissBtn.Visible = true; CPMain.Size = UDim2.new(0,0,0,0); TwBack(CPMain, 0.35, {Size = UDim2.new(0, 220, 0, 220)})
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
-- Toast System with queue and rapid-toggle support
local ToastActiveTween = nil
local ToastHideThread = nil

local function ShowToast(msg, col)
    -- Cancel any pending hide operation
    if ToastHideThread then
        task.cancel(ToastHideThread)
        ToastHideThread = nil
    end
    
    -- Set text and color immediately
    ToastLbl.Text = msg
    ToastLbl.TextColor3 = col or Colors.PrimaryBlue
    Toast.Visible = true
    
    -- If already visible, flash briefly then animate in fresh
    if Toast.Position.Y.Scale < 0.95 then
        -- Toast is currently showing, flash it quickly
        Toast.Position = UDim2.new(0.5, -120, 1, -50)
        TwBack(Toast, 0.15, {Position = UDim2.new(0.5, -120, 1, -54)})
    else
        -- Toast is hidden, animate in normally
        Toast.Position = UDim2.new(0.5, -120, 1, 10)
        TwBack(Toast, 0.25, {Position = UDim2.new(0.5, -120, 1, -54)})
    end
    
    -- Schedule hide with new thread
    ToastHideThread = task.delay(1.8, function()
        Tw(Toast, 0.2, {Position = UDim2.new(0.5, -120, 1, 10)})
        task.wait(0.21)
        if Toast.Position.Y.Scale >= 0.95 then
            Toast.Visible = false
        end
        ToastHideThread = nil
    end)
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
    for _,cn in pairs({WS_Loop,JP_Loop,NC_Conn,IJ_Conn,AFK_Conn,FPS_DescConn,SafeTP_Conn}) do if cn then pcall(function() cn:Disconnect() end) end end
    Tw(MainFrame,0.22,{Size=UDim2.new(0,W*0.45,0,H*0.45),Position=UDim2.new(0.5,-W*0.225,0.5,-H*0.225)})
    task.delay(0.23,function() pcall(function() FloatingLayer:Destroy() end); pcall(function() CPGui:Destroy() end); pcall(function() ScreenGui:Destroy() end) end)
end

-- [ CONFIRMATION DIALOG ]
-- Algorithm: Create a modal backdrop with a smooth scale-in transition
local function ShowConfirm(title, desc, onYes)
    local ModalBackdrop = Instance.new("TextButton", ScreenGui)
    ModalBackdrop.Size = UDim2.new(1, 0, 1, 0); ModalBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    ModalBackdrop.BackgroundTransparency = 1; ModalBackdrop.Text = ""; ModalBackdrop.AutoButtonColor = false; ModalBackdrop.ZIndex = 500
    Tw(ModalBackdrop, 0.3, {BackgroundTransparency = 0.5})

    local Dialog = Instance.new("Frame", ModalBackdrop)
    Dialog.Size = UDim2.new(0, 320, 0, 160); Dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
    Dialog.AnchorPoint = Vector2.new(0.5, 0.5); Dialog.BackgroundColor3 = Colors.WindowBg; Dialog.ZIndex = 501
    Corner(Dialog, 16); Stroke(Dialog, Colors.Stroke, 1); Dialog.ClipsDescendants = true
    Dialog.Size = UDim2.new(0, 0, 0, 0); TwSpring(Dialog, 0.5, {Size = UDim2.new(0, 320, 0, 160)})

    local T = Instance.new("TextLabel", Dialog)
    T.Size = UDim2.new(1, 0, 0, 50); T.BackgroundTransparency = 1
    T.Text = title; T.TextColor3 = Colors.TextMain; T.Font = Enum.Font.GothamBold; T.TextSize = 18; T.ZIndex = 502

    local D = Instance.new("TextLabel", Dialog)
    D.Size = UDim2.new(1, -40, 0, 40); D.Position = UDim2.new(0, 20, 0, 45); D.BackgroundTransparency = 1
    D.Text = desc; D.TextColor3 = Colors.TextSub; D.Font = Enum.Font.GothamMedium; D.TextSize = 14; D.TextWrapped = true; D.ZIndex = 502

    local BtnGroup = Instance.new("Frame", Dialog)
    BtnGroup.Size = UDim2.new(1, -40, 0, 36); BtnGroup.Position = UDim2.new(0, 20, 1, -56); BtnGroup.BackgroundTransparency = 1; BtnGroup.ZIndex = 502
    local BLyt = Instance.new("UIListLayout", BtnGroup); BLyt.FillDirection = Enum.FillDirection.Horizontal; BLyt.Padding = UDim.new(0, 12); BLyt.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local function MakeBtn(txt, col, click)
        local b = Instance.new("TextButton", BtnGroup); b.Size = UDim2.new(0.45, 0, 1, 0); b.BackgroundColor3 = col
        b.Text = txt; b.TextColor3 = Colors.TextMain; b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.ZIndex = 503; Corner(b, 10)
        b.MouseButton1Click:Connect(function()
            Tw(Dialog, 0.2, {Size = UDim2.new(0, 0, 0, 0)})
            Tw(ModalBackdrop, 0.2, {BackgroundTransparency = 1})
            task.delay(0.2, function() ModalBackdrop:Destroy() end)
            if click then click() end
        end)
    end
    MakeBtn("ยกเลิก", Color3.fromRGB(60, 60, 80))
    MakeBtn("ยืนยัน", Colors.Red, onYes)
end

DotRed.MouseButton1Click:Connect(function()
    ShowConfirm("ยืนยันการปิดสคริปต์", "คุณแน่ใจหรือไม่ว่าต้องการปิดเมนูและหยุดการทำงานทั้งหมด?", function()
        FullUnload()
    end)
end)
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
    function E:Toggle(t,st,key,onChange,customText,keybindName)
        local _,C=Row(t,st); local isOn=Config[key]
        -- If keybind enabled, adjust layout
        -- Auto-create keybind entry if not exists
        if keybindName then
            if not Config.Keybinds[keybindName] then
                Config.Keybinds[keybindName] = {Type=nil, Key=nil, Enabled=false}
            end
        end
        local hasKeybind = keybindName ~= nil
        
        local Stat=Instance.new("TextLabel",C); 
        if hasKeybind then
            Stat.Size=UDim2.new(0,25,1,0)
        else
            Stat.Size=UDim2.new(0,30,1,0)
        end
        Stat.BackgroundTransparency=1
        Stat.Text=isOn and(customText and customText[1] or "On")or(customText and customText[2] or "Off")
        Stat.TextColor3=isOn and Colors.Green or Color3.fromRGB(120,120,140); Stat.Font=Enum.Font.GothamBold; Stat.TextSize=13; Stat.TextXAlignment=Enum.TextXAlignment.Right
        
        -- Keybind Button (if enabled)
        local KeyBtn, ClearBtn
        if hasKeybind then
            -- Container for keybind buttons
            local KeybindContainer = Instance.new("Frame",C)
            KeybindContainer.Size=UDim2.new(0,70,0,22)
            KeybindContainer.BackgroundTransparency=1
            KeybindContainer.LayoutOrder=1
            
            KeyBtn=Instance.new("TextButton",KeybindContainer)
            KeyBtn.Size=UDim2.new(0,50,0,22)
            KeyBtn.Position=UDim2.new(0,0,0,0)
            KeyBtn.BackgroundColor3=Colors.DarkElement
            KeyBtn.TextColor3=Colors.TextSub
            KeyBtn.Font=Enum.Font.GothamBold
            KeyBtn.TextSize=10
            KeyBtn.AutoButtonColor=false
            Corner(KeyBtn,6)
            local KBS=Stroke(KeyBtn,Colors.Stroke,0.8)
            
            -- Clear button (×)
            ClearBtn=Instance.new("TextButton",KeybindContainer)
            ClearBtn.Size=UDim2.new(0,18,0,22)
            ClearBtn.Position=UDim2.new(0,52,0,0)
            ClearBtn.BackgroundColor3=Color3.fromRGB(80,60,60)
            ClearBtn.TextColor3=Colors.TextSub
            ClearBtn.Font=Enum.Font.GothamBold
            ClearBtn.TextSize=12
            ClearBtn.Text="×"
            ClearBtn.AutoButtonColor=false
            Corner(ClearBtn,6)
            local ClearStroke=Stroke(ClearBtn,Color3.fromRGB(120,80,80),0.8)
            
            local function UpdateKeyDisplay()
                local kb=Config.Keybinds[keybindName]
                if kb and kb.Enabled and kb.Key then
                    if kb.Type=="Mouse" then
                        KeyBtn.Text="🖱️M"..tostring(kb.Key)
                        KeyBtn.TextColor3=Colors.PrimaryBlue
                    else
                        local keyName=kb.Key.Name:gsub("Enum.KeyCode.","")
                        KeyBtn.Text=""..keyName:sub(1,3)
                        KeyBtn.TextColor3=Colors.PrimaryBlue
                    end
                    -- Show clear button when keybind is set
                    ClearBtn.Visible=true
                    KeybindContainer.Size=UDim2.new(0,70,0,22)
                else
                    KeyBtn.Text="กด..."
                    KeyBtn.TextColor3=Colors.TextSub
                    -- Hide clear button when no keybind
                    ClearBtn.Visible=false
                    KeybindContainer.Size=UDim2.new(0,50,0,22)
                end
            end
            UpdateKeyDisplay()
            
            KeyBtn.MouseEnter:Connect(function() 
                Tw(KeyBtn,0.15,{BackgroundColor3=Color3.fromRGB(58,58,75)})
                Tw(KBS,0.15,{Color=Colors.PrimaryBlue,Thickness=1.2})
            end)
            KeyBtn.MouseLeave:Connect(function() 
                if not State.Binding then
                    Tw(KeyBtn,0.15,{BackgroundColor3=Colors.DarkElement})
                    Tw(KBS,0.15,{Color=Colors.Stroke,Thickness=0.8})
                end
            end)
            KeyBtn.MouseButton1Click:Connect(function()
                KeyBtn.Text="[กด]"
                Tw(KeyBtn,0.15,{BackgroundColor3=Colors.PrimaryBlue})
                State.Binding=function(io,k)
                    local kb=Config.Keybinds[keybindName]
                    kb.Type=io
                    kb.Key=k
                    kb.Enabled=true
                    Tw(KeyBtn,0.2,{BackgroundColor3=Colors.DarkElement})
                    Tw(KBS,0.2,{Color=Colors.Stroke,Thickness=0.8})
                    UpdateKeyDisplay()
                    ShowToast("🔧 ตั้งค่าปุ่ม "..t..": "..(io=="Mouse" and "MB"..tostring(k) or k.Name),Colors.PrimaryBlue)
                end
            end)
            
            -- Clear button events
            ClearBtn.MouseEnter:Connect(function()
                Tw(ClearBtn,0.15,{BackgroundColor3=Colors.Red,TextColor3=Color3.new(1,1,1)})
                Tw(ClearStroke,0.15,{Color=Colors.Red,Thickness=1.2})
            end)
            ClearBtn.MouseLeave:Connect(function()
                Tw(ClearBtn,0.15,{BackgroundColor3=Color3.fromRGB(80,60,60),TextColor3=Colors.TextSub})
                Tw(ClearStroke,0.15,{Color=Color3.fromRGB(120,80,80),Thickness=0.8})
            end)
            ClearBtn.MouseButton1Click:Connect(function()
                local kb=Config.Keybinds[keybindName]
                if kb then
                    kb.Enabled=false
                    kb.Key=nil
                    kb.Type=nil
                    UpdateKeyDisplay()
                    ShowToast("ลบปุ่ม "..t.." แล้ว",Colors.Red)
                end
            end)
            
            -- Update display periodically
            AddConn(RunService.RenderStepped:Connect(function()
                UpdateKeyDisplay()
            end))
        end
        
        local Track=Instance.new("TextButton",C); Track.Size=UDim2.new(0,46,0,26); Track.Text=""
        Track.ZIndex=2
        Track.BackgroundColor3=isOn and Colors.PrimaryBlue or Colors.Toggle_Off; Track.AutoButtonColor=false; Corner(Track,99)
        local TS=Stroke(Track,isOn and Colors.AccentGlow or Color3.fromRGB(70,70,90),0.8)
        local Circ=Instance.new("Frame",Track); Circ.Size=UDim2.new(0,20,0,20)
        Circ.Position=isOn and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)
        Circ.BackgroundColor3=Color3.new(1,1,1); Corner(Circ,99)
        local CG=Instance.new("Frame",Circ); CG.Size=UDim2.new(0,7,0,7); CG.Position=UDim2.new(0.5,-3.5,0.5,-3.5)
        CG.BackgroundColor3=Colors.PrimaryBlue; CG.BackgroundTransparency=isOn and 0.2 or 1; CG.BorderSizePixel=0; Corner(CG,99)
        
        -- Store UI references for external updates
        if not State.ToggleUIRefs then State.ToggleUIRefs = {} end
        State.ToggleUIRefs[key] = {
            Stat = Stat,
            Track = Track,
            Circ = Circ,
            CG = CG,
            TS = TS,
            customText = customText,
            onChange = onChange
        }
        
        -- Function to update toggle UI
        local function UpdateToggleUI()
            local on = Config[key]
            Stat.Text=on and(customText and customText[1] or "On")or(customText and customText[2] or "Off")
            Tw(Stat,0.2,{TextColor3=on and Colors.Green or Color3.fromRGB(120,120,140)})
            Tw(Track,0.25,{BackgroundColor3=on and Colors.PrimaryBlue or Colors.Toggle_Off})
            Tw(TS,0.25,{Color=on and Colors.AccentGlow or Color3.fromRGB(70,70,90),Thickness=0.8})
            Tw(Circ,0.15,{Size=UDim2.new(0,26,0,20)})
            task.delay(0.12, function() TwSpring(Circ,0.35,{Size=UDim2.new(0,20,0,20),Position=on and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)}) end)
            Tw(CG,0.25,{BackgroundTransparency=on and 0.2 or 1})
        end
        
        Track.MouseEnter:Connect(function() Tw(TS,0.2,{Thickness=1.3,Color=Config[key] and Colors.PrimaryBlue or Color3.fromRGB(100,100,120)}) end)
        Track.MouseLeave:Connect(function() Tw(TS,0.2,{Thickness=0.8,Color=Config[key] and Colors.AccentGlow or Color3.fromRGB(70,70,90)}) end)
        Track.MouseButton1Click:Connect(function()
            Config[key]=not Config[key]
            UpdateToggleUI()
            if onChange then onChange(Config[key]) end
            -- Toast notification สำหรับทุก Toggle
            local isEnabled = Config[key]
            local emoji = isEnabled and "✅" or "❌"
            local action = isEnabled and "เปิด" or "ปิด"
            local toastColor = isEnabled and Colors.Green or Colors.Red
            ShowToast(emoji .. " " .. action .. " : " .. t, toastColor)
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
        local BArr=Instance.new("TextLabel",B); BArr.Size=UDim2.new(0,20,1,0); BArr.Position=UDim2.new(1,-22,0,0); BArr.BackgroundTransparency=1; BArr.Text="☯"; BArr.TextColor3=Colors.PrimaryBlue; BArr.TextSize=15
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

    -- Keybind (New: สำหรับ Hotkeys Tab - มี Toggle เปิด/ปิดการใช้งานปุ่ม)
    function E:Keybind(featureName, featureKey, defaultType, defaultKey, onToggle)
        local R,C=Row(featureName, "กดปุ่มเพื่อเปิด/ปิดฟังชั่นนี้")
        
        -- สร้าง Container สำหรับปุ่ม
        local BtnContainer = Instance.new("Frame", C)
        BtnContainer.Size = UDim2.new(0, 140, 0, 34)
        BtnContainer.BackgroundTransparency = 1
        
        local Lyt = Instance.new("UIListLayout", BtnContainer)
        Lyt.FillDirection = Enum.FillDirection.Horizontal
        Lyt.Padding = UDim.new(0, 6)
        Lyt.HorizontalAlignment = Enum.HorizontalAlignment.Right
        Lyt.VerticalAlignment = Enum.VerticalAlignment.Center
        
        -- ปุ่ม Toggle เปิด/ปิดการใช้งาน Keybind
        local ToggleBtn = Instance.new("TextButton", BtnContainer)
        ToggleBtn.Size = UDim2.new(0, 36, 0, 28)
        ToggleBtn.BackgroundColor3 = Colors.Toggle_Off
        ToggleBtn.Text = "OFF"
        ToggleBtn.TextColor3 = Colors.TextSub
        ToggleBtn.Font = Enum.Font.GothamBold
        ToggleBtn.TextSize = 10
        ToggleBtn.AutoButtonColor = false
        Corner(ToggleBtn, 8)
        
        -- ปุ่มตั้งค่า Key
        local KeyBtn = Instance.new("TextButton", BtnContainer)
        KeyBtn.Size = UDim2.new(0, 90, 0, 28)
        KeyBtn.BackgroundColor3 = Colors.DarkElement
        KeyBtn.TextColor3 = Colors.TextMain
        KeyBtn.Font = Enum.Font.GothamBold
        KeyBtn.TextSize = 12
        KeyBtn.AutoButtonColor = false
        KeyBtn.TextTruncate = Enum.TextTruncate.AtEnd
        Corner(KeyBtn, 8)
        local KeyBS = Stroke(KeyBtn, Colors.Stroke, 1)
        
        -- ฟังก์ชันอัพเดตการแสดงผล
        local function UpdateDisplay()
            local kb = Config.Keybinds[featureKey]
            if not kb then
                kb = {Type=defaultType or "Keyboard", Key=defaultKey or Enum.KeyCode.Q, Enabled=false}
                Config.Keybinds[featureKey] = kb
            end
            
            -- อัพเดตปุ่ม Toggle
            if kb.Enabled then
                ToggleBtn.Text = "ON"
                ToggleBtn.BackgroundColor3 = Colors.Green
                ToggleBtn.TextColor3 = Color3.new(1,1,1)
            else
                ToggleBtn.Text = "OFF"
                ToggleBtn.BackgroundColor3 = Colors.Toggle_Off
                ToggleBtn.TextColor3 = Colors.TextSub
            end
            
            -- อัพเดตปุ่ม Key
            if kb.Type == "Mouse" then
                KeyBtn.Text = "🖱️ MB" .. tostring(kb.Key)
            else
                KeyBtn.Text = " " .. (kb.Key and kb.Key.Name or "None")
            end
        end
        
        UpdateDisplay()
        
        -- Event: Toggle เปิด/ปิดการใช้งาน
        ToggleBtn.MouseEnter:Connect(function() 
            Tw(ToggleBtn, 0.15, {BackgroundColor3 = ToggleBtn.Text=="ON" and Color3.fromRGB(80,255,120) or Color3.fromRGB(70,70,90)})
        end)
        ToggleBtn.MouseLeave:Connect(function() 
            Tw(ToggleBtn, 0.15, {BackgroundColor3 = ToggleBtn.Text=="ON" and Colors.Green or Colors.Toggle_Off})
        end)
        ToggleBtn.MouseButton1Click:Connect(function()
            local kb = Config.Keybinds[featureKey]
            kb.Enabled = not kb.Enabled
            UpdateDisplay()
            if onToggle then onToggle(kb.Enabled) end
            ShowToast(kb.Enabled and "✅ เปิดใช้งานปุ่ม: " .. featureName or "❌ ปิดใช้งานปุ่ม: " .. featureName, kb.Enabled and Colors.Green or Colors.Red)
        end)
        
        -- Event: ตั้งค่า Key
        KeyBtn.MouseEnter:Connect(function() Tw(KeyBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(58,58,75)}); Tw(KeyBS, 0.15, {Color = Colors.PrimaryBlue}) end)
        KeyBtn.MouseLeave:Connect(function() if not State.Binding then Tw(KeyBtn, 0.15, {BackgroundColor3 = Colors.DarkElement}); Tw(KeyBS, 0.15, {Color = Colors.Stroke}) end end)
        KeyBtn.MouseButton1Click:Connect(function()
            KeyBtn.Text = "[ กดปุ่ม... ]"; Tw(KeyBtn, 0.15, {BackgroundColor3 = Colors.PrimaryBlue})
            State.Binding = function(io, k)
                local kb = Config.Keybinds[featureKey]
                kb.Type = io
                kb.Key = k
                Tw(KeyBtn, 0.2, {BackgroundColor3 = Colors.DarkElement}); Tw(KeyBS, 0.2, {Color = Colors.Stroke})
                UpdateDisplay()
                ShowToast("🔧 ตั้งค่าปุ่ม " .. featureName .. " เป็น: " .. (io=="Mouse" and "MB"..tostring(k) or k.Name), Colors.PrimaryBlue)
            end
        end)
        
        -- เก็บ reference สำหรับอัพเดตภายหลัง
        AddConn(RunService.RenderStepped:Connect(function()
            local kb = Config.Keybinds[featureKey]
            if kb then
                local expectedText = kb.Enabled and "ON" or "OFF"
                if ToggleBtn.Text ~= expectedText then
                    UpdateDisplay()
                end
            end
        end))
        
        return {Toggle = ToggleBtn, Key = KeyBtn, Update = UpdateDisplay}
    end

    -- RunButton
    function E:RunButton(t,st,btnTxt,col,onClick)
        local _,C = Row(t,st)
        local Btn = Instance.new("TextButton",C); Btn.Size=UDim2.new(0,135,0,30); Btn.BackgroundColor3=col or Colors.PrimaryBlue
        Btn.Text=""; Btn.AutoButtonColor=false; Corner(Btn,8); local BS=Stroke(Btn,Colors.Stroke,1)
        
        -- Logic: If text is provided, show it; if specific icon requested, show icon
        local BtnContent = Instance.new("Frame",Btn); BtnContent.Size=UDim2.new(1,0,1,0); BtnContent.BackgroundTransparency=1
        local BCLyt = Instance.new("UIListLayout",BtnContent); BCLyt.FillDirection=Enum.FillDirection.Horizontal; BCLyt.HorizontalAlignment=Enum.HorizontalAlignment.Center; BCLyt.VerticalAlignment=Enum.VerticalAlignment.Center; BCLyt.Padding=UDim.new(0,6)

        if btnTxt == "ICON_CLICK" then
            Btn.Size = UDim2.new(0, 80, 0, 30)
            local ClickIcon = Instance.new("ImageLabel",BtnContent); ClickIcon.Size=UDim2.new(0,18,0,18)
            ClickIcon.BackgroundTransparency=1; ClickIcon.Image="rbxthumb://type=Asset&id=9728118922&w=150&h=150"
            ClickIcon.ImageColor3=Colors.TextMain; ClickIcon.ScaleType=Enum.ScaleType.Fit
        else
            local Lbl = Instance.new("TextLabel",BtnContent); Lbl.Size=UDim2.new(1,0,1,0); Lbl.BackgroundTransparency=1
            Lbl.Text=btnTxt; Lbl.TextColor3=Colors.TextMain; Lbl.Font=Enum.Font.GothamBold; Lbl.TextSize=13
        end

        Btn.MouseEnter:Connect(function() Tw(Btn,0.15,{BackgroundColor3=(col or Colors.PrimaryBlue):Lerp(Color3.new(1,1,1),0.14)}); Tw(BS,0.15,{Color=Colors.AccentGlow}) end)
        Btn.MouseLeave:Connect(function() Tw(Btn,0.15,{BackgroundColor3=col or Colors.PrimaryBlue}); Tw(BS,0.15,{Color=Colors.Stroke}) end)
        Btn.MouseButton1Down:Connect(function() Tw(Btn,0.08,{BackgroundColor3=(col or Colors.PrimaryBlue):Lerp(Color3.new(0,0,0),0.18)}) end)
        Btn.MouseButton1Up:Connect(function() Tw(Btn,0.18,{BackgroundColor3=col or Colors.PrimaryBlue}) end)
        Btn.MouseButton1Click:Connect(function() if onClick then onClick() end end)
        return Btn
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

-- [ UNIVERSAL CHARACTER PARTS FINDER ]
local function GetCharacterParts(char)
    if not char or not char:IsA("Model") then return nil, nil, nil end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then 
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Humanoid") then
                humanoid = obj
                break
            end
        end
    end
    
    local head = char:FindFirstChild("Head")
    if not head and humanoid then
        head = humanoid.Parent:FindFirstChild("Head")
    end
    if not head then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():match("head") or part.Name:lower():match("face")) then
                head = part
                break
            end
        end
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp and humanoid then
        hrp = humanoid.RootPart
    end
    if not hrp then
        hrp = char.PrimaryPart
    end
    if not hrp then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():match("torso") or part.Name:lower():match("body") or part.Name:lower():match("root") or part.Name:lower():match("main")) then
                hrp = part
                break
            end
        end
    end
    if not hrp then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                hrp = part
                break
            end
        end
    end
    
    return head, hrp, humanoid
end

-- [ AIMLOCK TARGET PART SELECTOR ]
local function GetTargetPart(char)
    if not char or not char:IsA("Model") then return nil end
    
    local head, hrp, humanoid = GetCharacterParts(char)
    local targetMode = Config.AimTargetPart or "Auto"
    
    if targetMode == "Head" then
        return head or hrp
    elseif targetMode == "Torso" then
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso")
        if not torso and humanoid then
            torso = humanoid.RootPart
        end
        return torso or hrp or head
    elseif targetMode == "HumanoidRootPart" then
        return hrp or head
    else
        if head then return head end
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if torso then return torso end
        return hrp or char:FindFirstChildWhichIsA("BasePart")
    end
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

-- [ GRAPHIC / SKY SYSTEM ]
local OriginalSky = nil
pcall(function()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") then OriginalSky = obj:Clone(); break end
    end
end)

local SkyOptions = {
    ["Anime-sky"] = "13107361022",
    ["Obby-Sky"] = "127719608807122",
    ["CakeUp-Night-Sky-Galaxy-Planets"] = "15983996673",
    ["Night-sky"] = "90988519",
    ["Pink-sky"] = "8202961731",
    ["Night-Sky-With-Effects"] = "4951222008",
    ["Sky"] = "116402178504134",
    ["Starry-night-sky"] = "911025794",
    ["Space-Sky"] = "11675661848",
    ["Cartoon-Sky"] = "15313376186",
    ["Galaxy-Nebula-Space-Sky"] = "18618101697",
    ["Map-Minecraft-Sky"] = "10594760952",
    ["Minecraft-Sky"] = "8735253332",
    ["Galaxy-Sky"] = "11284918730",
    ["Clear-Blue-Sky-Skybox"] = "18586545848",
    ["Space-Sky-HD"] = "16262385808",
    ["Green-Screen-Sky-by-Flebsy"] = "5222782366",
    ["Great-Ocean-Road-Sky"] = "15502603038",
    ["Nebulous-Night-Sky"] = "136350850692118"
}

local SkyList = {
    "Anime-sky",
    "Obby-Sky",
    "CakeUp-Night-Sky-Galaxy-Planets",
    "Night-sky",
    "Pink-sky",
    "Night-Sky-With-Effects",
    "Sky",
    "Starry-night-sky",
    "Space-Sky",
    "Cartoon-Sky",
    "Galaxy-Nebula-Space-Sky",
    "Map-Minecraft-Sky",
    "Minecraft-Sky",
    "Galaxy-Sky",
    "Clear-Blue-Sky-Skybox",
    "Space-Sky-HD",
    "Green-Screen-Sky-by-Flebsy",
    "Great-Ocean-Road-Sky",
    "Nebulous-Night-Sky"
}

local function ApplySkyById(assetId)
    pcall(function()
        local objects = game:GetObjects("rbxassetid://"..assetId)
        local newSky = nil
        for _, obj in pairs(objects) do
            if obj:IsA("Sky") then newSky = obj; break
            elseif obj:FindFirstChildWhichIsA("Sky") then newSky = obj:FindFirstChildWhichIsA("Sky"); break end
        end
        if newSky then
            for _, oldObj in ipairs(Lighting:GetChildren()) do
                if oldObj:IsA("Sky") then oldObj:Destroy() end
            end
            newSky.Parent = Lighting
        end
    end)
end

local function ResetSky()
    pcall(function()
        for _, oldObj in ipairs(Lighting:GetChildren()) do
            if oldObj:IsA("Sky") then oldObj:Destroy() end
        end
        if OriginalSky then
            local cloned = OriginalSky:Clone()
            cloned.Parent = Lighting
        end
    end)
end

local function SetChangeSky(on)
    if on then
        local id = SkyOptions[Config.ChangeSky_Selected]
        if id then ApplySkyById(id) end
    else
        ResetSky()
    end
end

local RTXLoaded = false
local function SetRTX(on)
    if on and not RTXLoaded then
        ShowConfirm(
            "ระวัง! Ray Tracing กินทรัพยากรสูง",
            "การเปิดใช้งาน Ray Tracing จะกินทรัพยากรเครื่องมากขึ้น อาจทำให้เกมกระตุกหรือ FPS ตก คุณต้องการเปิดใช้งานหรือไม่?",
            function()
                pcall(function()
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/phwyverysad/script-roblox/refs/heads/main/rtx.lua"))()
                end)
                RTXLoaded = true
                Config.RTX_Enabled = true
                pcall(function() UpdateToggleUIFromKeybind("RTX_Enabled") end)
                ShowToast("✅ เปิด Ray Tracing แล้ว", Colors.Green)
            end
        )
        -- ถ้ายกเลิก confirm ให้ rollback toggle เป็น false
        task.delay(0.05, function()
            if not RTXLoaded then
                Config.RTX_Enabled = false
                pcall(function() UpdateToggleUIFromKeybind("RTX_Enabled") end)
            end
        end)
    elseif not on then
        Config.RTX_Enabled = false
        ShowToast("❌ Ray Tracing ไม่สามารถปิดได้ทันที กรุณารันสคริปต์ใหม่หากต้องการปิด", Colors.Red)
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

local function SetAntiAFK(on) if AFK_Conn then AFK_Conn:Disconnect(); AFK_Conn=nil end; if on and VirtualUser then AFK_Conn=LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end end
local function SetAntiStun(on)
    if AntiStun_Loop then AntiStun_Loop:Disconnect(); AntiStun_Loop=nil end
    if on then
        AntiStun_Loop=RunService.Stepped:Connect(function()
            pcall(function()
                local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
                    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
                    h.PlatformStand=false
                    h.Sit=false
                    if h.WalkSpeed<16 then h.WalkSpeed=16 end
                    if h.JumpPower<50 then h.JumpPower=50 end
                end
            end)
        end)
    end
end
local _origMaxZoom = LocalPlayer.CameraMaxZoomDistance
local _origMinZoom = 0.5  -- Roblox default min zoom (first-person)
local function SetInfZoom(on)
    if on then
        _origMaxZoom = LocalPlayer.CameraMaxZoomDistance -- save current max
        LocalPlayer.CameraMaxZoomDistance = math.huge    -- unlimited max zoom
        LocalPlayer.CameraMinZoomDistance = 0            -- allow first-person (min zoom)
    else
        LocalPlayer.CameraMaxZoomDistance = _origMaxZoom  -- restore max
        LocalPlayer.CameraMinZoomDistance = _origMinZoom           -- restore default min (allow first-person)
    end
end
local function UpdateInteractables()
    local function ProcessPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") then return end
        if not OriginalInteractData[prompt] then
            pcall(function()
                OriginalInteractData[prompt] = {
                    HoldDuration = prompt.HoldDuration,
                    MaxActivationDistance = prompt.MaxActivationDistance
                }
            end)
        end
        local orig = OriginalInteractData[prompt]
        if Config.InstantPress then
            pcall(function() prompt.HoldDuration = 0 end)
        elseif orig then
            pcall(function() prompt.HoldDuration = orig.HoldDuration end)
        end
        if Config.AuraRange then
            pcall(function() prompt.MaxActivationDistance = 50 end)
        elseif orig then
            pcall(function() prompt.MaxActivationDistance = orig.MaxActivationDistance end)
        end
    end
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do ProcessPrompt(v) end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do ProcessPrompt(v) end
            end
            if plr:FindFirstChild("Backpack") then
                for _, v in ipairs(plr.Backpack:GetDescendants()) do ProcessPrompt(v) end
            end
        end
    end)
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

-- HipHeight System v2 - รองรับทุกพื้นที่และสิ่งกีดขวางด้วย Raycast
local HipHeight_Platform = nil
local HipHeight_Loop = nil
local HipHeight_RayParams = nil
local HipHeight_IgnoreList = {}

local function ShouldIgnoreForRaycast(obj)
    if not obj then return true end
    if not obj:IsA("BasePart") then return true end
    -- ข้าม fog, particles, effects
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then return true end
    -- ข้าม objects ที่โปร่งใสและไม่มี collision
    if obj.Transparency >= 0.95 and not obj.CanCollide then return true end
    -- ข้าม objects ที่มี CanCollide = false และไม่ใช่พื้นหลัก
    if not obj.CanCollide and obj.Name ~= "Terrain" then
        -- ตรวจสอบชื่อที่มักเป็น effects
        local name = obj.Name:lower()
        if name:find("fog") or name:find("cloud") or name:find("mist") or name:find("smoke") or 
           name:find("fire") or name:find("spark") or name:find("aura") or name:find("glow") then
            return true
        end
    end
    return false
end

local function InitHipHeightRayParams()
    if HipHeight_RayParams then return end
    HipHeight_RayParams = RaycastParams.new()
    HipHeight_RayParams.FilterType = Enum.RaycastFilterType.Blacklist
    HipHeight_RayParams.IgnoreWater = true
end

local function UpdateHipHeightIgnoreList()
    HipHeight_IgnoreList = {}
    -- เก็บ effects ต่างๆ ใน workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if ShouldIgnoreForRaycast(obj) then
            table.insert(HipHeight_IgnoreList, obj)
        end
    end
end

local function GetGroundHeight(position)
    InitHipHeightRayParams()
    -- อัพเดต blacklist
    local char = LocalPlayer.Character
    local blacklist = {}
    
    -- เพิ่มตัวละครตัวเอง
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(blacklist, part)
            end
        end
    end
    
    -- เพิ่มแพลตฟอร์มตัวเอง
    if HipHeight_Platform then
        table.insert(blacklist, HipHeight_Platform)
    end
    
    -- เพิ่ม effects ที่ต้องข้าม (อัพเดตทุก 2 วินาที)
    if math.random(1, 60) == 1 then
        UpdateHipHeightIgnoreList()
    end
    for _, obj in ipairs(HipHeight_IgnoreList) do
        if obj and obj.Parent then
            table.insert(blacklist, obj)
        end
    end
    
    HipHeight_RayParams.FilterDescendantsInstances = blacklist
    HipHeight_RayParams.IgnoreWater = true
    
    -- Raycast หลายระดับเพื่อหาพื้นที่แข็งจริง
    local checks = {
        {startY = 500, dir = -1000},
        {startY = 200, dir = -400},
        {startY = 100, dir = -200},
    }
    
    for _, check in ipairs(checks) do
        local rayStart = Vector3.new(position.X, check.startY, position.Z)
        local rayDirection = Vector3.new(0, check.dir, 0)
        
        local result = workspace:Raycast(rayStart, rayDirection, HipHeight_RayParams)
        if result then
            local hitPart = result.Instance
            -- ตรวจสอบว่าเป็นพื้นที่แข็งจริง
            if hitPart and hitPart.CanCollide and not ShouldIgnoreForRaycast(hitPart) then
                return result.Position.Y, result.Position
            end
        end
    end
    
    return nil, nil
end

local function SetHipHeight(on)
    if HipHeight_Loop then HipHeight_Loop:Disconnect(); HipHeight_Loop = nil end
    if HipHeight_Platform then pcall(function() HipHeight_Platform:Destroy() end); HipHeight_Platform = nil end
    
    if on then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        -- หาความสูงพื้นปัจจุบัน
        local groundY, _ = GetGroundHeight(hrp.Position)
        if not groundY then groundY = hrp.Position.Y - 3 end
        
        -- สร้างพื้นล่องหน
        HipHeight_Platform = Instance.new("Part")
        HipHeight_Platform.Name = "HipHeightPlatform"
        HipHeight_Platform.Size = Vector3.new(12, 1, 12)
        HipHeight_Platform.Anchored = true
        HipHeight_Platform.Transparency = 1
        HipHeight_Platform.CanCollide = true
        HipHeight_Platform.CanQuery = false
        HipHeight_Platform.Parent = workspace
        
        -- คำนวณความสูงเป้าหมาย (พื้น + ค่าที่ผู้ใช้ตั้ง)
        local targetY = groundY + (Config.HipHeightValue or 50)
        HipHeight_Platform.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z)
        
        -- วาปผู้เล่นไปยังพื้น
        task.wait(0.1)
        hrp.CFrame = CFrame.new(hrp.Position.X, targetY + 3.5, hrp.Position.Z)
        
        -- อัพเดตตำแหน่งพื้นตาม terrain
        local lastUpdate = 0
        HipHeight_Loop = RunService.Heartbeat:Connect(function()
            if not Config.HipHeightToggle then return end
            lastUpdate = lastUpdate + 1
            if lastUpdate < 3 then return end -- อัพเดตทุก 3 frames
            lastUpdate = 0
            
            if HipHeight_Platform then
                local currentChar = LocalPlayer.Character
                local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
                if currentHrp then
                    local newGroundY, _ = GetGroundHeight(currentHrp.Position)
                    if newGroundY then
                        local newTargetY = newGroundY + (Config.HipHeightValue or 50)
                        -- Smooth transition ระหว่างความสูง
                        local currentY = HipHeight_Platform.Position.Y
                        local lerpY = currentY + (newTargetY - currentY) * 0.15
                        HipHeight_Platform.CFrame = CFrame.new(currentHrp.Position.X, lerpY, currentHrp.Position.Z)
                    end
                end
            end
        end)
    end
end

local function SetHipHeightValue(newValue)
    local targetOffset = tonumber(newValue)
    if not targetOffset then return end
    
    Config.HipHeightValue = targetOffset
    
    -- อัพเดตความสูงแพลตฟอร์มทันที
    if Config.HipHeightToggle and HipHeight_Platform then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local groundY, _ = GetGroundHeight(hrp.Position)
            if groundY then
                local newTargetY = groundY + targetOffset
                local tween = TweenService:Create(HipHeight_Platform, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    CFrame = CFrame.new(HipHeight_Platform.Position.X, newTargetY, HipHeight_Platform.Position.Z)
                })
                tween:Play()
                
                -- ย้ายผู้เล่นตาม
                task.delay(0.05, function()
                    if hrp and hrp.Parent then
                        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X * 0.3, 0, hrp.AssemblyLinearVelocity.Z * 0.3)
                        hrp.CFrame = CFrame.new(hrp.Position.X, newTargetY + 3.5, hrp.Position.Z)
                    end
                end)
            end
        end
    end
end

local function SetRemoveFog(on)
    if on then
        -- บันทึกค่าเดิมก่อนเปลี่ยน
        if FogRemoval_Original.FogEnd == nil then
            SaveOriginalFog()
        end
        
        -- ยกเลิก connection เดิมถ้ามี
        if FogRemoval_Conn then
            FogRemoval_Conn:Disconnect()
            FogRemoval_Conn = nil
        end
        
        -- ลบหมอกทันที
        pcall(function()
            Lighting.FogEnd = 9e9
            Lighting.FogStart = 9e9
        end)
        pcall(function()
            local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmos then
                atmos.Density = 0
                atmos.Haze = 0
                atmos.Glare = 0
            end
        end)
        
        -- สร้าง loop ต่อเนื่องเพื่อต่อต้าน local scripts ที่ reset หมอก
        FogRemoval_Conn = RunService.Heartbeat:Connect(function()
            if not Config.RemoveFog_Toggle then return end
            pcall(function()
                if Lighting.FogEnd < 100000 then
                    Lighting.FogEnd = 9e9
                    Lighting.FogStart = 9e9
                end
                local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmos and atmos.Density > 0.01 then
                    atmos.Density = 0
                    atmos.Haze = 0
                    atmos.Glare = 0
                end
            end)
        end)
    else
        -- ยกเลิก loop
        if FogRemoval_Conn then
            FogRemoval_Conn:Disconnect()
            FogRemoval_Conn = nil
        end
        -- คืนค่าเดิม
        pcall(function() 
            Lighting.FogEnd = FogRemoval_Original.FogEnd or 1e6 
            Lighting.FogStart = FogRemoval_Original.FogStart or 0
        end)
        pcall(function()
            local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmos and FogRemoval_Original.AtmosphereDensity then
                atmos.Density = FogRemoval_Original.AtmosphereDensity
            end
        end)
        -- รีเซ็ตค่า saved
        FogRemoval_Original = {FogEnd = nil, FogStart = nil, AtmosphereDensity = nil}
    end
end

LocalPlayer.CharacterAdded:Connect(function() task.wait(0.7); FlyBG=nil; FlyBV=nil; if Config.WSToggle then SetWalkSpeed(true) end; if Config.JPToggle then SetJumpPower(true) end; if Config.Noclip then SetNoclip(true) end; if Config.InfJump then SetInfJump(true) end; if Config.FlyToggle then SetFly(true) end; if Config.InfZoom then SetInfZoom(true) end; if Config.HipHeightToggle then SetHipHeight(true) end; if Config.AntiStun then SetAntiStun(true) end end)
AddConn(RunService.RenderStepped:Connect(function() Stats.frameCount = Stats.frameCount + 1 end))

-- [ INITIALIZE CONFIG - Apply default enabled features ]
task.spawn(function()
    task.wait(0.5) -- wait for UI to build
    -- Apply Max Zoom
    if Config.InfZoom then SetInfZoom(true) end
    -- Apply Fast Interact & Aura
    if Config.InstantPress or Config.AuraRange then UpdateInteractables() end
    -- Apply ESP if enabled
    if Config.P_Master then
        -- ESP จะทำงานอัตโนมัติผ่าน RenderStepped loop
    end
    -- Apply Show Stats HUD
    if Config.ShowStatsToggle then
        pcall(function() StatsHUD_Frame.Visible = true end)
    end
    -- Apply Change Sky if enabled
    if Config.ChangeSky_Enabled then
        local id = SkyOptions[Config.ChangeSky_Selected]
        if id then ApplySkyById(id) end
    end
end)

task.spawn(function() while State.Running do task.wait(1); Stats.lastFPS = Stats.frameCount; Stats.frameCount = 0; pcall(function() Stats.pingValue = math.round(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end) end end)

-- TAB 1: AIMLOCK
local T1=BuildTab("Aimlock")
T1:Section("Aim Assist","ระบบช่วยเล็งอัตโนมัติ")
T1:Toggle("Enable Aimlock","เปิดใช้งานระบบล็อกเป้า","Aimlock",function(v) if not v then LockedTarget=nil; State.ToggleAiming=false end end,nil,"Aimlock")

T1:Dropdown("Aim Mode","รูปแบบการใช้งาน: Toggle | Hold | Always","AimMode",{"TOGGLE","HOLD","ALWAYS ON"})

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
T1:Toggle("Enemy Only","ล็อกเป้าเฉพาะศัตรู (ทีมตรงข้าม)","EnemyOnly",nil,nil,"EnemyOnly")
T1:Bind("Aim Keybind","เลือกปุ่มที่ใช้สำหรับล็อกเป้า","BindType","BindKey")
T1:Slider("FOV Radius","ปรับขนาดวงกลมขอบเขตการล็อก","FOV",1,200,"%",false)
T1:Slider("Smoothing","ความเร็วในการลากเป้าไปยังศัตรู","AimSmooth",0.01,1,"",true)
T1:ColorPicker("FOV Color","ปรับสีของวงกลมขอบเขตการล็อก","FOVColor_C3")
T1:Toggle("Wall Check","ล็อกเป้าเฉพาะศัตรูที่มองเห็นเท่านั้น","WallCheck",nil,nil,"WallCheck")
T1:Dropdown("Target Part","เลือกส่วนที่จะล็อก: หัว/ตัว/อัตโนมัติ","AimTargetPart",{"Head","Torso","HumanoidRootPart","Auto"})

local T2=BuildTab("ESP Player")
T2:Section("ESP Visuals","ระบบแสดงตำแหน่งผู้เล่นและ NPC")
T2:Toggle("Enable Visuals","เปิดใช้งานการแสดงตำแหน่งทั้งหมด","P_Master",nil,nil,"P_Master")
T2:Toggle("View Distance Only","แสดงผลระยะไกลตามแนวสายตา","P_ESPInFOVOnly",nil,nil,"P_ESPInFOVOnly")
T2:Toggle("Show Names","แสดงชื่อเหนือศีรษะตัวละคร","P_ShowName",nil,nil,"P_ShowName"); T2:Toggle("Show Health","แสดงสถานะพลังชีวิตแบบเปอร์เซ็นต์","P_ShowHealth",nil,nil,"P_ShowHealth")
T2:Toggle("Show Distance","แสดงระยะห่างจากตำแหน่งปัจจุบัน","P_ShowDist",nil,nil,"P_ShowDist"); T2:Toggle("Highlight Glow","ระบายสีตัวละครเพื่อเน้นตำแหน่ง","P_Highlight",nil,nil,"P_Highlight")
T2:Toggle("Team Color","ใช้สีตามทีมที่ผู้เล่นสังกัด","P_TeamColor",nil,nil,"P_TeamColor"); T2:Toggle("Ignore Team","ซ่อนเพื่อนร่วมทีมจากการแสดงผล","P_TeamCheck",nil,nil,"P_TeamCheck")
T2:Toggle("X-Ray Mode","โหมดมองทะลุสิ่งกีดขวางและกำแพง","P_Xray",function() UpdateXray(XrayCache_P,Config.P_Xray) end,nil,"P_Xray")
T2:Section("Customization","ปรับแต่งรูปแบบการแสดงผล")
T2:ColorPicker("Primary Color","เลือกสีหลักสำหรับ ESP Player","P_Color_C3")
T2:Slider("Text Size","ปรับขนาดตัวอักษรของข้อมูล","P_TextSize",8,30,"px",false)
T2:Slider("Fill Opacity","ระดับความทึบของสีในตัวละคร","P_FillTrans",0,1,"",true)
T2:Slider("Outline Opacity","ระดับความทึบของเส้นขอบ","P_OutlineTrans",0,1,"",true)
T2:Section("Hitbox Expansion","ระบบขยายขอบเขตการรับความเสียหาย")
T2:Toggle("Enable Hitbox","เปิดใช้งานการขยาย Hitbox ตัวละคร","P_HitboxToggle",function(v) if not v then for char,sz in pairs(HitboxOriginalSizes) do pcall(function() local hrp=char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.Size=sz; hrp.Transparency=1; hrp.Material=Enum.Material.SmoothPlastic; hrp.CanCollide=true end end) end; HitboxOriginalSizes={} end end,nil,"P_HitboxToggle")
T2:Dropdown("Target Selection","เลือกกลุ่มเป้าหมายที่ต้องการขยาย","HitboxTargetMode",{"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"})
T2:Slider("Expansion Size","เลือกขนาดความกว้าง (หน่วย studs)","P_HitboxSize",4,200,"",false)

-- TAB 3: SETTING PLAYER
local T3=BuildTab("Setting Player")

T3:Section("Animations","ระบบแสดงท่าทาง (Emotes)")
T3:RunButton("Open Emote Menu", "เรียกใช้งานเมนูท่าเต้นที่ซ่อนอยู่", "ICON_CLICK", Colors.PrimaryBlue, function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))()
    end)
end)

T3:Section("Appearance","การปรับแต่งธีมและรูปลักษณ์")
T3:Dropdown("UI Theme","เลือกโทนสีของเมนู (มีผลทันที)","Theme",{"Dark","Midnight","Neon","Rose","Gold","Purple"},false,function(v) ApplyTheme(v) end)
T3:Section("Movement","ระบบควบคุมการเคลื่อนที่")
T3:Toggle("Super Walk","เปิดใช้งานการเพิ่มความเร็วในการววิ่ง","WSToggle",function(v) SetWalkSpeed(v) end,nil,"WSToggle")
T3:Slider("Speed Value","กำหนดระดับความเร็วที่ต้องการ","WalkSpeed",16,1000,"",false,function() if Config.WSToggle then SetWalkSpeed(true) end end)
T3:Toggle("Super Jump","เปิดใช้งานการปรับระดับการกระโดด","JPToggle",function(v) SetJumpPower(v) end,nil,"JPToggle")
T3:Slider("Jump Value","กำหนดระดับพลังกระโดดที่ต้องการ","JumpPower",10,1000,"",false,function() if Config.JPToggle then SetJumpPower(true) end end)
T3:Toggle("Infinite Jump","สามารถกระโดดบนอากาศได้ต่อเนื่อง","InfJump",function(v) SetInfJump(v) end,nil,"InfJump")
T3:Toggle("Fly Mode","Space=ขึ้น | Shift=ลง | WASD=ทิศทาง","FlyToggle",function(v) SetFly(v) end,nil,"FlyToggle")
T3:Slider("Flying Speed","กำหนดความเร็วในการบิน","FlySpeed",5,500,"",false)
T3:Toggle("No Clip","เดินทะลุกำแพงและสิ่งกีดขวางได้","Noclip",function(v) SetNoclip(v) end,nil,"Noclip")
T3:Toggle("Invisibility","โหมดล่องหน (ใช้ได้เฉพาะบางแมพ)","InvisToggle",function(v) SetInvisibility(v) end,nil,"InvisToggle")
T3:Toggle("Max Zoom","ระยะการซูมกล้องแบบไร้ขีดจำกัด","InfZoom",function(v) SetInfZoom(v) end,nil,"InfZoom")
T3:Toggle("Hip Height","สร้างพื้นล่องหนลอยตัวที่ความสูงที่กำหนด","HipHeightToggle",function(v) SetHipHeight(v) end,nil,"HipHeightToggle")
T3:Slider("Height Level","กำหนดระดับความสูงที่ต้องการลอย ( studs )","HipHeightValue",-100,1000,"",false,function(v) SetHipHeightValue(v) end)
T3:Section("Visual Environment","ระบบปรับแต่งสภาพแวดล้อม")
T3:Toggle("Custom Field of View","เปิดใช้งานการปรับมุมมองสายตา","FOVToggle",function(v)
    if v then pcall(function() workspace.CurrentCamera.FieldOfView=Config.FOVView end)
    else pcall(function() workspace.CurrentCamera.FieldOfView=70 end) end
end,nil,"FOVToggle")
T3:Slider("FOV Value","เลือกองศามุมกล้อง (70 คือปกติ)","FOVView",30,360,"°",false,function(v)
    if Config.FOVToggle then pcall(function() workspace.CurrentCamera.FieldOfView=v end) end
end)
T3:Section("Lighting","ระบบความสว่างและแสงเงา")
T3:Toggle("Fullbright","เพิ่มความสว่างสูงสุดทั่วทั้งแผนที่","Fullbright_Toggle",nil,nil,"Fullbright_Toggle")
T3:Toggle("Disable Fog","ลบหมอกควันเพื่อเพิ่มทัศนวิสัย","RemoveFog_Toggle",function(v) SetRemoveFog(v) end,nil,"RemoveFog_Toggle")
T3:Section("Interactions","สิ่งอำนวยความสะดวกในการเล่น")
T3:Toggle("Fast Interact","โต้ตอบกับวัตถุได้ทันทีไม่ต้องรอ","InstantPress",function() UpdateInteractables() end,nil,"InstantPress")
T3:Toggle("Interaction Aura","เพิ่มระยะการโต้ตอบกับวัตถุให้ไกลขึ้น","AuraRange",function() UpdateInteractables() end,nil,"AuraRange")

T3:Toggle("Anti-AFK","ระบบป้องกันการถูกเตะเมื่อไม่ได้ขยับตัว","AntiAFK",function(v) SetAntiAFK(v) end,nil,"AntiAFK")
T3:Toggle("Anti Stun","ป้องกันการล้มและป้องกันสตั้น","AntiStun",function(v) SetAntiStun(v) end,nil,"AntiStun")
T3:Section("Optimization","ระบบเพิ่มประสิทธิภาพเฟรมเรต")
T3:Toggle("Enable FPS Booster","เปิดใช้งานโหมดเพิ่มความลื่นไหล","FPSBooster",function(v) if v then ApplyFPSBoost() else DisableFPSBoost() end end,nil,"FPSBooster")
T3:Toggle("Disable Shadows","ปิดการแสดงผลเงาในแผนที่","FPS_NoShadows",nil,nil,"FPS_NoShadows"); T3:Toggle("Clear Particles","ปิดการแสดงผลเอฟเฟกต์ควันและไฟ","FPS_NoParticles",nil,nil,"FPS_NoParticles")
T3:Toggle("Strip Outfits","ปิดการแสดงผลเสื้อผ้าของตัวละคร","FPS_NoClothes",nil,nil,"FPS_NoClothes"); T3:Toggle("Low Mesh Quality","ลดคุณภาพวัตถุเพื่อเพิ่มความลื่นไหล","FPS_LowQuality",nil,nil,"FPS_LowQuality")
T3:Section("Interface Info","ระบบแสดงข้อมูลสถานะบนหน้าจอ")
T3:Dropdown("Data Display","เลือกข้อมูลที่ต้องการติดตาม","ShowFPSPing",{"FPS","Ping","FPS & Ping"})
T3:Toggle("Show Activity HUD","แสดงแถบข้อมูลสถานะบนหน้าจอ","ShowStatsToggle",function(v) StatHUD.Visible=v end,nil,"ShowStatsToggle")
T3:Dropdown("HUD Position","เลือกตำแหน่งการวางแถบข้อมูล","HUDPosition",{"TopLeft","TopRight","BottomLeft","BottomRight"},false,function() UpdateHUDPos() end)
T3:Section("Save/Load Configuration","ระบบจัดการการตั้งค่า")
T3:Button(" Save My Settings",Colors.PrimaryBlue,SaveSettings)
T3:Button(" Load Settings",Color3.fromRGB(52,52,72),LoadSettings)


-- TAB 3.5: GRAPHIC
local TG=BuildTab("Graphic")
TG:Section("Ray Tracing","ระบบเพิ่มความสวยงามด้วยแสงเงาสมจริง (กินทรัพยากรสูง)")
TG:Toggle("Ray Tracing","เพิ่มความสวยงามด้วย Ray Tracing (กินทรัพยากรสูง)","RTX_Enabled",function(v) SetRTX(v) end,nil,"RTX_Enabled")

TG:Section("Change the Sky","ระบบเปลี่ยนท้องฟ้าและบรรยากาศ")
TG:Toggle("Change Sky","เปิดใช้งานการเปลี่ยนท้องฟ้าและบรรยากาศ","ChangeSky_Enabled",function(v) SetChangeSky(v) end,nil,"ChangeSky_Enabled")
TG:Dropdown("Sky Selection","เลือกท้องฟ้าที่ต้องการ","ChangeSky_Selected",SkyList,false,function(v)
    if Config.ChangeSky_Enabled then
        local id = SkyOptions[v]
        if id then ApplySkyById(id) end
    end
end)

-- TAB 4: TELEPORT
local T4=BuildTab("Player Teleport")
T4:Section("Target Tracking","ระบบวาร์ปและติดตามผู้เล่น")
T4:Dropdown("Target Player","ระบุชื่อผู้เล่นที่ต้องการ (ค้นหาได้)","TPTarget",{"-"},true)
T4:Dropdown("Tracking Mode","Safe Fly = บินตาม | Warp = วาร์ปหา","TPMode",{"Safe Fly","Warp"})
T4:Slider("Follow Speed","ความเร็วในการบินติดตามเป้าหมาย","TPFlightSens",10,500,"",false)
T4:Toggle("Activate System","START = เริ่มทำงาน | STOP = หยุด","TPGOSwitch",function(v)
    if v and Config.TPTarget~="-" then local tp=Players:FindFirstChild(Config.TPTarget)
        if tp then if Config.TPMode=="Safe Fly" then StartSafeTP(tp) else local tHRP=tp.Character and tp.Character:FindFirstChild("HumanoidRootPart"); if tHRP and LocalPlayer.Character then pcall(function() LocalPlayer.Character:PivotTo(tHRP.CFrame*CFrame.new(0,0,3)) end) end end end
    else StopSafeTP() end
end,nil,"TPGOSwitch")
T4:Section("Spectator Mode","ระบบรับชมกล้องของผู้เล่นอื่น")
T4:Dropdown("Watch Player","เลือกผู้เล่นที่ต้องการรับชม","SpecTarget",{"-"},true)
T4:Toggle("Enable Eye","เปิดใช้งานการรับชมจอผู้เล่นแบบสด","SpecToggle",function(v) if not v then local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then Camera.CameraSubject=h end end end,nil,"SpecToggle")
T4:Section("Mouse Teleportation","จัดการตำแหน่งด้วยเมาส์และคีย์")
T4:Bind("Teleport Key","กดปุ่มนี้ค้างไว้แล้วคลิกเมาส์ซ้ายเพื่อวาร์ป","ClickTPBindType","ClickTPBindKey")
T4:Toggle("Enable Click-TP","เปิดใช้งานระบบวาร์ปตามตำแหน่งคลิก","ClickTPToggle",nil,nil,"ClickTPToggle")

-- TAB 5: SERVER INFO
local T5=BuildTab("Server Details")

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

-- [ KEYBINDS INPUT HANDLER ]
-- Update toggle UI when keybind toggles a feature
local function UpdateToggleUIFromKeybind(featureKey)
    if not State.ToggleUIRefs then return end
    local refs = State.ToggleUIRefs[featureKey]
    if not refs then return end
    
    local on = Config[featureKey]
    local Stat, Track, Circ, CG, TS = refs.Stat, refs.Track, refs.Circ, refs.CG, refs.TS
    local customText = refs.customText
    
    -- Update text
    Stat.Text = on and (customText and customText[1] or "On") or (customText and customText[2] or "Off")
    Tw(Stat, 0.2, {TextColor3 = on and Colors.Green or Color3.fromRGB(120,120,140)})
    
    -- Update track colors
    Tw(Track, 0.25, {BackgroundColor3 = on and Colors.PrimaryBlue or Colors.Toggle_Off})
    Tw(TS, 0.25, {Color = on and Colors.AccentGlow or Color3.fromRGB(70,70,90), Thickness = 0.8})
    
    -- Animate circle
    Tw(Circ, 0.15, {Size = UDim2.new(0,26,0,20)})
    task.delay(0.12, function()
        TwSpring(Circ, 0.35, {Size = UDim2.new(0,20,0,20), Position = on and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)})
    end)
    
    -- Update glow
    Tw(CG, 0.25, {BackgroundTransparency = on and 0.2 or 1})
    
    -- Call onChange callback if exists
    if refs.onChange then refs.onChange(on) end
end

local function ProcessKeybinds(input)
    for featureKey, kb in pairs(Config.Keybinds) do
        if kb.Enabled and kb.Key then
            local matched = false
            if kb.Type == "Keyboard" and input.UserInputType == Enum.UserInputType.Keyboard then
                matched = (input.KeyCode == kb.Key)
            elseif kb.Type == "Mouse" then
                local mb = (kb.Key == 1) and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
                matched = (input.UserInputType == mb)
            end
            if matched then
                local currentValue = Config[featureKey]
                if currentValue ~= nil and type(currentValue) == "boolean" then
                    Config[featureKey] = not currentValue
                    local newValue = Config[featureKey]
                    local featureNames = {
                        Aimlock = "Aimlock", P_Master = "ESP Master", P_HitboxToggle = "Hitbox Expand",
                        WSToggle = "Super Speed", JPToggle = "Super Jump", FlyToggle = "Fly Mode",
                        Noclip = "No Clip", InfJump = "Infinite Jump", InvisToggle = "Invisibility",
                        InfZoom = "Max Zoom", FOVToggle = "Custom FOV", Fullbright_Toggle = "Fullbright",
                        RemoveFog_Toggle = "Remove Fog", AntiAFK = "Anti-AFK", AntiStun = "Anti Stun", FPSBooster = "FPS Booster",
                        TPGOSwitch = "Teleport Target", ClickTPToggle = "Click TP",
                        FPS_NoShadows = "FPS No Shadows", FPS_NoParticles = "FPS No Particles",
                        FPS_NoClothes = "FPS No Clothes", FPS_LowQuality = "FPS Low Quality",
                        ShowStatsToggle = "Show Stats HUD", InstantPress = "Fast Interact",
                        AuraRange = "Interaction Aura", P_ESPInFOVOnly = "ESP FOV Only",
                        P_ShowName = "ESP Show Names", P_ShowHealth = "ESP Show Health",
                        P_ShowDist = "ESP Show Distance", P_Highlight = "ESP Highlight",
                        P_TeamColor = "ESP Team Color", P_TeamCheck = "ESP Ignore Team",
                        P_Xray = "ESP X-Ray", SpecToggle = "Spectator Mode",
                        EnemyOnly = "Enemy Only", WallCheck = "Wall Check",
                        HipHeightToggle = "Hip Height Float",
                        RTX_Enabled = "Ray Tracing",
                        ChangeSky_Enabled = "Change Sky"
                    }
                    local name = featureNames[featureKey] or featureKey
                    local emoji = newValue and "✅" or "❌"
                    local action = newValue and "เปิด" or "ปิด"
                    ShowToast(emoji .. " " .. action .. " : " .. name, newValue and Colors.Green or Colors.Red)
                    
                    -- Update UI toggle to match new state
                    UpdateToggleUIFromKeybind(featureKey)
                    
                    if featureKey == "WSToggle" then SetWalkSpeed(newValue) end
                    if featureKey == "JPToggle" then SetJumpPower(newValue) end
                    if featureKey == "FlyToggle" then SetFly(newValue) end
                    if featureKey == "Noclip" then SetNoclip(newValue) end
                    if featureKey == "InfJump" then SetInfJump(newValue) end
                    if featureKey == "InvisToggle" then SetInvisibility(newValue) end
                    if featureKey == "InfZoom" then SetInfZoom(newValue) end
                    if featureKey == "AntiAFK" then SetAntiAFK(newValue) end
                    if featureKey == "AntiStun" then SetAntiStun(newValue) end
                    if featureKey == "FPSBooster" then if newValue then ApplyFPSBoost() else DisableFPSBoost() end end
                    if featureKey == "TPGOSwitch" then 
                        if newValue and Config.TPTarget~="-" then 
                            local tp=Players:FindFirstChild(Config.TPTarget)
                            if tp then if Config.TPMode=="Safe Fly" then StartSafeTP(tp) else local tHRP=tp.Character and tp.Character:FindFirstChild("HumanoidRootPart"); if tHRP and LocalPlayer.Character then pcall(function() LocalPlayer.Character:PivotTo(tHRP.CFrame*CFrame.new(0,0,3)) end) end end end
                        else StopSafeTP() end
                    end
                    if featureKey == "Aimlock" then if not newValue then LockedTarget=nil; State.ToggleAiming=false end end
                    if featureKey == "HipHeightToggle" then SetHipHeight(newValue) end
                    if featureKey == "RemoveFog_Toggle" then SetRemoveFog(newValue) end
                    if featureKey == "RTX_Enabled" then SetRTX(newValue) end
                    if featureKey == "ChangeSky_Enabled" then SetChangeSky(newValue) end
                    return true
                end
            end
        end
    end
    return false
end

-- [ INPUT HANDLERS ]
AddConn(UIS.InputBegan:Connect(function(input,gp)
    if gp or State.Binding then return end
    -- Process custom keybinds first
    if ProcessKeybinds(input) then return end
    -- Menu toggle
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
        if UIS:IsKeyDown(Config.ClickTPBindKey) then
            local lpc=LocalPlayer.Character
            if lpc and Mouse.Hit then
                pcall(function() lpc:PivotTo(Mouse.Hit*CFrame.new(0,3,0)) end)
            end
        end
    end
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
        if Config.ShowFPSPing=="FPS" then StatHUD.Text="FPS: "..Stats.lastFPS
        elseif Config.ShowFPSPing=="Ping" then StatHUD.Text="Ping: "..Stats.pingValue.."ms"
        else StatHUD.Text="FPS: "..Stats.lastFPS.." | "..Stats.pingValue.."ms" end
    else StatHUD.Visible=false end

    local LPChar=LocalPlayer.Character; local LPHum=LPChar and LPChar:FindFirstChildOfClass("Humanoid"); local LPHRP=LPChar and LPChar:FindFirstChild("HumanoidRootPart")

    -- Lighting
    if Config.Fullbright_Toggle then
        pcall(function() Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 9e9; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128) end)
    elseif Config.RemoveFog_Toggle then
        pcall(function() Lighting.FogEnd = 9e9 end)
    end

    -- Custom FOV: force every frame when enabled (Simulated Ultra-Wide for 120-360 range)
    if Config.FOVToggle then
        pcall(function()
            local baseFOV = math.clamp(Config.FOVView, 30, 120)
            Camera.FieldOfView = baseFOV
            if Config.FOVView > 120 then
                local extra = Config.FOVView - 120
                -- Algorithm: Offset CFrame backward to simulate fish-eye/wide-angle effects beyond engine limits
                Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, extra * 0.1) 
            end
        end)
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
        local now=tick(); if now-Stats.lastWarpTick>=0.5 then Stats.lastWarpTick=now; local tp=Players:FindFirstChild(Config.TPTarget); if tp and tp.Character then local tHRP=tp.Character:FindFirstChild("HumanoidRootPart"); if tHRP then pcall(function() LPChar:PivotTo(tHRP.CFrame*CFrame.new(0,0,3)) end) end end end
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
        local head, hrp, hum = GetCharacterParts(char)
        
        -- ตรวจสอบความถูกต้อง - ยืดหยุ่นกว่าเดิม
        if not char.Parent then
            local e=ESP_Cache[char]; if e then e.Gui.Enabled=false; e.Highlight.Enabled=false end
            continue
        end
        
        -- ถ้าไม่มี Humanoid หรือไม่มีส่วนหลัก ให้ข้าม
        if not (hum and hum.Health > 0) then
            local e=ESP_Cache[char]; if e then e.Gui.Enabled=false; e.Highlight.Enabled=false end
            continue
        end
        
        -- ต้องมีอย่างน้อย HRP หรือ Head
        if not (hrp or head) then
            local e=ESP_Cache[char]; if e then e.Gui.Enabled=false; e.Highlight.Enabled=false end
            continue
        end
        
        -- ใช้ตำแหน่งจาก HRP หรือ Head หรือส่วนแรกที่เจอ
        local refPart = hrp or head
        local esp=GetESP(char)
        local rPos,rVis=Camera:WorldToViewportPoint(refPart.Position)
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
            -- ใช้ head หรือ hrp หรือส่วนแรกที่เจอเป็น Adornee
            local espAdornee = head or hrp or char:FindFirstChildWhichIsA("BasePart")
            esp.Gui.Adornee=espAdornee; esp.Gui.Enabled=true
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

        -- ── Aimlock Candidate: Smart Selection ──
        -- ใช้ GetTargetPart เพื่อเลือกส่วนที่จะล็อกตามการตั้งค่า
        local targetPart = GetTargetPart(char)
        
        -- คำนวณคะแนนรวม: ใกล้ FOV + ใกล้ตัวละคร (50/50)
        -- ถ้าไม่มี LPHRP2 ใช้ Camera position แทน
        if isAimingNow and not LockedTarget and inFOV and rVis and rPos.Z>0 and targetPart then
            local isEnemy=true
            if isPlayer and Config.EnemyOnly then
                if ownerPlayer.Team ~= nil and LocalPlayer.Team ~= nil then
                    isEnemy=(ownerPlayer.Team~=LocalPlayer.Team)
                else
                    isEnemy=true
                end
            end
            -- Wall check เฉพาะตอนเลือกเป้าหมายใหม่ (ไม่ใช่ตอนล็อกอยู่)
            if isEnemy and IsVisible(targetPart) then
                local scrDist=(scr2D-center).Magnitude                    -- px distance to FOV center
                local playerPos = LPHRP2 and LPHRP2.Position or Camera.CFrame.Position
                local wldDist=(refPart.Position-playerPos).Magnitude      -- 3D world studs
                
                -- Normalize distances
                local normScr=scrDist/(Circle.Radius+0.001)               -- 0..1 (0=ตรงกลาง)
                local normWld=math.clamp(wldDist/500, 0, 1)                -- 0..1 (0=ใกล้, 500 studs=ไกลสุด)
                
                -- Smart Score: 50% screen distance + 50% world distance
                -- ค่าน้อย = ดี (ใกล้ FOV และใกล้ตัวละคร)
                local score=(normScr*0.5 + normWld*0.5)
                
                -- Bonus: ถ้าเป้าหมายอยู่ใกล้มาก (<50 studs) ลดคะแนนเพิ่ม (prioritize close targets)
                if wldDist < 50 then
                    score=score*0.7
                elseif wldDist < 100 then
                    score=score*0.85
                end
                
                if score<bestScore then bestHead=targetPart; bestScore=score end
            end
        end
        
        -- ตรวจสอบ LockedTarget เฉพาะว่ายังมีชีวิตอยู่ไหม (ไม่สนว่าอยู่หลังกำแพง)
        -- Sticky Lock: ล็อกจนตาย หรือจนกว่าผู้ใช้จะปลดเอง
        if LockedTarget==targetPart and hum.Health<=0 then 
            LockedTarget=nil 
        end
    end

    -- ── Lock & Aim ──
    if isAimingNow and not LockedTarget and bestHead then 
        LockedTarget=bestHead 
    end
    
    if isAimingNow and LockedTarget then
        if LockedTarget and LockedTarget.Parent then
            local lhum=LockedTarget.Parent:FindFirstChildOfClass("Humanoid")
            -- Sticky Lock: ล็อกต่อไปจนกว่าจะตาย ไม่สน visibility (ยิงทะลุกำแพงได้ถ้าล็อกไว้แล้ว)
            if lhum and lhum.Health>0 then
                Camera.CFrame=Camera.CFrame:Lerp(
                    CFrame.lookAt(Camera.CFrame.Position,LockedTarget.Position),
                    math.clamp(Config.AimSmooth,0.01,1))
            else 
                LockedTarget=nil 
            end
        else 
            LockedTarget=nil 
        end
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
