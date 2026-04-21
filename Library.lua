local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local function cloneref(inst)
    if typeof(inst) ~= "Instance" then return inst end
    local ok, fn = pcall(function() return rawget(getfenv(0), "cloneref") end)
    if ok and type(fn) == "function" then
        local s, r = pcall(fn, inst)
        if s and typeof(r) == "Instance" then return r end
    end
    return inst
end

local function service(name)
    return cloneref(game:GetService(name))
end

local function getHui()
    local ok, fn = pcall(function() return rawget(getfenv(0), "gethui") end)
    if ok and type(fn) == "function" then
        local s, r = pcall(fn)
        if s and typeof(r) == "Instance" then return r end
    end
    local s, cg = pcall(service, "CoreGui")
    if s and typeof(cg) == "Instance" then return cg end
    error("[Auro]: No UI Found :(")
end

local UIS = service("UserInputService")
local TS = service("TweenService")
local RS = service("RunService")

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
                if v == fn then
                    table.remove(h, i)
                    break
                end
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
        for k, v in pairs(props) do
            inst[k] = v
        end
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
        Surface = Color3.fromRGB(26, 26, 32),
        Accent = Color3.fromRGB(120, 90, 255),
        Text = Color3.fromRGB(235, 235, 240),
        SubText = Color3.fromRGB(150, 150, 160),
        Divider = Color3.fromRGB(40, 40, 48),
        Danger = Color3.fromRGB(220, 60, 80),
    }
    if type(custom) == "table" then
        for k, v in pairs(custom) do
            out[k] = v
        end
    end
    return out
end

local function tween(inst, t, goal, style, dir)
    return TS:Create(
        inst,
        TweenInfo.new(t, style or Enum.EasingStyle.Cubic, dir or Enum.EasingDirection.Out),
        goal
    )
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

local function bindHover(maid, btn, prop, base, hover)
    maid:Give(btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tween(btn, 0.18, { [prop] = hover }):Play()
        end
    end))
    maid:Give(btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tween(btn, 0.18, { [prop] = base }):Play()
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
    self._maid = Maid.new()
    self._theme = theme
    self._state = {
        Title = tostring(cfg.Title or "Aurocode"),
        Footer = tostring(cfg.Footer or "v1.0.0"),
        Open = true,
        Locked = false,
        Maximized = false,
        DPIScale = tonumber(cfg.DPIScale) or 1,
        CornerRadius = tonumber(cfg.CornerRadius) or 10,
        Draggable = (cfg.Draggable ~= false),
    }
    self._origSize = (typeof(cfg.Size) == "UDim2") and cfg.Size or UDim2.fromOffset(520, 300)
    self._origPos = (typeof(cfg.Position) == "UDim2") and cfg.Position or UDim2.fromScale(0.5, 0.5)
    self._destroyCbs = {}
    self._textboxes = {}

    self.Toggled = self._maid:Give(Signal.new())
    self.Closed = self._maid:Give(Signal.new())
    self.Opened = self._maid:Give(Signal.new())
    self.Locked = self._maid:Give(Signal.new())
    self.Unlocked = self._maid:Give(Signal.new())
    self.Maximized = self._maid:Give(Signal.new())
    self.Restored = self._maid:Give(Signal.new())
    self.Destroyed = self._maid:Give(Signal.new())

    local screen = new("ScreenGui", {
        Name = "Aurocode",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 2147483647,
    })
    screen.Parent = getHui()
    self._screen = screen
    self._maid:Give(screen)

    self._maid:Give(RS.Heartbeat:Connect(function()
        if screen.DisplayOrder ~= 2147483647 then
            screen.DisplayOrder = 2147483647
        end
    end))

    local function cornerBtn(name, text, order)
        local b = child(screen, "TextButton", {
            Name = name,
            AutoButtonColor = false,
            BackgroundColor3 = theme.Surface,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0),
            Size = UDim2.fromOffset(96, 34),
            Font = Enum.Font.GothamBold,
            Text = text,
            TextColor3 = theme.Text,
            TextSize = 14,
            Active = true,
            LayoutOrder = order,
        })
        child(b, "UICorner", { Name = "Auro@Corner", CornerRadius = UDim.new(0, 8) })
        child(b, "UIStroke", {
            Name = "Auro@Stroke",
            Color = theme.Divider,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        return b
    end

    self._toggleBtn = cornerBtn("Auro@Toggle", "Toggle", 1)
    self._lockBtn = cornerBtn("Auro@Lock", "Lock", 2)
    self._toggleBtn.Position = UDim2.fromOffset(12, 12)
    self._lockBtn.Position = UDim2.fromOffset(12, 54)

    local main = child(screen, "Frame", {
        Name = "Main@Auro",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = self._origPos,
        Size = self._origSize,
        ClipsDescendants = false,
        Visible = true,
    })
    self._main = main

    self._mainCorner = child(main, "UICorner", {
        Name = "Auro@Corner",
        CornerRadius = UDim.new(0, self._state.CornerRadius),
    })
    self._mainStroke = child(main, "UIStroke", {
        Name = "Auro@Stroke",
        Color = theme.Divider,
        Thickness = 1,
        Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    self._uiScale = child(main, "UIScale", {
        Name = "Auro@Scale",
        Scale = self._state.DPIScale * 0.8,
    })

    local contentGroup = child(main, "CanvasGroup", {
        Name = "Auro@ContentGroup",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1,
    })
    self._contentGroup = contentGroup

    local headerHeight = 40
    local footerHeight = 24

    local header = child(contentGroup, "Frame", {
        Name = "Auro@Header",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, headerHeight),
    })
    self._header = header
    self._headerCorner = child(header, "UICorner", {
        Name = "Auro@Corner",
        CornerRadius = UDim.new(0, self._state.CornerRadius),
    })
    child(header, "Frame", {
        Name = "Frame@Frame",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0.5, 0),
    })
    child(header, "Frame", {
        Name = "Frame@Frame_2",
        BackgroundColor3 = theme.Divider,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
    })

    self._titleLabel = child(header, "TextLabel", {
        Name = "Auro@Title",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -136, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = self._state.Title,
        TextColor3 = theme.Text,
        TextSize = 14,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local controls = child(header, "Frame", {
        Name = "Auro@Controls",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(128, 22),
    })
    child(controls, "UIListLayout", {
        Name = "Auro@Layout",
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 14),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local function icon(name, asset, order)
        return child(controls, "ImageButton", {
            Name = name,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Image = asset,
            ImageColor3 = theme.SubText,
            Size = UDim2.fromOffset(18, 18),
            LayoutOrder = order,
        })
    end

    local addBtn = icon("Auro@AddTextbox", "rbxassetid://91408778765512", 1)
    local minBtn = icon("Auro@Minimize", "rbxassetid://82909496983440", 2)
    local maxBtn = icon("Auro@Maximize", "rbxassetid://84623133872179", 3)
    local closeBtn = icon("Auro@Close", "rbxassetid://100928939627907", 4)

    local body = child(contentGroup, "Frame", {
        Name = "Auro@Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, headerHeight),
        Size = UDim2.new(1, 0, 1, -(headerHeight + footerHeight)),
    })
    self._body = body

    local content = child(body, "ScrollingFrame", {
        Name = "Auro@Content",
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
        Name = "Auro@Padding",
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    })
    child(content, "UIListLayout", {
        Name = "Auro@Layout",
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local footerBar = child(contentGroup, "Frame", {
        Name = "Auro@Footer",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, footerHeight),
    })
    self._footerBar = footerBar
    self._footerCorner = child(footerBar, "UICorner", {
        Name = "Auro@Corner",
        CornerRadius = UDim.new(0, self._state.CornerRadius),
    })
    child(footerBar, "Frame", {
        Name = "Frame@Frame",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0.5, 0),
    })
    child(footerBar, "Frame", {
        Name = "Frame@Frame_2",
        BackgroundColor3 = theme.Divider,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
    })
    self._footerLabel = child(footerBar, "TextLabel", {
        Name = "Auro@Label",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.Gotham,
        Text = self._state.Footer,
        TextColor3 = theme.SubText,
        TextSize = 10,
    })

    local searchOverlay
    local searchBackdrop
    local searchBox
    local searchClosing = false

    local function closeSearch()
        if searchClosing then return end
        if not searchOverlay or not searchOverlay.Parent then return end
        searchClosing = true

        local t1 = tween(searchBackdrop, 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        local t2 = tween(searchBox, 0.35, { Size = UDim2.new(0, 0, 0.15, 0) }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

        t1:Play()
        t2:Play()

        t2.Completed:Once(function()
            if searchOverlay and searchOverlay.Parent then
                searchOverlay:Destroy()
            end
            searchOverlay = nil
            searchBackdrop = nil
            searchBox = nil
            searchClosing = false
        end)
    end

    local function openSearch()
        if searchOverlay and searchOverlay.Parent then
            if searchBox then
                pcall(function()
                    searchBox:CaptureFocus()
                end)
            end
            return
        end

        searchClosing = false

        searchOverlay = child(contentGroup, "Frame", {
            Name = "Auro@SearchOverlay",
            BackgroundTransparency = 1,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromScale(0, 0),
            ZIndex = 1000,
        })

        searchBackdrop = child(searchOverlay, "Frame", {
            Name = "Auro@SearchBackdrop",
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromScale(0, 0),
            ZIndex = 1001,
        })

        searchBox = child(searchOverlay, "TextBox", {
            Name = "Search",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = theme.Surface,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 0, 0.15, 0),
            ZIndex = 1002,
            ClearTextOnFocus = false,
            Text = "",
            PlaceholderText = "Enter Your Search Query...",
            Font = Enum.Font.Gotham,
            TextColor3 = theme.Text,
            PlaceholderColor3 = theme.SubText,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ClipsDescendants = true,
        })

        child(searchBox, "UICorner", {
            Name = "Auro@Corner",
            CornerRadius = UDim.new(0, 8),
        })
        child(searchBox, "UIStroke", {
            Name = "Auro@Stroke",
            Color = theme.Divider,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        child(searchBox, "UIPadding", {
            Name = "Auro@Padding",
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        })

        self._maid:Give(searchOverlay)
        self._maid:Give(searchBackdrop)
        self._maid:Give(searchBox)

        tween(searchBackdrop, 0.35, { BackgroundTransparency = 0.55 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
        tween(searchBox, 0.35, { Size = UDim2.new(0.6, 0, 0.15, 0) }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()

        searchBox.FocusLost:Connect(function()
            closeSearch()
        end)

        task.defer(function()
            if searchBox and searchBox.Parent then
                pcall(function()
                    searchBox:CaptureFocus()
                end)
            end
        end)
    end

    bindHover(self._maid, addBtn, "ImageColor3", theme.SubText, theme.Text)
    bindHover(self._maid, minBtn, "ImageColor3", theme.SubText, theme.Text)
    bindHover(self._maid, maxBtn, "ImageColor3", theme.SubText, theme.Text)
    bindHover(self._maid, closeBtn, "ImageColor3", theme.SubText, theme.Danger)
    bindHover(self._maid, self._toggleBtn, "BackgroundColor3", theme.Surface, theme.Divider)
    bindHover(self._maid, self._lockBtn, "BackgroundColor3", theme.Surface, theme.Divider)

    self._maid:Give(addBtn.MouseButton1Click:Connect(function()
        openSearch()
    end))
    self._maid:Give(closeBtn.MouseButton1Click:Connect(function() self:Destroy() end))
    self._maid:Give(minBtn.MouseButton1Click:Connect(function() self:Close() end))
    self._maid:Give(maxBtn.MouseButton1Click:Connect(function() self:ToggleMaximize() end))
    self._maid:Give(self._toggleBtn.MouseButton1Click:Connect(function() self:Toggle() end))
    self._maid:Give(self._lockBtn.MouseButton1Click:Connect(function() self:ToggleLock() end))

    bindDrag(self._maid, header, main, function()
        return self._state.Locked or self._state.Maximized or not self._state.Draggable
    end)
    bindDrag(self._maid, self._toggleBtn, self._toggleBtn, function() return self._state.Locked end)
    bindDrag(self._maid, self._lockBtn, self._lockBtn, function() return self._state.Locked end)

    self:_playOpen(true)

    return self
end

function Window:_playOpen(initial)
    local dpi = self._state.DPIScale
    self._uiScale.Scale = dpi * 0.8
    if initial then
        self._main.BackgroundTransparency = 1
        self._mainStroke.Transparency = 1
        self._contentGroup.GroupTransparency = 1
    end
    self._main.Visible = true
    tween(self._main, 0.37, { BackgroundTransparency = 0 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
    tween(self._mainStroke, 0.37, { Transparency = 0 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
    tween(self._contentGroup, 0.37, { GroupTransparency = 0 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
    tween(self._uiScale, 0.37, { Scale = dpi }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
end

function Window:_playClose(after)
    local dpi = self._state.DPIScale
    local t1 = tween(self._main, 0.33, { BackgroundTransparency = 1 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local t2 = tween(self._mainStroke, 0.33, { Transparency = 1 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local t3 = tween(self._contentGroup, 0.33, { GroupTransparency = 1 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local t4 = tween(self._uiScale, 0.33, { Scale = dpi * 0.8 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    t1:Play()
    t2:Play()
    t3:Play()
    t4:Play()
    t1.Completed:Once(function()
        if not self._state.Open then
            self._main.Visible = false
            if type(after) == "function" then after() end
        end
    end)
end

function Window:SetDPIScale(n)
    n = tonumber(n) or 1
    if n < 0.25 then n = 0.25 elseif n > 4 then n = 4 end
    self._state.DPIScale = n
    self._uiScale.Scale = n * (self._state.Open and 1 or 0.8)
    return self
end

function Window:SetCornerRadius(n)
    n = tonumber(n) or 0
    if n < 0 then n = 0 end
    self._state.CornerRadius = n
    local u = UDim.new(0, n)
    self._mainCorner.CornerRadius = u
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
        self._toggleBtn.BackgroundColor3 = t.Surface
        self._lockBtn.BackgroundColor3 = t.Surface
    end
    if t.Divider then self._mainStroke.Color = t.Divider end
    if t.Text then
        self._titleLabel.TextColor3 = t.Text
        self._toggleBtn.TextColor3 = t.Text
        self._lockBtn.TextColor3 = t.Text
    end
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

function Window:GetRoot() return self._screen end
function Window:GetMain() return self._main end
function Window:GetContent() return self._content end

function Window:Toggle()
    if self._state.Open then self:Close() else self:Open() end
    return self
end

function Window:Close()
    if not self._state.Open then return self end
    self._state.Open = false
    self:_playClose()
    self.Closed:Fire()
    self.Toggled:Fire(false)
    return self
end

function Window:Open()
    if self._state.Open then return self end
    self._state.Open = true
    self:_playOpen(false)
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
    self._origPos = self._main.Position
    tween(self._main, 0.35, {
        Size = UDim2.new(1, -24, 1, -24),
        Position = UDim2.fromScale(0.5, 0.5),
    }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
    self.Maximized:Fire()
    return self
end

function Window:Restore()
    if not self._state.Maximized then return self end
    self._state.Maximized = false
    tween(self._main, 0.35, { Size = self._origSize, Position = self._origPos }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out):Play()
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
    self._state.Open = false
    self:_playClose(function() self._maid:Clean() end)
    task.delay(0.55, function()
        if self._maid then self._maid:Clean() end
    end)
end

return setmetatable({}, {
    __index = Library,
    __call = function(_, ...) return Library:CreateWindow(...) end,
})
