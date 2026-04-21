local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local function cloneref(inst)
    if typeof(inst) ~= "Instance" then return inst end
    local ok, fn = pcall(function() return rawget(getfenv(0), "cloneref") end)
    if ok and type(fn) == "function" then
        local success, res = pcall(fn, inst)
        if success and typeof(res) == "Instance" then
            return res
        end
    end
    return inst
end

local function service(name)
    return cloneref(game:GetService(name))
end

local function getHui()
    local ok, fn = pcall(function() return rawget(getfenv(0), "gethui") end)
    if ok and type(fn) == "function" then
        local s, res = pcall(fn)
        if s and typeof(res) == "Instance" then return res end
    end
    local s, cg = pcall(service, "CoreGui")
    if s and typeof(cg) == "Instance" then return cg end
    error("[Auro]: No UI Found :(")
end

local UIS = service("UserInputService")
local TS  = service("TweenService")
local RS  = service("RunService")

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _t = {} }, Maid)
end

function Maid:Give(t)
    self._t[#self._t + 1] = t
    return t
end

function Maid:Clean()
    for i = #self._t, 1, -1 do
        local t = self._t[i]
        self._t[i] = nil
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

local function child(parent, class, props)
    local i = new(class, props)
    i.Parent = parent
    return i
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

local function tween(inst, t, goal)
    return TS:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
end

local function bindDrag(maid, handle, target, isBlocked)
    local dragging, dragInput, dragStart, startPos
    maid:Give(handle.InputBegan:Connect(function(input)
        if isBlocked() then return end
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
    maid:Give(UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            if isBlocked() then dragging = false return end
            local d = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
end

local function bindHover(maid, btn, prop, baseColor, hoverColor)
    maid:Give(btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tween(btn, 0.12, { [prop] = hoverColor }):Play()
        end
    end))
    maid:Give(btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tween(btn, 0.12, { [prop] = baseColor }):Play()
        end
    end))
end

function Library.new()
    return setmetatable({}, Library)
end

function Library:CreateWindow(...)
    local a = { ... }
    local cfg = (type(a[1]) == "table") and a[1] or { Title = a[1], Footer = a[2], CornerRadius = a[3] }

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
    self._destroyCbs = {}

    self.Toggled   = self._maid:Give(Signal.new())
    self.Closed    = self._maid:Give(Signal.new())
    self.Opened    = self._maid:Give(Signal.new())
    self.Locked    = self._maid:Give(Signal.new())
    self.Unlocked  = self._maid:Give(Signal.new())
    self.Maximized = self._maid:Give(Signal.new())
    self.Restored  = self._maid:Give(Signal.new())
    self.Destroyed = self._maid:Give(Signal.new())

    local screen = new("ScreenGui", {
        Name           = "Aurocode_" .. tostring(math.random(100000, 999999)),
        IgnoreGuiInset = true,
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 2147483647,
    })
    screen.Parent = getHui()
    self._screen = screen
    self._maid:Give(screen)

    self._maid:Give(RS.Heartbeat:Connect(function()
        if screen.DisplayOrder ~= 2147483647 then
            screen.DisplayOrder = 2147483647
        end
    end))

    self._scale = child(screen, "UIScale", { Scale = self._state.DPIScale })

    local main = child(screen, "CanvasGroup", {
        Name              = "Main",
        AnchorPoint       = Vector2.new(0.5, 0.5),
        BackgroundColor3  = theme.Background,
        BorderSizePixel   = 0,
        Position          = self._origPos,
        Size              = self._origSize,
        GroupTransparency = 0,
    })
    self._main = main

    self._rootCorner = child(main, "UICorner", { CornerRadius = UDim.new(0, self._state.CornerRadius) })
    child(main, "UIStroke", {
        Color = theme.Divider,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local header = child(main, "Frame", {
        Name = "Header",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 32),
    })
    self._header = header
    self._headerCorner = child(header, "UICorner", { CornerRadius = UDim.new(0, self._state.CornerRadius) })
    child(header, "Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0.5, 0),
        Size             = UDim2.new(1, 0, 0.5, 0),
    })
    child(header, "Frame", {
        BackgroundColor3 = theme.Divider,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 1, -1),
        Size             = UDim2.new(1, 0, 0, 1),
    })

    self._titleLabel = child(header, "TextLabel", {
        BackgroundTransparency = 1,
        Position       = UDim2.new(0, 12, 0, 0),
        Size           = UDim2.new(1, -96, 1, 0),
        Font           = Enum.Font.GothamMedium,
        Text           = self._state.Title,
        TextColor3     = theme.Text,
        TextSize       = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate   = Enum.TextTruncate.AtEnd,
    })

    local controls = child(header, "Frame", {
        Name = "Controls",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(76, 20),
    })
    child(controls, "UIListLayout", {
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 6),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })

    local function icon(name, asset, order)
        return child(controls, "ImageButton", {
            Name = name,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Image = asset,
            ImageColor3 = theme.SubText,
            Size = UDim2.fromOffset(16, 16),
            LayoutOrder = order,
        })
    end

    local minBtn   = icon("Minimize", "rbxassetid://82909496983440", 1)
    local maxBtn   = icon("Maximize", "rbxassetid://84623133872179", 2)
    local closeBtn = icon("Close",    "rbxassetid://100928939627907", 3)

    local body = child(main, "Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 32),
        Size     = UDim2.new(1, 0, 1, -56),
    })
    self._body = body

    local content = child(body, "ScrollingFrame", {
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
    self._content = content
    child(content, "UIPadding", {
        PaddingTop    = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft   = UDim.new(0, 12),
        PaddingRight  = UDim.new(0, 12),
    })
    child(content, "UIListLayout", {
        Padding   = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local footerBar = child(main, "Frame", {
        Name = "Footer",
        AnchorPoint      = Vector2.new(0, 1),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 24),
    })
    self._footerBar = footerBar
    self._footerCorner = child(footerBar, "UICorner", { CornerRadius = UDim.new(0, self._state.CornerRadius) })
    child(footerBar, "Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0.5, 0),
    })
    child(footerBar, "Frame", {
        BackgroundColor3 = theme.Divider,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 1),
    })
    self._footerLabel = child(footerBar, "TextLabel", {
        BackgroundTransparency = 1,
        Size       = UDim2.fromScale(1, 1),
        Font       = Enum.Font.Gotham,
        Text       = self._state.Footer,
        TextColor3 = theme.SubText,
        TextSize   = 10,
    })

    local cc = child(screen, "Frame", {
        Name = "CornerControls",
        AnchorPoint = Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 12),
        Size = UDim2.fromOffset(110, 96),
        Active = true,
    })
    self._cornerControls = cc
    child(cc, "UIListLayout", {
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment   = Enum.VerticalAlignment.Top,
        Padding             = UDim.new(0, 8),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })

    local function flatBtn(name, text, order)
        return child(cc, "TextButton", {
            Name = name,
            AutoButtonColor        = false,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Size                   = UDim2.fromOffset(110, 42),
            Font                   = Enum.Font.GothamBold,
            Text                   = text,
            TextColor3             = theme.Text,
            TextSize               = 18,
            TextXAlignment         = Enum.TextXAlignment.Left,
            LayoutOrder            = order,
            Active                 = true,
        })
    end

    self._toggleBtn = flatBtn("Toggle", "Toggle", 1)
    self._lockBtn   = flatBtn("Lock",   "Lock",   2)

    bindHover(self._maid, minBtn,   "ImageColor3", theme.SubText, theme.Text)
    bindHover(self._maid, maxBtn,   "ImageColor3", theme.SubText, theme.Text)
    bindHover(self._maid, closeBtn, "ImageColor3", theme.SubText, theme.Danger)
    bindHover(self._maid, self._toggleBtn, "TextColor3", theme.Text, theme.Accent)
    bindHover(self._maid, self._lockBtn,   "TextColor3", theme.Text, theme.Accent)

    self._maid:Give(closeBtn.MouseButton1Click:Connect(function() self:Destroy() end))
    self._maid:Give(minBtn.MouseButton1Click:Connect(function() self:Close() end))
    self._maid:Give(maxBtn.MouseButton1Click:Connect(function() self:ToggleMaximize() end))
    self._maid:Give(self._toggleBtn.MouseButton1Click:Connect(function() self:Toggle() end))
    self._maid:Give(self._lockBtn.MouseButton1Click:Connect(function() self:ToggleLock() end))

    bindDrag(self._maid, header, main, function()
        return self._state.Locked or self._state.Maximized or not self._state.Draggable
    end)
    bindDrag(self._maid, cc, cc, function()
        return self._state.Locked
    end)

    return self
end

function Window:SetDPIScale(n)
    n = tonumber(n) or 1
    if n < 0.25 then n = 0.25 elseif n > 4 then n = 4 end
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
        if not self._state.Maximized then self._origSize = sz end
    end
    return self
end

function Window:SetPosition(p)
    if typeof(p) == "UDim2" then
        self._main.Position = p
        if not self._state.Maximized then self._origPos = p end
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
    local t = tween(self._main, 0.18, { GroupTransparency = 1 })
    t:Play()
    t.Completed:Once(function()
        if not self._state.Open then self._main.Visible = false end
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
    tween(self._main, 0.2, { GroupTransparency = 0 }):Play()
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
    tween(self._main, 0.2, {
        Size     = UDim2.new(1, -24, 1, -24),
        Position = UDim2.fromScale(0.5, 0.5),
    }):Play()
    self.Maximized:Fire()
    return self
end

function Window:Restore()
    if not self._state.Maximized then return self end
    self._state.Maximized = false
    tween(self._main, 0.2, { Size = self._origSize, Position = self._origPos }):Play()
    self.Restored:Fire()
    return self
end

function Window:ToggleMaximize()
    if self._state.Maximized then self:Restore() else self:Maximize() end
    return self
end

function Window:OnDestroy(fn)
    if type(fn) == "function" then
        self._destroyCbs[#self._destroyCbs + 1] = fn
    end
    return self
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    for _, fn in ipairs(self._destroyCbs) do
        task.spawn(function() pcall(fn) end)
    end
    self.Destroyed:Fire()
    tween(self._main, 0.15, { GroupTransparency = 1 }):Play()
    task.delay(0.16, function() self._maid:Clean() end)
end

return setmetatable({}, {
    __index = Library,
    __call = function(_, ...) return Library:CreateWindow(...) end,
})
