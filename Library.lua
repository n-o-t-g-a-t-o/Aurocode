local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
    self._tasks[#self._tasks + 1] = task
    return task
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
    return setmetatable({ _handlers = {}, _alive = true }, Signal)
end

function Signal:Connect(fn)
    if not self._alive then return { Disconnect = function() end } end
    local handlers = self._handlers
    handlers[#handlers + 1] = fn
    return {
        Disconnect = function()
            for i, h in ipairs(handlers) do
                if h == fn then
                    table.remove(handlers, i)
                    break
                end
            end
        end,
    }
end

function Signal:Fire(...)
    if not self._alive then return end
    for _, h in ipairs(self._handlers) do
        task.spawn(h, ...)
    end
end

function Signal:Destroy()
    self._alive = false
    table.clear(self._handlers)
end

local DefaultTheme = {
    Background = Color3.fromRGB(18, 18, 22),
    Surface = Color3.fromRGB(26, 26, 32),
    Accent = Color3.fromRGB(120, 90, 255),
    Text = Color3.fromRGB(235, 235, 240),
    SubText = Color3.fromRGB(150, 150, 160),
    Divider = Color3.fromRGB(40, 40, 48),
    Danger = Color3.fromRGB(220, 60, 80),
}

local function new(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if children then
        for _, c in ipairs(children) do
            c.Parent = inst
        end
    end
    return inst
end

local function mount(gui)
    gui.Name = "Aurocode_" .. tostring(math.random(100000, 999999))
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 2147483647

    local parented = pcall(function()
        if typeof(gethui) == "function" then
            gui.Parent = gethui()
        elseif syn and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
            gui.Parent = CoreGui
        else
            gui.Parent = CoreGui
        end
    end)
    if not parented or not gui.Parent then
        gui.Parent = PlayerGui or CoreGui
    end
end

local function mergeTheme(custom)
    local out = {}
    for k, v in pairs(DefaultTheme) do out[k] = v end
    if type(custom) == "table" then
        for k, v in pairs(custom) do out[k] = v end
    end
    return out
end

function Library.new()
    return setmetatable({ _windows = {} }, Library)
end

function Library:CreateWindow(...)
    local args = { ... }
    local config
    if type(args[1]) == "table" then
        config = args[1]
    else
        config = {
            Title = args[1],
            Footer = args[2],
            CornerRadius = args[3],
        }
    end

    local title = tostring(config.Title or "Aurocode")
    local footer = tostring(config.Footer or "v1.0.0")
    local corner = tonumber(config.CornerRadius) or 10
    local dpi = tonumber(config.DPIScale) or 1
    local size = (typeof(config.Size) == "UDim2") and config.Size or UDim2.fromOffset(320, 420)
    local position = (typeof(config.Position) == "UDim2") and config.Position or UDim2.fromScale(0.5, 0.5)
    local draggable = (config.Draggable ~= false)
    local theme = mergeTheme(config.Theme)

    local self = setmetatable({}, Window)
    self._maid = Maid.new()
    self._theme = theme
    self._state = {
        Title = title,
        Footer = footer,
        Open = true,
        DPIScale = dpi,
        CornerRadius = corner,
        Draggable = draggable,
    }

    self.Toggled = Signal.new()
    self.Closed = Signal.new()
    self.Opened = Signal.new()
    self.Destroyed = Signal.new()
    self._maid:Give(self.Toggled)
    self._maid:Give(self.Closed)
    self._maid:Give(self.Opened)
    self._maid:Give(self.Destroyed)

    local screen = new("ScreenGui")
    mount(screen)
    self._screen = screen
    self._maid:Give(screen)

    local scale = new("UIScale", { Scale = dpi })
    scale.Parent = screen
    self._scale = scale

    local root = new("Frame", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        ClipsDescendants = true,
    })
    root.Parent = screen
    self._root = root

    self._rootCorner = new("UICorner", { CornerRadius = UDim.new(0, corner) })
    self._rootCorner.Parent = root

    new("UIStroke", {
        Color = theme.Divider,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }).Parent = root

    local header = new("Frame", {
        Name = "Header",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
    })
    header.Parent = root
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
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -104, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = title,
        TextColor3 = theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    titleLabel.Parent = header
    self._titleLabel = titleLabel

    local function makeIconButton(name, char, xOffset)
        local btn = new("TextButton", {
            Name = name,
            AnchorPoint = Vector2.new(1, 0.5),
            AutoButtonColor = false,
            BackgroundColor3 = theme.Divider,
            BorderSizePixel = 0,
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(32, 32),
            Font = Enum.Font.GothamBold,
            Text = char,
            TextColor3 = theme.Text,
            TextSize = 18,
        })
        new("UICorner", { CornerRadius = UDim.new(1, 0) }).Parent = btn
        btn.Parent = header
        return btn
    end

    local closeBtn = makeIconButton("Close", "×", -10)
    local toggleBtn = makeIconButton("Minimize", "–", -50)

    local body = new("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 44),
        Size = UDim2.new(1, 0, 1, -72),
    })
    body.Parent = root
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
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
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
        Size = UDim2.new(1, 0, 0, 28),
    })
    footerBar.Parent = root
    self._footerBar = footerBar

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
        TextSize = 11,
    })
    footerLabel.Parent = footerBar
    self._footerLabel = footerLabel

    self._maid:Give(closeBtn.MouseButton1Click:Connect(function()
        self:Destroy()
    end))
    self._maid:Give(toggleBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end))

    local function bindPress(btn, hoverColor)
        local base = btn.BackgroundColor3
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        self._maid:Give(btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                TweenService:Create(btn, info, { BackgroundColor3 = hoverColor }):Play()
            elseif input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                TweenService:Create(btn, info, { BackgroundColor3 = hoverColor }):Play()
            end
        end))
        self._maid:Give(btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                TweenService:Create(btn, info, { BackgroundColor3 = base }):Play()
            end
        end))
    end
    bindPress(closeBtn, theme.Danger)
    bindPress(toggleBtn, theme.Accent)

    do
        local dragging, dragInput, dragStart, startPos
        self._maid:Give(header.InputBegan:Connect(function(input)
            if not self._state.Draggable then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = root.Position
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
                local delta = input.Position - dragStart
                root.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
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
    local udim = UDim.new(0, n)
    self._rootCorner.CornerRadius = udim
    self._headerCorner.CornerRadius = udim
    self._footerCorner.CornerRadius = udim
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
        self._root.Size = sz
    end
    return self
end

function Window:SetPosition(pos)
    if typeof(pos) == "UDim2" then
        self._root.Position = pos
    end
    return self
end

function Window:SetDraggable(bool)
    self._state.Draggable = bool and true or false
    return self
end

function Window:SetTheme(t)
    if type(t) ~= "table" then return self end
    for k, v in pairs(t) do self._theme[k] = v end
    if t.Background then self._root.BackgroundColor3 = t.Background end
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
        local copy = {}
        for k, v in pairs(self._state) do copy[k] = v end
        return copy
    end
    return self._state[key]
end

function Window:GetRoot()
    return self._screen
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
    self._root.Visible = false
    self.Closed:Fire()
    self.Toggled:Fire(false)
    return self
end

function Window:Open()
    if self._state.Open then return self end
    self._state.Open = true
    self._root.Visible = true
    self.Opened:Fire()
    self.Toggled:Fire(true)
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
