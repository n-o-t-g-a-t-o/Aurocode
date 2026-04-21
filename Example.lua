local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/n-o-t-g-a-t-o/Aurocode/refs/heads/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title        = "Aurocode",
    Footer       = "v1.0.0 mobile",
    CornerRadius = 10,
    DPIScale     = 1,
    Size         = UDim2.fromOffset(520, 300),
    Draggable    = true,
})

Window:OnDestroy(function()
    print("[Aurocode] OnDestroy callback fired")
end)

Window.Opened:Connect(function()
    print("[Aurocode] opened")
end)

Window.Closed:Connect(function()
    print("[Aurocode] closed")
end)

Window.Toggled:Connect(function(o)
    print("[Aurocode] toggled:", o)
end)

Window.Locked:Connect(function()
    print("[Aurocode] locked")
end)

Window.Unlocked:Connect(function()
    print("[Aurocode] unlocked")
end)

Window.Maximized:Connect(function()
    print("[Aurocode] maximized")
end)

Window.Restored:Connect(function()
    print("[Aurocode] restored")
end)

local Notify = Library:Notify("Aurocode Says:", "This is a normal notification.", 3, true)
Notify.NotifyDirection = "ru"
Notify:SetTimeIndicator(15)

task.wait(1)

local InfiniteNotify = Library:Notify("Aurocode Says:", "This one stays until dismissed.", 0, true)
InfiniteNotify.NotifyDirection = "lu"
InfiniteNotify:SetTimeIndicator(10)

task.wait(2)
InfiniteNotify:SetTimeIndicator(50)

task.wait(1)
InfiniteNotify:SetTimeIndicator(100)

task.wait(2)
InfiniteNotify:Dissmiss()

task.wait(2)
Window:SetTitle("Aurocode Library")
Window:SetFooter("example.lua demo")

task.wait(2)
Window:Toggle()
task.wait(1)
Window:Toggle()

task.wait(2)
Window:Lock()
task.wait(2)
Window:Unlock()

task.wait(2)
Window:Maximize()
task.wait(2)
Window:Restore()

task.wait(2)
print("State:", Window:GetState())
