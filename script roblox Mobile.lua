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
            o.GlobalShadows  = Lighting.GlobalShadows
            o.FogEnd         = Lighting.FogEnd
            o.FogStart       = Lighting.FogStart
            o.ClockTime      = Lighting.ClockTime
            o.Brightness     = Lighting.Brightness
            o.OutdoorAmbient = Lighting.OutdoorAmbient
        end)
        -- Atmosphere
        pcall(function()
            local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmos then
                o.AtmoDensity = atmos.Density
                o.AtmoHaze    = atmos.Haze
                o.AtmoGlare   = atmos.Glare
            end
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
                pcall(function() o.Health = h.Health end)
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
    Aimlock = false, AimMode = "HOLD", FOV = 20, AimSmooth = 1, WallCheck = true, TargetMode = "PLAYERS ONLY", EnemyOnly = false, AimTargetPart = "Head", BindType = "Keyboard", BindKey = Enum.KeyCode.Q,
    ESPMaster = false, ESPShowName = false, ESPShowHealth = false, ESPShowDistance = false, ESPHighlight = false, ESPTeamCheck = false, ESPTeamColor = false, ESPXray = false, ESPTextSize = 10, ESPFillTrans = 0.5, ESPOutlineTrans = 0.1, ESPColor_C3 = Color3.new(1,1,1),
    P_Master = false, P_ShowName = true, P_ShowHealth = true, P_ShowDist = true, P_Highlight = true, P_TeamCheck = false, P_TeamColor = false, P_Xray = false, P_TextSize = 10, P_FillTrans = 0.5, P_OutlineTrans = 0.1, P_HitboxToggle = false, P_HitboxSize = 32, HitboxTargetMode = "PLAYERS ONLY", P_Color_C3 = Color3.new(1,1,1), P_ESPInFOVOnly = false,
    WalkSpeed = 100, WSToggle = false, JumpPower = 100, JPToggle = false, InfJump = false, FlyToggle = false, FlySpeed = 100, Noclip = false, InfZoom = true, InvisToggle = false, FOVToggle = false, FOVView = 70, FOVColor_C3 = Color3.fromRGB(30,161,255),
    AntiAFK = true, AntiStun = false, FPSBooster = false, FPS_NoShadows = true, FPS_NoParticles = true, FPS_NoClothes = true, FPS_LowQuality = true, HipHeightToggle = false, HipHeightValue = 50, InstantPress = true, AuraRange = false, Fullbright_Toggle = false, RemoveFog_Toggle = false,
    RTX_Enabled = false, ChangeSky_Enabled = false, ChangeSky_Selected = "Anime-sky",
    ShowFPSPing = "FPS & Ping", ShowStatsToggle = true, HUDPosition = "TopRight", TPTarget = "-", TPMode = "Warp", TPFlightSens = 80, TPGOSwitch = false, SpecTarget = "-", SpecToggle = false, ClickTPToggle = false, ClickTPBindType = "Keyboard", ClickTPBindKey = Enum.KeyCode.C, MenuToggleBindType = "Keyboard", MenuToggleBindKey = Enum.KeyCode.G, MenuVisible = true, Theme = "Midnight", 
    AutoLoadSettings = false,
    GithubURL = "https://github.com/phwyverysad",
    -- Keybinds System: เก็บการตั้งค่าปุ่มสำหรับแต่ละฟีเจอร์
    Keybinds = {
        -- Aimlock Tab
        Aimlock = {Type="Keyboard", Key=Enum.KeyCode.Q, Enabled=false, Mode="Toggle"},
        -- ESP Tab
        P_Master = {Type="Keyboard", Key=Enum.KeyCode.Z, Enabled=false, Mode="Toggle"},
        P_HitboxToggle = {Type="Keyboard", Key=Enum.KeyCode.X, Enabled=false, Mode="Toggle"},
        -- Player Tab
        WSToggle = {Type="Keyboard", Key=Enum.KeyCode.LeftShift, Enabled=false, Mode="Toggle"},
        JPToggle = {Type="Keyboard", Key=Enum.KeyCode.Space, Enabled=false, Mode="Toggle"},
        FlyToggle = {Type="Keyboard", Key=Enum.KeyCode.F, Enabled=false, Mode="Toggle"},
        Noclip = {Type="Keyboard", Key=Enum.KeyCode.N, Enabled=false, Mode="Toggle"},
        InfJump = {Type="Keyboard", Key=Enum.KeyCode.V, Enabled=false, Mode="Toggle"},
        InvisToggle = {Type="Keyboard", Key=Enum.KeyCode.I, Enabled=false, Mode="Toggle"},
        InfZoom = {Type="Keyboard", Key=Enum.KeyCode.M, Enabled=false, Mode="Toggle"},
        FOVToggle = {Type="Keyboard", Key=Enum.KeyCode.P, Enabled=false, Mode="Toggle"},
        Fullbright_Toggle = {Type="Keyboard", Key=Enum.KeyCode.B, Enabled=false, Mode="Toggle"},
        RemoveFog_Toggle = {Type="Keyboard", Key=Enum.KeyCode.End, Enabled=false, Mode="Toggle"},
        AntiAFK = {Type="Keyboard", Key=Enum.KeyCode.Home, Enabled=false, Mode="Toggle"},
        FPSBooster = {Type="Keyboard", Key=Enum.KeyCode.Insert, Enabled=false, Mode="Toggle"},
        HipHeightToggle = {Type="Keyboard", Key=Enum.KeyCode.PageUp, Enabled=false, Mode="Toggle"},
        -- Teleport Tab
        TPGOSwitch = {Type="Keyboard", Key=Enum.KeyCode.T, Enabled=false, Mode="Toggle"},
        ClickTPToggle = {Type="Keyboard", Key=Enum.KeyCode.C, Enabled=false, Mode="Toggle"},
    }
}
for k, v in pairs(initialConfig) do Phwy.Settings[k] = v end

local initialState = {
    Running = true, ToggleAiming = false, Binding = nil, isMinimized = false, isMaximized = false, isHidden = false, preHideSize = nil,
    originalSize = UDim2.new(0,880,0,570), originalPos = UDim2.new(0.5,-440,0.5,-285),
    UIRefs = {}
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

-- Local state variables (prevent global leaks)
local LockedTarget, FlyBG, FlyBV, FlyAO, FlyLV
local WS_Loop, JP_Loop, NC_Conn, IJ_Conn, AFK_Conn, AntiStun_Loop
local SafeTP_Conn, FPS_DescConn, FogRemoval_Conn
local ESP_Folder

-- [ COMPATIBILITY DUMMIES for roblox.lua API parity ]
local W, H = 880, 570
local ScreenGui = nil
local MainFrame = nil
local FloatingLayer = nil
local CPGui = nil
local TitleLine = nil

-- Theme stubs (roblox.lua has custom themes; Rayfield handles its own)
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
    Colors.PrimaryBlue = (t and t.Primary) or Color3.fromRGB(30,161,255)
    Colors.AccentGlow = (t and t.Accent) or Color3.fromRGB(80,190,255)
    Colors.WindowBg = (t and t.WinBg) or Color3.fromRGB(20,20,24)
    Colors.TitleBg = (t and t.TitleBg) or Color3.fromRGB(28,28,34)
    Colors.SidebarBg = (t and t.SideBar) or Color3.fromRGB(24,24,30)
    Colors.ContentBg = (t and t.Content) or Color3.fromRGB(17,17,22)
    Colors.RowBg = (t and t.Row) or Color3.fromRGB(32,32,40)
    Colors.RowHover = (t and t.RowH) or Color3.fromRGB(44,44,54)
    Colors.DarkElement = (t and t.Element) or Color3.fromRGB(46,46,58)
    Colors.Stroke = (t and t.Stroke) or Color3.fromRGB(60,60,78)
    Colors.Toggle_Off = (t and t.Toggle_Off) or Color3.fromRGB(55,55,68)
    Colors.TextSub = (t and t.TextSub) or Color3.fromRGB(120,120,140)
    Colors.TextMain = Color3.fromRGB(240,240,240)
    Colors.Green = Color3.fromRGB(50,220,90)
    Colors.Red = Color3.fromRGB(220,60,60)
end
CopyTheme(Themes.Dark)

-- Tween / UI helpers stubs
local function Tw(obj,t,props,style,dir)
    if obj and typeof(obj) == "Instance" and obj.Parent then
        pcall(function() TweenService:Create(obj,TweenInfo.new(t or 0.3, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props or {}):Play() end)
    end
end
local function TwSpring(obj,t,props) Tw(obj,t,props,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out) end
local function TwBack(obj,t,props) Tw(obj,t,props,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end
local function Corner(obj,r)
    if obj and typeof(obj) == "Instance" then pcall(function() Instance.new("UICorner",obj).CornerRadius = UDim.new(0, r or 10) end) end
    return obj
end
local function Stroke(obj,col,th)
    if obj and typeof(obj) == "Instance" then
        pcall(function()
            local s = Instance.new("UIStroke",obj)
            s.Color = col or Color3.new(1,1,1)
            s.Thickness = th or 1
        end)
    end
    return obj
end
local function RegTR(obj,key,prop)
    -- roblox.lua registers theme refs for ApplyTheme; Rayfield handles themes internally
    return obj
end
local function MakeDot(col, icon) return nil end
local function SwitchTab(targetTab) end
function OpenCPicker(key, pos, cb)
    if cb then cb(Config[key] or Color3.new(1,1,1)) end
end
local function UpdateMenuBindLabel() end
local function ShowDD() end
local function HideDD() end
local CP_D = {H = 0, S = 1, V = 1, callback = nil, dragMode = nil}
local function UpdateCP() end
local function TrackInput() end

-- [ WINDOW CONTROLS ] (roblox.lua parity)
local function RestoreAll()
    -- Delegate to the more comprehensive ResetAllSettings if available
    if _G.ResetAllSettings then
        pcall(_G.ResetAllSettings)
    else
        -- Minimal fallback
        local lpc = LocalPlayer.Character
        if lpc then
            local h = lpc:FindFirstChildOfClass("Humanoid")
            if h then
                pcall(function() h.WalkSpeed = 16; h.UseJumpPower = true; h.JumpPower = 50; h.MaxHealth = 100; h.Health = 100; h.BreakJointsOnDeath = true end)
                pcall(function() h.RequiresNeck = true; h.PlatformStand = false end)
            end
            pcall(function() lpc.Animate.Disabled = false end)
        end
        if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG = nil end
        if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV = nil end
        if FlyAO then pcall(function() FlyAO:Destroy() end); FlyAO = nil end
        if FlyLV then pcall(function() FlyLV:Destroy() end); FlyLV = nil end
        if lpc then
            local h = lpc:FindFirstChildOfClass("Humanoid")
            if h then pcall(function() Camera.CameraSubject = h end) end
        end
        pcall(function() Camera.FieldOfView = 70 end)
        pcall(function() LocalPlayer.CameraMaxZoomDistance = 400 end)
        for p,o in pairs(XrayCache_M) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier = o end end) end
        for p,o in pairs(XrayCache_P) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier = o end end) end
        for char,sz in pairs(HitboxOriginalSizes) do
            pcall(function()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Size = sz; hrp.Transparency = 1; hrp.Material = Enum.Material.SmoothPlastic; hrp.CanCollide = true end
            end)
        end
        if SafeTP_Conn then SafeTP_Conn:Disconnect(); SafeTP_Conn = nil end
        pcall(function() Lighting.GlobalShadows = true end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        if ESP_Folder and ESP_Folder.Parent then pcall(function() ESP_Folder:Destroy() end) end
    end
end

local function FullUnload()
    State.Running = false
    RestoreAll()
    Circle.Visible = false
    for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _,cn in pairs({WS_Loop, JP_Loop, NC_Conn, IJ_Conn, AFK_Conn, FPS_DescConn, SafeTP_Conn, AntiStun_Loop, FogRemoval_Conn}) do
        if cn then pcall(function() cn:Disconnect() end) end
    end
    Tw(MainFrame,0.22,{Size=UDim2.new(0,W*0.45,0,H*0.45),Position=UDim2.new(0.5,-W*0.225,0.5,-H*0.225)})
    task.delay(0.23,function()
        pcall(function() if FloatingLayer then FloatingLayer:Destroy() end end)
        pcall(function() if CPGui then CPGui:Destroy() end end)
        pcall(function() if ScreenGui then ScreenGui:Destroy() end end)
        pcall(function() if StatsHUD_Screen then StatsHUD_Screen:Destroy() end end)
        pcall(function() if ESP_Folder then ESP_Folder:Destroy() end end)
    end)
end

local function ApplyTheme(themeName)
    -- Rayfield handles its own theming; this is a no-op for compatibility
    Config.Theme = themeName or Config.Theme
end

-- [ SKY SYSTEM - must be defined before Rayfield GUI dropdowns ]
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

function SetChangeSky(on)
    if on then
        local id = SkyOptions[Config.ChangeSky_Selected]
        if id then ApplySkyById(id) end
    else
        ResetSky()
    end
end

-- [ RAYFIELD GUI ]
-- Rayfield dropdowns pass CurrentOption as a table {string} instead of a raw string.
local function GetDropdownValue(v)
    if type(v) == "table" then return v[1] end
    return v
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "phwyverysad",
    LoadingTitle = "phwyverysad Hub",
    LoadingSubtitle = "by phwyverysad",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "phwyverysad",
        FileName = "phwyverysad_v9"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = false
    },
    KeySystem = false
})

-- [ NOTIFICATIONS & HUD ]
local function ShowToast(msg, col)
    Rayfield:Notify({
        Title = "phwyverysad",
        Content = msg,
        Duration = 3,
        Image = nil,
        Actions = {}
    })
end

local function ShowConfirm(title, desc, onYes)
    Rayfield:Notify({
        Title = title,
        Content = desc,
        Duration = 8,
        Actions = {
            Confirm = {
                Name = "Yes",
                Callback = onYes
            },
            Decline = {
                Name = "No",
                Callback = function() end
            }
        }
    })
end

-- Stats HUD (simple ScreenGui label)
local StatsHUD_Screen = Instance.new("ScreenGui", CoreGui)
StatsHUD_Screen.Name = "PhwyHUD"
StatsHUD_Screen.ResetOnSpawn = false

local StatHUD = Instance.new("TextLabel", StatsHUD_Screen)
StatHUD.Size = UDim2.new(0, 200, 0, 30)
StatHUD.BackgroundTransparency = 1
StatHUD.TextColor3 = Color3.fromRGB(0, 240, 150)
StatHUD.Font = Enum.Font.GothamBold
StatHUD.TextStrokeTransparency = 0
StatHUD.TextStrokeColor3 = Color3.new(0, 0, 0)
StatHUD.TextSize = 14
StatHUD.Visible = false
StatHUD.TextXAlignment = Enum.TextXAlignment.Left

local HUDPositions = {
    TopLeft = UDim2.new(0, 10, 0, 10),
    TopRight = UDim2.new(1, -210, 0, 10),
    BottomLeft = UDim2.new(0, 10, 1, -40),
    BottomRight = UDim2.new(1, -210, 1, -40)
}
local function UpdateHUDPos()
    StatHUD.Position = HUDPositions[Config.HUDPosition] or HUDPositions.TopLeft
end

-- FOV Circle for Aimlock
local Circle = Drawing.new("Circle")
Circle.Thickness = 1.5
Circle.NumSides = 64
Circle.Filled = false
Circle.Transparency = 0.75
Circle.Color = Color3.fromRGB(30, 161, 255)
Circle.Visible = false
_G._PwyvCircle = Circle

-- Settings save/load (simplified for Rayfield)
local SAVE_FILE = "phwyverysad_v9.json"
local HttpService = cloneref(game:GetService("HttpService"))

function SaveSettings()
    -- Explicitly trigger Rayfield save if available
    if Rayfield and Rayfield.SaveConfiguration then
        pcall(function() Rayfield:SaveConfiguration() end)
    end
    -- Fallback: also write to JSON for external portability
    local function Serialize(val)
        if typeof(val) == "Color3" then
            return {__type="Color3", R=val.R, G=val.G, B=val.B}
        elseif typeof(val) == "EnumItem" then
            return {__type="Enum", Name=val.Name}
        elseif type(val) == "table" then
            local t = {}
            for k, v in pairs(val) do t[k] = Serialize(v) end
            return t
        end
        return val
    end
    local data = {}
    for k, v in pairs(Config) do
        data[k] = Serialize(v)
    end
    local ok = pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(data)) end)
    ShowToast(ok and "Saved! (Rayfield auto-saves)" or "Failed to save", ok and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end

local function ProcessKeybinds(input)
    return false
end

local function SyncUIFromConfig()
    pcall(function() if Config.WSToggle then SetWalkSpeed(true) end end)
    pcall(function() if Config.JPToggle then SetJumpPower(true) end end)
    pcall(function() if Config.Noclip then SetNoclip(true) end end)
    pcall(function() if Config.InfJump then SetInfJump(true) end end)
    pcall(function() if Config.FlyToggle then SetFly(true) end end)
    pcall(function() if Config.InfZoom then SetInfZoom(true) end end)
    pcall(function() if Config.AntiAFK then SetAntiAFK(true) end end)
    pcall(function() if Config.AntiStun then SetAntiStun(true) end end)
    pcall(function() if Config.HipHeightToggle then SetHipHeight(true) end end)
    pcall(function() if Config.Fullbright_Toggle then SetFullbright(true) end end)
    pcall(function() if Config.RemoveFog_Toggle then SetRemoveFog(true) end end)
    pcall(function() if Config.RTX_Enabled then SetRTX(true, true) end end)
    pcall(function() if Config.ChangeSky_Enabled then SetChangeSky(true) end end)
    pcall(function() if Config.FPSBooster then ApplyFPSBoost() end end)
    pcall(function() if Config.P_Xray then UpdateXray(XrayCache_P, true) end end)
end

function LoadSettings()
    local usedRayfield = false
    -- Prefer Rayfield built-in config loading via Flags + LoadConfiguration
    if Rayfield and Rayfield.LoadConfiguration then
        usedRayfield = pcall(function() Rayfield:LoadConfiguration() end)
        if usedRayfield then
            ShowToast("Settings loaded from Rayfield config!", Color3.fromRGB(50, 220, 90))
        end
    end
    -- Fallback: JSON file
    if not usedRayfield then
        local ok, content = pcall(readfile, SAVE_FILE)
        if not ok then ShowToast("No saved settings found", Color3.fromRGB(220, 60, 60)); return end
        local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok2 then ShowToast("Invalid settings file", Color3.fromRGB(220, 60, 60)); return end
        local function Deserialize(v)
            if type(v) == "table" and v.__type == "Color3" then
                return Color3.new(v.R, v.G, v.B)
            elseif type(v) == "table" and v.__type == "Enum" then
                return Enum.KeyCode[v.Name] or Enum.UserInputType[v.Name]
            elseif type(v) == "table" then
                local t = {}
                for k2, v2 in pairs(v) do t[k2] = Deserialize(v2) end
                return t
            end
            return v
        end
        for k, v in pairs(data) do
            if Config[k] ~= nil then
                Config[k] = Deserialize(v)
            end
        end
        ShowToast("Settings loaded from JSON!", Color3.fromRGB(50, 220, 90))
    end
    -- Apply loaded config to UI and features
    _G._PwyvSkipRTXConfirm = true
    SyncUIFromConfig()
    _G._PwyvSkipRTXConfirm = nil
end

-- Fog removal original storage
local FogRemoval_Original = {FogEnd = nil, FogStart = nil, AtmosphereDensity = nil}
local function SaveOriginalFog()
    pcall(function() FogRemoval_Original.FogEnd = Lighting.FogEnd end)
    pcall(function() FogRemoval_Original.FogStart = Lighting.FogStart end)
    pcall(function()
        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then FogRemoval_Original.AtmosphereDensity = atmos.Density end
    end)
end

-- ==========================================
-- RAYFIELD TABS & ELEMENTS
-- ==========================================

local TabAimlock = Window:CreateTab("Aimlock", nil)
local TabESP = Window:CreateTab("ESP Player", nil)
local TabPlayer = Window:CreateTab("Setting Player", nil)
local TabGraphic = Window:CreateTab("Graphic", nil)
local TabTeleport = Window:CreateTab("Player Teleport", nil)
local TabServer = Window:CreateTab("Server Details", nil)

-- Wrap Rayfield tab creators to store UI references for programmatic updates
local function WrapTabElementCreators(tab)
    if not tab then return end
    for _, methodName in ipairs({"CreateToggle", "CreateSlider", "CreateDropdown", "CreateColorPicker", "CreateKeybind"}) do
        local orig = tab[methodName]
        if type(orig) == "function" then
            tab[methodName] = function(self, props)
                local ref = orig(self, props)
                if props and props.Flag then
                    State.UIRefs[props.Flag] = ref
                end
                return ref
            end
        end
    end
end
WrapTabElementCreators(TabAimlock)
WrapTabElementCreators(TabESP)
WrapTabElementCreators(TabPlayer)
WrapTabElementCreators(TabGraphic)
WrapTabElementCreators(TabTeleport)
WrapTabElementCreators(TabServer)

-- AIMLOCK TAB
TabAimlock:CreateSection("Aim Assist")
TabAimlock:CreateToggle({
    Name = "Enable Aimlock",
    CurrentValue = Config.Aimlock,
    Flag = "Aimlock",
    Callback = function(v)
        Config.Aimlock = v
        if not v then LockedTarget = nil; State.ToggleAiming = false end
    end
})

TabAimlock:CreateDropdown({
    Name = "Aim Mode",
    Options = {"TOGGLE", "HOLD", "ALWAYS ON"},
    CurrentOption = Config.AimMode or "HOLD",
    Flag = "AimMode",
    Callback = function(opt)
        Config.AimMode = GetDropdownValue(opt)
    end
})

TabAimlock:CreateDropdown({
    Name = "Target Mode",
    Options = {"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"},
    CurrentOption = Config.TargetMode or "PLAYERS ONLY",
    Flag = "TargetMode",
    Callback = function(v) Config.TargetMode = GetDropdownValue(v) end
})

TabAimlock:CreateToggle({
    Name = "Enemy Only",
    CurrentValue = Config.EnemyOnly,
    Flag = "EnemyOnly",
    Callback = function(v) Config.EnemyOnly = v end
})

TabAimlock:CreateDropdown({
    Name = "Bind Type",
    Options = {"Keyboard", "Mouse"},
    CurrentOption = Config.BindType or "Keyboard",
    Flag = "BindType",
    Callback = function(v) Config.BindType = GetDropdownValue(v) end
})

TabAimlock:CreateKeybind({
    Name = "Aim Keybind",
    CurrentKeybind = Config.BindKey and Config.BindKey.Name or "Q",
    HoldToInteract = false,
    Flag = "AimKeybind",
    Callback = function(Keybind)
        if typeof(Keybind) == "EnumItem" then
            if Keybind.EnumType == Enum.UserInputType then
                Config.BindType = "Mouse"
                Config.BindKey = (Keybind == Enum.UserInputType.MouseButton1) and 1 or 2
            else
                Config.BindType = "Keyboard"
                Config.BindKey = Keybind
            end
        elseif type(Keybind) == "string" then
            Config.BindType = "Keyboard"
            Config.BindKey = Enum.KeyCode[Keybind]
        end
    end
})

TabAimlock:CreateSlider({
    Name = "FOV Radius",
    Range = {1, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.FOV,
    Flag = "FOV",
    Callback = function(v) Config.FOV = v end
})

TabAimlock:CreateSlider({
    Name = "Smoothing",
    Range = {0.01, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = Config.AimSmooth,
    Flag = "AimSmooth",
    Callback = function(v) Config.AimSmooth = v end
})

TabAimlock:CreateColorPicker({
    Name = "FOV Color",
    Color = Config.FOVColor_C3 or Color3.fromRGB(30, 161, 255),
    Flag = "FOVColor_C3",
    Callback = function(col) Config.FOVColor_C3 = col end
})

TabAimlock:CreateToggle({
    Name = "Wall Check",
    CurrentValue = Config.WallCheck,
    Flag = "WallCheck",
    Callback = function(v) Config.WallCheck = v end
})

TabAimlock:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "Torso", "HumanoidRootPart", "Auto"},
    CurrentOption = Config.AimTargetPart or "Head",
    Flag = "AimTargetPart",
    Callback = function(v) Config.AimTargetPart = GetDropdownValue(v) end
})

-- ESP TAB
TabESP:CreateSection("ESP Visuals")
TabESP:CreateToggle({
    Name = "Enable Visuals",
    CurrentValue = Config.P_Master,
    Flag = "P_Master",
    Callback = function(v) Config.P_Master = v end
})

TabESP:CreateToggle({
    Name = "View Distance Only",
    CurrentValue = Config.P_ESPInFOVOnly,
    Flag = "P_ESPInFOVOnly",
    Callback = function(v) Config.P_ESPInFOVOnly = v end
})

TabESP:CreateToggle({
    Name = "Show Names",
    CurrentValue = Config.P_ShowName,
    Flag = "P_ShowName",
    Callback = function(v) Config.P_ShowName = v end
})

TabESP:CreateToggle({
    Name = "Show Health",
    CurrentValue = Config.P_ShowHealth,
    Flag = "P_ShowHealth",
    Callback = function(v) Config.P_ShowHealth = v end
})

TabESP:CreateToggle({
    Name = "Show Distance",
    CurrentValue = Config.P_ShowDist,
    Flag = "P_ShowDist",
    Callback = function(v) Config.P_ShowDist = v end
})

TabESP:CreateToggle({
    Name = "Highlight Glow",
    CurrentValue = Config.P_Highlight,
    Flag = "P_Highlight",
    Callback = function(v) Config.P_Highlight = v end
})

TabESP:CreateToggle({
    Name = "Team Color",
    CurrentValue = Config.P_TeamColor,
    Flag = "P_TeamColor",
    Callback = function(v) Config.P_TeamColor = v end
})

TabESP:CreateToggle({
    Name = "Ignore Team",
    CurrentValue = Config.P_TeamCheck,
    Flag = "P_TeamCheck",
    Callback = function(v) Config.P_TeamCheck = v end
})

TabESP:CreateToggle({
    Name = "X-Ray Mode",
    CurrentValue = Config.P_Xray,
    Flag = "P_Xray",
    Callback = function(v)
        Config.P_Xray = v
        UpdateXray(XrayCache_P, v)
    end
})

TabESP:CreateSection("Customization")
TabESP:CreateColorPicker({
    Name = "Primary Color",
    Color = Config.P_Color_C3 or Color3.new(1, 1, 1),
    Flag = "P_Color_C3",
    Callback = function(col) Config.P_Color_C3 = col end
})

TabESP:CreateSlider({
    Name = "Text Size",
    Range = {8, 30},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.P_TextSize,
    Flag = "P_TextSize",
    Callback = function(v) Config.P_TextSize = v end
})

TabESP:CreateSlider({
    Name = "Fill Opacity",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = Config.P_FillTrans,
    Flag = "P_FillTrans",
    Callback = function(v) Config.P_FillTrans = v end
})

TabESP:CreateSlider({
    Name = "Outline Opacity",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = Config.P_OutlineTrans,
    Flag = "P_OutlineTrans",
    Callback = function(v) Config.P_OutlineTrans = v end
})

TabESP:CreateSection("Hitbox Expansion")
TabESP:CreateToggle({
    Name = "Enable Hitbox",
    CurrentValue = Config.P_HitboxToggle,
    Flag = "P_HitboxToggle",
    Callback = function(v)
        Config.P_HitboxToggle = v
        if not v then
            for char, sz in pairs(HitboxOriginalSizes) do
                pcall(function()
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Size = sz
                        hrp.Transparency = 1
                        hrp.Material = Enum.Material.SmoothPlastic
                        hrp.CanCollide = true
                    end
                end)
            end
            HitboxOriginalSizes = {}
        end
    end
})

TabESP:CreateDropdown({
    Name = "Target Selection",
    Options = {"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"},
    CurrentOption = Config.HitboxTargetMode or "PLAYERS ONLY",
    Flag = "HitboxTargetMode",
    Callback = function(v) Config.HitboxTargetMode = GetDropdownValue(v) end
})

TabESP:CreateSlider({
    Name = "Expansion Size",
    Range = {4, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.P_HitboxSize,
    Flag = "P_HitboxSize",
    Callback = function(v) Config.P_HitboxSize = v end
})

-- PLAYER TAB
TabPlayer:CreateSection("Animations")
TabPlayer:CreateButton({
    Name = "Open Emote Menu",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))()
        end)
    end
})

TabPlayer:CreateSection("Movement")
TabPlayer:CreateToggle({
    Name = "Super Walk",
    CurrentValue = Config.WSToggle,
    Flag = "WSToggle",
    Callback = function(v)
        Config.WSToggle = v
        SetWalkSpeed(v)
    end
})

TabPlayer:CreateSlider({
    Name = "Speed Value",
    Range = {16, 1000},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.WalkSpeed,
    Flag = "WalkSpeed",
    Callback = function(v)
        Config.WalkSpeed = v
        if Config.WSToggle then SetWalkSpeed(true) end
    end
})

TabPlayer:CreateToggle({
    Name = "Super Jump",
    CurrentValue = Config.JPToggle,
    Flag = "JPToggle",
    Callback = function(v)
        Config.JPToggle = v
        SetJumpPower(v)
    end
})

TabPlayer:CreateSlider({
    Name = "Jump Value",
    Range = {10, 1000},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.JumpPower,
    Flag = "JumpPower",
    Callback = function(v)
        Config.JumpPower = v
        if Config.JPToggle then SetJumpPower(true) end
    end
})

TabPlayer:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = Config.InfJump,
    Flag = "InfJump",
    Callback = function(v)
        Config.InfJump = v
        SetInfJump(v)
    end
})

TabPlayer:CreateToggle({
    Name = "Fly Mode",
    CurrentValue = Config.FlyToggle,
    Flag = "FlyToggle",
    Callback = function(v)
        Config.FlyToggle = v
        SetFly(v)
    end
})

TabPlayer:CreateSlider({
    Name = "Flying Speed",
    Range = {5, 500},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.FlySpeed,
    Flag = "FlySpeed",
    Callback = function(v) Config.FlySpeed = v end
})

TabPlayer:CreateToggle({
    Name = "No Clip",
    CurrentValue = Config.Noclip,
    Flag = "Noclip",
    Callback = function(v)
        Config.Noclip = v
        SetNoclip(v)
    end
})

TabPlayer:CreateToggle({
    Name = "Invisibility",
    CurrentValue = Config.InvisToggle,
    Flag = "InvisToggle",
    Callback = function(v)
        Config.InvisToggle = v
        SetInvisibility(v)
    end
})

TabPlayer:CreateToggle({
    Name = "Max Zoom",
    CurrentValue = Config.InfZoom,
    Flag = "InfZoom",
    Callback = function(v)
        Config.InfZoom = v
        SetInfZoom(v)
    end
})

TabPlayer:CreateToggle({
    Name = "Hip Height",
    CurrentValue = Config.HipHeightToggle,
    Flag = "HipHeightToggle",
    Callback = function(v)
        Config.HipHeightToggle = v
        SetHipHeight(v)
    end
})

TabPlayer:CreateSlider({
    Name = "Height Level",
    Range = {-100, 1000},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.HipHeightValue,
    Flag = "HipHeightValue",
    Callback = function(v) SetHipHeightValue(v) end
})

TabPlayer:CreateSection("Visual Environment")
TabPlayer:CreateToggle({
    Name = "Custom Field of View",
    CurrentValue = Config.FOVToggle,
    Flag = "FOVToggle",
    Callback = function(v)
        Config.FOVToggle = v
        if v then pcall(function() workspace.CurrentCamera.FieldOfView = Config.FOVView end)
        else pcall(function() workspace.CurrentCamera.FieldOfView = 70 end) end
    end
})

TabPlayer:CreateSlider({
    Name = "FOV Value",
    Range = {30, 360},
    Increment = 1,
    Suffix = " degrees",
    CurrentValue = Config.FOVView,
    Flag = "FOVView",
    Callback = function(v)
        Config.FOVView = v
        if Config.FOVToggle then pcall(function() workspace.CurrentCamera.FieldOfView = v end) end
    end
})

TabPlayer:CreateSection("Lighting")
TabPlayer:CreateToggle({
    Name = "Fullbright",
    CurrentValue = Config.Fullbright_Toggle or false,
    Flag = "Fullbright_Toggle",
    Callback = function(v)
        Config.Fullbright_Toggle = v
        SetFullbright(v)
    end
})

TabPlayer:CreateToggle({
    Name = "Disable Fog",
    CurrentValue = Config.RemoveFog_Toggle or false,
    Flag = "RemoveFog_Toggle",
    Callback = function(v)
        Config.RemoveFog_Toggle = v
        SetRemoveFog(v)
    end
})

TabPlayer:CreateSection("Interactions")
TabPlayer:CreateToggle({
    Name = "Fast Interact",
    CurrentValue = Config.InstantPress,
    Flag = "InstantPress",
    Callback = function(v)
        Config.InstantPress = v
        UpdateInteractables()
    end
})

TabPlayer:CreateToggle({
    Name = "Interaction Aura",
    CurrentValue = Config.AuraRange,
    Flag = "AuraRange",
    Callback = function(v)
        Config.AuraRange = v
        UpdateInteractables()
    end
})

TabPlayer:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = Config.AntiAFK,
    Flag = "AntiAFK",
    Callback = function(v)
        Config.AntiAFK = v
        SetAntiAFK(v)
    end
})

TabPlayer:CreateToggle({
    Name = "Anti Stun",
    CurrentValue = Config.AntiStun or false,
    Flag = "AntiStun",
    Callback = function(v)
        Config.AntiStun = v
        SetAntiStun(v)
    end
})

TabPlayer:CreateSection("Optimization")
TabPlayer:CreateToggle({
    Name = "Enable FPS Booster",
    CurrentValue = Config.FPSBooster,
    Flag = "FPSBooster",
    Callback = function(v)
        Config.FPSBooster = v
        if v then ApplyFPSBoost() else DisableFPSBoost() end
    end
})

TabPlayer:CreateToggle({
    Name = "Disable Shadows",
    CurrentValue = Config.FPS_NoShadows,
    Flag = "FPS_NoShadows",
    Callback = function(v) Config.FPS_NoShadows = v end
})

TabPlayer:CreateToggle({
    Name = "Clear Particles",
    CurrentValue = Config.FPS_NoParticles,
    Flag = "FPS_NoParticles",
    Callback = function(v) Config.FPS_NoParticles = v end
})

TabPlayer:CreateToggle({
    Name = "Strip Outfits",
    CurrentValue = Config.FPS_NoClothes,
    Flag = "FPS_NoClothes",
    Callback = function(v) Config.FPS_NoClothes = v end
})

TabPlayer:CreateToggle({
    Name = "Low Mesh Quality",
    CurrentValue = Config.FPS_LowQuality,
    Flag = "FPS_LowQuality",
    Callback = function(v) Config.FPS_LowQuality = v end
})

TabPlayer:CreateSection("Interface Info")
TabPlayer:CreateDropdown({
    Name = "Data Display",
    Options = {"FPS", "Ping", "FPS & Ping"},
    CurrentOption = Config.ShowFPSPing or "FPS & Ping",
    Flag = "ShowFPSPing",
    Callback = function(v) Config.ShowFPSPing = GetDropdownValue(v) end
})

TabPlayer:CreateToggle({
    Name = "Show Activity HUD",
    CurrentValue = Config.ShowStatsToggle,
    Flag = "ShowStatsToggle",
    Callback = function(v)
        Config.ShowStatsToggle = v
        StatHUD.Visible = v
    end
})

TabPlayer:CreateDropdown({
    Name = "HUD Position",
    Options = {"TopLeft", "TopRight", "BottomLeft", "BottomRight"},
    CurrentOption = Config.HUDPosition or "TopRight",
    Flag = "HUDPosition",
    Callback = function(v)
        Config.HUDPosition = GetDropdownValue(v)
        UpdateHUDPos()
    end
})

TabPlayer:CreateSection("Save/Load")
TabPlayer:CreateButton({
    Name = "Save My Settings",
    Callback = SaveSettings
})

TabPlayer:CreateButton({
    Name = "Load Settings",
    Callback = LoadSettings
})

TabPlayer:CreateToggle({
    Name = "Auto Load Settings",
    CurrentValue = Config.AutoLoadSettings,
    Flag = "AutoLoadSettings",
    Callback = function(v) Config.AutoLoadSettings = v end
})

TabPlayer:CreateButton({
    Name = "Reset All Settings",
    Callback = function()
        ResetAllSettings()
    end
})

TabPlayer:CreateButton({
    Name = "Delete Saved Config",
    Callback = function()
        local ok = pcall(function() delfile(SAVE_FILE) end)
        ShowToast(ok and "Config deleted" or "No file to delete", ok and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
    end
})

-- GRAPHIC TAB
TabGraphic:CreateSection("Ray Tracing")
TabGraphic:CreateToggle({
    Name = "Ray Tracing",
    CurrentValue = Config.RTX_Enabled,
    Flag = "RTX_Enabled",
    Callback = function(v)
        Config.RTX_Enabled = v
        SetRTX(v, _G._PwyvSkipRTXConfirm)
    end
})

TabGraphic:CreateSection("Change the Sky")
TabGraphic:CreateToggle({
    Name = "Change Sky",
    CurrentValue = Config.ChangeSky_Enabled,
    Flag = "ChangeSky_Enabled",
    Callback = function(v)
        Config.ChangeSky_Enabled = v
        SetChangeSky(v)
    end
})

TabGraphic:CreateDropdown({
    Name = "Sky Selection",
    Options = SkyList,
    CurrentOption = Config.ChangeSky_Selected or "Anime-sky",
    Flag = "ChangeSky_Selected",
    Callback = function(v)
        local sel = GetDropdownValue(v)
        Config.ChangeSky_Selected = sel
        if Config.ChangeSky_Enabled then
            local id = SkyOptions[sel]
            if id then ApplySkyById(id) end
        end
    end
})

-- TELEPORT TAB
TabTeleport:CreateSection("Target Tracking")

-- Build player list dynamically for dropdowns
local function GetPlayerNames()
    local list = {"-"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

local TPDropdown = TabTeleport:CreateDropdown({
    Name = "Target Player",
    Options = GetPlayerNames(),
    CurrentOption = Config.TPTarget or "-",
    Flag = "TPTarget",
    Callback = function(v) Config.TPTarget = GetDropdownValue(v) end
})

-- Refresh player list periodically
task.spawn(function()
    while State.Running do
        task.wait(5)
        local names = GetPlayerNames()
        pcall(function() TPDropdown:Refresh(names) end)
    end
end)

TabTeleport:CreateDropdown({
    Name = "Tracking Mode",
    Options = {"Safe Fly", "Warp"},
    CurrentOption = Config.TPMode or "Warp",
    Flag = "TPMode",
    Callback = function(v) Config.TPMode = GetDropdownValue(v) end
})

TabTeleport:CreateSlider({
    Name = "Follow Speed",
    Range = {10, 500},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.TPFlightSens,
    Flag = "TPFlightSens",
    Callback = function(v) Config.TPFlightSens = v end
})

TabTeleport:CreateToggle({
    Name = "Activate System",
    CurrentValue = Config.TPGOSwitch,
    Flag = "TPGOSwitch",
    Callback = function(v)
        Config.TPGOSwitch = v
        if v and Config.TPTarget ~= "-" then
            local tp = Players:FindFirstChild(Config.TPTarget)
            if tp then
                if Config.TPMode == "Safe Fly" then
                    StartSafeTP(tp)
                else
                    local tHRP = tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
                    if tHRP and LocalPlayer.Character then
                        pcall(function() LocalPlayer.Character:PivotTo(tHRP.CFrame * CFrame.new(0, 0, 3)) end)
                    end
                end
            end
        else
            StopSafeTP()
        end
    end
})

TabTeleport:CreateSection("Spectator Mode")
local SpecDropdown = TabTeleport:CreateDropdown({
    Name = "Watch Player",
    Options = GetPlayerNames(),
    CurrentOption = Config.SpecTarget or "-",
    Flag = "SpecTarget",
    Callback = function(v) Config.SpecTarget = GetDropdownValue(v) end
})

-- Refresh spectator list periodically
task.spawn(function()
    while State.Running do
        task.wait(5)
        local names = GetPlayerNames()
        pcall(function() SpecDropdown:Refresh(names) end)
    end
end)

TabTeleport:CreateToggle({
    Name = "Enable Eye",
    CurrentValue = Config.SpecToggle,
    Flag = "SpecToggle",
    Callback = function(v)
        Config.SpecToggle = v
        if not v then
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then Camera.CameraSubject = h end
        end
    end
})

TabTeleport:CreateSection("Mouse Teleportation")
TabTeleport:CreateKeybind({
    Name = "Teleport Key",
    CurrentKeybind = Config.ClickTPBindKey and Config.ClickTPBindKey.Name or "C",
    HoldToInteract = false,
    Flag = "ClickTPBindKey",
    Callback = function(Keybind)
        if typeof(Keybind) == "EnumItem" then
            if Keybind.EnumType == Enum.UserInputType then
                Config.ClickTPBindType = "Mouse"
                Config.ClickTPBindKey = (Keybind == Enum.UserInputType.MouseButton1) and 1 or 2
            else
                Config.ClickTPBindType = "Keyboard"
                Config.ClickTPBindKey = Keybind
            end
        elseif type(Keybind) == "string" then
            Config.ClickTPBindType = "Keyboard"
            Config.ClickTPBindKey = Enum.KeyCode[Keybind]
        end
    end
})

TabTeleport:CreateToggle({
    Name = "Enable Click-TP",
    CurrentValue = Config.ClickTPToggle,
    Flag = "ClickTPToggle",
    Callback = function(v) Config.ClickTPToggle = v end
})

-- SERVER INFO TAB
TabServer:CreateSection("Server Information")

local nameBtnRef = TabServer:CreateButton({
    Name = "Game Name: Loading...",
    Callback = function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        local name = info and info.Name or game.Name
        if setclipboard then
            setclipboard(name)
            ShowToast("Copied game name!", Color3.fromRGB(50, 220, 90))
        end
    end
})

task.spawn(function()
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then
            local displayName = "Game Name: " .. info.Name
            pcall(function() nameBtnRef:Set(displayName) end)
        end
    end)
end)

TabServer:CreateButton({
    Name = "Copy Creator ID: " .. tostring(game.CreatorId),
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.CreatorId))
            ShowToast("Copied Creator ID!", Color3.fromRGB(50, 220, 90))
        end
    end
})

TabServer:CreateButton({
    Name = "Copy Place ID: " .. tostring(game.PlaceId),
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            ShowToast("Copied Place ID!", Color3.fromRGB(50, 220, 90))
        end
    end
})

TabServer:CreateButton({
    Name = "Copy Job ID: " .. tostring(game.JobId),
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.JobId))
            ShowToast("Copied Job ID!", Color3.fromRGB(50, 220, 90))
        end
    end
})

TabServer:CreateButton({
    Name = "Copy Direct Join Link",
    Callback = function()
        local link = "roblox://experiences/start?placeId=" .. tostring(game.PlaceId) .. "&gameInstanceId=" .. tostring(game.JobId)
        if setclipboard then
            setclipboard(link)
            ShowToast("Copied direct join link!", Color3.fromRGB(50, 220, 90))
        end
    end
})

TabServer:CreateButton({
    Name = "Copy JS Join Script",
    Callback = function()
        local code = "Roblox.GameLauncher.joinGameInstance(" .. tostring(game.PlaceId) .. ", '" .. tostring(game.JobId) .. "');"
        if setclipboard then
            setclipboard(code)
            ShowToast("Copied JS script!", Color3.fromRGB(50, 220, 90))
        end
    end
})

TabServer:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        ShowToast("Rejoining...", Color3.fromRGB(30, 161, 255))
        local ts = game:GetService("TeleportService")
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("Rejoining...")
            task.wait()
            ts:Teleport(game.PlaceId, LocalPlayer)
        else
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end
})

TabServer:CreateButton({
    Name = "Server Hop",
    Callback = function()
        ShowToast("Switching server...", Color3.fromRGB(30, 161, 255))
        local ts = game:GetService("TeleportService")
        ts:Teleport(game.PlaceId, LocalPlayer)
    end
})


-- [ MOBILE SUPPORT ]
local GuiService = cloneref(game:GetService("GuiService"))

-- Detect mobile platform
local isMobile = false
pcall(function()
    isMobile = UIS.TouchEnabled and (not UIS.KeyboardEnabled or UIS.MouseEnabled == false)
end)

-- Mobile GUI Container
local MobileGui = Instance.new("ScreenGui", CoreGui)
MobileGui.Name = "PhwyMobile"
MobileGui.ResetOnSpawn = false
MobileGui.Enabled = isMobile

-- Quick Toggles Panel
local MobFrame = Instance.new("ScrollingFrame", MobileGui)
MobFrame.Name = "QuickToggles"
MobFrame.Size = UDim2.new(0, 200, 0, 320)
MobFrame.Position = UDim2.new(1, -210, 1, -330)
MobFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MobFrame.BackgroundTransparency = 0.15
MobFrame.BorderSizePixel = 0
MobFrame.Active = true
MobFrame.ScrollBarThickness = 4
MobFrame.ScrollingDirection = Enum.ScrollingDirection.Y
MobFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
local mc = Instance.new("UICorner", MobFrame); mc.CornerRadius = UDim.new(0, 12)
local ms = Instance.new("UIStroke", MobFrame); ms.Color = Color3.fromRGB(60, 60, 80); ms.Thickness = 1

local MobTitle = Instance.new("TextLabel", MobFrame)
MobTitle.Size = UDim2.new(1, 0, 0, 28)
MobTitle.BackgroundTransparency = 1
MobTitle.Text = "Quick Toggles"
MobTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
MobTitle.Font = Enum.Font.GothamBold
MobTitle.TextSize = 14

local MobList = Instance.new("UIListLayout", MobFrame)
MobList.Padding = UDim.new(0, 6)
MobList.FillDirection = Enum.FillDirection.Vertical
MobList.HorizontalAlignment = Enum.HorizontalAlignment.Center
MobList.VerticalAlignment = Enum.VerticalAlignment.Top

local function MakeMobBtn(text, color, callback)
    local btn = Instance.new("TextButton", MobFrame)
    btn.Size = UDim2.new(0, 180, 0, 36)
    btn.BackgroundColor3 = color or Color3.fromRGB(40, 40, 55)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 240)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    local bc = Instance.new("UICorner", btn); bc.CornerRadius = UDim.new(0, 8)
    local bs = Instance.new("UIStroke", btn); bs.Color = Color3.fromRGB(80, 80, 100); bs.Thickness = 0.8
    btn.MouseButton1Click:Connect(callback)
    return btn
end

MakeMobBtn("Aim Toggle", Color3.fromRGB(80, 40, 40), function()
    Config.Aimlock = not Config.Aimlock
    if not Config.Aimlock then LockedTarget = nil; State.ToggleAiming = false end
    ShowToast(Config.Aimlock and "Aimlock ON" or "Aimlock OFF", Config.Aimlock and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("ESP Toggle", Color3.fromRGB(40, 80, 40), function()
    Config.P_Master = not Config.P_Master
    ShowToast(Config.P_Master and "ESP ON" or "ESP OFF", Config.P_Master and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Fly Toggle", Color3.fromRGB(40, 40, 80), function()
    Config.FlyToggle = not Config.FlyToggle
    SetFly(Config.FlyToggle)
    ShowToast(Config.FlyToggle and "Fly ON" or "Fly OFF", Config.FlyToggle and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Noclip Toggle", Color3.fromRGB(80, 80, 40), function()
    Config.Noclip = not Config.Noclip
    SetNoclip(Config.Noclip)
    ShowToast(Config.Noclip and "Noclip ON" or "Noclip OFF", Config.Noclip and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Hitbox Toggle", Color3.fromRGB(80, 40, 80), function()
    Config.P_HitboxToggle = not Config.P_HitboxToggle
    if not Config.P_HitboxToggle then
        for char, sz in pairs(HitboxOriginalSizes) do
            pcall(function()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Size = sz; hrp.Transparency = 1; hrp.Material = Enum.Material.SmoothPlastic; hrp.CanCollide = true end
            end)
        end
        HitboxOriginalSizes = {}
    end
    ShowToast(Config.P_HitboxToggle and "Hitbox ON" or "Hitbox OFF", Config.P_HitboxToggle and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Fullbright", Color3.fromRGB(80, 80, 30), function()
    SetFullbright(not Config.Fullbright_Toggle)
    ShowToast(Config.Fullbright_Toggle and "Fullbright ON" or "Fullbright OFF", Config.Fullbright_Toggle and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Inf Jump", Color3.fromRGB(40, 60, 80), function()
    Config.InfJump = not Config.InfJump
    SetInfJump(Config.InfJump)
    ShowToast(Config.InfJump and "InfJump ON" or "InfJump OFF", Config.InfJump and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Super Walk", Color3.fromRGB(80, 40, 40), function()
    Config.WSToggle = not Config.WSToggle
    SetWalkSpeed(Config.WSToggle)
    ShowToast(Config.WSToggle and "Speed ON" or "Speed OFF", Config.WSToggle and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Super Jump", Color3.fromRGB(40, 80, 40), function()
    Config.JPToggle = not Config.JPToggle
    SetJumpPower(Config.JPToggle)
    ShowToast(Config.JPToggle and "Jump ON" or "Jump OFF", Config.JPToggle and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Anti-AFK", Color3.fromRGB(80, 60, 20), function()
    Config.AntiAFK = not Config.AntiAFK
    SetAntiAFK(Config.AntiAFK)
    ShowToast(Config.AntiAFK and "AntiAFK ON" or "AntiAFK OFF", Config.AntiAFK and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Anti Stun", Color3.fromRGB(60, 40, 80), function()
    Config.AntiStun = not Config.AntiStun
    SetAntiStun(Config.AntiStun)
    ShowToast(Config.AntiStun and "AntiStun ON" or "AntiStun OFF", Config.AntiStun and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("Hip Height", Color3.fromRGB(40, 60, 80), function()
    Config.HipHeightToggle = not Config.HipHeightToggle
    SetHipHeight(Config.HipHeightToggle)
    ShowToast(Config.HipHeightToggle and "HipHeight ON" or "HipHeight OFF", Config.HipHeightToggle and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

MakeMobBtn("FPS Boost", Color3.fromRGB(60, 80, 40), function()
    Config.FPSBooster = not Config.FPSBooster
    if Config.FPSBooster then ApplyFPSBoost() else DisableFPSBoost() end
    ShowToast(Config.FPSBooster and "FPS Boost ON" or "FPS Boost OFF", Config.FPSBooster and Color3.fromRGB(50, 220, 90) or Color3.fromRGB(220, 60, 60))
end)

-- Mobile Fly Directional Pad
local FlyPad = Instance.new("Frame", MobileGui)
FlyPad.Name = "FlyPad"
FlyPad.Size = UDim2.new(0, 150, 0, 150)
FlyPad.Position = UDim2.new(0, 10, 1, -160)
FlyPad.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
FlyPad.BackgroundTransparency = 0.2
FlyPad.BorderSizePixel = 0
FlyPad.Active = true
FlyPad.Visible = false
local fc = Instance.new("UICorner", FlyPad); fc.CornerRadius = UDim.new(0, 75)
local fs = Instance.new("UIStroke", FlyPad); fs.Color = Color3.fromRGB(80, 80, 100); fs.Thickness = 1.5

_G._PwyvMobileFlyDir = {X = 0, Y = 0, Z = 0}

local function MakeFlyBtn(name, pos, dirX, dirY, dirZ)
    local btn = Instance.new("TextButton", FlyPad)
    btn.Name = name
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    btn.BackgroundTransparency = 0.3
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    local bcc = Instance.new("UICorner", btn); bcc.CornerRadius = UDim.new(0, 22)
    
    local function updateDir(deltaX, deltaY, deltaZ, add)
        local mult = add and 1 or -1
        _G._PwyvMobileFlyDir.X = math.clamp(_G._PwyvMobileFlyDir.X + deltaX * mult, -1, 1)
        _G._PwyvMobileFlyDir.Y = math.clamp(_G._PwyvMobileFlyDir.Y + deltaY * mult, -1, 1)
        _G._PwyvMobileFlyDir.Z = math.clamp(_G._PwyvMobileFlyDir.Z + deltaZ * mult, -1, 1)
    end
    
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            updateDir(dirX, dirY, dirZ, true)
            btn.BackgroundColor3 = Color3.fromRGB(100, 100, 140)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            updateDir(dirX, dirY, dirZ, false)
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        end
    end)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(80, 80, 110) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80) end)
end

MakeFlyBtn("Up",   UDim2.new(0.5, -22, 0, 4),    0,  1,  0)
MakeFlyBtn("Down", UDim2.new(0.5, -22, 1, -48),  0, -1,  0)
MakeFlyBtn("Fwd",  UDim2.new(0.5, -22, 0.5, -22), 0,  0,  1)
MakeFlyBtn("Back", UDim2.new(0, 4, 0.5, -22),      0,  0, -1)
MakeFlyBtn("Right",UDim2.new(1, -48, 0.5, -22),    1,  0,  0)
MakeFlyBtn("Left", UDim2.new(0, 4, 0.5, -22),      -1, 0,  0)

-- Mobile Menu / Quick Toggle Visibility Button
local MobMenuBtn = Instance.new("TextButton", MobileGui)
MobMenuBtn.Size = UDim2.new(0, 50, 0, 50)
MobMenuBtn.Position = UDim2.new(0, 10, 0, 10)
MobMenuBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
MobMenuBtn.Text = "Q"
MobMenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MobMenuBtn.TextSize = 20
MobMenuBtn.Font = Enum.Font.GothamBold
MobMenuBtn.AutoButtonColor = false
local mbc = Instance.new("UICorner", MobMenuBtn); mbc.CornerRadius = UDim.new(0, 12)
local mbs = Instance.new("UIStroke", MobMenuBtn); mbs.Color = Color3.fromRGB(80, 80, 100); mbs.Thickness = 1.2

MobMenuBtn.MouseButton1Click:Connect(function()
    MobFrame.Visible = not MobFrame.Visible
    FlyPad.Visible = Config.FlyToggle and MobFrame.Visible
end)

-- Mobile Touch Teleport (double tap)
local lastTapTime = 0
local lastTapPos = Vector2.new(0, 0)
if isMobile then
    AddConn(UIS.TouchTap:Connect(function(touchPositions, gameProcessedEvent)
        if gameProcessedEvent then return end
        if not Config.ClickTPToggle then return end
        local now = tick()
        local pos = touchPositions[1]
        if pos and lastTapPos and (pos - lastTapPos).Magnitude < 40 then
            if now - lastTapTime < 0.35 then
                local lpc = LocalPlayer.Character
                if lpc then
                    local ray = Camera:ViewportPointToRay(pos.X, pos.Y)
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000)
                    if result then
                        pcall(function() lpc:PivotTo(CFrame.new(result.Position + Vector3.new(0, 3, 0))) end)
                        ShowToast("Teleported!", Color3.fromRGB(50, 220, 90))
                    end
                end
                lastTapTime = 0
                return
            end
        end
        lastTapTime = now
        if pos then lastTapPos = pos end
    end))
end

-- Mobile Aim Button (center-right)
local MobAimBtn = Instance.new("TextButton", MobileGui)
MobAimBtn.Size = UDim2.new(0, 70, 0, 70)
MobAimBtn.Position = UDim2.new(1, -80, 0.5, -35)
MobAimBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
MobAimBtn.BackgroundTransparency = 0.3
MobAimBtn.Text = "AIM"
MobAimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MobAimBtn.TextSize = 16
MobAimBtn.Font = Enum.Font.GothamBold
MobAimBtn.AutoButtonColor = false
MobAimBtn.Visible = isMobile
local mab = Instance.new("UICorner", MobAimBtn); mab.CornerRadius = UDim.new(0, 35)
local mas = Instance.new("UIStroke", MobAimBtn); mas.Color = Color3.fromRGB(200, 50, 50); mas.Thickness = 2

MobAimBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        if Config.AimMode == "HOLD" then
            State.ToggleAiming = true
        elseif Config.AimMode == "TOGGLE" then
            State.ToggleAiming = not State.ToggleAiming
            if not State.ToggleAiming then LockedTarget = nil end
        end
        MobAimBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
    end
end)

MobAimBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        if Config.AimMode == "HOLD" then
            State.ToggleAiming = false
            LockedTarget = nil
        end
        MobAimBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    end
end)

-- Update fly pad visibility (only show when mobile panel is open)
AddConn(RunService.RenderStepped:Connect(function()
    if isMobile then
        FlyPad.Visible = Config.FlyToggle and MobFrame.Visible
    end
end))

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
        local mode = Config.TargetMode
        local camPos = Camera.CFrame.Position
        -- Players
        if mode=="PLAYERS ONLY" or mode=="PLAYERS & NPCs" then
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
        if mode=="NPCs ONLY" or mode=="PLAYERS & NPCs" then
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
function SetInvisibility(on)
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
local RTXLoaded = false
function SetRTX(on, skipConfirm)
    if on and not RTXLoaded then
        local ok = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/phwyverysad/script-roblox/refs/heads/main/rtx.lua"))()
        end)
        if ok then
            RTXLoaded = true
            Config.RTX_Enabled = true
            ShowToast("เปิด Ray Tracing แล้ว", Color3.fromRGB(50, 220, 90))
        else
            RTXLoaded = false
            Config.RTX_Enabled = false
            ShowToast("โหลด Ray Tracing ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต/ลิงก์", Color3.fromRGB(220, 60, 60))
        end
    elseif not on then
        Config.RTX_Enabled = false
        if not skipConfirm then
            ShowToast("Ray Tracing ไม่สามารถปิดได้ทันที กรุณารันสคริปต์ใหม่หากต้องการปิด", Color3.fromRGB(220, 60, 60))
        end
    end
end

function SetWalkSpeed(on)
    if WS_Loop then WS_Loop:Disconnect(); WS_Loop=nil end
    if on then
        WS_Loop=RunService.RenderStepped:Connect(function(dt)
            local lpc = LocalPlayer.Character
            if not lpc then return end
            local h = lpc:FindFirstChildOfClass("Humanoid")
            local hrp = lpc:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.MoveDirection.Magnitude > 0 then
                h.WalkSpeed = Config.WalkSpeed
                local md = h.MoveDirection
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * Config.WalkSpeed, hrp.AssemblyLinearVelocity.Y, md.Z * Config.WalkSpeed)
            end
        end)
    else
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed = 16 end) end
    end
end
function SetJumpPower(on)
    if JP_Loop then JP_Loop:Disconnect(); JP_Loop = nil end
    if on then
        JP_Loop = RunService.Heartbeat:Connect(function()
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.UseJumpPower = true; h.JumpPower = Config.JumpPower end
        end)
    else
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.UseJumpPower = true; h.JumpPower = 50 end
    end
end

function SetNoclip(on)
    if NC_Conn then NC_Conn:Disconnect(); NC_Conn = nil end
    if on then
        NC_Conn = RunService.Stepped:Connect(function()
            local lpc = LocalPlayer.Character
            if lpc then
                for _, p in ipairs(lpc:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
        local lpc = LocalPlayer.Character
        if lpc then
            for _, p in ipairs(lpc:GetDescendants()) do
                pcall(function() if p:IsA("BasePart") then p.CanCollide = true end end)
            end
        end
    end
end

function SetInfJump(on)
    if IJ_Conn then IJ_Conn:Disconnect(); IJ_Conn = nil end
    if on then
        IJ_Conn = UIS.JumpRequest:Connect(function()
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

function SetAntiAFK(on)
    if AFK_Conn then AFK_Conn:Disconnect(); AFK_Conn = nil end
    if on and VirtualUser then
        AFK_Conn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end
function SetAntiStun(on)
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
function SetInfZoom(on)
    if on then
        _origMaxZoom = LocalPlayer.CameraMaxZoomDistance -- save current max
        LocalPlayer.CameraMaxZoomDistance = math.huge    -- unlimited max zoom
        LocalPlayer.CameraMinZoomDistance = 0            -- allow first-person (min zoom)
    else
        LocalPlayer.CameraMaxZoomDistance = _origMaxZoom  -- restore max
        LocalPlayer.CameraMinZoomDistance = _origMinZoom           -- restore default min (allow first-person)
    end
end
function UpdateInteractables()
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
function UpdateXray(cache,enabled) if enabled then for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("BasePart") then local ic=v.Parent:FindFirstChildWhichIsA("Humanoid") or (v.Parent.Parent and v.Parent.Parent:FindFirstChildWhichIsA("Humanoid")); if not ic then if not cache[v] then cache[v]=v.LocalTransparencyModifier end; v.LocalTransparencyModifier=0.5 end end end else for p,o in pairs(cache) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=o end end) end; table.clear(cache) end end
local CFly_Loop = nil
function SetFly(on) 
    local lpc=LocalPlayer.Character; if not lpc then return end
    local hum=lpc:FindFirstChildOfClass("Humanoid")
    local hrp=lpc:FindFirstChild("HumanoidRootPart")
    if on and hrp then 
        -- Cleanup old deprecated or modern instances
        if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG=nil end
        if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV=nil end
        if FlyAO then pcall(function() FlyAO:Destroy() end); FlyAO=nil end
        if FlyLV then pcall(function() FlyLV:Destroy() end); FlyLV=nil end
        if CFly_Loop then CFly_Loop:Disconnect(); CFly_Loop=nil end
        
        -- Create AlignOrientation (replaces BodyGyro)
        FlyAO = Instance.new("AlignOrientation")
        FlyAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
        local aoAtt = Instance.new("Attachment", hrp)
        FlyAO.Attachment0 = aoAtt
        FlyAO.AlignType = Enum.AlignType.Parallel
        FlyAO.RigidityEnabled = false
        FlyAO.Responsiveness = 200
        FlyAO.MaxTorque = 9e9
        FlyAO.Parent = hrp
        
        -- Create LinearVelocity (replaces BodyVelocity)
        FlyLV = Instance.new("LinearVelocity")
        FlyLV.MaxForce = 9e9
        FlyLV.VectorVelocity = Vector3.new(0,0,0)
        FlyLV.Attachment0 = aoAtt
        FlyLV.Parent = hrp
        
        if hum then hum.PlatformStand=true end
        pcall(function() lpc.Animate.Disabled=true end)
        
        local cam = workspace.CurrentCamera
        CFly_Loop = RunService.RenderStepped:Connect(function()
            if not lpc or not lpc:FindFirstChild("HumanoidRootPart") then return end
            if not Config.FlyToggle then return end
            local speed = Config.FlySpeed or 50
            local vel = Vector3.new(0,0,0)
            -- Keyboard input
            if UIS:IsKeyDown(Enum.KeyCode.W) then vel = vel + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then vel = vel - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then vel = vel - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then vel = vel + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end
            -- Mobile D-pad input
            local mobDir = _G._PwyvMobileFlyDir
            if mobDir and (mobDir.X ~= 0 or mobDir.Y ~= 0 or mobDir.Z ~= 0) then
                vel = vel + (cam.CFrame.LookVector * mobDir.Z)
                vel = vel + (cam.CFrame.RightVector * mobDir.X)
                vel = vel + (Vector3.new(0, 1, 0) * mobDir.Y)
            end
            if FlyLV then
                FlyLV.VectorVelocity = vel.Magnitude > 0 and (vel.Unit * speed) or Vector3.new(0,0,0)
            end
            if FlyAO then
                FlyAO.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
            end
            for _,p in ipairs(lpc:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
        end)
    else 
        if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG=nil end
        if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV=nil end
        if FlyAO then pcall(function() FlyAO:Destroy() end); FlyAO=nil end
        if FlyLV then pcall(function() FlyLV:Destroy() end); FlyLV=nil end
        if hum then hum.PlatformStand=false end
        pcall(function() lpc.Animate.Disabled=false end)
        if CFly_Loop then CFly_Loop:Disconnect(); CFly_Loop=nil end
        for _,p in ipairs(lpc:GetDescendants()) do pcall(function() if p:IsA("BasePart") then p.CanCollide=true end end) end
    end 
end
function ApplyFPSBoost()
    if Config.FPS_NoShadows then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
        end)
    end
    if Config.FPS_LowQuality then
        pcall(function() settings().Rendering.QualityLevel = 1 end)
    end
    if FPS_DescConn then
        FPS_DescConn:Disconnect()
        FPS_DescConn = nil
    end
    local function Proc(inst)
        if inst:IsDescendantOf(Players) then return end
        if Config.FPS_NoParticles and (inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles")) then
            inst.Enabled = false
        end
        if Config.FPS_NoClothes and (inst:IsA("Clothing") or inst:IsA("SurfaceAppearance") or inst:IsA("BaseWrap")) then
            pcall(function() inst:Destroy() end)
            return
        end
        if Config.FPS_LowQuality then
            if inst:IsA("BasePart") then
                pcall(function()
                    inst.Material = Enum.Material.Plastic
                    inst.Reflectance = 0
                end)
            end
        end
        if inst:IsA("PostEffect") then
            pcall(function() inst.Enabled = false end)
        end
    end
    task.spawn(function()
        for i, v in ipairs(game:GetDescendants()) do
            pcall(function() Proc(v) end)
            if i % 1000 == 0 then task.wait() end
        end
    end)
    FPS_DescConn = game.DescendantAdded:Connect(function(v)
        task.wait(0.3)
        pcall(function() Proc(v) end)
    end)
end
function DisableFPSBoost()
    if FPS_DescConn then
        FPS_DescConn:Disconnect()
        FPS_DescConn = nil
    end
    pcall(function() Lighting.GlobalShadows = true end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
end

function StartSafeTP(tp)
    if SafeTP_Conn then
        SafeTP_Conn:Disconnect()
        SafeTP_Conn = nil
    end
    SafeTP_Conn = RunService.Heartbeat:Connect(function(dt)
        if not Config.TPGOSwitch then
            SafeTP_Conn:Disconnect()
            SafeTP_Conn = nil
            return
        end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local tHRP = tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
        if not (myHRP and tHRP) then return end
        if (tHRP.Position - myHRP.Position).Magnitude > 4 then
            myHRP.CFrame = myHRP.CFrame:Lerp(
                CFrame.new(tHRP.Position + tHRP.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)),
                math.clamp(dt * math.clamp(Config.TPFlightSens, 10, 500) * 0.12, 0.01, 0.4)
            )
        end
    end)
end

function StopSafeTP()
    if SafeTP_Conn then
        SafeTP_Conn:Disconnect()
        SafeTP_Conn = nil
    end
end

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

function SetHipHeight(on)
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
            if lastUpdate < 3 then 
                return 
            end -- อัพเดตทุก 3 frames
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

function SetHipHeightValue(newValue)
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

function SetFullbright(on)
    Config.Fullbright_Toggle = on
    if on then
        pcall(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 9e9
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end)
    else
        -- Restore original values if available, otherwise defaults
        local o = _G._PwyvOrig or {}
        pcall(function() Lighting.Brightness = o.Brightness or 1 end)
        pcall(function() Lighting.ClockTime = o.ClockTime or 14 end)
        pcall(function() Lighting.FogEnd = o.FogEnd or 1e6 end)
        pcall(function() Lighting.GlobalShadows = (o.GlobalShadows ~= nil) and o.GlobalShadows or true end)
        pcall(function() Lighting.OutdoorAmbient = o.OutdoorAmbient or Color3.fromRGB(128, 128, 128) end)
    end
end

function SetRemoveFog(on)
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

LocalPlayer.CharacterAdded:Connect(function() task.wait(0.7); FlyBG=nil; FlyBV=nil; FlyAO=nil; FlyLV=nil; if Config.WSToggle then SetWalkSpeed(true) end; if Config.JPToggle then SetJumpPower(true) end; if Config.Noclip then SetNoclip(true) end; if Config.InfJump then SetInfJump(true) end; if Config.FlyToggle then SetFly(true) end; if Config.InfZoom then SetInfZoom(true) end; if Config.HipHeightToggle then SetHipHeight(true) end; if Config.AntiStun then SetAntiStun(true) end end)
AddConn(RunService.RenderStepped:Connect(function() Stats.frameCount = Stats.frameCount + 1 end))

-- [ INPUT HANDLERS ]
AddConn(UIS.InputBegan:Connect(function(input,gp)
    if gp or State.Binding then return end
    -- Process custom keybinds first
    if ProcessKeybinds(input) then return end
    -- Menu toggle handled by Rayfield internally
    if Config.Aimlock and Config.AimMode=="TOGGLE" and not isMobile then
        local hit = false
        if Config.BindType == "Mouse" then
            local mb = Config.BindKey == 1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
            hit = (input.UserInputType == mb)
        elseif Config.BindType == "Keyboard" and Config.BindKey then
            if typeof(Config.BindKey) == "EnumItem" then
                hit = (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.BindKey)
            else
                local kc = Enum.KeyCode[Config.BindKey]
                if kc then hit = (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == kc) end
            end
        end
        if hit then State.ToggleAiming = not State.ToggleAiming; if not State.ToggleAiming then LockedTarget = nil end end
    end
    if Config.ClickTPToggle and input.UserInputType==Enum.UserInputType.MouseButton1 and Config.ClickTPBindKey then
        local tpKey = Config.ClickTPBindKey
        local keyDown = false
        if type(tpKey) == "number" then
            local mb = tpKey == 1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
            keyDown = UIS:IsMouseButtonPressed(mb)
        elseif typeof(tpKey) == "EnumItem" then
            if tpKey.EnumType == Enum.KeyCode then
                keyDown = UIS:IsKeyDown(tpKey)
            elseif tpKey.EnumType == Enum.UserInputType then
                keyDown = UIS:IsMouseButtonPressed(tpKey)
            end
        elseif type(tpKey) == "string" then
            local kc = Enum.KeyCode[tpKey]
            if kc then keyDown = UIS:IsKeyDown(kc) end
        end
        if keyDown then
            local lpc=LocalPlayer.Character
            if lpc and Mouse.Hit then
                pcall(function() lpc:PivotTo(Mouse.Hit*CFrame.new(0,3,0)) end)
            end
        end
    end
end))

local function IsAimKeyHeld()
    if Config.BindType == "Mouse" then
        local mb = Config.BindKey == 1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
        return UIS:IsMouseButtonPressed(mb)
    elseif Config.BindType == "Keyboard" and Config.BindKey then
        if typeof(Config.BindKey) == "EnumItem" then
            return UIS:IsKeyDown(Config.BindKey)
        end
        local kc = Enum.KeyCode[Config.BindKey]
        if kc then return UIS:IsKeyDown(kc) end
    end
    return false
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
    if Config.FlyToggle and FlyLV and FlyAO and LPHRP then
        local cam=Camera.CFrame
        local fwd=(UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)+(UIS:IsKeyDown(Enum.KeyCode.S) and -1 or 0)
        local rgt=(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)+(UIS:IsKeyDown(Enum.KeyCode.A) and -1 or 0)
        local up=(UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)+(UIS:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 0)
        -- Mobile fly override
        if isMobile and _G._PwyvMobileFlyDir then
            local mdir = _G._PwyvMobileFlyDir
            fwd = fwd + mdir.Z
            rgt = rgt + mdir.X
            up = up + mdir.Y
        end
        local vel = (fwd~=0 or rgt~=0 or up~=0) and (cam.LookVector*fwd+cam.RightVector*rgt+Vector3.new(0,up,0))*Config.FlySpeed or Vector3.new(0,0,0)
        FlyLV.VectorVelocity = vel
        FlyAO.CFrame = Camera.CFrame
    elseif not Config.FlyToggle and (FlyAO or FlyLV or FlyBG or FlyBV) then SetFly(false) end

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
                hrp.Color = Color3.fromRGB(30, 161, 255)
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
        Circle.Color=Config.FOVColor_C3 or Color3.fromRGB(30, 161, 255)
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
-- Rayfield:LoadConfiguration() must be called after all backend function definitions
-- so that restored config callbacks can safely invoke SetWalkSpeed, SetFly, etc.
pcall(function() Rayfield:LoadConfiguration() end)

-- Migrate old configs and normalize types loaded by Rayfield or JSON
if type(Config.TargetMode) == "number" then
    local map = {[1]="PLAYERS ONLY", [2]="NPCs ONLY", [3]="PLAYERS & NPCs"}
    Config.TargetMode = map[Config.TargetMode] or "PLAYERS ONLY"
elseif type(Config.TargetMode) == "table" then
    Config.TargetMode = Config.TargetMode[1] or "PLAYERS ONLY"
end
if type(Config.AimMode) == "table" then Config.AimMode = Config.AimMode[1] or "HOLD" end
if type(Config.HitboxTargetMode) == "table" then Config.HitboxTargetMode = Config.HitboxTargetMode[1] or "PLAYERS ONLY" end
if type(Config.BindKey) == "string" then
    Config.BindKey = Enum.KeyCode[Config.BindKey] or Enum.UserInputType[Config.BindKey]
end
if type(Config.BindKey) == "number" then
    Config.BindType = "Mouse"
end
if type(Config.ClickTPBindKey) == "string" then
    Config.ClickTPBindKey = Enum.KeyCode[Config.ClickTPBindKey]
end
if Config.ClickTPBindKey == nil then
    Config.ClickTPBindKey = Enum.KeyCode.C
    Config.ClickTPBindType = "Keyboard"
end

-- Ensure UI matches the migrated/normalized Config and features are applied
_G._PwyvSkipRTXConfirm = true
SyncUIFromConfig()
_G._PwyvSkipRTXConfirm = nil

-- Update derived UI state (HUD position, theme, etc.).
task.spawn(function()
    task.wait(0.75); UpdateHUDPos()
    if Themes[Config.Theme] then ApplyTheme(Config.Theme) end
    UpdateMenuBindLabel()
end)

-- Legacy AutoLoadSettings fallback (Rayfield handles this automatically now)
if Config.AutoLoadSettings then
    -- Rayfield ConfigurationSaving already loaded via LoadConfiguration() above.
    -- If Rayfield config is missing, try JSON fallback silently.
    if not Rayfield or not Rayfield.LoadConfiguration then
        local ok = pcall(function() return readfile(SAVE_FILE) end)
        if ok then
            LoadSettings()
        end
    end
end

-- Pulse title line (safe no-op when TitleLine is nil / Rayfield mode)
task.spawn(function()
    while State.Running do
        pcall(function() Tw(TitleLine,1.6,{BackgroundColor3=Colors.AccentGlow}) end)
        task.wait(1.7)
        pcall(function() Tw(TitleLine,1.6,{BackgroundColor3=Colors.PrimaryBlue}) end)
        task.wait(1.7)
    end
end)