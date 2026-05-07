local RunService = game:GetService("RunService")
local Lighting   = game:GetService("Lighting")
local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local PHYSICS = {
    EARTH_TILT = math.rad(23.5),
    EARTH_RADIUS = 6371000,
    ATMOSPHERE_HEIGHT = 80000,
    SOLAR_CONSTANT = 1361,
    RAYLEIGH_R = 0.0058,
    RAYLEIGH_G = 0.0135,
    RAYLEIGH_B = 0.0331,
    MIE_COEFF = 0.0021,
    MIE_DIRECTIONAL_G = 0.76,
    N_RED = 1.514,
    N_GREEN = 1.519,
    N_BLUE = 1.524,
    WATER_REFRACTIVE_INDEX = 1.333,
    WATER_SPECULAR_POWER = 256,
    WATER_REFLECTIVITY = 0.6,
    RAIN_DENSITY_CLEAR = 0,
    RAIN_DENSITY_LIGHT = 500,
    RAIN_DENSITY_HEAVY = 2000,
    RAIN_DENSITY_STORM = 5000,
    RAIN_DROP_SIZE = 0.08,
    RAIN_FALL_SPEED = 15,
    RAIN_SPLASH_SIZE = 0.3,
    FRESNEL_POWER = 5.0,
}

local CFG = {
    Vignette      = true,
    ChromaAberr   = true,
    Letterbox     = true,
    LensFlare     = true,
    DynamicCycle  = true,
    RainSystem    = true,
    WetReflections = true,
    VolumetricLights = true,
    ScreenSpaceReflections = true,
    TimeStart     = 5.0,
    TimeEnd       = 22.0,
    CycleDuration = 300,
    RealTimeSync  = false,
    BreathFreq    = 0.15,
    BreathAmp     = 0.01,
    AO_Rays       = 32,
    AO_Distance   = 75,
    AO_Interval   = 6,
    Sun_Interval  = 1,
    GI_Interval   = 4,
    GI_MaxDist    = 150,
    GI_Strength   = 0.45,
    AO_AmbStrength= 0.85,
    GI_Bounces    = 2,
    Specular_Rays = 8,
    Shadow_Samples = 16,
    RainEnabled   = true,
    SSR_MaxSteps = 64,
    SSR_StepSize = 0.5,
    SSR_Thickness = 0.1,
    SSR_MaxDistance = 100,
    VolLight_Samples = 32,
    VolLight_Scattering = 0.3,
    VolLight_Intensity = 1.5,
    ColorSpace    = "ACES",
    ToneMapper    = "AgX",
    FilmGrain     = 0.02,
}

local ColorScience = {}

function ColorScience.ACESFilm(x)
    local a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return math.clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0, 1)
end

function ColorScience.AgX(x)
    local y = math.max(0, x)
    return y / (y + 0.155) * 1.019
end

function ColorScience.LinearToSRGB(c)
    if c <= 0.0031308 then
        return c * 12.92
    else
        return 1.055 * math.pow(c, 1/2.4) - 0.055
    end
end

function ColorScience.SRGBToLinear(c)
    if c <= 0.04045 then
        return c / 12.92
    else
        return math.pow((c + 0.055) / 1.055, 2.4)
    end
end

function ColorScience.KelvinToRGB(kelvin)
    local temp = kelvin / 100
    local r, g, b

    if temp <= 66 then
        r = 255
    else
        r = 329.698727446 * math.pow(temp - 60, -0.1332047592)
        r = math.clamp(r, 0, 255)
    end

    if temp <= 66 then
        g = 99.4708025861 * math.log(temp) - 161.1195681661
    else
        g = 288.1221695283 * math.pow(temp - 60, -0.0755148492)
    end
    g = math.clamp(g, 0, 255)

    if temp >= 66 then
        b = 255
    elseif temp <= 19 then
        b = 0
    else
        b = 138.5177312231 * math.log(temp - 10) - 305.0447927307
        b = math.clamp(b, 0, 255)
    end

    return Color3.fromRGB(math.floor(r), math.floor(g), math.floor(b))
end

function ColorScience.FresnelReflectance(cosTheta, n1, n2)
    local r0 = ((n1 - n2) / (n1 + n2)) ^ 2
    return r0 + (1 - r0) * math.pow(1 - cosTheta, PHYSICS.FRESNEL_POWER)
end

local Astronomy = {}

function Astronomy.CalculateSunPosition(clockTime, latitude, dayOfYear)
    local hourAngle = math.rad((clockTime - 12) * 15)
    local declination = PHYSICS.EARTH_TILT * math.sin(math.rad((360/365) * (dayOfYear - 81)))
    local latRad = math.rad(latitude)

    local sinElevation = math.sin(latRad) * math.sin(declination) + 
                        math.cos(latRad) * math.cos(declination) * math.cos(hourAngle)
    local elevation = math.asin(sinElevation)

    local cosAzimuth = (math.sin(declination) - math.sin(latRad) * sinElevation) / 
                       (math.cos(latRad) * math.cos(elevation))
    cosAzimuth = math.clamp(cosAzimuth, -1, 1)
    local azimuth = math.acos(cosAzimuth)

    if hourAngle > 0 then
        azimuth = 2 * math.pi - azimuth
    end

    return elevation, azimuth
end

function Astronomy.CalculateAtmosphere(elevation)
    if elevation <= 0 then
        return Color3.new(0.02, 0.03, 0.08), 0.1
    end

    local zenith = math.pi/2 - elevation
    local cosZenith = math.cos(zenith)
    local opticalDepth = 1 / (cosZenith + 0.15 * math.pow(93.885 - math.deg(zenith), -1.253))

    local rayleighR = math.exp(-opticalDepth * PHYSICS.RAYLEIGH_R)
    local rayleighG = math.exp(-opticalDepth * PHYSICS.RAYLEIGH_G)
    local rayleighB = math.exp(-opticalDepth * PHYSICS.RAYLEIGH_B)

    local mie = math.exp(-opticalDepth * PHYSICS.MIE_COEFF)

    local skyR = rayleighR * 0.3 + mie * 0.7
    local skyG = rayleighG * 0.3 + mie * 0.7
    local skyB = rayleighB * 0.5 + mie * 0.5

    local intensity = math.max(0, math.sin(elevation))

    return Color3.new(
        math.clamp(skyR * intensity, 0, 1),
        math.clamp(skyG * intensity, 0, 1),
        math.clamp(skyB * intensity, 0, 1)
    ), intensity
end

function Astronomy.GetColorTemperature(elevation)
    if elevation < 0 then
        return 4000
    elseif elevation < math.rad(10) then
        return 3000 + (4500 - 3000) * (elevation / math.rad(10))
    elseif elevation < math.rad(30) then
        return 4500 + (5500 - 4500) * ((elevation - math.rad(10)) / math.rad(20))
    else
        return 5500 + (6500 - 5500) * math.min(1, (elevation - math.rad(30)) / math.rad(30))
    end
end

local MathUtils = {}

function MathUtils.lerpN(a, b, t)
    return a + (b - a) * t
end

function MathUtils.lerpC(a, b, t)
    return Color3.new(
        MathUtils.lerpN(a.R, b.R, t),
        MathUtils.lerpN(a.G, b.G, t),
        MathUtils.lerpN(a.B, b.B, t)
    )
end

function MathUtils.smoothStep(t, tension)
    tension = tension or 3
    if tension == 3 then
        return t * t * t * (t * (t * 6 - 15) + 10)
    else
        local p = math.floor(tension)
        local result = 0
        for i = 0, p do
            local sign = (i % 2 == 0) and 1 or -1
            result = result + sign * math.comb(p, i) * math.pow(t, p + i)
        end
        return math.clamp(result, 0, 1)
    end
end

function MathUtils.noise(x)
    return math.sin(x * 12.9898) * 43758.5453 % 1
end

function MathUtils.perlinNoise(x, y)
    return (math.sin(x * 12.9898 + y * 78.233) * 43758.5453) % 1
end

for _, v in pairs(Lighting:GetChildren()) do
    if not v:IsA("Sky") then
        v:Destroy()
    end
end

local Bloom    = Instance.new("BloomEffect")
local ColorCor = Instance.new("ColorCorrectionEffect")
local SunRays  = Instance.new("SunRaysEffect")
local Blur     = Instance.new("BlurEffect")
local DepthOfField = Instance.new("DepthOfFieldEffect")

Bloom.Parent    = Lighting
ColorCor.Parent = Lighting
SunRays.Parent  = Lighting
Blur.Parent     = Lighting
DepthOfField.Parent = Lighting

Blur.Enabled = false
DepthOfField.Enabled = false

Lighting.Technology              = Enum.LightingTechnology.Future
Lighting.GeographicLatitude      = 35
Lighting.GlobalShadows           = true
Lighting.ShadowSoftness          = 0.02
Lighting.ColorShift_Bottom       = Color3.fromRGB(0, 0, 0)
Lighting.EnvironmentDiffuseScale  = 0.40
Lighting.EnvironmentSpecularScale = 0.80
Lighting.FogStart                = 1000000
Lighting.FogEnd                   = 1000000
Lighting.Brightness               = 1.5

local Sky = Instance.new("Sky")
Sky.Parent = Lighting

Sky.SkyboxBk = "http://www.roblox.com/asset/?id=151165214"
Sky.SkyboxDn = "http://www.roblox.com/asset/?id=151165197"
Sky.SkyboxFt = "http://www.roblox.com/asset/?id=151165224"
Sky.SkyboxLf = "http://www.roblox.com/asset/?id=151165191"
Sky.SkyboxRt = "http://www.roblox.com/asset/?id=151165206"
Sky.SkyboxUp = "http://www.roblox.com/asset/?id=151165227"

Sky.SunAngularSize  = 6
Sky.MoonAngularSize = 5
Sky.StarCount       = 8000

local KF = {
    [5.0] = {
        name = "Dawn",
        lightBri = 0.8, expComp = -0.15,
        ambient = Color3.fromRGB(25, 30, 45),
        cShiftTop = Color3.fromRGB(255, 140, 90),
        cShiftBottom = Color3.fromRGB(80, 60, 100),
        bloomI = 0.12, bloomS = 12, bloomT = 0.92,
        ccBri = -0.03, ccCon = 0.85, ccSat = 0.60,
        tint = Color3.fromRGB(255, 220, 190),
        srI = 0.25, srSpr = 0.65,
        envDiff = 0.35, envSpec = 0.65,
        kelvin = 3200,
        fogDensity = 0.3,
        starVisibility = 0.2,
        rainProbability = 0.1,
        wetness = 0.2,
    },
    [7.0] = {
        name = "Sunrise",
        lightBri = 1.3, expComp = 0.10,
        ambient = Color3.fromRGB(45, 40, 50),
        cShiftTop = Color3.fromRGB(255, 180, 120),
        cShiftBottom = Color3.fromRGB(120, 90, 80),
        bloomI = 0.18, bloomS = 14, bloomT = 0.88,
        ccBri = 0.00, ccCon = 0.88, ccSat = 0.70,
        tint = Color3.fromRGB(255, 235, 210),
        srI = 0.35, srSpr = 0.75,
        envDiff = 0.40, envSpec = 0.70,
        kelvin = 4500,
        fogDensity = 0.2,
        starVisibility = 0.0,
        rainProbability = 0.15,
        wetness = 0.3,
    },
    [10.0] = {
        name = "Morning",
        lightBri = 1.8, expComp = 0.25,
        ambient = Color3.fromRGB(80, 85, 95),
        cShiftTop = Color3.fromRGB(255, 245, 235),
        cShiftBottom = Color3.fromRGB(150, 145, 140),
        bloomI = 0.08, bloomS = 8, bloomT = 0.95,
        ccBri = 0.02, ccCon = 0.82, ccSat = 0.75,
        tint = Color3.fromRGB(255, 252, 245),
        srI = 0.15, srSpr = 0.40,
        envDiff = 0.45, envSpec = 0.75,
        kelvin = 5500,
        fogDensity = 0.1,
        starVisibility = 0.0,
        rainProbability = 0.2,
        wetness = 0.1,
    },
    [12.0] = {
        name = "Noon",
        lightBri = 2.0, expComp = 0.35,
        ambient = Color3.fromRGB(110, 115, 125),
        cShiftTop = Color3.fromRGB(255, 255, 250),
        cShiftBottom = Color3.fromRGB(200, 200, 195),
        bloomI = 0.05, bloomS = 6, bloomT = 0.98,
        ccBri = 0.03, ccCon = 0.80, ccSat = 0.80,
        tint = Color3.fromRGB(255, 255, 255),
        srI = 0.10, srSpr = 0.25,
        envDiff = 0.50, envSpec = 0.85,
        kelvin = 6500,
        fogDensity = 0.05,
        starVisibility = 0.0,
        rainProbability = 0.25,
        wetness = 0.0,
    },
    [15.0] = {
        name = "Afternoon",
        lightBri = 1.6, expComp = 0.20,
        ambient = Color3.fromRGB(95, 90, 85),
        cShiftTop = Color3.fromRGB(255, 240, 220),
        cShiftBottom = Color3.fromRGB(160, 150, 140),
        bloomI = 0.10, bloomS = 10, bloomT = 0.94,
        ccBri = 0.01, ccCon = 0.85, ccSat = 0.75,
        tint = Color3.fromRGB(255, 248, 235),
        srI = 0.18, srSpr = 0.45,
        envDiff = 0.45, envSpec = 0.75,
        kelvin = 5800,
        fogDensity = 0.1,
        starVisibility = 0.0,
        rainProbability = 0.3,
        wetness = 0.1,
    },
    [17.0] = {
        name = "Golden Hour",
        lightBri = 1.4, expComp = 0.15,
        ambient = Color3.fromRGB(60, 45, 35),
        cShiftTop = Color3.fromRGB(255, 170, 90),
        cShiftBottom = Color3.fromRGB(140, 100, 70),
        bloomI = 0.22, bloomS = 16, bloomT = 0.85,
        ccBri = -0.02, ccCon = 0.90, ccSat = 0.80,
        tint = Color3.fromRGB(255, 210, 170),
        srI = 0.40, srSpr = 0.80,
        envDiff = 0.35, envSpec = 0.60,
        kelvin = 3800,
        fogDensity = 0.25,
        starVisibility = 0.1,
        rainProbability = 0.35,
        wetness = 0.3,
    },
    [19.0] = {
        name = "Sunset",
        lightBri = 0.6, expComp = -0.05,
        ambient = Color3.fromRGB(25, 20, 25),
        cShiftTop = Color3.fromRGB(255, 90, 50),
        cShiftBottom = Color3.fromRGB(100, 60, 60),
        bloomI = 0.28, bloomS = 18, bloomT = 0.80,
        ccBri = -0.05, ccCon = 0.92, ccSat = 0.85,
        tint = Color3.fromRGB(255, 190, 150),
        srI = 0.30, srSpr = 0.70,
        envDiff = 0.25, envSpec = 0.45,
        kelvin = 2800,
        fogDensity = 0.35,
        starVisibility = 0.3,
        rainProbability = 0.4,
        wetness = 0.5,
    },
    [20.5] = {
        name = "Blue Hour",
        lightBri = 0.25, expComp = -0.15,
        ambient = Color3.fromRGB(10, 15, 30),
        cShiftTop = Color3.fromRGB(80, 100, 160),
        cShiftBottom = Color3.fromRGB(40, 50, 80),
        bloomI = 0.10, bloomS = 10, bloomT = 0.92,
        ccBri = -0.08, ccCon = 0.85, ccSat = 0.50,
        tint = Color3.fromRGB(190, 200, 230),
        srI = 0.05, srSpr = 0.30,
        envDiff = 0.15, envSpec = 0.25,
        kelvin = 8000,
        fogDensity = 0.4,
        starVisibility = 0.6,
        rainProbability = 0.5,
        wetness = 0.7,
    },
    [22.0] = {
        name = "Deep Night",
        lightBri = 0.05, expComp = -0.30,
        ambient = Color3.fromRGB(2, 3, 8),
        cShiftTop = Color3.fromRGB(15, 25, 60),
        cShiftBottom = Color3.fromRGB(5, 8, 20),
        bloomI = 0.03, bloomS = 4, bloomT = 0.98,
        ccBri = -0.15, ccCon = 0.90, ccSat = 0.40,
        tint = Color3.fromRGB(170, 180, 210),
        srI = 0.01, srSpr = 0.10,
        envDiff = 0.08, envSpec = 0.10,
        kelvin = 4000,
        fogDensity = 0.5,
        starVisibility = 1.0,
        rainProbability = 0.6,
        wetness = 0.8,
    },
}

local KF_T = {}
for k, _ in pairs(KF) do
    table.insert(KF_T, k)
end
table.sort(KF_T)

function sampleKF(clock)
    clock = math.clamp(clock, KF_T[1], KF_T[#KF_T])

    local idx = 1
    for i = 1, #KF_T - 1 do
        if clock >= KF_T[i] and clock <= KF_T[i + 1] then
            idx = i
            break
        end
    end

    local t = (clock - KF_T[idx]) / (KF_T[idx + 1] - KF_T[idx])
    t = MathUtils.smoothStep(t, 3)

    local kA = KF[KF_T[idx]]
    local kB = KF[KF_T[idx + 1]]

    local function ln(a, b) return MathUtils.lerpN(a, b, t) end
    local function lc(a, b) return MathUtils.lerpC(a, b, t) end

    return {
        lightBri = ln(kA.lightBri, kB.lightBri),
        expComp = ln(kA.expComp, kB.expComp),
        ambient = lc(kA.ambient, kB.ambient),
        cShiftTop = lc(kA.cShiftTop, kB.cShiftTop),
        cShiftBottom = lc(kA.cShiftBottom, kB.cShiftBottom),
        bloomI = ln(kA.bloomI, kB.bloomI),
        bloomS = ln(kA.bloomS, kB.bloomS),
        bloomT = ln(kA.bloomT, kB.bloomT),
        ccBri = ln(kA.ccBri, kB.ccBri),
        ccCon = ln(kA.ccCon, kB.ccCon),
        ccSat = ln(kA.ccSat, kB.ccSat),
        tint = lc(kA.tint, kB.tint),
        srI = ln(kA.srI, kB.srI),
        srSpr = ln(kA.srSpr, kB.srSpr),
        envDiff = ln(kA.envDiff, kB.envDiff),
        envSpec = ln(kA.envSpec, kB.envSpec),
        kelvin = ln(kA.kelvin, kB.kelvin),
        fogDensity = ln(kA.fogDensity, kB.fogDensity),
        starVisibility = ln(kA.starVisibility, kB.starVisibility),
        rainProbability = ln(kA.rainProbability, kB.rainProbability),
        wetness = ln(kA.wetness, kB.wetness),
        name = t < 0.5 and kA.name or kB.name,
    }
end

local RainSystem = {}
RainSystem.active = false
RainSystem.intensity = 0
RainSystem.drops = {}
RainSystem.splashes = {}
RainSystem.puddles = {}
RainSystem.wetSurfaces = {}

function RainSystem.init()
    if not CFG.RainEnabled then return end

    local rainFolder = Instance.new("Folder")
    rainFolder.Name = "RainSystem"
    rainFolder.Parent = Workspace
    RainSystem.folder = rainFolder

    local rainPart = Instance.new("Part")
    rainPart.Name = "RainEmitter"
    rainPart.Anchored = true
    rainPart.CanCollide = false
    rainPart.Transparency = 1
    rainPart.Size = Vector3.new(100, 1, 100)
    rainPart.Position = Vector3.new(0, 100, 0)
    rainPart.Parent = rainFolder

    local rainEmitter = Instance.new("ParticleEmitter")
    rainEmitter.Name = "RainParticles"
    rainEmitter.Parent = rainPart
    rainEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    rainEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.8)
    })
    rainEmitter.Lifetime = NumberRange.new(1.5, 2.5)
    rainEmitter.Rate = 0  -- Controlled dynamically
    rainEmitter.Speed = NumberRange.new(30, 40)
    rainEmitter.SpreadAngle = Vector2.new(5, 0)
    rainEmitter.Rotation = NumberRange.new(-90, -90)
    rainEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 210, 230))
    rainEmitter.LightEmission = 0.1
    rainEmitter.LightInfluence = 0.8
    rainEmitter.Acceleration = Vector3.new(0, -20, 0)

    RainSystem.emitter = rainEmitter

    local splashPart = Instance.new("Part")
    splashPart.Name = "SplashEmitter"
    splashPart.Anchored = true
    splashPart.CanCollide = false
    splashPart.Transparency = 1
    splashPart.Size = Vector3.new(1, 1, 1)
    splashPart.Parent = rainFolder

    local splashEmitter = Instance.new("ParticleEmitter")
    splashEmitter.Name = "SplashParticles"
    splashEmitter.Parent = splashPart
    splashEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.3, 0.4),
        NumberSequenceKeypoint.new(1, 0)
    })
    splashEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1)
    })
    splashEmitter.Lifetime = NumberRange.new(0.2, 0.4)
    splashEmitter.Rate = 0
    splashEmitter.Speed = NumberRange.new(2, 5)
    splashEmitter.SpreadAngle = Vector2.new(30, 30)
    splashEmitter.Color = ColorSequence.new(Color3.fromRGB(220, 230, 255))
    splashEmitter.LightEmission = 0.2

    RainSystem.splashEmitter = splashEmitter
    RainSystem.splashPart = splashPart

    local rainSound = Instance.new("Sound")
    rainSound.Name = "RainAmbient"
    rainSound.Looped = true
    rainSound.Volume = 0
    rainSound.Parent = rainFolder
    RainSystem.sound = rainSound

    end

function RainSystem.update(intensity, clock)
    if not CFG.RainEnabled or not RainSystem.emitter then return end

    RainSystem.intensity = intensity

    local density = math.floor(PHYSICS.RAIN_DENSITY_LIGHT * intensity)
    if intensity > 0.5 then
        density = PHYSICS.RAIN_DENSITY_LIGHT + 
                  (PHYSICS.RAIN_DENSITY_HEAVY - PHYSICS.RAIN_DENSITY_LIGHT) * (intensity - 0.5) * 2
    end

    RainSystem.emitter.Rate = density
    RainSystem.emitter.Speed = NumberRange.new(
        PHYSICS.RAIN_FALL_SPEED * (0.8 + intensity * 0.4),
        PHYSICS.RAIN_FALL_SPEED * (1.0 + intensity * 0.5)
    )

    if clock < 6 or clock > 20 then
        RainSystem.emitter.Color = ColorSequence.new(Color3.fromRGB(150, 160, 200))
    elseif clock < 8 or clock > 17 then
        RainSystem.emitter.Color = ColorSequence.new(Color3.fromRGB(180, 170, 160))
    else
        RainSystem.emitter.Color = ColorSequence.new(Color3.fromRGB(200, 210, 230))
    end

    if RainSystem.sound then
        RainSystem.sound.Volume = intensity * 0.5
        if intensity > 0.1 and not RainSystem.sound.Playing then
            RainSystem.sound:Play()
        elseif intensity <= 0.1 and RainSystem.sound.Playing then
            RainSystem.sound:Stop()
        end
    end

    if RainSystem.splashEmitter then
        RainSystem.splashEmitter.Rate = density * 0.1
    end

    local hrp = Players.LocalPlayer.Character and 
                Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and RainSystem.folder then
        local rainPart = RainSystem.folder:FindFirstChild("RainEmitter")
        if rainPart then
            rainPart.Position = Vector3.new(hrp.Position.X, 100, hrp.Position.Z)
        end

        local splashPart = RainSystem.folder:FindFirstChild("SplashEmitter")
        if splashPart then
            splashPart.Position = Vector3.new(hrp.Position.X, 0.5, hrp.Position.Z)
        end
    end
end

function RainSystem.createPuddle(position, normal, size)
    if not CFG.PuddleForming then return end
    if math.abs(normal.Y) < 0.9 then return end  

    local puddle = Instance.new("Part")
    puddle.Name = "Puddle"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.Transparency = 0.7
    puddle.Size = Vector3.new(size, 0.05, size)
    puddle.Position = position + Vector3.new(0, 0.025, 0)
    puddle.Parent = RainSystem.folder

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Scale = Vector3.new(1, 0.1, 1)
    mesh.Parent = puddle

    local reflectance = Instance.new("NumberValue")
    reflectance.Name = "Reflectance"
    reflectance.Value = 0.8
    reflectance.Parent = puddle

    puddle.Material = Enum.Material.Glass
    puddle.Color = Color3.fromRGB(180, 190, 210)

    spawn(function()
        local startTime = tick()
        while puddle.Parent do
            local elapsed = tick() - startTime
            if elapsed > CFG.WetSurfaceDuration then
                puddle.Transparency = 0.7 + (1 - (elapsed - CFG.WetSurfaceDuration) / 10) * 0.3
                if (elapsed - CFG.WetSurfaceDuration) / 10 >= 1 then
                    puddle:Destroy()
                    break
                end
            end
            wait(0.5)
        end
    end)

    table.insert(RainSystem.puddles, puddle)
end

local SSR = {}
SSR.reflections = {}

function SSR.calculateReflection(viewPos, viewDir, normal)
    local reflectDir = (viewDir - 2 * viewDir:Dot(normal) * normal).Unit

    local currentPos = viewPos
    local step = reflectDir * CFG.SSR_StepSize

    for i = 1, CFG.SSR_MaxSteps do
        currentPos = currentPos + step

        local raycastResult = Workspace:Raycast(currentPos, -reflectDir * 0.5, RAY_PARAMS)
        if raycastResult then
            return raycastResult.Position, raycastResult.Instance
        end

        if (currentPos - viewPos).Magnitude > CFG.SSR_MaxDistance then
            break
        end
    end

    return nil, nil
end

local VolumetricSystem = {}
VolumetricSystem.lights = {}

function VolumetricSystem.addLight(light, intensity)
    if not CFG.VolumetricLights then return end

    if light:IsA("SpotLight") then
        local volPart = Instance.new("Part")
        volPart.Name = "VolumetricCone_" .. light.Name
        volPart.Anchored = true
        volPart.CanCollide = false
        volPart.Transparency = 0.95
        volPart.Material = Enum.Material.Neon
        volPart.Color = light.Color
        volPart.Parent = light.Parent

        local range = light.Range
        local angle = math.rad(light.Angle)
        local height = range
        local radius = range * math.tan(angle / 2)

        volPart.Size = Vector3.new(radius * 2, height, radius * 2)
        volPart.CFrame = light.CFrame * CFrame.new(0, 0, -height / 2)

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Cylinder
        mesh.Scale = Vector3.new(1, 1, 0.01)  
        mesh.Parent = volPart

        VolumetricSystem.lights[light] = {
            part = volPart,
            mesh = mesh,
            baseIntensity = intensity or 1,
        }
    end
end

function VolumetricSystem.update(dt)
    for light, data in pairs(VolumetricSystem.lights) do
        if not light.Parent then
            data.part:Destroy()
            VolumetricSystem.lights[light] = nil
            continue
        end

        data.part.CFrame = light.CFrame * CFrame.new(0, 0, -light.Range / 2)

        local flicker = math.sin(tick() * 10) * 0.05 + math.sin(tick() * 23) * 0.03
        local baseTransparency = 0.95 - (light.Brightness / 100) * 0.3
        data.part.Transparency = math.clamp(baseTransparency + flicker, 0.8, 0.98)

        data.part.Color = light.Color
    end
end

local RT = {}

local AO_DIRS = {}
do
    local sqN = math.floor(math.sqrt(CFG.AO_Rays))
    for i = 0, sqN - 1 do
        for j = 0, sqN - 1 do
            local u = (i + math.random()) / sqN
            local v = (j + math.random()) / sqN
            local th = math.acos(math.sqrt(1 - u))
            local phi = math.pi * 2 * v
            local sinT = math.sin(th)

            local jitter = 0.05
            local dir = Vector3.new(
                sinT * math.cos(phi) + (math.random() - 0.5) * jitter,
                math.cos(th) + (math.random() - 0.5) * jitter,
                sinT * math.sin(phi) + (math.random() - 0.5) * jitter
            ).Unit

            table.insert(AO_DIRS, dir)
        end
    end
end

local SPEC_DIRS = {}
for i = 1, CFG.Specular_Rays do
    local theta = math.random() * math.pi * 2
    local phi = math.acos(1 - math.random() * 0.1)
    table.insert(SPEC_DIRS, Vector3.new(
        math.sin(phi) * math.cos(theta),
        math.cos(phi),
        math.sin(phi) * math.sin(theta)
    ))
end

local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

local rtState = {
    sunOccFactor = 1.0,
    sunOccTarget = 1.0,
    aoFactor = 0.0,
    aoTarget = 0.0,
    bounceColor = Color3.new(0, 0, 0),
    bounceTarget = Color3.new(0, 0, 0),
    specularColor = Color3.new(0, 0, 0),
    specularTarget = Color3.new(0, 0, 0),
    shadowFactor = 1.0,
    shadowTarget = 1.0,
    wetnessFactor = 0.0,
    wetnessTarget = 0.0,
}

function RT.castSunRay(origin, sunDir)
    if sunDir.Y < -0.05 then
        rtState.sunOccTarget = 0.0
        return
    end

    local hit = Workspace:Raycast(origin, sunDir * 2000, RAY_PARAMS)
    if not hit then
        rtState.sunOccTarget = 1.0
        return
    end

    local occluded = 1
    local sampleDirs = {
        Vector3.new(0.1, 0, 0),
        Vector3.new(-0.1, 0, 0),
        Vector3.new(0, 0.1, 0),
        Vector3.new(0, -0.1, 0),
        Vector3.new(0, 0, 0.1),
        Vector3.new(0, 0, -0.1),
    }

    for _, offset in ipairs(sampleDirs) do
        local sampleDir = (sunDir + offset).Unit
        if not Workspace:Raycast(origin, sampleDir * 2000, RAY_PARAMS) then
            occluded = occluded - 0.15
        end
    end

    rtState.sunOccTarget = math.clamp(occluded, 0.15, 1.0)
end

function RT.castAORays(origin)
    local hits = 0
    local totalWeight = 0

    for _, dir in ipairs(AO_DIRS) do
        local result = Workspace:Raycast(origin, dir * CFG.AO_Distance, RAY_PARAMS)
        if result then
            local dist = result.Distance
            local weight = 1 / (1 + dist * 0.1)
            hits = hits + weight
        end
        totalWeight = totalWeight + 1
    end

    rtState.aoTarget = hits / totalWeight
end

function RT.castBounceRay(origin, sunColor, sunDir)
    local downRay = Workspace:Raycast(origin, Vector3.new(0, -CFG.GI_MaxDist, 0), RAY_PARAMS)
    if not downRay then
        rtState.bounceTarget = Color3.new(0, 0, 0)
        return
    end

    local d = math.max(1, downRay.Distance)
    local falloff = math.min(1, 50 / (d * d))

    local groundColor
    if downRay.Instance and downRay.Instance:IsA("BasePart") then
        groundColor = downRay.Instance.Color
    else
        groundColor = Color3.new(0.5, 0.45, 0.4)
    end

    local upBounce = Color3.new(0, 0, 0)
    if CFG.GI_Bounces >= 2 then
        local upRay = Workspace:Raycast(
            downRay.Position, 
            Vector3.new(0, CFG.GI_MaxDist * 0.5, 0), 
            RAY_PARAMS
        )
        if upRay then
            local upColor = (upRay.Instance and upRay.Instance:IsA("BasePart")) 
                and upRay.Instance.Color 
                or Color3.new(0.6, 0.6, 0.6)
            upBounce = Color3.new(
                math.min(1, upColor.R * groundColor.R * 0.3),
                math.min(1, upColor.G * groundColor.G * 0.3),
                math.min(1, upColor.B * groundColor.B * 0.3)
            )
        end
    end

    local bounceR = math.min(1, (groundColor.R * sunColor.R * falloff * CFG.GI_Strength) + upBounce.R)
    local bounceG = math.min(1, (groundColor.G * sunColor.G * falloff * CFG.GI_Strength) + upBounce.G)
    local bounceB = math.min(1, (groundColor.B * sunColor.B * falloff * CFG.GI_Strength) + upBounce.B)

    rtState.bounceTarget = Color3.new(bounceR, bounceG, bounceB)
end

function RT.castSpecularRays(origin, viewDir)
    local specR, specG, specB = 0, 0, 0
    local samples = 0

    for _, dir in ipairs(SPEC_DIRS) do
        local reflectDir = (viewDir - 2 * viewDir:Dot(dir) * dir).Unit
        local hit = Workspace:Raycast(origin, reflectDir * 100, RAY_PARAMS)

        if hit and hit.Instance and hit.Instance:IsA("BasePart") then
            local hitColor = hit.Instance.Color
            local dist = hit.Distance
            local atten = 1 / (1 + dist * 0.05)

            local cosTheta = math.abs(viewDir:Dot(hit.Normal))
            local fresnel = ColorScience.FresnelReflectance(cosTheta, 1.0, PHYSICS.WATER_REFRACTIVE_INDEX)

            specR = specR + hitColor.R * atten * fresnel
            specG = specG + hitColor.G * atten * fresnel
            specB = specB + hitColor.B * atten * fresnel
            samples = samples + 1
        end
    end

    if samples > 0 then
        rtState.specularTarget = Color3.new(
            math.min(1, specR / samples),
            math.min(1, specG / samples),
            math.min(1, specB / samples)
        )
    else
        rtState.specularTarget = Color3.new(0, 0, 0)
    end
end

function RT.detectWetSurfaces(origin)
    local wetness = 0

    local groundRay = Workspace:Raycast(origin, Vector3.new(0, -5, 0), RAY_PARAMS)
    if groundRay then
        local material = groundRay.Instance.Material

        local wettableMaterials = {
            [Enum.Material.Concrete] = true,
            [Enum.Material.Asphalt] = true,
            [Enum.Material.Brick] = true,
            [Enum.Material.Cobblestone] = true,
            [Enum.Material.WoodPlanks] = true,
            [Enum.Material.Rock] = true,
        }

        if wettableMaterials[material] then
            wetness = RainSystem.intensity * 0.8

            if RainSystem.intensity > 0.3 and math.abs(groundRay.Normal.Y) > 0.95 then
                if math.random() < 0.01 then  
                    RainSystem.createPuddle(groundRay.Position, groundRay.Normal, math.random(2, 5))
                end
            end
        end
    end

    rtState.wetnessTarget = wetness
end

local LightBulbSystem = {}
LightBulbSystem.bulbs = {}

function LightBulbSystem.scanForLights()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            if not LightBulbSystem.bulbs[obj] then
                LightBulbSystem.enhanceLight(obj)
            end
        end
    end
end

function LightBulbSystem.enhanceLight(light)
    LightBulbSystem.bulbs[light] = {
        originalBrightness = light.Brightness,
        originalRange = light.Range,
        originalColor = light.Color,
    }

    light.Brightness = light.Brightness * 1.5
    light.Range = light.Range * 1.2

    if light:IsA("PointLight") then
        local glowPart = Instance.new("Part")
        glowPart.Name = "LightGlow"
        glowPart.Anchored = true
        glowPart.CanCollide = false
        glowPart.Transparency = 0.9
        glowPart.Size = Vector3.new(0.5, 0.5, 0.5)
        glowPart.Material = Enum.Material.Neon
        glowPart.Color = light.Color
        glowPart.Parent = light.Parent

        if light.Parent:IsA("BasePart") then
            glowPart.CFrame = light.Parent.CFrame
        end

        LightBulbSystem.bulbs[light].glowPart = glowPart
    end

    if light:IsA("SpotLight") then
        VolumetricSystem.addLight(light, 1.5)
    end

    spawn(function()
        while light.Parent do
            local flicker = math.sin(tick() * 8) * 0.03 + math.sin(tick() * 17) * 0.02
            light.Brightness = LightBulbSystem.bulbs[light].originalBrightness * 1.5 * (1 + flicker)
            wait(0.05)
        end
    end)
end

function LightBulbSystem.updateRainEffect()
    for light, data in pairs(LightBulbSystem.bulbs) do
        if not light.Parent then
            if data.glowPart then data.glowPart:Destroy() end
            LightBulbSystem.bulbs[light] = nil
            continue
        end

        if RainSystem.intensity > 0.2 then
            light.Brightness = data.originalBrightness * 1.5 * (1 + RainSystem.intensity * 0.3)
        end

        if data.glowPart then
            data.glowPart.Color = light.Color
            local pulse = math.sin(tick() * 3) * 0.05
            data.glowPart.Transparency = 0.85 + pulse
        end
    end
end

local UI = {}

function UI.createCinematicUI()
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "CinematicRT_v5"
    Gui.Parent = pg
    Gui.IgnoreGuiInset = true
    Gui.ResetOnSpawn = false
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    if CFG.Vignette then
        local Vig = Instance.new("ImageLabel")
        Vig.Parent = Gui
        Vig.AnchorPoint = Vector2.new(0.5, 0.5)
        Vig.Position = UDim2.new(0.5, 0, 0.5, 0)
        Vig.Size = UDim2.new(1.1, 0, 1.1, 0)
        Vig.BackgroundTransparency = 1
        Vig.Image = "rbxassetid://4576475446"
        Vig.ImageTransparency = 0.30
        Vig.ImageColor3 = Color3.fromRGB(8, 4, 2)
        Vig.ZIndex = 10

        spawn(function()
            while Gui.Parent do
                local breathe = math.sin(tick() * 0.5) * 0.02
                Vig.ImageTransparency = 0.30 + breathe
                wait(0.1)
            end
        end)
    end

    if CFG.ChromaAberr then
        local dispersion = 2.5

        local redChannel = Instance.new("ImageLabel")
        redChannel.Parent = Gui
        redChannel.AnchorPoint = Vector2.new(0.5, 0.5)
        redChannel.Position = UDim2.new(0.5, -dispersion, 0.5, -dispersion)
        redChannel.Size = UDim2.new(1.008, 0, 1.008, 0)
        redChannel.BackgroundTransparency = 1
        redChannel.Image = "rbxassetid://4576475446"
        redChannel.ImageTransparency = 0.92
        redChannel.ImageColor3 = Color3.fromRGB(255, 40, 0)
        redChannel.ZIndex = 9

        local blueChannel = Instance.new("ImageLabel")
        blueChannel.Parent = Gui
        blueChannel.AnchorPoint = Vector2.new(0.5, 0.5)
        blueChannel.Position = UDim2.new(0.5, dispersion, 0.5, dispersion)
        blueChannel.Size = UDim2.new(1.008, 0, 1.008, 0)
        blueChannel.BackgroundTransparency = 1
        blueChannel.Image = "rbxassetid://4576475446"
        blueChannel.ImageTransparency = 0.92
        blueChannel.ImageColor3 = Color3.fromRGB(0, 40, 255)
        blueChannel.ZIndex = 9
    end

    if CFG.Letterbox then
        local bH = 0.08
        for _, yp in ipairs({0, 1 - bH}) do
            local bar = Instance.new("Frame")
            bar.Parent = Gui
            bar.Size = UDim2.new(1, 0, bH, 0)
            bar.Position = UDim2.new(0, 0, yp, 0)
            bar.BackgroundColor3 = Color3.new(0, 0, 0)
            bar.BorderSizePixel = 0
            bar.ZIndex = 20
        end
    end

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Parent = Gui
    timeLabel.AnchorPoint = Vector2.new(1, 0)
    timeLabel.Position = UDim2.new(0.98, 0, 0.02, 0)
    timeLabel.Size = UDim2.new(0, 120, 0, 30)
    timeLabel.BackgroundTransparency = 1
    timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timeLabel.TextStrokeTransparency = 0.5
    timeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    timeLabel.Font = Enum.Font.GothamBold
    timeLabel.TextSize = 16
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    timeLabel.ZIndex = 30
    timeLabel.Name = "TimeDisplay"

    local weatherLabel = Instance.new("TextLabel")
    weatherLabel.Parent = Gui
    weatherLabel.AnchorPoint = Vector2.new(1, 0)
    weatherLabel.Position = UDim2.new(0.98, 0, 0.06, 0)
    weatherLabel.Size = UDim2.new(0, 120, 0, 20)
    weatherLabel.BackgroundTransparency = 1
    weatherLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    weatherLabel.TextStrokeTransparency = 0.5
    weatherLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    weatherLabel.Font = Enum.Font.Gotham
    weatherLabel.TextSize = 12
    weatherLabel.TextXAlignment = Enum.TextXAlignment.Right
    weatherLabel.ZIndex = 30
    weatherLabel.Name = "WeatherDisplay"

    return Gui, timeLabel, weatherLabel
end

local CharacterSystem = {}
local hrp = nil
local camera = Workspace.CurrentCamera

function CharacterSystem.onChar(char)
    hrp = char:WaitForChild("HumanoidRootPart")
    RAY_PARAMS.FilterDescendantsInstances = {char}
end

local pl = Players.LocalPlayer
if pl.Character then
    CharacterSystem.onChar(pl.Character)
end
pl.CharacterAdded:Connect(CharacterSystem.onChar)

local t0 = tick()
local frame = 0
local timeSpan = CFG.TimeEnd - CFG.TimeStart

local CinematicGui, TimeDisplay, WeatherDisplay = UI.createCinematicUI()

RainSystem.init()
LightBulbSystem.scanForLights()

local dayOfYear = os.date("%j", os.time())

local rainTimer = 0
local targetRainIntensity = 0
local currentRainIntensity = 0

RunService.Heartbeat:Connect(function(dt)
    frame = frame + 1
    local elapsed = tick() - t0

    local phase = elapsed % (CFG.CycleDuration * 2)
    local alpha
    if phase <= CFG.CycleDuration then
        alpha = phase / CFG.CycleDuration
    else
        alpha = 1 - (phase - CFG.CycleDuration) / CFG.CycleDuration
    end

    local clock = CFG.TimeStart + alpha * timeSpan
    local d = sampleKF(clock)

    if CFG.RainVariation then
        rainTimer = rainTimer + dt
        if rainTimer > math.random(30, 60) then
            rainTimer = 0
            if math.random() < d.rainProbability then
                targetRainIntensity = math.random() * CFG.RainIntensity
            else
                targetRainIntensity = 0
            end
        end
        currentRainIntensity = currentRainIntensity + (targetRainIntensity - currentRainIntensity) * dt * 0.5
    else
        currentRainIntensity = CFG.RainIntensity
    end

    RainSystem.update(currentRainIntensity, clock)

    local elevation, azimuth = Astronomy.CalculateSunPosition(clock, Lighting.GeographicLatitude, dayOfYear)
    local skyColor, skyIntensity = Astronomy.CalculateAtmosphere(elevation)
    local colorTemp = Astronomy.GetColorTemperature(elevation)

    local breath = math.sin(elapsed * CFG.BreathFreq * math.pi * 2) * CFG.BreathAmp
    local noise = MathUtils.noise(elapsed * 0.1) * 0.005

    local origin = hrp and (hrp.Position + Vector3.new(0, 2.5, 0)) or nil
    local sunDir = Lighting:GetSunDirection()
    local viewDir = camera.CFrame.LookVector

    if origin then
        if frame % CFG.Sun_Interval == 0 then
            RT.castSunRay(origin, sunDir)
        end
        if frame % CFG.AO_Interval == 0 then
            RT.castAORays(origin)
        end
        if frame % CFG.GI_Interval == 0 then
            RT.castBounceRay(origin, d.cShiftTop, sunDir)
        end
        if frame % 3 == 0 then
            RT.castSpecularRays(origin, viewDir)
        end
        RT.detectWetSurfaces(origin)
    end

    LightBulbSystem.updateRainEffect()

    VolumetricSystem.update(dt)

    local lerpSpeed = math.min(1, dt * 5)
    rtState.sunOccFactor = MathUtils.lerpN(rtState.sunOccFactor, rtState.sunOccTarget, 0.12)
    rtState.aoFactor = MathUtils.lerpN(rtState.aoFactor, rtState.aoTarget, 0.08)
    rtState.bounceColor = MathUtils.lerpC(rtState.bounceColor, rtState.bounceTarget, 0.05)
    rtState.specularColor = MathUtils.lerpC(rtState.specularColor, rtState.specularTarget, 0.04)
    rtState.wetnessFactor = MathUtils.lerpN(rtState.wetnessFactor, rtState.wetnessTarget, 0.1)

    local aoInfluence = rtState.aoFactor * CFG.AO_AmbStrength
    local ambientRT = Color3.new(
        d.ambient.R * (1 - aoInfluence),
        d.ambient.G * (1 - aoInfluence),
        d.ambient.B * (1 - aoInfluence)
    )

    ambientRT = Color3.new(
        math.min(1, ambientRT.R + rtState.bounceColor.R * 0.4),
        math.min(1, ambientRT.G + rtState.bounceColor.G * 0.4),
        math.min(1, ambientRT.B + rtState.bounceColor.B * 0.4)
    )

    if rtState.wetnessFactor > 0 then
        local wetBoost = rtState.wetnessFactor * 0.3
        ambientRT = Color3.new(
            math.min(1, ambientRT.R + wetBoost),
            math.min(1, ambientRT.G + wetBoost),
            math.min(1, ambientRT.B + wetBoost * 1.1)
        )
    end

    ambientRT = Color3.new(
        ColorScience.ACESFilm(ambientRT.R),
        ColorScience.ACESFilm(ambientRT.G),
        ColorScience.ACESFilm(ambientRT.B)
    )

    Lighting.ClockTime = clock
    Lighting.Brightness = d.lightBri * (0.95 + breath) * (1 + currentRainIntensity * 0.2)
    Lighting.ExposureCompensation = d.expComp * (1 - rtState.aoFactor * 0.25) - currentRainIntensity * 0.1
    Lighting.Ambient = ambientRT
    Lighting.ColorShift_Top = d.cShiftTop

    local wetBottom = Color3.new(
        math.min(1, d.cShiftBottom.R + rtState.bounceColor.R * 0.3 + rtState.wetnessFactor * 0.1),
        math.min(1, d.cShiftBottom.G + rtState.bounceColor.G * 0.3 + rtState.wetnessFactor * 0.1),
        math.min(1, d.cShiftBottom.B + rtState.bounceColor.B * 0.3 + rtState.wetnessFactor * 0.15)
    )
    Lighting.ColorShift_Bottom = wetBottom

    Lighting.EnvironmentDiffuseScale = d.envDiff * (1 + currentRainIntensity * 0.3)
    Lighting.EnvironmentSpecularScale = d.envSpec * (0.8 + rtState.sunOccFactor * 0.2) * (1 + rtState.wetnessFactor * 0.5)

    Sky.StarCount = math.floor(8000 * d.starVisibility)

    Bloom.Intensity = math.max(0, d.bloomI * (0.4 + 0.6 * rtState.sunOccFactor) + breath * 0.5 + currentRainIntensity * 0.1)
    Bloom.Size = d.bloomS
    Bloom.Threshold = d.bloomT

    local toneMappedBri = ColorScience.AgX(d.ccBri + 0.5) - 0.5
    ColorCor.Brightness = toneMappedBri
    ColorCor.Contrast = d.ccCon + currentRainIntensity * 0.1
    ColorCor.Saturation = d.ccSat - currentRainIntensity * 0.1
    ColorCor.TintColor = d.tint

    SunRays.Intensity = d.srI * rtState.sunOccFactor * (1 - currentRainIntensity * 0.5)
    SunRays.Spread = d.srSpr

    if TimeDisplay then
        local hours = math.floor(clock)
        local minutes = math.floor((clock - hours) * 60)
        TimeDisplay.Text = string.format("%s %02d:%02d", d.name, hours, minutes)
    end

    if WeatherDisplay then
        if currentRainIntensity > 0.7 then
            WeatherDisplay.Text = " Storm"
        elseif currentRainIntensity > 0.4 then
            WeatherDisplay.Text = " Heavy Rain"
        elseif currentRainIntensity > 0.1 then
            WeatherDisplay.Text = " Light Rain"
        else
            WeatherDisplay.Text = " Clear"
        end
    end
end)
