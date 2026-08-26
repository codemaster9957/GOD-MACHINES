--!nonstrict
-- GOD MACHINES quality-of-life shell. This script never mutates gameplay authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local Mouse = player:GetMouse()
local QoLDefinitions = require(ReplicatedStorage:WaitForChild("MechFramework"):WaitForChild("Shared"):WaitForChild("QoLDefinitions"))

local PREFIX = "GMQoL_"
local connections = {}
local tooltipConnections = setmetatable({}, {__mode="k"})
local focusConnections = setmetatable({}, {__mode="k"})
local favoriteVisibility = nil
local favoritesOnly = false
local currentTarget = nil
local currentTargetMech = nil
local TargetMechId = nil
local TargetComponentId = nil
local primaryHeld = false
local secondaryHeld = false
local lastTargetUpdate = 0

local function track(connection)
	table.insert(connections, connection)
	return connection
end

local function attr(key)
	local value = player:GetAttribute(PREFIX .. key)
	if value == nil then return QoLDefinitions.GetDefault(key) end
	return value
end

local function setAttr(key, value)
	player:SetAttribute(PREFIX .. key, value)
end

for key, value in pairs(QoLDefinitions.Defaults) do
	if player:GetAttribute(PREFIX .. key) == nil then player:SetAttribute(PREFIX .. key, value) end
end

local oldGui = playerGui:FindFirstChild("GodMachinesQoL")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "GodMachinesQoL"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 90
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local colors = {
	bg=Color3.fromRGB(8,11,15), panel=Color3.fromRGB(17,22,29), raised=Color3.fromRGB(27,34,43),
	line=Color3.fromRGB(69,82,96), text=Color3.fromRGB(240,244,247), muted=Color3.fromRGB(151,160,170),
	amber=Color3.fromRGB(255,178,48), good=Color3.fromRGB(88,227,139), bad=Color3.fromRGB(255,80,78), blue=Color3.fromRGB(93,173,255),
}

local function corner(parent, radius)
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,radius or 6); c.Parent=parent; return c
end
local function stroke(parent, color, transparency, thickness)
	local s=Instance.new("UIStroke"); s.Color=color or colors.line; s.Transparency=transparency or 0; s.Thickness=thickness or 1; s.Parent=parent; return s
end
local function label(parent, text, size, position, textSize, bold)
	local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Size=size; l.Position=position; l.Text=text or ""; l.TextSize=textSize or 11
	l.Font=if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium; l.TextColor3=colors.text; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent; return l
end
local function button(parent, text, size, position)
	local b=Instance.new("TextButton"); b.AutoButtonColor=false; b.BackgroundColor3=colors.raised; b.BorderSizePixel=0; b.Size=size; b.Position=position
	b.Text=text; b.TextSize=11; b.Font=Enum.Font.GothamBold; b.TextColor3=colors.text; b.Parent=parent; corner(b,6); stroke(b,colors.line,.25,1); return b
end
local function frame(parent, name, size, position)
	local f=Instance.new("Frame"); f.Name=name; f.BorderSizePixel=0; f.BackgroundColor3=colors.panel; f.Size=size; f.Position=position; f.Parent=parent; corner(f,8); stroke(f,colors.line,.3,1); return f
end

local toastBridge = playerScripts:FindFirstChild("GMQoLToast")
local ownsToastBridge = false
if not toastBridge then
	toastBridge=Instance.new("BindableEvent"); toastBridge.Name="GMQoLToast"; toastBridge.Parent=playerScripts; ownsToastBridge=true
end

local toastHost=Instance.new("Frame")
toastHost.Name="ToastHost"; toastHost.AnchorPoint=Vector2.new(1,0); toastHost.Position=UDim2.new(1,-16,0,18); toastHost.Size=UDim2.fromOffset(340,220); toastHost.BackgroundTransparency=1; toastHost.Parent=gui
local toastLayout=Instance.new("UIListLayout"); toastLayout.HorizontalAlignment=Enum.HorizontalAlignment.Right; toastLayout.VerticalAlignment=Enum.VerticalAlignment.Top; toastLayout.Padding=UDim.new(0,7); toastLayout.Parent=toastHost

local function showToast(text, tone)
	text=tostring(text or "")
	if text=="" then return end
	local glyph="•"
	if attr("ColorblindGlyphs") then
		if tone=="good" then glyph="✓" elseif tone=="bad" then glyph="!" elseif tone=="warn" then glyph="▲" else glyph="i" end
	end
	local toast=frame(toastHost,"Toast",UDim2.fromOffset(330,42),UDim2.new())
	toast.LayoutOrder=-math.floor(os.clock()*1000)
	local rail=Instance.new("Frame"); rail.BorderSizePixel=0; rail.Size=UDim2.fromOffset(4,30); rail.Position=UDim2.fromOffset(7,6); rail.Parent=toast; corner(rail,2)
	rail.BackgroundColor3=if tone=="good" then colors.good elseif tone=="bad" then colors.bad elseif tone=="warn" then colors.amber else colors.blue
	local txt=label(toast,glyph.."  "..text,UDim2.new(1,-28,1,0),UDim2.fromOffset(20,0),11,true); txt.TextTruncate=Enum.TextTruncate.AtEnd
	if not attr("ReducedMotion") then
		toast.Position=UDim2.fromOffset(30,0); toast.BackgroundTransparency=1
		TweenService:Create(toast,TweenInfo.new(.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(),BackgroundTransparency=0}):Play()
	end
	task.delay(math.clamp(tonumber(attr("ToastDuration")) or 2.4,.6,8),function()
		if not toast.Parent then return end
		if attr("ReducedMotion") then toast:Destroy() else
			local t=TweenService:Create(toast,TweenInfo.new(.15),{BackgroundTransparency=1}); t:Play(); t.Completed:Once(function() if toast.Parent then toast:Destroy() end end)
		end
	end)
end
track((toastBridge :: BindableEvent).Event:Connect(showToast))

local combatHud=Instance.new("Frame")
combatHud.Name="CombatHUD"; combatHud.Size=UDim2.fromScale(1,1); combatHud.BackgroundTransparency=1; combatHud.Parent=gui

local Crosshair=Instance.new("Frame")
Crosshair.Name="Crosshair"; Crosshair.AnchorPoint=Vector2.new(.5,.5); Crosshair.Position=UDim2.fromScale(.5,.5); Crosshair.Size=UDim2.fromOffset(50,50); Crosshair.BackgroundTransparency=1; Crosshair.Parent=combatHud
local crossPieces={}
for i=1,4 do local p=Instance.new("Frame"); p.Name="CrosshairLine"..i; p.BorderSizePixel=0; p.BackgroundColor3=colors.text; p.Parent=Crosshair; crossPieces[i]=p end

local targetChip=frame(combatHud,"TargetChip",UDim2.fromOffset(270,34),UDim2.new(.5,-135,.5,34))
targetChip.BackgroundTransparency=.18
local targetText=label(targetChip,"NO TARGET",UDim2.new(1,-16,1,0),UDim2.fromOffset(8,0),10,true); targetText.TextXAlignment=Enum.TextXAlignment.Center

local controlsChip=frame(combatHud,"ControlHelp",UDim2.fromOffset(420,34),UDim2.new(.5,-210,1,-54))
local controlsText=label(controlsChip,"LMB PRIMARY   RMB SECONDARY   R RELOAD   Q/E UTILITY   1/2 MECHANISMS",UDim2.new(1,-12,1,0),UDim2.fromOffset(6,0),9,true); controlsText.TextXAlignment=Enum.TextXAlignment.Center

local inputChip=frame(combatHud,"InputStatus",UDim2.fromOffset(178,28),UDim2.new(.5,-89,.5,74))
local inputText=label(inputChip,"P —    S —",UDim2.new(1,-10,1,0),UDim2.fromOffset(5,0),9,true); inputText.TextXAlignment=Enum.TextXAlignment.Center

local componentHighlight=Instance.new("Highlight")
componentHighlight.Name="GMQoLComponentHighlight"; componentHighlight.FillTransparency=.84; componentHighlight.OutlineTransparency=.05; componentHighlight.FillColor=colors.amber; componentHighlight.OutlineColor=colors.amber; componentHighlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; componentHighlight.Enabled=false; componentHighlight.Parent=workspace.CurrentCamera or workspace
local mechHighlight=Instance.new("Highlight")
mechHighlight.Name="GMQoLMechHighlight"; mechHighlight.FillTransparency=1; mechHighlight.OutlineTransparency=.55; mechHighlight.OutlineColor=colors.blue; mechHighlight.DepthMode=Enum.HighlightDepthMode.Occluded; mechHighlight.Enabled=false; mechHighlight.Parent=workspace.CurrentCamera or workspace

local function findTarget(instance)
	local component=nil; local mech=nil; local mechId=nil; local componentId=nil; local current=instance
	while current do
		local m=current:GetAttribute("MechId")
		local c=current:GetAttribute("ComponentId")
		if type(m)=="string" then mechId=m; mech=mech or current end
		if type(c)=="string" then componentId=c; component=component or current end
		if mechId and componentId then break end
		current=current.Parent
	end
	if component and component.Parent and component.Parent:IsA("Model") then component=component.Parent end
	if component then
		local p=component
		while p and p.Parent do
			if p:IsA("Model") and p:GetAttribute("MechId")==mechId then mech=p end
			p=p.Parent
		end
	end
	return component,mech,mechId,componentId
end

local function updateCrosshair()
	local size=math.clamp(tonumber(attr("CrosshairSize")) or 10,4,22)
	local gap=math.clamp(tonumber(attr("CrosshairGap")) or 5,1,16)
	local alpha=1-math.clamp(tonumber(attr("CrosshairOpacity")) or .9,.1,1)
	for _,p in ipairs(crossPieces) do p.BackgroundTransparency=alpha end
	crossPieces[1].Size=UDim2.fromOffset(size,2); crossPieces[1].Position=UDim2.new(.5,gap, .5,-1)
	crossPieces[2].Size=UDim2.fromOffset(size,2); crossPieces[2].AnchorPoint=Vector2.new(1,0); crossPieces[2].Position=UDim2.new(.5,-gap,.5,-1)
	crossPieces[3].Size=UDim2.fromOffset(2,size); crossPieces[3].Position=UDim2.new(.5,-1,.5,gap)
	crossPieces[4].Size=UDim2.fromOffset(2,size); crossPieces[4].AnchorPoint=Vector2.new(0,1); crossPieces[4].Position=UDim2.new(.5,-1,.5,-gap)
end

local function clearTarget()
	currentTarget=nil; currentTargetMech=nil; TargetMechId=nil; TargetComponentId=nil
	componentHighlight.Adornee=nil; componentHighlight.Enabled=false; mechHighlight.Adornee=nil; mechHighlight.Enabled=false; targetText.Text="NO TARGET"
end

local function updateTarget()
	local activeMech=player:GetAttribute("ActiveMechId")
	local combatActive=player:GetAttribute("BuildMode")~=true and type(activeMech)=="string" and activeMech~=""
	combatHud.Visible=combatActive
	local density=math.clamp(tonumber(attr("ChipDensity")) or 1,0,2)
	targetChip.Visible=combatActive and density>=1
	inputChip.Visible=combatActive and density>=1
	controlsChip.Visible=combatActive and density>=2 and attr("ControlHelp")~=false and not attr("HideHints")
	if not combatActive then clearTarget(); return end
	local target=Mouse.Target
	local component,mech,mechId,componentId=findTarget(target)
	currentTarget=component; currentTargetMech=mech; TargetMechId=mechId; TargetComponentId=componentId
	local performance=attr("PerformanceMode")==true
	componentHighlight.Enabled=component~=nil and not performance; componentHighlight.Adornee=if componentHighlight.Enabled then component else nil
	mechHighlight.Enabled=mech~=nil and not performance; mechHighlight.Adornee=if mechHighlight.Enabled then mech else nil
	if mechId then
		local shortMech=mechId; if #shortMech>13 then shortMech=shortMech:sub(1,10).."…" end
		local shortComponent=tostring(componentId or "MACHINE"); if #shortComponent>13 then shortComponent=shortComponent:sub(1,10).."…" end
		targetText.Text="TARGET  "..string.upper(shortMech).."  /  "..string.upper(shortComponent)
	else targetText.Text="NO TARGET" end
	inputText.Text=(primaryHeld and "P ●" or "P —").."    "..(secondaryHeld and "S ●" or "S —")
	inputText.TextColor3=if primaryHeld or secondaryHeld then colors.amber else colors.muted
end

local workshopChip=frame(gui,"WorkshopQoLChip",UDim2.fromOffset(360,54),UDim2.new(1,-376,1,-72))
local workshopLine=label(workshopChip,"",UDim2.new(1,-12,0,20),UDim2.fromOffset(6,5),9,true)
local workshopState=label(workshopChip,"",UDim2.new(1,-12,0,18),UDim2.fromOffset(6,28),9,false); workshopState.TextColor3=colors.muted

local function workshopGui()
	local w=playerGui:FindFirstChild("GodMachinesBuildUI")
	return if w and w:IsA("ScreenGui") then w else nil
end
local function workshopSearch()
	local w=workshopGui(); if not w then return nil end
	for _,d in ipairs(w:GetDescendants()) do if d:IsA("TextBox") and tostring(d.PlaceholderText):find("SEARCH COMPONENTS") then return d end end
	return nil
end
local function releaseOwnedFocus()
	local focused=UserInputService:GetFocusedTextBox()
	if not focused then return end
	local workshop=workshopGui()
	if focused:IsDescendantOf(gui) or (workshop and focused:IsDescendantOf(workshop)) then
		focused:ReleaseFocus()
	end
end
local function catalogGrid()
	local w=workshopGui(); return w and w:FindFirstChild("CatalogCardGrid",true) or nil
end
local function focusWorkshopSearch()
	local search=workshopSearch(); if search then search:CaptureFocus(); return true end
	return false
end
local function cycleWorkshopTab(delta)
	local w=workshopGui(); if not w then return end
	local names={"PARTPage","PAINTPage","BLUEPRINTSPage","CONTROLSPage"}
	local pages={}; local current=1
	for i,name in ipairs(names) do local p=w:FindFirstChild(name,true); pages[i]=p; if p and p:IsA("GuiObject") and p.Visible then current=i end end
	local nextIndex=((current-1+delta)%#names)+1
	for i,p in ipairs(pages) do if p and p:IsA("GuiObject") then p.Visible=i==nextIndex end end
end
local function isFavoriteCard(card)
	for _,d in ipairs(card:GetDescendants()) do if (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Text=="★" then return true end end
	return false
end
local function setFavoritesFilter(enabled)
	local grid=catalogGrid(); if not grid then return end
	if enabled and not favoritesOnly then
		favoriteVisibility={}
		for _,card in ipairs(grid:GetChildren()) do if card:IsA("GuiObject") and card.Name:sub(1,5)=="Card_" then favoriteVisibility[card]=card.Visible; card.Visible=card.Visible and isFavoriteCard(card) end end
		favoritesOnly=true; showToast("Workshop: favourites only","good")
	elseif not enabled and favoritesOnly then
		for card,wasVisible in pairs(favoriteVisibility or {}) do if card.Parent then card.Visible=wasVisible end end
		favoriteVisibility=nil; favoritesOnly=false; showToast("Workshop filter cleared","info")
	end
end
local function updateWorkshopChip()
	local w=workshopGui(); local active=player:GetAttribute("BuildMode")==true and w~=nil
	local density=math.clamp(tonumber(attr("ChipDensity")) or 1,0,2)
	workshopChip.Visible=active and density>=1 and not attr("HideHints")
	if not active then return end
	local grid=catalogGrid(); local visible,total=0,0
	if grid then for _,card in ipairs(grid:GetChildren()) do if card:IsA("GuiObject") and card.Name:sub(1,5)=="Card_" then total+=1; if card.Visible then visible+=1 end end end end
	workshopLine.Text=string.format("%d / %d COMPONENTS   •   / SEARCH   •   TAB PAGES",visible,total)
	local search=workshopSearch(); local query=search and search.Text or ""
	workshopState.Text=if favoritesOnly then "FILTER: ★ FAVOURITES" elseif query~="" then "SEARCH: "..string.upper(query) else "CTRL+Z/Y HISTORY   •   CTRL+D COPY   •   BACKSPACE REMOVE"
end

local tooltip=frame(gui,"Tooltip",UDim2.fromOffset(260,32),UDim2.fromOffset(0,0)); tooltip.Visible=false; tooltip.ZIndex=200
local tooltipText=label(tooltip,"",UDim2.new(1,-12,1,0),UDim2.fromOffset(6,0),9,true); tooltipText.TextTruncate=Enum.TextTruncate.AtEnd; tooltipText.ZIndex=201
local tooltipToken=0
local overlayShade=nil
local commandPalette=nil
local settingsPanel=nil
local function bindTooltip(object)
	if tooltipConnections[object] or not object:IsA("GuiButton") or object:IsDescendantOf(gui) then return end
	local entered=object.MouseEnter:Connect(function()
		if attr("Tooltips")~=true or attr("PerformanceMode")==true then return end
		tooltipToken+=1; local token=tooltipToken
		task.delay(math.clamp(tonumber(attr("TooltipDelay")) or .45,.05,2),function()
			if token~=tooltipToken or not object.Parent or attr("Tooltips")~=true then return end
			local text=if object:IsA("TextButton") then tostring(object.Text) else object.Name; if text=="" then text=object.Name end
			tooltipText.Text=text; tooltip.Position=UDim2.fromOffset(Mouse.X+14,Mouse.Y+16); tooltip.Visible=true
		end)
	end)
	local left=object.MouseLeave:Connect(function() tooltipToken+=1; tooltip.Visible=false end)
	tooltipConnections[object]={entered,left}
end
local function bindFocus(textBox)
	if focusConnections[textBox] or not textBox:IsA("TextBox") then return end
	local focusStroke=nil
	local a=textBox.Focused:Connect(function()
		if attr("FocusOutline")~=true then return end
		focusStroke=stroke(textBox,colors.amber,.05,2); focusStroke.Name="GMQoLFocusOutline"
	end)
	local b=textBox.FocusLost:Connect(function() if focusStroke then focusStroke:Destroy(); focusStroke=nil end end)
	focusConnections[textBox]={a,b}
end

local function applyAccessibility()
	updateCrosshair()
	local scale=math.clamp(tonumber(attr("UIScale")) or 1,.75,1.35)
	local large=attr("LargeText")==true
	local high=attr("HighContrast")==true
	local hudOpacity=math.clamp(tonumber(attr("HUDOpacity")) or 1,.35,1)
	local panelOpacity=math.clamp(tonumber(attr("PanelOpacity")) or 1,.3,1)
	local compact=attr("CompactHUD")==true
	local safe=math.clamp(tonumber(attr("SafeMargin")) or 16,0,64)
	toastHost.Position=UDim2.new(1,-safe,0,safe)
	workshopChip.Position=UDim2.new(1,-(compact and 346 or 376),1,-(56+safe))
	workshopChip.Size=UDim2.fromOffset(compact and 330 or 360,compact and 46 or 54)
	targetChip.Size=UDim2.fromOffset(compact and 220 or 270,compact and 28 or 34)
	targetChip.Position=UDim2.new(.5,-(compact and 110 or 135),.5,34)
	inputChip.Size=UDim2.fromOffset(compact and 142 or 178,compact and 24 or 28)
	inputChip.Position=UDim2.new(.5,-(compact and 71 or 89),.5,compact and 66 or 74)
	controlsChip.Size=UDim2.fromOffset(compact and 360 or 420,compact and 28 or 34)
	controlsChip.Position=UDim2.new(.5,-(compact and 180 or 210),1,-(38+safe))
	for _,screen in ipairs(playerGui:GetChildren()) do
		if not screen:IsA("ScreenGui") then continue end
		for _,root in ipairs(screen:GetChildren()) do
			if root:IsA("GuiObject") and root~=combatHud and root~=overlayShade then
				local scaler=root:FindFirstChild("GMQoLScale")
				if not scaler then scaler=Instance.new("UIScale"); scaler.Name="GMQoLScale"; scaler.Parent=root end
				scaler.Scale=scale
			end
		end
		for _,d in ipairs(screen:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				if d:GetAttribute("GMQoLBaseTextSize")==nil then d:SetAttribute("GMQoLBaseTextSize",d.TextSize) end
				local base=tonumber(d:GetAttribute("GMQoLBaseTextSize")) or d.TextSize
				d.TextSize=math.max(7,math.floor(base*(large and 1.16 or 1)+.5))
				d.TextStrokeTransparency=if high then .55 else 1
				if d:IsA("TextBox") then bindFocus(d) end
			end
			if d:IsA("GuiButton") then bindTooltip(d) end
		end
	end
	for _,d in ipairs(combatHud:GetDescendants()) do if d:IsA("Frame") and d.BackgroundTransparency<1 then
		if d:GetAttribute("GMQoLBaseTransparency")==nil then d:SetAttribute("GMQoLBaseTransparency",d.BackgroundTransparency) end
		local base=tonumber(d:GetAttribute("GMQoLBaseTransparency")) or 0
		d.BackgroundTransparency=1-(1-base)*hudOpacity
	end end
	for _,panelItem in ipairs({workshopChip,targetChip,controlsChip,inputChip,commandPalette,settingsPanel}) do
		if panelItem then
			if panelItem:GetAttribute("GMQoLBasePanelTransparency")==nil then panelItem:SetAttribute("GMQoLBasePanelTransparency",panelItem.BackgroundTransparency) end
			local base=tonumber(panelItem:GetAttribute("GMQoLBasePanelTransparency")) or 0
			panelItem.BackgroundTransparency=1-(1-base)*panelOpacity
		end
	end
	workshopChip.Visible=workshopChip.Visible and not attr("HideHints")
end

overlayShade=Instance.new("Frame"); overlayShade.Name="OverlayShade"; overlayShade.Size=UDim2.fromScale(1,1); overlayShade.BackgroundColor3=colors.bg; overlayShade.BackgroundTransparency=.35; overlayShade.BorderSizePixel=0; overlayShade.Visible=false; overlayShade.Parent=gui

commandPalette=frame(gui,"CommandPalette",UDim2.fromOffset(520,360),UDim2.new(.5,-260,.18,0)); commandPalette.Visible=false; commandPalette.ZIndex=110
local commandTitle=label(commandPalette,"COMMAND PALETTE   [CTRL+K]",UDim2.new(1,-28,0,30),UDim2.fromOffset(14,10),13,true); commandTitle.TextColor3=colors.amber; commandTitle.ZIndex=111
local commandSearch=Instance.new("TextBox"); commandSearch.Name="CommandSearch"; commandSearch.Size=UDim2.new(1,-28,0,38); commandSearch.Position=UDim2.fromOffset(14,48); commandSearch.BackgroundColor3=colors.bg; commandSearch.BorderSizePixel=0; commandSearch.PlaceholderText="SEARCH COMMANDS..."; commandSearch.ClearTextOnFocus=false; commandSearch.Text=""; commandSearch.TextColor3=colors.text; commandSearch.PlaceholderColor3=colors.muted; commandSearch.TextSize=12; commandSearch.Font=Enum.Font.GothamMedium; commandSearch.ZIndex=111; commandSearch.Parent=commandPalette; corner(commandSearch,6); stroke(commandSearch,colors.line,.1,1)
local commandList=Instance.new("ScrollingFrame"); commandList.Name="CommandList"; commandList.Position=UDim2.fromOffset(14,96); commandList.Size=UDim2.new(1,-28,1,-110); commandList.BackgroundTransparency=1; commandList.BorderSizePixel=0; commandList.ScrollBarThickness=3; commandList.AutomaticCanvasSize=Enum.AutomaticSize.Y; commandList.CanvasSize=UDim2.new(); commandList.ZIndex=111; commandList.Parent=commandPalette
local commandLayout=Instance.new("UIListLayout"); commandLayout.Padding=UDim.new(0,6); commandLayout.Parent=commandList

settingsPanel=frame(gui,"QoLSettings",UDim2.fromOffset(560,560),UDim2.new(.5,-280,.5,-280)); settingsPanel.Visible=false; settingsPanel.ZIndex=115
local settingsTitle=label(settingsPanel,"QUALITY OF LIFE   •   100 IMPROVEMENTS",UDim2.new(1,-110,0,34),UDim2.fromOffset(16,10),14,true); settingsTitle.TextColor3=colors.amber; settingsTitle.ZIndex=116
local settingsClose=button(settingsPanel,"CLOSE [F10]",UDim2.fromOffset(94,30),UDim2.new(1,-108,0,10)); settingsClose.ZIndex=116
local settingsScroll=Instance.new("ScrollingFrame"); settingsScroll.Position=UDim2.fromOffset(14,54); settingsScroll.Size=UDim2.new(1,-28,1,-68); settingsScroll.BackgroundTransparency=1; settingsScroll.BorderSizePixel=0; settingsScroll.ScrollBarThickness=4; settingsScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; settingsScroll.CanvasSize=UDim2.new(); settingsScroll.ZIndex=116; settingsScroll.Parent=settingsPanel
local settingsLayout=Instance.new("UIListLayout"); settingsLayout.Padding=UDim.new(0,6); settingsLayout.Parent=settingsScroll

local function panelVisibility()
	overlayShade.Visible=commandPalette.Visible or settingsPanel.Visible
end
local function toggleSettings()
	settingsPanel.Visible=not settingsPanel.Visible
	if settingsPanel.Visible then
		if commandPalette.Visible then commandPalette.Visible=false; releaseOwnedFocus() end
	else
		releaseOwnedFocus()
	end
	panelVisibility()
end
local function toggleCommandPalette()
	commandPalette.Visible=not commandPalette.Visible
	if commandPalette.Visible then
		settingsPanel.Visible=false; commandSearch.Text=""; commandSearch:CaptureFocus()
	else
		releaseOwnedFocus()
	end
	panelVisibility()
end
settingsClose.MouseButton1Click:Connect(toggleSettings)

local function resetSettings()
	for key,value in pairs(QoLDefinitions.Defaults) do setAttr(key,value) end
	showToast("QoL settings restored to defaults","good")
end

local commands={
	{Name="OPEN QOL SETTINGS", Run=toggleSettings},
	{Name="FOCUS WORKSHOP SEARCH", Run=focusWorkshopSearch},
	{Name="CLEAR WORKSHOP FILTER", Run=function() local s=workshopSearch(); if s then s.Text="" end; setFavoritesFilter(false) end},
	{Name="TOGGLE COMPACT HUD", Run=function() setAttr("CompactHUD",not attr("CompactHUD")) end},
	{Name="TOGGLE CONTROL HELP", Run=function() setAttr("ControlHelp",not attr("ControlHelp")) end},
	{Name="TOGGLE HINTS", Run=function() setAttr("HideHints",not attr("HideHints")) end},
	{Name="TOGGLE PERFORMANCE MODE", Run=function() setAttr("PerformanceMode",not attr("PerformanceMode")) end},
	{Name="TOGGLE STREAMER MODE", Run=function() setAttr("StreamerMode",not attr("StreamerMode")) end},
	{Name="RESET QOL SETTINGS", Run=resetSettings},
}
local commandButtons={}
local function refreshCommands()
	local q=string.lower(commandSearch.Text or "")
	for _,entry in ipairs(commandButtons) do entry.Button.Visible=q=="" or string.find(string.lower(entry.Name),q,1,true)~=nil end
end
for _,command in ipairs(commands) do
	local b=button(commandList,command.Name,UDim2.new(1,-4,0,34),UDim2.new()); b.ZIndex=112; b.TextXAlignment=Enum.TextXAlignment.Left
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,10); pad.Parent=b
	b.MouseButton1Click:Connect(function() commandPalette.Visible=false; panelVisibility(); command.Run(); commandSearch:ReleaseFocus() end)
	table.insert(commandButtons,{Name=command.Name,Button=b,Run=command.Run})
end
commandSearch:GetPropertyChangedSignal("Text"):Connect(refreshCommands)

local settingRows={}
local function settingRow(key, labelText, values)
	local row=frame(settingsScroll,"Setting_"..key,UDim2.new(1,-5,0,44),UDim2.new()); row.ZIndex=117
	local title=label(row,labelText,UDim2.new(.55,-10,1,0),UDim2.fromOffset(10,0),10,true); title.ZIndex=118
	local valueButton=button(row,"",UDim2.new(.42,-12,0,30),UDim2.new(.58,0,.5,-15)); valueButton.ZIndex=118
	local function textValue(v) if type(v)=="boolean" then return if v then "ON" else "OFF" elseif type(v)=="number" then return tostring(math.floor(v*100+0.5)/100) else return string.upper(tostring(v)) end end
	local function refresh() valueButton.Text=textValue(attr(key)); valueButton.TextColor3=if attr(key)==true then colors.good else colors.text end
	valueButton.MouseButton1Click:Connect(function()
		local current=attr(key)
		if type(current)=="boolean" then setAttr(key,not current)
		elseif values then
			local index=table.find(values,current) or 1; setAttr(key,values[index%#values+1])
		end
		refresh()
	end)
	track(player:GetAttributeChangedSignal(PREFIX..key):Connect(refresh)); refresh(); table.insert(settingRows,row)
end
settingRow("LargeText","LARGE TEXT")
settingRow("HighContrast","HIGH CONTRAST")
settingRow("ReducedMotion","REDUCED MOTION")
settingRow("UIScale","UI SCALE",{.8,.9,1,1.1,1.2,1.3})
settingRow("HUDOpacity","HUD OPACITY",{.45,.6,.75,.9,1})
settingRow("PanelOpacity","PANEL OPACITY",{.4,.55,.7,.85,1})
settingRow("SafeMargin","SAFE MARGIN",{8,16,24,32,40})
settingRow("CompactHUD","COMPACT HUD")
settingRow("Tooltips","TOOLTIPS")
settingRow("TooltipDelay","TOOLTIP DELAY",{.1,.25,.45,.7,1})
settingRow("ToastDuration","TOAST DURATION",{1.2,1.8,2.4,3.2,4})
settingRow("FocusOutline","FOCUS OUTLINE")
settingRow("ColorblindGlyphs","STATUS GLYPHS")
settingRow("StreamerMode","STREAMER MODE")
settingRow("PerformanceMode","PERFORMANCE MODE")
settingRow("HideHints","HIDE HINTS")
settingRow("ChipDensity","CHIP DENSITY",{0,1,2})
settingRow("CrosshairSize","CROSSHAIR SIZE",{6,8,10,12,16,20})
settingRow("CrosshairOpacity","CROSSHAIR OPACITY",{.4,.6,.75,.9,1})
settingRow("CrosshairGap","CROSSHAIR GAP",{2,4,5,7,10,14})
settingRow("QuickSwapCompact","COMPACT QUICK SWAP")
settingRow("QuickSwapHints","QUICK SWAP HINTS")
settingRow("TradeCompact","COMPACT TRADE")
settingRow("ControlHelp","DRIVING HELP")
local resetButton=button(settingsScroll,"RESET ALL QOL SETTINGS",UDim2.new(1,-5,0,40),UDim2.new()); resetButton.TextColor3=colors.bad; resetButton.ZIndex=118; resetButton.MouseButton1Click:Connect(resetSettings)

local function ctrlHeld() return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) end
local function shiftHeld() return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) end

track(UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then primaryHeld=true end
	if input.UserInputType==Enum.UserInputType.MouseButton2 then secondaryHeld=true end
	if processed and not commandPalette.Visible then return end
	local focused=UserInputService:GetFocusedTextBox()
	if focused then
		if commandPalette.Visible and focused==commandSearch and input.KeyCode==Enum.KeyCode.Return then
			for _,entry in ipairs(commandButtons) do if entry.Button.Visible then commandPalette.Visible=false; panelVisibility(); commandSearch:ReleaseFocus(); entry.Run(); break end end
		elseif input.KeyCode==Enum.KeyCode.Escape then
			if commandPalette.Visible then commandPalette.Visible=false; commandSearch:ReleaseFocus(); panelVisibility()
			elseif focused==workshopSearch() then focused.Text=""; focused:ReleaseFocus() end
		end
		return
	end
	if ctrlHeld() and input.KeyCode==Enum.KeyCode.K then toggleCommandPalette(); return end
	if input.KeyCode==Enum.KeyCode.F10 then toggleSettings(); return end
	if commandPalette.Visible or settingsPanel.Visible then
		if input.KeyCode==Enum.KeyCode.Escape then commandPalette.Visible=false; settingsPanel.Visible=false; releaseOwnedFocus(); panelVisibility() end
		return
	end
	if player:GetAttribute("BuildMode")==true then
		if input.KeyCode==Enum.KeyCode.Slash or (ctrlHeld() and input.KeyCode==Enum.KeyCode.F) then focusWorkshopSearch(); return end
		if input.KeyCode==Enum.KeyCode.Home then local grid=catalogGrid(); if grid and grid:IsA("ScrollingFrame") then grid.CanvasPosition=Vector2.new(0,0) end; return end
		if input.KeyCode==Enum.KeyCode.End then local grid=catalogGrid(); if grid and grid:IsA("ScrollingFrame") then grid.CanvasPosition=Vector2.new(0,math.max(0,grid.AbsoluteCanvasSize.Y-grid.AbsoluteSize.Y)) end; return end
		if input.KeyCode==Enum.KeyCode.Tab then cycleWorkshopTab(shiftHeld() and -1 or 1); return end
		if ctrlHeld() and shiftHeld() and input.KeyCode==Enum.KeyCode.F then setFavoritesFilter(false); return end
		if shiftHeld() and input.KeyCode==Enum.KeyCode.F then setFavoritesFilter(not favoritesOnly); return end
	end
end))
track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then primaryHeld=false end
	if input.UserInputType==Enum.UserInputType.MouseButton2 then secondaryHeld=false end
end))

for key in pairs(QoLDefinitions.Defaults) do track(player:GetAttributeChangedSignal(PREFIX..key):Connect(function() applyAccessibility(); updateWorkshopChip() end)) end
track(player:GetAttributeChangedSignal("BuildMode"):Connect(function() if player:GetAttribute("BuildMode")~=true then releaseOwnedFocus(); setFavoritesFilter(false) end; updateWorkshopChip(); updateTarget() end))
track(player:GetAttributeChangedSignal("ActiveMechId"):Connect(updateTarget))
track(playerGui.DescendantAdded:Connect(function(descendant) task.defer(function() if descendant:IsA("GuiButton") then bindTooltip(descendant) elseif descendant:IsA("TextBox") then bindFocus(descendant) end; applyAccessibility(); updateWorkshopChip() end) end))
track(playerGui.ChildAdded:Connect(function() task.defer(function() applyAccessibility(); updateWorkshopChip() end) end))
track(player.CharacterAdded:Connect(function() task.defer(function() applyAccessibility(); updateTarget() end) end))

track(RunService.RenderStepped:Connect(function()
	local now=os.clock(); local rate=if attr("PerformanceMode") then 1/15 else 1/30
	if now-lastTargetUpdate>=rate then lastTargetUpdate=now; updateTarget(); updateWorkshopChip() end
	if tooltip.Visible then tooltip.Position=UDim2.fromOffset(Mouse.X+14,Mouse.Y+16) end
end))

script.Destroying:Connect(function()
	releaseOwnedFocus()
	for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
	for _,pair in pairs(tooltipConnections) do for _,connection in ipairs(pair) do pcall(function() connection:Disconnect() end) end end
	for _,pair in pairs(focusConnections) do for _,connection in ipairs(pair) do pcall(function() connection:Disconnect() end) end end
	componentHighlight:Destroy(); mechHighlight:Destroy()
	if ownsToastBridge and toastBridge.Parent then toastBridge:Destroy() end
	if gui.Parent then gui:Destroy() end
end)

applyAccessibility()
updateCrosshair()
updateWorkshopChip()
updateTarget()
showToast("100 QoL improvements loaded","good")