--!strict
-- Compact play-mode HUD with polished quick-swap feedback and alternate controls.
-- The server remains authoritative for slot ownership, cooldowns, and vehicle replacement.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")

local player=Players.LocalPlayer
local framework=ReplicatedStorage:WaitForChild("MechFramework")
local remote=framework:WaitForChild("Remotes"):WaitForChild("Functions"):WaitForChild("RequestMachineAction")::RemoteFunction
local QuickSwapRules=require(framework:WaitForChild("Shared"):WaitForChild("QuickSwapRules"))

local slots:{[number]:string}={}
local CurrentSlot:number?=nil
local CooldownEndsAt=0
local CooldownDuration=QuickSwapRules.CooldownSeconds
local busy=false
local wasCooling=false

local ATTR_COMPACT="GMQoL_QuickSwapCompact"
local ATTR_HINTS="GMQoL_QuickSwapHints"
local ATTR_SAFE_MARGIN="GMQoL_SafeMargin"

local function preference(key:string, fallback:any):any
	local value=player:GetAttribute("GMQoL_"..key)
	return if value==nil then fallback else value
end

local function showToast(text:string,tone:string?)
	local playerScripts=player:FindFirstChild("PlayerScripts")
	local bridge=playerScripts and playerScripts:FindFirstChild("GMQoLToast")
	if bridge and bridge:IsA("BindableEvent") then bridge:Fire(text,tone or "info") end
end

local errors:{[string]:string}={
	QuickSwapCooldown="QUICK SWAP IS COOLING DOWN",
	BlueprintNotFound="SAVED VEHICLE NO LONGER EXISTS",
	NoQuickSwapSlots="ASSIGN A VEHICLE TO A QUICK SLOT FIRST",
	NoAlternateQuickSwap="NO OTHER QUICK-SLOT VEHICLE IS AVAILABLE",
	NotAuthorized="YOU DO NOT CONTROL THIS MACHINE",
	ProfileNotReady="PROFILE IS STILL LOADING",
	MachineNotFound="ACTIVE MACHINE COULD NOT BE FOUND",
}
local function humanize(value:any):string
	local code:string
	if type(value)=="table" then code=tostring(value.Error or value.Reason or "SWAP FAILED") else code=tostring(value or "SWAP FAILED") end
	return errors[code] or string.upper(code:gsub("_"," "))
end

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
root.Size=UDim2.fromOffset(340,72)
root.BackgroundColor3=Color3.fromRGB(12,15,18)
root.BackgroundTransparency=.1
root.BorderSizePixel=0
root.Visible=false
root.Parent=gui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,7); corner.Parent=root
local rootStroke=Instance.new("UIStroke"); rootStroke.Color=Color3.fromRGB(255,178,48); rootStroke.Transparency=.25; rootStroke.Parent=root

local title=Instance.new("TextLabel")
title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.new(.48,-10,0,16)
title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold; title.TextSize=10
title.TextColor3=Color3.fromRGB(255,178,48); title.TextXAlignment=Enum.TextXAlignment.Left
title.Text="[V / M4]  QUICK SWAP"; title.Parent=root

local status=Instance.new("TextLabel")
status.Position=UDim2.new(.45,0,0,5); status.Size=UDim2.new(.55,-10,0,16)
status.BackgroundTransparency=1; status.Font=Enum.Font.Gotham; status.TextSize=9
status.TextColor3=Color3.fromRGB(151,158,166); status.TextXAlignment=Enum.TextXAlignment.Right
status.Text="READY"; status.Parent=root

local progressTrack=Instance.new("Frame")
progressTrack.Name="CooldownTrack"; progressTrack.Position=UDim2.new(0,8,1,-7); progressTrack.Size=UDim2.new(1,-16,0,3); progressTrack.BackgroundColor3=Color3.fromRGB(43,48,53); progressTrack.BorderSizePixel=0; progressTrack.Parent=root
local CooldownProgress=Instance.new("Frame")
CooldownProgress.Name="CooldownProgress"; CooldownProgress.Size=UDim2.new(0,0,1,0); CooldownProgress.BackgroundColor3=Color3.fromRGB(255,178,48); CooldownProgress.BorderSizePixel=0; CooldownProgress.Parent=progressTrack

local cards:{[number]:TextLabel}={}
local fullNames:{[number]:string}={}
for slot=1,QuickSwapRules.MaxSlots do
	local card=Instance.new("TextLabel")
	card.Name="QuickSlot"..slot
	card.Position=UDim2.new((slot-1)/QuickSwapRules.MaxSlots,8,0,27)
	card.Size=UDim2.new(1/QuickSwapRules.MaxSlots,-11,0,31)
	card.BackgroundColor3=Color3.fromRGB(28,33,38); card.BorderSizePixel=0
	card.Font=Enum.Font.GothamBold; card.TextSize=9; card.TextColor3=Color3.fromRGB(235,238,241)
	card.Text="Q"..slot.."  EMPTY"; card.Active=true; card.Parent=root
	local cardCorner=Instance.new("UICorner"); cardCorner.CornerRadius=UDim.new(0,4); cardCorner.Parent=card
	cards[slot]=card
end

local tooltip=Instance.new("TextLabel")
tooltip.Name="QuickSwapTooltip"; tooltip.AnchorPoint=Vector2.new(.5,1); tooltip.Position=UDim2.new(.5,0,0,-5); tooltip.Size=UDim2.fromOffset(260,28)
tooltip.BackgroundColor3=Color3.fromRGB(8,11,15); tooltip.BackgroundTransparency=.04; tooltip.BorderSizePixel=0; tooltip.Font=Enum.Font.GothamBold; tooltip.TextSize=9; tooltip.TextColor3=Color3.fromRGB(235,238,241); tooltip.Visible=false; tooltip.Parent=root
local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,5); tc.Parent=tooltip
for slot,card in pairs(cards) do
	card.MouseEnter:Connect(function()
		local name=fullNames[slot]
		if name and name~="" and preference("Tooltips",true)==true then tooltip.Text="QUICK "..slot.."  •  "..name; tooltip.Visible=true end
	end)
	card.MouseLeave:Connect(function() tooltip.Visible=false end)
end

local function usableSlotCount():number
	local count=0
	for slot=1,QuickSwapRules.MaxSlots do if slots[slot] then count+=1 end end
	return count
end

local function displayName(name:string):string
	if preference("StreamerMode",false)==true and #name>8 then return name:sub(1,7).."…" end
	if #name>10 then return name:sub(1,9).."…" end
	return name
end

local function SetQuickSwapSlots(nextSlots:any)
	slots=QuickSwapRules.NormalizeSlots(nextSlots)
	for slot=1,QuickSwapRules.MaxSlots do
		local name=slots[slot]
		fullNames[slot]=name
		local display=if name then string.upper(displayName(name)) else "EMPTY"
		cards[slot].Text="Q"..slot.."  "..display
		cards[slot].BackgroundColor3=if CurrentSlot==slot then Color3.fromRGB(91,67,31) else Color3.fromRGB(28,33,38)
		cards[slot].TextColor3=if name then Color3.fromRGB(235,238,241) else Color3.fromRGB(116,125,134)
	end
end

local function invokeSlots()
	if player:GetAttribute("GMProfileReady")~=true then status.Text="PROFILE LOADING"; return end
	local called,success,result=pcall(function() return remote:InvokeServer({Action="GetQuickSwapSlots"}) end)
	if called and success and type(result)=="table" then
		SetQuickSwapSlots(result)
		local count=usableSlotCount()
		status.Text=if count>0 then string.format("READY  •  %d/%d SLOTS",count,QuickSwapRules.MaxSlots) else "NO QUICK SLOTS"
	elseif not called then
		status.Text="NETWORK ERROR"; showToast("Quick swap could not reach the server","bad")
	end
end

local function updateLayout()
	local safe=math.clamp(tonumber(preference("SafeMargin",16)) or 16,0,64)
	local compact=preference("QuickSwapCompact",false)==true
	local hints=preference("QuickSwapHints",true)==true
	root.Position=UDim2.new(.5,0,1,-(70+safe))
	root.Size=if compact then UDim2.fromOffset(300,58) else UDim2.fromOffset(340,72)
	title.Text=if hints then "[V / M4]  QUICK SWAP" else "QUICK SWAP"
	for slot,card in pairs(cards) do
		card.Position=UDim2.new((slot-1)/QuickSwapRules.MaxSlots,8,0,if compact then 24 else 27)
		card.Size=UDim2.new(1/QuickSwapRules.MaxSlots,-11,0,if compact then 24 else 31)
	end
end

local function updateVisible()
	local mechId=player:GetAttribute("ActiveMechId")
	root.Visible=player:GetAttribute("BuildMode")~=true and type(mechId)=="string" and mechId~=""
	if root.Visible and player:GetAttribute("GMProfileReady")~=true then status.Text="PROFILE LOADING" end
end

local function altHeld():boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
end

local function attemptSwap(source:string)
	if busy or not root.Visible then return end
	if player:GetAttribute("GMProfileReady")~=true then status.Text="PROFILE LOADING"; showToast("Profile is still loading","warn"); return end
	local mechId=player:GetAttribute("ActiveMechId")
	if type(mechId)~="string" or mechId=="" then return end
	if usableSlotCount()==0 then status.Text="NO QUICK SLOTS"; showToast("Assign a saved vehicle to a quick slot first","warn"); return end
	local remaining=CooldownEndsAt-os.clock()
	if remaining>0 then status.Text=string.format("COOLDOWN %.1FS",remaining); return end
	busy=true; status.Text="SWAPPING…"
	local called,success,result=pcall(function() return remote:InvokeServer({Action="QuickSwap",MechId=mechId,Source=source}) end)
	busy=false
	if called and success and type(result)=="table" then
		CurrentSlot=tonumber(result.Slot)
		CooldownDuration=math.max(.01,tonumber(result.Cooldown) or QuickSwapRules.CooldownSeconds)
		CooldownEndsAt=os.clock()+CooldownDuration
		wasCooling=true
		if type(result.Slots)=="table" then SetQuickSwapSlots(result.Slots) else SetQuickSwapSlots(slots) end
		local name=tostring(result.Name or "VEHICLE")
		status.Text="ACTIVE: "..string.upper(displayName(name))
		showToast("Quick swapped to "..name,"good")
	elseif called and type(result)=="table" and result.Error=="QuickSwapCooldown" then
		CooldownDuration=math.max(.01,tonumber(result.Cooldown) or QuickSwapRules.CooldownSeconds)
		CooldownEndsAt=os.clock()+(tonumber(result.Remaining) or 0); wasCooling=true; status.Text="COOLDOWN"
	else
		local message=humanize(if called then result or success else "NETWORK ERROR")
		status.Text=message; showToast(message,"bad")
	end
end

UserInputService.InputBegan:Connect(function(input,processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType==Enum.UserInputType.MouseButton4 then attemptSwap("MouseButton4"); return end
	if input.KeyCode==Enum.KeyCode.V then attemptSwap(if altHeld() then "Alt+V" else "V") end
end)

local playerScripts=player:WaitForChild("PlayerScripts")
local bridge=playerScripts:FindFirstChild("GMQuickSwapSlotsChanged")
if not bridge then bridge=Instance.new("BindableEvent"); bridge.Name="GMQuickSwapSlotsChanged"; bridge.Parent=playerScripts end
(bridge::BindableEvent).Event:Connect(SetQuickSwapSlots)

for _,attribute in ipairs({"ActiveMechId","BuildMode","GMProfileReady"}) do
	player:GetAttributeChangedSignal(attribute):Connect(function() updateVisible(); if attribute=="GMProfileReady" then task.spawn(invokeSlots) end end)
end
for _,key in ipairs({"QuickSwapCompact","QuickSwapHints","SafeMargin","StreamerMode"}) do player:GetAttributeChangedSignal("GMQoL_"..key):Connect(function() updateLayout(); SetQuickSwapSlots(slots) end) end
framework:GetAttributeChangedSignal("MachineServerReady"):Connect(function() task.spawn(invokeSlots) end)

RunService.RenderStepped:Connect(function()
	updateVisible(); updateLayout()
	local remaining=math.max(0,CooldownEndsAt-os.clock())
	local fraction=if remaining>0 then math.clamp(remaining/math.max(.01,CooldownDuration),0,1) else 0
	CooldownProgress.Size=UDim2.new(fraction,0,1,0)
	if remaining>0 then
		status.Text=string.format("COOLDOWN %.1FS  •  %d/%d",remaining,usableSlotCount(),QuickSwapRules.MaxSlots)
		wasCooling=true
	elseif wasCooling and not busy then
		wasCooling=false; status.Text=string.format("READY  •  %d/%d SLOTS",usableSlotCount(),QuickSwapRules.MaxSlots)
		if preference("ReducedMotion",false)~=true then
			rootStroke.Transparency=0
			TweenService:Create(rootStroke,TweenInfo.new(.35),{Transparency=.25}):Play()
		end
	elseif not busy and player:GetAttribute("GMProfileReady")==true and not status.Text:find("ACTIVE") and not status.Text:find("NO QUICK") then
		status.Text=string.format("READY  •  %d/%d SLOTS",usableSlotCount(),QuickSwapRules.MaxSlots)
	end
end)

updateLayout(); updateVisible(); task.spawn(invokeSlots)
