--!strict
-- Polished lightweight trade console. T toggles; all ownership and commit logic remains server-side.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local framework = ReplicatedStorage:WaitForChild("MechFramework")
local remotes = framework:WaitForChild("Remotes")
local functions = remotes:WaitForChild("Functions")
local events = remotes:WaitForChild("Events")
local request = functions:WaitForChild("RequestVehicleTrade",15)
local stateEvent = events:WaitForChild("VehicleTradeState",15)
if not request or not request:IsA("RemoteFunction") or not stateEvent or not stateEvent:IsA("RemoteEvent") then
	warn("[GOD MACHINES] Vehicle trade remotes unavailable")
	return
end

local palette = {
	Bg=Color3.fromRGB(8,11,16), Panel=Color3.fromRGB(15,20,29), Raised=Color3.fromRGB(23,30,42),
	Line=Color3.fromRGB(55,72,92), Text=Color3.fromRGB(232,240,248), Muted=Color3.fromRGB(137,154,173),
	Accent=Color3.fromRGB(71,203,255), Good=Color3.fromRGB(83,220,145), Danger=Color3.fromRGB(255,91,101),
}

local function corner(parent: Instance, radius: number)
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,radius); c.Parent=parent
end
local function stroke(parent: Instance, transparency: number?)
	local s=Instance.new("UIStroke"); s.Color=palette.Line; s.Transparency=transparency or .15; s.Thickness=1; s.Parent=parent
end
local function label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?): TextLabel
	local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Size=size; l.Position=position; l.Font=Enum.Font.GothamMedium
	l.Text=text; l.TextColor3=color or palette.Text; l.TextSize=textSize; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent; return l
end
local function button(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local b=Instance.new("TextButton"); b.AutoButtonColor=false; b.BackgroundColor3=palette.Raised; b.Size=size; b.Position=position
	b.Font=Enum.Font.GothamBold; b.Text=text; b.TextColor3=palette.Text; b.TextSize=13; b.Parent=parent; corner(b,8); stroke(b,.25)
	b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(31,42,58)}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=palette.Raised}):Play() end)
	return b
end

local gui=Instance.new("ScreenGui"); gui.Name="GodMachinesVehicleTrade"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player:WaitForChild("PlayerGui")

local launcher=button(gui,"TRADE  [T]",UDim2.fromOffset(112,38),UDim2.new(1,-128,0,22)); launcher.BackgroundColor3=palette.Panel
local panel=Instance.new("Frame"); panel.Name="TradeConsole"; panel.AnchorPoint=Vector2.new(1,0); panel.Position=UDim2.new(1,-16,0,70); panel.Size=UDim2.fromOffset(420,430)
panel.BackgroundColor3=palette.Bg; panel.Visible=false; panel.Parent=gui; corner(panel,12); stroke(panel,0)

local accent=Instance.new("Frame"); accent.BorderSizePixel=0; accent.BackgroundColor3=palette.Accent; accent.Size=UDim2.new(1,0,0,3); accent.Parent=panel; corner(accent,2)
label(panel,"VEHICLE EXCHANGE",UDim2.new(1,-105,0,28),UDim2.fromOffset(18,16),18)
local status=label(panel,"SERVER-VERIFIED TRANSFER",UDim2.new(1,-36,0,18),UDim2.fromOffset(18,45),10,palette.Muted)
local close=button(panel,"×",UDim2.fromOffset(34,30),UDim2.new(1,-48,0,14)); close.TextSize=20

local partnerTitle=label(panel,"TRADE PARTNER",UDim2.fromOffset(185,18),UDim2.fromOffset(18,82),10,palette.Muted)
local vehicleTitle=label(panel,"YOUR VEHICLE",UDim2.fromOffset(185,18),UDim2.fromOffset(216,82),10,palette.Muted)
local partnerButton=button(panel,"No player",UDim2.fromOffset(185,42),UDim2.fromOffset(18,103))
local vehicleButton=button(panel,"No saved vehicle",UDim2.fromOffset(185,42),UDim2.fromOffset(216,103))

local invite=button(panel,"SEND TRADE REQUEST",UDim2.new(1,-36,0,42),UDim2.fromOffset(18,158)); invite.BackgroundColor3=Color3.fromRGB(24,73,94)

local divider=Instance.new("Frame"); divider.BorderSizePixel=0; divider.BackgroundColor3=palette.Line; divider.BackgroundTransparency=.4; divider.Size=UDim2.new(1,-36,0,1); divider.Position=UDim2.fromOffset(18,216); divider.Parent=panel
local sessionTitle=label(panel,"NO ACTIVE TRADE",UDim2.new(1,-36,0,26),UDim2.fromOffset(18,230),14)
local offerLine=label(panel,"Select a player and a saved vehicle to begin.",UDim2.new(1,-36,0,40),UDim2.fromOffset(18,260),12,palette.Muted); offerLine.TextWrapped=true
local timer=label(panel,"",UDim2.new(1,-36,0,26),UDim2.fromOffset(18,305),18,palette.Accent); timer.Font=Enum.Font.GothamBold

local offer=button(panel,"SET / UPDATE OFFER",UDim2.fromOffset(185,40),UDim2.fromOffset(18,342))
local test=button(panel,"START 2:00 TEST DRIVE",UDim2.fromOffset(185,40),UDim2.fromOffset(216,342)); test.BackgroundColor3=Color3.fromRGB(22,67,86)
local cancel=button(panel,"CANCEL",UDim2.fromOffset(110,34),UDim2.fromOffset(18,391)); cancel.TextColor3=palette.Danger
local accept=button(panel,"ACCEPT SWAP",UDim2.fromOffset(253,34),UDim2.fromOffset(148,391)); accept.BackgroundColor3=Color3.fromRGB(25,82,58); accept.TextColor3=palette.Good

local overview:any={Blueprints={},Players={},Session=nil,TestDriveSeconds=120}
local currentSession:any=nil
local partnerIndex=1
local vehicleIndex=1
local visible=false
local busy=false

local function selectedPartner(): any return overview.Players and overview.Players[partnerIndex] end
local function selectedVehicle(): any return overview.Blueprints and overview.Blueprints[vehicleIndex] end
local function updateSelectors()
	local p=selectedPartner(); partnerButton.Text=p and tostring(p.DisplayName) or "No player"
	local v=selectedVehicle(); vehicleButton.Text=v and tostring(v.Name) or "No saved vehicle"
end
local function cycle(list:any,index:number):number
	if type(list)~="table" or #list==0 then return 1 end
	return (index % #list)+1
end

local function renderSession(session:any?)
	currentSession=session
	local active=session~=nil and session.State~="Cancelled" and session.State~="Committed"
	invite.Visible=not active; partnerButton.Visible=not active; vehicleButton.Visible=true; partnerTitle.Visible=not active; vehicleTitle.Visible=true
	offer.Visible=active; test.Visible=active; cancel.Visible=active; accept.Visible=active
	if not session then
		sessionTitle.Text="NO ACTIVE TRADE"; offerLine.Text="Select a player and a saved vehicle to begin."; timer.Text=""; return
	end
	if session.State=="Cancelled" then
		sessionTitle.Text="TRADE CANCELLED"; offerLine.Text=tostring(session.CancelReason or "Cancelled"); timer.Text=""; return
	elseif session.State=="Committed" then
		sessionTitle.Text="SWAP COMPLETE"; offerLine.Text="Vehicle ownership was exchanged and saved."; timer.Text="TRANSFER VERIFIED"; timer.TextColor3=palette.Good; return
	end
	timer.TextColor3=palette.Accent
	sessionTitle.Text="TRADING WITH  "..string.upper(tostring(session.PartnerName or "PLAYER"))
	offerLine.Text=string.format("You: %s\nThem: %s",tostring(session.YourOffer or "choose a vehicle"),tostring(session.PartnerOffer or "waiting for offer"))
	if session.State=="Testing" then
		local remaining=math.max(0,tonumber(session.TestRemaining) or 0); local mins=math.floor(remaining/60); local secs=math.floor(remaining%60)
		timer.Text=string.format("TEST DRIVE  %d:%02d",mins,secs)
	elseif session.State=="Review" then timer.Text="TEST COMPLETE — DECIDE"
	else timer.Text="LOCK BOTH VEHICLES TO TEST" end
	accept.Text=(session.YourAccepted==true) and "ACCEPTED ✓" or "ACCEPT SWAP"
	accept.TextColor3=(session.YourAccepted==true) and palette.Good or palette.Text
end

local function invoke(payload:any):(boolean,any)
	if busy then return false,"Busy" end
	busy=true
	local ok,a,b=pcall(function() return request:InvokeServer(payload) end)
	busy=false
	if not ok then status.Text="NETWORK ERROR"; status.TextColor3=palette.Danger; return false,a end
	if a~=true then status.Text=tostring(b or "REQUEST REJECTED"); status.TextColor3=palette.Danger; return false,b end
	status.Text="SERVER-VERIFIED TRANSFER"; status.TextColor3=palette.Muted
	return true,b
end

local function refresh()
	local ok,data=invoke({Action="Overview"})
	if ok and type(data)=="table" then overview=data; partnerIndex=math.clamp(partnerIndex,1,math.max(1,#overview.Players)); vehicleIndex=math.clamp(vehicleIndex,1,math.max(1,#overview.Blueprints)); updateSelectors(); renderSession(data.Session) end
end

local function setVisible(value:boolean)
	visible=value; panel.Visible=value
	if value then refresh(); panel.Position=UDim2.new(1,-4,0,70); panel.BackgroundTransparency=.15; TweenService:Create(panel,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(1,-16,0,70),BackgroundTransparency=0}):Play() end
end

launcher.MouseButton1Click:Connect(function() setVisible(not visible) end)
close.MouseButton1Click:Connect(function() setVisible(false) end)
partnerButton.MouseButton1Click:Connect(function() partnerIndex=cycle(overview.Players,partnerIndex); updateSelectors() end)
vehicleButton.MouseButton1Click:Connect(function() vehicleIndex=cycle(overview.Blueprints,vehicleIndex); updateSelectors() end)
invite.MouseButton1Click:Connect(function()
	local p,v=selectedPartner(),selectedVehicle(); if not p or not v then status.Text="SELECT PLAYER + VEHICLE"; status.TextColor3=palette.Danger; return end
	local ok,data=invoke({Action="Invite",TargetUserId=p.UserId,BlueprintName=v.Name}); if ok then renderSession(data) end
end)
offer.MouseButton1Click:Connect(function() local v=selectedVehicle(); if v then local ok,data=invoke({Action="SetOffer",BlueprintName=v.Name}); if ok then renderSession(data) end end end)
test.MouseButton1Click:Connect(function() local ok,data=invoke({Action="StartTest"}); if ok then renderSession(data) end end)
cancel.MouseButton1Click:Connect(function() invoke({Action="Cancel"}); refresh() end)
accept.MouseButton1Click:Connect(function() local desired=not (currentSession and currentSession.YourAccepted==true); local ok,data=invoke({Action="Accept",Accepted=desired}); if ok and type(data)=="table" then renderSession(data) end end)

stateEvent.OnClientEvent:Connect(function(session:any)
	renderSession(session)
	if not visible and session and session.State=="Selecting" then setVisible(true) end
end)

UserInputService.InputBegan:Connect(function(input:InputObject,processed:boolean)
	if processed then return end
	if input.KeyCode==Enum.KeyCode.T then setVisible(not visible) end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(.25)
		if currentSession and currentSession.State=="Testing" and currentSession.TestEndsAt then
			currentSession.TestRemaining=math.max(0,currentSession.TestEndsAt-os.clock()); renderSession(currentSession)
		end
	end
end)

renderSession(nil); updateSelectors()
