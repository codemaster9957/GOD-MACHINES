--!strict
-- Compact play-mode HUD and V-to-cycle input for saved vehicle quick slots.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")

local player=Players.LocalPlayer
local framework=ReplicatedStorage:WaitForChild("MechFramework")
local remote=framework:WaitForChild("Remotes"):WaitForChild("Functions"):WaitForChild("RequestMachineAction")::RemoteFunction
local QuickSwapRules=require(framework:WaitForChild("Shared"):WaitForChild("QuickSwapRules"))

local slots:{[number]:string}={}
local CurrentSlot:number?=nil
local CooldownEndsAt=0
local busy=false

local gui=Instance.new("ScreenGui")
gui.Name="VehicleQuickSwap"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=18
gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Name="QuickSwapBar"
root.AnchorPoint=Vector2.new(.5,1)
root.Position=UDim2.new(.5,0,1,-88)
root.Size=UDim2.fromOffset(340,68)
root.BackgroundColor3=Color3.fromRGB(12,15,18)
root.BackgroundTransparency=.1
root.BorderSizePixel=0
root.Visible=false
root.Parent=gui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,7); corner.Parent=root
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(255,178,48); stroke.Transparency=.25; stroke.Parent=root

local title=Instance.new("TextLabel")
title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.new(1,-20,0,16)
title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold; title.TextSize=10
title.TextColor3=Color3.fromRGB(255,178,48); title.TextXAlignment=Enum.TextXAlignment.Left
title.Text="[V]  QUICK SWAP"; title.Parent=root

local status=Instance.new("TextLabel")
status.Position=UDim2.new(.5,0,0,5); status.Size=UDim2.new(.5,-10,0,16)
status.BackgroundTransparency=1; status.Font=Enum.Font.Gotham; status.TextSize=9
status.TextColor3=Color3.fromRGB(151,158,166); status.TextXAlignment=Enum.TextXAlignment.Right
status.Text="READY"; status.Parent=root

local cards={}
for slot=1,QuickSwapRules.MaxSlots do
	local card=Instance.new("TextLabel")
	card.Position=UDim2.new((slot-1)/3,8,0,27); card.Size=UDim2.new(1/3,-11,0,31)
	card.BackgroundColor3=Color3.fromRGB(28,33,38); card.BorderSizePixel=0
	card.Font=Enum.Font.GothamBold; card.TextSize=9; card.TextColor3=Color3.fromRGB(235,238,241)
	card.Text="Q"..slot.."  EMPTY"; card.Parent=root
	local cardCorner=Instance.new("UICorner"); cardCorner.CornerRadius=UDim.new(0,4); cardCorner.Parent=card
	cards[slot]=card
end

local function SetQuickSwapSlots(nextSlots:any)
	slots=QuickSwapRules.NormalizeSlots(nextSlots)
	for slot=1,QuickSwapRules.MaxSlots do
		local name=slots[slot]
		local display=if name then string.upper(name) else "EMPTY"
		if #display>10 then display=display:sub(1,9).."…" end
		cards[slot].Text="Q"..slot.."  "..display
		cards[slot].BackgroundColor3=if CurrentSlot==slot then Color3.fromRGB(91,67,31) else Color3.fromRGB(28,33,38)
	end
end

local function invokeSlots()
	if player:GetAttribute("GMProfileReady")~=true then return end
	local called,success,result=pcall(function() return remote:InvokeServer({Action="GetQuickSwapSlots"}) end)
	if called and success and type(result)=="table" then SetQuickSwapSlots(result) end
end

local function updateVisible()
	local mechId=player:GetAttribute("ActiveMechId")
	root.Visible=player:GetAttribute("BuildMode")~=true and type(mechId)=="string" and mechId~="" and player:GetAttribute("GMProfileReady")==true
end

UserInputService.InputBegan:Connect(function(input,processed)
	if processed or input.KeyCode~=Enum.KeyCode.V or busy or not root.Visible then return end
	local mechId=player:GetAttribute("ActiveMechId")
	if type(mechId)~="string" or mechId=="" then return end
	local remaining=CooldownEndsAt-os.clock()
	if remaining>0 then status.Text=string.format("COOLDOWN %.1FS",remaining); return end
	busy=true; status.Text="SWAPPING…"
	local called,success,result=pcall(function() return remote:InvokeServer({Action="QuickSwap",MechId=mechId}) end)
	busy=false
	if called and success and type(result)=="table" then
		CurrentSlot=tonumber(result.Slot)
		CooldownEndsAt=os.clock()+(tonumber(result.Cooldown) or QuickSwapRules.CooldownSeconds)
		if type(result.Slots)=="table" then SetQuickSwapSlots(result.Slots) end
		status.Text="ACTIVE: "..string.upper(tostring(result.Name or "VEHICLE"))
	elseif called and type(result)=="table" and result.Error=="QuickSwapCooldown" then
		CooldownEndsAt=os.clock()+(tonumber(result.Remaining) or 0); status.Text="COOLDOWN"
	else status.Text=string.upper(tostring(result or success or "SWAP FAILED")) end
end)

local playerScripts=player:WaitForChild("PlayerScripts")
local bridge=playerScripts:FindFirstChild("GMQuickSwapSlotsChanged")
if not bridge then bridge=Instance.new("BindableEvent"); bridge.Name="GMQuickSwapSlotsChanged"; bridge.Parent=playerScripts end
(bridge::BindableEvent).Event:Connect(SetQuickSwapSlots)

for _,attribute in ipairs({"ActiveMechId","BuildMode","GMProfileReady"}) do player:GetAttributeChangedSignal(attribute):Connect(function() updateVisible(); if attribute=="GMProfileReady" then task.spawn(invokeSlots) end end) end
framework:GetAttributeChangedSignal("MachineServerReady"):Connect(function() task.spawn(invokeSlots) end)
RunService.RenderStepped:Connect(function()
	updateVisible()
	local remaining=CooldownEndsAt-os.clock()
	if remaining>0 then status.Text=string.format("COOLDOWN %.1FS",remaining) elseif not busy and status.Text:find("COOLDOWN") then status.Text="READY" end
end)

updateVisible()
task.spawn(invokeSlots)
