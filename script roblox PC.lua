local cloneref = cloneref or function(s) return s end
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local UIS          = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local CoreGui      = cloneref(game:GetService("CoreGui"))
local Stats        = cloneref(game:GetService("Stats"))
local Lighting     = cloneref(game:GetService("Lighting"))
local HttpService  = cloneref(game:GetService("HttpService"))
local PathfindingService = cloneref(game:GetService("PathfindingService"))
local VirtualUser  = nil
pcall(function() VirtualUser = cloneref(game:GetService("VirtualUser")) end)

local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- [ SHARED VARIABLE DECLARATIONS TO PREVENT REGISTER LIMITS ]
local UI = {}
local Conns = {}
local SetShiftLockActive, SetShiftLockEnabled, ExecuteClickTP, StopCurrentClickTP
local SetWalkSpeed, SetJumpPower, SetNoclip, SetInfJump, SetAntiAFK, SetAntiStun, SetInfZoom, SetFly
local SetInvisibility, SetRTX, SetChangeSky, SetHipHeight, SetHipHeightValue, SetRemoveFog, SetFullbright, SetCollisionBypass, SetFakeLag, ApplyFPSBoost, DisableFPSBoost, StartSafeTP, StopSafeTP
local UpdateHUDPos, ShowToast, ApplyTheme, RestoreAll, FullUnload, ShowConfirm, BuildAllTabs
local GetESPColor, GetESP, ClearESP, GetCharacterParts, GetTargetPart, IsVisible, CacheNPC, IsAimKeyHeld, ProcessKeybinds, ProcessKeybindsRelease, ResetAllSettings, UpdateToggleUIFromKeybind, UpdateInteractables, UpdateXray, ApplySkyById, ResetSky
local _origMaxZoom, _origMinZoom, FlyBG, FlyBV, FlyAtt, HipHeight_Platform, HipHeight_Loop, HipHeight_RayParams, LastGroundY, LockedTarget, ValidTargets, NPCCache, XrayCache_M, XrayCache_P, HitboxOriginalSizes, OriginalInteractData, OriginalSky, RTXLoaded, currentTab, featureNames, SkyList, SkyOptions
local AddConn, RegTR, Config, State, Runtime, Connections, ESP_Cache, ThemeRefs, AllRows, AllRowFrames, Tabs, Stats
local TPTargetDropdown, SpecTargetDropdown
local Toggles = {}
local InteractPromptCache = {}

local function SafeDisconnect(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function()
            conn:Disconnect()
        end)
    end
end

local function SafeDestroy(obj)
    if obj then
        pcall(function()
            obj:Destroy()
        end)
    end
end

local function SafeRemoveDrawing(obj)
    if not obj then
        return
    end
    pcall(function()
        obj.Visible = false
    end)
    pcall(function()
        if obj.Remove then
            obj:Remove()
        elseif obj.Destroy then
            obj:Destroy()
        end
    end)
end

local NoCollideRegistry = {}
local NoclipTouchedParts = {}
local NoclipFloorParts = {}
local FlyTouchedParts = {}
local CollisionBypassTouchedParts = {}
local NoclipFloorRayParams = nil

local function IsValidNoCollidePart(part)
    return part and part:IsA("BasePart")
end

local function IsLocalCharacterPart(part)
    local char = LocalPlayer and LocalPlayer.Character
    return char and part and part:IsDescendantOf(char)
end

local function AcquireNoCollide(part, touchedParts, featureKey, preserveQuery)
    if not IsValidNoCollidePart(part) then
        return
    end
    local state = NoCollideRegistry[part]
    if not state then
        state = {
            original = {
                CanCollide = part.CanCollide,
                CanTouch = part.CanTouch,
                CanQuery = part.CanQuery,
            },
            refs = {},
            count = 0,
        }
        NoCollideRegistry[part] = state
    end
    if not state.refs[featureKey] then
        state.refs[featureKey] = true
        state.count = state.count + 1
    end
    if touchedParts then
        touchedParts[part] = true
    end
    pcall(function()
        part.CanCollide = false
        if part.CanTouch ~= nil then
            part.CanTouch = false
        end
        if part.CanQuery ~= nil and not preserveQuery then
            part.CanQuery = false
        end
    end)
end

local function ReleaseNoCollidePart(part, touchedParts, featureKey)
    local state = NoCollideRegistry[part]
    if state and state.refs[featureKey] then
        state.refs[featureKey] = nil
        state.count = math.max((state.count or 1) - 1, 0)
        if state.count <= 0 then
            pcall(function()
                if part and part.Parent and part:IsA("BasePart") then
                    part.CanCollide = state.original.CanCollide
                    if part.CanTouch ~= nil and state.original.CanTouch ~= nil then
                        part.CanTouch = state.original.CanTouch
                    end
                    if part.CanQuery ~= nil and state.original.CanQuery ~= nil then
                        part.CanQuery = state.original.CanQuery
                    end
                end
            end)
            NoCollideRegistry[part] = nil
        end
    end
    if touchedParts then
        touchedParts[part] = nil
    end
end

local function ReinforceNoCollideParts(touchedParts, skipParts, preserveQuery)
    if not touchedParts then
        return
    end
    for part in pairs(touchedParts) do
        if skipParts and skipParts[part] then
            ReleaseNoCollidePart(part, touchedParts, "Noclip")
        elseif IsValidNoCollidePart(part) and part.Parent then
            pcall(function()
                part.CanCollide = false
                if part.CanTouch ~= nil then
                    part.CanTouch = false
                end
                if part.CanQuery ~= nil and not preserveQuery then
                    part.CanQuery = false
                end
            end)
        else
            touchedParts[part] = nil
        end
    end
end

local function ApplyCharacterNoCollide(char, touchedParts, featureKey, preserveQuery)
    if not char then
        return
    end
    for _, part in ipairs(char:GetDescendants()) do
        AcquireNoCollide(part, touchedParts, featureKey, preserveQuery)
    end
end

local function ApplyWorkspaceNoCollide(touchedParts, featureKey, isActive, shouldSkip, preserveQuery)
    task.spawn(function()
        for i, part in ipairs(workspace:GetDescendants()) do
            if isActive and not isActive() then
                break
            end
            if (not shouldSkip) or (not shouldSkip(part)) then
                AcquireNoCollide(part, touchedParts, featureKey, preserveQuery)
            end
            if i % 500 == 0 then
                task.wait()
            end
        end
    end)
end

local function UpdateNoclipFloorParts()
    table.clear(NoclipFloorParts)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return NoclipFloorParts
    end
    if not NoclipFloorRayParams then
        NoclipFloorRayParams = RaycastParams.new()
        NoclipFloorRayParams.FilterType = Enum.RaycastFilterType.Exclude
        NoclipFloorRayParams.IgnoreWater = false
    end
    NoclipFloorRayParams.FilterDescendantsInstances = {char}

    local cf = hrp.CFrame
    local origins = {
        hrp.Position,
        hrp.Position + cf.RightVector * 1.6,
        hrp.Position - cf.RightVector * 1.6,
        hrp.Position + cf.LookVector * 1.6,
        hrp.Position - cf.LookVector * 1.6,
    }
    for _, origin in ipairs(origins) do
        local result = workspace:Raycast(origin + Vector3.new(0, 1, 0), Vector3.new(0, -9, 0), NoclipFloorRayParams)
        local part = result and result.Instance
        if IsValidNoCollidePart(part) then
            NoclipFloorParts[part] = true
            ReleaseNoCollidePart(part, NoclipTouchedParts, "Noclip")
        end
    end
    return NoclipFloorParts
end

local function ReleaseNoCollideParts(touchedParts, featureKey)
    if not touchedParts then
        return
    end
    for part in pairs(touchedParts) do
        local state = NoCollideRegistry[part]
        if state and state.refs[featureKey] then
            state.refs[featureKey] = nil
            state.count = math.max((state.count or 1) - 1, 0)
            if state.count <= 0 then
                pcall(function()
                    if part and part.Parent and part:IsA("BasePart") then
                        part.CanCollide = state.original.CanCollide
                        if part.CanTouch ~= nil and state.original.CanTouch ~= nil then
                            part.CanTouch = state.original.CanTouch
                        end
                        if part.CanQuery ~= nil and state.original.CanQuery ~= nil then
                            part.CanQuery = state.original.CanQuery
                        end
                    end
                end)
                NoCollideRegistry[part] = nil
            end
        end
        touchedParts[part] = nil
    end
end

local function ResetNoCollideRegistry()
    ReleaseNoCollideParts(NoclipTouchedParts, "Noclip")
    ReleaseNoCollideParts(FlyTouchedParts, "FlyToggle")
    ReleaseNoCollideParts(CollisionBypassTouchedParts, "CollisionBypass")
    for part, state in pairs(NoCollideRegistry) do
        pcall(function()
            if part and part.Parent and part:IsA("BasePart") then
                part.CanCollide = state.original.CanCollide
                if part.CanTouch ~= nil and state.original.CanTouch ~= nil then
                    part.CanTouch = state.original.CanTouch
                end
                if part.CanQuery ~= nil and state.original.CanQuery ~= nil then
                    part.CanQuery = state.original.CanQuery
                end
            end
        end)
        NoCollideRegistry[part] = nil
    end
    table.clear(NoclipTouchedParts)
    table.clear(NoclipFloorParts)
    table.clear(FlyTouchedParts)
    table.clear(CollisionBypassTouchedParts)
end

local function RestoreProperty(target, propertyName, savedValue, fallbackValue)
    local value = savedValue
    if value == nil then
        value = fallbackValue
    end
    if value ~= nil then
        pcall(function()
            target[propertyName] = value
        end)
    end
end

local function RestoreOriginalState(saved)
    local o = saved or {}
    local lpc = LocalPlayer.Character

    if lpc then
        local h = lpc:FindFirstChildOfClass("Humanoid")
        if h then
            RestoreProperty(h, "WalkSpeed", o.WalkSpeed, 16)
            RestoreProperty(h, "UseJumpPower", o.UseJumpPower, true)
            RestoreProperty(h, "JumpPower", o.JumpPower, 50)
            if h.JumpHeight ~= nil then
                RestoreProperty(h, "JumpHeight", o.JumpHeight, 7.2)
            end
            RestoreProperty(h, "MaxHealth", o.MaxHealth, 100)
            if o.Health ~= nil then
                pcall(function()
                    h.Health = math.min(o.Health, h.MaxHealth)
                end)
            end
            RestoreProperty(h, "BreakJointsOnDeath", o.BreakJoints, true)
            pcall(function()
                if o.RequiresNeck ~= nil then
                    h.RequiresNeck = o.RequiresNeck
                end
                h.PlatformStand = false
            end)
        end

        pcall(function()
            local animate = lpc:FindFirstChild("Animate")
            if animate then
                animate.Disabled = false
            end
        end)
    end

    SafeDestroy(FlyBG)
    FlyBG = nil
    SafeDestroy(FlyBV)
    FlyBV = nil
    SafeDestroy(FlyAtt)
    FlyAtt = nil

    if lpc then
        local h = lpc:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                Camera.CameraSubject = h
            end)
        end
    end

    RestoreProperty(Camera, "FieldOfView", o.FOV, 70)
    RestoreProperty(LocalPlayer, "CameraMaxZoomDistance", o.MaxZoom, 400)
    RestoreProperty(LocalPlayer, "CameraMinZoomDistance", o.MinZoom, 5)
    RestoreProperty(workspace, "Gravity", o.Gravity, 196.2)
    RestoreProperty(Lighting, "GlobalShadows", o.GlobalShadows, true)
    RestoreProperty(Lighting, "FogEnd", o.FogEnd, 1e6)
    RestoreProperty(Lighting, "FogStart", o.FogStart, 0)
    RestoreProperty(Lighting, "ClockTime", o.ClockTime, 14)
    RestoreProperty(Lighting, "Brightness", o.Brightness, 1)
    RestoreProperty(Lighting, "Ambient", o.Ambient, Color3.fromRGB(0, 0, 0))
    RestoreProperty(Lighting, "OutdoorAmbient", o.OutdoorAmbient, Color3.fromRGB(128, 128, 128))

    if o.AtmoDensity ~= nil or o.AtmoHaze ~= nil or o.AtmoGlare ~= nil then
        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then
            RestoreProperty(atmos, "Density", o.AtmoDensity)
            RestoreProperty(atmos, "Haze", o.AtmoHaze)
            RestoreProperty(atmos, "Glare", o.AtmoGlare)
        end
    end

    pcall(function()
        settings().Rendering.QualityLevel = o.Quality or Enum.QualityLevel.Automatic
    end)

    for p, originalTransparency in pairs(XrayCache_M) do
        if p ~= "__conn" then
            pcall(function()
                if p and p.Parent then
                    p.LocalTransparencyModifier = originalTransparency
                end
            end)
        end
    end
    if XrayCache_M.__conn then
        SafeDisconnect(XrayCache_M.__conn)
        XrayCache_M.__conn = nil
    end
    for p, originalTransparency in pairs(XrayCache_P) do
        if p ~= "__conn" then
            pcall(function()
                if p and p.Parent then
                    p.LocalTransparencyModifier = originalTransparency
                end
            end)
        end
    end
    if XrayCache_P.__conn then
        SafeDisconnect(XrayCache_P.__conn)
        XrayCache_P.__conn = nil
    end

    pcall(function() SetCollisionBypass(false) end)
    pcall(function() SetFly(false) end)
    pcall(function() SetNoclip(false) end)
    ResetNoCollideRegistry()

    if o.HRPSizes then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                pcall(function()
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local originalSize = o.HRPSizes[p.Name]
                        if originalSize then
                            hrp.Size = originalSize
                        end
                        hrp.Transparency = 1
                        hrp.Material = Enum.Material.SmoothPlastic
                        hrp.CanCollide = true
                    end
                end)
            end
        end
    end

    SafeDestroy(UI.ESP_Folder)
    UI.ESP_Folder = nil

    if _G._PwyvCircle then
        SafeRemoveDrawing(_G._PwyvCircle)
        _G._PwyvCircle = nil
    end

    table.clear(InteractPromptCache)
    table.clear(ESP_Cache)
    table.clear(NPCCache)
    table.clear(XrayCache_M)
    table.clear(XrayCache_P)
    table.clear(HitboxOriginalSizes)
    table.clear(OriginalInteractData)
    table.clear(ValidTargets)
end

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
            o.Ambient        = Lighting.Ambient
            o.OutdoorAmbient = Lighting.OutdoorAmbient
        end)
        pcall(function()
            o.Gravity = workspace.Gravity
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

    local alreadyRan = (_G._PwyvWindow ~= nil) or (CoreGui:FindFirstChild("PhwyverysadOverlay") ~= nil)
    if not alreadyRan then
        _SaveOriginals()
    else
        -- Re-run: restore everything to exact originals
        pcall(function()
            RestoreOriginalState(_G._PwyvOrig)
        end)
        _G._PwyvOrig = nil
    end
end

-- [ COMPREHENSIVE CLEANUP ]
local function ComprehensiveCleanup()
    -- 1. Unload Maclib Window safely
    if _G._PwyvWindow then
        pcall(function() _G._PwyvWindow:Unload() end)
        _G._PwyvWindow = nil
    end

    -- 2. Clear UI Core elements
    local guiNames = {
        "PhwyverysadOverlay",
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
    
    -- 3. Destroy Workspace additions
    pcall(function()
        local hipPlatform = workspace:FindFirstChild("HipHeightPlatform")
        if hipPlatform then hipPlatform:Destroy() end
    end)
    pcall(function()
        local invisSeat = workspace:FindFirstChild("invischair_pwy")
        if invisSeat then invisSeat:Destroy() end
    end)
    
    -- 4. Disconnect Connections
    if _G._PwyvConnections then
        for _, conn in ipairs(_G._PwyvConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G._PwyvConnections = {}
    end
    
    -- 5. Clear Caches
    if _G._PwyvCaches then
        for char, cache in pairs(_G._PwyvCaches.ESP or {}) do
            pcall(function()
                if cache.Gui then cache.Gui:Destroy() end
                if cache.Highlight then cache.Highlight:Destroy() end
            end)
        end
        _G._PwyvCaches = nil
    end
    
    -- 6. Revert Character Changes
    pcall(function()
        local lpc = Players.LocalPlayer.Character
        if lpc then
            for _, p in ipairs(lpc:GetDescendants()) do
                pcall(function() if p:IsA("BasePart") then p.CanCollide = true end end)
            end
            local hrp = lpc:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, child in ipairs(hrp:GetChildren()) do
                    if child:IsA("BodyGyro") or child:IsA("BodyVelocity") then
                        child:Destroy()
                    end
                end
            end
            local animate = lpc:FindFirstChild("Animate")
            if animate then animate.Disabled = false end
            local hum = lpc:FindFirstChildOfClass("Humanoid")
            if hum then
                workspace.CurrentCamera.CameraSubject = hum
                hum.PlatformStand = false
            end
        end
    end)
    
    -- 7. Revert other Hitboxes
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
    
    -- 8. Revert Camera & Lighting
    pcall(function() workspace.CurrentCamera.FieldOfView = 70 end)
    pcall(function()
        Players.LocalPlayer.CameraMaxZoomDistance = 400
        Players.LocalPlayer.CameraMinZoomDistance = 5
    end)
    pcall(function()
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 1
    end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    
    -- 9. Revert FOV Circle
    if _G._PwyvCircle then
        SafeRemoveDrawing(_G._PwyvCircle)
        _G._PwyvCircle = nil
    end
    
    _G._PwyvState = nil
    _G._PwyvRuntime = nil
    task.wait()
end

ComprehensiveCleanup()

-- [ UNIFIED APPLICATION CORE ]
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
            Loops = {}
        },
        Stats = {
            frameCount = 0, lastFPS = 0, pingValue = 0, lastWarpTick = 0
        }
    }
}

-- [ ENCAPSULATION: Settings Proxy ]
setmetatable(Phwy.Settings, {
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end
})

-- [ DATA INITIALIZATION ]
local initialConfig = {
    ButtonGUI_Visible = true, GlobalUseBind = false,
    Aimlock = false, AimMode = "HOLD", FOV = 20, AimSmooth = 1, WallCheck = true, FOVShowMode = "Always", TargetMode = 1, EnemyOnly = false, AimTargetPart = "Head", BindType = "Keyboard", BindKey = nil,
    ESPMaster = false, ESPShowName = false, ESPShowHealth = false, ESPShowDistance = false, ESPHighlight = false, ESPTeamCheck = false, ESPTeamColor = false, ESPXray = false, ESPTextSize = 10, ESPFillTrans = 0.5, ESPOutlineTrans = 0.1, ESPColor_C3 = Color3.new(1,1,1),
    P_Master = false, P_TargetMode = "PLAYERS ONLY", P_ShowName = true, P_ShowHealth = true, P_ShowDist = true, P_Highlight = true, P_TeamCheck = false, P_TeamColor = false, P_Xray = false, P_TextSize = 10, P_FillTrans = 0.5, P_OutlineTrans = 0.1, P_HitboxToggle = false, P_HitboxSize = 32, HitboxTargetMode = "PLAYERS ONLY", P_Color_C3 = Color3.fromRGB(255,255,255), P_ESPInFOVOnly = false,
    WalkSpeed = 100, WSToggle = false, JumpPower = 100, JPToggle = false, InfJump = false, FlyToggle = false, FlyNoclip = true, FlySpeed = 100, Noclip = false, InfZoom = true, ZoomNoclip = true, InvisToggle = false, FOVToggle = false, FOVView = 70, FOVColor_C3 = Color3.fromRGB(30,161,255),
    AntiAFK = true, FPSBooster = false, FPS_NoShadows = true, FPS_NoParticles = true, FPS_NoClothes = true, FPS_LowQuality = true, HipHeightToggle = false, HipHeightValue = 50, InstantPress = false, AuraRange = false,
    RTX_Enabled = false, EmoteMenuOpen = false, ChangeSky_Enabled = false, ChangeSky_Selected = "Anime-sky", Fullbright_Toggle = false, RemoveFog_Toggle = false, MapTimeEnabled = false, MapTimeValue = 12,
    ShowFPSPing = "FPS & Ping", ShowStatsToggle = true, HUDPosition = "TopRight", TPTarget = "-", TPMode = "Warp", TPFlightSens = 80, TPGOSwitch = false, SpecTarget = "-", SpecToggle = false, ClickTPToggle = false, ClickTPBindType = "Keyboard", ClickTPBindKey = nil, MenuToggleBindType = "Keyboard", MenuToggleBindKey = Enum.KeyCode.G, MenuVisible = true, Theme = "Midnight", 
    SliderStep = 1,
    FPSUnlockerEnabled = true,
    FPSCapOption = "Infinity",
    Language = "EN",
    GithubURL = "https://github.com/phwyverysad",
    ShiftLock_Enabled = false, ShiftLock_Active = false, ShiftLock_BindType = nil, ShiftLock_BindKey = nil,
    ClickTP_Mode = "Teleport", ClickTP_Speed = 100, CollisionBypass = false, CollisionBounce = false, FakeLag = false, FakeLagMode = "Current", FakeLagFreezeWorld = false, Freecam = false,
    Keybinds = {
        Aimlock = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        P_Master = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        P_HitboxToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        WSToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        JPToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        FlyToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        Noclip = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        InfJump = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        InvisToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        InfZoom = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        FOVToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        Fullbright_Toggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        RemoveFog_Toggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        AntiAFK = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        FPSBooster = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        HipHeightToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        TPGOSwitch = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        ClickTPToggle = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        CollisionBypass = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        CollisionBounce = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        FakeLag = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
        Freecam = {Type=nil, Key=nil, Enabled=false, Mode="Toggle"},
    }
}
for k, v in pairs(initialConfig) do Phwy.Settings[k] = v end

local initialState = {
    Running = true, ToggleAiming = false, Binding = nil, isMinimized = false, isMaximized = false, isHidden = false, preHideSize = nil,
    Unloading = false,
    originalSize = UDim2.new(0,880,0,570), originalPos = UDim2.new(0.5,-440,0.5,-285),
}
for k, v in pairs(initialState) do Phwy.State[k] = v end

Config        = Phwy.Settings
State         = Phwy.State
Runtime       = Phwy.Runtime
Connections   = Runtime.Memory.Connections
ESP_Cache     = Runtime.Caches.ESP
NPCCache      = Runtime.Caches.NPCs
XrayCache_M   = Runtime.Caches.XrayM
XrayCache_P   = Runtime.Caches.XrayP
HitboxOriginalSizes = Runtime.Caches.HitboxOrig
OriginalInteractData = Runtime.Caches.InteractOrig
ValidTargets  = Runtime.Caches.ValidTargets
ThemeRefs     = Runtime.Memory.ThemeRefs
AllRows       = Runtime.Memory.AllRows
AllRowFrames  = Runtime.Memory.AllRowFrames
Tabs          = Runtime.Memory.Tabs
Stats         = Runtime.Stats

function AddConn(c) 
    table.insert(Connections,c) 
    if not _G._PwyvConnections then _G._PwyvConnections = {} end
    table.insert(_G._PwyvConnections, c)
    return c 
end
function RegTR(obj,key,prop) table.insert(ThemeRefs,{obj=obj,key=key,prop=prop}); return obj end

local function TL(en, th)
    if Config and Config.Language == "TH" then
        return th
    end
    return en
end

local UITranslateMap = {
    ["Aimlock"] = "ล็อกเป้า",
    ["ESP Player"] = "ESP ผู้เล่น",
    ["Setting Player"] = "ตั้งค่าผู้เล่น",
    ["Graphic"] = "กราฟิก",
    ["Player Teleport"] = "วาร์ปผู้เล่น",
    ["Server Details"] = "ข้อมูลเซิร์ฟเวอร์",
    ["Aim Assist"] = "ระบบช่วยเล็ง",
    ["Target"] = "เป้าหมาย",
    ["ESP Visuals"] = "การแสดงผล ESP",
    ["ESP Visuals (More)"] = "การแสดงผล ESP (เพิ่มเติม)",
    ["Customization"] = "ปรับแต่ง",
    ["Hitbox Expansion"] = "ขยายฮิตบ็อกซ์",
    ["Movement"] = "การเคลื่อนไหว",
    ["Visual Environment"] = "สภาพแวดล้อมภาพ",
    ["Lighting"] = "แสงสว่าง",
    ["Interactions"] = "การโต้ตอบ",
    ["Fake Lag"] = "เฟคลาก",
    ["Optimization"] = "เพิ่มประสิทธิภาพ",
    ["Interface Info"] = "ข้อมูลหน้าจอ",
    ["Ray Tracing"] = "เรย์เทรซซิ่ง",
    ["Change the Sky"] = "เปลี่ยนท้องฟ้า",
    ["Graphic Guide"] = "คู่มือกราฟิก",
    ["Target Tracking"] = "ติดตามเป้าหมาย",
    ["Spectator Mode"] = "โหมดส่องผู้เล่น",
    ["Mouse Teleportation"] = "วาร์ปด้วยเมาส์",
    ["Server Info"] = "ข้อมูลเซิร์ฟเวอร์",
    ["Server Actions"] = "การทำงานเซิร์ฟเวอร์",
    ["Window Controls"] = "ควบคุมหน้าต่าง",
    ["Main Features"] = "คุณสมบัติหลัก",
    ["Player & Environment"] = "ผู้เล่นและสภาพแวดล้อม",
    ["Teleport & Utility"] = "เทเลพอร์ตและเครื่องมือ",
    ["Language"] = "ภาษา",
    ["England"] = "อังกฤษ",
    ["Thailand"] = "ไทย",
    ["Enable Aimlock"] = "เปิดใช้งานล็อกเป้า",
    ["Aim Mode"] = "โหมดเล็ง",
    ["Enemy Only"] = "เฉพาะศัตรู",
    ["Aim Keybind"] = "ปุ่มลัดเล็ง",
    ["FOV Radius"] = "ขอบเขตวงกลมเล็ง",
    ["Smoothing"] = "ความลื่นไหลในการเล็ง",
    ["FOV Color"] = "สีวงเล็ง",
    ["Wall Check"] = "ตรวจสิ่งกีดขวาง",
    ["Target Part"] = "ชิ้นส่วนเป้าหมาย",
    ["Head"] = "หัว",
    ["Torso"] = "ลำตัว",
    ["HumanoidRootPart"] = "จุดศูนย์กลาง",
    ["Auto"] = "อัตโนมัติ",
    ["Enable Visuals"] = "เปิดการแสดงผล",
    ["View Distance Only"] = "แสดงตามระยะ",
    ["Show Names"] = "แสดงชื่อ",
    ["Show Health"] = "แสดงพลังชีวิต",
    ["Show Distance"] = "แสดงระยะทาง",
    ["Highlight Glow"] = "ไฮไลต์เรืองแสง",
    ["Team Color"] = "สีทีม",
    ["Ignore Team"] = "ไม่สนทีม",
    ["X-Ray Mode"] = "โหมดเอ็กซเรย์",
    ["Primary Color"] = "สีหลัก",
    ["Text Size"] = "ขนาดตัวอักษร",
    ["Fill Opacity"] = "ความทึบพื้น",
    ["Outline Opacity"] = "ความทึบขอบ",
    ["Enable Hitbox"] = "เปิดฮิตบ็อกซ์",
    ["Target Selection"] = "เลือกเป้าหมาย",
    ["PLAYERS ONLY"] = "ผู้เล่นเท่านั้น",
    ["NPCs ONLY"] = "NPC เท่านั้น",
    ["PLAYERS & NPCs"] = "ผู้เล่นและ NPC",
    ["Expansion Size"] = "ขนาดการขยาย",
    ["Open Emote Menu"] = "เปิดเมนูอีโมต",
    ["Menu Toggle Key"] = "ปุ่มเปิด/ปิดเมนู",
    ["Slider Step"] = "ช่วงการเลื่อนสไลเดอร์",
    ["Super Walk"] = "วิ่งเร็ว",
    ["Speed Value"] = "ค่าความเร็ว",
    ["Super Jump"] = "กระโดดสูง",
    ["Jump Value"] = "ค่าพลังกระโดด",
    ["Infinite Jump"] = "กระโดดไม่จำกัด",
    ["Fly Mode"] = "โหมดบิน",
    ["Flying Speed"] = "ความเร็วบิน",
    ["No Clip"] = "เดินทะลุกำแพง",
    ["Invisibility"] = "ล่องหน",
    ["Max Zoom"] = "ซูมสูงสุด",
    ["Hip Height"] = "ความสูงตัวละคร",
    ["Height Level"] = "ระดับความสูง",
    ["Custom Field of View"] = "กำหนดมุมมองเอง",
    ["FOV Value"] = "ค่ามุมมอง",
    ["Fullbright"] = "สว่างสุด",
    ["Disable Fog"] = "ปิดหมอก",
    ["Fast Interact"] = "โต้ตอบไว",
    ["Interaction Aura"] = "ออร่าโต้ตอบ",
    ["Anti-AFK"] = "กัน AFK",
    ["Anti Stun"] = "กันสตัน",
    ["Shift Lock"] = "ล็อกไหล่",
    ["Shift Lock Key"] = "ปุ่มล็อกไหล่",
    ["Collision Bypass"] = "ทะลุการชน",
    ["Warp Mode"] = "โหมดวาร์ป",
    ["Current"] = "ตำแหน่งปัจจุบัน",
    ["Back"] = "ย้อนกลับ",
    ["Freecam"] = "กล้องอิสระ",
    ["Enable FPS Booster"] = "เปิดเร่ง FPS",
    ["FPS Unlocker"] = "ปลดล็อกเฟรมเรต",
    ["Infinity"] = "ไร้ขีดจำกัด",
    ["Disable Shadows"] = "ปิดเงา",
    ["Clear Particles"] = "ลบอนุภาค",
    ["Strip Outfits"] = "ลดชุดตัวละคร",
    ["Low Mesh Quality"] = "ลดคุณภาพ Mesh",
    ["Data Display"] = "การแสดงข้อมูล",
    ["FPS"] = "FPS",
    ["Ping"] = "Ping",
    ["FPS & Ping"] = "FPS และ Ping",
    ["Show Activity HUD"] = "แสดง HUD กิจกรรม",
    ["HUD Position"] = "ตำแหน่ง HUD",
    ["TopLeft"] = "ซ้ายบน",
    ["TopRight"] = "ขวาบน",
    ["BottomLeft"] = "ซ้ายล่าง",
    ["BottomRight"] = "ขวาล่าง",
    ["Change Sky"] = "เปลี่ยนท้องฟ้า",
    ["Sky Selection"] = "เลือกท้องฟ้า",
    ["Target Player"] = "เลือกผู้เล่นเป้าหมาย",
    ["Tracking Mode"] = "โหมดติดตาม",
    ["Safe Fly"] = "บินปลอดภัย",
    ["Warp"] = "วาร์ป",
    ["Follow Speed"] = "ความเร็วติดตาม",
    ["Activate System"] = "เปิดระบบ",
    ["Watch Player"] = "ดูผู้เล่น",
    ["Enable Eye"] = "เปิดโหมดดู",
    ["Teleport Key"] = "ปุ่มวาร์ป",
    ["Enable Click-TP"] = "เปิดคลิกวาร์ป",
    ["Click-TP Mode"] = "โหมดคลิกวาร์ป",
    ["Teleport"] = "วาร์ป",
    ["Fly"] = "บิน",
    ["Walk"] = "เดิน",
    ["Travel Speed"] = "ความเร็วเดินทาง",
    ["Direct Join Link"] = "ลิงก์เข้าตรง",
    ["Rejoin Server"] = "เข้าเซิร์ฟเวอร์เดิม",
    ["Server Hop"] = "ย้ายเซิร์ฟเวอร์",
    ["Unload Script Safely"] = "ปิดสคริปต์อย่างปลอดภัย",
    ["Use Bind"] = "ใช้ปุ่มลัด",
    ["Mode"] = "โหมด",
    ["Key"] = "ปุ่ม",
    ["Toggle"] = "สลับ",
    ["Hold"] = "กดค้าง",
    ["Confirm"] = "ยืนยัน",
    ["Cancel"] = "ยกเลิก",
    ["Enabled"] = "เปิดแล้ว",
    ["Info"] = "ข้อมูล",
    ["Warning"] = "คำเตือน"
}
local UITranslateMapReverse = {}
for enText, thText in pairs(UITranslateMap) do
    UITranslateMapReverse[thText] = enText
end

local function TranslateUIRawText(textValue)
    if type(textValue) ~= "string" then return textValue end
    local trimmed = textValue:gsub("^%s+", ""):gsub("%s+$", "")
    local leading = textValue:match("^(%s*)") or ""
    local trailing = textValue:match("(%s*)$") or ""
    local function compose(mapped) return leading .. mapped .. trailing end
    if Config.Language == "TH" then
        if UITranslateMap[trimmed] then return compose(UITranslateMap[trimmed]) end
        local prefixA, suffixA = trimmed:match("^(Use Bind%s*•%s*)(.+)$")
        if prefixA and suffixA then
            return compose("ใช้ปุ่มลัด • " .. (UITranslateMap[suffixA] or suffixA))
        end
        local prefixB, suffixB = trimmed:match("^(Mode%s*•%s*)(.+)$")
        if prefixB and suffixB then
            return compose("โหมด • " .. (UITranslateMap[suffixB] or suffixB))
        end
        local prefixC, suffixC = trimmed:match("^(Key%s*•%s*)(.+)$")
        if prefixC and suffixC then
            return compose("ปุ่ม • " .. (UITranslateMap[suffixC] or suffixC))
        end
        return textValue
    end
    if UITranslateMapReverse[trimmed] then return compose(UITranslateMapReverse[trimmed]) end
    local thA, thSfxA = trimmed:match("^(ใช้ปุ่มลัด%s*•%s*)(.+)$")
    if thA and thSfxA then
        return compose("Use Bind • " .. (UITranslateMapReverse[thSfxA] or thSfxA))
    end
    local thB, thSfxB = trimmed:match("^(โหมด%s*•%s*)(.+)$")
    if thB and thSfxB then
        return compose("Mode • " .. (UITranslateMapReverse[thSfxB] or thSfxB))
    end
    local thC, thSfxC = trimmed:match("^(ปุ่ม%s*•%s*)(.+)$")
    if thC and thSfxC then
        return compose("Key • " .. (UITranslateMapReverse[thSfxC] or thSfxC))
    end
    return textValue
end

local function ApplyLanguageToRawUI()
    local targets = {}
    pcall(function()
        local knownNames = {
            "PhwyverysadOverlay",
            "PhwyverysadModMenu",
            "PhwyverysadDropdowns",
            "PhwyverysadCPicker",
            "PhwyToastContainer"
        }
        for _, n in ipairs(knownNames) do
            local inst = CoreGui:FindFirstChild(n, true)
            if inst then table.insert(targets, inst) end
        end
    end)
    if UI and UI.ScreenGui then
        table.insert(targets, UI.ScreenGui)
    end
    for _, root in ipairs(targets) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                pcall(function()
                    d.Text = TranslateUIRawText(d.Text)
                end)
            end
        end
    end
end

-- [ MACLIB UI INITIALIZATION ]
local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Window = MacLib:Window({
    Title = "phwyverysad",
    Subtitle = "v0.0.1",
    Size = UDim2.fromOffset(868, 650),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})
_G._PwyvWindow = Window

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

-- [ SCREEN OVERLAY ]
UI.ScreenGui = Instance.new("ScreenGui", CoreGui)
UI.ScreenGui.Name = "PhwyverysadOverlay"
UI.ScreenGui.ResetOnSpawn = false

-- [ STATS HUD ]
UI.StatHUD = Instance.new("TextLabel", UI.ScreenGui)
UI.StatHUD.Size = UDim2.new(0, 165, 0, 32)
UI.StatHUD.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
UI.StatHUD.BackgroundTransparency = 1
UI.StatHUD.TextColor3 = Color3.fromRGB(0, 240, 150)
UI.StatHUD.Font = Enum.Font.GothamBold
UI.StatHUD.TextStrokeTransparency = 0.3
UI.StatHUD.TextStrokeColor3 = Color3.new(0, 0, 0)
UI.StatHUD.TextSize = 16
UI.StatHUD.Visible = false
Instance.new("UIPadding", UI.StatHUD).PaddingLeft = UDim.new(0, 10)
UI.StatHUD.TextXAlignment = Enum.TextXAlignment.Left

local HUDPositions = {TopLeft = UDim2.new(0, 10, 0, 10), TopRight = UDim2.new(1, -175, 0, 10), BottomLeft = UDim2.new(0, 10, 1, -42), BottomRight = UDim2.new(1, -175, 1, -42)}
function UpdateHUDPos() UI.StatHUD.Position = HUDPositions[Config.HUDPosition] or HUDPositions.TopLeft end

-- [ NOTIFICATION SYSTEM MAPPED TO MACLIB ]
function ShowToast(msg, col)
    pcall(function()
        Window:Notify({
            Title = "phwyverysad",
            Description = msg,
            Lifetime = 2
        })
    end)
end

-- FOV UI.Circle
UI.Circle = Drawing.new("Circle")
UI.Circle.Thickness = 1.5
UI.Circle.NumSides = 64
UI.Circle.Filled = false
UI.Circle.Transparency = 0.75
UI.Circle.Color = Colors.PrimaryBlue
UI.Circle.Visible = false
_G._PwyvCircle = UI.Circle

-- [ APPLY THEME ]
function ApplyTheme(themeName)
    Config.Theme = themeName
    local t = Themes[themeName] or Themes.Dark
    CopyTheme(t)
    if UI.Circle then UI.Circle.Color = t.Primary end
    if UI.StatHUD then UI.StatHUD.TextColor3 = t.Primary end
end

-- [ WINDOW CONTROLS ]
function RestoreAll()
    RestoreOriginalState(_G._PwyvOrig)
    SafeDisconnect(Conns.SafeTP_Conn)
    Conns.SafeTP_Conn = nil
end

function FullUnload()
    if State.Unloading then return end
    State.Unloading = true
    State.Running = false
    Config.MenuVisible = false

    for _, cn in ipairs({
        Conns.FPS_DescConn,
        Conns.InteractAddedConn,
        Conns.FogDescAddedConn,
        Conns.FogConn,
        Conns.FullbrightConn,
        Conns.CollisionBypassConn,
        Conns.CollisionBypassCharAddedConn,
        Conns.CollisionBypassCharDescConn
    }) do
        SafeDisconnect(cn)
    end
    Conns.FPS_DescConn = nil
    Conns.InteractAddedConn = nil
    Conns.FogDescAddedConn = nil
    Conns.FogConn = nil
    Conns.FullbrightConn = nil
    Conns.CollisionBypassConn = nil
    Conns.CollisionBypassCharAddedConn = nil
    Conns.CollisionBypassCharDescConn = nil

    for _, c in ipairs(Connections) do
        SafeDisconnect(c)
    end
    for k, cn in pairs(Conns) do
        SafeDisconnect(cn)
        Conns[k] = nil
    end

    pcall(function() SetFullbright(false) end)
    pcall(function() SetRemoveFog(false) end)
    pcall(function() SetFly(false) end)
    pcall(function() SetNoclip(false) end)
    pcall(function() SetJumpPower(false) end)
    pcall(function() SetWalkSpeed(false) end)
    pcall(function() SetInfJump(false) end)
    pcall(function() SetAntiAFK(false) end)
    pcall(function() SetAntiStun(false) end)
    pcall(function() SetInvisibility(false) end)
    pcall(function() SetInfZoom(false) end)
    pcall(function() SetHipHeight(false) end)
    pcall(function() SetShiftLockEnabled(false) end)
    pcall(function() SetCollisionBypass(false) end)
    pcall(function() SetFakeLag(false) end)
    pcall(function() SetFreecam(false) end)
    pcall(function() LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom end)
    pcall(function() 
        if Config.MapTimeEnabled and State.OriginalMapTime then
            game:GetService("Lighting").ClockTime = State.OriginalMapTime
        end
    end)
    pcall(function() DisableFPSBoost() end)
    pcall(function() StopSafeTP() end)
    pcall(function() StopCurrentClickTP() end)
    pcall(function() RestoreAll() end)
    SafeRemoveDrawing(UI.Circle)
    UI.Circle = nil

    pcall(function()
        local lpc = LocalPlayer.Character
        if lpc then
            local h = lpc:FindFirstChildOfClass("Humanoid")
            if h then
                h.WalkSpeed = 16
                h.UseJumpPower = true
                h.JumpPower = 50
                h.PlatformStand = false
            end
            for _, part in ipairs(lpc:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                    if part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 0
                    end
                end
            end
        end
    end)

    pcall(function()
        for char, cache in pairs(ESP_Cache) do
            if cache.Gui then cache.Gui:Destroy() end
            if cache.Highlight then cache.Highlight:Destroy() end
            ESP_Cache[char] = nil
        end
    end)
    SafeDestroy(UI.ESP_Folder)
    UI.ESP_Folder = nil
    pcall(function()
        for char, sz in pairs(HitboxOriginalSizes) do
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = sz
                hrp.Transparency = 1
                hrp.Material = Enum.Material.SmoothPlastic
                hrp.CanCollide = true
            end
            HitboxOriginalSizes[char] = nil
        end
    end)

    if _G._PwyvWindow then
        pcall(function() _G._PwyvWindow:Unload() end)
        _G._PwyvWindow = nil
    end
    SafeDestroy(UI.ScreenGui)

    for k in pairs(UI) do UI[k] = nil end
    table.clear(Connections)
    table.clear(Conns)
end

-- [ CONFIRMATION DIALOG MAPPED TO MACLIB ]
function ShowConfirm(title, desc, onYes)
    pcall(function()
        Window:Dialog({
            Title = title,
            Description = desc,
            Buttons = {
                {
                    Name = TL("Confirm", "ยืนยัน"),
                    Callback = onYes
                },
                {
                    Name = TL("Cancel", "ยกเลิก")
                }
            }
        })
    end)
end

-- [ BACKEND HELPERS ]
function GetESPColor(c3val, hpPct)
    if hpPct and typeof(c3val)=="Color3" and c3val==Color3.new(0,0,0) then
        hpPct=hpPct or 100
        if hpPct>=70 then return Color3.fromRGB(50,255,50) elseif hpPct>=35 then return Color3.fromRGB(255,200,50) else return Color3.fromRGB(255,50,50) end
    end
    return c3val or Color3.new(1,1,1)
end

UI.ESP_Folder = Instance.new("Folder", CoreGui)
UI.ESP_Folder.Name = "NexusESP_Folder"

function GetESP(char)
    if ESP_Cache[char] then return ESP_Cache[char] end
    local bGui = Instance.new("BillboardGui", UI.ESP_Folder)
    bGui.AlwaysOnTop = true
    bGui.Size = UDim2.new(0, 220, 0, 75)
    bGui.StudsOffset = Vector3.new(0, 4, 0)
    bGui.Enabled = false
    local lbl = Instance.new("TextLabel", bGui)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.TextWrapped = true
    local hlt = Instance.new("Highlight", UI.ESP_Folder)
    hlt.OutlineTransparency = 0.1
    hlt.Enabled = false
    ESP_Cache[char] = {Gui = bGui, Label = lbl, Highlight = hlt}
    return ESP_Cache[char]
end

function ClearESP(char)
    if not ESP_Cache[char] then return end
    pcall(function() ESP_Cache[char].Gui:Destroy() end)
    pcall(function() ESP_Cache[char].Highlight:Destroy() end)
    ESP_Cache[char] = nil
end

function GetCharacterParts(char)
    if not char or not char:IsA("Model") then return nil, nil, nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then 
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Humanoid") then humanoid = obj; break end
        end
    end
    local head = char:FindFirstChild("Head")
    if not head and humanoid then head = humanoid.Parent:FindFirstChild("Head") end
    if not head then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():match("head") or part.Name:lower():match("face")) then head = part; break end
        end
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp and humanoid then hrp = humanoid.RootPart end
    if not hrp then hrp = char.PrimaryPart end
    if not hrp then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():match("torso") or part.Name:lower():match("body") or part.Name:lower():match("root") or part.Name:lower():match("main")) then hrp = part; break end
        end
    end
    if not hrp then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then hrp = part; break end
        end
    end
    return head, hrp, humanoid
end

function GetTargetPart(char)
    if not char or not char:IsA("Model") then return nil end
    local head, hrp, humanoid = GetCharacterParts(char)
    local targetMode = Config.AimTargetPart or "Auto"
    if targetMode == "Head" then
        return head or hrp
    elseif targetMode == "Torso" then
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso")
        if not torso and humanoid then torso = humanoid.RootPart end
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

function IsVisible(tp)
    if not Config.WallCheck then return true end
    local lpc = LocalPlayer.Character; if not lpc then return true end
    if not Runtime._AimRayParams then
        Runtime._AimRayParams = RaycastParams.new()
        Runtime._AimRayParams.FilterType = Enum.RaycastFilterType.Exclude
        Runtime._AimRayParams.IgnoreWater = true
    end
    Runtime._AimRayFilter = Runtime._AimRayFilter or {}
    Runtime._AimRayFilter[1] = lpc
    Runtime._AimRayFilter[2] = Camera
    Runtime._AimRayParams.FilterDescendantsInstances = Runtime._AimRayFilter
    local res = workspace:Raycast(Camera.CFrame.Position, tp.Position - Camera.CFrame.Position, Runtime._AimRayParams)
    if res then return res.Instance:IsDescendantOf(tp.Parent) end
    return true
end

function CacheNPC(obj)
    if not obj:IsA("Humanoid") then return end; local char = obj.Parent
    if char and char:IsA("Model") and char ~= LocalPlayer.Character then
        task.delay(0.1, function()
            if char.Parent and char:FindFirstChild("HumanoidRootPart") and not Players:GetPlayerFromCharacter(char) then
                NPCCache[char] = true
            end
        end)
    end
end
task.spawn(function()
    for i, v in ipairs(workspace:GetDescendants()) do
        CacheNPC(v)
        if i % 100 == 0 then
            RunService.Heartbeat:Wait()
        end
    end
end)
AddConn(workspace.DescendantAdded:Connect(function(desc)
    if State.Unloading then return end
    CacheNPC(desc)
end))

local TargetsDirty = true
local function MarkTargetsDirty()
    TargetsDirty = true
end
AddConn(Players.PlayerAdded:Connect(MarkTargetsDirty))
AddConn(Players.PlayerRemoving:Connect(MarkTargetsDirty))
AddConn(workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Humanoid") or desc.Name == "HumanoidRootPart" then
        TargetsDirty = true
    end
end))

task.spawn(function()
    while State.Running do
        if not TargetsDirty then
            task.wait(1.5)
        else
            TargetsDirty = false
            local newTargets = {}
            local mode = Config.TargetMode
            local camPos = Camera.CFrame.Position
            if mode == 1 or mode == 3 then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - camPos).Magnitude <= 2000 then
                            newTargets[p.Character] = p.DisplayName or p.Name
                        end
                    end
                end
            end
            if mode == 2 or mode == 3 then
                local c = 0
                for char in pairs(NPCCache) do
                    local hum = char:FindFirstChild("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if char.Parent and hum and hrp and hum.Health > 0 then
                        if (hrp.Position - camPos).Magnitude <= 2000 then
                            newTargets[char] = char.Name
                        end
                    else
                        NPCCache[char] = nil
                    end
                    c = c + 1
                    if c % 100 == 0 then RunService.Heartbeat:Wait() end
                end
            end
            local c2 = 0
            for char in pairs(ESP_Cache) do
                if not newTargets[char] then ClearESP(char) end
                c2 = c2 + 1
                if c2 % 100 == 0 then RunService.Heartbeat:Wait() end
            end
            ValidTargets = newTargets
            task.wait(1.5)
        end
    end
end)

task.spawn(function()
    while State.Running do
        task.wait(2.5)
        local c = 0
        for char in pairs(NPCCache) do
            if (not char) or (not char.Parent) then
                NPCCache[char] = nil
            else
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not (hum and hrp and hum.Health > 0) then
                    NPCCache[char] = nil
                end
            end
            c = c + 1
            if c % 100 == 0 then RunService.Heartbeat:Wait() end
        end
    end
end)

-- [ BACKEND MOVEMENT AND SYSTEM CONTROLS ]
local InvisState = {
    Active = false,
    RealCharacter = nil,
    CloneCharacter = nil,
    OriginalCFrame = nil,
    OriginalName = nil,
    Connections = {}
}

local function CleanupInvisibilityState()
    pcall(function() LocalPlayer.ReplicationFocus = nil end)

    for _, c in pairs(InvisState.Connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(InvisState.Connections)

    if InvisState.CloneCharacter then
        pcall(function() InvisState.CloneCharacter:Destroy() end)
        InvisState.CloneCharacter = nil
    end

    local real = InvisState.RealCharacter
    if real and real.Parent then
        if InvisState.OriginalName then
            pcall(function() real.Name = InvisState.OriginalName end)
        end

        local hrp = real:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function() hrp.Anchored = false end)
        end

        pcall(function() LocalPlayer.Character = real end)
        local hum = real:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() workspace.CurrentCamera.CameraSubject = hum end)
        end
    end

    InvisState.RealCharacter = nil
    InvisState.OriginalCFrame = nil
    InvisState.OriginalName = nil
    InvisState.Active = false
end

function SetInvisibility(on)
    if not on then
        Config.InvisToggle = false
        if not InvisState.Active and not InvisState.CloneCharacter and not InvisState.RealCharacter then return end
        local cloneHRP = InvisState.CloneCharacter and InvisState.CloneCharacter:FindFirstChild("HumanoidRootPart")
        local targetCFrame = cloneHRP and cloneHRP.CFrame
        local real = InvisState.RealCharacter

        if real and real.Parent then
            if InvisState.CloneCharacter then
                for _, child in ipairs(InvisState.CloneCharacter:GetChildren()) do
                    if child:IsA("Tool") then
                        child.Parent = real
                    end
                end
            end

            if InvisState.OriginalName then
                pcall(function() real.Name = InvisState.OriginalName end)
            end

            local hrp = real:FindFirstChild("HumanoidRootPart")
            if hrp and targetCFrame then
                local startCFrame = hrp.CFrame
                pcall(function() hrp.Anchored = true end)
                for i = 1, 20 do
                    pcall(function() hrp.CFrame = startCFrame:Lerp(targetCFrame, i / 20) end)
                    task.wait()
                end
                pcall(function() hrp.CFrame = targetCFrame end)
            end
        end

        CleanupInvisibilityState()
        return
    end

    if InvisState.Active then return end
    local realChar = LocalPlayer.Character
    local hrp = realChar and realChar:FindFirstChild("HumanoidRootPart")
    if not (realChar and hrp) then return end

    InvisState.Active = true
    InvisState.RealCharacter = realChar
    InvisState.OriginalCFrame = hrp.CFrame
    InvisState.OriginalName = realChar.Name

    local ok, clone = pcall(function()
        realChar.Archivable = true
        local created = realChar:Clone()
        realChar.Archivable = false
        return created
    end)
    realChar.Archivable = false
    if not ok or not clone then
        CleanupInvisibilityState()
        return
    end
    
    clone.Name = LocalPlayer.Name
    clone.Parent = workspace
    InvisState.CloneCharacter = clone

    pcall(function() realChar.Name = LocalPlayer.Name .. "_Real" end)
    
    local cloneHrp = clone:FindFirstChild("HumanoidRootPart")
    if cloneHrp then
        pcall(function() LocalPlayer.ReplicationFocus = cloneHrp end)
    end

    for _, child in ipairs(realChar:GetChildren()) do
        if child:IsA("Tool") then
            child.Parent = clone
        end
    end

    local toolConn = realChar.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.defer(function()
                if InvisState.Active and InvisState.CloneCharacter and child.Parent == realChar then
                    child.Parent = InvisState.CloneCharacter
                end
            end)
        end
    end)
    table.insert(InvisState.Connections, toolConn)

    local startY = hrp.Position.Y
    local targetY = startY + 1500
    pcall(function() hrp.Anchored = true end)
    for i=1, 30 do
        pcall(function() hrp.CFrame = CFrame.new(hrp.Position.X, startY + (targetY - startY)*(i/30), hrp.Position.Z) end)
        task.wait()
    end
    
    pcall(function() LocalPlayer.Character = clone end)
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() workspace.CurrentCamera.CameraSubject = hum end) end
    
    local animate = clone:FindFirstChild("Animate")
    if animate then
        pcall(function()
            animate.Disabled = true
            task.wait()
            animate.Disabled = false
        end)
    end

    table.insert(InvisState.Connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
        if Config.InvisToggle then
            SetInvisibility(false)
            task.wait(0.5)
            SetInvisibility(true)
        end
    end))
end

OriginalSky = nil
pcall(function()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") then OriginalSky = obj:Clone(); break end
    end
end)

SkyOptions = {
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

SkyList = {
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

function ApplySkyById(assetId)
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

function ResetSky()
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

RTXLoaded = false
function SetRTX(on)
    if on and not RTXLoaded then
        ShowConfirm(
            TL("Enable Ray Tracing", "เปิดใช้งาน Ray Tracing"),
            TL("This action is permanent for this session and cannot be turned off. Ray Tracing may reduce FPS. Continue?", "การทำงานนี้จะเปิดถาวรในรอบนี้และปิดไม่ได้ อาจทำให้ FPS ลดลง ต้องการดำเนินการต่อหรือไม่?"),
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
        task.delay(0.05, function()
            if not RTXLoaded then
                Config.RTX_Enabled = false
                pcall(function() UpdateToggleUIFromKeybind("RTX_Enabled") end)
            end
        end)
    elseif on and RTXLoaded then
        Config.RTX_Enabled = true
        pcall(function() UpdateToggleUIFromKeybind("RTX_Enabled") end)
    elseif not on then
        Config.RTX_Enabled = true
        pcall(function() UpdateToggleUIFromKeybind("RTX_Enabled") end)
        ShowToast("🔒 Ray Tracing ถูกล็อกเป็นเปิดแล้ว", Colors.Red)
    end
end

function SetWalkSpeed(on)
    if Conns.WS_Loop then Conns.WS_Loop:Disconnect(); Conns.WS_Loop = nil end
    if on then
        Conns.WS_Loop = RunService.RenderStepped:Connect(function(dt)
            local lpc = LocalPlayer.Character
            if not lpc then return end
            local h = lpc:FindFirstChildOfClass("Humanoid")
            local hrp = lpc:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.MoveDirection.Magnitude > 0 then
                local vel = hrp.AssemblyLinearVelocity
                if Vector2.new(vel.X, vel.Z).Magnitude < 0.2 then return end
                hrp.Velocity = Vector3.new(h.MoveDirection.X * Config.WalkSpeed, hrp.Velocity.Y, h.MoveDirection.Z * Config.WalkSpeed)
            end
        end)
    else
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then
            local o = _G._PwyvOrig or {}
            RestoreProperty(h, "WalkSpeed", o.WalkSpeed, 16)
        end
    end
end

function SetJumpPower(on)
    if Conns.JP_Loop then Conns.JP_Loop:Disconnect(); Conns.JP_Loop = nil end
    if on then
        Conns.JP_Loop = RunService.Heartbeat:Connect(function()
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then
                h.UseJumpPower = true
                h.JumpPower = Config.JumpPower
            end
        end)
    else
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then
            local o = _G._PwyvOrig or {}
            RestoreProperty(h, "UseJumpPower", o.UseJumpPower, true)
            RestoreProperty(h, "JumpPower", o.JumpPower, 50)
        end
    end
end

function SetNoclip(on)
    Config.Noclip = on
    if Conns.NC_Conn then Conns.NC_Conn:Disconnect(); Conns.NC_Conn = nil end
    if Conns.NC_DescConn then Conns.NC_DescConn:Disconnect(); Conns.NC_DescConn = nil end
    if Conns.NC_Heartbeat then Conns.NC_Heartbeat:Disconnect(); Conns.NC_Heartbeat = nil end
    if Conns.NC_WorkspaceDescConn then Conns.NC_WorkspaceDescConn:Disconnect(); Conns.NC_WorkspaceDescConn = nil end
    ReleaseNoCollideParts(NoclipTouchedParts, "Noclip")
    Conns.NC_TrackedChar = nil
    table.clear(NoclipFloorParts)
    if on then
        local function applyNoClipPart(part)
            if NoclipFloorParts[part] or IsLocalCharacterPart(part) then
                return
            end
            AcquireNoCollide(part, NoclipTouchedParts, "Noclip", true)
        end
        local function applyNoClipCharacter(lpc)
            if not lpc then return end
            Conns.NC_TrackedChar = lpc
            if Conns.NC_DescConn then
                Conns.NC_DescConn:Disconnect()
                Conns.NC_DescConn = nil
            end
            Conns.NC_DescConn = AddConn(lpc.DescendantAdded:Connect(function(desc)
                if Config.Noclip then
                    applyNoClipPart(desc)
                end
            end))
        end
        UpdateNoclipFloorParts()
        applyNoClipCharacter(LocalPlayer.Character)
        ApplyWorkspaceNoCollide(NoclipTouchedParts, "Noclip", function()
            return Config.Noclip and not State.Unloading
        end, function(part)
            return NoclipFloorParts[part] == true or IsLocalCharacterPart(part)
        end, true)
        Conns.NC_WorkspaceDescConn = AddConn(workspace.DescendantAdded:Connect(function(desc)
            if Config.Noclip and not NoclipFloorParts[desc] then
                applyNoClipPart(desc)
            end
        end))
        Conns.NC_Heartbeat = AddConn(RunService.Stepped:Connect(function()
            if not Config.Noclip then return end
            local char = LocalPlayer.Character
            if not char then return end
            UpdateNoclipFloorParts()
            if Conns.NC_TrackedChar ~= char then
                ReleaseNoCollideParts(NoclipTouchedParts, "Noclip")
                UpdateNoclipFloorParts()
                applyNoClipCharacter(char)
                ApplyWorkspaceNoCollide(NoclipTouchedParts, "Noclip", function()
                    return Config.Noclip and not State.Unloading
                end, function(part)
                    return NoclipFloorParts[part] == true or IsLocalCharacterPart(part)
                end, true)
                return
            end
            ReinforceNoCollideParts(NoclipTouchedParts, NoclipFloorParts, true)
        end))
        Conns.NC_Conn = AddConn(LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.1)
            if Config.Noclip then
                ReleaseNoCollideParts(NoclipTouchedParts, "Noclip")
                UpdateNoclipFloorParts()
                applyNoClipCharacter(char)
                ApplyWorkspaceNoCollide(NoclipTouchedParts, "Noclip", function()
                    return Config.Noclip and not State.Unloading
                end, function(part)
                    return NoclipFloorParts[part] == true or IsLocalCharacterPart(part)
                end, true)
            end
        end))
    end
end

function SetInfJump(on)
    if Conns.IJ_Conn then Conns.IJ_Conn:Disconnect(); Conns.IJ_Conn = nil end
    if Conns.IJ_Conn2 then Conns.IJ_Conn2:Disconnect(); Conns.IJ_Conn2 = nil end
    if on then
        local function doJump()
            local char = LocalPlayer.Character
            local h = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if h and hrp then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
                hrp.Velocity = Vector3.new(hrp.Velocity.X, Config.JumpPower or 50, hrp.Velocity.Z)
            end
        end
        Conns.IJ_Conn = RunService.Heartbeat:Connect(function()
            pcall(function()
                if UIS:IsKeyDown(Enum.KeyCode.Space) then doJump() end
            end)
        end)
        Conns.IJ_Conn2 = UIS.JumpRequest:Connect(doJump)
    end
end

function SetAntiAFK(on)
    if Conns.AFK_Conn then Conns.AFK_Conn:Disconnect(); Conns.AFK_Conn = nil end
    if on then
        local vu = VirtualUser or cloneref(game:GetService("VirtualUser"))
        
        local function activeAntiAfk()
            if not vu then return end
            pcall(function()
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(0, 0))
            end)
            pcall(function()
                vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.1)
                vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end

        Conns.AFK_Conn = AddConn(LocalPlayer.Idled:Connect(function()
            activeAntiAfk()
        end))

        local currentRun = tick()
        State.AntiAFKRunID = currentRun
        task.spawn(function()
            while State.AntiAFKRunID == currentRun and Config.AntiAFK do
                task.wait(120)
                if State.AntiAFKRunID == currentRun and Config.AntiAFK then
                    activeAntiAfk()
                end
            end
        end)
    else
        State.AntiAFKRunID = nil
    end
end

function SetAntiStun(on)
    if Conns.AntiStun_Loop then Conns.AntiStun_Loop:Disconnect(); Conns.AntiStun_Loop = nil end
    if on then
        Conns.AntiStun_Loop = RunService.Stepped:Connect(function()
            pcall(function()
                local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    h.PlatformStand = false
                    h.Sit = false
                end
            end)
        end)
    else
        pcall(function()
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then
                h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end
        end)
    end
end

function SetInfZoom(on)
    if on then
        if _origMaxZoom == nil then
            _origMaxZoom = LocalPlayer.CameraMaxZoomDistance
        end
        if _origMinZoom == nil then
            _origMinZoom = LocalPlayer.CameraMinZoomDistance
        end
        LocalPlayer.CameraMaxZoomDistance = math.huge
        LocalPlayer.CameraMinZoomDistance = 0
    else
        if _origMaxZoom ~= nil then
            LocalPlayer.CameraMaxZoomDistance = _origMaxZoom
        end
        if _origMinZoom ~= nil then
            LocalPlayer.CameraMinZoomDistance = _origMinZoom
        end
    end
end

Conns.InteractAddedConn = nil
function UpdateInteractables()
    local function ProcessPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") then return end
        InteractPromptCache[prompt] = true
        if not OriginalInteractData[prompt] then
            OriginalInteractData[prompt] = {
                HoldDuration = prompt.HoldDuration,
                MaxActivationDistance = prompt.MaxActivationDistance
            }
        end
        local orig = OriginalInteractData[prompt]
        if Config.InstantPress then
            prompt.HoldDuration = 0
        else
            prompt.HoldDuration = orig.HoldDuration
        end
        if Config.AuraRange then
            prompt.MaxActivationDistance = 50
        else
            prompt.MaxActivationDistance = orig.MaxActivationDistance
        end
    end

    if not next(InteractPromptCache) then
        pcall(function()
            for i, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then
                    InteractPromptCache[v] = true
                end
                if i % 500 == 0 then task.wait() end
            end
        end)
    end
    for prompt in pairs(InteractPromptCache) do
        if prompt and prompt.Parent then
            ProcessPrompt(prompt)
        else
            InteractPromptCache[prompt] = nil
            OriginalInteractData[prompt] = nil
        end
    end

    if not Conns.InteractAddedConn then
        Conns.InteractAddedConn = AddConn(workspace.DescendantAdded:Connect(function(desc)
            if State.Unloading then return end
            if desc:IsA("ProximityPrompt") then
                pcall(function() ProcessPrompt(desc) end)
            end
        end))
    end
end

task.spawn(function()
    while State.Running do
        task.wait(2.5)
        if Config.InstantPress or Config.AuraRange then
            UpdateInteractables()
        end
    end
end)

function UpdateXray(cache, enabled)
    if not cache then return end
    if cache.__conn then
        SafeDisconnect(cache.__conn)
        cache.__conn = nil
    end
    if enabled then
        local function applyPart(v)
            if not v or not v:IsA("BasePart") then return end
            local parent = v.Parent
            if not parent then return end
            local ic = parent:FindFirstChildWhichIsA("Humanoid") or (parent.Parent and parent.Parent:FindFirstChildWhichIsA("Humanoid"))
            if not ic then
                if not cache[v] then cache[v] = v.LocalTransparencyModifier end
                v.LocalTransparencyModifier = 0.5
            end
        end
        task.spawn(function()
            for i, v in ipairs(workspace:GetDescendants()) do
                if not enabled then break end
                applyPart(v)
                if i % 500 == 0 then task.wait() end
            end
        end)
        cache.__conn = AddConn(workspace.DescendantAdded:Connect(function(v)
            if not enabled then return end
            applyPart(v)
        end))
    else
        for p, o in pairs(cache) do
            if p ~= "__conn" then
                pcall(function() if p and p.Parent then p.LocalTransparencyModifier = o end end)
            end
        end
        table.clear(cache)
    end
end

Conns.CFly_Loop = nil
function SetFly(on)
    Config.FlyToggle = on
    if Conns.FlyDescConn then Conns.FlyDescConn:Disconnect(); Conns.FlyDescConn = nil end
    if Conns.FlyWorkspaceDescConn then Conns.FlyWorkspaceDescConn:Disconnect(); Conns.FlyWorkspaceDescConn = nil end
    if Conns.FlyNC_Heartbeat then Conns.FlyNC_Heartbeat:Disconnect(); Conns.FlyNC_Heartbeat = nil end
    if Conns.CFly_Loop then Conns.CFly_Loop:Disconnect(); Conns.CFly_Loop = nil end
    ReleaseNoCollideParts(FlyTouchedParts, "FlyToggle")
    Conns.FlyTrackedChar = nil

    if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG = nil end
    if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV = nil end
    if FlyAtt then pcall(function() FlyAtt:Destroy() end); FlyAtt = nil end

    local lpc = LocalPlayer.Character
    local hum = lpc and lpc:FindFirstChildOfClass("Humanoid")
    local hrp = lpc and lpc:FindFirstChild("HumanoidRootPart")

    if hum then
        hum.PlatformStand = false
        pcall(function()
            local animate = lpc:FindFirstChild("Animate")
            if animate then
                animate.Disabled = false
            end
        end)
    end

    if not on then
        return
    end
    if not lpc or not hrp then
        return
    end

    FlyAtt = Instance.new("Attachment")
    FlyAtt.Name = "FlyAtt"
    FlyAtt.Parent = hrp

    FlyBG = Instance.new("AlignOrientation")
    FlyBG.Mode = Enum.OrientationAlignmentMode.OneAttachment
    FlyBG.Attachment0 = FlyAtt
    FlyBG.MaxTorque = 9e9
    FlyBG.Responsiveness = 200
    FlyBG.CFrame = hrp.CFrame
    FlyBG.Parent = hrp

    FlyBV = Instance.new("LinearVelocity")
    FlyBV.Attachment0 = FlyAtt
    FlyBV.MaxForce = 9e9
    FlyBV.RelativeTo = Enum.ActuatorRelativeTo.World
    FlyBV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    FlyBV.VectorVelocity = Vector3.new(0, 0, 0)
    FlyBV.Parent = hrp

    if hum then
        hum.PlatformStand = true
    end
    pcall(function()
        local animate = lpc:FindFirstChild("Animate")
        if animate then
            animate.Disabled = true
        end
    end)

    if Config.FlyNoclip then
        Conns.FlyTrackedChar = lpc
        ApplyCharacterNoCollide(lpc, FlyTouchedParts, "FlyToggle")
        ApplyWorkspaceNoCollide(FlyTouchedParts, "FlyToggle", function()
            return Config.FlyToggle and Config.FlyNoclip and not State.Unloading
        end)

        Conns.FlyDescConn = AddConn(lpc.DescendantAdded:Connect(function(desc)
            if Config.FlyToggle and Config.FlyNoclip then
                AcquireNoCollide(desc, FlyTouchedParts, "FlyToggle")
            end
        end))
        Conns.FlyWorkspaceDescConn = AddConn(workspace.DescendantAdded:Connect(function(desc)
            if Config.FlyToggle and Config.FlyNoclip then
                AcquireNoCollide(desc, FlyTouchedParts, "FlyToggle")
            end
        end))
        Conns.FlyNC_Heartbeat = AddConn(RunService.Stepped:Connect(function()
            if not Config.FlyToggle or not Config.FlyNoclip then return end
            local char = LocalPlayer.Character
            if not char then return end
            if Conns.FlyTrackedChar ~= char then
                ReleaseNoCollideParts(FlyTouchedParts, "FlyToggle")
                Conns.FlyTrackedChar = char
                ApplyWorkspaceNoCollide(FlyTouchedParts, "FlyToggle", function()
                    return Config.FlyToggle and Config.FlyNoclip and not State.Unloading
                end)
            end
            ApplyCharacterNoCollide(char, FlyTouchedParts, "FlyToggle")
            ReinforceNoCollideParts(FlyTouchedParts)
        end))
    end

    local cam = workspace.CurrentCamera or Camera
    Conns.CFly_Loop = AddConn(RunService.RenderStepped:Connect(function()
        if not Config.FlyToggle then return end
        if not FlyBV or not FlyBG or not FlyBV.Parent or not FlyBG.Parent then return end
        local currentChar = LocalPlayer.Character
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end
        local speed = Config.FlySpeed or 50
        local vel = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then vel = vel + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then vel = vel - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then vel = vel - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then vel = vel + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, 1, 0) end
        FlyBV.VectorVelocity = vel.Magnitude > 0 and (vel.Unit * speed) or Vector3.new(0, 0, 0)
        FlyBG.CFrame = CFrame.new(currentHrp.Position, currentHrp.Position + cam.CFrame.LookVector)
    end))
end

function UpdateFlyNoclip()
    if not Config.FlyToggle then return end
    if Conns.FlyDescConn then Conns.FlyDescConn:Disconnect(); Conns.FlyDescConn = nil end
    if Conns.FlyWorkspaceDescConn then Conns.FlyWorkspaceDescConn:Disconnect(); Conns.FlyWorkspaceDescConn = nil end
    if Conns.FlyNC_Heartbeat then Conns.FlyNC_Heartbeat:Disconnect(); Conns.FlyNC_Heartbeat = nil end
    ReleaseNoCollideParts(FlyTouchedParts, "FlyToggle")
    Conns.FlyTrackedChar = nil
    
    if Config.FlyNoclip then
        local lpc = LocalPlayer.Character
        if not lpc then return end
        Conns.FlyTrackedChar = lpc
        ApplyCharacterNoCollide(lpc, FlyTouchedParts, "FlyToggle")
        ApplyWorkspaceNoCollide(FlyTouchedParts, "FlyToggle", function()
            return Config.FlyToggle and Config.FlyNoclip and not State.Unloading
        end)
        Conns.FlyDescConn = AddConn(lpc.DescendantAdded:Connect(function(desc)
            if Config.FlyToggle and Config.FlyNoclip then
                AcquireNoCollide(desc, FlyTouchedParts, "FlyToggle")
            end
        end))
        Conns.FlyWorkspaceDescConn = AddConn(workspace.DescendantAdded:Connect(function(desc)
            if Config.FlyToggle and Config.FlyNoclip then
                AcquireNoCollide(desc, FlyTouchedParts, "FlyToggle")
            end
        end))
        Conns.FlyNC_Heartbeat = AddConn(RunService.Stepped:Connect(function()
            if not Config.FlyToggle or not Config.FlyNoclip then return end
            local char = LocalPlayer.Character
            if not char then return end
            if Conns.FlyTrackedChar ~= char then
                ReleaseNoCollideParts(FlyTouchedParts, "FlyToggle")
                Conns.FlyTrackedChar = char
                ApplyWorkspaceNoCollide(FlyTouchedParts, "FlyToggle", function()
                    return Config.FlyToggle and Config.FlyNoclip and not State.Unloading
                end)
            end
            ApplyCharacterNoCollide(char, FlyTouchedParts, "FlyToggle")
            ReinforceNoCollideParts(FlyTouchedParts)
        end))
    end
end

function ApplyFPSBoost()
    if Config.FPS_NoShadows then pcall(function() Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9 end) end
    if Config.FPS_LowQuality then pcall(function() settings().Rendering.QualityLevel = 1 end) end
    if Conns.FPS_DescConn then Conns.FPS_DescConn:Disconnect(); Conns.FPS_DescConn = nil end
    local function Proc(inst)
        if inst:IsDescendantOf(Players) then return end
        if Config.FPS_NoParticles and (inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles")) then inst.Enabled = false end
        if Config.FPS_NoClothes and (inst:IsA("Clothing") or inst:IsA("SurfaceAppearance") or inst:IsA("BaseWrap")) then pcall(function() inst:Destroy() end); return end
        if Config.FPS_LowQuality then
            if inst:IsA("BasePart") then pcall(function() inst.Material = Enum.Material.Plastic; inst.Reflectance = 0 end) end
        end
        if inst:IsA("PostEffect") then pcall(function() inst.Enabled = false end) end
    end
    task.spawn(function()
        for i, v in ipairs(game:GetDescendants()) do
            pcall(function() Proc(v) end)
            if i % 1000 == 0 then task.wait() end
        end
    end)
    Conns.FPS_DescConn = game.DescendantAdded:Connect(function(v)
        if State.Unloading then return end
        task.wait(0.3)
        if State.Unloading then return end
        pcall(function() Proc(v) end)
    end)
end

function DisableFPSBoost()
    if Conns.FPS_DescConn then Conns.FPS_DescConn:Disconnect(); Conns.FPS_DescConn = nil end
    pcall(function() Lighting.GlobalShadows = true end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
end

function StartSafeTP(tp)
    if Conns.SafeTP_Conn then Conns.SafeTP_Conn:Disconnect(); Conns.SafeTP_Conn = nil end
    Conns.SafeTP_Conn = RunService.Heartbeat:Connect(function(dt)
        if not Config.TPGOSwitch then Conns.SafeTP_Conn:Disconnect(); Conns.SafeTP_Conn = nil; return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local tHRP = tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
        if not(myHRP and tHRP) then return end
        if (tHRP.Position - myHRP.Position).Magnitude > 4 then
            myHRP.CFrame = myHRP.CFrame:Lerp(CFrame.new(tHRP.Position + tHRP.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)), math.clamp(dt * math.clamp(Config.TPFlightSens, 10, 500) * 0.12, 0.01, 0.4))
        end
    end)
end

function StopSafeTP()
    if Conns.SafeTP_Conn then Conns.SafeTP_Conn:Disconnect(); Conns.SafeTP_Conn = nil end
end

-- [ HIP HEIGHT OPTIMIZED FLOAT SYSTEM ]
do
HipHeight_Platform = nil
HipHeight_Loop = nil
HipHeight_RayParams = nil
LastGroundY = nil

function InitHipHeightRayParams()
    if HipHeight_RayParams then return end
    HipHeight_RayParams = RaycastParams.new()
    HipHeight_RayParams.FilterType = Enum.RaycastFilterType.Exclude
    HipHeight_RayParams.IgnoreWater = true
end

function GetGroundHeight(position)
    InitHipHeightRayParams()
    local char = LocalPlayer.Character
    if not char then return nil end
    local blacklist = {char}
    if HipHeight_Platform then table.insert(blacklist, HipHeight_Platform) end
    HipHeight_RayParams.FilterDescendantsInstances = blacklist
    
    local rayStart = Vector3.new(position.X, position.Y + 10, position.Z)
    local rayDirection = Vector3.new(0, -1000, 0)
    local result = workspace:Raycast(rayStart, rayDirection, HipHeight_RayParams)
    if result then return result.Position.Y end
    return nil
end

function SetHipHeight(on)
    Config.HipHeightToggle = on
    if HipHeight_Loop then HipHeight_Loop:Disconnect(); HipHeight_Loop = nil end
    if HipHeight_Platform then pcall(function() HipHeight_Platform:Destroy() end); HipHeight_Platform = nil end
    LastGroundY = nil
    
    if on then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum and hum.Health > 0) then return end
        
        local groundY = GetGroundHeight(hrp.Position) or (hrp.Position.Y - 3)
        LastGroundY = groundY
        
        HipHeight_Platform = Instance.new("Part")
        HipHeight_Platform.Name = "HipHeightPlatform"
        HipHeight_Platform.Size = Vector3.new(12, 1, 12)
        HipHeight_Platform.Anchored = true
        HipHeight_Platform.Transparency = 1
        HipHeight_Platform.CanCollide = true
        HipHeight_Platform.CanQuery = false
        HipHeight_Platform.Parent = workspace
        
        local targetY = groundY + (Config.HipHeightValue or 50)
        HipHeight_Platform.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z)
        
        task.wait(0.1)
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(hrp.Position.X, targetY + 3.5, hrp.Position.Z)
        end
        
        HipHeight_Loop = RunService.Heartbeat:Connect(function()
            if not Config.HipHeightToggle then return end
            local currentChar = LocalPlayer.Character
            local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
            local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
            if not (currentHrp and currentHum and currentHum.Health > 0) then return end
            
            local vel = currentHrp.AssemblyLinearVelocity
            local isStationary = (Vector2.new(vel.X, vel.Z).Magnitude < 0.2)
            
            local groundY = LastGroundY
            if not isStationary or not LastGroundY then
                local newGround = GetGroundHeight(currentHrp.Position)
                if newGround then
                    groundY = newGround
                    LastGroundY = newGround
                end
            end
            
            if groundY and HipHeight_Platform then
                local newTargetY = groundY + (Config.HipHeightValue or 50)
                local currentY = HipHeight_Platform.Position.Y
                local lerpY = currentY + (newTargetY - currentY) * 0.15
                HipHeight_Platform.CFrame = CFrame.new(currentHrp.Position.X, lerpY, currentHrp.Position.Z)
            end
        end)
    end
end

function SetHipHeightValue(newValue)
    local targetOffset = tonumber(newValue)
    if not targetOffset then return end
    Config.HipHeightValue = targetOffset
    if Config.HipHeightToggle and HipHeight_Platform then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local groundY = GetGroundHeight(hrp.Position)
            if groundY then
                local newTargetY = groundY + targetOffset
                local tween = TweenService:Create(HipHeight_Platform, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    CFrame = CFrame.new(HipHeight_Platform.Position.X, newTargetY, HipHeight_Platform.Position.Z)
                })
                tween:Play()
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
end

-- [ LIGHTING, FOG, FULLBRIGHT ]
do
local OriginalFog = {}
Conns.FogConn = nil
Conns.FogDescAddedConn = nil

function SaveOriginalFog(atmos)
    if not OriginalFog.FogEnd then
        OriginalFog.FogEnd = Lighting.FogEnd
        OriginalFog.FogStart = Lighting.FogStart
    end
    if atmos and not OriginalFog[atmos] then
        OriginalFog[atmos] = {
            Density = atmos.Density,
            Haze = atmos.Haze,
            Glare = atmos.Glare
        }
    end
end

function ClearFogProperties()
    pcall(function()
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 9e9
    end)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            SaveOriginalFog(obj)
            pcall(function()
                obj.Density = 0
                obj.Haze = 0
                obj.Glare = 0
            end)
        end
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Atmosphere") then
            SaveOriginalFog(obj)
            pcall(function()
                obj.Density = 0
                obj.Haze = 0
                obj.Glare = 0
            end)
        end
    end
end

function SetRemoveFog(on)
    Config.RemoveFog_Toggle = on
    if Conns.FogConn then Conns.FogConn:Disconnect(); Conns.FogConn = nil end
    if Conns.FogDescAddedConn then Conns.FogDescAddedConn:Disconnect(); Conns.FogDescAddedConn = nil end
    if Conns.FogLightingDescConn then Conns.FogLightingDescConn:Disconnect(); Conns.FogLightingDescConn = nil end
    
    if on then
        SaveOriginalFog()
        ClearFogProperties()
        
        Conns.FogConn = AddConn(Lighting.Changed:Connect(function(prop)
            if State.Unloading then return end
            if not Config.RemoveFog_Toggle then return end
            if prop == "FogEnd" or prop == "FogStart" then
                pcall(function()
                    Lighting.FogEnd = 9e9
                    Lighting.FogStart = 9e9
                end)
            end
        end))
        
        local function onDescendant(desc)
            if State.Unloading then return end
            if desc:IsA("Atmosphere") then
                task.wait(0.1)
                if State.Unloading then return end
                pcall(function()
                    SaveOriginalFog(desc)
                    desc.Density = 0
                    desc.Haze = 0
                    desc.Glare = 0
                end)
            end
        end
        Conns.FogDescAddedConn = AddConn(workspace.DescendantAdded:Connect(onDescendant))
        Conns.FogLightingDescConn = AddConn(Lighting.DescendantAdded:Connect(onDescendant))
    else
        if OriginalFog.FogEnd then
            pcall(function()
                Lighting.FogEnd = OriginalFog.FogEnd
                Lighting.FogStart = OriginalFog.FogStart
            end)
        end
        for atmos, data in pairs(OriginalFog) do
            if typeof(atmos) == "Instance" and atmos.Parent then
                pcall(function()
                    atmos.Density = data.Density
                    atmos.Haze = data.Haze
                    atmos.Glare = data.Glare
                end)
            end
        end
        table.clear(OriginalFog)
    end
end

local OriginalLighting = {}
local HasOriginalLighting = false
Conns.FullbrightConn = nil

local function SaveOriginalLighting()
    table.clear(OriginalLighting)
    OriginalLighting.Ambient = Lighting.Ambient
    OriginalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
    OriginalLighting.Brightness = Lighting.Brightness
    OriginalLighting.ClockTime = Lighting.ClockTime
    OriginalLighting.GlobalShadows = Lighting.GlobalShadows
    OriginalLighting.ColorShift_Bottom = Lighting.ColorShift_Bottom
    OriginalLighting.ColorShift_Top = Lighting.ColorShift_Top
    OriginalLighting.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
    OriginalLighting.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    OriginalLighting.ExposureCompensation = Lighting.ExposureCompensation
    OriginalLighting.FogColor = Lighting.FogColor
    OriginalLighting.FogEnd = Lighting.FogEnd
    OriginalLighting.FogStart = Lighting.FogStart
    OriginalLighting.ShadowSoftness = Lighting.ShadowSoftness
    HasOriginalLighting = true
end

function SetFullbright(on)
    Config.Fullbright_Toggle = on
    if Conns.FullbrightConn then Conns.FullbrightConn:Disconnect(); Conns.FullbrightConn = nil end
    if on then
        SaveOriginalLighting()
        local function apply()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
            Lighting.Ambient = Color3.fromRGB(128,128,128)
            Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
            Lighting.ColorShift_Top = Color3.new(0, 0, 0)
            Lighting.EnvironmentDiffuseScale = 1
            Lighting.EnvironmentSpecularScale = 1
            Lighting.ExposureCompensation = 0.1
        end
        pcall(apply)
        Conns.FullbrightConn = AddConn(Lighting.Changed:Connect(function(prop)
            if State.Unloading then return end
            if not Config.Fullbright_Toggle then return end
            if prop == "Brightness" or prop == "ClockTime" or prop == "GlobalShadows" or prop == "OutdoorAmbient" or prop == "Ambient"
                or prop == "ColorShift_Bottom" or prop == "ColorShift_Top" or prop == "EnvironmentDiffuseScale"
                or prop == "EnvironmentSpecularScale" or prop == "ExposureCompensation" then
                pcall(apply)
            end
        end))
    else
        if HasOriginalLighting then
            pcall(function()
                Lighting.Ambient = OriginalLighting.Ambient
                Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
                Lighting.Brightness = OriginalLighting.Brightness
                Lighting.ClockTime = OriginalLighting.ClockTime
                Lighting.GlobalShadows = OriginalLighting.GlobalShadows
                Lighting.ColorShift_Bottom = OriginalLighting.ColorShift_Bottom
                Lighting.ColorShift_Top = OriginalLighting.ColorShift_Top
                Lighting.EnvironmentDiffuseScale = OriginalLighting.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = OriginalLighting.EnvironmentSpecularScale
                Lighting.ExposureCompensation = OriginalLighting.ExposureCompensation
                Lighting.FogColor = OriginalLighting.FogColor
                Lighting.FogEnd = OriginalLighting.FogEnd
                Lighting.FogStart = OriginalLighting.FogStart
                Lighting.ShadowSoftness = OriginalLighting.ShadowSoftness
            end)
            HasOriginalLighting = false
            table.clear(OriginalLighting)
        end
    end
end

-- Collision Bypass
Conns.CollisionBypassConn = nil
local CollisionBypassCharConns = {}
local CollisionBypassPlayerConns = {}
local CollisionBypassTouchConns = {}
local CollisionBypassMode = "Bypass"
local CollisionBypassActive = false

local function DisconnectCollisionTouchConns()
    for part, conn in pairs(CollisionBypassTouchConns) do
        pcall(function()
            if conn then conn:Disconnect() end
        end)
        CollisionBypassTouchConns[part] = nil
    end
end

local function GetCharacterRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local function TrackCollisionPart(part)
    if not part:IsA("BasePart") then return end
    local myChar = LocalPlayer.Character
    if myChar and part.Name == "HumanoidRootPart" and part:IsDescendantOf(myChar) then return end
    AcquireNoCollide(part, CollisionBypassTouchedParts, "CollisionBypass")
    if CollisionBypassMode == "Bounce" and myChar and part:IsDescendantOf(myChar) and not CollisionBypassTouchConns[part] then
        CollisionBypassTouchConns[part] = AddConn(part.Touched:Connect(function(hit)
            if not CollisionBypassActive or not hit or not hit.Parent then return end
            local otherChar = hit:FindFirstAncestorOfClass("Model")
            if not otherChar or otherChar == myChar then return end
            local humanoid = otherChar:FindFirstChildOfClass("Humanoid")
            local otherRoot = GetCharacterRoot(otherChar)
            local myRoot = GetCharacterRoot(myChar)
            if not humanoid or humanoid.Health <= 0 or not otherRoot or not myRoot then return end
            local offset = otherRoot.Position - myRoot.Position
            local flat = Vector3.new(offset.X, 0, offset.Z)
            if flat.Magnitude < 0.1 then
                flat = myRoot.CFrame.LookVector
            else
                flat = flat.Unit
            end
            pcall(function()
                otherRoot.AssemblyLinearVelocity = flat * 35 + Vector3.new(0, 10, 0)
            end)
        end))
    end
end

local function TrackCharacterParts(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        TrackCollisionPart(part)
    end
    if CollisionBypassCharConns[char] then
        pcall(function() CollisionBypassCharConns[char]:Disconnect() end)
        CollisionBypassCharConns[char] = nil
    end
    CollisionBypassCharConns[char] = AddConn(char.DescendantAdded:Connect(function(desc)
        TrackCollisionPart(desc)
    end))
end

local function ClearCollisionBypassCharConnections()
    for char, conn in pairs(CollisionBypassCharConns) do
        pcall(function() if conn then conn:Disconnect() end end)
        CollisionBypassCharConns[char] = nil
    end
end

local function ClearCollisionBypassPlayerConnections()
    for plr, connData in pairs(CollisionBypassPlayerConns) do
        if connData then
            pcall(function() if connData.added then connData.added:Disconnect() end end)
            pcall(function() if connData.removing then connData.removing:Disconnect() end end)
        end
        CollisionBypassPlayerConns[plr] = nil
    end
end

function SetCollisionBypass(on, mode)
    if Conns.CollisionBypassConn then Conns.CollisionBypassConn:Disconnect(); Conns.CollisionBypassConn = nil end
    if Conns.CollisionBypassCharDescConn then Conns.CollisionBypassCharDescConn:Disconnect(); Conns.CollisionBypassCharDescConn = nil end
    if Conns.CollisionBypassCharAddedConn then Conns.CollisionBypassCharAddedConn:Disconnect(); Conns.CollisionBypassCharAddedConn = nil end
    if Conns.CollisionBypassHeartbeat then Conns.CollisionBypassHeartbeat:Disconnect(); Conns.CollisionBypassHeartbeat = nil end
    ClearCollisionBypassCharConnections()
    ClearCollisionBypassPlayerConnections()
    DisconnectCollisionTouchConns()
    ReleaseNoCollideParts(CollisionBypassTouchedParts, "CollisionBypass")
    if on then
        CollisionBypassActive = true
        CollisionBypassMode = mode or "Bypass"

        local myChar = LocalPlayer.Character
        if myChar then
            TrackCharacterParts(myChar)
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                TrackCharacterParts(plr.Character)
            end
            local addedConn = AddConn(plr.CharacterAdded:Connect(function(newChar)
                TrackCharacterParts(newChar)
            end))
            local removingConn = AddConn(plr.CharacterRemoving:Connect(function(oldChar)
                local chConn = CollisionBypassCharConns[oldChar]
                if chConn then
                    pcall(function() chConn:Disconnect() end)
                    CollisionBypassCharConns[oldChar] = nil
                end
            end))
            CollisionBypassPlayerConns[plr] = {added = addedConn, removing = removingConn}
        end

        Conns.CollisionBypassCharAddedConn = AddConn(Players.PlayerAdded:Connect(function(plr)
            local addedConn = AddConn(plr.CharacterAdded:Connect(function(newChar)
                TrackCharacterParts(newChar)
            end))
            local removingConn = AddConn(plr.CharacterRemoving:Connect(function(oldChar)
                local chConn = CollisionBypassCharConns[oldChar]
                if chConn then
                    pcall(function() chConn:Disconnect() end)
                    CollisionBypassCharConns[oldChar] = nil
                end
            end))
            CollisionBypassPlayerConns[plr] = {added = addedConn, removing = removingConn}
        end))
        Conns.CollisionBypassCharDescConn = AddConn(Players.PlayerRemoving:Connect(function(plr)
            local data = CollisionBypassPlayerConns[plr]
            if data then
                pcall(function() if data.added then data.added:Disconnect() end end)
                pcall(function() if data.removing then data.removing:Disconnect() end end)
                CollisionBypassPlayerConns[plr] = nil
            end
        end))

        for npcChar in pairs(NPCCache) do
            if npcChar and npcChar.Parent then
                TrackCharacterParts(npcChar)
            end
        end
        for part in pairs(CollisionBypassTouchedParts) do
            if part and part.Parent and part:IsA("BasePart") then
                pcall(function()
                    part.CanCollide = false
                    if part.CanTouch ~= nil then
                        part.CanTouch = false
                    end
                    if part.CanQuery ~= nil then
                        part.CanQuery = false
                    end
                end)
            end
        end
        Conns.CollisionBypassHeartbeat = AddConn(RunService.Heartbeat:Connect(function()
            if not CollisionBypassActive then return end
            local myChar = LocalPlayer.Character
            if myChar then
                TrackCharacterParts(myChar)
            end
            for npcChar in pairs(NPCCache) do
                if npcChar and npcChar.Parent then
                    TrackCharacterParts(npcChar)
                end
            end
            for part in pairs(CollisionBypassTouchedParts) do
                if part and part.Parent and part:IsA("BasePart") then
                    pcall(function()
                        part.CanCollide = false
                        if part.CanTouch ~= nil then
                            part.CanTouch = false
                        end
                        if part.CanQuery ~= nil then
                            part.CanQuery = false
                        end
                    end)
                end
            end
        end))
    else
        CollisionBypassActive = false
        CollisionBypassMode = "Bypass"
        ReleaseNoCollideParts(CollisionBypassTouchedParts, "CollisionBypass")
        ClearCollisionBypassCharConnections()
        ClearCollisionBypassPlayerConnections()
        DisconnectCollisionTouchConns()
    end
end

-- [ FAKE LAG ]
do
local FakeLagState = {
    Active = false,
    RealCharacter = nil,
    LocalClone = nil,
    FreezeCFrame = nil,
    OriginalTransparencies = {},
    Marker = nil,
    Connections = {}
}

local function CleanupFakeLagVisuals()
    if FakeLagState.Marker then
        pcall(function() FakeLagState.Marker:Destroy() end)
        FakeLagState.Marker = nil
    end
end

local function ResetFakeLagReplication()
    pcall(function()
        settings().Network.IncomingReplicationLag = 0
    end)
end

function SetFakeLag(on)
    if not on then
        FakeLagState.Active = false
        Config.FakeLag = false

        for _, c in pairs(FakeLagState.Connections) do pcall(function() c:Disconnect() end) end
        table.clear(FakeLagState.Connections)
        
        local real = FakeLagState.RealCharacter
        
        CleanupFakeLagVisuals()
        
        if real then
            for part, transparency in pairs(FakeLagState.OriginalTransparencies) do
                if part and part.Parent then
                    pcall(function() part.Transparency = transparency end)
                end
            end
            table.clear(FakeLagState.OriginalTransparencies)
            
            local hrp = real:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function() hrp.Anchored = false end)
                pcall(function()
                    if sethiddenproperty then
                        sethiddenproperty(hrp, "NetworkIsSleeping", false)
                    end
                end)

                if Config.FakeLagMethod == "แช่แข็ง" then
                    if Config.FakeLagMode == "Current" then
                        -- Real character stays where player walked on their screen
                    elseif Config.FakeLagMode == "Back" and FakeLagState.FreezeCFrame then
                        pcall(function() real:PivotTo(FakeLagState.FreezeCFrame) end)
                    end
                else
                    -- Normal Mode (Desync)
                    local finalCFrame = FakeLagState.FreezeCFrame
                    if FakeLagState.LocalClone and FakeLagState.LocalClone:FindFirstChild("HumanoidRootPart") then
                        finalCFrame = FakeLagState.LocalClone.HumanoidRootPart.CFrame
                    end
                    if Config.FakeLagMode == "Current" then
                        pcall(function() real:PivotTo(finalCFrame) end)
                    else
                        if FakeLagState.FreezeCFrame then pcall(function() real:PivotTo(FakeLagState.FreezeCFrame) end) end
                    end
                end
            end
            
            LocalPlayer.Character = real
            workspace.CurrentCamera.CameraSubject = real:FindFirstChildOfClass("Humanoid")
        end

        if FakeLagState.LocalClone then
            FakeLagState.LocalClone:Destroy()
            FakeLagState.LocalClone = nil
        end

        ResetFakeLagReplication()
        
        FakeLagState.RealCharacter = nil
        FakeLagState.FreezeCFrame = nil
        return
    end

    if FakeLagState.Active then return end
    local realChar = LocalPlayer.Character
    local hrp = realChar and realChar:FindFirstChild("HumanoidRootPart")
    if not (realChar and hrp) then return end

    FakeLagState.Active = true
    FakeLagState.RealCharacter = realChar
    FakeLagState.FreezeCFrame = hrp.CFrame

    local ok, marker = pcall(function()
        realChar.Archivable = true
        local created = realChar:Clone()
        realChar.Archivable = false
        return created
    end)
    realChar.Archivable = false
    if ok and marker then
        FakeLagState.Marker = marker
        for _, obj in ipairs(marker:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("Script") then
                obj:Destroy()
            elseif obj:IsA("BasePart") then
                obj.CanCollide = false
                obj.Anchored = true
                obj.Material = Enum.Material.ForceField
                obj.Color = Color3.fromRGB(255, 50, 50)
                obj.Transparency = 0.4
            end
        end
        local hl = Instance.new("Highlight")
        hl.Name = "FakeLagHighlight"
        hl.FillColor = Color3.fromRGB(255, 0, 0)
        hl.FillTransparency = 0.7
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.1
        hl.Parent = marker
        marker.Parent = workspace
        marker:PivotTo(FakeLagState.FreezeCFrame)
    end

    if Config.FakeLagMethod == "แช่แข็ง" then
        pcall(function()
            settings().Network.IncomingReplicationLag = 999999
        end)

        local loop = RunService.Heartbeat:Connect(function()
            if not FakeLagState.Active then return end
            pcall(function()
                if sethiddenproperty and hrp then
                    sethiddenproperty(hrp, "NetworkIsSleeping", true)
                end
            end)
            pcall(function()
                settings().Network.IncomingReplicationLag = 999999
            end)
        end)
        table.insert(FakeLagState.Connections, loop)
    else
        -- Normal Fake Lag (Desync)
        realChar.Archivable = true
        local localClone = realChar:Clone()
        realChar.Archivable = false
        
        localClone.Name = realChar.Name .. "_Local"
        localClone.Parent = workspace
        FakeLagState.LocalClone = localClone
        
        table.clear(FakeLagState.OriginalTransparencies)
        for _, part in ipairs(realChar:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                FakeLagState.OriginalTransparencies[part] = part.Transparency
                part.Transparency = 1
            end
        end
        
        pcall(function() hrp.Anchored = true end)
        
        LocalPlayer.Character = localClone
        workspace.CurrentCamera.CameraSubject = localClone:FindFirstChildOfClass("Humanoid")
        
        local loop = RunService.Heartbeat:Connect(function()
            if not FakeLagState.Active then return end
            if FakeLagState.RealCharacter and hrp then
                hrp.CFrame = FakeLagState.FreezeCFrame
            end
        end)
        table.insert(FakeLagState.Connections, loop)
    end

    local rh = realChar:FindFirstChildOfClass("Humanoid")
    if rh then
        table.insert(FakeLagState.Connections, rh.Died:Connect(function() SetFakeLag(false) end))
    end
end
end

-- [ FREECAM ]
do
local FreecamState = {
    Active = false,
    CamPos = Vector3.new(),
    CamRotX = 0,
    CamRotY = 0,
    RenderConn = nil,
    InputConn = nil,
    AnchoredHRP = nil
}

local function StopFreecamInternal()
    if FreecamState.RenderConn then pcall(function() FreecamState.RenderConn:Disconnect() end); FreecamState.RenderConn = nil end
    if FreecamState.InputConn then pcall(function() FreecamState.InputConn:Disconnect() end); FreecamState.InputConn = nil end
    if FreecamState.AnchoredHRP and FreecamState.AnchoredHRP.Parent then
        pcall(function() FreecamState.AnchoredHRP.Anchored = false end)
    end
    FreecamState.AnchoredHRP = nil
    pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
    pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
    FreecamState.Active = false
end

function SetFreecam(on)
    if not on then
        StopFreecamInternal()
        return
    end
    if FreecamState.Active then return end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    FreecamState.Active = true
    if hrp then
        hrp.Anchored = true
        FreecamState.AnchoredHRP = hrp
    end
    FreecamState.CamPos = Camera.CFrame.Position
    local rx, ry = Camera.CFrame:ToEulerAnglesYXZ()
    FreecamState.CamRotX = rx
    FreecamState.CamRotY = ry

    Camera.CameraType = Enum.CameraType.Scriptable
    UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

    FreecamState.InputConn = UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            FreecamState.CamRotY = FreecamState.CamRotY - math.rad(input.Delta.X * 0.5)
            FreecamState.CamRotX = math.clamp(FreecamState.CamRotX - math.rad(input.Delta.Y * 0.5), -math.rad(89), math.rad(89))
        end
    end)

    FreecamState.RenderConn = RunService.RenderStepped:Connect(function(dt)
        if not FreecamState.Active then return end
        local moveDir = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Vector3.new(0, 0, -1) end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + Vector3.new(0, 0, 1) end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir + Vector3.new(-1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Vector3.new(1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir + Vector3.new(0, -1, 0) end
        local currentSpeed = UIS:IsKeyDown(Enum.KeyCode.LeftControl) and 6 or 2
        local rotation = CFrame.Angles(0, FreecamState.CamRotY, 0) * CFrame.Angles(FreecamState.CamRotX, 0, 0)
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit * currentSpeed * (dt * 60)
            FreecamState.CamPos = FreecamState.CamPos + (rotation * moveDir)
        end
        Camera.CFrame = CFrame.new(FreecamState.CamPos) * rotation
    end)
end
end

-- [ SHIFTLOCK AND CLICK-TP ]
do
Conns.ShiftLockConn = nil

function SetShiftLockActive(active)
    Config.ShiftLock_Active = active
    if active and Config.ShiftLock_Enabled then
        if Conns.ShiftLockConn then Conns.ShiftLockConn:Disconnect() end
        Conns.ShiftLockConn = AddConn(RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
                local camLook = Camera.CFrame.LookVector
                local targetRotation = math.atan2(-camLook.X, -camLook.Z)
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, targetRotation, 0)
                hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.new(1.75, 1.25, 0), 0.25)
            end
        end))
    else
        if Conns.ShiftLockConn then
            Conns.ShiftLockConn:Disconnect()
            Conns.ShiftLockConn = nil
        end
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.CameraOffset = Vector3.new(0, 0, 0)
            end
        end)
    end
end

function SetShiftLockEnabled(on)
    Config.ShiftLock_Enabled = on
    if not on then
        SetShiftLockActive(false)
    else
        local bindType, bindKey = Config.ShiftLock_BindType, Config.ShiftLock_BindKey
        if bindType == "Keyboard" and bindKey and UIS:IsKeyDown(bindKey) then
            SetShiftLockActive(true)
        elseif bindType == "Mouse" and bindKey then
            local mb = (bindKey == 1 and Enum.UserInputType.MouseButton1)
                or (bindKey == 2 and Enum.UserInputType.MouseButton2)
                or (bindKey == 3 and Enum.UserInputType.MouseButton3)
            if mb and UIS:IsMouseButtonPressed(mb) then
                SetShiftLockActive(true)
            end
        end
    end
end

UI.CurrentClickTPTween = nil
Conns.CurrentClickTPConnection = nil
Conns.CurrentClickTPWalking = false
local OriginalWalkSpeed = 16
local OriginalWSToggle = false

local function StartClickTPFly(char, hrp, hum, dest)
    local startPos = hrp.Position
    local dist = (dest - startPos).Magnitude
    local duration = dist / math.max(Config.ClickTP_Speed, 10)

    if Config.WSToggle then SetWalkSpeed(false) end

    StopCurrentClickTP()
    hrp.Anchored = true
    local targetCFrame = CFrame.new(dest) * (hrp.CFrame - hrp.CFrame.Position)

    local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, info, {CFrame = targetCFrame})
    UI.CurrentClickTPTween = tween

    local completedConn
    completedConn = tween.Completed:Connect(function()
        if completedConn == Conns.CurrentClickTPConnection then
            Conns.CurrentClickTPConnection = nil
        end
        hrp.Anchored = false
        UI.CurrentClickTPTween = nil
        pcall(function()
            if hum then hum.WalkSpeed = OriginalWalkSpeed end
            if OriginalWSToggle then SetWalkSpeed(true) end
        end)
    end)
    Conns.CurrentClickTPConnection = completedConn
    tween:Play()
end

local function CanWalkToDestination(startPos, dest)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 8,
        AgentMaxSlope = 45
    })
    local ok = pcall(function() path:ComputeAsync(startPos, dest) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then return false end
    local waypoints = path:GetWaypoints()
    if #waypoints < 2 then return false end
    return true
end

function StopCurrentClickTP()
    if UI.CurrentClickTPTween then
        UI.CurrentClickTPTween:Cancel()
        UI.CurrentClickTPTween = nil
    end
    if Conns.CurrentClickTPConnection then
        Conns.CurrentClickTPConnection:Disconnect()
        Conns.CurrentClickTPConnection = nil
    end
    Conns.CurrentClickTPWalking = false
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = OriginalWalkSpeed end
        if OriginalWSToggle then SetWalkSpeed(true) end
    end)
end

local function GetClickTPDestination(hitPos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = LocalPlayer.Character
    local filter = {char}
    params.FilterDescendantsInstances = filter
    
    local startPos = hitPos + Vector3.new(0, 20, 0)
    local direction = Vector3.new(0, -100, 0)
    local result = workspace:Raycast(startPos, direction, params)
    if result then
        return result.Position + Vector3.new(0, 3, 0)
    else
        return hitPos + Vector3.new(0, 3, 0)
    end
end

function ExecuteClickTP(hitPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    
    if not Conns.CurrentClickTPWalking and not UI.CurrentClickTPTween then
        OriginalWalkSpeed = hum.WalkSpeed
        OriginalWSToggle = Config.WSToggle
    end
    
    local mode = Config.ClickTP_Mode or "Teleport"
    if mode == "Teleport" then
        StopCurrentClickTP()
        local dest = GetClickTPDestination(hitPos)
        pcall(function() char:PivotTo(CFrame.new(dest)) end)
    elseif mode == "Fly" then
        local dest = GetClickTPDestination(hitPos)
        StartClickTPFly(char, hrp, hum, dest)
    elseif mode == "Walk" then
        local dest = GetClickTPDestination(hitPos)
        local shouldFlyInstead = not CanWalkToDestination(hrp.Position, dest)
        if shouldFlyInstead then
            StartClickTPFly(char, hrp, hum, dest)
            return
        end
        if Config.WSToggle then SetWalkSpeed(false) end
        
        StopCurrentClickTP()
        Conns.CurrentClickTPWalking = true
        
        local arrived = false
        local finishedEvent
        finishedEvent = hum.MoveToFinished:Connect(function(reached) arrived = true end)
        
        Conns.CurrentClickTPConnection = RunService.Stepped:Connect(function()
            local cChar = LocalPlayer.Character
            local cHrp = cChar and cChar:FindFirstChild("HumanoidRootPart")
            local cHum = cChar and cChar:FindFirstChildOfClass("Humanoid")
            
            if not cChar or not cHrp or not cHum or cHum.Health <= 0 or not Conns.CurrentClickTPWalking then
                if finishedEvent then finishedEvent:Disconnect() end
                StopCurrentClickTP()
                return
            end
            
            local dist = (dest - cHrp.Position).Magnitude
            if dist < 4 or arrived then
                if finishedEvent then finishedEvent:Disconnect() end
                StopCurrentClickTP()
                return
            end
            
            cHum.WalkSpeed = Config.ClickTP_Speed
            cHum:MoveTo(dest)
        end)
    end
end
end

LocalPlayer.CharacterAdded:Connect(function() 
    task.wait(0.7)
    FlyBG = nil; FlyBV = nil; FlyAtt = nil
    if Config.WSToggle then SetWalkSpeed(true) end
    if Config.JPToggle then SetJumpPower(true) end
    if Config.Noclip then SetNoclip(true) end
    if Config.InfJump then SetInfJump(true) end
    if Config.FlyToggle then SetFly(true) end
    if Config.InfZoom then SetInfZoom(true) end
    if Config.HipHeightToggle then SetHipHeight(true) end
    if Config.AntiStun then SetAntiStun(true) end
end)
AddConn(RunService.RenderStepped:Connect(function() Stats.frameCount = Stats.frameCount + 1 end))

-- [ SYSTEM REFRESH FOR KEYBINDS ]
function UpdateToggleUIFromKeybind(featureKey)
    local toggleInstance = Toggles[featureKey]
    if toggleInstance then
        pcall(function() toggleInstance:UpdateState(Config[featureKey]) end)
    end
end
local FeatureUIElements = {}
local InlineBindUIElements = {}

Window:GlobalSetting({
    Name = TL("Button GUI", "ปุ่มควบคุมหลัก"),
    Default = Config.ButtonGUI_Visible,
    Callback = function(State)
        Config.ButtonGUI_Visible = State
        for _, elem in ipairs(FeatureUIElements) do
            pcall(function() elem:SetVisibility(State) end)
        end
    end,
})

Window:GlobalSetting({
    Name = TL("Use Bind", "ปุ่มลัดย่อย"),
    Default = Config.GlobalUseBind,
    Callback = function(State)
        Config.GlobalUseBind = State
        for _, elem in ipairs(InlineBindUIElements) do
            pcall(function() elem:SetVisibility(State) end)
        end
    end,
})

local function WrapSection(section)
    local methods = {"Toggle", "Button", "Slider", "Dropdown", "Keybind", "Colorpicker", "Paragraph", "Header", "Divider", "Label", "SubLabel", "Spacer", "Input"}
    local originals = {}
    local unwrapped = {}
    for _, method in ipairs(methods) do
        originals[method] = section[method]
        unwrapped[method] = function(_, ...)
            return originals[method](section, ...)
        end
        section[method] = function(self, ...)
            local args = {...}
            if method == "Slider" and type(args[1]) == "table" then
                local settings = args[1]
                settings.DisplayMethod = "Percent"
                settings.Minimum = math.min(tonumber(settings.Minimum) or 1, 1)
                settings.Default = 1
                
                if settings.Precision == nil then
                    local minV = tonumber(settings.Minimum)
                    local maxV = tonumber(settings.Maximum)
                    if (minV and minV % 1 ~= 0) or (maxV and maxV % 1 ~= 0) then
                        settings.Precision = 2
                    end
                end
                
                local originalComplete = settings.onInputComplete
                local originalCallback = settings.Callback
                settings.Callback = function(value)
                    if originalCallback then
                        originalCallback(value)
                    end
                    if originalComplete then
                        originalComplete(value)
                    end
                settings.onInputComplete = nil
            end
            end
            local elem = originals[method](self, table.unpack(args))
            if elem then
                table.insert(FeatureUIElements, elem)
                pcall(function() elem:SetVisibility(Config.ButtonGUI_Visible) end)
            end
            return elem
        end
    end
    section.Unwrapped = unwrapped
    return section
end

-- [ TABS DESIGN SYSTEM ]
local TabGroup1, TabGroup2, TabGroup3
local TabAimlock, TabESP, TabPlayer, TabFling, TabGraphic, TabTP, TabServer

local function RebuildTabHandles()
    TabGroup1 = Window:TabGroup() -- Main Features
    TabGroup2 = Window:TabGroup() -- Player & Environment
    TabGroup3 = Window:TabGroup() -- Teleport & Utility

    TabAimlock = TabGroup1:Tab({ Name = TL("Aimlock", "เล็งเป้า") })
    TabESP = TabGroup1:Tab({ Name = TL("ESP Player", "ESP ผู้เล่น") })
    TabPlayer = TabGroup2:Tab({ Name = TL("Setting Player", "ตั้งค่าผู้เล่น") })
    TabFling = TabGroup2:Tab({ Name = TL("Fling", "ฟลิง") })
    TabGraphic = TabGroup2:Tab({ Name = TL("Graphic", "กราฟิก") })
    TabTP = TabGroup3:Tab({ Name = TL("Player Teleport", "วาร์ปผู้เล่น") })
    TabServer = TabGroup3:Tab({ Name = TL("Server Details", "ข้อมูลเซิร์ฟเวอร์") })
end

RebuildTabHandles()

local TargetModeNames = {"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"}
local LanguageUpdaters = {}
local LanguageDescConn = nil
local function RegisterLanguageUpdater(fn)
    table.insert(LanguageUpdaters, fn)
end
local function ApplyLanguageUI()
    for _, fn in ipairs(LanguageUpdaters) do
        pcall(fn)
    end
    pcall(ApplyLanguageToRawUI)
end
local function EnsureLanguageHooks()
    if LanguageDescConn then return end
    LanguageDescConn = AddConn(CoreGui.DescendantAdded:Connect(function(inst)
        if Config.Language ~= "TH" and Config.Language ~= "EN" then return end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
            pcall(function()
                inst.Text = TranslateUIRawText(inst.Text)
            end)
        end
    end))
end
local LocalizedFeatureNamesTH = {
    ["Enable Aimlock"] = "เปิดเล็งเป้า",
    ["Enemy Only"] = "เฉพาะศัตรู",
    ["Wall Check"] = "เช็กกำแพง",
    ["Enable Visuals"] = "เปิด ESP",
    ["View Distance Only"] = "แสดงระยะเท่านั้น",
    ["Show Names"] = "แสดงชื่อ",
    ["Show Health"] = "แสดงพลังชีวิต",
    ["Show Distance"] = "แสดงระยะทาง",
    ["Highlight Glow"] = "ไฮไลต์เรืองแสง",
    ["Team Color"] = "สีทีม",
    ["Ignore Team"] = "ไม่สนทีม",
    ["X-Ray Mode"] = "โหมดเอ็กซเรย์",
    ["Hitbox Expander"] = "ขยายฮิตบ็อกซ์",
    ["Super Walk"] = "เดินไว",
    ["Super Jump"] = "กระโดดสูง",
    ["Infinite Jump"] = "กระโดดไม่จำกัด",
    ["Fly Mode"] = "โหมดบิน",
    ["No Clip"] = "ทะลุวัตถุ",
    ["Invisibility"] = "ล่องหน",
    ["Max Zoom"] = "ซูมไกลสุด",
    ["Hip Height"] = "ความสูงตัวละคร",
    ["Custom Field of View"] = "กำหนดมุมมองเอง",
    ["Fullbright"] = "สว่างสุด",
    ["Disable Fog"] = "ปิดหมอก",
    ["Fast Interact"] = "โต้ตอบไว",
    ["Interaction Aura"] = "ออร่าโต้ตอบ",
    ["Anti-AFK"] = "กัน AFK",
    ["Anti Stun"] = "กันสตัน",
    ["Shift Lock"] = "ล็อกไหล่",
    ["Collision Bypass"] = "ทะลุชน",
    ["Fake Lag"] = "เฟคลาก",
    ["Freecam"] = "กล้องอิสระ",
    ["FPS Booster"] = "เร่ง FPS",
    ["Show Activity HUD"] = "แสดง HUD",
    ["Change Sky"] = "เปลี่ยนท้องฟ้า",
    ["Activate System"] = "เปิดระบบ",
    ["Enable Eye"] = "เปิดมุมมอง",
    ["Click TP"] = "คลิกวาร์ป"
}
local function LocalizeFeatureName(name)
    if Config.Language == "TH" then
        return LocalizedFeatureNamesTH[name] or name
    end
    return name
end

local function ParseBoundInput(bind)
    local bindText = tostring(bind)
    if type(bind) == "string" then
        if bind:find("MouseButton1") then return "Mouse", 1, "MouseButton1" end
        if bind:find("MouseButton2") then return "Mouse", 2, "MouseButton2" end
        if bind:find("MouseButton3") then return "Mouse", 3, "MouseButton3" end
        local keyName = bind:gsub("^Enum%.KeyCode%.", "")
        local enumKey = Enum.KeyCode[keyName]
        if enumKey then
            return "Keyboard", enumKey, keyName
        end
        return "Keyboard", bind, bind
    end
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.UserInputType then
            if bind == Enum.UserInputType.MouseButton1 then return "Mouse", 1, "MouseButton1" end
            if bind == Enum.UserInputType.MouseButton2 then return "Mouse", 2, "MouseButton2" end
            if bind == Enum.UserInputType.MouseButton3 then return "Mouse", 3, "MouseButton3" end
        elseif bind.EnumType == Enum.KeyCode then
            return "Keyboard", bind, bind.Name
        end
    end
    if bindText:find("MouseButton1") then return "Mouse", 1, "MouseButton1" end
    if bindText:find("MouseButton2") then return "Mouse", 2, "MouseButton2" end
    if bindText:find("MouseButton3") then return "Mouse", 3, "MouseButton3" end
    return "Keyboard", bind, (typeof(bind) == "EnumItem" and bind.Name) or bindText
end

local function NormalizeKeybindData()
    if not Config or not Config.Keybinds then return end
    for _, bindInfo in pairs(Config.Keybinds) do
        if bindInfo then
            if bindInfo.Mode == "กดค้าง" then
                bindInfo.Mode = "Hold"
            elseif bindInfo.Mode == "สลับ" then
                bindInfo.Mode = "Toggle"
            elseif bindInfo.Mode ~= "Hold" and bindInfo.Mode ~= "Toggle" then
                bindInfo.Mode = "Toggle"
            end

            if bindInfo.Type == "เมาส์" then
                bindInfo.Type = "Mouse"
            elseif bindInfo.Type == "คีย์บอร์ด" then
                bindInfo.Type = "Keyboard"
            end

            if bindInfo.Type == "Keyboard" and type(bindInfo.Key) == "string" then
                local keyName = bindInfo.Key:gsub("^Enum%.KeyCode%.", "")
                local enumKey = Enum.KeyCode[keyName]
                if enumKey then
                    bindInfo.Key = enumKey
                end
            end
        end
    end

    local function normalizeGlobalKey(typeField, keyField)
        if Config[typeField] == "Keyboard" and type(Config[keyField]) == "string" then
            local keyName = Config[keyField]:gsub("^Enum%.KeyCode%.", "")
            local enumKey = Enum.KeyCode[keyName]
            if enumKey then
                Config[keyField] = enumKey
            end
        end
    end
    normalizeGlobalKey("MenuToggleBindType", "MenuToggleBindKey")
    normalizeGlobalKey("ShiftLock_BindType", "ShiftLock_BindKey")
    normalizeGlobalKey("ClickTPBindType", "ClickTPBindKey")
    if Config.BindType == "Keyboard" and type(Config.BindKey) == "string" then
        local keyName = Config.BindKey:gsub("^Enum%.KeyCode%.", "")
        local enumKey = Enum.KeyCode[keyName]
        if enumKey then
            Config.BindKey = enumKey
        end
    end
end

local function AddInlineFeatureBind(section, featureName, featureKey, defaultKey)
    if not Config.Keybinds[featureKey] then
        Config.Keybinds[featureKey] = {Type = nil, Key = nil, Enabled = false, Mode = "Toggle"}
    end
    local kb = Config.Keybinds[featureKey]
    local u_section = section.Unwrapped or section

    local shownFeatureName = LocalizeFeatureName(featureName)
    local bindToggle = u_section.Toggle(section, {
        Name = TL("Use Bind • ", "ใช้ปุ่มลัด • ") .. shownFeatureName,
        Default = kb.Enabled,
        Callback = function(v)
            kb.Enabled = v
        end
    })
    local bindMode = u_section.Dropdown(section, {
        Name = TL("Mode • ", "โหมด • ") .. shownFeatureName,
        Multi = false,
        Required = true,
        Options = Config.Language == "TH" and {"สลับ (Toggle)", "กดค้าง (Hold)"} or {"Toggle", "Hold"},
        Default = kb.Mode == "Hold" and 2 or 1,
        Callback = function(v)
            if v == "สลับ" or v == "สลับ (Toggle)" then
                kb.Mode = "Toggle"
            elseif v == "กดค้าง" or v == "กดค้าง (Hold)" then
                kb.Mode = "Hold"
            else
                kb.Mode = v
            end
        end
    })

    local bindKey = u_section.Keybind(section, {
        Name = TL("Key • ", "ปุ่ม • ") .. shownFeatureName,
        Default = kb.Key,
        Callback = function() end,
        onBinded = function(bind)
            local bindType, bindKey, bindName = ParseBoundInput(bind)
            kb.Type = bindType
            kb.Key = bindKey
            kb.Enabled = true
            ShowToast(TL("Set key for ", "ตั้งปุ่มให้ ") .. shownFeatureName .. " : " .. bindName, Colors.PrimaryBlue)
        end
    })
    RegisterLanguageUpdater(function()
        local localizedFeatureName = LocalizeFeatureName(featureName)
        pcall(function() bindToggle:UpdateName(TL("Use Bind • ", "ใช้ปุ่มลัด • ") .. localizedFeatureName) end)
        pcall(function() bindMode:UpdateName(TL("Mode • ", "โหมด • ") .. localizedFeatureName) end)
        pcall(function() bindMode:ClearOptions() end)
        pcall(function()
            if Config.Language == "TH" then
                bindMode:InsertOptions({"สลับ (Toggle)", "กดค้าง (Hold)"})
                bindMode:UpdateSelection((kb.Mode == "Hold") and "กดค้าง (Hold)" or "สลับ (Toggle)")
            else
                bindMode:InsertOptions({"Toggle", "Hold"})
                bindMode:UpdateSelection((kb.Mode == "Hold") and "Hold" or "Toggle")
            end
        end)
        pcall(function() bindKey:UpdateName(TL("Key • ", "ปุ่ม • ") .. localizedFeatureName) end)
    end)
    local spacer = u_section.Spacer(section)
    
    if bindToggle then
        table.insert(InlineBindUIElements, bindToggle)
        pcall(function() bindToggle:SetVisibility(Config.GlobalUseBind) end)
    end
    if bindMode then
        table.insert(InlineBindUIElements, bindMode)
        pcall(function() bindMode:SetVisibility(Config.GlobalUseBind) end)
    end
    if bindKey then
        table.insert(InlineBindUIElements, bindKey)
        pcall(function() bindKey:SetVisibility(Config.GlobalUseBind) end)
    end
    if spacer then
        table.insert(InlineBindUIElements, spacer)
        pcall(function() spacer:SetVisibility(Config.GlobalUseBind) end)
    end
end

local function ApplySliderStep(value, minValue, maxValue, allowDecimal)
    local function NormalizeSliderStepValue()
        local raw = Config.SliderStep
        if type(raw) == "number" then
            if raw < 1 then raw = 1 end
            Config.SliderStep = raw
            return raw
        end
        local txt = tostring(raw or "1")
        local n = tonumber((txt:gsub("[^%d]", "")))
        if not n or n < 1 then n = 1 end
        Config.SliderStep = n
        return n
    end
    local v = tonumber(value) or minValue
    local minV = tonumber(minValue) or v
    local maxV = tonumber(maxValue) or v
    if allowDecimal then
        if v < minV then v = minV end
        if v > maxV then v = maxV end
        return v
    end
    local step = NormalizeSliderStepValue()
    if step < 1 then step = 1 end
    local snapped = math.floor((v / step) + 0.5) * step
    if snapped < minV then snapped = minV end
    if snapped > maxV then snapped = maxV end
    return snapped
end

function BuildAllTabs()
    -- AIMLOCK TAB
    local Section_AimAssistL = WrapSection(TabAimlock:Section({ Side = "Left" }))
    local Section_AimAssistR = WrapSection(TabAimlock:Section({ Side = "Right" }))
    Section_AimAssistL:Header({ Name = TL("Aim Assist", "ช่วยเล็ง") })
    Section_AimAssistL:SubLabel({ Text = TL("Main controls and key input", "ค่าหลักและคีย์กด") })
    Section_AimAssistL:Divider()
    Section_AimAssistR:Header({ Name = TL("Target", "เป้าหมาย") })
    Section_AimAssistR:SubLabel({ Text = TL("Accuracy and target part", "ความแม่นยำและส่วนเป้า") })
    Section_AimAssistR:Divider()
    
    Toggles["Aimlock"] = Section_AimAssistL:Toggle({
        Name = TL("Enable Aimlock", "เปิดใช้งานเล็งเป้า"),
        Default = Config.Aimlock,
        Callback = function(v)
            Config.Aimlock = v
            if not v then LockedTarget = nil; State.ToggleAiming = false end
        end
    })
    AddInlineFeatureBind(Section_AimAssistL, "Enable Aimlock", "Aimlock", Enum.KeyCode.Q)

    Section_AimAssistL:Dropdown({
        Name = TL("Aim Mode", "โหมดเล็ง"),
        Multi = false,
        Required = true,
        Options = {"TOGGLE", "HOLD", "ALWAYS ON"},
        Default = table.find({"TOGGLE", "HOLD", "ALWAYS ON"}, Config.AimMode) or 1,
        Callback = function(v) Config.AimMode = v end
    })

    Section_AimAssistR:Dropdown({
        Name = "เป้าหมาย:",
        Multi = false,
        Required = true,
        Options = TargetModeNames,
        Default = Config.TargetMode,
        Callback = function(v)
            local idx = table.find(TargetModeNames, v) or 1
            Config.TargetMode = idx
            LockedTarget = nil
            ValidTargets = {}
        end
    })

    Toggles["EnemyOnly"] = Section_AimAssistR:Toggle({
        Name = TL("Enemy Only", "เฉพาะศัตรู"),
        Default = Config.EnemyOnly,
        Callback = function(v) Config.EnemyOnly = v end
    })

    Section_AimAssistL:Keybind({
        Name = TL("Aim Keybind", "ปุ่มลัดเล็ง"),
        Default = Config.BindKey,
        Callback = function() end,
        onBinded = function(bind)
            local bindType, bindKey = ParseBoundInput(bind)
            Config.BindType = bindType
            Config.BindKey = bindKey
        end
    })

    Section_AimAssistR:Slider({
        Name = TL("FOV Radius", "รัศมี FOV"),
        Default = Config.FOV,
        Minimum = 1,
        Maximum = 200,
        DisplayMethod = "Value",
        Callback = function(v) Config.FOV = ApplySliderStep(v, 1, 200, false) end
    })

    Section_AimAssistL:Slider({
        Name = TL("Smoothing", "ความลื่นไหล"),
        Default = Config.AimSmooth,
        Minimum = 0.01,
        Maximum = 1,
        DisplayMethod = "Value",
        Precision = 2,
        Callback = function(v) Config.AimSmooth = ApplySliderStep(v, 0.01, 1, true) end
    })

    Section_AimAssistR:Colorpicker({
        Name = TL("FOV Color", "สี FOV"),
        Default = Config.FOVColor_C3,
        Alpha = nil,
        Callback = function(color, alpha)
            if typeof(color) == "Color3" then
                Config.FOVColor_C3 = color
                if UI.Circle then
                    UI.Circle.Color = color
                end
            end
        end
    }, "FOVColorToggle")

    Section_AimAssistR:Dropdown({
        Name = TL("FOV Show Mode", "โหมดแสดง FOV"),
        Multi = false,
        Required = true,
        Options = {"Always", "On Aiming"},
        Default = table.find({"Always", "On Aiming"}, Config.FOVShowMode) or 1,
        Callback = function(v) Config.FOVShowMode = v end
    })

    Toggles["WallCheck"] = Section_AimAssistR:Toggle({
        Name = TL("Wall Check", "เช็กกำแพง"),
        Default = Config.WallCheck,
        Callback = function(v) Config.WallCheck = v end
    })

    Section_AimAssistR:Dropdown({
        Name = TL("Target Part", "ส่วนเป้า"),
        Multi = false,
        Required = true,
        Options = {"Head", "Torso", "HumanoidRootPart", "Auto"},
        Default = table.find({"Head", "Torso", "HumanoidRootPart", "Auto"}, Config.AimTargetPart) or 1,
        Callback = function(v) Config.AimTargetPart = v end
    })
    AddInlineFeatureBind(Section_AimAssistR, "Enemy Only", "EnemyOnly", Enum.KeyCode.E)
    AddInlineFeatureBind(Section_AimAssistR, "Wall Check", "WallCheck", Enum.KeyCode.R)
    Section_AimAssistR:Spacer()

    -- ESP PLAYER TAB
    local Section_ESPVisuals = WrapSection(TabESP:Section({ Side = "Left" }))
    local Section_ESPVisualsR = WrapSection(TabESP:Section({ Side = "Right" }))
    local Section_Customization = WrapSection(TabESP:Section({ Side = "Right" }))
    local Section_Hitbox = WrapSection(TabESP:Section({ Side = "Left" }))
    Section_ESPVisuals:Header({ Name = TL("ESP Visuals", "การแสดงผล ESP") })
    Section_ESPVisualsR:Header({ Name = TL("ESP Visuals (More)", "การแสดงผล ESP (เพิ่มเติม)") })
    Section_Customization:Header({ Name = TL("Customization", "การปรับแต่ง") })
    Section_Hitbox:Header({ Name = TL("Hitbox Expansion", "ขยายฮิตบ็อกซ์") })

    Toggles["P_Master"] = Section_ESPVisuals:Toggle({
        Name = TL("Enable Visuals", "เปิดการแสดงผล"),
        Default = Config.P_Master,
        Callback = function(v) Config.P_Master = v end
    })
    AddInlineFeatureBind(Section_ESPVisuals, "Enable Visuals", "P_Master", Enum.KeyCode.Z)

    Section_ESPVisuals:Dropdown({
        Name = TL("Target Mode", "โหมดเป้าหมาย"),
        Multi = false,
        Required = true,
        Options = {"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"},
        Default = table.find({"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"}, Config.P_TargetMode) or 1,
        Callback = function(v) Config.P_TargetMode = v end
    })

    Toggles["P_ESPInFOVOnly"] = Section_ESPVisuals:Toggle({
        Name = TL("View Distance Only", "แสดงเฉพาะระยะ"),
        Default = Config.P_ESPInFOVOnly,
        Callback = function(v) Config.P_ESPInFOVOnly = v end
    })
    AddInlineFeatureBind(Section_ESPVisuals, "View Distance Only", "P_ESPInFOVOnly", Enum.KeyCode.F1)

    Toggles["P_ShowName"] = Section_ESPVisuals:Toggle({
        Name = TL("Show Names", "แสดงชื่อ"),
        Default = Config.P_ShowName,
        Callback = function(v) Config.P_ShowName = v end
    })
    AddInlineFeatureBind(Section_ESPVisuals, "Show Names", "P_ShowName", Enum.KeyCode.F2)

    Toggles["P_ShowHealth"] = Section_ESPVisuals:Toggle({
        Name = TL("Show Health", "แสดงเลือด"),
        Default = Config.P_ShowHealth,
        Callback = function(v) Config.P_ShowHealth = v end
    })
    AddInlineFeatureBind(Section_ESPVisuals, "Show Health", "P_ShowHealth", Enum.KeyCode.F3)

    Toggles["P_ShowDist"] = Section_ESPVisualsR:Toggle({
        Name = TL("Show Distance", "แสดงระยะ"),
        Default = Config.P_ShowDist,
        Callback = function(v) Config.P_ShowDist = v end
    })
    AddInlineFeatureBind(Section_ESPVisualsR, "Show Distance", "P_ShowDist", Enum.KeyCode.F4)

    Toggles["P_Highlight"] = Section_ESPVisualsR:Toggle({
        Name = TL("Highlight Glow", "ไฮไลต์เรืองแสง"),
        Default = Config.P_Highlight,
        Callback = function(v) Config.P_Highlight = v end
    })
    AddInlineFeatureBind(Section_ESPVisualsR, "Highlight Glow", "P_Highlight", Enum.KeyCode.F5)

    Toggles["P_TeamColor"] = Section_ESPVisualsR:Toggle({
        Name = TL("Team Color", "สีทีม"),
        Default = Config.P_TeamColor,
        Callback = function(v) Config.P_TeamColor = v end
    })
    AddInlineFeatureBind(Section_ESPVisualsR, "Team Color", "P_TeamColor", Enum.KeyCode.F6)

    Toggles["P_TeamCheck"] = Section_ESPVisualsR:Toggle({
        Name = TL("Ignore Team", "ไม่สนทีม"),
        Default = Config.P_TeamCheck,
        Callback = function(v) Config.P_TeamCheck = v end
    })
    AddInlineFeatureBind(Section_ESPVisualsR, "Ignore Team", "P_TeamCheck", Enum.KeyCode.F7)

    Toggles["P_Xray"] = Section_ESPVisualsR:Toggle({
        Name = TL("X-Ray Mode", "โหมดเอ็กซเรย์"),
        Default = Config.P_Xray,
        Callback = function(v) Config.P_Xray = v; UpdateXray(XrayCache_P, v) end
    })
    AddInlineFeatureBind(Section_ESPVisualsR, "X-Ray Mode", "P_Xray", Enum.KeyCode.F8)

    Section_Customization:Colorpicker({
        Name = TL("Primary Color", "สีหลัก"),
        Default = Config.P_Color_C3,
        Alpha = nil,
        Callback = function(color, alpha)
            if typeof(color) == "Color3" then
                Config.P_Color_C3 = color
            end
        end
    }, "ESPColorToggle")

    Section_Customization:Slider({
        Name = TL("Text Size", "ขนาดตัวอักษร"),
        Default = Config.P_TextSize,
        Minimum = 8,
        Maximum = 30,
        DisplayMethod = "Value",
        Callback = function(v) Config.P_TextSize = ApplySliderStep(v, 8, 30, false) end
    })

    Section_Customization:Slider({
        Name = TL("Fill Opacity", "ความทึบพื้น"),
        Default = Config.P_FillTrans,
        Minimum = 0,
        Maximum = 1,
        DisplayMethod = "Value",
        Precision = 2,
        Callback = function(v) Config.P_FillTrans = ApplySliderStep(v, 0, 1, true) end
    })

    Section_Customization:Slider({
        Name = TL("Outline Opacity", "ความทึบเส้นขอบ"),
        Default = Config.P_OutlineTrans,
        Minimum = 0,
        Maximum = 1,
        DisplayMethod = "Value",
        Precision = 2,
        Callback = function(v) Config.P_OutlineTrans = ApplySliderStep(v, 0, 1, true) end
    })
    Section_Customization:Spacer()

    Toggles["P_HitboxToggle"] = Section_Hitbox:Toggle({
        Name = TL("Enable Hitbox", "เปิดฮิตบ็อกซ์"),
        Default = Config.P_HitboxToggle,
        Callback = function(v)
            Config.P_HitboxToggle = v
            if not v then
                for char, sz in pairs(HitboxOriginalSizes) do
                    pcall(function()
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.Size = sz; hrp.Transparency = 1; hrp.Material = Enum.Material.SmoothPlastic; hrp.CanCollide = true end
                    end)
                end
                HitboxOriginalSizes = {}
            end
        end
    })

    Section_Hitbox:Dropdown({
        Name = TL("Target Selection", "การเลือกเป้าหมาย"),
        Multi = false,
        Required = true,
        Options = {"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"},
        Default = table.find({"PLAYERS ONLY", "NPCs ONLY", "PLAYERS & NPCs"}, Config.HitboxTargetMode) or 1,
        Callback = function(v) Config.HitboxTargetMode = v end
    })

    Section_Hitbox:Slider({
        Name = TL("Expansion Size", "ขนาดการขยาย"),
        Default = Config.P_HitboxSize,
        Minimum = 4,
        Maximum = 200,
        DisplayMethod = "Value",
        Callback = function(v) Config.P_HitboxSize = ApplySliderStep(v, 4, 200, false) end
    })

    -- SETTING PLAYER TAB
    local Section_PlayerTop = WrapSection(TabPlayer:Section({ Side = "Left" }))
    Section_PlayerTop:Header({ Name = TL("Player Actions", "การจัดการผู้เล่น") })
    Section_PlayerTop:Button({
        Name = TL("Respawn", "รีเซ็ตตัวละคร"),
        Callback = function()
            local char = LocalPlayer and LocalPlayer.Character
            pcall(function()
                if char and char.Parent then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.Health = 0
                    else
                        char:BreakJoints()
                    end
                end
            end)
            task.delay(0.5, function()
                pcall(function() LocalPlayer:LoadCharacter() end)
            end)
        end
    })
    Section_PlayerTop:Button({
        Name = TL("Leave", "ออกจากแมพ"),
        Callback = function()
            pcall(function() LocalPlayer:Kick("") end)
        end
    })

    local Section_Animations = WrapSection(TabPlayer:Section({ Side = "Left" }))
    local Section_Movement = WrapSection(TabPlayer:Section({ Side = "Left" }))
    local Section_VisualEnv = WrapSection(TabPlayer:Section({ Side = "Left" }))
    local Section_WindowControls = WrapSection(TabPlayer:Section({ Side = "Right" }))
    local Section_Lighting = WrapSection(TabPlayer:Section({ Side = "Right" }))
    local Section_Interactions = WrapSection(TabPlayer:Section({ Side = "Right" }))
    local Section_FakeLag = WrapSection(TabPlayer:Section({ Side = "Left" }))
    local Section_Optimization = WrapSection(TabPlayer:Section({ Side = "Right" }))
    local Section_InterfaceInfo = WrapSection(TabPlayer:Section({ Side = "Right" }))
    Section_Movement:Header({ Name = TL("Movement", "การเคลื่อนไหว") })
    Section_VisualEnv:Header({ Name = TL("Visual Environment", "ภาพแวดล้อม") })
    Section_Lighting:Header({ Name = TL("Lighting", "แสงสว่าง") })
    Section_Interactions:Header({ Name = TL("Interactions", "การโต้ตอบ") })
    Section_FakeLag:Header({ Name = TL("Fake Lag", "เฟคลาก") })
    Section_Optimization:Header({ Name = TL("Optimization", "เพิ่มประสิทธิภาพ") })
    Section_InterfaceInfo:Header({ Name = TL("Interface Info", "ข้อมูลหน้าจอ") })

    -- Animations
    Section_Animations:Header({ Name = TL("Animations", "แอนิเมชัน") })
    Section_Animations:Button({
        Name = TL("Open Emote Menu", "เปิดเมนูอีโมต"),
        Callback = function()
            if State.EmoteMenuLoaded then
                Config.EmoteMenuOpen = true
                Window:Notify({ Title = TL("Info", "ข้อมูล"), Description = TL("Emote Menu is already enabled permanently for this session.", "เมนูอีโมตถูกเปิดถาวรสำหรับรอบนี้แล้ว"), Lifetime = 3 })
                return
            end
            ShowConfirm(
                TL("Enable Emote Menu", "เปิดเมนูอีโมต"),
                TL("This action is permanent for this session and cannot be turned off. Continue?", "การทำงานนี้จะเปิดถาวรในรอบนี้และปิดไม่ได้ ต้องการดำเนินการต่อหรือไม่?"),
                function()
                    local ok = pcall(function()
                        loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))()
                    end)
                    if ok then
                        State.EmoteMenuLoaded = true
                        Config.EmoteMenuOpen = true
                        Window:Notify({ Title = TL("Enabled", "เปิดแล้ว"), Description = TL("Emote Menu is now permanently enabled for this session.", "เมนูอีโมตเปิดถาวรสำหรับรอบนี้แล้ว"), Lifetime = 3 })
                    else
                        Window:Notify({ Title = TL("Error", "ข้อผิดพลาด"), Description = TL("Failed to load Emote Menu.", "โหลดเมนูอีโมตไม่สำเร็จ"), Lifetime = 4 })
                    end
                end
            )
        end
    })

    Section_WindowControls:Header({ Name = TL("Window Controls", "ควบคุมหน้าต่าง") })
    Section_WindowControls:SubLabel({ Text = TL("Set menu key and language", "ตั้งปุ่มเมนูและภาษา") })
    Section_WindowControls:Keybind({
        Name = TL("Menu Toggle Key", "ปุ่มเปิด/ปิดเมนู"),
        Default = Config.MenuToggleBindKey,
        Callback = function() end,
        onBinded = function(bind)
            local bindType, bindKey = ParseBoundInput(bind)
            Config.MenuToggleBindType = bindType
            Config.MenuToggleBindKey = bindKey
        end
    })

    AddInlineFeatureBind(Section_Hitbox, "Hitbox Expander", "P_HitboxToggle", Enum.KeyCode.X)
    local LanguageDropdown = Section_WindowControls:Dropdown({
        Name = TL("Language", "ภาษา"),
        Multi = false,
        Required = true,
        Options = {"England", "Thailand"},
        Default = (Config.Language == "TH") and 2 or 1,
        Callback = function(v)
            local selected = (v == "Thailand") and "TH" or "EN"
            if Config.Language ~= selected then
                Config.Language = selected
                ApplyLanguageUI()
            end
        end
    })
    RegisterLanguageUpdater(function()
        pcall(function() LanguageDropdown:UpdateName(TL("Language", "ภาษา")) end)
    end)
    Section_WindowControls:Divider()
    
    Section_WindowControls:Button({
        Name = TL("🛑 Unload Script Safely", "🛑 ปิดสคริปต์อย่างปลอดภัย"),
        Callback = function()
            ShowConfirm(
                TL("Confirm Unload", "ยืนยันการปิดระบบ"),
                TL("Are you sure you want to close the menu and stop all features?", "ต้องการยกเลิกฟังก์ชันและปิดหน้าจอสคริปต์ทั้งหมดหรือไม่?"),
                function()
                FullUnload()
            end)
        end
    })

    -- Movement
    Toggles["WSToggle"] = Section_Movement:Toggle({
        Name = TL("Super Walk", "เดินไว"),
        Default = Config.WSToggle,
        Callback = function(v) SetWalkSpeed(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Super Walk", "WSToggle", Enum.KeyCode.LeftShift)

    Section_Movement:Slider({
        Name = TL("Speed Value", "ค่าความเร็ว"),
        Default = Config.WalkSpeed,
        Minimum = 16,
        Maximum = 1000,
        DisplayMethod = "Value",
        Callback = function(v) Config.WalkSpeed = ApplySliderStep(v, 16, 1000, false); if Config.WSToggle then SetWalkSpeed(true) end end
    })

    Toggles["JPToggle"] = Section_Movement:Toggle({
        Name = TL("Super Jump", "กระโดดสูง"),
        Default = Config.JPToggle,
        Callback = function(v) SetJumpPower(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Super Jump", "JPToggle", Enum.KeyCode.Space)

    Section_Movement:Slider({
        Name = TL("Jump Value", "ค่าแรงกระโดด"),
        Default = Config.JumpPower,
        Minimum = 10,
        Maximum = 1000,
        DisplayMethod = "Value",
        Callback = function(v) Config.JumpPower = ApplySliderStep(v, 10, 1000, false); if Config.JPToggle then SetJumpPower(true) end end
    })

    Toggles["InfJump"] = Section_Movement:Toggle({
        Name = TL("Infinite Jump", "กระโดดไม่จำกัด"),
        Default = Config.InfJump,
        Callback = function(v) SetInfJump(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Infinite Jump", "InfJump", Enum.KeyCode.V)

    Toggles["FlyToggle"] = Section_Movement:Toggle({
        Name = TL("Fly Mode", "โหมดบิน"),
        Default = Config.FlyToggle,
        Callback = function(v) SetFly(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Fly Mode", "FlyToggle", Enum.KeyCode.F)

    Toggles["FlyNoclip"] = Section_Movement:Toggle({
        Name = TL("Fly Noclip", "บินทะลุวัตถุ"),
        Default = Config.FlyNoclip,
        Callback = function(v) Config.FlyNoclip = v; UpdateFlyNoclip() end
    })

    Section_Movement:Slider({
        Name = TL("Flying Speed", "ความเร็วบิน"),
        Default = Config.FlySpeed,
        Minimum = 5,
        Maximum = 500,
        DisplayMethod = "Value",
        Callback = function(v) Config.FlySpeed = ApplySliderStep(v, 5, 500, false) end
    })

    Toggles["Noclip"] = Section_Movement:Toggle({
        Name = TL("No Clip", "ทะลุวัตถุ"),
        Default = Config.Noclip,
        Callback = function(v) SetNoclip(v) end
    })
    AddInlineFeatureBind(Section_Movement, "No Clip", "Noclip", Enum.KeyCode.N)

    Toggles["InvisToggle"] = Section_Movement:Toggle({
        Name = TL("Invisibility", "ล่องหน"),
        Default = Config.InvisToggle,
        Callback = function(v) SetInvisibility(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Invisibility", "InvisToggle", Enum.KeyCode.I)

    Toggles["InfZoom"] = Section_Movement:Toggle({
        Name = TL("Max Zoom", "ซูมไกลสุด"),
        Default = Config.InfZoom,
        Callback = function(v) SetInfZoom(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Max Zoom", "InfZoom", Enum.KeyCode.M)

    Toggles["ZoomNoclip"] = Section_Movement:Toggle({
        Name = TL("Zoom NoClip", "ซูมทะลุวัตถุ"),
        Default = Config.ZoomNoclip,
        Callback = function(v) 
            Config.ZoomNoclip = v
            if v then
                pcall(function() LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam end)
            else
                pcall(function() LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom end)
            end
        end
    })

    Toggles["HipHeightToggle"] = Section_Movement:Toggle({
        Name = TL("Hip Height", "ความสูงตัวละคร"),
        Default = Config.HipHeightToggle,
        Callback = function(v) SetHipHeight(v) end
    })
    AddInlineFeatureBind(Section_Movement, "Hip Height", "HipHeightToggle", Enum.KeyCode.PageUp)

    Section_Movement:Slider({
        Name = TL("Height Level", "ระดับความสูง"),
        Default = Config.HipHeightValue,
        Minimum = -100,
        Maximum = 1000,
        DisplayMethod = "Value",
        Callback = function(v) Config.HipHeightValue = ApplySliderStep(v, -100, 1000, false) end,
        onInputComplete = function(v) SetHipHeightValue(ApplySliderStep(v, -100, 1000, false)) end
    })
    Section_Movement:Divider()

    -- Visual Environment
    Toggles["FOVToggle"] = Section_VisualEnv:Toggle({
        Name = TL("Custom Field of View", "กำหนดมุมมองเอง"),
        Default = Config.FOVToggle,
        Callback = function(v)
            if v then pcall(function() workspace.CurrentCamera.FieldOfView = Config.FOVView end)
            else pcall(function() workspace.CurrentCamera.FieldOfView = 70 end) end
        end
    })
    AddInlineFeatureBind(Section_VisualEnv, "Custom Field of View", "FOVToggle", Enum.KeyCode.P)

    Section_VisualEnv:Slider({
        Name = TL("FOV Value", "ค่ามุมมอง"),
        Default = Config.FOVView,
        Minimum = 30,
        Maximum = 360,
        DisplayMethod = "Value",
        Callback = function(v)
            Config.FOVView = ApplySliderStep(v, 30, 360, false)
            if Config.FOVToggle then pcall(function() workspace.CurrentCamera.FieldOfView = Config.FOVView end) end
        end
    })

    -- Lighting
    Toggles["Fullbright_Toggle"] = Section_Lighting:Toggle({
        Name = TL("Fullbright", "สว่างสุด"),
        Default = Config.Fullbright_Toggle,
        Callback = function(v) SetFullbright(v) end
    })
    AddInlineFeatureBind(Section_Lighting, "Fullbright", "Fullbright_Toggle", Enum.KeyCode.B)

    Toggles["RemoveFog_Toggle"] = Section_Lighting:Toggle({
        Name = TL("Disable Fog", "ปิดหมอก"),
        Default = Config.RemoveFog_Toggle,
        Callback = function(v) SetRemoveFog(v) end
    })
    AddInlineFeatureBind(Section_Lighting, "Disable Fog", "RemoveFog_Toggle", Enum.KeyCode.End)

    -- Interactions
    Toggles["InstantPress"] = Section_Interactions:Toggle({
        Name = TL("Fast Interact", "โต้ตอบไว"),
        Default = Config.InstantPress,
        Callback = function(v) Config.InstantPress = v; UpdateInteractables() end
    })
    AddInlineFeatureBind(Section_Interactions, "Fast Interact", "InstantPress", Enum.KeyCode.F10)

    Toggles["AuraRange"] = Section_Interactions:Toggle({
        Name = TL("Interaction Aura", "ออร่าโต้ตอบ"),
        Default = Config.AuraRange,
        Callback = function(v) Config.AuraRange = v; UpdateInteractables() end
    })
    AddInlineFeatureBind(Section_Interactions, "Interaction Aura", "AuraRange", Enum.KeyCode.F11)

    Toggles["AntiAFK"] = Section_Interactions:Toggle({
        Name = TL("Anti-AFK", "กัน AFK"),
        Default = Config.AntiAFK,
        Callback = function(v) SetAntiAFK(v) end
    })
    AddInlineFeatureBind(Section_Interactions, "Anti-AFK", "AntiAFK", Enum.KeyCode.Home)

    Toggles["AntiStun"] = Section_Interactions:Toggle({
        Name = TL("Anti Stun", "กันสตัน"),
        Default = Config.AntiStun,
        Callback = function(v) SetAntiStun(v) end
    })
    AddInlineFeatureBind(Section_Interactions, "Anti Stun", "AntiStun", Enum.KeyCode.F12)

    Toggles["ShiftLock_Enabled"] = Section_Interactions:Toggle({
        Name = TL("Shift Lock", "ล็อกไหล่"),
        Default = Config.ShiftLock_Enabled,
        Callback = function(v) SetShiftLockEnabled(v) end
    })
    AddInlineFeatureBind(Section_Interactions, "Shift Lock", "ShiftLock_Enabled", Enum.KeyCode.LeftAlt)

    Section_Interactions:Keybind({
        Name = TL("Shift Lock Key", "ปุ่มล็อกไหล่"),
        Default = Config.ShiftLock_BindKey,
        Callback = function() end,
        onBinded = function(bind)
            local bindType, bindKey = ParseBoundInput(bind)
            Config.ShiftLock_BindType = bindType
            Config.ShiftLock_BindKey = bindKey
        end
    })

    Toggles["CollisionBypass"] = Section_Interactions:Toggle({
        Name = TL("Collision Bypass", "ทะลุชน"),
        Default = Config.CollisionBypass,
        Callback = function(v)
            Config.CollisionBypass = v
            if v and Config.CollisionBounce then
                Config.CollisionBounce = false
                if Toggles["CollisionBounce"] and Toggles["CollisionBounce"].Set then
                    pcall(function() Toggles["CollisionBounce"]:Set(false) end)
                end
            end
            SetCollisionBypass(v, "Bypass")
        end
    })
    AddInlineFeatureBind(Section_Interactions, "Collision Bypass", "CollisionBypass", Enum.KeyCode.H)

    Toggles["CollisionBounce"] = Section_Interactions:Toggle({
        Name = TL("Collision Bounce", "เด้งออกตอนชน"),
        Default = Config.CollisionBounce,
        Callback = function(v)
            Config.CollisionBounce = v
            if v and Config.CollisionBypass then
                Config.CollisionBypass = false
                if Toggles["CollisionBypass"] and Toggles["CollisionBypass"].Set then
                    pcall(function() Toggles["CollisionBypass"]:Set(false) end)
                end
            end
            SetCollisionBypass(v, "Bounce")
        end
    })
    AddInlineFeatureBind(Section_Interactions, "Collision Bounce", "CollisionBounce", Enum.KeyCode.Y)

    Toggles["FakeLag"] = Section_FakeLag:Toggle({
        Name = TL("Fake Lag", "เฟคลาก"),
        Default = Config.FakeLag,
        Callback = function(v)
            Config.FakeLag = v
            SetFakeLag(v)
        end
    })
    AddInlineFeatureBind(Section_FakeLag, "Fake Lag", "FakeLag", Enum.KeyCode.L)
    Section_FakeLag:Dropdown({
        Name = TL("Fake Lag Method", "รูปแบบเฟคลาก"),
        Multi = false,
        Required = true,
        Options = {"ปกติ", "แช่แข็ง"},
        Default = (Config.FakeLagMethod == "แช่แข็ง") and 2 or 1,
        Callback = function(v)
            Config.FakeLagMethod = v
            if Config.FakeLag and FakeLagState.Active then
                SetFakeLag(false)
                SetFakeLag(true)
            end
        end
    })
    Section_FakeLag:Dropdown({
        Name = TL("Warp Mode", "โหมดวาร์ป"),
        Multi = false,
        Required = true,
        Options = {"Current", "Back"},
        Default = table.find({"Current", "Back"}, Config.FakeLagMode) or 1,
        Callback = function(v) Config.FakeLagMode = v end
    })
    Toggles["Freecam"] = Section_FakeLag:Toggle({
        Name = TL("Freecam", "กล้องอิสระ"),
        Default = Config.Freecam,
        Callback = function(v)
            Config.Freecam = v
            SetFreecam(v)
        end
    })
    AddInlineFeatureBind(Section_FakeLag, "Freecam", "Freecam", nil)

    -- Fling
    do
        if _G.PhwyFlingCleanup then pcall(_G.PhwyFlingCleanup) end

        local Fling = {
            State = {
                Armed = false,
                Active = false,
                Resolving = false,
                AnimId = "133566007754001",
                Speed = 16,
                QuickFireKey = Enum.KeyCode.T,
            FloatingButtonsEnabled = true,
                FloatingButtonScale = 0.7,
                antiFallEnabled = false,
                godEnabled = false,
                antiFlingEnabled = false,
                VisibleButtons = {},
            },
            Presets = {
                ["Dropkick"] = "133566007754001",
                ["Dropkicking [TRENDY]"] = "90717656419568",
                ["Tenna Kick"] = "118139885865308",
                ["MMA Kick"] = "88347541858075",
                ["Slap"] = "108225134235478",
                ["Slap2"] = "78221709455150",
                ["Push"] = "135890160317037",
                ["Push2"] = "82070755455634",
            },
            Names = {"Dropkick", "Dropkicking [TRENDY]", "Tenna Kick", "MMA Kick", "Slap", "Slap2", "Push", "Push2"},
            Conns = {},
            Track = nil,
            LastFireTime = 0,
            LastSafeCFrame = nil,
            Recovering = false,
            Gui = nil,
            Container = nil,
        }
        for _, name in ipairs(Fling.Names) do
            Fling.State.VisibleButtons[name] = true
        end

        local function FlingDisconnect(name)
            if Fling.Conns[name] then
                pcall(function() Fling.Conns[name]:Disconnect() end)
                Fling.Conns[name] = nil
            end
        end

        local function FlingConnect(name, conn)
            FlingDisconnect(name)
            Fling.Conns[name] = conn
            AddConn(conn)
        end

        local function FlingSetProps(instance, props)
            for prop, value in pairs(props) do
                instance[prop] = value
            end
            return instance
        end

        local function FlingCleanupTrack()
            Fling.State.Active = false
            if Fling.Track then
                pcall(function() Fling.Track:Stop() end)
                Fling.Track = nil
            end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, prop in ipairs({"AssemblyLinearVelocity", "AssemblyAngularVelocity", "Velocity", "RotVelocity"}) do
                    pcall(function() hrp[prop] = Vector3.zero end)
                end
            end
        end

        local function FlingResolveAnimationId(rawId)
            if type(rawId) ~= "string" or rawId == "" or rawId:match("^%s*$") then return nil end
            local numStr = rawId:match("%d+")
            if not numStr then return nil end
            local numId = tonumber(numStr)
            pcall(function()
                local info = game:GetService("MarketplaceService"):GetProductInfo(numId)
                if info and info.AssetTypeId ~= 24 and info.AssetTypeId ~= 61 then
                    numStr = nil
                end
            end)
            if not numStr then return nil end
            local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. numStr) end)
            if ok and type(objects) == "table" then
                for _, obj in pairs(objects) do
                    if typeof(obj) == "Instance" then
                        if obj:IsA("Animation") then return obj.AnimationId end
                        local childAnim = obj:FindFirstChildWhichIsA("Animation", true)
                        if childAnim then return childAnim.AnimationId end
                    end
                end
            end
            return "rbxassetid://" .. numStr
        end

        local function FlingFire(animId)
            if tick() - Fling.LastFireTime < 1 then return end
            Fling.LastFireTime = tick()
            if Fling.State.Resolving then return end
            if Fling.State.Active then
                FlingCleanupTrack()
                return
            end
            if not Fling.State.Armed then return end
            Fling.State.Resolving = true
            Fling.State.AnimId = animId or Fling.State.AnimId
            task.spawn(function()
                local finalAnimId = FlingResolveAnimationId(Fling.State.AnimId)
                Fling.State.Resolving = false
                if not finalAnimId then return end

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildWhichIsA("Humanoid")
                if not (hrp and hum) then return end

                local anim = Instance.new("Animation")
                anim.AnimationId = finalAnimId
                local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
                if not ok or not track then return end

                Fling.State.Active = true
                Fling.Track = track
                track.Priority = Enum.AnimationPriority.Action
                track.Looped = false
                pcall(function() track:Play() end)

                local stopped = false
                local stoppedConn = track.Stopped:Connect(function() stopped = true end)
                local flip = 1
                local timeout = tick() + 300
                while Fling.State.Active and not stopped and tick() <= timeout do
                    RunService.Heartbeat:Wait()
                    char = LocalPlayer.Character
                    hrp = char and char:FindFirstChild("HumanoidRootPart")
                    hum = char and char:FindFirstChildWhichIsA("Humanoid")
                    if not (hrp and hum) then break end
                    flip = flip * -1
                    hrp.AssemblyLinearVelocity = Vector3.new(100000 * flip, 0, 100000 * flip)
                    hrp.AssemblyAngularVelocity = Vector3.new(100000 * flip, 100000 * flip, 100000 * flip)
                    RunService.RenderStepped:Wait()
                    if hum.MoveDirection.Magnitude > 0 then
                        for _, prop in ipairs({"AssemblyLinearVelocity", "Velocity"}) do
                            pcall(function()
                                hrp[prop] = Vector3.new(hum.MoveDirection.X * Fling.State.Speed, -2, hum.MoveDirection.Z * Fling.State.Speed)
                            end)
                        end
                    else
                        for _, prop in ipairs({"AssemblyLinearVelocity", "Velocity"}) do
                            pcall(function() hrp[prop] = Vector3.new(0, -2, 0) end)
                        end
                    end
                    for _, prop in ipairs({"AssemblyAngularVelocity", "RotVelocity"}) do
                        pcall(function() hrp[prop] = Vector3.zero end)
                    end
                end
                pcall(function() stoppedConn:Disconnect() end)
                FlingCleanupTrack()
            end)
        end

        local function FlingBuildFloatingButtons()
            if not Fling.Gui then
                Fling.Gui = FlingSetProps(Instance.new("ScreenGui"), {
                    Name = "PhwyFlingFloatingButtons",
                    ResetOnSpawn = false,
                    IgnoreGuiInset = true,
                    Parent = CoreGui,
                })
                Fling.Container = FlingSetProps(Instance.new("Frame"), {
                    Name = "FloatingContainer",
                    Size = UDim2.new(0, 220, 1, 0),
                    Position = UDim2.new(1, -240, 0, 80),
                    BackgroundTransparency = 1,
                    Parent = Fling.Gui,
                })
                FlingSetProps(Instance.new("UIListLayout"), {
                    Padding = UDim.new(0, 8),
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    VerticalAlignment = Enum.VerticalAlignment.Top,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = Fling.Container,
                })
            end
            Fling.Container.Visible = Fling.State.Armed and Fling.State.FloatingButtonsEnabled
            for _, child in ipairs(Fling.Container:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            for index, name in ipairs(Fling.Names) do
                if Fling.State.VisibleButtons[name] ~= false then
                    local frame = FlingSetProps(Instance.new("Frame"), {
                        Size = UDim2.new(0, math.floor(200 * Fling.State.FloatingButtonScale), 0, math.floor(44 * Fling.State.FloatingButtonScale)),
                        BackgroundColor3 = Color3.fromRGB(38, 38, 38),
                        BackgroundTransparency = 0.12,
                        BorderSizePixel = 0,
                        LayoutOrder = index,
                        Parent = Fling.Container,
                    })
                    FlingSetProps(Instance.new("UICorner"), { CornerRadius = UDim.new(1, 0), Parent = frame })
                    FlingSetProps(Instance.new("UIStroke"), { Color = Color3.fromRGB(80, 80, 80), Thickness = 1, Parent = frame })
                    FlingSetProps(Instance.new("TextLabel"), {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = name,
                        TextColor3 = Color3.fromRGB(245, 245, 245),
                        TextSize = math.floor(12 * Fling.State.FloatingButtonScale),
                        Font = Enum.Font.GothamBold,
                        Parent = frame,
                    })
                    FlingSetProps(Instance.new("TextButton"), {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "",
                        Parent = frame,
                    }).MouseButton1Click:Connect(function()
                        FlingFire(Fling.Presets[name])
                    end)
                end
            end
        end

        local function FlingSetAntiFall(value)
            Fling.State.antiFallEnabled = value
            FlingDisconnect("antiFallLoop")
            FlingDisconnect("antiFallRespawn")
            if not value then return end
            local function hook(char)
                task.spawn(function()
                    local hrp = char and char:WaitForChild("HumanoidRootPart", 10)
                    if not (hrp and Fling.State.antiFallEnabled) then return end
                    FlingConnect("antiFallLoop", RunService.Heartbeat:Connect(function()
                        if not Fling.State.antiFallEnabled or not hrp.Parent then
                            FlingDisconnect("antiFallLoop")
                            return
                        end
                        local velocity = hrp.AssemblyLinearVelocity
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        RunService.RenderStepped:Wait()
                        hrp.AssemblyLinearVelocity = velocity
                    end))
                end)
            end
            hook(LocalPlayer.Character)
            FlingConnect("antiFallRespawn", LocalPlayer.CharacterAdded:Connect(hook))
        end

        local function FlingSetGod(value)
            Fling.State.godEnabled = value
            FlingDisconnect("godLoop")
            FlingDisconnect("godRespawn")
            local function setStates(char, enabled)
                local hum = char and char:FindFirstChildWhichIsA("Humanoid")
                if not hum then return end
                for _, state in ipairs({Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Physics}) do
                    pcall(function() hum:SetStateEnabled(state, not enabled) end)
                end
                if enabled then
                    pcall(function() hum.MaxHealth = math.max(hum.MaxHealth, 100) end)
                    pcall(function() hum.Health = hum.MaxHealth end)
                    pcall(function() hum.BreakJointsOnDeath = false end)
                end
            end
            if not value then
                setStates(LocalPlayer.Character, false)
                return
            end
            setStates(LocalPlayer.Character, true)
            FlingConnect("godLoop", RunService.Heartbeat:Connect(function()
                if not Fling.State.godEnabled then return end
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
                if hum then pcall(function() hum.Health = hum.MaxHealth end) end
            end))
            FlingConnect("godRespawn", LocalPlayer.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                if Fling.State.godEnabled then setStates(char, true) end
            end))
        end

        local function FlingSetAntiFling(value)
            Fling.State.antiFlingEnabled = value
            FlingDisconnect("antiFlingLoop")
            Fling.LastSafeCFrame = nil
            Fling.Recovering = false
            if not value then return end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then Fling.LastSafeCFrame = hrp.CFrame end
            FlingConnect("antiFlingLoop", RunService.Stepped:Connect(function()
                if not Fling.State.antiFlingEnabled then return end
                char = LocalPlayer.Character
                hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildWhichIsA("Humanoid")
                if not (hrp and hum and hum.Health > 0) then return end
                local velocity = hrp.AssemblyLinearVelocity
                local rotVelocity = hrp.AssemblyAngularVelocity
                local mag = velocity.Magnitude
                local rotMag = rotVelocity.Magnitude
                if not Fling.LastSafeCFrame then Fling.LastSafeCFrame = hrp.CFrame end
                local controlled = rotMag < 60
                local state = hum:GetState()
                local maxLinear = Fling.State.Active and 250 or 150
                local maxUp, maxDown = 250, -350
                if controlled then
                    maxLinear = 1000
                    maxUp = 800
                    maxDown = (velocity.Y < -50 and (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown)) and -5000 or -800
                end
                if rotMag > 120 or velocity.Y > maxUp or velocity.Y < maxDown or mag > maxLinear then
                    Fling.Recovering = true
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    if Fling.LastSafeCFrame then hrp.CFrame = Fling.LastSafeCFrame end
                    if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                        hum.PlatformStand = false
                        hum.Sit = false
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                elseif Fling.LastSafeCFrame then
                    if (hrp.Position - Fling.LastSafeCFrame.Position).Magnitude > 50 and mag < 100 and not Fling.Recovering then
                        Fling.LastSafeCFrame = hrp.CFrame
                    end
                    if controlled and mag < 900 then
                        Fling.LastSafeCFrame = hrp.CFrame
                        Fling.Recovering = false
                    end
                end
            end))
        end

        local Section_FlingMain = WrapSection(TabFling:Section({ Side = "Left" }))
        local Section_FlingButtons = WrapSection(TabFling:Section({ Side = "Right" }))
        local Section_FlingProtection = WrapSection(TabFling:Section({ Side = "Left" }))
        Section_FlingMain:Header({ Name = TL("MAIN SETTINGS", "MAIN SETTINGS") })
        Section_FlingButtons:Header({ Name = TL("VISIBLE FLOATING BUTTONS", "VISIBLE FLOATING BUTTONS") })
        Section_FlingProtection:Header({ Name = TL("GODMODE & ANTI-FALL", "GODMODE & ANTI-FALL") })

        Section_FlingMain:Toggle({
            Name = TL("Enable Fling", "Enable Fling"),
            Default = Fling.State.Armed,
            Callback = function(v)
                Fling.State.Armed = v
                if not v then FlingCleanupTrack() end
                FlingBuildFloatingButtons()
            end
        })
        Section_FlingMain:Keybind({
            Name = TL("Key ...", "Key ..."),
            Default = Fling.State.QuickFireKey,
            Callback = function() FlingFire() end,
            onBinded = function(bind)
                local bindType, bindKey = ParseBoundInput(bind)
                if bindType == "Keyboard" then Fling.State.QuickFireKey = bindKey end
            end
        })
        Section_FlingMain:Button({
            Name = TL("Execute / Stop Fling", "Execute / Stop Fling"),
            Callback = function() FlingFire() end
        })

        for _, name in ipairs(Fling.Names) do
            Section_FlingButtons:Toggle({
                Name = TL("Button: " .. name, "Button: " .. name),
                Default = Fling.State.VisibleButtons[name],
                Callback = function(v)
                    Fling.State.VisibleButtons[name] = v
                    FlingBuildFloatingButtons()
                end
            })
        end

        Section_FlingProtection:Toggle({
            Name = TL("Anti-Fall Damage", "Anti-Fall Damage"),
            Default = Fling.State.antiFallEnabled,
            Callback = FlingSetAntiFall
        })
        Section_FlingProtection:Toggle({
            Name = TL("Godmode (Anti-Instakill)", "Godmode (Anti-Instakill)"),
            Default = Fling.State.godEnabled,
            Callback = FlingSetGod
        })
        Section_FlingProtection:Toggle({
            Name = TL("Anti-Fling Protection", "Anti-Fling Protection"),
            Default = Fling.State.antiFlingEnabled,
            Callback = FlingSetAntiFling
        })

        FlingConnect("quickFireInput", UIS.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or input.KeyCode == Enum.KeyCode.Unknown then return end
            if Fling.State.QuickFireKey and input.KeyCode == Fling.State.QuickFireKey then
                FlingFire()
            end
        end))
        FlingConnect("charReset", LocalPlayer.CharacterAdded:Connect(function()
            if Fling.State.Active then FlingCleanupTrack() end
        end))
        FlingBuildFloatingButtons()
        FlingSetAntiFling(Fling.State.antiFlingEnabled)

        _G.PhwyFlingCleanup = function()
            for name in pairs(Fling.Conns) do
                FlingDisconnect(name)
            end
            FlingCleanupTrack()
            if Fling.Gui then
                pcall(function() Fling.Gui:Destroy() end)
                Fling.Gui = nil
            end
        end
    end

    -- Optimization
    Toggles["FPSBooster"] = Section_Optimization:Toggle({
        Name = TL("Enable FPS Booster", "เปิดเร่ง FPS"),
        Default = Config.FPSBooster,
        Callback = function(v) Config.FPSBooster = v; if v then ApplyFPSBoost() else DisableFPSBoost() end end
    })
    AddInlineFeatureBind(Section_Optimization, "FPS Booster", "FPSBooster", Enum.KeyCode.Insert)
    Toggles["FPSUnlockerEnabled"] = Section_Optimization:Toggle({
        Name = TL("FPS Unlocker", "ปลดล็อกเฟรมเรต"),
        Default = Config.FPSUnlockerEnabled,
        Callback = function(v)
            Config.FPSUnlockerEnabled = v
            if FPSCapDropdown then
                pcall(function() FPSCapDropdown:SetVisibility(v) end)
            end
            if v then
                local selected = Config.FPSCapOption or "Infinity"
                pcall(function()
                    if selected == "Infinity" then
                        if setfpscap then setfpscap(9999) end
                    else
                        local cap = tonumber(selected)
                        if cap and setfpscap then setfpscap(cap) end
                    end
                end)
            end
        end
    })
    local fpsCapOptionsEN = {"Infinity", "30", "60", "75", "120", "144", "165", "240", "360"}
    local fpsCapOptionsTH = {"ไร้ขีดจำกัด", "30", "60", "75", "120", "144", "165", "240", "360"}
    local fpsCapSelection = Config.FPSCapOption or "Infinity"
    local fpsCapDefaultIndex = table.find(fpsCapOptionsEN, fpsCapSelection) or 1
    FPSCapDropdown = Section_Optimization:Dropdown({
        Name = TL("FPS Unlocker", "ปลดล็อกเฟรมเรต"),
        Multi = false,
        Required = true,
        Options = (Config.Language == "TH") and fpsCapOptionsTH or fpsCapOptionsEN,
        Default = fpsCapDefaultIndex,
        Callback = function(v)
            local selected = v
            if selected == "ไร้ขีดจำกัด" then
                selected = "Infinity"
            end
            Config.FPSCapOption = selected
            if not Config.FPSUnlockerEnabled then return end
            pcall(function()
                if selected == "Infinity" then
                    if setfpscap then
                        setfpscap(9999)
                    end
                else
                    local cap = tonumber(selected)
                    if cap and setfpscap then
                        setfpscap(cap)
                    end
                end
            end)
        end
    })
    pcall(function() FPSCapDropdown:SetVisibility(Config.FPSUnlockerEnabled == true) end)
    RegisterLanguageUpdater(function()
        pcall(function() FPSCapDropdown:UpdateName(TL("FPS Unlocker", "ปลดล็อกเฟรมเรต")) end)
        pcall(function() FPSCapDropdown:ClearOptions() end)
        pcall(function()
            if Config.Language == "TH" then
                FPSCapDropdown:InsertOptions(fpsCapOptionsTH)
                FPSCapDropdown:UpdateSelection((Config.FPSCapOption == "Infinity") and "ไร้ขีดจำกัด" or tostring(Config.FPSCapOption))
            else
                FPSCapDropdown:InsertOptions(fpsCapOptionsEN)
                FPSCapDropdown:UpdateSelection(tostring(Config.FPSCapOption or "Infinity"))
            end
        end)
        pcall(function() FPSCapDropdown:SetVisibility(Config.FPSUnlockerEnabled == true) end)
    end)

    Toggles["FPS_NoShadows"] = Section_Optimization:Toggle({
        Name = TL("Disable Shadows", "ปิดเงา"),
        Default = Config.FPS_NoShadows,
        Callback = function(v) Config.FPS_NoShadows = v end
    })

    Toggles["FPS_NoParticles"] = Section_Optimization:Toggle({
        Name = TL("Clear Particles", "ลบอนุภาค"),
        Default = Config.FPS_NoParticles,
        Callback = function(v) Config.FPS_NoParticles = v end
    })

    Toggles["FPS_NoClothes"] = Section_Optimization:Toggle({
        Name = TL("Strip Outfits", "ลดชุดตัวละคร"),
        Default = Config.FPS_NoClothes,
        Callback = function(v) Config.FPS_NoClothes = v end
    })

    Toggles["FPS_LowQuality"] = Section_Optimization:Toggle({
        Name = TL("Low Mesh Quality", "ลดคุณภาพ Mesh"),
        Default = Config.FPS_LowQuality,
        Callback = function(v) Config.FPS_LowQuality = v end
    })

    -- Interface Info
    Section_InterfaceInfo:Dropdown({
        Name = TL("Data Display", "การแสดงข้อมูล"),
        Multi = false,
        Required = true,
        Options = {"FPS", "Ping", "FPS & Ping"},
        Default = table.find({"FPS", "Ping", "FPS & Ping"}, Config.ShowFPSPing) or 3,
        Callback = function(v) Config.ShowFPSPing = v end
    })

    Toggles["ShowStatsToggle"] = Section_InterfaceInfo:Toggle({
        Name = TL("Show Activity HUD", "แสดง HUD"),
        Default = Config.ShowStatsToggle,
        Callback = function(v) Config.ShowStatsToggle = v; UI.StatHUD.Visible = v end
    })
    AddInlineFeatureBind(Section_InterfaceInfo, "Show Activity HUD", "ShowStatsToggle", Enum.KeyCode.KeypadFive)

    Section_InterfaceInfo:Dropdown({
        Name = TL("HUD Position", "ตำแหน่ง HUD"),
        Multi = false,
        Required = true,
        Options = {"TopLeft", "TopRight", "BottomLeft", "BottomRight"},
        Default = table.find({"TopLeft", "TopRight", "BottomLeft", "BottomRight"}, Config.HUDPosition) or 2,
        Callback = function(v) Config.HUDPosition = v; UpdateHUDPos() end
    })
    Section_InterfaceInfo:SubLabel({ Text = "แสดงผล HUD สถานะเรียลไทม์และจัดตำแหน่งตามหน้าจอ" })

    Section_Optimization:Spacer()
    Section_Optimization:Paragraph({
        Header = "Optimization Notes",
        Body = "เปิด FPS Booster เมื่อเกมหนัก และปิดเมื่อทดสอบภาพกราฟิกหรือ Ray Tracing เพื่อบาลานซ์ประสิทธิภาพ"
    })

    -- GRAPHIC TAB
    local Section_RayTracing = WrapSection(TabGraphic:Section({ Side = "Left" }))
    local Section_ChangeSky = WrapSection(TabGraphic:Section({ Side = "Right" }))
    local Section_GraphicInfo = WrapSection(TabGraphic:Section({ Side = "Left" }))
    Section_RayTracing:Header({ Name = TL("Ray Tracing", "เรย์เทรซซิ่ง") })
    Section_ChangeSky:Header({ Name = TL("Change the Sky", "เปลี่ยนท้องฟ้า") })
    Section_GraphicInfo:Header({ Name = TL("Graphic Guide", "คู่มือกราฟิก") })
    Section_GraphicInfo:Paragraph({
        Header = TL("Tips", "คำแนะนำ"),
        Body = "Ray Tracing ใช้ทรัพยากรสูง ควรเปิดร่วมกับ FPS Booster ตามสถานการณ์ และเปลี่ยน Sky เพื่อปรับบรรยากาศโดยไม่กระทบตรรกะหลักของสคริปต์"
    })

    Section_RayTracing:Button({
        Name = TL("Ray Tracing", "เรย์เทรซซิ่ง"),
        Callback = function()
            if RTXLoaded or Config.RTX_Enabled then
                Config.RTX_Enabled = true
                Window:Notify({ Title = TL("Info", "ข้อมูล"), Description = TL("Ray Tracing is already enabled permanently for this session.", "Ray Tracing เปิดถาวรสำหรับรอบนี้แล้ว"), Lifetime = 3 })
                return
            end
            SetRTX(true)
        end
    })

    Toggles["ChangeSky_Enabled"] = Section_ChangeSky:Toggle({
        Name = TL("Change Sky", "เปลี่ยนท้องฟ้า"),
        Default = Config.ChangeSky_Enabled,
        Callback = function(v) SetChangeSky(v) end
    })
    AddInlineFeatureBind(Section_ChangeSky, "Change Sky", "ChangeSky_Enabled", Enum.KeyCode.KeypadSeven)

    Section_ChangeSky:Dropdown({
        Name = TL("Sky Selection", "เลือกท้องฟ้า"),
        Search = true,
        Multi = false,
        Required = true,
        Options = SkyList,
        Default = table.find(SkyList, Config.ChangeSky_Selected) or 1,
        Callback = function(v)
            Config.ChangeSky_Selected = v
            if Config.ChangeSky_Enabled then
                local id = SkyOptions[v]
                if id then ApplySkyById(id) end
            end
        end
    })

    local Section_MapTime = WrapSection(TabGraphic:Section({ Side = "Right" }))
    Section_MapTime:Header({ Name = TL("Time of Day", "ปรับเวลาในแมพ") })

    if State.OriginalMapTime == nil then
        pcall(function() State.OriginalMapTime = game:GetService("Lighting").ClockTime end)
    end

    Toggles["MapTime_Enabled"] = Section_MapTime:Toggle({
        Name = TL("Enable Custom Time", "เปิดปรับเวลา"),
        Default = Config.MapTimeEnabled,
        Callback = function(v) 
            Config.MapTimeEnabled = v 
            if v then
                pcall(function() State.OriginalMapTime = game:GetService("Lighting").ClockTime end)
            else
                pcall(function() game:GetService("Lighting").ClockTime = State.OriginalMapTime or 14 end)
            end
        end
    })

    Section_MapTime:Dropdown({
        Name = TL("Time Presets", "เลือกเวลาสำเร็จรูป"),
        Multi = false,
        Required = true,
        Options = {"Morning (06:00)", "Noon (12:00)", "Evening (18:00)", "Midnight (00:00)"},
        Default = 2,
        Callback = function(v)
            if v == "Morning (06:00)" then Config.MapTimeValue = 6
            elseif v == "Noon (12:00)" then Config.MapTimeValue = 12
            elseif v == "Evening (18:00)" then Config.MapTimeValue = 18
            elseif v == "Midnight (00:00)" then Config.MapTimeValue = 0
            end
        end
    })

    Section_MapTime:Slider({
        Name = TL("Custom Time (Hours)", "กำหนดเวลาเอง (ชั่วโมง)"),
        Default = Config.MapTimeValue or 12,
        Minimum = 0,
        Maximum = 24,
        DisplayMethod = "Value",
        Callback = function(v) Config.MapTimeValue = ApplySliderStep(v, 0, 24, false) end
    })

    -- PLAYER TELEPORT TAB
    local Section_TargetTracking = WrapSection(TabTP:Section({ Side = "Left" }))
    local Section_MouseTP = WrapSection(TabTP:Section({ Side = "Left" }))
    local Section_Spectator = WrapSection(TabTP:Section({ Side = "Right" }))
    Section_TargetTracking:Header({ Name = TL("Target Tracking", "ติดตามเป้าหมาย") })
    Section_Spectator:Header({ Name = TL("Spectator Mode", "โหมดส่องผู้เล่น") })
    Section_MouseTP:Header({ Name = TL("Mouse Teleportation", "วาร์ปด้วยเมาส์") })

    TPTargetDropdown = Section_TargetTracking:Dropdown({
        Name = TL("Target Player", "ผู้เล่นเป้าหมาย"),
        Search = true,
        Multi = false,
        Required = false,
        Options = {"-"},
        Default = 1,
        Callback = function(v) Config.TPTarget = v end
    })

    Section_TargetTracking:Dropdown({
        Name = TL("Tracking Mode", "โหมดติดตาม"),
        Multi = false,
        Required = true,
        Options = {"Safe Fly", "Warp"},
        Default = table.find({"Safe Fly", "Warp"}, Config.TPMode) or 2,
        Callback = function(v) Config.TPMode = v end
    })

    Section_TargetTracking:Slider({
        Name = TL("Follow Speed", "ความเร็วติดตาม"),
        Default = Config.TPFlightSens,
        Minimum = 10,
        Maximum = 500,
        DisplayMethod = "Value",
        Callback = function(v) Config.TPFlightSens = ApplySliderStep(v, 10, 500, false) end
    })

    Toggles["TPGOSwitch"] = Section_TargetTracking:Toggle({
        Name = TL("Activate System", "เปิดระบบ"),
        Default = Config.TPGOSwitch,
        Callback = function(v)
            Config.TPGOSwitch = v
            if v and Config.TPTarget ~= "-" then
                local tp = Players:FindFirstChild(Config.TPTarget)
                if tp then
                    if Config.TPMode == "Safe Fly" then StartSafeTP(tp)
                    else local tHRP = tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
                        if tHRP and LocalPlayer.Character then pcall(function() LocalPlayer.Character:PivotTo(tHRP.CFrame * CFrame.new(0, 0, 3)) end) end
                    end
                end
            else
                StopSafeTP()
            end
        end
    })
    AddInlineFeatureBind(Section_TargetTracking, "Activate System", "TPGOSwitch", Enum.KeyCode.T)

    SpecTargetDropdown = Section_Spectator:Dropdown({
        Name = TL("Watch Player", "ดูผู้เล่น"),
        Search = true,
        Multi = false,
        Required = false,
        Options = {"-"},
        Default = 1,
        Callback = function(v) Config.SpecTarget = v end
    })

    Toggles["SpecToggle"] = Section_Spectator:Toggle({
        Name = TL("Enable Eye", "เปิดโหมดดู"),
        Default = Config.SpecToggle,
        Callback = function(v)
            Config.SpecToggle = v
            if not v then
                local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then Camera.CameraSubject = h end
            end
        end
    })
    AddInlineFeatureBind(Section_Spectator, "Enable Eye", "SpecToggle", Enum.KeyCode.KeypadEight)

    Section_MouseTP:Keybind({
        Name = TL("Teleport Key", "ปุ่มวาร์ป"),
        Default = Config.ClickTPBindKey,
        Callback = function() end,
        onBinded = function(bind)
            local bindType, bindKey = ParseBoundInput(bind)
            Config.ClickTPBindType = bindType
            Config.ClickTPBindKey = bindKey
        end
    })

    Toggles["ClickTPToggle"] = Section_MouseTP:Toggle({
        Name = TL("Enable Click-TP", "เปิดคลิกวาร์ป"),
        Default = Config.ClickTPToggle,
        Callback = function(v) Config.ClickTPToggle = v end
    })
    AddInlineFeatureBind(Section_MouseTP, "Click TP", "ClickTPToggle", Enum.KeyCode.C)

    Section_MouseTP:Dropdown({
        Name = TL("Click-TP Mode", "โหมดคลิกวาร์ป"),
        Multi = false,
        Required = true,
        Options = {"Teleport", "Fly", "Walk"},
        Default = table.find({"Teleport", "Fly", "Walk"}, Config.ClickTP_Mode) or 1,
        Callback = function(v) Config.ClickTP_Mode = v; StopCurrentClickTP() end
    })

    Section_MouseTP:Slider({
        Name = TL("Travel Speed", "ความเร็วเดินทาง"),
        Default = Config.ClickTP_Speed,
        Minimum = 10,
        Maximum = 500,
        DisplayMethod = "Value",
        Callback = function(v) Config.ClickTP_Speed = ApplySliderStep(v, 10, 500, false) end
    })

    -- SERVER DETAILS TAB
    local Section_ServerInfo = WrapSection(TabServer:Section({ Side = "Left" }))
    local Section_ServerActions = WrapSection(TabServer:Section({ Side = "Right" }))
    Section_ServerInfo:Header({ Name = TL("Server Info", "ข้อมูลเซิร์ฟเวอร์") })
    Section_ServerInfo:SubLabel({ Text = TL("Copy server details instantly", "คัดลอกข้อมูลเซิร์ฟเวอร์และลิงก์เข้าร่วมได้ทันที") })
    Section_ServerInfo:Divider()
    Section_ServerActions:Header({ Name = TL("Server Actions", "การทำงานเซิร์ฟเวอร์") })
    Section_ServerActions:SubLabel({ Text = TL("Server controls and script state", "คำสั่งจัดการการเชื่อมต่อเซิร์ฟเวอร์และสถานะสคริปต์") })
    Section_ServerActions:Divider()

    local gameNameLocal = TL("Loading...", "กำลังโหลด...")
    local nameBtn = Section_ServerInfo:Button({
        Name = TL("🎮 Name: Loading...", "🎮 ชื่อเกม: กำลังโหลด..."),
        Callback = function()
            if setclipboard then
                setclipboard(gameNameLocal)
                ShowToast(TL("Game name copied.", "คัดลอกชื่อเกมเรียบร้อยแล้ว"), Colors.Green)
            end
        end
    })

    local serverTimeBtn = Section_ServerInfo:Button({
        Name = TL("⏱️ Time in Server: 00:00:00", "⏱️ เวลาในเซิร์ฟเวอร์: 00:00:00"),
        Callback = function() end
    })
    
    local startTime = os.time()
    task.spawn(function()
        while State.Running do
            task.wait(1)
            local diff = os.time() - startTime
            local hours = math.floor(diff / 3600)
            local mins = math.floor((diff % 3600) / 60)
            local secs = diff % 60
            local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)
            pcall(function()
                serverTimeBtn:UpdateName(TL("⏱️ Time in Server: ", "⏱️ เวลาในเซิร์ฟเวอร์: ") .. timeStr)
            end)
        end
    end)

    task.spawn(function()
        pcall(function()
            local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
            if info and info.Name then gameNameLocal = info.Name else gameNameLocal = game.Name end
            nameBtn:UpdateName((Config.Language == "TH" and "🎮 ชื่อเกม: " or "🎮 Name: ") .. gameNameLocal)
        end)
    end)

    Section_ServerInfo:Button({
        Name = TL("👤 Creator ID: ", "👤 ไอดีผู้สร้าง: ") .. tostring(game.CreatorId),
        Callback = function()
            if setclipboard then setclipboard(tostring(game.CreatorId)); ShowToast(TL("Creator ID copied.", "คัดลอก ID ผู้สร้างแล้ว"), Colors.Green) end
        end
    })

    Section_ServerInfo:Button({
        Name = TL("🆔 Place ID: ", "🆔 ไอดีแมพ: ") .. tostring(game.PlaceId),
        Callback = function()
            if setclipboard then setclipboard(tostring(game.PlaceId)); ShowToast(TL("Place ID copied.", "คัดลอก Place ID แล้ว"), Colors.Green) end
        end
    })

    Section_ServerInfo:Button({
        Name = TL("🔑 Job ID: ", "🔑 ไอดีเซิร์ฟเวอร์: ") .. tostring(game.JobId),
        Callback = function()
            if setclipboard then setclipboard(tostring(game.JobId)); ShowToast(TL("Job ID copied.", "คัดลอก Job ID แล้ว"), Colors.Green) end
        end
    })

    Section_ServerInfo:Button({
        Name = TL("🔗 Direct Join Link", "🔗 ลิงก์เข้าโดยตรง"),
        Callback = function()
            local link = "roblox://experiences/start?placeId=" .. tostring(game.PlaceId) .. "&gameInstanceId=" .. tostring(game.JobId)
            if setclipboard then setclipboard(link); ShowToast(TL("Direct join link copied.", "คัดลอกลิงก์เข้าร่วมแล้ว"), Colors.Green) end
        end
    })

    Section_ServerInfo:Button({
        Name = TL("💻 JS Join Script (Browser Console)", "💻 โค้ด JS เข้าเซิร์ฟเวอร์"),
        Callback = function()
            local code = "Roblox.GameLauncher.joinGameInstance(" .. tostring(game.PlaceId) .. ", '" .. tostring(game.JobId) .. "');"
            if setclipboard then setclipboard(code); ShowToast(TL("JS join script copied.", "คัดลอกโค้ด JS เข้าร่วมแล้ว"), Colors.Green) end
        end
    })

    Section_ServerActions:Button({
        Name = TL("🔥 Highest Player Hop", "🔥 Highest Player Hop"),
        Callback = function()
            Window:Dialog({
                Title = TL("Join Populated Server", "สุ่มเซิร์ฟคนเยอะ"),
                Description = TL("Do you want to find and join a server with the most players?", "ต้องการค้นหาและเข้าร่วมเซิร์ฟเวอร์ที่มีผู้เล่นเยอะที่สุดใช่หรือไม่?"),
                Buttons = {
                    {
                        Name = TL("Confirm", "ยืนยัน"),
                        Callback = function()
                            ShowToast(TL("Searching for populated server...", "กำลังค้นหาเซิร์ฟเวอร์คนเยอะ..."), Colors.PrimaryBlue)
                            task.spawn(function()
                                local HttpService = game:GetService("HttpService")
                                local TPService = game:GetService("TeleportService")
                                local placeId = game.PlaceId
                                local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"
                                
                                local success, result = pcall(function()
                                    return game:HttpGet(url)
                                end)
                                
                                if success and result then
                                    local data = HttpService:JSONDecode(result)
                                    if data and data.data then
                                        local bestServer = nil
                                        local maxP = -1
                                        for _, server in ipairs(data.data) do
                                            if server.playing and server.maxPlayers and server.playing < server.maxPlayers and server.id ~= game.JobId then
                                                if server.playing > maxP then
                                                    maxP = server.playing
                                                    bestServer = server.id
                                                end
                                            end
                                        end
                                        if bestServer then
                                            ShowToast(TL("Server found! Teleporting...", "พบเซิร์ฟเวอร์แล้ว! กำลังวาร์ป..."), Colors.Green)
                                            TPService:TeleportToPlaceInstance(placeId, bestServer, LocalPlayer)
                                        else
                                            ShowToast(TL("No available populated server found.", "ไม่พบเซิร์ฟเวอร์ที่มีที่ว่าง"), Colors.Red)
                                        end
                                    end
                                else
                                    ShowToast(TL("Failed to fetch servers.", "ค้นหาเซิร์ฟเวอร์ไม่สำเร็จ"), Colors.Red)
                                end
                            end)
                        end
                    },
                    { Name = TL("Cancel", "ยกเลิก") }
                }
            })
        end
    })

    Section_ServerActions:Button({
        Name = TL("🔄 Rejoin Server", "🔄 เข้าเซิร์ฟเวอร์เดิม"),
        Callback = function()
            Window:Dialog({
                Title = TL("Rejoin Server", "เข้าเกมใหม่อีกครั้ง"),
                Description = TL(
                    "Are you sure you want to rejoin this server? This will reset your current game session.",
                    "คุณต้องการกลับเข้าสู่เซิร์ฟเวอร์เดิมนี้ใช่หรือไม่? การกระทำนี้จะรีเซ็ตข้อมูลตัวละครของคุณ"
                ),
                Buttons = {
                    {
                        Name = TL("Confirm", "ยืนยัน"),
                        Callback = function()
                            ShowToast(TL("Rejoining current server...", "กำลังเชื่อมต่อเซิร์ฟเวอร์เดิมใหม่..."), Colors.PrimaryBlue)
                            local ts = game:GetService("TeleportService")
                            if #Players:GetPlayers() <= 1 then
                                LocalPlayer:Kick("\nRejoining...")
                                task.wait()
                                ts:Teleport(game.PlaceId, LocalPlayer)
                            else
                                ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                            end
                        end
                    },
                    {
                        Name = TL("Cancel", "ยกเลิก")
                    }
                }
            })
        end
    })

    local function LowestServerHop()
        ShowToast(TL("Searching for lowest player server...", "กำลังค้นหาเซิร์ฟเวอร์คนน้อยที่สุด..."), Colors.PrimaryBlue)
        pcall(function()
            local HttpService = game:GetService("HttpService")
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
            if req then
                local response = req({
                    Url = url,
                    Method = "GET"
                })
                if response and response.Body then
                    local data = HttpService:JSONDecode(response.Body)
                    if data and data.data then
                        local bestServer = nil
                        for _, server in ipairs(data.data) do
                            if server.playing and server.playing > 0 and server.id ~= game.JobId then
                                if not bestServer or server.playing < bestServer.playing then
                                    bestServer = server
                                end
                            end
                        end
                        if bestServer then
                            ShowToast(TL("Found server! Teleporting...", "พบเซิร์ฟเวอร์แล้ว! กำลังเทเลพอร์ต..."), Colors.Green)
                            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, bestServer.id, LocalPlayer)
                            return
                        end
                    end
                end
            end
            ShowToast(TL("Could not find a suitable server.", "ไม่พบเซิร์ฟเวอร์ที่เหมาะสม"), Colors.Red)
        end)
    end

    Section_ServerActions:Button({
        Name = TL("📉 Lowest Player Hop", "📉 เซิร์ฟเวอร์คนน้อยที่สุด"),
        Callback = function()
            Window:Dialog({
                Title = TL("Lowest Player Hop", "ย้ายไปเซิร์ฟเวอร์คนน้อยที่สุด"),
                Description = TL(
                    "Hop to a server with the lowest amount of players?",
                    "คุณต้องการย้ายไปเซิร์ฟเวอร์ที่มีผู้เล่นน้อยที่สุดใช่หรือไม่?"
                ),
                Buttons = {
                    {
                        Name = TL("Confirm", "ยืนยัน"),
                        Callback = function()
                            LowestServerHop()
                        end
                    },
                    {
                        Name = TL("Cancel", "ยกเลิก")
                    }
                }
            })
        end
    })

    Section_ServerActions:Button({
        Name = TL("🚪 Server Hop", "🚪 ย้ายเซิร์ฟเวอร์"),
        Callback = function()
            Window:Dialog({
                Title = TL("Server Hop", "ย้ายเปลี่ยนเซิร์ฟเวอร์"),
                Description = TL(
                    "Are you sure you want to hop to another server? You will be connected to a random active server.",
                    "คุณแน่ใจหรือไม่ว่าต้องการสลับไปเล่นเซิร์ฟเวอร์อื่น? ระบบจะสุ่มค้นหาห้องใหม่ให้คุณโดยอัตโนมัติ"
                ),
                Buttons = {
                    {
                        Name = TL("Confirm", "ยืนยัน"),
                        Callback = function()
                            ShowToast(TL("Searching for another server...", "กำลังสลับหาเซิร์ฟเวอร์อื่น..."), Colors.PrimaryBlue)
                            local ts = game:GetService("TeleportService")
                            ts:Teleport(game.PlaceId, LocalPlayer)
                        end
                    },
                    {
                        Name = TL("Cancel", "ยกเลิก")
                    }
                }
            })
        end
    })
    

end

-- [ TARGET LIST DYNAMIC UPDATER ]
local function RefreshPlayerDropdowns()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Name and p.Name ~= "" then
            table.insert(list, p.Name)
        end
    end
    table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
    if #list == 0 then
        table.insert(list, "-")
    end
    pcall(function()
        if TPTargetDropdown then
            local current = Config.TPTarget
            TPTargetDropdown:ClearOptions()
            TPTargetDropdown:InsertOptions(list)
            if current and table.find(list, current) then
                TPTargetDropdown:UpdateSelection(current)
                Config.TPTarget = current
            else
                TPTargetDropdown:UpdateSelection("-")
                Config.TPTarget = "-"
            end
        end
        if SpecTargetDropdown then
            local current = Config.SpecTarget
            SpecTargetDropdown:ClearOptions()
            SpecTargetDropdown:InsertOptions(list)
            if current and table.find(list, current) then
                SpecTargetDropdown:UpdateSelection(current)
                Config.SpecTarget = current
            else
                SpecTargetDropdown:UpdateSelection("-")
                Config.SpecTarget = "-"
            end
        end
    end)
end
AddConn(Players.PlayerAdded:Connect(RefreshPlayerDropdowns))
AddConn(Players.PlayerRemoving:Connect(RefreshPlayerDropdowns))
task.defer(RefreshPlayerDropdowns)
task.delay(1, RefreshPlayerDropdowns)

BuildAllTabs()
EnsureLanguageHooks()
ApplyLanguageUI()

-- [ KEYBINDS INPUT HANDLER ]
featureNames = {
    Aimlock = "Aimlock", P_Master = "ESP Master", P_HitboxToggle = "Hitbox Expand",
    WSToggle = "Super Speed", JPToggle = "Super Jump", FlyToggle = "Fly Mode",
    Noclip = "No Clip", InfJump = "Infinite Jump", InvisToggle = "Invisibility",
    InfZoom = "Max Zoom", FOVToggle = "Custom FOV", Fullbright_Toggle = "Fullbright",
    RemoveFog_Toggle = "Remove Fog", AntiAFK = "Anti-AFK", FPSBooster = "FPS Booster",
    TPGOSwitch = "Teleport Target", ClickTPToggle = "Click TP",
    P_ESPInFOVOnly = "ESP FOV Only", P_ShowName = "ESP Show Names", P_ShowHealth = "ESP Show Health",
    P_ShowDist = "ESP Show Distance", P_Highlight = "ESP Highlight",
    P_TeamColor = "ESP Team Color", P_TeamCheck = "ESP Ignore Team",
    P_Xray = "ESP X-Ray", SpecToggle = "Spectator Mode",
    EnemyOnly = "Enemy Only", WallCheck = "Wall Check",
    HipHeightToggle = "Hip Height Float",
    RTX_Enabled = "Ray Tracing",
    EmoteMenuOpen = "Open Emote Menu",
    ChangeSky_Enabled = "Change Sky",
    ShiftLock = "Shift Lock",
    CollisionBypass = "Collision Bypass",
    CollisionBounce = "Collision Bounce",
    FakeLag = "Fake Lag",
    Freecam = "Freecam"
}

function ProcessKeybinds(input)
    NormalizeKeybindData()
    for featureKey, bindInfo in pairs(Config.Keybinds) do
        if featureKey ~= "ShiftLock" and bindInfo and bindInfo.Enabled then
            local matched = false
            if bindInfo.Type == "Keyboard" and input.UserInputType == Enum.UserInputType.Keyboard and bindInfo.Key then
                matched = (input.KeyCode == bindInfo.Key)
            elseif bindInfo.Type == "Mouse" then
                if bindInfo.Key == 1 then
                    matched = (input.UserInputType == Enum.UserInputType.MouseButton1)
                elseif bindInfo.Key == 2 then
                    matched = (input.UserInputType == Enum.UserInputType.MouseButton2)
                elseif bindInfo.Key == 3 then
                    matched = (input.UserInputType == Enum.UserInputType.MouseButton3)
                end
            end
            if matched then
                local mode = bindInfo.Mode or "Toggle"
                local displayName = featureNames[featureKey] or featureKey
                if mode == "Hold" then
                    Config[featureKey] = true
                    ShowToast((Config.Language == "TH" and "กดค้าง : " or "Hold: ") .. TranslateUIRawText(displayName), Colors.Green)
                    if featureKey == "WSToggle" then SetWalkSpeed(true) end
                    if featureKey == "JPToggle" then SetJumpPower(true) end
                    if featureKey == "FlyToggle" then SetFly(true) end
                    if featureKey == "Noclip" then SetNoclip(true) end
                    if featureKey == "InfJump" then SetInfJump(true) end
                    if featureKey == "AntiAFK" then SetAntiAFK(true) end
                    if featureKey == "AntiStun" then SetAntiStun(true) end
                    if featureKey == "InfZoom" then SetInfZoom(true) end
                    if featureKey == "FPSBooster" then ApplyFPSBoost() end
                    if featureKey == "InvisToggle" then SetInvisibility(true) end
                    if featureKey == "HipHeightToggle" then SetHipHeight(true) end
                    if featureKey == "Fullbright_Toggle" then SetFullbright(true) end
                    if featureKey == "RemoveFog_Toggle" then SetRemoveFog(true) end
                    if featureKey == "RTX_Enabled" then SetRTX(true) end
                    if featureKey == "ChangeSky_Enabled" then SetChangeSky(true) end
                    if featureKey == "Aimlock" then State.ToggleAiming = true end
                    if featureKey == "ShiftLock" then SetShiftLockActive(true) end
                    if featureKey == "CollisionBypass" then SetCollisionBypass(true, "Bypass") end
                    if featureKey == "CollisionBounce" then SetCollisionBypass(true, "Bounce") end
                    if featureKey == "FakeLag" then SetFakeLag(true) end
                    if featureKey == "Freecam" then SetFreecam(true) end
                    if featureKey == "TPGOSwitch" then
                        if Config.TPTarget ~= "-" then
                            local tp = Players:FindFirstChild(Config.TPTarget)
                            if tp then
                                if Config.TPMode == "Safe Fly" then
                                    StartSafeTP(tp)
                                else
                                    local tHRP = tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
                                    if tHRP and LocalPlayer.Character then
                                        pcall(function()
                                            LocalPlayer.Character:PivotTo(tHRP.CFrame * CFrame.new(0, 0, 3))
                                        end)
                                    end
                                end
                            end
                        end
                    end
                    pcall(function() UpdateToggleUIFromKeybind(featureKey) end)
                    return true
                else
                    if featureKey == "EmoteMenuOpen" then
                        if not State.EmoteMenuLoaded then
                            local ok = pcall(function()
                                loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))()
                            end)
                            if ok then
                                State.EmoteMenuLoaded = true
                            else
                                Window:Notify({ Title = TL("Error", "ข้อผิดพลาด"), Description = TL("Failed to load Emote Menu.", "โหลดเมนูอีโมตไม่สำเร็จ"), Lifetime = 4 })
                                return true
                            end
                        end
                        Config.EmoteMenuOpen = true
                        local emoteStateText = (Config.Language == "TH") and "เปิด" or "Enabled"
                        ShowToast(emoteStateText .. " : " .. TranslateUIRawText(displayName), Colors.Green)
                        pcall(function() UpdateToggleUIFromKeybind(featureKey) end)
                        return true
                    end

                    local newValue = not Config[featureKey]
                    if featureKey == "RTX_Enabled" and Config.RTX_Enabled then newValue = true end
                    Config[featureKey] = newValue
                    local stateText = ""
                    if Config.Language == "TH" then
                        stateText = newValue and "เปิด" or "ปิด"
                    else
                        stateText = newValue and "Enabled" or "Disabled"
                    end
                    ShowToast(stateText .. " : " .. TranslateUIRawText(displayName), newValue and Colors.Green or Colors.Red)
                    if featureKey == "WSToggle" then SetWalkSpeed(newValue) end
                    if featureKey == "JPToggle" then SetJumpPower(newValue) end
                    if featureKey == "FlyToggle" then SetFly(newValue) end
                    if featureKey == "Noclip" then SetNoclip(newValue) end
                    if featureKey == "InfJump" then SetInfJump(newValue) end
                    if featureKey == "AntiAFK" then SetAntiAFK(newValue) end
                    if featureKey == "AntiStun" then SetAntiStun(newValue) end
                    if featureKey == "InfZoom" then SetInfZoom(newValue) end
                    if featureKey == "FPSBooster" then if newValue then ApplyFPSBoost() else DisableFPSBoost() end end
                    if featureKey == "InvisToggle" then SetInvisibility(newValue) end
                    if featureKey == "HipHeightToggle" then SetHipHeight(newValue) end
                    if featureKey == "Fullbright_Toggle" then SetFullbright(newValue) end
                    if featureKey == "RemoveFog_Toggle" then SetRemoveFog(newValue) end
                    if featureKey == "RTX_Enabled" then SetRTX(newValue) end
                    if featureKey == "ChangeSky_Enabled" then SetChangeSky(newValue) end
                    if featureKey == "Aimlock" then if not newValue then LockedTarget = nil; State.ToggleAiming = false end end
                    if featureKey == "ShiftLock" then SetShiftLockActive(newValue) end
                    if featureKey == "CollisionBypass" then SetCollisionBypass(newValue) end
                    if featureKey == "FakeLag" then SetFakeLag(newValue) end
                    if featureKey == "Freecam" then SetFreecam(newValue) end
                    if featureKey == "TPGOSwitch" then
                        if newValue and Config.TPTarget ~= "-" then
                            local tp = Players:FindFirstChild(Config.TPTarget)
                            if tp then
                                if Config.TPMode == "Safe Fly" then
                                    StartSafeTP(tp)
                                else
                                    local tHRP = tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
                                    if tHRP and LocalPlayer.Character then
                                        pcall(function()
                                            LocalPlayer.Character:PivotTo(tHRP.CFrame * CFrame.new(0, 0, 3))
                                        end)
                                    end
                                end
                            end
                        else
                            StopSafeTP()
                        end
                    end
                    pcall(function() UpdateToggleUIFromKeybind(featureKey) end)
                    return true
                end
            end
        end
    end
    return false
end

function ProcessKeybindsRelease(input)
    NormalizeKeybindData()
    for featureKey, bindInfo in pairs(Config.Keybinds) do
        if featureKey ~= "ShiftLock" and bindInfo and bindInfo.Enabled then
            local mode = bindInfo.Mode or "Toggle"
            if mode == "Hold" then
                local matched = false
                if bindInfo.Type == "Keyboard" and input.UserInputType == Enum.UserInputType.Keyboard and bindInfo.Key then
                    matched = (input.KeyCode == bindInfo.Key)
                elseif bindInfo.Type == "Mouse" then
                    if bindInfo.Key == 1 then
                        matched = (input.UserInputType == Enum.UserInputType.MouseButton1)
                    elseif bindInfo.Key == 2 then
                        matched = (input.UserInputType == Enum.UserInputType.MouseButton2)
                    elseif bindInfo.Key == 3 then
                        matched = (input.UserInputType == Enum.UserInputType.MouseButton3)
                    end
                end
                if matched then
                    Config[featureKey] = false
                    if featureKey == "WSToggle" then SetWalkSpeed(false) end
                    if featureKey == "JPToggle" then SetJumpPower(false) end
                    if featureKey == "FlyToggle" then SetFly(false) end
                    if featureKey == "Noclip" then SetNoclip(false) end
                    if featureKey == "InfJump" then SetInfJump(false) end
                    if featureKey == "AntiAFK" then SetAntiAFK(false) end
                    if featureKey == "AntiStun" then SetAntiStun(false) end
                    if featureKey == "InfZoom" then SetInfZoom(false) end
                    if featureKey == "FPSBooster" then DisableFPSBoost() end
                    if featureKey == "InvisToggle" then SetInvisibility(false) end
                    if featureKey == "HipHeightToggle" then SetHipHeight(false) end
                    if featureKey == "Fullbright_Toggle" then SetFullbright(false) end
                    if featureKey == "RemoveFog_Toggle" then SetRemoveFog(false) end
                    if featureKey == "RTX_Enabled" then SetRTX(false) end
                    if featureKey == "ChangeSky_Enabled" then SetChangeSky(false) end
                    if featureKey == "ShiftLock" then SetShiftLockActive(false) end
                    if featureKey == "CollisionBypass" then SetCollisionBypass(false) end
                    if featureKey == "CollisionBounce" then SetCollisionBypass(false) end
                    if featureKey == "FakeLag" then SetFakeLag(false) end
                    if featureKey == "Freecam" then SetFreecam(false) end
                    if featureKey == "Aimlock" then State.ToggleAiming = false; LockedTarget = nil end
                    if featureKey == "TPGOSwitch" then StopSafeTP() end
                    pcall(function() UpdateToggleUIFromKeybind(featureKey) end)
                end
            end
        end
    end
end

-- [ SYSTEM RESTORE FACTORY RESET ]
function ResetAllSettings()
    if State.Resetting then return end
    State.Resetting = true
    State.Unloading = true
    State.Running = false
    Config.MenuVisible = false

    local o = _G._PwyvOrig or {}

    local resetDisconnectList = {
        "FPS_DescConn","InteractAddedConn","FogDescAddedConn","FogLightingDescConn","FogConn","FullbrightConn",
        "CollisionBypassConn","CollisionBypassCharAddedConn","CollisionBypassCharDescConn",
        "CollisionBypassHeartbeat","SafeTP_Conn","CFly_Loop","FlyDescConn","FlyWorkspaceDescConn","FlyNC_Heartbeat",
        "WS_Loop","JP_Loop","NC_Conn","NC_DescConn","NC_WorkspaceDescConn","NC_Heartbeat","IJ_Conn","AFK_Conn","AntiStun_Loop",
        "ShiftLockConn","CurrentClickTPConnection"
    }
    for _, key in ipairs(resetDisconnectList) do
        local cn = Conns[key]
        if cn and typeof(cn) == "RBXScriptConnection" then pcall(function() cn:Disconnect() end) end
        Conns[key] = nil
    end
    Conns.NC_TrackedChar = nil
    Conns.FlyTrackedChar = nil
    for _, cn in ipairs(Connections) do
        if cn and typeof(cn) == "RBXScriptConnection" then
            pcall(function() cn:Disconnect() end)
        end
    end
    table.clear(Connections)
    LanguageDescConn = nil
    table.clear(LanguageUpdaters)
    pcall(function() StopCurrentClickTP() end)
    Conns.CurrentClickTPWalking = false
    SafeDestroy(FlyBG)
    FlyBG = nil
    SafeDestroy(FlyBV)
    FlyBV = nil
    SafeDestroy(FlyAtt)
    FlyAtt = nil

    pcall(function() ResetNoCollideRegistry() end)
    RestoreOriginalState(o)

    for k, v in pairs(Config) do if type(v) == "boolean" then Config[k] = false end end
    SafeRemoveDrawing(UI.Circle)
    UI.Circle = nil

    if _G._PwyvWindow then
        pcall(function() _G._PwyvWindow:Unload() end)
        _G._PwyvWindow = nil
    end

    SafeDestroy(UI.ScreenGui)
    UI.ScreenGui = Instance.new("ScreenGui", CoreGui)
    UI.ScreenGui.Name = "PhwyverysadOverlay"
    UI.ScreenGui.ResetOnSpawn = false
    UI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    UI.StatHUD = Instance.new("TextLabel", UI.ScreenGui)
    UI.StatHUD.Size = UDim2.new(0, 165, 0, 32)
    UI.StatHUD.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    UI.StatHUD.BackgroundTransparency = 1
    UI.StatHUD.TextColor3 = Color3.fromRGB(0, 240, 150)
    UI.StatHUD.Font = Enum.Font.GothamBold
    UI.StatHUD.TextStrokeTransparency = 0.3
    UI.StatHUD.TextStrokeColor3 = Color3.new(0, 0, 0)
    UI.StatHUD.TextSize = 16
    UI.StatHUD.Visible = false
    Instance.new("UIPadding", UI.StatHUD).PaddingLeft = UDim.new(0, 10)
    UI.StatHUD.TextXAlignment = Enum.TextXAlignment.Left

    local function CopyTable(orig)
        local copy = {}
        for k, v in pairs(orig) do
            if typeof(v) == "Color3" or typeof(v) == "EnumItem" then copy[k] = v
            elseif type(v) == "table" then copy[k] = CopyTable(v)
            else copy[k] = v end
        end
        return copy
    end

    local selectedLanguage = Config.Language
    local newCfg = CopyTable(initialConfig)
    for k, v in pairs(newCfg) do Config[k] = v end
    if selectedLanguage == "TH" or selectedLanguage == "EN" then
        Config.Language = selectedLanguage
    end

    for k in pairs(State) do State[k] = nil end
    for k, v in pairs(initialState) do State[k] = v end
    State.Resetting = true
    State.Unloading = false
    State.Running = true

    table.clear(AllRows)
    table.clear(AllRowFrames)
    table.clear(ThemeRefs)
    table.clear(Tabs)

    -- Re-init window structure
    if _G._PwyvWindow then
        pcall(function() _G._PwyvWindow:Unload() end)
        _G._PwyvWindow = nil
    end
    Window = MacLib:Window({
        Title = "phwyverysad",
        Subtitle = "v0.0.1",
        Size = UDim2.fromOffset(868, 650),
        DragStyle = 1,
        DisabledWindowControls = {},
        ShowUserInfo = true,
        Keybind = Enum.KeyCode.RightControl,
        AcrylicBlur = true,
    })
    _G._PwyvWindow = Window
    RebuildTabHandles()

    BuildAllTabs()
    EnsureLanguageHooks()
    ApplyLanguageUI()
    pcall(function() UpdateHUDPos() end)
    pcall(function() ApplyTheme(Config.Theme or "Midnight") end)

    ShowToast("♻️ รีเซ็ตค่าการตั้งค่าทั้งหมดเสร็จสิ้น", Colors.PrimaryBlue)
    State.Resetting = false
end

-- [ INPUT EVENT RECEIVER ]
AddConn(UIS.InputBegan:Connect(function(input, gp)
    if gp or State.Binding then return end
    NormalizeKeybindData()
    if ProcessKeybinds(input) then return end

    if Config.MenuToggleBindType and Config.MenuToggleBindKey and Window then
        local menuHit = false
        if Config.MenuToggleBindType == "Keyboard" and input.UserInputType == Enum.UserInputType.Keyboard then
            menuHit = (input.KeyCode == Config.MenuToggleBindKey)
        elseif Config.MenuToggleBindType == "Mouse" then
            if Config.MenuToggleBindKey == 1 then
                menuHit = (input.UserInputType == Enum.UserInputType.MouseButton1)
            elseif Config.MenuToggleBindKey == 2 then
                menuHit = (input.UserInputType == Enum.UserInputType.MouseButton2)
            elseif Config.MenuToggleBindKey == 3 then
                menuHit = (input.UserInputType == Enum.UserInputType.MouseButton3)
            end
        end
        if menuHit then
            Config.MenuVisible = not Config.MenuVisible
            pcall(function() Window:SetState(Config.MenuVisible) end)
            return
        end
    end
    
    if Config.ShiftLock_Enabled and Config.ShiftLock_BindType and Config.ShiftLock_BindKey then
        local matched = false
        if Config.ShiftLock_BindType == "Keyboard" and input.UserInputType == Enum.UserInputType.Keyboard then
            matched = (input.KeyCode == Config.ShiftLock_BindKey)
        elseif Config.ShiftLock_BindType == "Mouse" then
            if Config.ShiftLock_BindKey == 1 then matched = (input.UserInputType == Enum.UserInputType.MouseButton1)
            elseif Config.ShiftLock_BindKey == 2 then matched = (input.UserInputType == Enum.UserInputType.MouseButton2)
            elseif Config.ShiftLock_BindKey == 3 then matched = (input.UserInputType == Enum.UserInputType.MouseButton3) end
        end
        if matched then SetShiftLockActive(not Config.ShiftLock_Active); return end
    end

    if Config.Aimlock and Config.AimMode == "TOGGLE" then
        local hit = false
        if Config.BindType == "Mouse" then 
            local mb = Config.BindKey == 1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
            hit = (input.UserInputType == mb)
        elseif Config.BindType == "Keyboard" and Config.BindKey then 
            hit = (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.BindKey) 
        end
        if hit then State.ToggleAiming = not State.ToggleAiming; if not State.ToggleAiming then LockedTarget = nil end end
    end

    if Config.ClickTPToggle and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local modifierPressed = false
        if Config.ClickTPBindType == "Keyboard" and Config.ClickTPBindKey then
            modifierPressed = UIS:IsKeyDown(Config.ClickTPBindKey)
        elseif Config.ClickTPBindType == "Mouse" and Config.ClickTPBindKey then
            local mb = Config.ClickTPBindKey == 1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2
            modifierPressed = UIS:IsMouseButtonPressed(mb)
        end
        if modifierPressed then if Mouse.Hit then pcall(function() ExecuteClickTP(Mouse.Hit.Position) end) end end
    end
end))

AddConn(UIS.InputEnded:Connect(function(input, gp)
    if gp or State.Binding then return end
    ProcessKeybindsRelease(input)
end))

function IsAimKeyHeld()
    if Config.BindType == "Mouse" then 
        local mb = Enum.UserInputType.MouseButton1
        if Config.BindKey == 2 then
            mb = Enum.UserInputType.MouseButton2
        elseif Config.BindKey == 3 then
            mb = Enum.UserInputType.MouseButton3
        end
        return UIS:IsMouseButtonPressed(mb)
    elseif Config.BindType == "Keyboard" and Config.BindKey then 
        return UIS:IsKeyDown(Config.BindKey) 
    end
    return false
end

-- [ MAIN GAME RENDER STEPPED SYSTEM ]
local HitboxCharsPool = {}
local CurrentHitboxedPool = {}
local RenderCenter = Vector2.new(0, 0)
local LastHitboxTick = 0
local LastESPTick = 0
local HITBOX_UPDATE_INTERVAL = 0.12
local ESP_UPDATE_INTERVAL = 0.05
AddConn(RunService.RenderStepped:Connect(function()
    if not State.Running then return end
    Camera = workspace.CurrentCamera
    
    if Config.ShowStatsToggle then 
        UI.StatHUD.Visible = true
        if Config.ShowFPSPing == "FPS" then
            if Config.Language == "TH" then
                UI.StatHUD.Text = "เฟรมเรต: " .. Stats.lastFPS
            else
                UI.StatHUD.Text = "FPS: " .. Stats.lastFPS
            end
        elseif Config.ShowFPSPing == "Ping" then
            if Config.Language == "TH" then
                UI.StatHUD.Text = "ปิง: " .. Stats.pingValue .. " มิลลิวินาที"
            else
                UI.StatHUD.Text = "Ping: " .. Stats.pingValue .. "ms"
            end
        else
            if Config.Language == "TH" then
                UI.StatHUD.Text = "เฟรมเรต: " .. Stats.lastFPS .. " | ปิง: " .. Stats.pingValue .. " มิลลิวินาที"
            else
                UI.StatHUD.Text = "FPS: " .. Stats.lastFPS .. " | Ping: " .. Stats.pingValue .. "ms"
            end
        end
    else 
        UI.StatHUD.Visible = false 
    end

    local LPChar = LocalPlayer.Character
    local LPHum = LPChar and LPChar:FindFirstChildOfClass("Humanoid")
    local LPHRP = LPChar and LPChar:FindFirstChild("HumanoidRootPart")

    if Config.RemoveFog_Toggle and not Config.Fullbright_Toggle then
        pcall(function() Lighting.FogEnd = 9e9 end)
    end

    if Config.FOVToggle then
        pcall(function()
            local baseFOV = math.clamp(Config.FOVView, 30, 120)
            Camera.FieldOfView = baseFOV
            if Config.FOVView > 120 then
                local extra = Config.FOVView - 120
                Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, extra * 0.1) 
            end
        end)
    end



    if Config.SpecToggle and Config.SpecTarget ~= "-" then 
        local sp = Players:FindFirstChild(Config.SpecTarget)
        if sp and sp.Character then 
            local sh = sp.Character:FindFirstChildOfClass("Humanoid")
            if sh and Camera.CameraSubject ~= sh then Camera.CameraSubject = sh end 
        end
    elseif not Config.SpecToggle and LPHum and Camera.CameraSubject ~= LPHum then 
        Camera.CameraSubject = LPHum 
    end

    if Config.TPGOSwitch and Config.TPTarget ~= "-" and Config.TPMode == "Warp" and LPChar then
        local now = tick()
        if now - Stats.lastWarpTick >= 0.5 then 
            Stats.lastWarpTick = now
            local tp = Players:FindFirstChild(Config.TPTarget)
            if tp and tp.Character then 
                local tHRP = tp.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then pcall(function() LPChar:PivotTo(tHRP.CFrame * CFrame.new(0, 0, 3)) end) end 
            end 
        end
    end

    local nowTick = tick()
    local doHitboxUpdate = (nowTick - LastHitboxTick) >= HITBOX_UPDATE_INTERVAL
    local doESPUpdate = (nowTick - LastESPTick) >= ESP_UPDATE_INTERVAL
    if doHitboxUpdate then LastHitboxTick = nowTick end
    if doESPUpdate then LastESPTick = nowTick end

    if Config.P_HitboxToggle and doHitboxUpdate then
        table.clear(HitboxCharsPool)
        local hMode = Config.HitboxTargetMode

        if hMode == "PLAYERS ONLY" or hMode == "PLAYERS & NPCs" then
            for char, _ in pairs(ValidTargets) do
                local owner = Players:GetPlayerFromCharacter(char)
                if owner and owner ~= LocalPlayer then
                    table.insert(HitboxCharsPool, char)
                end
            end
        end
        if hMode == "NPCs ONLY" or hMode == "PLAYERS & NPCs" then
            for char, _ in pairs(ValidTargets) do
                local owner = Players:GetPlayerFromCharacter(char)
                if not owner then
                    table.insert(HitboxCharsPool, char)
                end
            end
        end

        table.clear(CurrentHitboxedPool)
        for _, char in ipairs(HitboxCharsPool) do
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                CurrentHitboxedPool[char] = true
                if not HitboxOriginalSizes[char] then HitboxOriginalSizes[char] = hrp.Size end
                hrp.Size = Vector3.new(Config.P_HitboxSize, Config.P_HitboxSize, Config.P_HitboxSize)
                hrp.Transparency = 0.6
                hrp.Material = Enum.Material.Neon
                hrp.Color = Colors.PrimaryBlue
                hrp.CanCollide = false
            end
        end

        for char, origSize in pairs(HitboxOriginalSizes) do
            if not CurrentHitboxedPool[char] then
                pcall(function()
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.Size = origSize; hrp.Transparency = 1; hrp.Material = Enum.Material.SmoothPlastic; hrp.CanCollide = true end
                end)
                HitboxOriginalSizes[char] = nil
            end
        end
    end

    local vp = Camera.ViewportSize
    local aimOrEspOrHitboxEnabled = (Config.Aimlock == true) or (Config.P_Master == true) or (Config.P_HitboxToggle == true)
    if not aimOrEspOrHitboxEnabled then
        if UI.Circle then
            UI.Circle.Visible = false
        end
        if LockedTarget then
            LockedTarget = nil
        end
        for _, e in pairs(ESP_Cache) do
            pcall(function() e.Gui.Enabled = false; e.Highlight.Enabled = false end)
        end
        return
    end

    local isAimingNow = false
    if Config.Aimlock then
        if Config.AimMode == "ALWAYS ON" then isAimingNow = true
        elseif Config.AimMode == "HOLD" then isAimingNow = IsAimKeyHeld()
        else isAimingNow = State.ToggleAiming end
    end
    if not isAimingNow then LockedTarget = nil end

    if vp.X > 0 then
        if typeof(Config.FOVColor_C3) ~= "Color3" then
            Config.FOVColor_C3 = Color3.fromRGB(30,161,255)
        end
        UI.Circle.Radius = (math.min(vp.X, vp.Y) / 2) * (Config.FOV / 100)
        UI.Circle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        UI.Circle.Color = Config.FOVColor_C3 or Colors.PrimaryBlue
        
        if Config.FOVShowMode == "On Aiming" then
            UI.Circle.Visible = (Config.Aimlock == true) and isAimingNow
        else
            UI.Circle.Visible = Config.Aimlock == true
        end
    end

    local runESP = (Config.P_Master == true)
    if not Config.Aimlock then
        isAimingNow = false
    end
    if (not runESP) and (not isAimingNow) and (not Config.P_HitboxToggle) then
        if UI.Circle then
            if Config.FOVShowMode == "On Aiming" then
                UI.Circle.Visible = false
            else
                UI.Circle.Visible = Config.Aimlock == true
            end
        end
        for _, e in pairs(ESP_Cache) do
            pcall(function() e.Gui.Enabled = false; e.Highlight.Enabled = false end)
        end
        return
    end

    RenderCenter = Vector2.new(vp.X / 2, vp.Y / 2)
    local bestHead, bestScore = nil, math.huge
    local LPHRP2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for char, nameStr in pairs(ValidTargets) do
        local head, hrp, hum = GetCharacterParts(char)
        if not char.Parent then
            local e = ESP_Cache[char]; if e then pcall(function() e.Gui.Enabled = false; e.Highlight.Enabled = false end) end
        elseif not (hum and hum.Health > 0) then
            local e = ESP_Cache[char]; if e then pcall(function() e.Gui.Enabled = false; e.Highlight.Enabled = false end) end
        elseif not (hrp or head) then
            local e = ESP_Cache[char]; if e then pcall(function() e.Gui.Enabled = false; e.Highlight.Enabled = false end) end
        else
            local refPart = hrp or head
            local esp = ESP_Cache[char]
            local rPos, rVis = Camera:WorldToViewportPoint(refPart.Position)
            local scr2D = Vector2.new(rPos.X, rPos.Y)
            local dxCenter = rPos.X - RenderCenter.X
            local dyCenter = rPos.Y - RenderCenter.Y
            local scrDistCenter = math.sqrt(dxCenter * dxCenter + dyCenter * dyCenter)
            local inFOV = rVis and scrDistCenter <= UI.Circle.Radius
            local hpPct = math.floor((hum.Health / math.max(hum.MaxHealth, 1)) * 100)

            local ownerPlayer = Players:GetPlayerFromCharacter(char)
            local isPlayer = (ownerPlayer ~= nil)

            local validTarget = false
        if Config.P_TargetMode == "PLAYERS ONLY" and isPlayer then validTarget = true
        elseif Config.P_TargetMode == "NPCs ONLY" and not isPlayer then validTarget = true
        elseif Config.P_TargetMode == "PLAYERS & NPCs" then validTarget = true end

        local useP = validTarget and runESP
        local showESP = useP and rVis and rPos.Z > 0 and rPos.Z < 2000

        if useP and Config.P_ESPInFOVOnly and not inFOV then showESP = false end
        if showESP and isPlayer then
            local p = ownerPlayer
            local skipTeam = (Config.P_TeamCheck) and (p.Team == LocalPlayer.Team)
            if skipTeam then showESP = false end
        end

        if showESP then
            if not esp then
                esp = GetESP(char)
            end
            local col
            if isPlayer then
                local p = ownerPlayer
                if typeof(Config.P_Color_C3) ~= "Color3" then
                    Config.P_Color_C3 = Color3.fromRGB(255,255,255)
                end
                col = (Config.P_TeamColor) and p.TeamColor.Color or Config.P_Color_C3
            else col = Color3.new(1,1,1) end
            if doESPUpdate then
                local espAdornee = head or hrp or char:FindFirstChildWhichIsA("BasePart")
                esp.Gui.Adornee = espAdornee
                esp.Gui.Enabled = true
                local info = {}
                if Config.P_ShowName then table.insert(info, (ownerPlayer and (ownerPlayer.DisplayName or ownerPlayer.Name)) or nameStr or char.Name) end
                if Config.P_ShowHealth then table.insert(info, "HP: " .. hpPct .. "%") end
                if Config.P_ShowDist then table.insert(info, "[" .. math.floor(rPos.Z) .. "m]") end
                esp.Label.Text = table.concat(info, "\n")
                esp.Label.TextColor3 = col
                esp.Label.TextSize = Config.P_TextSize
                esp.Highlight.Adornee = char
                esp.Highlight.Enabled = Config.P_Highlight
                esp.Highlight.FillColor = col
                esp.Highlight.FillTransparency = Config.P_FillTrans
                esp.Highlight.OutlineColor = col
                esp.Highlight.OutlineTransparency = Config.P_OutlineTrans
            end
        else
            if esp then
                pcall(function()
                    esp.Gui.Enabled = false
                    esp.Highlight.Enabled = false
                end)
            end
        end

        local targetPart = GetTargetPart(char)
        if isAimingNow and not LockedTarget and inFOV and rVis and rPos.Z > 0 and targetPart then
            local isEnemy = true
            if isPlayer and Config.EnemyOnly then
                if ownerPlayer.Team ~= nil and LocalPlayer.Team ~= nil then isEnemy = (ownerPlayer.Team ~= LocalPlayer.Team) else isEnemy = true end
            end
            if isEnemy and IsVisible(targetPart) then
                local scrDist = scrDistCenter
                local playerPos = LPHRP2 and LPHRP2.Position or Camera.CFrame.Position
                local wldDist = (refPart.Position - playerPos).Magnitude
                
                local normScr = scrDist / (UI.Circle.Radius + 0.001)
                local normWld = math.clamp(wldDist / 500, 0, 1)
                local score = (normScr * 0.5 + normWld * 0.5)
                
                if wldDist < 50 then score = score * 0.7
                elseif wldDist < 100 then score = score * 0.85 end
                
                if score < bestScore then bestHead = targetPart; bestScore = score end
            end
        end
        if LockedTarget == targetPart and hum.Health <= 0 then LockedTarget = nil end
    end
    end

    if isAimingNow and not LockedTarget and bestHead then LockedTarget = bestHead end
    if isAimingNow and LockedTarget then
        if LockedTarget and LockedTarget.Parent then
            local lhum = LockedTarget.Parent:FindFirstChildOfClass("Humanoid")
            if lhum and lhum.Health > 0 then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, LockedTarget.Position), math.clamp(Config.AimSmooth, 0.01, 1))
            else LockedTarget = nil end
        else LockedTarget = nil end
    end
end))

-- [ POST INITIALIZATION AND LOOPS ]
AddConn(RunService.RenderStepped:Connect(function()
    if State.Running and Config.MapTimeEnabled then
        pcall(function()
            game:GetService("Lighting").ClockTime = Config.MapTimeValue or 12
        end)
    end
end))

task.spawn(function()
    task.wait(0.5)
    if Config.InfZoom then SetInfZoom(true) end
    if Config.InstantPress or Config.AuraRange then UpdateInteractables() end
    if Config.ShowStatsToggle then pcall(function() UI.StatHUD.Visible = true end) end
    if Config.ChangeSky_Enabled then
        local id = SkyOptions[Config.ChangeSky_Selected]
        if id then ApplySkyById(id) end
    end
end)

task.spawn(function() 
    while State.Running do 
        task.wait(1)
        Stats.lastFPS = Stats.frameCount
        Stats.frameCount = 0
        pcall(function() 
            Stats.pingValue = math.round(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) 
        end) 
    end 
end)

task.spawn(function()   
    task.wait(0.75)
    UpdateHUDPos()
    if Themes[Config.Theme] then ApplyTheme(Config.Theme) end
end)


end