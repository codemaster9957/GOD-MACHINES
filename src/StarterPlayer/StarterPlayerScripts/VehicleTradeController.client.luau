--!strict
-- Polished lightweight trade console with keyboard navigation and test-drive feedback.
-- All ownership, validation, test-drive setup, and commit logic remains server-side.

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

local ATTR_TRADE_COMPACT="GMQoL_TradeCompact"
local ATTR_SAFE_MARGIN="GMQoL_SafeMargin"
local ATTR_REDUCED_MOTION="GMQoL_ReducedMotion"
local ATTR_STREAMER_MODE="GMQoL_StreamerMode"

local palette = {
	Bg=Color3.fromRGB(8,11,16), Panel=Color3.fromRGB(15,20,29), Raised=Color3.fromRGB(23,30,42),
	Line=Color3.fromRGB(55,72,92), Text=Color3.fromRGB(232,240,248), Muted=Color3.fromRGB(137,154,173),
	Accent=Color3.fromRGB(71,203,255), Good=Color3.fromRGB(83,220,145), Danger=Color3.fromRGB(255,91,101), Warn=Color3.fromRGB(255,178,48),
}

local function pref(attribute:string, fallback:any):any
	local value=player:GetAttribute(attribute)
	return if value==nil then fallback else value
end
local function showToast(text:string,tone:string?)
	local scripts=player:FindFirstChild("PlayerScripts")
	local bridge=scripts and scripts:FindFirstChild("GMQoLToast")
	if bridge and bridge:IsA("BindableEvent") then bridge:Fire(text,tone or "info") end
end
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
	b.MouseEnter:Connect(function() if pref(ATTR_REDUCED_MOTION,false)~=true then TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(31,42,58)}):Play() end end)
	b.MouseLeave:Connect(function() if pref(ATTR_REDUCED_MOTION,false)~=true then TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=palette.Raised}):Play() else b.BackgroundColor3=palette.Raised end end)
	return b
end
local function shortName(value:any):string
	local text=tostring(value or "")
	if pref(ATTR_STREAMER_MODE,false)==true and #text>10 then return text:sub(1,9).."…" end
	if #text>24 then return text:sub(1,23).."…" end
	return text
end

local gui=Instance.new("ScreenGui"); gui.Name="GodMachinesVehicleTrade"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player:WaitForChild("PlayerGui")

local launcher=button(gui,"TRADE  [T]",UDim2.fromOffset(112,38),UDim2.new(1,-128,0,22)); launcher.BackgroundColor3=palette.Panel
local panel=Instance.new("Frame"); panel.Name="TradeConsole"; panel.AnchorPoint=Vector2.new(1,0); panel.Position=UDim2.new(1,-16,0,70); panel.Size=UDim2.fromOffset(420,454)
panel.BackgroundColor3=palette.Bg; panel.Visible=false; panel.Parent=gui; corner(panel,12); stroke(panel,0)

local accent=Instance.new("Frame"); accent.BorderSizePixel=0; accent.BackgroundColor3=palette.Accent; accent.Size=UDim2.new(1,0,0,3); accent.Parent=panel; corner(accent,2)
label(panel,"VEHICLE EXCHANGE",UDim2.new(1,-105,0,28),UDim2.fromOffset(18,16),18)
local status=label(panel,"SERVER-VERIFIED TRANSFER",UDim2.new(1,-36,0,18),UDim2.fromOffset(18,45),10,palette.Muted)
local close=button(panel,"×",UDim2.fromOffset(34,30),UDim2.new(1,-48,0,14)); close.TextSize=20

local partnerTitle=label(panel,"TRADE PARTNER   [← / →]",UDim2.fromOffset(185,18),UDim2.fromOffset(18,82),10,palette.Muted)
local vehicleTitle=label(panel,"YOUR VEHICLE   [↑ / ↓]",UDim2.fromOffset(185,18),UDim2.fromOffset(216,82),10,palette.Muted)
local partnerButton=button(panel,"No player",UDim2.fromOffset(185,42),UDim2.fromOffset(18,103))
local vehicleButton=button(panel,"No saved vehicle",UDim2.fromOffset(185,42),UDim2.fromOffset(216,103))

local invite=button(panel,"SEND TRADE REQUEST  [ENTER]",UDim2.new(1,-36,0,42),UDim2.fromOffset(18,158)); invite.BackgroundColor3=Color3.fromRGB(24,73,94)

local divider=Instance.new("Frame"); divider.BorderSizePixel=0; divider.BackgroundColor3=palette.Line; divider.BackgroundTransparency=.4; divider.Size=UDim2.new(1,-36,0,1); divider.Position=UDim2.fromOffset(18,216); divider.Parent=panel
local sessionTitle=label(panel,"NO ACTIVE TRADE",UDim2.new(1,-36,0,26),UDim2.fromOffset(18,230),14)
local offerLine=label(panel,"Select a player and a saved vehicle to begin.",UDim2.new(1,-36,0,40),UDim2.fromOffset(18,260),12,palette.Muted); offerLine.TextWrapped=true
local timer=label(panel,"",UDim2.new(1,-36,0,26),UDim2.fromOffset(18,305),18,palette.Accent); timer.Font=Enum.Font.GothamBold

local progressTrack=Instance.new("Frame")
progressTrack.Name="TradeProgressTrack"; progressTrack.Position=UDim2.fromOffset(18,333); progressTrack.Size=UDim2.new(1,-36,0,5); progressTrack.BackgroundColor3=palette.Raised; progressTrack.BorderSizePixel=0; progressTrack.Parent=panel; corner(progressTrack,3)
local TradeProgress=Instance.new("Frame")
TradeProgress.Name="TradeProgress"; TradeProgress.Size=UDim2.new(0,0,1,0); TradeProgress.BackgroundColor3=palette.Accent; TradeProgress.BorderSizePixel=0; TradeProgress.Parent=progressTrack; corner(TradeProgress,3)
local progressText=label(panel,"",UDim2.fromOffset(90,16),UDim2.new(1,-108,0,318),9,palette.Muted); progressText.TextXAlignment=Enum.TextXAlignment.Right

local yourBadge=label(panel,"YOU: WAITING",UDim2.fromOffset(126,20),UDim2.fromOffset(18,344),9,palette.Muted); yourBadge.Font=Enum.Font.GothamBold
local partnerBadge=label(panel,"THEM: WAITING",UDim2.fromOffset(130,20),UDim2.fromOffset(148,344),9,palette.Muted); partnerBadge.Font=Enum.Font.GothamBold
local reviewBanner=label(panel,"",UDim2.fromOffset(120,20),UDim2.new(1,-138,0,344),9,palette.Warn); reviewBanner.TextXAlignment=Enum.TextXAlignment.Right; reviewBanner.Font=Enum.Font.GothamBold

local offer=button(panel,"SET / UPDATE OFFER",UDim2.fromOffset(185,40),UDim2.fromOffset(18,370))
local test=button(panel,"START 2:00 TEST DRIVE",UDim2.fromOffset(185,40),UDim2.fromOffset(216,370)); test.BackgroundColor3=Color3.fromRGB(22,67,86)
local cancel=button(panel,"CANCEL",UDim2.fromOffset(110,34),UDim2.fromOffset(18,416)); cancel.TextColor3=palette.Danger
local accept=button(panel,"ACCEPT SWAP",UDim2.fromOffset(253,34),UDim2.fromOffset(148,416)); accept.BackgroundColor3=Color3.fromRGB(25,82,58); accept.TextColor3=palette.Good

local overview:any={Blueprints={},Players={},Session=nil,TestDriveSeconds=120}
local currentSession:any=nil
local localTestEndAt:number?=nil
local partnerIndex=1
local vehicleIndex=1
local visible=false
local busy=false
local lastRenderedState:string?=nil

local function selectedPartner(): any return overview.Players and overview.Players[partnerIndex] end
local function selectedVehicle(): any return overview.Blueprints and overview.Blueprints[vehicleIndex] end
local function cycleDelta(list:any,index:number,delta:number):number
	if type(list)~="table" or #list==0 then return 1 end
	return ((index-1+delta)%#list)+1
end
local function updateSelectors()
	local p=selectedPartner(); partnerButton.Text=p and shortName(p.DisplayName) or "No player"
	local v=selectedVehicle(); vehicleButton.Text=v and shortName(v.Name) or "No saved vehicle"
	partnerButton.TextColor3=if p then palette.Accent else palette.Muted
end

local function drawTestTimer(remaining:number)
	remaining=math.max(0,remaining)
	local total=math.max(1,tonumber(overview.TestDriveSeconds) or 120)
	local mins=math.floor(remaining/60); local secs=math.floor(remaining%60)
	local fraction=math.clamp(remaining/total,0,1)
	local percent=math.floor(fraction*100+.5)
	timer.Text=string.format("TEST DRIVE  %d:%02d",mins,secs)
	progressText.Text=tostring(percent).."%"
	TradeProgress.Size=UDim2.new(fraction,0,1,0)
	local color=if remaining<=10 then palette.Danger elseif remaining<=30 then palette.Warn else palette.Accent
	timer.TextColor3=color; TradeProgress.BackgroundColor3=color
end

local function renderAcceptance(session:any?)
	local yours=session and session.YourAccepted==true
	local theirs=session and session.PartnerAccepted==true
	yourBadge.Text=if yours then "YOU: ACCEPTED ✓" else "YOU: WAITING"
	yourBadge.TextColor3=if yours then palette.Good else palette.Muted
	partnerBadge.Text=if theirs then "THEM: ACCEPTED ✓" else "THEM: WAITING"
	partnerBadge.TextColor3=if theirs then palette.Good else palette.Muted
end

local function renderSession(session:any?)
	currentSession=session
	local active=session~=nil and session.State~="Cancelled" and session.State~="Committed"
	invite.Visible=not active; partnerButton.Visible=not active; vehicleButton.Visible=true; partnerTitle.Visible=not active; vehicleTitle.Visible=true
	offer.Visible=active; test.Visible=active; cancel.Visible=active; accept.Visible=active
	renderAcceptance(session); reviewBanner.Text=""
	if not session then
		localTestEndAt=nil; sessionTitle.Text="NO ACTIVE TRADE"; offerLine.Text="Select a player and a saved vehicle to begin."; timer.Text=""; progressText.Text=""; TradeProgress.Size=UDim2.new(); return
	end
	local newState=tostring(session.State or "")
	if newState~=lastRenderedState then
		if newState=="Cancelled" then showToast("Trade cancelled: "..tostring(session.CancelReason or "Cancelled"),"warn")
		elseif newState=="Committed" then showToast("Vehicle swap complete and verified","good")
		elseif newState=="Review" then showToast("Test drive complete — review the swap","info") end
		lastRenderedState=newState
	end
	if session.State=="Cancelled" then
		localTestEndAt=nil; sessionTitle.Text="TRADE CANCELLED"; offerLine.Text=tostring(session.CancelReason or "Cancelled"); timer.Text=""; progressText.Text=""; TradeProgress.Size=UDim2.new(); return
	elseif session.State=="Committed" then
		localTestEndAt=nil; sessionTitle.Text="SWAP COMPLETE"; offerLine.Text="Vehicle ownership was exchanged and saved."; timer.Text="TRANSFER VERIFIED"; timer.TextColor3=palette.Good; progressText.Text="100%"; TradeProgress.Size=UDim2.fromScale(1,1); TradeProgress.BackgroundColor3=palette.Good; return
	end
	timer.TextColor3=palette.Accent
	sessionTitle.Text="TRADING WITH  "..string.upper(shortName(session.PartnerName or "PLAYER"))
	offerLine.Text=string.format("You: %s\nThem: %s",shortName(session.YourOffer or "choose a vehicle"),shortName(session.PartnerOffer or "waiting for offer"))
	if session.State=="Testing" then
		local remaining=math.max(0,tonumber(session.TestRemaining) or 0)
		localTestEndAt=os.clock()+remaining
		drawTestTimer(remaining)
	elseif session.State=="Review" then
		localTestEndAt=nil; timer.Text="TEST COMPLETE — DECIDE"; timer.TextColor3=palette.Warn; progressText.Text="0%"; TradeProgress.Size=UDim2.new(); reviewBanner.Text="REVIEW NOW"
	else
		localTestEndAt=nil; timer.Text="LOCK BOTH VEHICLES TO TEST"; progressText.Text=""; TradeProgress.Size=UDim2.new()
	end
	accept.Text=(session.YourAccepted==true) and "ACCEPTED ✓" or "ACCEPT SWAP"
	accept.TextColor3=(session.YourAccepted==true) and palette.Good or palette.Text
end

local function invoke(payload:any):(boolean,any)
	if busy then status.Text="BUSY"; status.TextColor3=palette.Warn; showToast("Trade request already in progress","warn"); return false,"BUSY" end
	busy=true
	local ok,a,b=pcall(function() return request:InvokeServer(payload) end)
	busy=false
	if not ok then status.Text="NETWORK ERROR"; status.TextColor3=palette.Danger; showToast("Trade network error","bad"); return false,a end
	if a~=true then local message=tostring(b or "REQUEST REJECTED"); status.Text=message; status.TextColor3=palette.Danger; showToast(message,"bad"); return false,b end
	status.Text="SERVER-VERIFIED TRANSFER"; status.TextColor3=palette.Muted
	return true,b
end

local function refresh()
	local ok,data=invoke({Action="Overview"})
	if ok and type(data)=="table" then overview=data; partnerIndex=math.clamp(partnerIndex,1,math.max(1,#overview.Players)); vehicleIndex=math.clamp(vehicleIndex,1,math.max(1,#overview.Blueprints)); updateSelectors(); renderSession(data.Session) end
end

local function applyLayout()
	local safe=math.clamp(tonumber(pref(ATTR_SAFE_MARGIN,16)) or 16,0,64)
	local compact=pref(ATTR_TRADE_COMPACT,false)==true
	launcher.Position=UDim2.new(1,-(112+safe),0,22+safe)
	panel.Position=UDim2.new(1,-safe,0,70+safe)
	panel.Size=if compact then UDim2.fromOffset(400,440) else UDim2.fromOffset(420,454)
	partnerButton.Size=if compact then UDim2.fromOffset(175,38) else UDim2.fromOffset(185,42)
	vehicleButton.Size=partnerButton.Size
end

local function setVisible(value:boolean)
	visible=value; panel.Visible=value; applyLayout()
	if value then
		refresh()
		if pref(ATTR_REDUCED_MOTION,false)==true then return end
		panel.Position=UDim2.new(1,-4,0,panel.Position.Y.Offset); panel.BackgroundTransparency=.15
		TweenService:Create(panel,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(1,-math.clamp(tonumber(pref(ATTR_SAFE_MARGIN,16)) or 16,0,64),0,panel.Position.Y.Offset),BackgroundTransparency=0}):Play()
	end
end

local function sendInvite()
	local p,v=selectedPartner(),selectedVehicle(); if not p or not v then status.Text="SELECT PLAYER + VEHICLE"; status.TextColor3=palette.Danger; return end
	local ok,data=invoke({Action="Invite",TargetUserId=p.UserId,BlueprintName=v.Name}); if ok then renderSession(data) end
end
local function updateOffer()
	local v=selectedVehicle(); if not v then status.Text="SELECT A VEHICLE"; return end
	local ok,data=invoke({Action="SetOffer",BlueprintName=v.Name}); if ok then renderSession(data) end
end
local function startTest()
	local ok,data=invoke({Action="StartTest"}); if ok then renderSession(data) end
end
local function cancelTrade()
	invoke({Action="Cancel"}); refresh()
end
local function toggleAccept()
	local desired=not (currentSession and currentSession.YourAccepted==true)
	local ok,data=invoke({Action="Accept",Accepted=desired}); if ok and type(data)=="table" then renderSession(data) end
end
local function primaryAction()
	if not currentSession or currentSession.State=="Cancelled" or currentSession.State=="Committed" then sendInvite(); return end
	if currentSession.State=="Review" then toggleAccept(); return end
	if currentSession.State=="Testing" then status.Text="TEST DRIVE IN PROGRESS"; return end
	updateOffer()
end

launcher.MouseButton1Click:Connect(function() setVisible(not visible) end)
close.MouseButton1Click:Connect(function() setVisible(false) end)
partnerButton.MouseButton1Click:Connect(function() partnerIndex=cycleDelta(overview.Players,partnerIndex,1); updateSelectors() end)
vehicleButton.MouseButton1Click:Connect(function() vehicleIndex=cycleDelta(overview.Blueprints,vehicleIndex,1); updateSelectors() end)
invite.MouseButton1Click:Connect(sendInvite)
offer.MouseButton1Click:Connect(updateOffer)
test.MouseButton1Click:Connect(startTest)
cancel.MouseButton1Click:Connect(cancelTrade)
accept.MouseButton1Click:Connect(toggleAccept)

stateEvent.OnClientEvent:Connect(function(session:any)
	local hadSession=currentSession~=nil
	renderSession(session)
	if not visible and session and session.State=="Selecting" then setVisible(true); if not hadSession then showToast("Incoming vehicle trade","info") end end
end)

UserInputService.InputBegan:Connect(function(input:InputObject,processed:boolean)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode==Enum.KeyCode.T then setVisible(not visible); return end
	if not visible then return end
	if input.KeyCode==Enum.KeyCode.Escape then setVisible(false); return end
	if input.KeyCode==Enum.KeyCode.F5 then refresh(); return end
	if input.KeyCode==Enum.KeyCode.Left then partnerIndex=cycleDelta(overview.Players,partnerIndex,-1); updateSelectors(); return end
	if input.KeyCode==Enum.KeyCode.Right then partnerIndex=cycleDelta(overview.Players,partnerIndex,1); updateSelectors(); return end
	if input.KeyCode==Enum.KeyCode.Up then vehicleIndex=cycleDelta(overview.Blueprints,vehicleIndex,-1); updateSelectors(); return end
	if input.KeyCode==Enum.KeyCode.Down then vehicleIndex=cycleDelta(overview.Blueprints,vehicleIndex,1); updateSelectors(); return end
	if input.KeyCode==Enum.KeyCode.Return then primaryAction(); return end
end)

for _,attribute in ipairs({ATTR_TRADE_COMPACT,ATTR_SAFE_MARGIN,ATTR_REDUCED_MOTION,ATTR_STREAMER_MODE}) do
	player:GetAttributeChangedSignal(attribute):Connect(function() applyLayout(); updateSelectors(); if currentSession then renderSession(currentSession) end end)
end

task.spawn(function()
	while gui.Parent do
		task.wait(.25)
		if currentSession and currentSession.State=="Testing" and localTestEndAt then
			local remaining=math.max(0,localTestEndAt-os.clock())
			currentSession.TestRemaining=remaining
			drawTestTimer(remaining)
		end
	end
end)

applyLayout(); renderSession(nil); updateSelectors()
