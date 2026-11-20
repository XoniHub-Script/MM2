-- XONI HUB V39 | Target, Aimbot pantalla completa, Server, tema Blanco y Negro
-- Murder vs Sheriff | XONI HUB V13 - GUI CARBON / RED (LocalScript)
-- Colocar en StarterPlayer > StarterPlayerScripts dentro de TU experiencia.
-- Detecta Knife o Gun dentro de Character y Backpack cuando son visibles al cliente.
-- En otros jugadores, las Tools guardadas pueden no replicarse al cliente.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local ICON_ID = "123652165225785" -- Cambia este ID para actualizar ambos logos
-- Iconos del menu (cambia los numeros aqui cuando quieras).
local OPEN_MENU_ICON_ID = "89449410140141"
local CATEGORY_ICON_IDS = {
    Home = "122429641585350",
    Event = "91591782151780",
    Player = "99344069257698",
    Settings = "94216259479852",
    Target = "134851470578994",
    Server = "92523741342063",
}


local UI = {} -- Componentes visuales agrupados para no exceder registros locales de Luau

local me = Players.LocalPlayer
UI.configFileName = "XONI_HUB_Config_" .. tostring(me.UserId) .. ".json"
local playerGui = me:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("MurderVsSheriffGui")
if old then old:Destroy() end

local C = {
    blue = Color3.fromRGB(20, 20, 23),
    dark = Color3.fromRGB(17, 17, 20),
    navy = Color3.fromRGB(106, 20, 27),
    bg = Color3.fromRGB(10, 10, 12),
    white = Color3.fromRGB(255, 255, 255),
    ink = Color3.fromRGB(238, 238, 241),
    muted = Color3.fromRGB(151, 152, 161),
    mint = Color3.fromRGB(65, 218, 136),
    purple = Color3.fromRGB(246, 48, 62),
    red = Color3.fromRGB(245, 36, 49),
    sheriff = Color3.fromRGB(79, 155, 255),
    orange = Color3.fromRGB(251, 154, 65),
    line = Color3.fromRGB(64, 64, 69)

}

local config = { rainbowLauncher = true, targetCollapsed = false, maxCoinDistance = 6000, coinSpeed = 40, notify = true, sounds = true, maxKillDistance = 5000, toastDuration = 4.3, scale = 1, theme = "Rojo", animations = true, playerSpeed = 20, flySpeed = 36, aimFov = 185, aimSmooth = 40, aimWallcheck = false, aimbot = false, autoSave = true, panelTransparency = 0, hotkeys = {}, onScreen = {} }
local state = { antiAfk = false, autoKillAll = false, targetUserId = nil, blacklist = {}, farm = false, murder = false, sheriff = false, autoGun = false, gunEsp = false, innocents = false, noclip = false, infiniteJump = false, fastMove = false, flying = false, busy = false, aim = false, open = true, min = false, closing = false }
local runningTween = nil
local visited = {}
local savedParts = nil
local roleCache = {} -- [Player] = {role=..., character=...}
local espRoleGrace = {} -- Evita parpadeos mientras una Tool cambia de Character a Backpack
local visuals = {}   -- [Player] = {highlight, billboard, label, character, role}
local currentOwnRole = nil
local connections = {}
local gunLastSeen = nil
local gunCooldownUntil = 0
local combatBusy = false
local escapeUntil = 0
local nearbyDangerActive = false
local unsafeSince = nil
local murderAlertCooldown = 0
local idleEscapeCooldown = 0
local retreatState = nil
local RETREAT_POINT = Vector3.new(14.51, 519.56, 15.49) -- Refugio del lobby, sin altura artificial
local DANGER_RADIUS = 40
local RETURN_RADIUS = 55
local RETREAT_TIMEOUT = 3
local SAFE_COIN_RADIUS = 75
local returnFromRetreat -- definida después de los helpers de movimiento
local controlsDisabled = false
local noclipOriginal = {} -- declarado antes de AutoCatchGun
-- No usar PlayerModule:GetControls():Disable(): en algunas camaras deja
-- el cursor centrado o impide interactuar con la interfaz.
-- Bloqueamos solo teclas de desplazamiento, nunca el mouse ni la camara.
-- V26: No secuestrar teclas de movimiento al asignar o usar un atajo.
-- La rutina de recolección administra su propio estado físico mientras se mueve.
-- El uso de ContextActionService:BindActionAtPriority sobre WASD/Space/Thumbstick
-- provocaba que el jugador dejara de poder moverse al usar el keybind.
local function setFarmInputLocked(_lock)
    controlsDisabled = false
    ContextActionService:UnbindAction("MVSS_FarmLock")
end
local function connect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(connections, conn)
    return conn
end
local function tween(obj, duration, goal, style)
    local t = TweenService:Create(obj, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    t:Play()
    return t
end
local function new(class, parent, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(parent, radius)
    return new("UICorner", parent, {CornerRadius = UDim.new(0, radius or 10)})
end
local function line(parent, color, alpha)
    return new("UIStroke", parent, {Color = color or C.line, Transparency = alpha or 0.2, Thickness = 1})
end
local function text(parent, value, size, color, bold, props)
    local p = props or {}
    p.BackgroundTransparency = 1
    p.Text = tostring(value)
    p.TextSize = size
    p.TextColor3 = color
    p.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
    p.TextYAlignment = p.TextYAlignment or Enum.TextYAlignment.Center
    return new("TextLabel", parent, p)
end

local gui = new("ScreenGui", playerGui, {
    Name = "MurderVsSheriffGui", ResetOnSpawn = false,
    IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 60
})
local sound = new("Sound", gui, {Name = "NotificationChime", SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.38})
local clickSound = new("Sound", gui, {Name = "ClickChime", SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.17, PlaybackSpeed = 1.3})
local function playSound(s)
    if config.sounds then
        s.TimePosition = 0
        s:Play()
    end
end

-- NOTIFICACIONES: pila visual abajo a la derecha
local alerts = new("Frame", gui, {
    Name = "Notifications", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -18), Size = UDim2.fromOffset(286, 310),
    BackgroundTransparency = 1, ZIndex = 100
})
new("UIListLayout", alerts, {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)
})
local nextAlertOrder = 0
local function notify(title, message, accent)
    if not config.notify or state.closing then return end
    nextAlertOrder += 1
    local n = new("Frame", alerts, {
        Name = "Toast", LayoutOrder = nextAlertOrder,
        Size = UDim2.fromOffset(280, 69), BackgroundColor3 = C.blue,
        BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 101
    })
    round(n, 10)
    line(n, C.line, 0.15)
    local stripe = new("Frame", n, {Name="ToneStripe",Size = UDim2.new(0, 5, 1, -16), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = C.navy, BorderSizePixel = 0, ZIndex = 102})
    round(stripe, 4)
    local heading = text(n, title, 12, C.ink, true, {Position = UDim2.fromOffset(17, 9), Size = UDim2.new(1, -27, 0, 22), ZIndex = 102, TextTransparency = 1})
    local subtitle = text(n, message, 10, C.muted, false, {Position = UDim2.fromOffset(17, 30), Size = UDim2.new(1, -27, 0, 30), TextWrapped = true, ZIndex = 102, TextTransparency = 1})
    n.Position = UDim2.fromOffset(25, 0)
    tween(n, 0.24, {BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0)})
    tween(heading, 0.24, {TextTransparency = 0})
    tween(subtitle, 0.24, {TextTransparency = 0})
    playSound(sound)
    task.delay(config.toastDuration, function()
        if not n.Parent then return end
        tween(heading, 0.2, {TextTransparency = 1})
        tween(subtitle, 0.2, {TextTransparency = 1})
        local out = tween(n, 0.23, {BackgroundTransparency = 1})
        out.Completed:Wait()
        if n.Parent then n:Destroy() end
    end)
end

-- ESTRUCTURA DEL DASHBOARD
local main = new("Frame", gui, {
    Name = "Dashboard", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 506),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true
})
round(main, 10)
-- El UIStroke aplicado directamente al Dashboard sobresalia de los bordes
-- redondeados. Dibujar un contorno INTERIOR para que las 4 esquinas sean limpias.
UI.mainBorderFrame = new("Frame", main, {
    Name = "InsetBorder", Position = UDim2.fromOffset(3, 3),
    Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1,
    BorderSizePixel = 0, Active = false, ZIndex = 30
})
round(UI.mainBorderFrame, 7)
UI.mainBorder = line(UI.mainBorderFrame, C.red, 0)
UI.mainBorder.Thickness = 1
UI.mainBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
new("UIGradient", main, {Rotation=90, Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14,14,17)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8,8,10))
})})
local uiScale = new("UIScale", main, {Scale = 1})
local compact = false
local configuredWidth, configuredHeight = 760, 506
local applyResponsiveLayout -- bound when all interface elements have been created
local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local v = camera.ViewportSize
    local phoneMode = v.X < 680
    if phoneMode ~= compact then
        compact = phoneMode
        configuredWidth = compact and 660 or 760
        configuredHeight = compact and 540 or 506
        main.Size = UDim2.fromOffset(configuredWidth, configuredHeight)
        if applyResponsiveLayout then applyResponsiveLayout() end
    end
    local fit = math.min(1, (v.X - 16) / configuredWidth, (v.Y - 16) / configuredHeight)
    -- El control siempre cambia el tamano; 35% = 0.35 de la base.
    -- En telefonos, se limita solo si lo exige el viewport.
    uiScale.Scale = math.max(0.12, math.min(config.scale, math.min((v.X-8)/configuredWidth,(v.Y-8)/configuredHeight)))
end
updateScale()
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    local camera = workspace.CurrentCamera
    if camera then connect(camera:GetPropertyChangedSignal("ViewportSize"), updateScale) end
    task.defer(updateScale)
end)
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale) end

UI.header = new("Frame", main, {Name = "Header", Position=UDim2.fromOffset(142,0), Size = UDim2.new(1, -142, 0, 62), BackgroundColor3 = C.dark, BorderSizePixel = 0})
-- Redondear el extremo superior derecho; cuadrar solamente esquinas INTERIORES.
round(UI.header, 10)
new("Frame",UI.header,{Name="HeaderSquareLeft",Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,12,1,0),BackgroundColor3=C.dark,BorderSizePixel=0})
new("Frame",UI.header,{Name="HeaderSquareBottom",Position=UDim2.new(0,0,1,-11),Size=UDim2.new(1,0,0,11),BackgroundColor3=C.dark,BorderSizePixel=0})
-- Sin línea gris debajo de la cabecera.
UI.headerTitle = text(UI.header,"XONI HUB   ›   HOME",12,C.white,true,{Position=UDim2.fromOffset(15,5),Size=UDim2.fromOffset(240,24)})
-- Sin reloj en la cabecera.
UI.topStatus = new("Frame",UI.header,{Name="ClockDisabled",Visible=false,Size=UDim2.fromOffset(0,0),BackgroundTransparency=1})
local search = new("TextBox", UI.header, {Name="Search",Position=UDim2.fromOffset(15,32),Size=UDim2.fromOffset(285,23),BackgroundColor3=C.bg,BorderSizePixel=0,Text="",PlaceholderText="⌕  Buscar opción...",PlaceholderColor3=C.muted,TextColor3=C.white,Font=Enum.Font.Gotham,TextSize=11,ClearTextOnFocus=false})
round(search,4)
line(search,C.line,.35)
new("UIPadding",search,{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,6)})

local function headerButton(label, x, bg, cb)
    local b = new("TextButton", UI.header, {
        Position = UDim2.new(1, x, 0, 9), Size = UDim2.fromOffset(27, 27),
        BackgroundColor3 = bg, Text = label, Font = Enum.Font.GothamBold,
        TextSize = 16, TextColor3 = C.white, AutoButtonColor = true
    })
    b.BackgroundTransparency=1
    b.TextColor3=(label == "×") and C.red or C.white
    b.TextSize=19
    b.ZIndex=15
    connect(b.MouseButton1Click, function() playSound(clickSound); cb() end)
    return b
end

local side = new("Frame", main, {Name="Sidebar",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(142,506),BackgroundColor3=C.dark,BorderSizePixel=0})
-- El fondo de Sidebar debe compartir el radio del Dashboard en sus esquinas externas.
round(side, 10)
-- Cuadrar SOLO la unión vertical con el contenido (sin línea divisoria).
new("Frame",side,{Name="SideSquareRight",Position=UDim2.new(1,-12,0,0),Size=UDim2.new(0,12,1,0),BackgroundColor3=C.dark,BorderSizePixel=0})
UI.profile = new("Frame",side,{Size=UDim2.fromOffset(142,76),BackgroundColor3=C.dark,BorderSizePixel=0})
round(UI.profile, 10)
new("Frame",UI.profile,{Name="ProfileSquareRight",Position=UDim2.new(1,-12,0,0),Size=UDim2.new(0,12,1,0),BackgroundColor3=C.dark,BorderSizePixel=0})
new("Frame",UI.profile,{Name="ProfileSquareBottom",Position=UDim2.new(0,0,1,-12),Size=UDim2.new(1,0,0,12),BackgroundColor3=C.dark,BorderSizePixel=0})
-- Eliminadas las líneas entre logo, cabecera y categorías.
UI.panelLogo = new("ImageLabel",UI.profile,{Name="PanelLogo",Position=UDim2.fromOffset(48,10),Size=UDim2.fromOffset(46,46),BackgroundColor3=C.dark,Image="rbxassetid://" .. ICON_ID,ScaleType=Enum.ScaleType.Fit,BorderSizePixel=0})
round(UI.panelLogo,7)
UI.logoStroke=line(UI.panelLogo,C.red,0)
UI.logoStroke.Thickness=1
UI.avatarShadow = new("Frame",UI.profile,{Visible=false,Size=UDim2.fromOffset(1,1),BackgroundTransparency=1})
UI.avatar = new("ImageLabel",UI.avatarShadow,{Size=UDim2.fromOffset(1,1),BackgroundTransparency=1})
UI.displayNameLabel = text(UI.profile,"XONI HUB",10,C.ink,true,{Position=UDim2.fromOffset(10,57),Size=UDim2.fromOffset(120,16),TextXAlignment=Enum.TextXAlignment.Center})
UI.usernameLabel = text(UI.profile,"@"..me.Name,9,C.muted,false,{Visible=false,Size=UDim2.fromOffset(1,1)})

-- Separadores finos REINCORPORADOS, trazados desde el Dashboard para que
-- no queden escondidos bajo los parches de UICorner del perfil o la cabecera.
-- Sus extremos tienen margen y nunca cruzan el contorno rojo exterior.
UI.separatorProfile = new("Frame", main, {
    Name="ProfileBottomDivider", Position=UDim2.fromOffset(8,75),
    Size=UDim2.fromOffset(126,1), BackgroundColor3=C.line,
    BackgroundTransparency=0.25, BorderSizePixel=0, ZIndex=8, Active=false
})
UI.separatorHeader = new("Frame", main, {
    Name="HeaderBottomDivider", Position=UDim2.fromOffset(150,61),
    Size=UDim2.new(1,-158,0,1), BackgroundColor3=C.line,
    BackgroundTransparency=0.25, BorderSizePixel=0, ZIndex=8, Active=false
})
UI.separatorSidebar = new("Frame", main, {
    Name="SidebarRightDivider", Position=UDim2.fromOffset(141,76),
    Size=UDim2.new(0,1,1,-84), BackgroundColor3=C.line,
    BackgroundTransparency=0.25, BorderSizePixel=0, ZIndex=8, Active=false
})
UI.content = new("Frame", main, {Name = "Content", Position = UDim2.fromOffset(142, 62), Size = UDim2.fromOffset(618, 444), BackgroundTransparency = 1, ClipsDescendants = true})
local pages = {}
local pageButtons = {}
local activePage = nil
local function makePage(name)
    local p = new("ScrollingFrame", UI.content, {Name = name .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 4, ScrollBarImageColor3 = C.blue, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y})
    new("UIPadding", p, {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9)})
    new("UIListLayout", p, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    pages[name] = p
    return p
end
local homePage = makePage("Home")
local eventPage = makePage("Event")
local opPage = makePage("Op")
pages.Target = makePage("Target")
local aimPage = makePage("Aim")
local playerPage = makePage("Player")
local settingsPage = makePage("Settings")
pages.Server = makePage("Server")

local function showPage(name)
    if activePage == name then return end
    activePage = name
    UI.headerTitle.Text = "XONI HUB   ›   " .. string.upper(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(pageButtons) do
        tween(b, 0.18, {BackgroundColor3 = n == name and C.navy or C.dark})
        local marker=b:FindFirstChild("ActiveMarker")
        if marker then marker.Visible=(n==name) end
        if config.theme=="Blanco y Negro" then
            for _,child in ipairs(b:GetChildren()) do
                if child:IsA("TextLabel") then
                    child.TextColor3=(n==name) and C.white or C.ink
                elseif child:IsA("ImageLabel") then
                    child.ImageColor3=(n==name) and C.white or C.ink
                end
            end
        end
    end
    local p = pages[name]
    p.Position = UDim2.fromOffset(24, 0)
    tween(p, 0.28, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Quint)
end
-- Grupos de categorías: superficies opacas, bordes delicados y acentos rojo oscuro.
UI.navGroups={}
UI.navScroll=new("ScrollingFrame",side,{Name="CategoriasScroll",Position=UDim2.fromOffset(0,76),Size=UDim2.new(1,0,1,-122),BackgroundColor3=C.dark,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.red,CanvasSize=UDim2.fromOffset(0,342),ClipsDescendants=true})
local function navGroup(y,height,titleValue)
    local group=new("Frame",UI.navScroll,{Position=UDim2.fromOffset(6,y),Size=UDim2.new(1,-12,0,height),BackgroundColor3=C.dark,BackgroundTransparency=1,BorderSizePixel=0})
    table.insert(UI.navGroups,group)
    text(group,titleValue,9,C.muted,true,{Position=UDim2.fromOffset(5,0),Size=UDim2.new(1,-10,0,18)})
end
navGroup(0,159,"PRINCIPAL")
navGroup(162,93,"SISTEMA")
navGroup(259,61,"CONFIG")
navGroup(323,60,"SERVER")
local function nav(label,symbol,y,page)
    local section=(page=="Server" and 4) or (page=="Settings" and 3) or ((page=="Aim" or page=="Player") and 2) or 1
    local group=UI.navGroups[section]
    local rel=section==4 and (y-323) or (section==3 and (y-259) or (section==2 and (y-162) or y))
    local b=new("TextButton",group,{Name=label,Position=UDim2.fromOffset(2,rel+21),Size=UDim2.new(1,-4,0,29),BackgroundColor3=C.dark,BorderSizePixel=0,Text="",AutoButtonColor=false})
    round(b,5)
    line(b,C.line,.72)
    local marker=new("Frame",b,{Name="ActiveMarker",Position=UDim2.fromOffset(0,5),Size=UDim2.fromOffset(3,19),BackgroundColor3=C.red,BorderSizePixel=0,Visible=false})
    local iconId = CATEGORY_ICON_IDS[page]
    if iconId then
        new("ImageLabel",b,{
            Name="CategoryIcon",Position=UDim2.fromOffset(9,5),
            Size=UDim2.fromOffset(19,19),BackgroundTransparency=1,
            Image="rbxassetid://"..iconId,ScaleType=Enum.ScaleType.Fit,
            ImageColor3=C.white,BorderSizePixel=0,Active=false
        })
    else
        -- Las categorias OP y Aim mantienen su simbolo original.
        text(b,symbol,16,C.white,true,{Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(21,29),TextXAlignment=Enum.TextXAlignment.Center})
    end
    text(b,label,11,C.ink,true,{Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-39,1,0),TextTruncate=Enum.TextTruncate.AtEnd})
    pageButtons[page]=b
    connect(b.MouseButton1Click,function() playSound(clickSound);showPage(page) end)
end
nav("Home","⌂",0,"Home")
nav("Event","✦",31,"Event")
nav("OP","◎",62,"Op")
nav("Target","◎",93,"Target")
nav("Aim","⊙",162,"Aim")
nav("Player","◇",193,"Player")
nav("Configuración","⚙",259,"Settings")
nav("Server","◈",323,"Server")
UI.navScroll.CanvasSize=UDim2.fromOffset(0,402)
UI.versionLabel=text(side,"XONI HUB  •  V39",9,C.muted,true,{Position=UDim2.new(0,5,1,-23),Size=UDim2.new(1,-10,0,17),TextXAlignment=Enum.TextXAlignment.Center})
UI.fpsPanel=new("Frame",side,{Name="FPSStatus",Position=UDim2.new(0,12,1,-53),Size=UDim2.new(1,-24,0,25),BackgroundColor3=C.bg,BorderSizePixel=0})
round(UI.fpsPanel,12)
line(UI.fpsPanel,C.line,.5)
UI.fpsDot=new("Frame",UI.fpsPanel,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(9,9),BackgroundColor3=C.mint,BorderSizePixel=0})
round(UI.fpsDot,9)
UI.fpsText=text(UI.fpsPanel,"-- FPS",10,C.white,true,{Position=UDim2.fromOffset(23,2),Size=UDim2.new(1,-27,1,-4),TextXAlignment=Enum.TextXAlignment.Center})

local function pageTitle(p,titleText,desc)
    local box=new("Frame",p,{Name="PageHeading",Size=UDim2.new(1,0,0,41),BackgroundTransparency=1})
    text(box,titleText:upper(),12,C.red,true,{Position=UDim2.fromOffset(4,0),Size=UDim2.new(1,-8,0,19)})
    text(box,desc,10,C.muted,false,{Position=UDim2.fromOffset(4,17),Size=UDim2.new(1,-8,0,22),TextWrapped=true})
end

local function card(p,height)
    local f=new("Frame",p,{Size=UDim2.new(1,0,0,height),BackgroundColor3=Color3.fromRGB(17,17,20),BorderSizePixel=0})
    round(f,4)
    local border=line(f,C.line,.38)
    border.Thickness=.8
    return f
end

local function infoCard(p, titleValue, mainValue, detail, color)
    local f = card(p, 106)
    local band = new("Frame", f, {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color, BorderSizePixel = 0})
    round(band, 9)
    new("Frame", band, {Position = UDim2.new(0, 0, 1, -9), Size = UDim2.new(1, 0, 0, 9), BackgroundColor3 = color, BorderSizePixel = 0})
    text(band, titleValue:upper(), 11, C.white, true, {Position = UDim2.fromOffset(14, 3), Size = UDim2.new(1, -24, 0, 25)})
    local val = text(f, mainValue, 22, C.ink, true, {Position = UDim2.fromOffset(15, 41), Size = UDim2.new(1, -30, 0, 34)})
    text(f, detail, 10, C.muted, false, {Position = UDim2.fromOffset(15, 79), Size = UDim2.new(1, -30, 0, 18)})
    return val
end
UI.searchables = {}
local function registerSearch(obj, words, label)
    local category = "Home"
    for name, page in pairs(pages) do
        if obj.Parent == page then category = name; break end
    end
    UI.searchables[#UI.searchables + 1] = {obj = obj, words = words:lower(), title = label or words, category = category}
end
UI.switches = {}
UI.inlineShortcutCards = {}
local function option(p,titleValue,description,accent,callback)
    local f=card(p,48)
    registerSearch(f,titleValue.." "..description,titleValue)
    text(f,titleValue,11,C.ink,true,{Position=UDim2.fromOffset(10,3),Size=UDim2.new(1,-125,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
    text(f,description,9,C.muted,false,{Position=UDim2.fromOffset(10,22),Size=UDim2.new(1,-125,0,22),TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd})
    local b=new("TextButton",f,{Position=UDim2.new(1,-49,.5,-11),Size=UDim2.fromOffset(40,22),BackgroundColor3=C.dark,Text="",TextColor3=C.white,TextSize=10,Font=Enum.Font.GothamBold,AutoButtonColor=false})
    round(b,14)
    local knob=new("Frame",b,{Size=UDim2.fromOffset(15,15),Position=UDim2.fromOffset(3,3),BackgroundColor3=C.muted,BorderSizePixel=0})
    round(knob,10)
    local symbol=text(knob,"",10,C.white,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
    local enabled=false
    local item={button=b,knob=knob}
    function item.refresh(animate)
        local bg=enabled and C.red or C.dark
        local pos=UDim2.fromOffset(enabled and 22 or 3,3)
        knob.BackgroundColor3=enabled and C.white or C.muted
        symbol.Text=enabled and "✓" or ""
        symbol.TextColor3=enabled and C.red or C.white
        if animate and config.animations then
            tween(b,.15,{BackgroundColor3=bg})
            tween(knob,.18,{Position=pos})
        else
            b.BackgroundColor3=bg
            knob.Position=pos
        end
    end
    table.insert(UI.switches,item)
    UI.inlineShortcutCards[titleValue]={card=f,main=b}
    local function set(v,silent)
        enabled=not not v
        item.refresh(not silent)
        callback(enabled)
        if not silent then notify(titleValue,enabled and "Función activada" or "Función desactivada",enabled and accent or C.muted) end
    end
    connect(b.MouseButton1Click,function()playSound(clickSound);set(not enabled)end)
    return set
end


local function actionOption(p,titleValue,description,accent,callback)
    local f=card(p,56)
    registerSearch(f,titleValue.." "..description,titleValue)
    text(f,titleValue,11,C.ink,true,{Position=UDim2.fromOffset(10,3),Size=UDim2.new(1,-173,0,21)})
    text(f,description,9,C.muted,false,{Position=UDim2.fromOffset(10,23),Size=UDim2.new(1,-173,0,30),TextWrapped=true})
    local b=new("TextButton",f,{Position=UDim2.new(1,-86,.5,-12),Size=UDim2.fromOffset(77,24),BackgroundColor3=C.red,TextColor3=C.white,Text="EJECUTAR",TextSize=9,Font=Enum.Font.GothamBold,AutoButtonColor=false})
    round(b,4)
    UI.inlineShortcutCards[titleValue]={card=f,main=b}
    connect(b.MouseButton1Click,function()
        playSound(clickSound)
        tween(b,.12,{BackgroundTransparency=.28})
        task.delay(.2,function()if b.Parent then tween(b,.15,{BackgroundTransparency=0})end end)
        task.spawn(callback)
    end)
    return b
end

-- Buscador global: resultados de TODAS las categorias con acceso directo a cada tarjeta.
UI.suggestionPanel = new("Frame", main, {
    Name = "Suggestions", Position = UDim2.fromOffset(157, 59),
    Size = UDim2.fromOffset(286, 0), Visible = false,
    BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 35,
    ClipsDescendants = true
})
round(UI.suggestionPanel, 10)
line(UI.suggestionPanel, C.line, 0)
UI.suggestionHeader = text(UI.suggestionPanel, "SUGERENCIAS", 11, C.navy, true, {
    Position = UDim2.fromOffset(12, 5), Size = UDim2.fromOffset(288, 25), ZIndex = 36
})
UI.results = new("Frame", UI.suggestionPanel, {
    Position = UDim2.fromOffset(5, 35), Size = UDim2.fromOffset(305, 0),
    BackgroundTransparency = 1, ZIndex = 36
})
new("UIListLayout", UI.results, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)})
local function focusOption(entry)
    search.Text = ""
    UI.suggestionPanel.Visible = false
    showPage(entry.category)
    local page = pages[entry.category]
    task.defer(function()
        if not page.Parent or not entry.obj.Parent then return end
        local scroller=entry.obj:FindFirstAncestorWhichIsA("ScrollingFrame")
        if scroller then
            local desired=entry.obj.AbsolutePosition.Y-scroller.AbsolutePosition.Y+scroller.CanvasPosition.Y-16
            scroller.CanvasPosition=Vector2.new(0,math.max(0,desired))
        end
        local st = entry.obj:FindFirstChildOfClass("UIStroke")
        if st then
            local old = st.Color
            st.Color = C.purple
            task.delay(0.9, function() if st.Parent then st.Color = old end end)
        end
    end)
end
local function updateSuggestions()
    for _, obj in ipairs(UI.results:GetChildren()) do
        if obj:IsA("TextButton") then obj:Destroy() end
    end
    local query = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then UI.suggestionPanel.Visible = false; return end
    local matches = {}
    for _, entry in ipairs(UI.searchables) do
        if entry.obj.Parent and entry.words:find(query, 1, true) then
            table.insert(matches, entry)
        end
    end
    table.sort(matches, function(a, b)
        local aPrefix = a.title:lower():sub(1, #query) == query
        local bPrefix = b.title:lower():sub(1, #query) == query
        if aPrefix ~= bPrefix then return aPrefix end
        return a.title < b.title
    end)
    local n = math.min(5, #matches)
    UI.suggestionHeader.Text = "SUGERENCIAS  •  " .. tostring(#matches) .. " resultados"
    for i = 1, n do
        local entry = matches[i]
        local row = new("TextButton", UI.results, {
            LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = i % 2 == 0 and C.bg or (C.surface or C.dark),
            BorderSizePixel = 0, Text = "", AutoButtonColor = true, ZIndex = 37
        })
        row.Name = "SuggestionRow"
        round(row, 6)
        text(row, entry.title, 12, C.ink, true, {Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -94, 0, 36), ZIndex = 38, TextTruncate=Enum.TextTruncate.AtEnd})
        text(row, entry.category:upper() .. "  ›", 10, C.muted, true, {Position = UDim2.new(1,-82,0,2), Size = UDim2.fromOffset(74, 36), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 38})
        connect(row.MouseButton1Click, function() playSound(clickSound); focusOption(entry) end)
    end
    if n == 0 then
        local row = new("TextButton", UI.results, {LayoutOrder = 1, Size = UDim2.fromOffset(305, 37), BackgroundTransparency = 1, Text = "No hay opciones con ese nombre", TextColor3 = C.muted, TextSize = 11, Font = Enum.Font.Gotham, ZIndex = 37})
    end
    local panelW = UI.suggestionPanel.Size.X.Offset
    UI.results.Size = UDim2.fromOffset(math.max(120,panelW-10), (n > 0 and n or 1) * 43)
    UI.suggestionPanel.Size = UDim2.fromOffset(panelW, 40 + (n > 0 and n or 1) * 43)
    local wasVisible = UI.suggestionPanel.Visible
    UI.suggestionPanel.Visible = true
    if not wasVisible and config.animations then
        UI.suggestionPanel.BackgroundTransparency = 0.27
        tween(UI.suggestionPanel,0.18,{BackgroundTransparency=0})
    end
end
connect(search:GetPropertyChangedSignal("Text"), updateSuggestions)

pageTitle(homePage, "Panel principal", "Resumen en vivo de tu sesión y estado de las funciones.")
UI.statusOwn = infoCard(homePage, "Tu rol detectado", "ESPERANDO", "Estado de la ronda.", C.purple)
UI.statusPlayers = infoCard(homePage, "Jugadores conectados", tostring(#Players:GetPlayers()), "Cantidad de jugadores en este servidor.", C.mint)
UI.statusOptions = infoCard(homePage, "Funciones activas", "0 / 5", "Coin Collector, ESP y AutoCatchGun.", C.blue)


pageTitle(eventPage, "Eventos", "Acciones disponibles para los caramelos.")
local setFarm
setFarm = option(eventPage, "Coin Collector", "Recolecta caramelos, recupera tu movimiento normal y continúa con el siguiente.", C.mint, function(v)
    if v and #Players:GetPlayers() <= 3 then
        state.farm = false
        task.defer(function()
            setFarm(false, true)
            notify("Coin Collector", "No tienes requisitos necesarios", C.orange)
        end)
        return
    end
    state.farm = v
    if not v then
        -- Guardar la posición ANTES de borrar el estado de escape.
        if returnFromRetreat then returnFromRetreat() end
        unsafeSince=nil
        nearbyDangerActive=false
        retreatState=nil
    end
    setFarmInputLocked(v)
end)
UI.coinStatus = card(eventPage, 65)
UI.coinStatusText = text(UI.coinStatus, "Estado: esperando activación", 12, C.ink, true, {Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 41), TextWrapped = true})

pageTitle(opPage, "OP", "Herramientas y acciones de la partida.")
local setMurder = option(opPage, "ESP Murder", "Marca al Murder en rojo y muestra su usuario.", C.red, function(v) state.murder = v end)
local setSheriff = option(opPage, "ESP Sheriff", "Marca al Sheriff en azul y muestra su usuario.", C.sheriff, function(v) state.sheriff = v end)
local setInnocents = option(opPage, "ESP Players", "Muestra jugadores normales, sin Murder ni Sheriff.", C.mint, function(v) state.innocents = v end)
local setGunEsp = option(opPage, "ESP Gun", "Marca la GunDrop a través de las paredes.", C.red, function(v)
    state.gunEsp = v
    if v then notify("ESP Gun", "Buscando GunDrop en el mapa...", C.red) end
end)
-- Tarjeta INFORMACIÓN DEL ESP eliminada: los controles ESP quedan en OP.

local setAutoGun = option(opPage, "AutoCatchGun", "Busca la Gun Drop y regresa automáticamente.", C.mint, function(v) state.autoGun = v; gunLastSeen = nil end)
local killSheriffButton = actionOption(opPage, "Kill Sheriff", "Acción con Knife sobre el Sheriff, cuando está disponible.", C.red, function() end)
local killAllButton = actionOption(opPage, "Kill All", "Excluye Murder y jugadores en blacklist.", C.purple, function() end)
UI.setAutoKillAll = option(opPage, "Auto Kill All", "Cuando tu rol sea Murder, prioriza Sheriff y ejecuta Kill All automáticamente. Pausa Coin Collector mientras actúa.", C.red, function(v)
    state.autoKillAll = v
end)
pageTitle(pages.Target,"Target","Seleccioná un jugador para ver su perfil y usar las acciones.")
UI.playerManageCard=card(pages.Target,310)
registerSearch(UI.playerManageCard,"kill target objetivo buscar jugador blacklist unblacklist goto fling spectate target", "Player Actions")
text(UI.playerManageCard,"PLAYER ACTIONS",14,C.ink,true,{Position=UDim2.fromOffset(17,10),Size=UDim2.fromOffset(180,27)})
UI.playerSearch=new("TextBox",UI.playerManageCard,{
    Position=UDim2.new(0,17,0,41),Size=UDim2.new(1,-70,0,30),
    BackgroundColor3=C.dark,TextColor3=C.white,PlaceholderColor3=C.muted,
    Font=Enum.Font.Gotham,TextSize=12,PlaceholderText="Buscar @usuario o nombre...",Text="",ClearTextOnFocus=false
})
round(UI.playerSearch,5)
UI.playerToggle=new("TextButton",UI.playerManageCard,{Position=UDim2.new(1,-44,0,41),Size=UDim2.fromOffset(27,30),BackgroundColor3=C.dark,Text="−",TextColor3=C.white,Font=Enum.Font.GothamBold,TextSize=18,AutoButtonColor=false})
round(UI.playerToggle,5)
local edge=line(UI.playerToggle,C.red,.35); edge.Thickness=.8
UI.playerList=new("ScrollingFrame",UI.playerManageCard,{
    Position=UDim2.new(0,17,0,78),Size=UDim2.new(1,-34,0,92),
    BackgroundColor3=C.dark,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,
    CanvasSize=UDim2.fromOffset(0,0),BorderSizePixel=0
})
round(UI.playerList,5)
new("UIListLayout",UI.playerList,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3)})
UI.playerSelected=text(UI.playerManageCard,"Sin jugador seleccionado",11,C.muted,false,{Position=UDim2.fromOffset(17,180),Size=UDim2.new(1,-34,0,18),TextTruncate=Enum.TextTruncate.AtEnd})
UI.playerButtonRow=new("Frame",UI.playerManageCard,{Position=UDim2.fromOffset(17,208),Size=UDim2.new(1,-34,0,70),BackgroundTransparency=1})
local function playerActionButton(parent, txt, x, width, color)
    local b=new("TextButton",parent,{Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(width,28),BackgroundColor3=color,TextColor3=C.white,Text=txt,Font=Enum.Font.GothamBold,TextSize=10,AutoButtonColor=false})
    round(b,6)
    return b
end
-- Los cuatro controles se ajustan al ancho disponible; sin superposiciones.
UI.targetActionGrid=new("UIGridLayout",UI.playerButtonRow,{
    FillDirection=Enum.FillDirection.Horizontal,
    FillDirectionMaxCells=3,
    SortOrder=Enum.SortOrder.LayoutOrder,
    CellSize=UDim2.new(0.333,-5,0,30),
    CellPadding=UDim2.fromOffset(5,5)
})
-- Los botones del Target necesitan superficies tactiles mas grandes.
-- Se ajusta tambien en telefonos que tengan un teclado conectado.
if UIS.TouchEnabled then
    UI.targetActionGrid.FillDirectionMaxCells=2
    UI.targetActionGrid.CellSize=UDim2.new(.5,-5,0,42)
    UI.playerButtonRow.Size=UDim2.new(1,-34,0,140)
end
UI.targetExecute=playerActionButton(UI.playerButtonRow,"KILL TARGET",0,70,C.red)
UI.blacklistToggle=playerActionButton(UI.playerButtonRow,"BLACKLIST",0,65,C.blue)
UI.gotoButton=playerActionButton(UI.playerButtonRow,"GOTO",0,45,C.navy)
UI.flingButton=playerActionButton(UI.playerButtonRow,"FLING",0,47,C.red)
UI.spectateButton=playerActionButton(UI.playerButtonRow,"SPECTATE",0,65,C.blue)
for index,button in ipairs({UI.targetExecute,UI.blacklistToggle,UI.gotoButton,UI.flingButton,UI.spectateButton}) do
    button.LayoutOrder=index
    button.Position=UDim2.fromOffset(0,0)
    button.Size=UDim2.fromOffset(60,30)
    button.Active=true
    button.Selectable=true
    button.TextScaled=true
    new("UITextSizeConstraint",button,{MinTextSize=8,MaxTextSize=10})
end
local function redrawPlayerList()
    local collapsed=config.targetCollapsed
    UI.playerToggle.Text=collapsed and "+" or "−"
    UI.playerList.Visible=not collapsed
    UI.playerSelected.Visible=not collapsed
    UI.playerButtonRow.Visible=not collapsed
    UI.playerManageCard.Size=UDim2.new(1,0,0,collapsed and 82 or (UIS.TouchEnabled and 372 or 310))
end
connect(UI.playerToggle.MouseButton1Click,function() config.targetCollapsed=not config.targetCollapsed; redrawPlayerList(); playSound(clickSound) end)
redrawPlayerList()

-- Una lista amplia con fotos de perfil, selección visible y estado de blacklist.
function UI.updateTargetButtons()
    local player=state.targetUserId and Players:GetPlayerByUserId(state.targetUserId)
    local blacklisted=player and state.blacklist[player.UserId] or false
    UI.blacklistToggle.Text=blacklisted and "UNBLACKLIST" or "BLACKLIST"
    UI.blacklistToggle.BackgroundColor3=blacklisted and C.mint or C.blue
    UI.spectateButton.Text=(player and state.spectatingUserId==player.UserId) and "STOP SPEC" or "SPECTATE"
end
local function refreshPlayerList()
    for _,child in ipairs(UI.playerList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local query=UI.playerSearch.Text:lower()
    local order=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=me and (query=="" or p.Name:lower():find(query,1,true) or p.DisplayName:lower():find(query,1,true)) then
            order+=1
            local selected=state.targetUserId==p.UserId
            local blocked=state.blacklist[p.UserId]
            local row=new("TextButton",UI.playerList,{
                LayoutOrder=order,Size=UDim2.new(1,-5,0,43),
                BackgroundColor3=selected and C.navy or (blocked and Color3.fromRGB(54,30,40) or C.blue),
                Text="",BorderSizePixel=0,AutoButtonColor=false
            })
            round(row,7)
            line(row,selected and C.red or C.line,selected and 0.12 or .65)
            local portrait=new("ImageLabel",row,{
                Name="Avatar",Position=UDim2.fromOffset(6,4),Size=UDim2.fromOffset(35,35),
                BackgroundColor3=C.dark,BorderSizePixel=0,Image="",ScaleType=Enum.ScaleType.Crop
            })
            round(portrait,7)
            text(row,p.DisplayName,12,C.ink,true,{
                Position=UDim2.fromOffset(49,3),Size=UDim2.new(1,-95,0,20),
                TextTruncate=Enum.TextTruncate.AtEnd
            })
            text(row,"@"..p.Name,10,C.muted,false,{
                Position=UDim2.fromOffset(49,22),Size=UDim2.new(1,-95,0,17),
                TextTruncate=Enum.TextTruncate.AtEnd
            })
            local marker=new("ImageLabel",row,{
                Name="TargetActionIcon",Position=UDim2.new(1,-34,0,9),
                Size=UDim2.fromOffset(25,25),BackgroundTransparency=1,
                Image="rbxassetid://130982584062898",ScaleType=Enum.ScaleType.Fit,
                ImageColor3=blocked and C.red or (selected and C.white or C.muted)
            })
            connect(row.MouseButton1Click,function()
                playSound(clickSound)
                state.targetUserId=p.UserId
                UI.playerSelected.Text="Seleccionado: "..p.DisplayName.."  @"..p.Name
                    ..(state.blacklist[p.UserId] and "  •  EN BLACKLIST" or "")
                refreshPlayerList()
            end)
            task.spawn(function()
                local ok,thumbnail=pcall(function()
                    return Players:GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
                end)
                if ok and portrait.Parent then portrait.Image=thumbnail end
            end)
        end
    end
    UI.updateTargetButtons()
end
connect(UI.playerSearch:GetPropertyChangedSignal("Text"),refreshPlayerList)
connect(Players.PlayerAdded,refreshPlayerList)
connect(Players.PlayerRemoving,function() task.defer(refreshPlayerList) end)
refreshPlayerList()

-- AIM: controles independientes, sin bloquear el mouse.
pageTitle(aimPage, "Aim", "Seguimiento visual con FOV y objetivos según tu rol.")
local setAim = option(aimPage, "FOV Circle + Aim", "Círculo y seguimiento suave del cuerpo al estar dentro del FOV.", C.purple, function(v)
    state.aim = v
end)
-- Modo Aimbot: usa el viewport completo sin necesidad de apuntar dentro del círculo.
UI.setAimbot = option(aimPage,"AIMBOT","Objetivos en toda la pantalla; respeta Wallcheck y el estado de vida.",C.red,function(v)
    config.aimbot=v
end)
local setAimWallcheck = option(aimPage, "Wallcheck", "Activado: solo apunta a personajes sin obstáculos. Desactivado: no filtra paredes.", C.sheriff, function(v)
    config.aimWallcheck = v
end)
UI.aimInfo = card(aimPage, 81)
registerSearch(UI.aimInfo, "aim fov seguimiento objetivo sheriff murder cuerpo wallcheck", "Estado Aim")
UI.aimInfoText = text(UI.aimInfo, "AIM: desactivado  •  WALLCHECK: No\nMurder → Sheriff  |  Sheriff → Murder", 11, C.muted, true, {
    Position=UDim2.fromOffset(16,9), Size=UDim2.new(1,-32,1,-18), TextWrapped=true
})
local function makeAimSlider(label, key, low, high, color, desc)
    local f = card(aimPage, 112)
    UI.whiteAimSliders = UI.whiteAimSliders or {}
    registerSearch(f, label .. " " .. desc, label)
    text(f, label:upper(), 13, C.ink, true, {Position=UDim2.fromOffset(17,8), Size=UDim2.new(1,-145,0,26)})
    local amount=text(f, "", 12, C.navy, true, {Position=UDim2.new(1,-142,0,8), Size=UDim2.fromOffset(125,26), TextXAlignment=Enum.TextXAlignment.Right})
    text(f, desc, 10, C.muted, false, {Position=UDim2.fromOffset(18,34), Size=UDim2.new(1,-36,0,22),TextWrapped=true})
    local track=new("Frame", f, {Position=UDim2.new(0,22,0,82),Size=UDim2.new(1,-44,0,8),BackgroundColor3=C.white,BackgroundTransparency=.52,BorderSizePixel=0,Active=true})
    track.Name="WhiteAimTrack_"..key
    round(track,8)
    track.BackgroundTransparency=0 -- blanco puro
    local fill=new("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.white,BackgroundTransparency=0,BorderSizePixel=0})
    fill.Name="WhiteAimFill_"..key
    round(fill,8)
    local knob=new("TextButton",track,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),Size=UDim2.fromOffset(22,22),BackgroundColor3=C.white,Text="",AutoButtonColor=false,ZIndex=5})
    knob.Name="WhiteAimKnob_"..key
    round(knob,20)
    knob.BackgroundTransparency=0
    knob.ZIndex=8
    table.insert(UI.whiteAimSliders,{track=track,fill=fill,knob=knob})
    line(knob,C.white,0)
    local held = false
    local function set(value)
        config[key]=math.clamp(math.floor(value+0.5),low,high)
        local f=(config[key]-low)/(high-low)
        fill.Size=UDim2.fromScale(f,1)
        knob.Position=UDim2.fromScale(f,0.5)
        amount.Text=tostring(config[key])..(key=="aimFov" and " px" or "%")
    end
    local function pointer(x)
        local fraction=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        set(low+(high-low)*fraction)
    end
    for _, item in ipairs({track,knob}) do
        connect(item.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                held=true
                pointer(input.Position.X)
            end
        end)
    end
    connect(UIS.InputChanged,function(input)
        if held and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            pointer(input.Position.X)
        end
    end)
    connect(UIS.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then held=false end
    end)
    set(config[key])
    return set
end
local setAimFov = makeAimSlider("Tamaño del FOV", "aimFov", 60, 420, C.white, "Radio de detección alrededor del centro de la pantalla.")
local setAimSmooth = makeAimSlider("Suavidad", "aimSmooth", 1, 100, C.white, "1 = fijación inmediata; valores altos = seguimiento más lento.")
-- Overlay circular. No intercepta clics, movimiento de cámara ni eventos táctiles.
local aimOverlay = new("Frame", gui, {Name="AimFovVisual",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(config.aimFov*2,config.aimFov*2),BackgroundTransparency=1,Visible=false,ZIndex=10,Active=false})
new("UICorner",aimOverlay,{CornerRadius=UDim.new(1,0)})
local aimOutline = new("UIStroke",aimOverlay,{Thickness=2,Color=C.white,Transparency=0.03,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})

pageTitle(playerPage, "Player", "Opciones de movimiento personalizables.")
local setNoclip = option(playerPage, "Noclip", "Permite atravesar objetos. Al desactivar restaura las colisiones.", C.purple, function(v) state.noclip = v end)
local setInfiniteJump = option(playerPage, "Infinite Jump", "Podés saltar nuevamente en el aire.", C.mint, function(v) state.infiniteJump = v end)
local setFly = option(playerPage, "Fly", "Vuelo con control de cámara y movimiento estable.", C.orange, function(v) state.flying = v end)
-- Velocidad al final de Player.
local setFastMove = option(playerPage, "Velocidad", "Ajustá la velocidad horizontal deslizando la barra.", C.sheriff, function(v) state.fastMove = v end)
UI.speedCard = card(playerPage, 104)
registerSearch(UI.speedCard, "velocidad speed slider deslizador configurar personalizar", "Velocidad")
text(UI.speedCard, "VELOCIDAD", 13, C.ink, true, {Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -115, 0, 27)})
UI.playerSpeedLabel = text(UI.speedCard, "20 / 250", 13, C.navy, true, {Position=UDim2.new(1,-112,0,10), Size=UDim2.fromOffset(95,27),TextXAlignment=Enum.TextXAlignment.Right})
UI.sliderTrack = new("Frame",UI.speedCard,{Name="SpeedSlider",Position=UDim2.new(0,23,0,61),Size=UDim2.new(1,-46,0,6), BackgroundColor3=C.white,BackgroundTransparency=.52,BorderSizePixel=0,Active=true})
round(UI.sliderTrack,8)
UI.sliderFill=new("Frame",UI.sliderTrack,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.white,BorderSizePixel=0})
round(UI.sliderFill,8)
UI.sliderKnob=new("TextButton",UI.sliderTrack,{Name="Handle",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),Size=UDim2.fromOffset(23,23),BackgroundColor3=C.white,Text="",AutoButtonColor=false,ZIndex=4})
round(UI.sliderKnob,20)
line(UI.sliderKnob,C.white,0)
local draggingSpeed=false
local function updateSpeedSlider(value)
    config.playerSpeed=math.clamp(math.floor(value+0.5),10,250)
    local fraction=(config.playerSpeed-10)/240
    UI.sliderFill.Size=UDim2.fromScale(fraction,1)
    UI.sliderKnob.Position=UDim2.fromScale(fraction,0.5)
    UI.playerSpeedLabel.Text=tostring(config.playerSpeed).." / 250"
end
local function setSpeedByPointer(x)
    local width=math.max(1,UI.sliderTrack.AbsoluteSize.X)
    local fraction=math.clamp((x-UI.sliderTrack.AbsolutePosition.X)/width,0,1)
    updateSpeedSlider(10+fraction*240)
end
connect(UI.sliderTrack.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        draggingSpeed=true
        setSpeedByPointer(input.Position.X)
    end
end)
connect(UI.sliderKnob.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        draggingSpeed=true
        setSpeedByPointer(input.Position.X)
    end
end)
connect(UIS.InputChanged,function(input)
    if draggingSpeed and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        setSpeedByPointer(input.Position.X)
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingSpeed=false end
end)
updateSpeedSlider(config.playerSpeed)


pageTitle(settingsPage, "Configuración", "Preferencias visuales y de avisos.")
local setNotif = option(settingsPage, "Notificaciones", "Muestra avisos en la esquina inferior derecha.", C.purple, function(v) config.notify = v end)
local setSound = option(settingsPage, "Sonidos", "Reproduce un pequeño sonido de aviso y clic.", C.orange, function(v) config.sounds = v end)
UI.setAntiAfk = option(opPage, "Anti-AFK", "Intenta enviar una entrada virtual a Roblox cada 15 segundos. No hace clic en el escritorio.", C.mint, function(v)
    state.antiAfk = v
end)


-- Inicializacion de settings sin toast
setNotif(true, true)
setSound(true, true)
local setRainbow = option(settingsPage,"RAINBOW","Activa los colores arcoíris del botón Open Menu.",C.red,function(v)
    config.rainbowLauncher=v
    if not v and UI.launcherStroke then UI.launcherStroke.Color=C.red end
end)
setRainbow(true,true)

-- Temas visuales: superficie, texto y componentes; elementos de identidad
-- (UI.avatar, titulo, marcadores de rol, acentos de acción) quedan intactos.
local THEMES = {
    {name="Rojo", blue=Color3.fromRGB(20,20,23),dark=Color3.fromRGB(17,17,20),navy=Color3.fromRGB(106,20,27),bg=Color3.fromRGB(10,10,12),ink=Color3.fromRGB(238,238,241),muted=Color3.fromRGB(151,152,161),line=Color3.fromRGB(64,64,69),surface=Color3.fromRGB(19,19,22)},
    {name="Carbon", blue=Color3.fromRGB(46,46,49),dark=Color3.fromRGB(29,29,33),navy=Color3.fromRGB(95,32,36),bg=Color3.fromRGB(19,19,22),ink=Color3.fromRGB(245,245,245),muted=Color3.fromRGB(173,173,180),line=Color3.fromRGB(91,91,99),surface=Color3.fromRGB(40,40,44)},
    {name="Carmesi", blue=Color3.fromRGB(60,31,39),dark=Color3.fromRGB(34,21,25),navy=Color3.fromRGB(118,35,52),bg=Color3.fromRGB(24,16,20),ink=Color3.fromRGB(255,240,243),muted=Color3.fromRGB(205,166,173),line=Color3.fromRGB(106,67,77),surface=Color3.fromRGB(51,31,39)},
    {name="Grafito", blue=Color3.fromRGB(45,48,55),dark=Color3.fromRGB(31,33,39),navy=Color3.fromRGB(103,32,38),bg=Color3.fromRGB(20,22,28),ink=Color3.fromRGB(241,243,248),muted=Color3.fromRGB(165,171,184),line=Color3.fromRGB(83,88,100),surface=Color3.fromRGB(40,43,50)},
    {name="Noche", blue=Color3.fromRGB(34,36,46),dark=Color3.fromRGB(22,24,32),navy=Color3.fromRGB(88,23,36),bg=Color3.fromRGB(14,16,24),ink=Color3.fromRGB(233,238,251),muted=Color3.fromRGB(151,161,186),line=Color3.fromRGB(67,75,95),surface=Color3.fromRGB(31,34,45)},
    {name="Rubí",blue=Color3.fromRGB(60,34,43),dark=Color3.fromRGB(40,25,31),navy=Color3.fromRGB(147,36,62),bg=Color3.fromRGB(25,18,23),ink=Color3.fromRGB(255,240,244),muted=Color3.fromRGB(213,171,184),line=Color3.fromRGB(126,74,91),surface=Color3.fromRGB(56,32,42)},
    {name="Amatista",blue=Color3.fromRGB(48,37,62),dark=Color3.fromRGB(30,26,39),navy=Color3.fromRGB(112,57,156),bg=Color3.fromRGB(21,18,29),ink=Color3.fromRGB(246,239,255),muted=Color3.fromRGB(183,170,202),line=Color3.fromRGB(93,76,111),surface=Color3.fromRGB(40,33,52)},
    {name="Océano",blue=Color3.fromRGB(32,47,59),dark=Color3.fromRGB(23,32,41),navy=Color3.fromRGB(35,115,152),bg=Color3.fromRGB(17,25,33),ink=Color3.fromRGB(236,247,255),muted=Color3.fromRGB(161,189,204),line=Color3.fromRGB(70,101,118),surface=Color3.fromRGB(31,46,57)},
    {name="Bosque",blue=Color3.fromRGB(35,52,47),dark=Color3.fromRGB(25,37,33),navy=Color3.fromRGB(35,125,93),bg=Color3.fromRGB(18,27,24),ink=Color3.fromRGB(236,250,244),muted=Color3.fromRGB(162,192,180),line=Color3.fromRGB(72,105,90),surface=Color3.fromRGB(34,49,43)},
    {name="Rosa",blue=Color3.fromRGB(59,37,51),dark=Color3.fromRGB(35,26,35),navy=Color3.fromRGB(193,71,130),bg=Color3.fromRGB(23,17,24),ink=Color3.fromRGB(255,239,247),muted=Color3.fromRGB(211,170,190),line=Color3.fromRGB(116,75,98),surface=Color3.fromRGB(46,30,42)},
    {name="Neón",blue=Color3.fromRGB(23,39,42),dark=Color3.fromRGB(17,27,31),navy=Color3.fromRGB(0,164,167),bg=Color3.fromRGB(10,20,24),ink=Color3.fromRGB(225,255,255),muted=Color3.fromRGB(151,200,201),line=Color3.fromRGB(54,102,106),surface=Color3.fromRGB(25,45,49)},
    {name="Dorado",blue=Color3.fromRGB(49,42,29),dark=Color3.fromRGB(28,26,22),navy=Color3.fromRGB(178,126,43),bg=Color3.fromRGB(19,18,15),ink=Color3.fromRGB(254,247,222),muted=Color3.fromRGB(200,184,149),line=Color3.fromRGB(112,97,63),surface=Color3.fromRGB(42,37,27)},
    {name="Hielo",blue=Color3.fromRGB(36,47,59),dark=Color3.fromRGB(23,31,40),navy=Color3.fromRGB(85,166,209),bg=Color3.fromRGB(15,23,31),ink=Color3.fromRGB(241,251,255),muted=Color3.fromRGB(171,200,215),line=Color3.fromRGB(77,110,134),surface=Color3.fromRGB(32,43,55)},
    {name="Violeta",blue=Color3.fromRGB(42,34,60),dark=Color3.fromRGB(27,23,37),navy=Color3.fromRGB(138,76,224),bg=Color3.fromRGB(18,15,27),ink=Color3.fromRGB(246,237,255),muted=Color3.fromRGB(190,173,216),line=Color3.fromRGB(96,73,124),surface=Color3.fromRGB(38,30,54)},
    {name="Esmeralda",blue=Color3.fromRGB(28,51,44),dark=Color3.fromRGB(21,34,29),navy=Color3.fromRGB(25,165,116),bg=Color3.fromRGB(14,25,21),ink=Color3.fromRGB(235,255,247),muted=Color3.fromRGB(161,206,187),line=Color3.fromRGB(64,119,94),surface=Color3.fromRGB(29,49,40)},
    {name="Blanco y Negro",blue=Color3.fromRGB(242,243,245),dark=Color3.fromRGB(255,255,255),navy=Color3.fromRGB(30,30,34),bg=Color3.fromRGB(232,233,237),ink=Color3.fromRGB(18,19,23),muted=Color3.fromRGB(94,96,105),line=Color3.fromRGB(190,193,200),surface=Color3.fromRGB(255,255,255)}
}
local sourceColors = {
    blue=C.blue, dark=C.dark, navy=C.navy, bg=C.bg,
    ink=C.ink, muted=C.muted, line=C.line, surface=C.white
}
local themeTargets = {}
local function themeToken(color, prop, obj)
    -- No recolorear los controles blancos de AIM.
    if obj.Name:find("^WhiteAim") then return nil end
    if obj == UI.avatar or obj == UI.avatarShadow or obj:IsDescendantOf(UI.avatarShadow) then return nil end
    if obj:IsDescendantOf(alerts) then return nil end
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then return nil end
    -- Blanco en textos significa blanco fijo, no fondo oscuro.
    if prop == "TextColor3" and color == C.white then return nil end
    if prop == "BackgroundColor3" and color == C.white then return "surface" end
    for _, token in ipairs({"blue", "dark", "navy", "bg", "ink", "muted", "line"}) do
        if color == sourceColors[token] then return token end
    end
    return nil
end
local function trackThemeObject(obj)
    if obj:IsA("Highlight") or obj:IsA("BillboardGui") or obj.Name == "RoleTag" then return end
    for _, prop in ipairs({"BackgroundColor3", "TextColor3", "PlaceholderColor3", "ScrollBarImageColor3", "Color"}) do
        local ok, value = pcall(function() return obj[prop] end)
        if ok and typeof(value) == "Color3" then
            local token = themeToken(value, prop, obj)
            if token then table.insert(themeTargets, {obj=obj, prop=prop, token=token}) end
        end
    end
end
local currentTheme = THEMES[1]
local function applyTheme(palette)
    currentTheme = palette
    config.theme = palette.name
    for k, v in pairs(palette) do if k ~= "name" then C[k] = v end end
    -- Respetar blanco real para texto encima de barras, y los colores de roles.
    C.white = Color3.fromRGB(255,255,255)
    C.surface = palette.surface
    for _, target in ipairs(themeTargets) do
        if target.obj.Parent then
            pcall(function() target.obj[target.prop] = palette[target.token] end)
        end
    end
    for name, button in pairs(pageButtons) do
        button.BackgroundColor3 = name == activePage and C.navy or C.dark
    end
    -- Nunca volver opacos los paneles de categorías (evita rectángulos grises).
    for _,navSection in ipairs(UI.navGroups) do
        navSection.BackgroundTransparency=1
    end
    UI.navScroll.BackgroundTransparency=1
    -- Barras y tiradores blancos en todos los temas.
    for _,slider in ipairs({UI.sliderTrack,UI.sizeTrack,UI.opacityTrack}) do
        if slider and slider.Parent then slider.BackgroundColor3=C.white end
    end
    for _,handle in ipairs({UI.sliderKnob,UI.sizeHandle,UI.opacityKnob}) do
        if handle and handle.Parent then handle.BackgroundColor3=C.white end
    end
    if UI.whiteAimSliders then
        for _,slider in ipairs(UI.whiteAimSliders) do
            for _,part in ipairs({slider.track,slider.fill,slider.knob}) do
                if part and part.Parent then
                    part.BackgroundColor3=Color3.fromRGB(255,255,255)
                    part.BackgroundTransparency=0
                end
            end
        end
    end
    if aimOutline and aimOutline.Parent then aimOutline.Color=C.white end
    -- Los interruptores se colorean según su estado REAL, no según el color anterior.
    for _,item in ipairs(UI.switches) do
        if item.button.Parent then item.refresh(false) end
    end
    -- Resultados creados después del registro inicial de temas.
    UI.suggestionPanel.BackgroundColor3 = C.surface
    UI.suggestionHeader.TextColor3 = C.red
    for _,row in ipairs(UI.results:GetChildren()) do
        if row:IsA("TextButton") and row.Name=="SuggestionRow" then
            row.BackgroundColor3 = (row.LayoutOrder % 2 == 0) and C.bg or C.surface
            for _,child in ipairs(row:GetChildren()) do
                if child:IsA("TextLabel") then
                    child.TextColor3 = (child.TextSize >= 12) and C.ink or C.muted
                end
            end
        end
    end
    for _,toast in ipairs(alerts:GetChildren()) do
        if toast:IsA("Frame") and toast.Name == "Toast" then
            toast.BackgroundColor3=C.blue
            local stripe=toast:FindFirstChild("ToneStripe")
            if stripe then stripe.BackgroundColor3=C.navy end
            local stroke=toast:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color=C.line end
            for _,item in ipairs(toast:GetChildren()) do
                if item:IsA("TextLabel") then
                    item.TextColor3=item.TextSize>=12 and C.ink or C.muted
                end
            end
        end
    end
    UI.avatar.ImageColor3 = Color3.new(1,1,1)
    UI.avatar.ImageTransparency = 0
    UI.avatar.BackgroundColor3 = Color3.fromRGB(245,247,251)
    UI.avatarShadow.BackgroundColor3 = Color3.fromRGB(255,255,255)
    -- Modo claro completo: sin degradados oscuros sobre superficies blancas.
    -- Los demás temas restauran los degradados originales.
    for _,obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("UIGradient") then
            obj.Enabled=palette.name~="Blanco y Negro"
        elseif palette.name=="Blanco y Negro" and obj:IsA("TextLabel") then
            if obj.TextColor3==Color3.fromRGB(255,255,255)
                and not obj:IsDescendantOf(alerts) and not obj:IsDescendantOf(UI.fpsPanel) then
                local parent=obj.Parent
                if parent and parent:IsA("GuiObject") and parent.BackgroundTransparency>=0.5 then
                    obj.TextColor3=C.ink
                end
            end
        end
    end
    if palette.name=="Blanco y Negro" then
        if UI.mainBorder then UI.mainBorder.Color=C.navy end
        if UI.logoStroke then UI.logoStroke.Color=C.navy end
        UI.headerTitle.TextColor3=C.ink
        UI.displayNameLabel.TextColor3=C.ink
        search.TextColor3=C.ink
        search.PlaceholderColor3=C.muted
        UI.versionLabel.TextColor3=C.muted
        UI.fpsText.TextColor3=C.ink
        for _,b in pairs(pageButtons) do
            for _,c in ipairs(b:GetChildren()) do
                if c:IsA("TextLabel") then c.TextColor3=(b==pageButtons[activePage]) and C.white or C.ink end
            end
        end
    end
    if palette.name~="Blanco y Negro" then
        if UI.mainBorder then UI.mainBorder.Color=C.red end
        if UI.logoStroke then UI.logoStroke.Color=C.red end
        UI.headerTitle.TextColor3=C.white
        UI.displayNameLabel.TextColor3=C.ink
        UI.fpsText.TextColor3=C.white
        for _,b in pairs(pageButtons) do
            for _,c in ipairs(b:GetChildren()) do
                if c:IsA("TextLabel") then c.TextColor3=C.ink end
            end
        end
    end
    notify("Tema actualizado", "Tema " .. palette.name .. " aplicado", C.mint)
end

UI.themeCard = card(settingsPage, 365)
registerSearch(UI.themeCard, "tema colores color apariencia azul rosa violeta verde noche", "Temas y colores")
text(UI.themeCard, "TEMAS Y COLORES", 13, C.ink, true, {Position = UDim2.fromOffset(16, 7), Size = UDim2.new(1,-30,0,29)})
for i, palette in ipairs(THEMES) do
    local b = new("TextButton", UI.themeCard, {
        Position = UDim2.new(((i-1)%3)/3, 10, 0, 44 + math.floor((i-1)/3)*51), Size = UDim2.new(1/3, -20, 0, 43),
        BackgroundColor3 = palette.blue, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, Text = palette.name, TextSize = 10, TextColor3 = Color3.new(1,1,1)
    })
    round(b, 7)
    connect(b.MouseButton1Click, function() playSound(clickSound); applyTheme(palette) end)
end

-- SERVER: cambio aleatorio. Sin API externa de listados NO se puede garantizar ocupación.
pageTitle(pages.Server,"Server","Cambiar de servidor sin perder el acceso al panel.")
UI.serverMode="random"
UI.serverCard=card(pages.Server,185)
text(UI.serverCard,"SERVER HOP",14,C.ink,true,{Position=UDim2.fromOffset(15,10),Size=UDim2.new(1,-30,0,24)})
text(UI.serverCard,"Ocupación preferida",11,C.muted,false,{Position=UDim2.fromOffset(15,40),Size=UDim2.new(1,-30,0,22)})
UI.serverModes={}
for i,data in ipairs({{"ALEATORIO","random"},{"MENOS LLENO","low"},{"LLENO","high"}}) do
    local b=new("TextButton",UI.serverCard,{Position=UDim2.new((i-1)/3,12,0,71),Size=UDim2.new(1/3,-18,0,30),BackgroundColor3=i==1 and C.navy or C.dark,TextColor3=C.white,Text=data[1],TextSize=9,Font=Enum.Font.GothamBold,BorderSizePixel=0})
    round(b,5)
    UI.serverModes[i]=b
    connect(b.MouseButton1Click,function()
        UI.serverMode=data[2]
        for j,other in ipairs(UI.serverModes) do other.BackgroundColor3=j==i and C.navy or C.dark end
        if data[2]~="random" then
            notify("Server Hop","No es posible verificar ocupación sin un listado de servidores autorizado.",C.orange)
        end
    end)
end
UI.serverHop=new("TextButton",UI.serverCard,{Position=UDim2.new(0,15,0,117),Size=UDim2.new(1,-30,0,36),Text="SERVER HOP",TextColor3=C.white,BackgroundColor3=C.navy,Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0})
round(UI.serverHop,7)
connect(UI.serverHop.MouseButton1Click,function()
    if UI.serverMode~="random" then
        notify("Server Hop","Sin datos de ocupación no puedo elegir un servidor lleno o vacío.",C.orange)
        return
    end
    local ok,err=pcall(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId,me)
    end)
    if not ok then notify("Server Hop",tostring(err),C.orange) end
end)

local syncSizeSlider
UI.scaleCard = card(settingsPage, 119)
registerSearch(UI.scaleCard, "tamaño escala zoom panel aumentar reducir", "Tamaño del panel")
text(UI.scaleCard, "TAMAÑO DEL PANEL", 12, C.ink, true, {Position = UDim2.fromOffset(15, 8), Size = UDim2.new(1,-30,0,26),TextTruncate=Enum.TextTruncate.AtEnd})
UI.scaleText = text(UI.scaleCard, "100%", 12, C.navy, true, {Position = UDim2.new(0,14,0,37), Size = UDim2.fromOffset(65,26), TextXAlignment = Enum.TextXAlignment.Center})
for _, data in ipairs({{"−", -114, -0.1}, {"+", -62, 0.1}}) do
    local button = new("TextButton", UI.scaleCard, {Position = UDim2.new(1,data[2],0,36), Size = UDim2.fromOffset(39,28), BackgroundColor3 = C.blue, TextColor3 = C.white, Text = data[1], Font = Enum.Font.GothamBold, TextSize = 18})
    round(button, 7)
    connect(button.MouseButton1Click, function()
        config.scale = math.clamp(math.floor((config.scale + data[3])*10+0.5)/10, 0.25, 1.6)
        UI.scaleText.Text = tostring(math.floor(config.scale*100+0.5)) .. "%"
        updateScale()
        if syncSizeSlider then syncSizeSlider() end
    end)
end

-- Tamano preciso mediante barra arrastrable (mouse y touch).
UI.sizeTrack=new("Frame",UI.scaleCard,{Position=UDim2.new(0,21,0,90),Size=UDim2.new(1,-42,0,5),BackgroundColor3=C.white,BackgroundTransparency=.52,BorderSizePixel=0,Active=true})
round(UI.sizeTrack,4)
UI.sizeFill=new("Frame",UI.sizeTrack,{BackgroundColor3=C.white,Size=UDim2.fromScale(0,1),BorderSizePixel=0})
round(UI.sizeFill,4)
UI.sizeHandle=new("TextButton",UI.sizeTrack,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(18,18),BackgroundColor3=C.white,Text="",AutoButtonColor=false,ZIndex=9})
round(UI.sizeHandle,10)
local slidingSize=false
syncSizeSlider=function()
    local a=math.clamp((config.scale-.25)/1.35,0,1)
    UI.sizeFill.Size=UDim2.fromScale(a,1)
    UI.sizeHandle.Position=UDim2.fromScale(a,.5)
    UI.scaleText.Text=tostring(math.floor(config.scale*100+0.5)).."%"
end
local function updateSizePointer(x)
    if UI.sizeTrack.AbsoluteSize.X<1 then return end
    local ratio=math.clamp((x-UI.sizeTrack.AbsolutePosition.X)/UI.sizeTrack.AbsoluteSize.X,0,1)
    config.scale=math.floor((.25+ratio*1.35)*100+.5)/100
    syncSizeSlider()
    updateScale()
end
connect(UI.sizeTrack.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        slidingSize=true; updateSizePointer(input.Position.X)
    end
end)
connect(UI.sizeHandle.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        slidingSize=true; updateSizePointer(input.Position.X)
    end
end)
connect(UIS.InputChanged,function(input)
    if slidingSize and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        updateSizePointer(input.Position.X)
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then slidingSize=false end
end)
syncSizeSlider()

-- La opcion de duracion de avisos fue retirada de Configuracion.

UI.saveCard = card(settingsPage, 78)
registerSearch(UI.saveCard, "guardar save config configuración persistente", "Save Config")
text(UI.saveCard, "SAVE CONFIG", 13, C.ink, true, {Position=UDim2.fromOffset(16,12),Size=UDim2.new(1,-193,0,51)})
UI.saveButton = new("TextButton", UI.saveCard, {Position=UDim2.new(1,-171,0,20),Size=UDim2.fromOffset(151,35),BackgroundColor3=C.blue,TextColor3=C.white,Text="GUARDAR",TextSize=11,Font=Enum.Font.GothamBold})
round(UI.saveButton,8)
local applyLoadedConfig = nil
-- Los LocalScripts de Roblox NO tienen acceso nativo a disco.
-- Si el entorno ofrece readfile/writefile, usamos JSON local por UserId.
-- Si no, informamos la limitacion sin fingir que se guardo nada.
UI.buildConfigPayload=function()
    local ids={}
    for id,blocked in pairs(state.blacklist) do
        if blocked then table.insert(ids,id) end
    end
    return {
        theme=config.theme, language=config.language or "es", scale=config.scale,notify=config.notify,
        sounds=config.sounds,rainbowLauncher=config.rainbowLauncher,
        blacklist=ids,playerSpeed=config.playerSpeed,flySpeed=config.flySpeed,
        targetCollapsed=config.targetCollapsed,panelTransparency=config.panelTransparency,
        aimFov=config.aimFov,aimSmooth=config.aimSmooth,aimWallcheck=config.aimWallcheck,aimbot=config.aimbot,
        hotkeys=config.hotkeys,onScreen=config.onScreen,
        enabledOptions={farm=state.farm,autoKillAll=state.autoKillAll,antiAfk=state.antiAfk,murder=state.murder,sheriff=state.sheriff,
            innocents=state.innocents,gunEsp=state.gunEsp,autoGun=state.autoGun,
            aim=state.aim,noclip=state.noclip,infiniteJump=state.infiniteJump,
            flying=state.flying,fastMove=state.fastMove}
    }
end
UI.saveLocalConfig=function()
    if typeof(writefile)~="function" then
        return false,"Este entorno no permite guardar archivos locales. En Roblox Studio hace falta DataStore."
    end
    local ok,err=pcall(function()
        local payload=UI.buildConfigPayload()
        payload.theme=currentTheme.name
        payload.themeColors={
            navy={currentTheme.navy.R,currentTheme.navy.G,currentTheme.navy.B},
            bg={currentTheme.bg.R,currentTheme.bg.G,currentTheme.bg.B}
        }
        local json=game:GetService("HttpService"):JSONEncode(payload)
        writefile(UI.configFileName,json)
    end)
    return ok,ok and "Configuración guardada para tu UserId en este dispositivo" or tostring(err)
end
connect(UI.saveButton.MouseButton1Click,function()
    local ok,message=UI.saveLocalConfig()
    notify("Guardar configuración",message,ok and C.mint or C.orange)
end)

-- Ajuste visual del panel: regula solo fondos y no tapa letras, avatar ni indicadores.
UI.opacityCard=card(settingsPage,108)
registerSearch(UI.opacityCard,"transparencia panel apariencia opacidad", "Transparencia del panel")
text(UI.opacityCard,"TRANSPARENCIA DEL PANEL",12,C.ink,true,{Position=UDim2.fromOffset(15,8),Size=UDim2.new(1,-110,0,26)})
UI.opacityValue=text(UI.opacityCard,"5%",12,C.muted,true,{Position=UDim2.new(1,-90,0,8),Size=UDim2.fromOffset(75,26),TextXAlignment=Enum.TextXAlignment.Right})
UI.opacityTrack=new("Frame",UI.opacityCard,{Position=UDim2.new(0,18,0,70),Size=UDim2.new(1,-36,0,6),BackgroundColor3=C.white,BackgroundTransparency=.52,Active=true,BorderSizePixel=0})
round(UI.opacityTrack,8)
UI.opacityFill=new("Frame",UI.opacityTrack,{Size=UDim2.fromScale(.05/.65,1),BackgroundColor3=C.white,BorderSizePixel=0})
round(UI.opacityFill,8)
UI.opacityKnob=new("TextButton",UI.opacityTrack,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.05/.65,.5),Size=UDim2.fromOffset(17,17),BackgroundColor3=C.white,Text="",AutoButtonColor=false})
round(UI.opacityKnob,10)
local opacitySurfaces={main,UI.header,side,UI.profile}
for _,patchName in ipairs({"HeaderSquareLeft","HeaderSquareBottom"}) do
    local patch=UI.header:FindFirstChild(patchName)
    if patch then table.insert(opacitySurfaces,patch) end
end
for _,patchName in ipairs({"SideSquareRight"}) do
    local patch=side:FindFirstChild(patchName)
    if patch then table.insert(opacitySurfaces,patch) end
end
for _,patchName in ipairs({"ProfileSquareRight","ProfileSquareBottom"}) do
    local patch=UI.profile:FindFirstChild(patchName)
    if patch then table.insert(opacitySurfaces,patch) end
end
-- Los grupos de navegación son transparentes: no agregarlos a opacitySurfaces.
for _,page in pairs(pages) do
    for _,child in ipairs(page:GetChildren()) do
        if child:IsA("Frame") and child.BackgroundTransparency<1 then
            table.insert(opacitySurfaces,child)
        end
    end
end
local function updatePanelTransparency(value)
    config.panelTransparency=math.clamp(value,0,.65)
    UI.opacityValue.Text=tostring(math.floor(config.panelTransparency*100+.5)).."%"
    local ratio=config.panelTransparency/.65
    UI.opacityFill.Size=UDim2.fromScale(ratio,1)
    UI.opacityKnob.Position=UDim2.fromScale(ratio,.5)
    for _,surface in ipairs(opacitySurfaces) do
        if surface and surface.Parent then surface.BackgroundTransparency=config.panelTransparency end
    end
end
local opacityDragging=false
local function opacityPointer(x)
    local width=UI.opacityTrack.AbsoluteSize.X
    if width>1 then
        updatePanelTransparency(math.clamp((x-UI.opacityTrack.AbsolutePosition.X)/width,0,1)*.65)
    end
end
for _,ctrl in ipairs({UI.opacityTrack,UI.opacityKnob}) do
    connect(ctrl.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            opacityDragging=true
            opacityPointer(input.Position.X)
        end
    end)
end
connect(UIS.InputChanged,function(input)
    if opacityDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then opacityPointer(input.Position.X) end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then opacityDragging=false end
end)
updatePanelTransparency(config.panelTransparency)

-- Nexus Op V12: distribución en dos columnas independientes como el panel de referencia.
-- Se reubican las tarjetas existentes sin recrearlas: los callbacks/estados siguen intactos.
local columnPages={}
local function setupColumns(pageName,firstColumnCount)
    local page=pages[pageName]
    local source={}
    for _,child in ipairs(page:GetChildren()) do
        if child:IsA("Frame") then table.insert(source,child) end
    end
    -- Los elementos se crearon en orden; se conserva su orden original.
    for _,obj in ipairs(page:GetChildren()) do
        if obj:IsA("UIListLayout") or obj:IsA("UIPadding") then obj:Destroy() end
    end
    local cols={}
    for i=1,2 do
        local col=new("ScrollingFrame",page,{
            Name=i==1 and "LeftControls" or "RightControls",Position=UDim2.new((i-1)*.5, (i==1 and 9 or 4), 0, 9),
            Size=UDim2.new(.5,-13,1,-18),BackgroundColor3=C.bg,BackgroundTransparency=0,
            BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.red,
            CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y
        })
        round(col,5)
        line(col,C.line,.2)
        new("UIPadding",col,{PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,12)})
        new("UIListLayout",col,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        cols[i]=col
    end
    for i,obj in ipairs(source) do
        obj.LayoutOrder=i
        obj.Parent=cols[i<=firstColumnCount and 1 or 2]
    end
    columnPages[pageName]=cols
end
setupColumns("Home",3)
setupColumns("Event",2)
setupColumns("Op",7)
setupColumns("Aim",4)
setupColumns("Player",4)
setupColumns("Settings",7)
-- Redistribuir controles en función del tamaño visible.
applyResponsiveLayout=function()
    local w,h=configuredWidth,configuredHeight
    local sideWidth=compact and 128 or 142
    side.Size=UDim2.fromOffset(sideWidth,h)
    UI.profile.Size=UDim2.fromOffset(sideWidth,76)
    UI.panelLogo.Position=UDim2.fromOffset(math.floor((sideWidth-46)/2),10)
    UI.header.Position=UDim2.fromOffset(sideWidth,0)
    UI.header.Size=UDim2.new(1,-sideWidth,0,62)
    UI.separatorProfile.Size=UDim2.fromOffset(sideWidth-16,1)
    UI.separatorHeader.Position=UDim2.fromOffset(sideWidth+8,61)
    UI.separatorHeader.Size=UDim2.new(1,-sideWidth-16,0,1)
    UI.separatorSidebar.Position=UDim2.fromOffset(sideWidth-1,76)
    UI.separatorSidebar.Size=UDim2.new(0,1,1,-84)
    UI.content.Position=UDim2.fromOffset(sideWidth,62)
    UI.content.Size=UDim2.fromOffset(w-sideWidth,h-62)
    search.Size=UDim2.fromOffset(math.min(285,w-sideWidth-140),23)
    UI.topStatus.Visible=not compact
    UI.navScroll.Size=UDim2.new(1,0,1,-122)
    UI.versionLabel.Position=UDim2.new(0,5,1,-23)
    UI.fpsPanel.Position=UDim2.new(0,12,1,-53)
    for _,group in ipairs(UI.navGroups) do group.Size=UDim2.new(1,-12,0,group.Size.Y.Offset) end
    UI.suggestionPanel.Position=UDim2.fromOffset(sideWidth+15,59)
    UI.suggestionPanel.Size=UDim2.fromOffset(math.min(286,w-sideWidth-30),UI.suggestionPanel.Size.Y.Offset)
    UI.results.Size=UDim2.new(1,-10,0,UI.results.Size.Y.Offset)
end

applyResponsiveLayout()
updateScale()
showPage("Home")
main.Visible=false

-- Boton compacto minimizado: icono de 4 flechas + Open Menu, como la referencia.
local launcher = new("TextButton", gui, {
    Name="OpenDashboard",AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0,10),Size=UDim2.fromOffset(145,28),
    BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.6,BorderSizePixel=0,
    Text="",TextColor3=C.white,TextSize=11,Font=Enum.Font.GothamBold,
    Visible=false,Active=true,AutoButtonColor=false
})
round(launcher, 12)
-- Flechas | imagen principal + Open Menu (sin segunda barra).
local launcherIcon = new("ImageLabel", launcher, {
    Name="ArrowsIcon",Position=UDim2.fromOffset(7,5),
    Size=UDim2.fromOffset(18,18),BackgroundTransparency=1,
    Image="rbxassetid://"..OPEN_MENU_ICON_ID,
    ImageColor3=C.white,ScaleType=Enum.ScaleType.Fit,Active=false
})
round(launcherIcon, 6)
local launcherBrandIcon = new("ImageLabel", launcher, {
    Name="PanelLogoIcon",Position=UDim2.fromOffset(35,5),
    Size=UDim2.fromOffset(18,18),BackgroundTransparency=1,
    Image="rbxassetid://"..ICON_ID,
    ImageColor3=C.white,ScaleType=Enum.ScaleType.Fit,Active=false
})
round(launcherBrandIcon, 6)
local launcherSeparator = new("Frame",launcher,{Name="Separator",Position=UDim2.fromOffset(29,6),Size=UDim2.fromOffset(1,16),BackgroundColor3=Color3.fromRGB(150,150,158),BorderSizePixel=0})
local launcherLabel = text(launcher,"Open Menu",10,C.white,true,{
    Name="OpenMenuLabel",Position=UDim2.fromOffset(57,0),
    Size=UDim2.new(1,-61,1,0),TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd,Active=false
})
-- Un Frame transparente exacto encima del boton recibe el UIStroke;
-- la letra M se colorea aparte y nunca tiene contorno verde.
UI.launcherOutlineFrame = new("Frame",launcher,{
    Name="RainbowOutline",BackgroundTransparency=1,
    Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),
    BorderSizePixel=0,Active=false,ZIndex=launcher.ZIndex+1
})
round(UI.launcherOutlineFrame,11)
UI.launcherStroke = line(UI.launcherOutlineFrame,C.red,0)
UI.launcherStroke.Thickness = 1.3
UI.launcherGradient=new("UIGradient",UI.launcherStroke,{
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,35,55)),
        ColorSequenceKeypoint.new(.24,Color3.fromRGB(255,181,41)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(57,245,118)),
        ColorSequenceKeypoint.new(.75,Color3.fromRGB(60,151,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(226,73,244))
    })
})
connect(RunService.RenderStepped,function()
    if not launcher.Visible then return end
    if config.rainbowLauncher then
        launcherIcon.ImageColor3=Color3.fromHSV((os.clock()*0.18)%1,0.70,1)
        launcherBrandIcon.ImageColor3=C.white
        UI.launcherStroke.Color=Color3.new(1,1,1)
        UI.launcherGradient.Enabled=true
        UI.launcherGradient.Rotation=(os.clock()*55)%360
    else
        launcherIcon.ImageColor3=C.white
        launcherBrandIcon.ImageColor3=C.white
        UI.launcherGradient.Enabled=false
        UI.launcherStroke.Color=C.red
    end
end)
local launchDrag = {active = false, moved = false, input = nil, start = nil, pos = nil}
connect(launcher.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        launchDrag.active = true
        launchDrag.input = input
        launchDrag.moved = false
        launchDrag.start = input.Position
        launchDrag.pos = launcher.Position
        launchDrag.target = launcher.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if not launchDrag.active then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input == launchDrag.input then
        local delta = input.Position - launchDrag.start
        if delta.Magnitude > 5 then launchDrag.moved = true end
        local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        local nextX=launchDrag.pos.X.Scale*vp.X+launchDrag.pos.X.Offset+delta.X
        local nextY=launchDrag.pos.Y.Scale*vp.Y+launchDrag.pos.Y.Offset+delta.Y
        launchDrag.target=UDim2.fromOffset(math.clamp(nextX,launcher.AbsoluteSize.X/2+5,math.max(launcher.AbsoluteSize.X/2+5,vp.X-launcher.AbsoluteSize.X/2-5)),math.clamp(nextY,5,math.max(5,vp.Y-launcher.AbsoluteSize.Y-5)))
    end
end)
connect(UIS.InputEnded, function(input)
    if input == launchDrag.input then
        launchDrag.active = false
        launchDrag.input = nil
    end
end)
-- Interpolación de arrastre sin tocar el cursor ni la cámara.
connect(RunService.RenderStepped,function(dt)
    if launcher.Visible and launchDrag.target then
        local a = config.animations and (1-math.exp(-24*dt)) or 1
        launcher.Position = launcher.Position:Lerp(launchDrag.target,a)
    end
end)
connect(launcher.MouseButton1Click, function()
    if launchDrag.moved then launchDrag.moved = false; return end
    playSound(clickSound)
    main.Visible = true
    launcher.Visible = false
    state.open = true
    main.Size = UDim2.fromOffset(configuredWidth, configuredHeight-24)
    tween(main, 0.22, {Size = UDim2.fromOffset(configuredWidth, configuredHeight)})
end)
function UI.hidePanel()
    main.Visible = false
    launcher.Visible = true
    state.open = false
end
headerButton("−", -73, C.dark, UI.hidePanel)
function UI.cleanVisual(p)
    local v = visuals[p]
    if not v then return end
    if v.highlight then v.highlight:Destroy() end
    if v.billboard then v.billboard:Destroy() end
    visuals[p] = nil
end
-- Restituir exactamente las propiedades originales de movimiento.
function UI.restoreFarmCharacter()
    if runningTween then runningTween:Cancel(); runningTween = nil end
    local snap = savedParts
    savedParts = nil
    if not snap then return end
    for part, collidable in pairs(snap.parts) do
        if part and part.Parent then part.CanCollide = collidable end
    end
    if snap.hrp and snap.hrp.Parent then
        snap.hrp.Anchored = snap.anchored
        snap.hrp.AssemblyLinearVelocity = Vector3.zero
        snap.hrp.AssemblyAngularVelocity = Vector3.zero
    end
    if snap.humanoid and snap.humanoid.Parent then
        snap.humanoid.PlatformStand = snap.platform
        snap.humanoid.AutoRotate = snap.autoRotate
        snap.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end
function UI.snapshotCharacter()
    local char = me.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil end
    local snap = {parts = {}, hrp = hrp, humanoid = hum, anchored = hrp.Anchored, platform = hum.PlatformStand, autoRotate = hum.AutoRotate}
    for _, bp in ipairs(char:GetDescendants()) do
        if bp:IsA("BasePart") then snap.parts[bp] = bp.CanCollide end
    end
    return snap
end
function UI.beginMove(snap)
    savedParts = snap
    -- Guardar/restaurar colisiones reales, sin alterar el cursor ni la camara.
    -- El HRP anclado arrastra al rig mediante sus uniones; evita empujones
    -- mientras el tween lo lleva a la moneda.
    for bp in pairs(snap.parts) do
        if bp.Parent then bp.CanCollide = false end
    end
    snap.hrp.CanCollide = false
    snap.hrp.AssemblyLinearVelocity = Vector3.zero
    snap.hrp.AssemblyAngularVelocity = Vector3.zero
    snap.humanoid.PlatformStand = true
    snap.humanoid.AutoRotate = false
    snap.hrp.Anchored = true
end
headerButton("×", -39, C.red, function()
    state.closing = true
    state.farm = false; if returnFromRetreat then returnFromRetreat() end; retreatState = nil; state.murder = false; state.sheriff = false
    state.innocents = false; state.noclip = false; state.infiniteJump = false
    state.fastMove = false; state.flying = false
    setFarmInputLocked(false)
    RunService:UnbindFromRenderStep("MVSS_AimV8")
    UI.restoreFarmCharacter()
    for p in pairs(visuals) do UI.cleanVisual(p) end
    for _, connection in ipairs(connections) do connection:Disconnect() end
    gui:Destroy()
end)

-- La camara y el cursor quedan a cargo del controlador normal de Roblox.
-- NO forzar MouseBehavior cada frame: eso impide girar la camara con el mouse.
-- Bloqueamos solamente desplazamiento/salto mientras el colector esta activo.

-- DRAG con mouse y touch
local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
connect(UI.header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
        UI.panelDragTarget = main.Position
        local changedConnection
        changedConnection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if changedConnection then changedConnection:Disconnect() end
            end
        end)
    end
end)
connect(UI.header.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
connect(UIS.InputChanged, function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        UI.panelDragTarget = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X / uiScale.Scale, startPos.Y.Scale, startPos.Y.Offset + delta.Y / uiScale.Scale)
    end
end)

connect(RunService.RenderStepped,function(dt)
    if UI.panelDragTarget and main.Visible then
        local a = config.animations and (1-math.exp(-23*dt)) or 1
        main.Position = main.Position:Lerp(UI.panelDragTarget,a)
    end
end)

-- Detectar el rol por las Tools que el jugador tiene actualmente.
-- Gun / Knife pueden estar equipadas (Character) o guardadas (Backpack).
-- Sin ninguna de las dos, el rol es Inocente (Player).
function UI.roleFromTools(p)
    local function scan(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local name = item.Name:lower()
                if name == "knife" then return "Murder" end
                if name == "gun" then return "Sheriff" end
            end
        end
        return nil
    end
    local equipped = scan(p.Character)
    if equipped then return equipped end
    return scan(p:FindFirstChildOfClass("Backpack"))
end
function UI.getRole(p)
    local role=UI.roleFromTools(p) or "Player"
    roleCache[p]=role -- El rol propio se actualiza inmediatamente.
    return role
end
-- Para la parte VISUAL únicamente: pequeñas interrupciones al equipar/desequipar
-- una Tool no deben hacer desaparecer el ESP en cada actualización.
function UI.getStableEspRole(p)
    local detected=UI.getRole(p)
    if p==me then return detected end
    local char=p.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not char or (hum and hum.Health<=0) then
        espRoleGrace[p]=nil
        return detected
    end
    local now=os.clock()
    local previous=espRoleGrace[p]
    if not previous or previous.character~=char then
        espRoleGrace[p]={character=char,role=detected,lastSeen=now}
        return detected
    end
    if detected~="Player" then
        previous.role=detected
        previous.lastSeen=now
        return detected
    end
    if previous.role~="Player" and now-previous.lastSeen<1.5 then
        return previous.role
    end
    previous.role="Player"
    return detected
end
-- Los mapas pueden usar una Part llamada Lobby o LobbyZone.
-- El filtro por volumen funciona también si el personaje NO es descendiente del modelo.
function UI.isInLobby(p)
    local char=p.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local lobby=workspace:FindFirstChild("LobbyZone",true) or workspace:FindFirstChild("Lobby",true)
    if not lobby then return false end
    if char:IsDescendantOf(lobby) then return true end
    local cf,size
    if lobby:IsA("BasePart") then
        cf,size=lobby.CFrame,lobby.Size
    elseif lobby:IsA("Model") then
        cf,size=lobby:GetBoundingBox()
    else
        return false
    end
    local point=cf:PointToObjectSpace(root.Position)
    local half=size*0.5
    return math.abs(point.X)<=half.X and math.abs(point.Z)<=half.Z
        and math.abs(point.Y)<=math.max(half.Y,12)
end
function UI.ensureVisual(p, role)
    local char = p.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
    if not char or not head or (human and human.Health <= 0) then UI.cleanVisual(p); return end
    local v = visuals[p]
    if v and (v.character ~= char or v.role ~= role or not v.highlight.Parent or not v.billboard.Parent) then
        UI.cleanVisual(p)
        v = nil
    end
    if not v then
        local color = role == "Murder" and C.red or (role == "Sheriff" and C.sheriff or C.mint)
        local hl = new("Highlight", gui, {
            Name = "RoleHighlight", Adornee = char, FillColor = color,
            OutlineColor = color, FillTransparency = 0.62,
            OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        })
        local bill = new("BillboardGui", gui, {
            Name = "RoleTag", Adornee = head, Enabled = true, AlwaysOnTop = true,
            Size = UDim2.fromOffset(180, 38), StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0),
            MaxDistance = 0, LightInfluence = 0, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        })
        local bg = new("Frame", bill, {Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(26,34,52), BackgroundTransparency = 0.05, BorderSizePixel = 0})
        round(bg, 7)
        line(bg, color, 0)
        local label = text(bg, "", 10, Color3.fromRGB(255,255,255), true, {
            Position=UDim2.fromOffset(7,3), Size=UDim2.new(1,-14,1,-6),
            TextXAlignment=Enum.TextXAlignment.Center, TextWrapped=true
        })
        v = {highlight=hl, billboard=bill, label=label, character=char, role=role, head=head}
        visuals[p] = v
    end
    local myRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local theirRoot = char:FindFirstChild("HumanoidRootPart")
    v.billboard.Adornee = head
    -- Distancia en metros aproximados (en Roblox, studs; conversión ajustable).
    local dist= (myRoot and theirRoot) and math.floor((myRoot.Position-theirRoot.Position).Magnitude*0.28+0.5) or nil
    v.label.Text = string.upper(role) .. (p == me and "  •  TÚ" or "")
        .. "\n@" .. p.Name .. (dist and ("  |  "..dist.." m") or "")
    v.highlight.Enabled = true
    v.billboard.Enabled = true
end
function UI.refreshEsp()
    for _, p in ipairs(Players:GetPlayers()) do
        local role = UI.getStableEspRole(p)
        local show = (role == "Murder" and state.murder) or (role == "Sheriff" and state.sheriff)
            or (role == "Player" and state.innocents and p ~= me)
        if show and not UI.isInLobby(p) then
            UI.ensureVisual(p, role)
        else
            UI.cleanVisual(p)
        end
    end
end
connect(Players.PlayerRemoving, function(p)
    UI.cleanVisual(p)
    roleCache[p] = nil
    espRoleGrace[p] = nil
end)

function UI.updateOwnRole()
    local role = UI.getRole(me)
    if role ~= currentOwnRole then
        currentOwnRole = role
        if role then
            UI.statusOwn.Text = role=="Player" and "INOCENTE" or string.upper(role)
            if role=="Murder" or role=="Sheriff" then
                notify("TU ERES EL " .. string.upper(role), "Rol detectado en la ronda actual.", role == "Murder" and C.red or C.sheriff)
            end
        else
            UI.statusOwn.Text = "INOCENTE"
        end
    end
end
-- Avisar al activar un ESP si no hay rol detectado, incluyendo al usuario local.
local espNoticeCooldown = {Murder = -math.huge, Sheriff = -math.huge}
function UI.notifyMissingRole(role)
    local found = false
    for _, p in ipairs(Players:GetPlayers()) do
        if UI.getRole(p) == role then found = true; break end
    end
    if not found and os.clock() - espNoticeCooldown[role] > 3 then
        espNoticeCooldown[role] = os.clock()
        notify("ESP " .. role, "Todavía no se pudo identificar un " .. role .. " visible. Puede tener el arma oculta.", C.orange)
    end
end
-- Comprobar cambios desde los botones de ESP directamente.
for _, entry in ipairs(UI.searchables) do
    if entry.title == "ESP Murder" or entry.title == "ESP Sheriff" then
        local target = entry.title == "ESP Murder" and "Murder" or "Sheriff"
        local button = entry.obj:FindFirstChildOfClass("TextButton")
        if button then
            connect(button.MouseButton1Click, function()
                task.delay(0.25, function()
                    if (target == "Murder" and state.murder) or (target == "Sheriff" and state.sheriff) then
                        UI.notifyMissingRole(target)
                    end
                end)
            end)
        end
    end
end
connect(me.CharacterAdded, function()
    currentOwnRole = nil
    roleCache[me] = nil
    visited = {}
    savedParts = nil
    retreatState = nil
end)

-- COIN COLLECTOR. La camara queda libre mientras el rig viaja anclado.
-- Al tocar la moneda se restaura la fisica para caer al piso antes de avanzar.
function UI.nearestMurderDistance(position)
    local best=math.huge
    for _, person in ipairs(Players:GetPlayers()) do
        if person ~= me and UI.getRole(person)=="Murder" then
            local mr=person.Character and person.Character:FindFirstChild("HumanoidRootPart")
            local hum=person.Character and person.Character:FindFirstChildOfClass("Humanoid")
            if mr and (not hum or hum.Health>0) then
                best=math.min(best,(mr.Position-position).Magnitude)
            end
        end
    end
    return best
end
function UI.coinTarget(root, allowUnsafe)
    local container=workspace:FindFirstChild("CoinContainer",true)
    if not container then return nil,nil,false end
    local safePart,safeDist=nil,math.huge
    local unsafePart,unsafeDist=nil,math.huge
    for _, obj in ipairs(container:GetChildren()) do
        if obj.Name=="Coin_Server" then
            local part=obj:FindFirstChild("CoinVisual")
            if part and part:IsA("BasePart") and not visited[part] then
                local dist=(root.Position-part.Position).Magnitude
                if dist<=config.maxCoinDistance then
                    if UI.nearestMurderDistance(part.Position)>=SAFE_COIN_RADIUS then
                        if dist<safeDist then safePart,safeDist=part,dist end
                    elseif dist<unsafeDist then
                        unsafePart,unsafeDist=part,dist
                    end
                end
            end
        end
    end
    if safePart then return safePart,safeDist,false end
    -- No elegir monedas a menos de SAFE_COIN_RADIUS del Murder, ni tras esperar.
    return nil,nil,(unsafePart~=nil)
end
-- Refugio del Coin Collector cuando un Murder se acerca.
-- Se conserva la posición de origen para regresar si el peligro desaparece.
function UI.teleportFarmRoot(root, destination)
    if not root or not root.Parent then return false end
    UI.restoreFarmCharacter() -- cancela el tween y restaura el personaje antes de moverlo
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = typeof(destination) == "CFrame" and destination or (CFrame.new(destination) * root.CFrame.Rotation)
    return true
end

-- Restaurar la posición exacta al apagar Coin Collector mientras se está refugiado.
returnFromRetreat = function()
    local info = retreatState
    if not info then return end
    retreatState = nil -- Previene una segunda restauración desde otro ciclo.
    local char = me.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if root and hum and hum.Health > 0 and info.character == char then
        UI.teleportFarmRoot(root, info.origin) -- CFrame original, incluyendo rotación.
        root.Anchored = false
        UI.coinStatusText.Text = "Coin Collector desactivado: posición restaurada"
    end
end

-- Elegir la moneda más alejada del Murder, no la más cercana al refugio.
function UI.farCoinFromMurder()
    local container = workspace:FindFirstChild("CoinContainer", true)
    if not container then return nil, 0, "no_container" end
    local bestCoin, bestSafety, bestTravel = nil, -1, math.huge
    local available, safeCount = 0, 0
    -- En algunos mapas las coins están dentro de subcarpetas; no asumir hijos directos.
    for _, coin in ipairs(container:GetDescendants()) do
        if coin.Name == "Coin_Server" then
            local visual = coin:FindFirstChild("CoinVisual", true)
            if visual and visual:IsA("BasePart") and visual.Parent then
                available += 1
                local safety = UI.nearestMurderDistance(visual.Position)
                if safety >= SAFE_COIN_RADIUS then
                    safeCount += 1
                    local travel = (visual.Position - RETREAT_POINT).Magnitude
                    -- La selección de escape no debe depender de maxCoinDistance
                    -- ni de visited: importa elegir la coin más alejada del Murder.
                    if safety > bestSafety or (safety == bestSafety and travel < bestTravel) then
                        bestCoin, bestSafety, bestTravel = visual, safety, travel
                    end
                end
            end
        end
    end
    if bestCoin then return bestCoin, safeCount, nil end
    if available == 0 then return nil, 0, "no_coins" end
    return nil, 0, "no_safe_coins"
end

-- Devuelve true mientras el sistema gestiona el escape: el loop normal no debe
-- iniciar otro tween, una recogida de gun ni seleccionar monedas simultáneamente.
function UI.dodgeNearbyMurder()
    if not state.farm or state.closing or state.busy then return false end
    local char = me.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        retreatState = nil
        return false
    end

    if retreatState then
        -- Si la ronda se quedó sin monedas mientras estábamos refugiados,
        -- regresar al punto anterior y dejar que el personaje baje al suelo.
        local folder = workspace:FindFirstChild("CoinContainer", true)
        local coinsRemain = false
        if folder then
            for _, item in ipairs(folder:GetDescendants()) do
                if item.Name == "Coin_Server" and item:FindFirstChild("CoinVisual", true) then
                    coinsRemain = true
                    break
                end
            end
        end
        if not coinsRemain then
            returnFromRetreat()
            escapeUntil = os.clock() + 1.5
            UI.coinStatusText.Text = "Sin coins: regresando al suelo"
            return true
        end
        -- Refugio en lobby, con gravedad y física normales; no forzar altura ni anclaje.
        if root.Anchored then root.Anchored = false end
        local threatAtOrigin = UI.nearestMurderDistance(retreatState.origin.Position)
        -- Si el asesino ya se alejó del punto de farmeo, volver y seguir recolectando.
        if threatAtOrigin >= RETURN_RADIUS then
            UI.teleportFarmRoot(root, retreatState.origin)
            root.Anchored = false
            retreatState = nil
            nearbyDangerActive = false
            escapeUntil = os.clock() + 0.6
            UI.coinStatusText.Text = "Murder lejos: retomando coins"
            return true
        end
        -- Si sigue cerca 3 segundos, saltar a una moneda lejos de él.
        if os.clock() - retreatState.started >= RETREAT_TIMEOUT then
            local safeCoin, _, reason = UI.farCoinFromMurder()
            if not safeCoin then
                -- Avisar el motivo en lugar de quedarse esperando sin explicación.
                UI.coinStatusText.Text = reason == "no_container" and "Sin CoinContainer: no se puede buscar coins"
                    or reason == "no_coins" and "No hay coins disponibles en esta ronda"
                    or "Sin coins seguras cerca"
                if reason == "no_coins" or reason == "no_container" then
                    returnFromRetreat()
                    escapeUntil = os.clock() + 1.5
                    return true
                end
                -- Evitar cualquier anclaje/tween o velocidad ascendente
                -- mientras la búsqueda no encuentra una moneda.
                if runningTween or savedParts then UI.restoreFarmCharacter() end
                root.Anchored = false
                hum.PlatformStand = false
                local velocity = root.AssemblyLinearVelocity
                if velocity.Y > 0 then
                    root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
                end
                return true
            end
            -- Comprobar de nuevo la seguridad, porque el Murder puede moverse.
            if UI.nearestMurderDistance(safeCoin.Position) < SAFE_COIN_RADIUS then return true end
            UI.teleportFarmRoot(root, safeCoin.Position)
            root.Anchored = false
            visited[safeCoin] = true
            retreatState = nil
            nearbyDangerActive = false
            escapeUntil = os.clock() + 0.7
            UI.coinStatusText.Text = "Coin alejada: retomando farmeo"
            return true
        end
        UI.coinStatusText.Text = "Refugio: esperando que se aleje el Murder (" .. math.max(0, math.ceil(RETREAT_TIMEOUT - (os.clock() - retreatState.started))) .. " s)"
        return true
    end

    if os.clock() < escapeUntil or UI.nearestMurderDistance(root.Position) >= DANGER_RADIUS then
        nearbyDangerActive = false
        return false
    end

    -- No escapar desde el lobby cuando no hay monedas de una ronda activa.
    local coinFolder = workspace:FindFirstChild("CoinContainer", true)
    local roundCoins = false
    if coinFolder then
        for _, coin in ipairs(coinFolder:GetDescendants()) do
            if coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual", true) then
                roundCoins = true
                break
            end
        end
    end
    if not roundCoins then return false end

    retreatState = {origin = root.CFrame, started = os.clock(), character = char}
    nearbyDangerActive = true
    UI.teleportFarmRoot(root, RETREAT_POINT)
    -- En el lobby la física funciona normalmente y no requiere anclar al personaje.
    root.Anchored = false
    UI.coinStatusText.Text = "Murder cerca: refugiándose"
    if os.clock() > murderAlertCooldown then
        murderAlertCooldown = os.clock() + 4
        notify("Murder cerca", "Refugio activado; regresando al alejarse o buscando coin en 3 segundos", C.orange)
    end
    return true
end
-- Si no hay caramelos, hacer una sola maniobra evasiva por intervalo.
-- Nunca anclar al personaje en espera: la fisica y los controles se mantienen normales.
function UI.idleEvasion()
    -- Sin coins: cancelar cualquier movimiento anterior y devolver el control
    -- físico normal. Nunca trasladar al jugador hacia arriba ni crear impulso.
    if runningTween or savedParts then UI.restoreFarmCharacter() end
    local char = me.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum and hum.Health > 0) then return end
    root.Anchored = false
    hum.PlatformStand = false
    hum.AutoRotate = true
    -- Eliminar solo el impulso ASCENDENTE residual, sin modificar X/Z ni
    -- la velocidad de caída. Esto evita el salto vertical al agotarse coins.
    local vel = root.AssemblyLinearVelocity
    if vel.Y > 0 then
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end
    if hum.FloorMaterial == Enum.Material.Air then
        -- Cuando una antigua animación/tween nos dejó suspendidos, buscar
        -- piso REAL bajo los pies y situarnos cerca de él. Nunca elevar Y.
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignored = {char}
        local coins = workspace:FindFirstChild("CoinContainer", true)
        if coins then table.insert(ignored, coins) end
        params.FilterDescendantsInstances = ignored
        params.IgnoreWater = true
        local floorHit = workspace:Raycast(root.Position, Vector3.new(0, -10000, 0), params)
        if floorHit and floorHit.Normal.Y > 0.5 then
            local landingY = floorHit.Position.Y + math.max(3, hum.HipHeight + 2)
            if root.Position.Y > landingY + 12 then
                root.CFrame = CFrame.new(root.Position.X, landingY, root.Position.Z) * root.CFrame.Rotation
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end

function UI.startCoinJumpAnimation(hum)
    local char=hum.Parent
    local animate=char and char:FindFirstChild("Animate")
    local jump=animate and animate:FindFirstChild("jump")
    local jumpAnim=jump and jump:FindFirstChildWhichIsA("Animation")
    local animator=hum:FindFirstChildOfClass("Animator")
    if not animator or not jumpAnim then return nil end
    local ok,track=pcall(function() return animator:LoadAnimation(jumpAnim) end)
    if ok and track then
        track.Priority=Enum.AnimationPriority.Action
        track.Looped=true
        track:Play(0.12,1,1)
        return track
    end
    return nil
end
function UI.moveToCoin(part, distance)
    local snap = UI.snapshotCharacter()
    if not snap or not part or not part.Parent or state.busy then return end
    snap.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    local jumpTrack=UI.startCoinJumpAnimation(snap.humanoid)
    UI.beginMove(snap)
    -- El centro del HumanoidRootPart debe coincidir con CoinVisual,
    -- no quedar 1.3 studs por encima de la moneda.
    local destination = CFrame.new(part.Position) * snap.hrp.CFrame.Rotation
    local duration = math.max(distance / config.coinSpeed, 0.04)
    runningTween = tween(snap.hrp, duration, {CFrame = destination}, Enum.EasingStyle.Linear)
    local started = os.clock()
    while state.farm and not state.busy and #Players:GetPlayers() > 3 and not state.closing and snap.hrp.Parent and part.Parent
        and runningTween and runningTween.PlaybackState == Enum.PlaybackState.Playing do
        if os.clock() - started > duration + 2 then break end
        if UI.nearestMurderDistance(part.Position) < SAFE_COIN_RADIUS then
            if runningTween then runningTween:Cancel() end
            visited[part] = nil
            break
        end
        if UI.dodgeNearbyMurder() then break end
        task.wait(0.04)
    end
    -- Solo completar la aproximacion si el tween llego a la moneda.
    -- Mantenemos el HRP centrado unos instantes para dar tiempo al contacto.
    if state.farm and not state.busy and part.Parent and snap.hrp.Parent
        and runningTween and runningTween.PlaybackState == Enum.PlaybackState.Completed then
        snap.hrp.CFrame = CFrame.new(part.Position) * snap.hrp.CFrame.Rotation
        task.wait(0.12)
    end
    UI.restoreFarmCharacter()
    if jumpTrack then pcall(function() jumpTrack:Stop(0.12); jumpTrack:Destroy() end) end
    if retreatState then
        -- Si se activó el escape durante un tween, no teletransportar otra vez
        -- ni anclar: el controlador del refugio ya gestiona el regreso.
        if snap.hrp.Parent and retreatState.character == snap.hrp.Parent then
            snap.hrp.Anchored = false
        end
        return
    end
    -- Dejar que la gravedad y el Humanoid tomen el control antes de continuar.
    -- Al aterrizar, esperar el descanso completo de 0.5 s.
    local hum = snap.humanoid
    local root = snap.hrp
    if state.farm and hum.Parent and root.Parent and hum.Health > 0 then
        hum.PlatformStand = false
        root.Anchored = false
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
        local deadline = os.clock()+4
        while state.farm and not state.busy and not state.closing and hum.Parent and root.Parent and hum.Health>0 and os.clock()<deadline do
            if hum.FloorMaterial ~= Enum.Material.Air then break end
            task.wait(0.06)
        end
        if state.farm and not state.busy then
            hum:ChangeState(Enum.HumanoidStateType.Running)
            task.wait(0.5)
        end
    end
end

-- Herramienta normal del personaje; el servidor decide si un golpe es válido.
function UI.equippedKnife()
    local char = me.Character
    if not char then return nil end
    local knife = char:FindFirstChild("Knife")
    if knife and knife:IsA("Tool") then return knife end
    local backpack = me:FindFirstChildOfClass("Backpack")
    knife = backpack and backpack:FindFirstChild("Knife")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if knife and knife:IsA("Tool") and hum then
        hum:EquipTool(knife)
        task.wait(0.1)
        if knife.Parent == char then return knife end
    end
    return nil
end
function UI.validMurder()
    if UI.getRole(me) ~= "Murder" then
        notify("Acción no disponible", "No tienes los requisitos adecuados", C.orange)
        return false
    end
    return true
end
function UI.getTargetRoot(p)
    local char = p and p.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and hum and hum.Health > 0 then return root, hum end
    return nil, nil
end
function UI.attackTarget(p, maxDuration)
    local knife = UI.equippedKnife()
    if not knife then
        notify("Sin herramienta", "No tienes los requisitos adecuados", C.orange)
        return false
    end
    local ownRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    if not ownRoot then return false end
    local started = os.clock()
    while os.clock() - started < maxDuration and not state.closing do
        -- El objetivo puede cambiar de rol durante la ronda: no seguir a otro Murder.
        if UI.getRole(p) == "Murder" or UI.getRole(me) ~= "Murder" then return false end
        local root, hum = UI.getTargetRoot(p)
        if not root or hum.Health <= 0 then return true end
        if knife.Parent ~= me.Character then return false end
        -- Detrás de la orientación del objetivo, sin modificar colisiones.
        ownRoot.CFrame = root.CFrame * CFrame.new(0, 0, 0.8) -- V26: acercamiento trasero más pegado
        ownRoot.AssemblyLinearVelocity = Vector3.zero
        knife:Activate()
        task.wait(0.045)
    end
    return false
end
-- Desplazamientos y ataques tienen prioridad sobre Coin Collector.
-- El farm permanece encendido pero no selecciona nuevos caramelos hasta terminar.
function UI.suspendFarm()
    if runningTween then runningTween:Cancel(); runningTween=nil end
    UI.restoreFarmCharacter()
end
function UI.runCombat(mode, chosenTarget)
    if combatBusy or state.busy then
        notify("Ocupado", "Hay otra acción en curso", C.orange)
        return
    end
    if not UI.validMurder() then return end
    if not UI.equippedKnife() then
        notify("Sin herramienta", "No tienes los requisitos adecuados", C.orange)
        return
    end
    state.busy = true
    combatBusy = true
    UI.suspendFarm()
    local originalRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local originalCFrame = originalRoot and originalRoot.CFrame
    local targets = {}
    if mode == "Target" then
        if chosenTarget and chosenTarget ~= me and not state.blacklist[chosenTarget.UserId] and UI.getRole(chosenTarget) ~= "Murder" then
            targets[1]=chosenTarget
        else
            notify("Kill Target","Objetivo no disponible o excluido",C.orange)
        end
    elseif mode == "Sheriff" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me and not state.blacklist[p.UserId] and UI.getRole(p) == "Sheriff" then targets[#targets + 1] = p end
        end
        if #targets == 0 then notify("Kill Sheriff", "No se detectó un Sheriff", C.orange) end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me and not state.blacklist[p.UserId] and UI.getRole(p) ~= "Murder" then
                local r = UI.getTargetRoot(p)
                if r and originalRoot and (r.Position - originalRoot.Position).Magnitude <= config.maxKillDistance then
                    targets[#targets + 1] = p
                end
            end
        end
        table.sort(targets,function(a,b)
            local ra,rb=UI.getRole(a),UI.getRole(b)
            if ra=="Sheriff" and rb~="Sheriff" then return true end
            if rb=="Sheriff" and ra~="Sheriff" then return false end
            return a.UserId<b.UserId
        end)
        if #targets == 0 then notify("Kill All", "No hay objetivos dentro del alcance", C.orange) end
    end
    for _, p in ipairs(targets) do
        if state.closing or not UI.validMurder() then break end
        local root = UI.getTargetRoot(p)
        if root and originalRoot and not state.blacklist[p.UserId] and UI.getRole(p) ~= "Murder"
            and (mode == "Target" or (root.Position - originalRoot.Position).Magnitude <= config.maxKillDistance) then
            -- Sigue al objetivo mientras esté vivo hasta un límite de seguridad.
            if UI.getRole(p) ~= "Murder" then
                UI.attackTarget(p, mode == "Sheriff" and 20 or mode == "Target" and 15 or 8)
            end
        end
    end
    if originalRoot and originalRoot.Parent and originalCFrame then
        originalRoot.CFrame = originalCFrame
        originalRoot.AssemblyLinearVelocity = Vector3.zero
        originalRoot.AssemblyAngularVelocity = Vector3.zero
    end
    combatBusy = false
    state.busy = false
    if #targets > 0 then notify("Acción finalizada", "Se completó el recorrido de objetivos", C.mint) end
end

-- FLING sobre el jugador seleccionado. Restaurar siempre la física y posición.
-- Advertencia: la simulación física puede ser filtrada por la propiedad de red/servidor.
local flingBusy = false

-- Se detienen solo las animaciones del personaje local durante el Fling.
-- El script Animate vuelve a su estado anterior al finalizar.
function UI.pauseFlingAnimations(character, humanoid)
    local animate = character:FindFirstChild("Animate")
    local oldDisabled = nil
    if animate and animate:IsA("LocalScript") then
        oldDisabled = animate.Disabled -- preservar false; `cond and false or nil` lo pierde
    end
    if animate and animate:IsA("LocalScript") then
        animate.Disabled = true
    end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0) end)
        end
    end
    return animate, oldDisabled
end

function UI.restoreFlingAnimations(character, humanoid, animate, oldDisabled)
    if not (character and character.Parent and humanoid and humanoid.Parent and humanoid.Health > 0) then
        return
    end
    -- El Animator conserva pistas detenidas incluso si Animate.Disabled se
    -- vuelve a establecer en false. Reiniciar Animate fuerza a reconstruir
    -- idle/walk/run/jump en lugar de esperar una transición que quizá no ocurra.
    if animate and animate.Parent == character and animate:IsA("LocalScript")
        and oldDisabled == false then
        pcall(function()
            animate.Disabled = true
            task.wait() -- un frame para liberar la ejecución anterior
            if animate.Parent ~= character or me.Character ~= character then return end
            animate.Disabled = false
        end)
    elseif animate and animate.Parent == character and oldDisabled ~= nil then
        pcall(function() animate.Disabled = oldDisabled end)
    end
    if me.Character ~= character then return end
    pcall(function()
        if humanoid.Sit then
            humanoid:ChangeState(Enum.HumanoidStateType.Seated)
        elseif humanoid.FloorMaterial == Enum.Material.Air then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        else
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
    -- Segundo chequeo ligero: si quedó deshabilitado tras una transición,
    -- aseguramos que Animate vuelva a arrancar en este mismo personaje.
    if oldDisabled == false then
        task.delay(0.2, function()
            if me.Character == character and animate and animate.Parent == character
                and animate:IsA("LocalScript") and animate.Disabled and humanoid.Health > 0 then
                animate.Disabled = false
            end
        end)
    end
end

function UI.executeFlingSingle(targetPlayer)
    if flingBusy or state.busy then return false end
    if not targetPlayer or targetPlayer == me or state.blacklist[targetPlayer.UserId] then return false end
    local char = me.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) or hum.Health <= 0 then return false end
    if not UI.getTargetRoot(targetPlayer) then return false end

    flingBusy = true
    state.busy = true
    UI.suspendFarm()
    local originalCFrame = root.CFrame
    local originalAnchored = root.Anchored
    local originalAutoRotate = hum.AutoRotate
    local originalPlatformStand = hum.PlatformStand
    local oldHeight = workspace.FallenPartsDestroyHeight
    local animate, animateWasDisabled
    local spin
    local mobileMode = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local movedOnMobile = false
    local ok, err = pcall(function()
        pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
        root.Anchored = false
        hum.AutoRotate = false
        animate, animateWasDisabled = UI.pauseFlingAnimations(char, hum)
        spin = Instance.new("BodyAngularVelocity")
        spin.Name = "XoniHubSpin"
        spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        spin.P = math.huge
        spin.AngularVelocity = Vector3.new(0, 9e20, 0)
        spin.Parent = root
        local started = os.clock()
        while os.clock() - started < 2 and not state.closing do
            local targetRoot = UI.getTargetRoot(targetPlayer)
            if not targetRoot or not root.Parent or state.blacklist[targetPlayer.UserId] then break end
            -- Movimiento original V23: HRP centrado y misma orientacion,
            -- sin los giros ni inclinaciones extra de la V24.
            if mobileMode then
                -- En tactil el Character puede volver a su posicion anterior
                -- si se actualiza solo el CFrame del HRP.
                char:PivotTo(targetRoot.CFrame)
                -- Evitar magnitudes no representables durante la correccion del rig.
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            else
                root.CFrame = targetRoot.CFrame
                root.AssemblyLinearVelocity = Vector3.new(9e9, 9e9, 9e9)
                root.AssemblyAngularVelocity = Vector3.new(9e20, 9e20, 9e20)
            end
            RunService.Heartbeat:Wait()
            if mobileMode and root.Parent and (root.Position-targetRoot.Position).Magnitude<=12 then
                movedOnMobile=true
            end
        end
    end)
    -- Limpieza siempre, incluso si ocurre un error durante el movimiento.
    if spin and spin.Parent then spin:Destroy() end
    for _ = 1, 8 do
        if root.Parent then
            root.CFrame = originalCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        RunService.Heartbeat:Wait()
    end
    if root.Parent then root.Anchored = originalAnchored end
    if hum.Parent then
        hum.PlatformStand = originalPlatformStand
        hum.AutoRotate = originalAutoRotate
    end
    pcall(function() workspace.FallenPartsDestroyHeight = oldHeight end)
    UI.restoreFlingAnimations(char, hum, animate, animateWasDisabled)
    state.busy = false
    flingBusy = false
    if not ok then warn("XONI HUB FLING: " .. tostring(err)) end
    if mobileMode and ok and not movedOnMobile then
        notify("Fling", "El movimiento fue bloqueado o revertido. Puede requerir control del servidor.", C.orange)
        return false
    end
    return ok
end

-- Anti-AFK opt-in: simulación interna de entrada Roblox cuando el entorno lo permite.
-- Nunca puede pulsar físicamente en la pantalla real del dispositivo.
task.spawn(function()
    while gui.Parent and not state.closing do
        task.wait(15)
        if state.antiAfk and not state.closing then
            local ok = pcall(function()
                local vu=game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(0,0))
            end)
            if not ok and not UI.antiAfkNotice then
                UI.antiAfkNotice=true
                notify("Anti-AFK","Este entorno no permite entradas virtuales; no se puede garantizar Anti-AFK.",C.orange)
            end
        end
    end
end)

-- Auto Kill All: solo cuando el rol propio es Murder; Kill All ya ordena al Sheriff primero.
-- Un cooldown evita intentos consecutivos en el mismo frame y deja que Coin Collector se reanude.
task.spawn(function()
    while gui.Parent and not state.closing do
        task.wait(3)
        if state.autoKillAll and not combatBusy and not state.busy and UI.getRole(me)=="Murder" then
            local found=false
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=me and not state.blacklist[p.UserId] and UI.getRole(p)~="Murder" and UI.getTargetRoot(p) then
                    found=true
                    break
                end
            end
            if found then UI.runCombat("All") end
        end
    end
end)

-- Las activaciones utilizan Tool:Activate; el servidor decide los efectos.
function UI.bindActionButton(button, callback)
    -- Asignar las acciones a los botones.
    connect(button.MouseButton1Click, function() task.spawn(callback) end)
end
UI.bindActionButton(killSheriffButton, function() UI.runCombat("Sheriff") end)
UI.bindActionButton(killAllButton, function() UI.runCombat("All") end)
connect(UI.targetExecute.MouseButton1Click,function()
    if not state.targetUserId then
        notify("Kill Target","Seleccioná primero un jugador",C.orange)
        return
    end
    local chosen=Players:GetPlayerByUserId(state.targetUserId)
    if not chosen then
        notify("Kill Target","El jugador ya no está disponible",C.orange)
        return
    end
    task.spawn(function() UI.runCombat("Target",chosen) end)
end)
connect(UI.blacklistToggle.MouseButton1Click,function()
    if not state.targetUserId then
        notify("Blacklist","Seleccioná primero un jugador",C.orange)
        return
    end
    local target=Players:GetPlayerByUserId(state.targetUserId)
    if not target then
        notify("Blacklist","El jugador ya no está disponible",C.orange)
        return
    end
    state.blacklist[target.UserId]=not state.blacklist[target.UserId]
    notify("Blacklist",(state.blacklist[target.UserId] and "Agregado: " or "Quitado: ")..target.Name,state.blacklist[target.UserId] and C.red or C.mint)
    UI.playerSelected.Text="Seleccionado: "..target.DisplayName.."  @"..target.Name..(state.blacklist[target.UserId] and "  •  EN BLACKLIST" or "")
    refreshPlayerList()
end)
-- Activated funciona tanto al tocar en celular como al hacer clic con mouse.
-- Un unico evento evita que una pulsacion tactil ejecute dos veces la accion.
connect(UI.flingButton.Activated,function()
    playSound(clickSound)
    if not state.targetUserId then
        notify("Fling","Seleccioná primero un jugador en Target",C.orange)
        return
    end
    local target = Players:GetPlayerByUserId(state.targetUserId)
    if not target or target == me or state.blacklist[target.UserId] then
        notify("Fling","Jugador no disponible o en blacklist",C.orange)
        return
    end
    if flingBusy or state.busy then
        notify("Fling","Ya hay otra accion en curso",C.orange)
        return
    end
    task.spawn(function()
        local ok = UI.executeFlingSingle(target)
        notify("Fling",ok and "Acción finalizada (resultado sujeto al servidor)" or "No se pudo ejecutar",ok and C.mint or C.orange)
    end)
end)
connect(UI.gotoButton.MouseButton1Click,function()
    if not state.targetUserId then
        notify("Goto","Seleccioná primero un jugador",C.orange)
        return
    end
    local target=Players:GetPlayerByUserId(state.targetUserId)
    local myRoot=me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot=target and UI.getTargetRoot(target)
    if not targetRoot or not myRoot then
        notify("Goto","El jugador no está disponible",C.orange)
        return
    end
    UI.suspendFarm()
    myRoot.CFrame=targetRoot.CFrame * CFrame.new(0,0,3)
    myRoot.AssemblyLinearVelocity=Vector3.zero
    myRoot.AssemblyAngularVelocity=Vector3.zero
    notify("Goto","Teletransportado a "..target.Name,C.mint)
end)

-- Spectate mantiene controles de cámara normales; vuelve al personaje local al salir.
function UI.stopSpectate()
    state.spectatingUserId=nil
    local camera=workspace.CurrentCamera
    local myHum=me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if camera then
        camera.CameraType=Enum.CameraType.Custom
        if myHum then camera.CameraSubject=myHum end
    end
    if UI.updateTargetButtons then UI.updateTargetButtons() end
end
connect(UI.spectateButton.MouseButton1Click,function()
    local target=state.targetUserId and Players:GetPlayerByUserId(state.targetUserId)
    if not target then notify("Spectate","Seleccioná un jugador",C.orange);return end
    if state.spectatingUserId==target.UserId then UI.stopSpectate();return end
    local humanoid=target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then notify("Spectate","El jugador no tiene personaje disponible",C.orange);return end
    local camera=workspace.CurrentCamera
    if not camera then return end
    state.spectatingUserId=target.UserId
    -- Si el objetivo reaparece, mantener la vista en su nuevo Humanoid.
    connect(target.CharacterAdded,function(character)
        if state.spectatingUserId~=target.UserId then return end
        local nextHum=character:WaitForChild("Humanoid",5)
        local activeCamera=workspace.CurrentCamera
        if nextHum and activeCamera and state.spectatingUserId==target.UserId then
            activeCamera.CameraType=Enum.CameraType.Custom
            activeCamera.CameraSubject=nextHum
        end
    end)
    camera.CameraType=Enum.CameraType.Custom
    camera.CameraSubject=humanoid
    UI.updateTargetButtons()
    notify("Spectate","Mirando a @"..target.Name..". Podés mover la cámara normalmente.",C.mint)
end)
connect(Players.PlayerRemoving,function(p)
    if state.spectatingUserId==p.UserId then UI.stopSpectate() end
end)
connect(me.CharacterAdded,function()
    if state.spectatingUserId then UI.stopSpectate() end
end)

-- GunDrop es la BasePart que contiene Fire / Mesh / TouchInterest.
-- El Mesh suele ser SpecialMesh: no tiene Position ni se puede tocar por si solo.
-- Los mapas (BioLab, MilBase, Manor...) cambian: buscar en todo Workspace.
local gunSearchCache = {part=nil, nextScan=0}
function UI.gunPart()
    local now = os.clock()
    if now < gunSearchCache.nextScan then
        local candidate = gunSearchCache.part
        if candidate and candidate:IsDescendantOf(workspace) then return candidate end
        if candidate == nil then return nil end
    end
    gunSearchCache.nextScan = now + 0.65
    local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local best, bestDistance = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        local key = obj.Name:lower():gsub("[%s_%-]", "")
        if key == "gundrop" then
            local part = nil
            if obj:IsA("BasePart") then
                part = obj
            elseif obj:IsA("Model") then
                -- Preferir la pieza fisica que contiene el mesh visual.
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") and (child:FindFirstChild("Mesh") or child:FindFirstChildWhichIsA("SpecialMesh")) then
                        part = child
                        break
                    end
                end
                part = part or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            end
            if part and part:IsDescendantOf(workspace) and not (me.Character and part:IsDescendantOf(me.Character)) then
                local distance = root and (root.Position - part.Position).Magnitude or 0
                if distance < bestDistance then
                    best, bestDistance = part, distance
                end
            end
        end
    end
    gunSearchCache.part = best
    return best
end

-- ESP Gun: Highlight + etiqueta independiente, sin interferir con los ESP de roles.
UI.gunHighlight = nil
UI.gunBillboard = nil
UI.gunDistanceLabel = nil
UI.gunTrackedPart = nil
function UI.clearGunEsp()
    if UI.gunHighlight then UI.gunHighlight:Destroy(); UI.gunHighlight=nil end
    if UI.gunBillboard then UI.gunBillboard:Destroy(); UI.gunBillboard=nil end
    UI.gunDistanceLabel=nil
    UI.gunTrackedPart=nil
end
function UI.updateGunEsp()
    if not state.gunEsp or state.closing then UI.clearGunEsp(); return end
    local target = UI.gunPart()
    if not target then UI.clearGunEsp(); return end
    if UI.gunTrackedPart ~= target or not UI.gunHighlight or not UI.gunHighlight.Parent or not UI.gunBillboard or not UI.gunBillboard.Parent then
        UI.clearGunEsp()
        UI.gunTrackedPart=target
        UI.gunHighlight=new("Highlight",gui,{Name="GunDropHighlight",Adornee=target,FillColor=C.red,OutlineColor=Color3.fromRGB(255,242,242),FillTransparency=0.4,OutlineTransparency=0,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop})
        UI.gunBillboard=new("BillboardGui",gui,{Name="GunDropTag",Adornee=target,AlwaysOnTop=true,Enabled=true,Size=UDim2.fromOffset(155,40),StudsOffsetWorldSpace=Vector3.new(0,2,0),MaxDistance=0})
        local tag=new("Frame",UI.gunBillboard,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(18,18,22),BackgroundTransparency=0.08,BorderSizePixel=0})
        round(tag,5)
        local outline=line(tag,C.red,0); outline.Thickness=1.5
        UI.gunDistanceLabel=text(tag,"GUN DROP",11,C.white,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true})
    end
    local root=me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local distance=root and math.floor((root.Position-target.Position).Magnitude+0.5) or nil
    if UI.gunDistanceLabel then UI.gunDistanceLabel.Text="GUN DROP" end
end

function UI.collectGun(gun)
    if not gun or not gun.Parent or state.busy or UI.getRole(me) == "Murder" then return end
    state.busy=true
    UI.suspendFarm()
    local snap = UI.snapshotCharacter()
    if not snap then state.busy=false; return end
    local root, hum = snap.hrp, snap.humanoid
    local original = root.CFrame
    local success, err = pcall(function()
        -- Suspender cualquier desplazamiento, fly o estados especiales mientras se recoge.
        if runningTween then runningTween:Cancel(); runningTween = nil end
        root.Anchored = false
        hum.PlatformStand = false
        hum.AutoRotate = true
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        -- Las colisiones normales evitan que quede el rig atravesando el piso al volver.
        for part, collidable in pairs(snap.parts) do
            if part.Parent then
                local originalCollide = collidable
                -- Si hay noclip, recuperar los valores anteriores al activar noclip.
                if noclipOriginal and noclipOriginal[part] ~= nil then
                    originalCollide = noclipOriginal[part]
                end
                part.CanCollide = originalCollide
            end
        end
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        -- SpecialMesh.Offset desplaza el centro visual respecto al centro fisico.
        -- Si el mesh no tiene Offset, usar el centro de GunDrop.
        local targetPosition = gun.Position
        local mesh = gun:FindFirstChild("Mesh") or gun:FindFirstChildWhichIsA("SpecialMesh")
        if mesh and mesh:IsA("SpecialMesh") then
            targetPosition = gun.CFrame:PointToWorldSpace(mesh.Offset)
        end
        root.CFrame = CFrame.new(targetPosition) * original.Rotation
        RunService.Heartbeat:Wait()
        task.wait(0.12)
    end)

    -- Restaurar siempre, incluso si GunDrop desaparecio mientras se recogia.
    if root.Parent and hum.Parent then
        root.Anchored = false
        root.CFrame = original
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        for part, collidable in pairs(snap.parts) do
            if part.Parent then part.CanCollide = collidable end
        end
        hum.PlatformStand = snap.platform
        hum.AutoRotate = snap.autoRotate
        root.Anchored = snap.anchored
    end
    state.busy = false
    if success then
        notify("AutoCatchGun", "Se intento recoger la GunDrop", C.mint)
    else
        warn("AutoCatchGun: " .. tostring(err))
        notify("AutoCatchGun", "No se pudo completar el intento", C.orange)
    end
end

task.spawn(function()
    while not state.closing and gui.Parent do
        if state.autoGun then
            if UI.getRole(me) == "Murder" then
                if gunLastSeen ~= "murder" then
                    notify("AutoCatchGun", "Murder no puede recoger GunDrop", C.orange)
                    gunLastSeen = "murder"
                end
            else
                local gun = UI.gunPart()
                if gun then
                    if gun ~= gunLastSeen and os.clock() >= gunCooldownUntil and not state.busy then
                        gunLastSeen = gun
                        gunCooldownUntil = os.clock() + 2
                        UI.collectGun(gun)
                    end
                else
                    if gunLastSeen ~= "missing" then
                        notify("AutoCatchGun", "La gun no fue dropeada", C.orange)
                    end
                    gunLastSeen = "missing"
                end
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while not state.closing and gui.Parent do
        if state.farm and state.busy then
            UI.coinStatusText.Text="Pausado: acción prioritaria"
            task.wait(0.12)
        elseif state.farm and #Players:GetPlayers() <= 3 then
            state.farm = false
            setFarm(false, true)
            setFarmInputLocked(false)
            UI.restoreFarmCharacter()
            notify("Coin Collector", "No tienes requisitos necesarios", C.orange)
        end
        if state.farm and not state.busy then
            local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
            if root then
                if UI.dodgeNearbyMurder() then
                    task.wait(0.12)
                else
                    local target,dist,hasUnsafe=UI.coinTarget(root,false)
                    if not target then
                        visited={}
                        target,dist,hasUnsafe=UI.coinTarget(root,false)
                    end
                    if target then
                        unsafeSince=nil
                    elseif hasUnsafe then
                        -- Esperar una moneda segura; NUNCA entrar al radio de riesgo.
                        unsafeSince=unsafeSince or os.clock()
                    else
                        unsafeSince=nil
                    end
                    if target then
                        visited[target]=true
                        UI.coinStatusText.Text="Agarrando coins"
                        state.coinMoving=true
                        UI.moveToCoin(target,dist)
                        state.coinMoving=false
                    elseif hasUnsafe then
                        UI.coinStatusText.Text="Evitando coins cerca del Murder • buscando moneda segura"
                        UI.idleEvasion()
                        task.wait(0.2)
                    else
                        UI.coinStatusText.Text="Agarrando coins • esperando nuevas monedas"
                        UI.idleEvasion()
                        task.wait(0.35)
                    end
                end
            else
                UI.coinStatusText.Text = "Esperando personaje..."
                task.wait(0.35)
            end
        else
            if not state.busy then UI.restoreFarmCharacter() end
            if not state.farm then UI.coinStatusText.Text="Coin Collector desactivado" end
            task.wait(0.25)
        end
    end
    UI.restoreFarmCharacter()
end)

-- Si un Murder toca nuestro personaje durante Coin Collector, solicitar Kill All.
-- La acción solamente es válida si el usuario tiene Knife y rol Murder;
-- de lo contrario, sigue operando la evasión normal de Coin Collector.
local lastMurderTouch=0
local touchConnections={}
function UI.watchCharacterMurderTouch(character)
    for _,conn in ipairs(touchConnections) do conn:Disconnect() end
    table.clear(touchConnections)
    local function touched(otherPart)
        if not state.farm or state.busy or os.clock()-lastMurderTouch<4 then return end
        local otherCharacter=otherPart and otherPart:FindFirstAncestorOfClass("Model")
        local otherPlayer=otherCharacter and Players:GetPlayerFromCharacter(otherCharacter)
        if otherPlayer and otherPlayer~=me and UI.getRole(otherPlayer)=="Murder" then
            lastMurderTouch=os.clock()
            -- Intentar Kill All al contacto. runCombat verifica la Knife y
            -- el rol local; si no cumple, el Coin Collector sigue evadiendo.
            if UI.getRole(me)=="Murder" then
                task.spawn(function() UI.runCombat("All") end)
            else
                UI.coinStatusText.Text="Murder cerca: evasión activada"
            end
        end
    end
    local root=character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart",5)
    if root then table.insert(touchConnections,root.Touched:Connect(touched)) end
end
if me.Character then task.defer(UI.watchCharacterMurderTouch,me.Character) end
connect(me.CharacterAdded,UI.watchCharacterMurderTouch)

-- AIM en RenderStep después del controlador de cámara. No mueve el cursor.
-- Solo sigue objetivos si el jugador local tiene rol detectado.
local aimCurrentTarget=nil
function UI.aimRole()
    local mine=UI.getRole(me)
    if mine=="Murder" then return "Sheriff" end
    if mine=="Sheriff" then return "Murder" end
    return nil
end
function UI.aimVisible(camera, point, target)
    if not config.aimWallcheck then return true end
    local castParams=RaycastParams.new()
    castParams.FilterType=Enum.RaycastFilterType.Exclude
    local exclusions={}
    if me.Character then table.insert(exclusions,me.Character) end
    castParams.FilterDescendantsInstances=exclusions
    castParams.IgnoreWater=true
    local delta=point-camera.CFrame.Position
    local result=workspace:Raycast(camera.CFrame.Position,delta,castParams)
    return not result or (target.Character and result.Instance:IsDescendantOf(target.Character))
end
function UI.updateAim(delta)
    if state.closing or not gui.Parent then return end
    -- No dibujar el circulo sobre las tarjetas del panel abierto.
    -- En juego (panel minimizado) vuelve a mostrarse normalmente.
    local ownHum=me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    local alive=ownHum and ownHum.Health>0
    aimOverlay.Visible = state.aim and alive and not config.aimbot
    aimOverlay.ZIndex=0 -- Detrás de los elementos del menú, visible durante el uso de Aim
    aimOverlay.Size=UDim2.fromOffset(config.aimFov*2,config.aimFov*2)
    if not alive or not (state.aim or config.aimbot) or state.farm or state.busy or UIS:GetFocusedTextBox() then
        aimCurrentTarget=nil
        return
    end
    local camera=workspace.CurrentCamera
    local desiredRole=UI.aimRole()
    if not camera or not desiredRole then
        aimCurrentTarget=nil
        return
    end
    local viewport=camera.ViewportSize
    local center=Vector2.new(viewport.X*0.5,viewport.Y*0.5)
    local closest=config.aimbot and math.huge or config.aimFov
    local chosenPos=nil
    local chosenTarget=nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=me and UI.getRole(p)==desiredRole then
            local char=p.Character
            local human=char and char:FindFirstChildOfClass("Humanoid")
            local body=char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart"))
            if human and human.Health>0 and body then
                local viewportPoint,onscreen=camera:WorldToViewportPoint(body.Position)
                if onscreen and viewportPoint.Z>0 then
                    local d=(Vector2.new(viewportPoint.X,viewportPoint.Y)-center).Magnitude
                    if d<=closest and UI.aimVisible(camera,body.Position,p) then
                        closest=d
                        chosenPos=body.Position
                        chosenTarget=p
                    end
                end
            end
        end
    end
    aimCurrentTarget=chosenTarget
    if chosenPos then
        -- Suavidad 1 = seguimiento instantaneo sin retraso.
        -- Al aumentar el valor, el seguimiento tarda progresivamente mas.
        -- La interpolacion exponencial mantiene una velocidad consistente
        -- con diferentes FPS (por ejemplo, 30, 60 o 120).
        local smooth=math.clamp(config.aimSmooth,1,100)
        local alpha
        if smooth <= 1 then
            alpha=1
        else
            local rate=85 / ((1+(smooth-1)*0.085)^1.75)
            alpha=1-math.exp(-rate*math.clamp(delta,0,0.1))
        end
        local source=camera.CFrame
        local desired=CFrame.lookAt(source.Position,chosenPos)
        camera.CFrame=source:Lerp(desired,alpha)
    end
end
RunService:BindToRenderStep("MVSS_AimV8",Enum.RenderPriority.Camera.Value+1,UI.updateAim)
connect(gui.Destroying,function()
    RunService:UnbindFromRenderStep("MVSS_AimV8")
end)

-- PLAYER: conservar colisiones originales para restaurarlas al salir de Noclip.
local flyVelocity, flyGyro = nil, nil
local originalPlatform = nil
local jumpRequested = false
connect(UIS.JumpRequest, function()
    if state.infiniteJump and not state.farm then
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
function UI.stopFly()
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    if originalPlatform and originalPlatform.hum.Parent then
        originalPlatform.hum.PlatformStand = originalPlatform.value
    end
    originalPlatform = nil
end
local speedAccum = 0
connect(RunService.Heartbeat,function(dt)
    if state.closing then return end
    local char = me.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if state.noclip and not state.farm and not state.busy and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipOriginal[part] == nil then noclipOriginal[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    elseif next(noclipOriginal) and not state.busy then
        for part,value in pairs(noclipOriginal) do
            if part.Parent then part.CanCollide = value end
            noclipOriginal[part] = nil
        end
    end
    if state.farm and hum then hum:Move(Vector3.zero, false) end
    if not root or not hum or hum.Health <= 0 or state.farm or state.busy then
        if flyVelocity then UI.stopFly() end
        return
    end
    if state.flying then
        if not flyVelocity then
            originalPlatform = {hum=hum,value=hum.PlatformStand}
            flyVelocity = new("BodyVelocity",root,{Name="MVSS_FlyVelocity",MaxForce=Vector3.new(1e7,1e7,1e7),P=20000,Velocity=Vector3.zero})
            flyGyro = new("BodyGyro",root,{Name="MVSS_FlyGyro",MaxTorque=Vector3.new(1e7,1e7,1e7),P=35000,D=900,CFrame=root.CFrame})
        end
        hum.PlatformStand=true
        local camera=workspace.CurrentCamera
        if camera then
            local cameraForward=camera.CFrame.LookVector
            local forward=Vector3.new(cameraForward.X,0,cameraForward.Z)
            if forward.Magnitude<0.01 then forward=Vector3.new(0,0,-1) end
            forward=forward.Unit
            local right=Vector3.new(camera.CFrame.RightVector.X,0,camera.CFrame.RightVector.Z).Unit
            local flat=Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then flat += forward end
            if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then flat -= forward end
            if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then flat += right end
            if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then flat -= right end
            if flat.Magnitude<0.01 then flat=hum.MoveDirection end -- joystick/touch
            local vertical=0
            if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.ButtonA) then vertical += 1 end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.ButtonB) then vertical -= 1 end
            local v=flat + Vector3.new(0,vertical,0)
            flyVelocity.Velocity=v.Magnitude>0 and v.Unit*config.flySpeed or Vector3.zero
            flyGyro.CFrame=CFrame.lookAt(root.Position,root.Position + forward)
        end
    else
        if flyVelocity then UI.stopFly() end
        if state.fastMove then
            -- Solo componentes X/Z; Y queda bajo control normal de la física.
            local move=hum.MoveDirection
            local flat=Vector3.new(move.X,0,move.Z)
            if flat.Magnitude>0.01 then
                flat=flat.Unit*config.playerSpeed
                local velocity=root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity=Vector3.new(flat.X,velocity.Y,flat.Z)
            end
        end
    end
end)
connect(me.CharacterAdded,function()
    UI.stopFly()
    noclipOriginal={}
    if state.farm then task.defer(function() setFarmInputLocked(true) end) end
end)
-- Carga local opcional, una vez que los controles estan construidos.
task.spawn(function()
    if typeof(readfile)~="function" or state.closing then return end
    local ok,data=pcall(function()
        local raw=readfile(UI.configFileName)
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok or type(data)~="table" or state.closing then return end
    if type(data.scale)=="number" then config.scale=math.clamp(data.scale,0.25,1.6); UI.scaleText.Text=tostring(math.floor(config.scale*100+0.5)).."%"; updateScale(); syncSizeSlider() end
    if type(data.playerSpeed)=="number" then updateSpeedSlider(data.playerSpeed) end
    if type(data.flySpeed)=="number" then config.flySpeed=math.clamp(data.flySpeed,10,120) end
    if type(data.aimFov)=="number" then setAimFov(data.aimFov) end
    if type(data.aimSmooth)=="number" then setAimSmooth(data.aimSmooth) end
    if type(data.aimWallcheck)=="boolean" then setAimWallcheck(data.aimWallcheck,true) end
    if type(data.aimbot)=="boolean" then UI.setAimbot(data.aimbot,true) end
    if type(data.notify)=="boolean" then setNotif(data.notify,true) end
    if type(data.sounds)=="boolean" then setSound(data.sounds,true) end
    if type(data.rainbowLauncher)=="boolean" then setRainbow(data.rainbowLauncher,true) end
    -- Restaurar también el estado visual y lógico de los interruptores.
    if type(data.enabledOptions)=="table" then
        local saved=data.enabledOptions
        local options={
            murder=setMurder,sheriff=setSheriff,innocents=setInnocents,
            autoKillAll=UI.setAutoKillAll,antiAfk=UI.setAntiAfk,
            gunEsp=setGunEsp,autoGun=setAutoGun,aim=setAim,
            noclip=setNoclip,infiniteJump=setInfiniteJump,
            flying=setFly,fastMove=setFastMove,
        }
        for key, setter in pairs(options) do
            if type(saved[key])=="boolean" then setter(saved[key],true) end
        end
        -- Coin Collector: se recupera el interruptor, pero respeta
        -- los requisitos de partida del propio script.
        if type(saved.farm)=="boolean" then setFarm(saved.farm,true) end
    end
    if type(data.blacklist)=="table" then
        state.blacklist={}
        for _,id in ipairs(data.blacklist) do
            if type(id)=="number" then state.blacklist[id]=true end
        end
        refreshPlayerList()
    end
    if type(data.hotkeys)=="table" then config.hotkeys=data.hotkeys end
    if type(data.onScreen)=="table" then config.onScreen=data.onScreen end
    if UI.refreshShortcutUi then UI.refreshShortcutUi() end
    if type(data.panelTransparency)=="number" then updatePanelTransparency(data.panelTransparency) end
    UI.lastSavedTheme = type(data.theme)=="string" and data.theme or nil
    if type(data.targetCollapsed)=="boolean" then config.targetCollapsed=data.targetCollapsed end
    redrawPlayerList()
    for _,t in ipairs(THEMES) do if t.name==data.theme then applyTheme(t);break end end
end)


-- Guardado a demanda: se realiza exclusivamente al pulsar GUARDAR.

-- ATAJOS DE TECLADO Y CONTROLES TÁCTILES.
-- Los atajos se ejecutan solo si no hay un TextBox en uso y no se está editando la tecla.
do
    local shortcuts = {
        {id="Farm", title="Coin Collector", toggle=function() setFarm(not state.farm) end, active=function() return state.farm end},
        {id="Murder", title="ESP Murder", toggle=function() setMurder(not state.murder) end, active=function() return state.murder end},
        {id="Sheriff", title="ESP Sheriff", toggle=function() setSheriff(not state.sheriff) end, active=function() return state.sheriff end},
        {id="Players", title="ESP Players", toggle=function() setInnocents(not state.innocents) end, active=function() return state.innocents end},
        {id="GunEsp", title="ESP Gun", toggle=function() setGunEsp(not state.gunEsp) end, active=function() return state.gunEsp end},
        {id="CatchGun", title="AutoCatchGun", toggle=function() setAutoGun(not state.autoGun) end, active=function() return state.autoGun end},
        {id="Aim", title="Aim", toggle=function() setAim(not state.aim) end, active=function() return state.aim end},
        {id="Aimbot", title="AIMBOT", toggle=function() UI.setAimbot(not config.aimbot) end, active=function() return config.aimbot end},
        {id="Noclip", title="Noclip", toggle=function() setNoclip(not state.noclip) end, active=function() return state.noclip end},
        {id="Jump", title="Infinite Jump", toggle=function() setInfiniteJump(not state.infiniteJump) end, active=function() return state.infiniteJump end},
        {id="Fly", title="Fly", toggle=function() setFly(not state.flying) end, active=function() return state.flying end},
        {id="Speed", title="Velocidad", toggle=function() setFastMove(not state.fastMove) end, active=function() return state.fastMove end},
        {id="KillAll", title="Kill All", toggle=function() task.spawn(function() UI.runCombat("All") end) end},
        {id="KillSheriff", title="Kill Sheriff", toggle=function() task.spawn(function() UI.runCombat("Sheriff") end) end},
        {id="KillTarget", title="Kill Target", toggle=function() end},
        {id="Goto", title="Goto", toggle=function()
            local target=state.targetUserId and Players:GetPlayerByUserId(state.targetUserId)
            local ownRoot=me.Character and me.Character:FindFirstChild("HumanoidRootPart")
            local targetRoot=target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if ownRoot and targetRoot then
                UI.suspendFarm()
                ownRoot.CFrame=targetRoot.CFrame * CFrame.new(0,0,3)
                ownRoot.AssemblyLinearVelocity=Vector3.zero
            else notify("Goto","Seleccioná un objetivo disponible",C.orange) end
        end},
        {id="AimWall", title="Wallcheck", toggle=function() setAimWallcheck(not config.aimWallcheck) end, active=function() return config.aimWallcheck end},
        {id="Notif", title="Notificaciones", toggle=function() setNotif(not config.notify) end, active=function() return config.notify end},
        {id="Sound", title="Sonidos", toggle=function() setSound(not config.sounds) end, active=function() return config.sounds end},
    }
    -- Los eventos RBXScriptSignal no se pueden disparar manualmente. Usar el botón existente
    -- para los atajos de acción con una función explícita.
    for _,entry in ipairs(shortcuts) do
        if entry.id=="KillTarget" then
            entry.toggle=function()
                local target = state.targetUserId and Players:GetPlayerByUserId(state.targetUserId)
                if target then task.spawn(function() UI.runCombat("Target",target) end)
                else notify("Kill Target","Seleccioná un jugador en OP",C.orange) end
            end
        end
    end
    UI.shortcutActions=shortcuts
    -- Atajos directamente a la IZQUIERDA de los interruptores / botones de OP.
    -- Un dispositivo con teclado usa KB; en pantalla táctil sin teclado usa ON SCREEN.
    local reserved = {W=true,A=true,S=true,D=true,Space=true,Up=true,Down=true,Left=true,Right=true,Escape=true,Unknown=true,Slash=true,Return=true,Tab=true}
    local editing = nil
    local rows = {}
    local touchMode = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local dock = new("ScrollingFrame",gui,{
        Name="MobileShortcuts",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),
        Size=UDim2.fromOffset(122,240),CanvasSize=UDim2.fromOffset(0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,BackgroundColor3=C.bg,
        BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=110,Visible=false
    })
    round(dock,9)
    line(dock,C.line,.16)
    new("UIPadding",dock,{PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6)})
    new("UIListLayout",dock,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
    UI.shortcutDock=dock
    local function refresh()
        local amount=0
        for _,entry in ipairs(shortcuts) do
            local row=rows[entry.id]
            if row then
                local keyName=config.hotkeys[entry.id]
                row.keyboard.Text=editing==entry.id and "..." or (keyName or "KB")
                row.mobile.Text=config.onScreen[entry.id] and "ON: SI" or "ON SCREEN"
                row.mobile.BackgroundColor3=config.onScreen[entry.id] and C.navy or C.dark
                row.keyboard.BackgroundColor3=keyName and C.navy or C.dark
                row.keyboard.Visible=not touchMode
                row.mobile.Visible=touchMode
                row.action.Visible=touchMode and config.onScreen[entry.id]==true
                row.action.BackgroundColor3=(entry.active and entry.active()) and C.navy or C.dark
                row.action.Text=entry.title.."  "..((entry.active and entry.active()) and "ON" or "OFF")
                if row.action.Visible then
                    amount+=1
                    if not row.action:GetAttribute("UserDragged") then
                        row.action.Position=UDim2.new(1,-12-math.floor((amount-1)/7)*139,0,70+((amount-1)%7)*42)
                    end
                end
            end
        end
        dock.Visible=false -- Cada acceso táctil es ahora un botón independiente.
    end
    -- Vincula cada opción al título real mostrado en su tarjeta.
    local titleMap={Aim="FOV Circle + Aim",Jump="Infinite Jump",Speed="Velocidad",AimWall="Wallcheck",Notif="Notificaciones",Sound="Sonidos"}
    for i,entry in ipairs(shortcuts) do
        local cardTitle=titleMap[entry.id] or entry.title
        local host=UI.inlineShortcutCards[cardTitle]
        if host then
            local kb=new("TextButton",host.card,{
                Name="KeyboardShortcut",Position=UDim2.new(1,host.main.Text=="EJECUTAR" and -125 or -87,.5,-11),Size=UDim2.fromOffset(30,22),
                BackgroundColor3=C.dark,TextColor3=C.white,TextSize=10,Font=Enum.Font.GothamBold,
                Text="KB",AutoButtonColor=false,Visible=not touchMode,ZIndex=6
            })
            local mobile=new("TextButton",host.card,{
                Name="OnScreenShortcut",Position=UDim2.new(1,host.main.Text=="EJECUTAR" and -161 or -126,.5,-11),Size=UDim2.fromOffset(66,22),
                BackgroundColor3=C.dark,TextColor3=C.white,TextSize=8,Font=Enum.Font.GothamBold,
                Text="ON SCREEN",AutoButtonColor=false,Visible=touchMode,ZIndex=6
            })
            round(kb,6);round(mobile,6)
            line(kb,C.line,.3);line(mobile,C.line,.3)
            local action=new("TextButton",gui,{
                Name="MobileAction_"..entry.id,AnchorPoint=Vector2.new(1,0),
                Position=UDim2.new(1,-12,0,80+(i-1)*43),
                Size=UDim2.fromOffset(128,36),Text=entry.title.." OFF",Font=Enum.Font.GothamBold,
                TextSize=10,TextColor3=C.white,BackgroundColor3=C.dark,Visible=false,AutoButtonColor=false,ZIndex=111
            })
            round(action,6)
            line(action,C.line,.2)
            local dragState={active=false,moved=false,input=nil,start=nil,orig=nil}
            connect(action.InputBegan,function(input)
                if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
                    dragState.active=true;dragState.moved=false;dragState.input=input
                    dragState.start=input.Position;dragState.orig=action.Position
                end
            end)
            connect(UIS.InputChanged,function(input)
                if dragState.active and (input==dragState.input or input.UserInputType==Enum.UserInputType.MouseMovement) then
                    local delta=input.Position-dragState.start
                    if delta.Magnitude>8 then dragState.moved=true end
                    if dragState.moved then
                        action.Position=UDim2.new(dragState.orig.X.Scale,dragState.orig.X.Offset+delta.X,dragState.orig.Y.Scale,dragState.orig.Y.Offset+delta.Y)
                    end
                end
            end)
            connect(UIS.InputEnded,function(input)
                if dragState.active and (input==dragState.input or input.UserInputType==Enum.UserInputType.MouseButton1) then
                    dragState.active=false
                    if dragState.moved then
                        action:SetAttribute("UserDragged",true)
                        dragState.cancelClick=true
                        task.delay(.2,function()dragState.cancelClick=false end)
                    end
                end
            end)
            rows[entry.id]={keyboard=kb,mobile=mobile,action=action}
            connect(kb.MouseButton1Click,function()
                editing=editing==entry.id and nil or entry.id
                refresh()
                if editing then notify("KEYBOARD","Presioná una tecla para "..entry.title.." (Backspace para borrar)",C.sheriff) end
            end)
            connect(mobile.MouseButton1Click,function()
                config.onScreen[entry.id]=not config.onScreen[entry.id]
                refresh()
            end)
            connect(action.MouseButton1Click,function()
                if editing or dragState.cancelClick then return end
                entry.toggle()
                refresh()
            end)
        end
    end
    connect(UIS.InputBegan,function(input,processed)
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local key=input.KeyCode
        if editing then
            local chosen=editing
            editing=nil
            if key==Enum.KeyCode.Backspace or key==Enum.KeyCode.Delete then
                config.hotkeys[chosen]=nil
            elseif not reserved[key.Name] then
                for id,value in pairs(config.hotkeys) do if value==key.Name then config.hotkeys[id]=nil end end
                config.hotkeys[chosen]=key.Name
            else
                notify("KEYBOARD","Tecla de movimiento o sistema reservada",C.orange)
            end
            refresh()
            return
        end
        if processed or UIS:GetFocusedTextBox() then return end
        for _,entry in ipairs(shortcuts) do
            if config.hotkeys[entry.id]==key.Name then
                entry.toggle()
                refresh()
                break
            end
        end
    end)
    UI.refreshShortcutUi=refresh
    refresh()
    task.spawn(function()
        while gui.Parent and not state.closing do
            task.wait(.45)
            if touchMode then refresh() end
        end
    end)
end

-- Registrar componentes recién creados: Settings, launcher y controles de ventana.
-- En versiones anteriores se registraban antes de existir y no cambiaban de color.
for _, obj in ipairs(gui:GetDescendants()) do
    trackThemeObject(obj)
end
-- Actualiza superficies claras a oscuro al iniciar, sin decolorar UI.avatar.
applyTheme(THEMES[1])
-- Mantener la búsqueda y la barra superior dentro del tema también.


-- FPS real: promedio de los últimos 0,65 segundos; un único listener ligero.
do
    local frameSamples=0
    local seconds=0
    connect(RunService.RenderStepped,function(dt)
        if state.closing or not gui.Parent then return end
        frameSamples+=1
        seconds+=math.clamp(dt,0,0.25)
        if seconds>=0.65 then
            local fps=math.floor(frameSamples/math.max(seconds,0.001)+0.5)
            UI.fpsText.Text=tostring(fps).." FPS"
            UI.fpsDot.BackgroundColor3=(fps<=20) and Color3.fromRGB(246,55,62)
                or ((fps<90) and Color3.fromRGB(255,157,39) or Color3.fromRGB(45,215,121))
            seconds=0
            frameSamples=0
        end
    end)
end

-- Se quitó el reloj de la cabecera.
-- Actualización periódica del ESP y del estado del panel.
task.spawn(function()
    while not state.closing and gui.Parent do
        UI.refreshEsp()
        UI.updateGunEsp()
        UI.updateOwnRole()
        UI.aimInfoText.Text = "AIM: " .. ((state.aim or config.aimbot) and (aimCurrentTarget and "@"..aimCurrentTarget.Name or "buscando") or "desactivado")
            .. "  •  WALLCHECK: " .. (config.aimWallcheck and "Yes" or "No")
            .. "\nMurder → Sheriff  |  Sheriff → Murder"
        UI.statusPlayers.Text = tostring(#Players:GetPlayers())
        local count = (state.farm and 1 or 0) + (state.murder and 1 or 0) + (state.sheriff and 1 or 0) + (state.innocents and 1 or 0) + (state.autoGun and 1 or 0) + (state.gunEsp and 1 or 0)
        UI.statusOptions.Text = tostring(count) .. " / 6"
        task.wait(0.45)
    end
end)

-- ================================================
-- XONI HUB | Bienvenida e idiomas (ES / EN / PT-BR)
-- ================================================
do
local languages = {
    en = {
        ["Open Menu"]="Open Menu", ["Open Panel"]="Open Panel",
        ["PRINCIPAL"]="MAIN", ["SISTEMA"]="SYSTEM", ["CONFIG"]="SETTINGS",
        ["Configuración"]="Settings", ["CONFIGURACIÓN"]="SETTINGS",
        ["Evento"]="Events",["Jugador"]="Player", ["Home"]="Home", ["Event"]="Events",
        ["Panel principal"]="Dashboard",["PANEL PRINCIPAL"]="DASHBOARD",
        ["Resumen en vivo de tu sesión y estado de las funciones."]="Live session overview and feature status.",
        ["Eventos"]="Events",["EVENTOS"]="EVENTS", ["Acciones disponibles para los caramelos."]="Available actions for coins.",
        ["Herramientas y acciones de la partida."]="Game tools and actions.",
        ["Buscar opción..."]="Search option...",["⌕  Buscar opción..."]="⌕  Search option...",
        ["Buscar @usuario o nombre..."]="Search @username or name...",
        ["Buscar @usuario o nombre..."]="Search @username or name...",
        ["ESP Jugadores"]="ESP Players",["ESP Players"]="ESP Players",
        ["Muestra jugadores normales, sin Murder ni Sheriff."]="Shows innocent players, excluding Murder and Sheriff.",
        ["Marca al Murder en rojo y muestra su usuario."]="Highlights Murder in red, with username and distance.",
        ["Marca al Sheriff en azul y muestra su usuario."]="Highlights Sheriff in blue, with username and distance.",
        ["Marca la GunDrop a través de las paredes."]="Shows the dropped gun through walls with distance.",
        ["Busca la Gun Drop y regresa automáticamente."]="Finds the dropped gun and returns automatically.",
        ["Acción con Knife sobre el Sheriff, cuando está disponible."]="Knife action against Sheriff when available.",
        ["Excluye Murder y jugadores en blacklist."]="Targets within 5000 studs; excludes Murder and blacklist.",
        ["Sin jugador seleccionado"]="No player selected",["PLAYER ACTIONS"]="PLAYER ACTIONS",
        ["EJECUTAR"]="RUN",["GUARDAR"]="SAVE",["SUGERENCIAS"]="SUGGESTIONS",
        ["No hay opciones con ese nombre"]="No matching options",
        ["Tu rol detectado"]="Your detected role",["TU ROL DETECTADO"]="YOUR DETECTED ROLE",
        ["Jugadores conectados"]="Connected players",["JUGADORES CONECTADOS"]="CONNECTED PLAYERS",
        ["Funciones activas"]="Enabled features",["FUNCIONES ACTIVAS"]="ENABLED FEATURES",
        ["Estado de la ronda."]="Round status.",["Cantidad de jugadores en este servidor."]="Number of players in this server.",
        ["Coin Collector, ESP y AutoCatchGun."]="Coin Collector, ESP and AutoCatchGun.",
        ["ESPERANDO"]="WAITING",["Estado: esperando activación"]="Status: waiting for activation",
        ["Recolecta caramelos, recupera tu movimiento normal y continúa con el siguiente."]="Collects coins, restores normal movement and continues.",
        ["Aim"]="Aim",["AIM"]="AIM",["Seguimiento visual con FOV y objetivos según tu rol."]="Visual aiming with FOV and role-based targets.",
        ["Círculo y seguimiento suave del cuerpo al estar dentro del FOV."]="FOV circle and smooth tracking for targets inside it.",
        ["Activado: solo apunta a personajes sin obstáculos. Desactivado: no filtra paredes."]="Enabled: only targets visible characters. Disabled: ignores walls.",
        ["TAMAÑO DEL FOV"]="FOV SIZE",["SUAVIDAD"]="SMOOTHNESS",
        ["Radio de detección alrededor del centro de la pantalla."]="Detection radius around the screen center.",
        ["1 = fijación inmediata; valores altos = seguimiento más lento."]="1 = instant lock; higher values = slower tracking.",
        ["Estado Aim"]="Aim status",["Opciones de movimiento personalizables."]="Customizable movement options.",
        ["Permite atravesar objetos. Al desactivar restaura las colisiones."]="Allows passing through objects. Disabling restores collisions.",
        ["Podés saltar nuevamente en el aire."]="Jump again while airborne.",
        ["Vuelo con control de cámara y movimiento estable."]="Camera-controlled stable flight.",
        ["Velocidad"]="Speed",["VELOCIDAD"]="SPEED",
        ["Ajustá la velocidad horizontal deslizando la barra."]="Adjust horizontal speed with the slider.",
        ["Configuración"]="Settings", ["Preferencias visuales y de avisos."]="Visual and notification preferences.",
        ["Notificaciones"]="Notifications",["Muestra avisos en la esquina inferior derecha."]="Displays notifications in the bottom-right corner.",
        ["Sonidos"]="Sounds",["Reproduce un pequeño sonido de aviso y clic."]="Plays a short alert and click sound.",
        ["RAINBOW"]="RAINBOW",["Activa los colores arcoíris del botón Open Menu."]="Enables rainbow colors on the Open Menu button.",
        ["TEMAS Y COLORES"]="THEMES AND COLORS",["Temas y colores"]="Themes and colors",
        ["TRANSPARENCIA DEL PANEL"]="PANEL TRANSPARENCY",["Transparencia del panel"]="Panel transparency",
        ["SAVE CONFIG"]="SAVE CONFIG",["4 segundos"]="4 seconds",["6 segundos"]="6 seconds",["8 segundos"]="8 seconds",
        ["Tema actualizado"]="Theme updated",["Preferencia actualizada"]="Preference updated",
        ["Función activada"]="Feature enabled",["Función desactivada"]="Feature disabled",
        ["Panel cargado"]="Panel loaded",["Dashboard listo"]="Dashboard ready",
        ["No tienes requisitos necesarios"]="Requirements not met",
        ["Buscando GunDrop en el mapa..."]="Searching map for GunDrop...",
        ["No identificado"]="Not identified",["desactivado"]="disabled",["buscando"]="searching",
        ["Seleccioná un jugador en OP"]="Select a player in OP",
        ["Seleccioná un objetivo disponible"]="Select an available target",
        ["Guardado permanente no disponible en esta experiencia"]="Permanent saving is not available in this experience",
        ["Configuración guardada"]="Settings saved",["No se pudo guardar; revisá DataStore"]="Could not save; check DataStore",
        ["Tecla de movimiento o sistema reservada"]="Movement/system key is reserved",
        ["Sin jugador seleccionado"]="No player selected",["ON: SI"]="ON: YES",
    },
    pt = {
        ["PRINCIPAL"]="PRINCIPAL",["SISTEMA"]="SISTEMA",["CONFIG"]="CONFIGURAÇÕES",
        ["Configuración"]="Configurações",["CONFIGURACIÓN"]="CONFIGURAÇÕES",
        ["Evento"]="Evento",["Jugador"]="Jogador",["Event"]="Eventos",["Home"]="Início",
        ["Panel principal"]="Painel principal",["PANEL PRINCIPAL"]="PAINEL PRINCIPAL",
        ["Resumen en vivo de tu sesión y estado de las funciones."]="Resumo em tempo real e status das funções.",
        ["Eventos"]="Eventos",["EVENTOS"]="EVENTOS",["Acciones disponibles para los caramelos."]="Ações disponíveis para coletar moedas.",
        ["Herramientas y acciones de la partida."]="Ferramentas e ações da partida.",
        ["⌕  Buscar opción..."]="⌕  Buscar opção...",["Buscar opción..."]="Buscar opção...",
        ["Buscar @usuario o nombre..."]="Buscar @usuário ou nome...",
        ["ESP Jugadores"]="ESP Jogadores",["ESP Players"]="ESP Jogadores",
        ["Muestra jugadores normales, sin Murder ni Sheriff."]="Mostra jogadores inocentes, exceto Murder e Sheriff.",
        ["Marca al Murder en rojo y muestra su usuario."]="Destaca o Murder em vermelho, com usuário e distância.",
        ["Marca al Sheriff en azul y muestra su usuario."]="Destaca o Sheriff em azul, com usuário e distância.",
        ["Marca la GunDrop a través de las paredes."]="Mostra a arma caída através das paredes e sua distância.",
        ["Busca la Gun Drop y regresa automáticamente."]="Encontra a arma caída e retorna automaticamente.",
        ["Acción con Knife sobre el Sheriff, cuando está disponible."]="Ação com faca contra Sheriff, quando disponível.",
        ["Excluye Murder y jugadores en blacklist."]="Alvos até 5000 studs; exclui Murder e lista negra.",["PLAYER ACTIONS"]="AÇÕES DE JOGADORES",
        ["Sin jugador seleccionado"]="Nenhum jogador selecionado",
        ["EJECUTAR"]="EXECUTAR",["GUARDAR"]="SALVAR",["SUGERENCIAS"]="SUGESTÕES",
        ["No hay opciones con ese nombre"]="Nenhuma opção encontrada",
        ["TU ROL DETECTADO"]="SUA FUNÇÃO IDENTIFICADA",["JUGADORES CONECTADOS"]="JOGADORES CONECTADOS",
        ["FUNCIONES ACTIVAS"]="FUNÇÕES ATIVAS",["Estado de la ronda."]="Status da rodada.",
        ["Cantidad de jugadores en este servidor."]="Número de jogadores neste servidor.",
        ["Coin Collector, ESP y AutoCatchGun."]="Coin Collector, ESP e AutoCatchGun.",
        ["ESPERANDO"]="AGUARDANDO",["Estado: esperando activación"]="Status: aguardando ativação",
        ["Recolecta caramelos, recupera tu movimiento normal y continúa con el siguiente."]="Coleta moedas, recupera o movimento normal e continua.",
        ["Seguimiento visual con FOV y objetivos según tu rol."]="Mira assistida com FOV e alvos de acordo com sua função.",
        ["Círculo y seguimiento suave del cuerpo al estar dentro del FOV."]="Círculo FOV e rastreamento suave de alvos dentro dele.",
        ["Activado: solo apunta a personajes sin obstáculos. Desactivado: no filtra paredes."]="Ativado: apenas alvos visíveis. Desativado: ignora paredes.",
        ["TAMAÑO DEL FOV"]="TAMANHO DO FOV",["SUAVIDAD"]="SUAVIDADE",
        ["Radio de detección alrededor del centro de la pantalla."]="Raio de detecção ao redor do centro da tela.",
        ["1 = fijación inmediata; valores altos = seguimiento más lento."]="1 = mira instantânea; valores maiores = rastreamento lento.",
        ["Opciones de movimiento personalizables."]="Opções de movimento personalizáveis.",
        ["Permite atravesar objetos. Al desactivar restaura las colisiones."]="Permite atravessar objetos. Ao desligar, restaura as colisões.",
        ["Podés saltar nuevamente en el aire."]="Você pode pular novamente no ar.",
        ["Vuelo con control de cámara y movimiento estable."]="Voo estável controlado pela câmera.",
        ["Velocidad"]="Velocidade",["VELOCIDAD"]="VELOCIDADE",
        ["Ajustá la velocidad horizontal deslizando la barra."]="Ajuste a velocidade horizontal com a barra.",
        ["Preferencias visuales y de avisos."]="Preferências visuais e de notificações.",
        ["Notificaciones"]="Notificações",["Muestra avisos en la esquina inferior derecha."]="Exibe avisos no canto inferior direito.",
        ["Sonidos"]="Sons",["Reproduce un pequeño sonido de aviso y clic."]="Reproduz um som curto de aviso e clique.",
        ["RAINBOW"]="RAINBOW",["Activa los colores arcoíris del botón Open Menu."]="Ativa as cores arco-íris do botão Open Menu.",
        ["TEMAS Y COLORES"]="TEMAS E CORES",["Temas y colores"]="Temas e cores",
        ["TRANSPARENCIA DEL PANEL"]="TRANSPARÊNCIA DO PAINEL",["Transparencia del panel"]="Transparência do painel",
        ["4 segundos"]="4 segundos",["6 segundos"]="6 segundos",["8 segundos"]="8 segundos",
        ["Tema actualizado"]="Tema atualizado",["Preferencia actualizada"]="Preferência atualizada",
        ["Función activada"]="Função ativada",["Función desactivada"]="Função desativada",
        ["Panel cargado"]="Painel carregado",["Dashboard listo"]="Painel pronto",
        ["No tienes requisitos necesarios"]="Requisitos não atendidos",
        ["Buscando GunDrop en el mapa..."]="Procurando GunDrop no mapa...",
        ["No identificado"]="Não identificado",["desactivado"]="desativado",["buscando"]="procurando",
        ["Seleccioná un jugador en OP"]="Selecione um jogador em OP",
        ["Seleccioná un objetivo disponible"]="Selecione um alvo disponível",
        ["Guardado permanente no disponible en esta experiencia"]="Salvamento permanente indisponível nesta experiência",
        ["Configuración guardada"] = "Configurações salvas",
        ["No se pudo guardar; revisá DataStore"] = "Não foi possível salvar; verifique o DataStore",
        ["Tecla de movimiento o sistema reservada"]="Tecla reservada para movimento/sistema",
        ["ON: SI"]="ON: SIM",
    },
}

-- Preservar a origem em espanhol; não traduzir nomes de usuários, chaves ou números.
local selectedLanguage="es"
local localizedObjects={}
local internalTextChange=false
local function translateUiString(original)
    if selectedLanguage=="es" then return original end
    local dict=languages[selectedLanguage] or {}
    if dict[original] then return dict[original] end
    local prefix,category=original:match("^(XONI HUB%s+›%s+)(.+)$")
    if prefix then return prefix..(dict[category] or category) end
    -- Textos de status alterados periodicamente durante a partida.
    local result=original
    if selectedLanguage=="en" then
        result=result:gsub("Sin jugador seleccionado","No player selected")
            :gsub("Seleccionado:","Selected:")
            :gsub("Función activada","Feature enabled")
            :gsub("Función desactivada","Feature disabled")
            :gsub("Murder: esperando","Murder: waiting")
            :gsub("Sheriff: esperando","Sheriff: waiting")
            :gsub("No identificado","Not identified")
            :gsub("desactivado","disabled")
            :gsub("buscando","searching")
            :gsub("No %(atraviesa paredes%)","No (through walls)")
            :gsub("TÚ","YOU")
            :gsub("Estado:","Status:")
            :gsub("Agarrando coins","Collecting coins")
            :gsub("Evitando coins cerca del Murder","Avoiding coins near Murder")
            :gsub("buscando moneda segura","looking for a safe coin")
            :gsub("Seleccioná primero un jugador","Select a player first")
            :gsub("Acción terminada","Action finished")
            :gsub("No se pudo ejecutar","Action failed")
            :gsub("esperando nuevas monedas","waiting for new coins")
            :gsub("SUGERENCIAS","SUGGESTIONS")
            :gsub("resultados","results")
    else
        result=result:gsub("Sin jugador seleccionado","Nenhum jogador selecionado")
            :gsub("Seleccionado:","Selecionado:")
            :gsub("Función activada","Função ativada")
            :gsub("Función desactivada","Função desativada")
            :gsub("Murder: esperando","Murder: aguardando")
            :gsub("Sheriff: esperando","Sheriff: aguardando")
            :gsub("No identificado","Não identificado")
            :gsub("desactivado","desativado")
            :gsub("buscando","procurando")
            :gsub("No %(atraviesa paredes%)","Não (através das paredes)")
            :gsub("TÚ","VOCÊ")
            :gsub("Estado:","Status:")
            :gsub("Agarrando coins","Coletando moedas")
            :gsub("Evitando coins cerca del Murder","Evitando moedas perto do Murder")
            :gsub("buscando moneda segura","procurando moeda segura")
            :gsub("Seleccioná primero un jugador","Selecione um jogador primeiro")
            :gsub("Acción terminada","Ação concluída")
            :gsub("No se pudo ejecutar","Ação falhou")
            :gsub("esperando nuevas monedas","aguardando novas moedas")
            :gsub("SUGERENCIAS","SUGESTÕES")
            :gsub("resultados","resultados")
    end
    return result
end
local function attachLocale(obj)
    if localizedObjects[obj] then return end
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    if obj:IsA("TextBox") then
        local initial=obj.PlaceholderText
        if initial and initial~="" then
            local base=initial
            localizedObjects[obj]={placeholder=base}
            connect(obj:GetPropertyChangedSignal("PlaceholderText"),function()
                if internalTextChange then return end
                base=obj.PlaceholderText
                localizedObjects[obj].placeholder=base
                local converted=translateUiString(base)
                if converted~=base then
                    internalTextChange=true;obj.PlaceholderText=converted;internalTextChange=false
                end
            end)
            local converted=translateUiString(base)
            if converted~=base then
                internalTextChange=true;obj.PlaceholderText=converted;internalTextChange=false
            end
            return
        end
    end
    local base=obj.Text
    localizedObjects[obj]={text=base}
    connect(obj:GetPropertyChangedSignal("Text"),function()
        if internalTextChange or not obj.Parent then return end
        local raw=obj.Text
        local converted=translateUiString(raw)
        localizedObjects[obj].text=raw
        if raw~=converted then
            internalTextChange=true;obj.Text=converted;internalTextChange=false
        end
    end)
    local converted=translateUiString(base)
    if converted~=base then
        internalTextChange=true;obj.Text=converted;internalTextChange=false
    end
end
local function setLanguage(code)
    selectedLanguage=code
    config.language=code
    for obj,data in pairs(localizedObjects) do
        if obj.Parent then
            internalTextChange=true
            if data.text~=nil then obj.Text=translateUiString(data.text) end
            if data.placeholder~=nil then obj.PlaceholderText=translateUiString(data.placeholder) end
            internalTextChange=false
        end
    end
    -- Cabecera e indicador de sección se actualizan al cambiar de idioma.
    UI.headerTitle.Text="XONI HUB   ›   "..string.upper(activePage or "Home")
end
for _,obj in ipairs(gui:GetDescendants()) do attachLocale(obj) end
connect(gui.DescendantAdded,function(obj)
    task.defer(function() if obj.Parent and gui.Parent then attachLocale(obj) end end)
end)

-- Mantener la interfaz oculta hasta elegir idioma.
main.Visible=false
launcher.Visible=false
local welcome=new("Frame",gui,{
    Name="WelcomeLanguage",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(440,280),BackgroundColor3=Color3.fromRGB(10,10,13),
    BorderSizePixel=0,ZIndex=200
})
round(welcome,12)
local welcomeStroke=line(welcome,C.red,0);welcomeStroke.Thickness=2
new("UIGradient",welcome,{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(25,15,21)),ColorSequenceKeypoint.new(.65,Color3.fromRGB(11,11,15)),ColorSequenceKeypoint.new(1,Color3.fromRGB(6,6,9))})})
local topLine=new("Frame",welcome,{Position=UDim2.fromOffset(16,8),Size=UDim2.new(1,-32,0,2),BorderSizePixel=0,BackgroundColor3=C.red,ZIndex=201})
new("UIGradient",topLine,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(75,12,19)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,55,65)),ColorSequenceKeypoint.new(1,Color3.fromRGB(75,12,19))})})
-- Animacion suave: reflejo rojo que recorre la linea y puntos flotantes.
-- Todo vive dentro de la bienvenida, de modo que se elimina al elegir idioma.
do
    local sweep=new("Frame",topLine,{
        Name="RedSweep",Size=UDim2.fromOffset(55,2),Position=UDim2.fromScale(0,0),
        BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(255,105,115),ZIndex=203
    })
    local t=TweenService:Create(sweep,TweenInfo.new(2.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{
        Position=UDim2.new(1,-55,0,0)
    })
    t:Play()
    for i=1,9 do
        local x=((i*47)%390)+20
        local y=((i*37)%210)+25
        local dot=new("Frame",welcome,{
            Name="AnimatedRedDot",Position=UDim2.fromOffset(x,y),
            Size=UDim2.fromOffset(i%3==0 and 3 or 2,i%3==0 and 3 or 2),
            BackgroundColor3=Color3.fromRGB(240,36,63),BackgroundTransparency=.45,
            BorderSizePixel=0,ZIndex=200
        })
        round(dot,4)
        TweenService:Create(dot,TweenInfo.new(2.1+(i%4)*.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{
            Position=UDim2.fromOffset(x,y-12-(i%3)*8),BackgroundTransparency=.82
        }):Play()
    end
end

new("Frame",welcome,{Position=UDim2.fromOffset(25,157),Size=UDim2.new(1,-50,0,1),BackgroundColor3=Color3.fromRGB(74,34,39),BorderSizePixel=0,ZIndex=201})
local welcomeScale=new("UIScale",welcome,{Scale=1})
local function welcomeFit()
    local cam=workspace.CurrentCamera
    if cam then
        local v=cam.ViewportSize
        welcomeScale.Scale=math.min(1,(v.X-18)/440,(v.Y-18)/280)
    end
end
welcomeFit()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),welcomeFit) end
local iconFrame=new("ImageLabel",welcome,{
    Position=UDim2.fromOffset(194,19),Size=UDim2.fromOffset(52,52),
    Image="rbxassetid://" .. ICON_ID,BackgroundColor3=C.dark,
    BorderSizePixel=0,ZIndex=201,ScaleType=Enum.ScaleType.Fit
})
round(iconFrame,9)
local iconBorder=line(iconFrame,C.red,0);iconBorder.Thickness=1.6
text(welcome,"BIENVENIDO A XONI HUB",20,C.white,true,{
    Position=UDim2.fromOffset(20,81),Size=UDim2.new(1,-40,0,33),
    TextXAlignment=Enum.TextXAlignment.Center,ZIndex=201
})
text(welcome,"SELECT IDIOM",11,C.muted,true,{
    Position=UDim2.fromOffset(20,124),Size=UDim2.new(1,-40,0,22),
    TextXAlignment=Enum.TextXAlignment.Center,ZIndex=201
})
local choices={
    {code="es",name="ESPAÑOL",x=21},
    {code="en",name="ENGLISH",x=160},
    {code="pt",name="BRASILERO",x=299},
}
for _,choice in ipairs(choices) do
    local btn=new("TextButton",welcome,{
        Name="Language_"..choice.code,Position=UDim2.fromOffset(choice.x,174),
        Size=UDim2.fromOffset(120,44),BackgroundColor3=C.dark,BorderSizePixel=0,
        Text=choice.name,TextColor3=C.white,Font=Enum.Font.GothamBold,TextSize=12,
        AutoButtonColor=false,ZIndex=201
    })
    round(btn,7)
    local stroke=line(btn,C.red,.42);stroke.Thickness=1
    text(btn,choice.code=="es" and "ES" or (choice.code=="en" and "EN" or "BR"),9,C.red,true,{Position=UDim2.fromOffset(7,2),Size=UDim2.fromOffset(22,11),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=202})
    connect(btn.MouseEnter,function()tween(btn,.12,{BackgroundColor3=C.navy})end)
    connect(btn.MouseLeave,function()tween(btn,.12,{BackgroundColor3=C.dark})end)
    connect(btn.MouseButton1Click,function()
        playSound(clickSound)
        setLanguage(choice.code)
        welcome:Destroy()
        main.Visible=true
        state.open=true
        updateScale()
        -- Forzar la restauracion del tema guardado al abrir el panel.
        -- Asi no queda sobrescrito por el tema inicial Rojo.
        if typeof(readfile)=="function" then
            local ok,data=pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile(UI.configFileName))
            end)
            if ok and type(data)=="table" then
                if type(data.theme)=="string" then
                    for _,palette in ipairs(THEMES) do
                        if palette.name==data.theme then applyTheme(palette);break end
                    end
                end
                if type(data.panelTransparency)=="number" then updatePanelTransparency(data.panelTransparency) end
                if type(data.scale)=="number" then
                    config.scale=math.clamp(data.scale,0.25,1.6)
                    UI.scaleText.Text=tostring(math.floor(config.scale*100+.5)).."%"
                    syncSizeSlider()
                    updateScale()
                end
            end
        end
        notify("Panel cargado","Dashboard listo",C.mint)
    end)
end
text(welcome,"XONI HUB  •  V32",10,C.muted,true,{
    Position=UDim2.fromOffset(20,239),Size=UDim2.new(1,-40,0,20),
    TextXAlignment=Enum.TextXAlignment.Center,ZIndex=201
})


end -- XONI HUB localization / welcome local scope
