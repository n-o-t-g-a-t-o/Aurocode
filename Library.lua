local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local cloneref = cloneref or function(x) return x end
local gethui = gethui
local syn = syn

local function getService(name)
    return cloneref(game:GetService(name))
end

local function getHui()
    if type(gethui) == "function" then
        local ok, res = pcall(gethui)
        if ok and typeof(res) == "Instance" then return res end
    end
    local ok, cg = pcall(function() return getService("CoreGui") end)
    if ok and typeof(cg) == "Instance" then return cg end
    error("[Auro]: No UI Found :(")
end

local function protectGui(gui)
    if syn and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    end
end

local UserInputService = getService("UserInputService")
local TweenService     = getService("TweenService")
local RunService       = getService("RunService")

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

local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do inst[k] = v end
    end
    return inst
end

local function mergeTheme(custom)
    local out = {
        Background = Color3.fromRGB(18, 18, 22),
        Surface    = Color3.fromRGB(26, 26, 32),
        Accent     = Color3.fromRGB(120, 90, 255),
        Text       = Color3.fromRGB(235, 235, 240),
        SubText    = Color3.fromRGB(150, 150, 160),
        Divider    = Color3.fromRGB(40, 40, 48),
        Danger     = Color3.fromRGB(220, 60, 80),
    }
    if type(custom) == "table" then
        for k, v in pairs(custom) do out[k] = v end
    end
    return out
end

local function bindDrag(maid, handle, target, getLocked)
    local dragging, dragInput, dragStart, startPos
    maid:Give(handle.InputBegan:Connect(function(input)
        if getLocked() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end))
    maid:Give(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            if getLocked() then
                dragging = false
                return
            end
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
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
        cfg = { Title = args[1], Footer = args[2], CornerRadius = args[3] }
    end

    local theme = mergeTheme(cfg.Theme)
    local self = setmetatable({}, Window)
    self._maid  = Maid.new()
    self._theme = theme
    self._state = {
        Title        = tostring(cfg.Title or "Aurocode"),
        Footer       = tostring(cfg.Footer or "v1.0.0"),
        Open         = true,
        Locked       = false,
        Maximized    = false,
        DPIScale     = tonumber(cfg.DPIScale) or 1,
        CornerRadius = tonumber(cfg.CornerRadius) or 10,
        Draggable    = (cfg.Draggable ~= false),
    }
    self._origSize = (typeof(cfg.Size) == "UDim2") and cfg.Size or UDim2.fromOffset(520, 300)
    self._origPos  = (typeof(cfg.Position) == "UDim2") and cfg.Position or UDim2.fromScale(0.5, 0.5)

    self.Toggled     = Signal.new()
    self.Closed      = Signal.new()
    self.Opened      = Signal.new()
    self.Locked      = Signal.new()
    self.Unlocked    = Signal.new()
    self.Maximized   = Signal.new()
    self.Restored    = Signal.new()
    self.Destroyed   = Signal.new()
    self._destroyCbs = {}

    self._maid:Give(self.Toggled)
    self._maid:Give(self.Closed)
    self._maid:Give(self.Opened)
    self._maid:Give(self.Locked)
    self._maid:Give(self.Unlocked)
    self._maid:Give(self.Maximized)
    self._maid:Give(self.Restored)
    self._maid:Give(self.Destroyed)

    local screen = new("ScreenGui", {
        Name = "Aurocode_" .. tostring(math.random(100000, 999999)),
        IgnoreGuiInset = true,
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 2147483647,
    })
    protectGui(screen)
    screen.Parent = getHui()
    self._screen = screen
    self._maid:Give(screen)

    self._maid:Give(RunService.Heartbeat:Connect(function()
        if screen.DisplayOrder ~= 2147483647 then
            screen.DisplayOrder = 2147483647
        end
    end))

    self._scale = new("UIScale", { Scale = self._state.DPIScale })
    self._scale.Parent = screen

    local main = new("CanvasGroup", {
        Name = "Main",
        AnchorPoint       = Vector2.new(0.5, 0.5),
        BackgroundColor3  = theme.Background,
        BorderSizePixel   = 0,
        Position          = self._origPos,
        Size              = self._origSize,
        GroupTransparency = 0,
    })
    main.Parent = screen
    self._main = main

    self._rootCorner = new("UICorner", { CornerRadius = UDim.new(0, self._state.CornerRadius) })
    self._rootCorner.Parent = main

    do
        local stroke = new("UIStroke", {
            Color = theme.Divider,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        stroke.Parent = main
    end

    local header = new("Frame", {
        Name = "Header",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 32),
    })
    header.Parent = main
    self._header = header

    self._headerCorner = new("UICorner", { CornerRadius = UDim.new(0, self._state.CornerRadius) })
    self._headerCorner.Parent = header

    do
        local bottom = new("Frame", {
            BackgroundColor3 = theme.Surface,
            BorderSizePixel  = 0,
            Position         = UDim2.new(0, 0, 0.5, 0),
            Size             = UDim2.new(1, 0, 0.5, 0),
        })
        bottom.Parent = header

        local sep = new("Frame", {
            BackgroundColor3 = theme.Divider,
            BorderSizePixel  = 0,
            Position         = UDim2.new(0, 0, 1, -1),
            Size             = UDim2.new(1, 0, 0, 1),
        })
        sep.Parent = header
    end

    self._titleLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position      = UDim2.new(0, 12, 0, 0),
        Size          = UDim2.new(1, -96, 1, 0),
        Font          = Enum.Font.GothamMedium,
        Text          = self._state.Title,
        TextColor3    = theme.Text,
        TextSize      = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate   = Enum.TextTruncate.AtEnd,
    })
    self._titleLabel.Parent = header

    local controls = new("Frame", {
        Name = "Controls",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(76, 20),
    })
    controls.Parent = header

    do
        local layout = new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        layout.Parent = controls
    end

    local function makeIcon(name, asset, order)
        local btn = new("ImageButton", {
            Name = name,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Image = asset,
            ImageColor3 = theme.SubText,
            Size = UDim2.fromOffset(16, 16),
            LayoutOrder = order,
        })
        btn.Parent = controls
        return btn
    end

    local minBtn   = makeIcon("Minimize", "rbxassetid://82909496983440", 1)
    local maxBtn   = makeIcon("Maximize", "rbxassetid://84623133872179", 2)
    local closeBtn = makeIcon("Close",    "rbxassetid://100928939627907", 3)

    local body = new("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 32),
        Size     = UDim2.new(1, 0, 1, -56),
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

    do
        local pad = new("UIPadding", {
            PaddingTop    = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft   = UDim.new(0, 12),
            PaddingRight  = UDim.new(0, 12),
        })
        pad.Parent = content

        local layout = new("UIListLayout", {
            Padding   = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        layout.Parent = content
    end

    local footerBar = new("Frame", {
        Name = "Footer",
        AnchorPoint      = Vector2.new(0, 1),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 24),
    })
    footerBar.Parent = main
    self._footerBar = footerBar

    self._footerCorner = new("UICorner", { CornerRadius = UDim.new(0, self._state.CornerRadius) })
    self._footerCorner.Parent = footerBar

    do
        local top = new("Frame", {
            BackgroundColor3 = theme.Surface,
            BorderSizePixel  = 0,
            Size             = UDim2.new(1, 0, 0.5, 0),
        })
        top.Parent = footerBar

        local sep = new("Frame", {
            BackgroundColor3 = theme.Divider,
            BorderSizePixel  = 0,
            Size             = UDim2.new(1, 0, 0, 1),
        })
        sep.Parent = footerBar
    end

    self._footerLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size        = UDim2.fromScale(1, 1),
        Font        = Enum.Font.Gotham,
        Text        = self._state.Footer,
        TextColor3  = theme.SubText,
        TextSize    = 10,
    })
    self._footerLabel.Parent = footerBar

    local cornerControls = new("Frame", {
        Name = "CornerControls",
        AnchorPoint = Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.fromOffset(80, 66),
        Active = true,
    })
    cornerControls.Parent = screen
    self._cornerControls = cornerControls

    do
        local layout = new("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        layout.Parent = cornerControls
    end

    local function makeCornerBtn(name, text, order)
        local b = new("TextButton", {
            Name = name,
            AutoButtonColor  = false,
            BackgroundColor3 = theme.Surface,
            BorderSizePixel  = 0,
            Size = UDim2.fromOffset(80, 30),
            Font = Enum.Font.GothamMedium,
            Text = text,
            TextColor3 = theme.Text,
            TextSize = 12,
            LayoutOrder = order,
            Active = true,
        })
        local c = new("UICorner", { CornerRadius = UDim.new(0, 6) })
        c.Parent = b
        local s = new("UIStroke", {
            Color = theme.Divider,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        s.Parent = b
        b.Parent = cornerControls
        return b
    end

    self._toggleBtn = makeCornerBtn("Toggle", "Toggle", 1)
    self._lockBtn   = makeCornerBtn("Lock",   "Lock",   2)

    local function bindIconPress(btn, hoverColor, baseColor)
        local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        self._maid:Give(btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                TweenService:Create(btn, info, { ImageColor3 = hoverColor }):Play()
            end
        end))
        self._maid:Give(btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                TweenService:Create(btn, info, { ImageColor3 = baseColor }):Play()
            end
        end))
    end

    bindIconPress(minBtn,   theme.Text,   theme.SubText)
    bindIconPress(maxBtn,   theme.Text,   theme.SubText)
    bindIconPress(closeBtn, theme.Danger, theme.SubText)

    self._maid:Give(closeBtn.MouseButton1Click:Connect(function() self:Destroy() end))
    self._maid:Give(minBtn.MouseButton1Click:Connect(function() self:Close() end))
    self._maid:Give(maxBtn.MouseButton1Click:Connect(function() self:ToggleMaximize() end))
    self._maid:Give(self._toggleBtn.MouseButton1Click:Connect(function() self:Toggle() end))
    self._maid:Give(self._lockBtn.MouseButton1Click:Connect(function() self:ToggleLock() end))

    bindDrag(self._maid, header, main, function()
        return self._state.Locked or self._state.Maximized or not self._state.Draggable
    end)
    bindDrag(self._maid, cornerControls, cornerControls, function()
        return self._state.Locked
    end)

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

function Window:GetRoot()    return self._screen  end
function Window:GetMain()    return self._main    end
function Window:GetContent() return self._content end

function Window:Toggle()
    if self._state.Open then self:Close() else self:Open() end
    return self
end

function Window:Close()
    if not self._state.Open then return self end
    self._state.Open = false
    local tween = TweenService:Create(
        self._main,
        TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { GroupTransparency = 1 }
    )
    tween:Play()
    tween.Completed:Once(function()
        if not self._state.Open then
            self._main.Visible = false
        end
    end)
    self.Closed:Fire()
    self.Toggled:Fire(false)
    return self
end

function Window:Open()
    if self._state.Open then return self end
    self._state.Open = true
    self._main.GroupTransparency = 1
    self._main.Visible = true
    TweenService:Create(
        self._main,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { GroupTransparency = 0 }
    ):Play()
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
    TweenService:Create(
        self._main,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromScale(0.5, 0.5) }
    ):Play()
    self.Maximized:Fire()
    return self
end

function Window:Restore()
    if not self._state.Maximized then return self end
    self._state.Maximized = false
    TweenService:Create(
        self._main,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = self._origSize, Position = self._origPos }
    ):Play()
    self.Restored:Fire()
    return self
end

function Window:ToggleMaximize()
    if self._state.Maximized then self:Restore() else self:Maximize() end
    return self
end

function Window:OnDestroy(fn)
    if type(fn) ~= "function" then return self end
    self._destroyCbs[#self._destroyCbs + 1] = fn
    return self
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    for _, fn in ipairs(self._destroyCbs) do
        task.spawn(function() pcall(fn) end)
    end
    self.Destroyed:Fire()
    self._maid:Clean()
end

return setmetatable({}, {
    __index = Library,
    __call = function(_, ...) return Library:CreateWindow(...) end,
})
