local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

local MAX_DISPLAY_ORDER = 2147483647

local ICONS = {
    Maximize = "rbxassetid://84623133872179",
    Close    = "rbxassetid://100928939627907",
    Minimize = "rbxassetid://82909496983440",
}

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(t)
    self._tasks[#self._tasks + 1] = t
    return t
end

function Maid:Clean()
    for i = #self._tasks, 1, -1 do
        local t = self._tasks[i]
        self._tasks[i] = nil
        if typeof(t) == "RBXScriptConnection" then
            t:Disconnect()
        elseif typeof(t) == "Instance" then
            t:Destroy()
        elseif type(t) == "function" then
            pcall(t)
        elseif type(t) == "table" and type(t.Destroy) == "function" then
            pcall(function() t:Destroy() end)
        end
    end
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _h = {}, _alive = true }, Signal)
end

function Signal:Connect(fn)
    if not self._alive then return { Disconnect = function() end } end
    local h = self._h
    h[#h + 1] = fn
    return {
        Disconnect = function()
            for i, v in ipairs(h) do
                if v == fn then table.remove(h, i) break end
            end
        end,
    }
end

function Signal:Fire(...)
    if not self._alive then return end
    for _, fn in ipairs(self._h) do
        task.spawn(fn, ...)
    end
end

function Signal:Destroy()
    self._alive = false
    table.clear(self._h)
end

local DefaultTheme = {
    Background = Color3.fromRGB(18, 18, 22),
    Surface    = Color3.fromRGB(26, 26, 32),
    Accent     = Color3.fromRGB(120, 90, 255),
    Text       = Color3.fromRGB(235, 235, 240),
    SubText    = Color3.fromRGB(150, 150, 160),
    Divider    = Color3.fromRGB(40, 40, 48),
    Danger     = Color3.fromRGB(220, 60, 80),
}

local function new(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do inst[k] = v end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    return inst
end

local function mergeTheme(custom)
    local out = {}
    for k, v in pairs(DefaultTheme) do out[k] = v end
    if type(custom) == "table" then
        for k, v in pairs(custom) do out[k] = v end
    end
    return out
end

local function parentOnTop(gui)
    gui.DisplayOrder = MAX_DISPLAY_ORDER
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local ok = pcall(function()
        if typeof(gethui) == "function" then
            gui.Parent = gethui()
        elseif syn and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
            gui.Parent = CoreGui
        else
            gui.Parent = CoreGui
        end
    end)
    if not ok or not gui.Parent then
        gui.Parent = PlayerGui or CoreGui
    end
end

function Library.new()
    return setmetatable({ _windows = {} }, Library)
end

function Library:CreateWindow(...)
    local args = { ... }
    local cfg
    if type(args[1]) == "table" then
        cfg = args[1]
    else
        cfg = {
            Title        = args[1],
            Footer       = args[2],
            CornerRadius = args[3],
        }
    end

    local title  = tostring(cfg.Title  or "Aurocode")
    local footer = tostring(cfg.Footer or "v1.0.0")
    local corner = tonumber(cfg.CornerRadius) or 10
    local dpi    = tonumber(cfg.DPIScale) or 1
    local size   = (typeof(cfg.Size) == "UDim2") and cfg.Size or UDim2.fromOffset(520, 300)
    local pos    = (typeof(cfg.Position) == "UDim2") and cfg.Position or UDim2.fromScale(0.5, 0.5)
    local draggable = (cfg.Draggable ~= false)
    local theme  = mergeTheme(cfg.Theme)

    local self = setmetatable({}, Window)
    self._maid  = Maid.new()
    self._theme = theme
    self._state = {
        Title        = title,
        Footer       = footer,
        Open         = true,
        Locked       = false,
        Maximized    = false,
        DPIScale     = dpi,
        CornerRadius = corner,
        Draggable    = draggable,
    }
    self._origSize = size
    self._origPos  = pos

    self.Toggled   = Signal.new()
    self.Closed    = Signal.new()
    self.Opened    = Signal.new()
    self.Locked    = Signal.new()
    self.Unlocked  = Signal.new()
    self.Maximized = Signal.new()
    self.Restored  = Signal.new()
    self.Destroyed = Signal.new()
    self._maid:Give(self.Toggled)
    self._maid:Give(self.Closed)
    self._maid:Give(self.Opened)
    self._maid:Give(self.Locked)
    self._maid:Give(self.Unlocked)
    self._maid:Give(self.Maximized)
    self._maid:Give(self.Restored)
    self._maid:Give(self.Destroyed)

    local screen = new("ScreenGui", { Name = "Aurocode_" .. tostring(math.random(100000, 999999)) })
    parentOnTop(screen)
    self._screen = screen
    self._maid:Give(screen)

    self._maid:Give(RunService.Heartbeat:Connect(function()
        if screen.DisplayOrder ~= MAX_DISPLAY_ORDER then
            screen.DisplayOrder = MAX_DISPLAY_ORDER
        end
    end))

    local rootScale = new("UIScale", { Scale = dpi })
    rootScale.Parent = screen
    self._scale = rootScale

    local main = new("CanvasGroup", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        Position = pos,
        Size = size,
        GroupTransparency = 0,
    })
    main.Parent = screen
    self._main = main

    self._rootCorner = new("UICorner", { CornerRadius = UDim.new(0, corner) })
    self._rootCorner.Parent = main

    new("UIStroke", {
        Color = theme.Divider,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }).Parent = main

    local header = new("Frame", {
        Name = "Header",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36),
    })
    header.Parent = main
    self._header = header

    self._headerCorner = new("UICorner", { CornerRadius = UDim.new(0, corner) })
    self._headerCorner.Parent = header

    new("Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0.5, 0),
    }).Parent = header

    new("Frame", {
        BackgroundColor3 = theme.Divider,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
    }).Parent = header

    local titleLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -128, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = title,
        TextColor3 = theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    titleLabel.Parent = header
    self._titleLabel = titleLabel

    local btnHolder = new("Frame", {
        Name = "Controls",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(108, 28),
    })
    btnHolder.Parent = header

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }).Parent = btnHolder

    local function makeIcon(name, asset, order, tint)
        local btn = new("ImageButton", {
            Name = name,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Image = asset,
            ImageColor3 = tint or theme.Text,
            Size = UDim2.fromOffset(22, 22),
            LayoutOrder = order,
        })
        btn.Parent = btnHolder
        return btn
    end

    local minBtn   = makeIcon("Minimize", ICONS.Minimize, 1, theme.SubText)
    local maxBtn   = makeIcon("Maximize", ICONS.Maximize, 2, theme.SubText)
    local closeBtn = makeIcon("Close",    ICONS.Close,    3, theme.SubText)

    local body = new("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 1, -60),
    })
    body.Parent = main
    self._body = body

    local content = new("ScrollingFrame", {
        Name = "Content",
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.Accent,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
    })
    content.Parent = body
    self._content = content

    new("UIPadding", {
        PaddingTop    = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft   = UDim.new(0, 12),
        PaddingRight  = UDim.new(0, 12),
    }).Parent = content

    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }).Parent = content

    local footerBar = new("Frame", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 24),
    })
    footerBar.Parent = main

    self._footerCorner = new("UICorner", { CornerRadius = UDim.new(0, corner) })
    self._footerCorner.Parent = footerBar

    new("Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0.5, 0),
    }).Parent = footerBar

    new("Frame", {
        BackgroundColor3 = theme.Divider,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
    }).Parent = footerBar

    local footerLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.Gotham,
        Text = footer,
        TextColor3 = theme.SubText,
        TextSize = 10,
    })
    footerLabel.Parent = footerBar
    self._footerLabel = footerLabel
    self._footerBar = footerBar

    local corner2 = new("Frame", {
        Name = "CornerControls",
        AnchorPoint = Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.fromOffset(160, 30),
    })
    corner2.Parent = screen
    self._cornerControls = corner2

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }).Parent = corner2

    local function makeCornerBtn(name, text, order)
        local b = new("TextButton", {
            Name = name,
            AutoButtonColor = false,
            BackgroundColor3 = theme.Surface,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(74, 28),
            Font = Enum.Font.GothamMedium,
            Text = text,
            TextColor3 = theme.Text,
            TextSize = 12,
            LayoutOrder = order,
        })
        new("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = b
        new("UIStroke", {
            Color = theme.Divider,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }).Parent = b
        b.Parent = corner2
        return b
    end

    local toggleBtn = makeCornerBtn("Toggle", "Toggle", 1)
    local lockBtn   = makeCornerBtn("Lock", "Lock", 2)
    self._toggleBtn = toggleBtn
    self._lockBtn = lockBtn

    local function fadeIcon(btn, target)
        TweenService:Create(
            btn,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = target }
        ):Play()
    end

    local function bindIconPress(btn, hoverColor, baseColor)
        self._maid:Give(btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                fadeIcon(btn, hoverColor)
            end
        end))
        self._maid:Give(btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                fadeIcon(btn, baseColor)
            end
        end))
    end

    bindIconPress(minBtn,   theme.Text,   theme.SubText)
    bindIconPress(maxBtn,   theme.Text,   theme.SubText)
    bindIconPress(closeBtn, theme.Danger, theme.SubText)

    self._maid:Give(closeBtn.MouseButton1Click:Connect(function()
        self:Destroy()
    end))
    self._maid:Give(minBtn.MouseButton1Click:Connect(function()
        self:Close()
    end))
    self._maid:Give(maxBtn.MouseButton1Click:Connect(function()
        self:ToggleMaximize()
    end))
    self._maid:Give(toggleBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end))
    self._maid:Give(lockBtn.MouseButton1Click:Connect(function()
        self:ToggleLock()
    end))

    do
        local dragging, dragInput, dragStart, startPos
        self._maid:Give(header.InputBegan:Connect(function(input)
            if not self._state.Draggable or self._state.Locked or self._state.Maximized then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                local conn
                conn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        if conn then conn:Disconnect() end
                    end
                end)
            end
        end))
        self._maid:Give(header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end))
        self._maid:Give(UserInputService.InputChanged:Connect(function(input)
            if dragging and input == dragInput then
                if self._state.Locked or self._state.Maximized or not self._state.Draggable then
                    dragging = false
                    return
                end
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
                if not self._state.Maximized then
                    self._origPos = main.Position
                end
            end
        end))
    end

    return self
end

function Window:SetDPIScale(n)
    n = tonumber(n) or 1
    if n < 0.25 then n = 0.25 end
    if n > 4 then n = 4 end
    self._state.DPIScale = n
    self._scale.Scale = n
    return self
end

function Window:SetCornerRadius(n)
    n = tonumber(n) or 0
    if n < 0 then n = 0 end
    self._state.CornerRadius = n
    local u = UDim.new(0, n)
    self._rootCorner.CornerRadius = u
    self._headerCorner.CornerRadius = u
    self._footerCorner.CornerRadius = u
    return self
end

function Window:SetTitle(s)
    s = tostring(s)
    self._state.Title = s
    self._titleLabel.Text = s
    return self
end

function Window:SetFooter(s)
    s = tostring(s)
    self._state.Footer = s
    self._footerLabel.Text = s
    return self
end

function Window:SetSize(sz)
    if typeof(sz) == "UDim2" then
        self._main.Size = sz
        if not self._state.Maximized then
            self._origSize = sz
        end
    end
    return self
end

function Window:SetPosition(p)
    if typeof(p) == "UDim2" then
        self._main.Position = p
        if not self._state.Maximized then
            self._origPos = p
        end
    end
    return self
end

function Window:SetDraggable(b)
    self._state.Draggable = b and true or false
    return self
end

function Window:SetTheme(t)
    if type(t) ~= "table" then return self end
    for k, v in pairs(t) do self._theme[k] = v end
    if t.Background then self._main.BackgroundColor3 = t.Background end
    if t.Surface then
        self._header.BackgroundColor3 = t.Surface
        self._footerBar.BackgroundColor3 = t.Surface
    end
    if t.Text then self._titleLabel.TextColor3 = t.Text end
    if t.SubText then self._footerLabel.TextColor3 = t.SubText end
    if t.Accent then self._content.ScrollBarImageColor3 = t.Accent end
    return self
end

function Window:GetState(key)
    if key == nil then
        local c = {}
        for k, v in pairs(self._state) do c[k] = v end
        return c
    end
    return self._state[key]
end

function Window:GetRoot()
    return self._screen
end

function Window:GetMain()
    return self._main
end

function Window:GetContent()
    return self._content
end

function Window:Toggle()
    if self._state.Open then self:Close() else self:Open() end
    return self
end

function Window:Close()
    if not self._state.Open then return self end
    self._state.Open = false
    self._main.Visible = false
    self.Closed:Fire()
    self.Toggled:Fire(false)
    return self
end

function Window:Open()
    if self._state.Open then return self end
    self._state.Open = true
    self._main.Visible = true
    self.Opened:Fire()
    self.Toggled:Fire(true)
    return self
end

function Window:Lock()
    if self._state.Locked then return self end
    self._state.Locked = true
    if self._lockBtn then self._lockBtn.Text = "Unlock" end
    self.Locked:Fire()
    return self
end

function Window:Unlock()
    if not self._state.Locked then return self end
    self._state.Locked = false
    if self._lockBtn then self._lockBtn.Text = "Lock" end
    self.Unlocked:Fire()
    return self
end

function Window:ToggleLock()
    if self._state.Locked then self:Unlock() else self:Lock() end
    return self
end

function Window:Maximize()
    if self._state.Maximized then return self end
    self._state.Maximized = true
    self._origSize = self._main.Size
    self._origPos  = self._main.Position
    self._main.Position = UDim2.fromScale(0.5, 0.5)
    self._main.Size = UDim2.new(1, -24, 1, -24)
    self.Maximized:Fire()
    return self
end

function Window:Restore()
    if not self._state.Maximized then return self end
    self._state.Maximized = false
    self._main.Size = self._origSize
    self._main.Position = self._origPos
    self.Restored:Fire()
    return self
end

function Window:ToggleMaximize()
    if self._state.Maximized then self:Restore() else self:Maximize() end
    return self
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self.Destroyed:Fire()
    self._maid:Clean()
end

return setmetatable({}, {
    __index = Library,
    __call = function(_, ...) return Library:CreateWindow(...) end,
})
