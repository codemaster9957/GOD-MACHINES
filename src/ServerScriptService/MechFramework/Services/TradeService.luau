--!strict
-- Server-authoritative saved vehicle trading with a two-minute reciprocal test drive.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.MechFramework.Shared.VehicleTradeRules)

local Trade: any = {
	_sessions = {},
	_byUser = {},
	_save = nil,
	_match = nil,
	_remote = nil,
	_stateEvent = nil,
}

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out = {}
	for key,item in pairs(value) do out[key] = clone(item) end
	return out
end

local function userName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return player and player.DisplayName or ("User "..tostring(userId))
end

function Trade:Init(container: any)
	self._save = container:Get("SaveService")
	self._match = container:Get("MatchService")

	local framework = ReplicatedStorage:WaitForChild("MechFramework")
	local remotes = framework:WaitForChild("Remotes")
	local functions = remotes:FindFirstChild("Functions") or Instance.new("Folder")
	functions.Name = "Functions"; functions.Parent = remotes
	local events = remotes:FindFirstChild("Events") or Instance.new("Folder")
	events.Name = "Events"; events.Parent = remotes

	local request = functions:FindFirstChild("RequestVehicleTrade")
	if not request then request = Instance.new("RemoteFunction"); request.Name = "RequestVehicleTrade"; request.Parent = functions end
	assert(request:IsA("RemoteFunction"), "RequestVehicleTrade must be a RemoteFunction")
	self._remote = request

	local stateEvent = events:FindFirstChild("VehicleTradeState")
	if not stateEvent then stateEvent = Instance.new("RemoteEvent"); stateEvent.Name = "VehicleTradeState"; stateEvent.Parent = events end
	assert(stateEvent:IsA("RemoteEvent"), "VehicleTradeState must be a RemoteEvent")
	self._stateEvent = stateEvent
end

function Trade:_sessionFor(userId: number): any?
	local id = self._byUser[userId]
	return id and self._sessions[id] or nil
end

function Trade:_public(session: any, viewerId: number): any
	local snapshot = Rules.PublicSnapshot(session, os.clock())
	snapshot.PartnerUserId = Rules.OtherUser(session, viewerId)
	snapshot.PartnerName = snapshot.PartnerUserId and userName(snapshot.PartnerUserId) or ""
	snapshot.YourOffer = snapshot.Offers[viewerId]
	snapshot.PartnerOffer = snapshot.PartnerUserId and snapshot.Offers[snapshot.PartnerUserId] or nil
	snapshot.YourAccepted = snapshot.Accepted[viewerId] == true
	snapshot.PartnerAccepted = snapshot.PartnerUserId and snapshot.Accepted[snapshot.PartnerUserId] == true or false
	snapshot.LockedBlueprints = nil
	return snapshot
end

function Trade:_overview(player: Player): any
	local blueprints = self._save:ListBlueprints(player.UserId)
	local candidates = {}
	for _,other in ipairs(Players:GetPlayers()) do
		if other ~= player and not self:_sessionFor(other.UserId) then
			table.insert(candidates,{UserId=other.UserId,Name=other.Name,DisplayName=other.DisplayName})
		end
	end
	table.sort(candidates,function(a,b) return string.lower(a.DisplayName)<string.lower(b.DisplayName) end)
	local session = self:_sessionFor(player.UserId)
	return {Blueprints=blueprints,Players=candidates,Session=session and self:_public(session,player.UserId) or nil,TestDriveSeconds=Rules.TEST_DRIVE_SECONDS}
end

function Trade:_push(session: any)
	for _,userId in ipairs(session.Participants) do
		local player = Players:GetPlayerByUserId(userId)
		if player then self._stateEvent:FireClient(player,self:_public(session,userId)) end
	end
end

function Trade:_closeTest(session: any, reason: string)
	if session.TestMatchId then
		pcall(function() self._match:End(session.TestMatchId,reason) end)
		session.TestMatchId = nil
	end
end

function Trade:_cancel(session: any, reason: string)
	if not session or session.State == "Cancelled" or session.State == "Committed" then return end
	self:_closeTest(session,"TradeCancelled")
	local cancelled = Rules.Cancel(session,reason)
	self._sessions[session.Id] = cancelled
	self:_push(cancelled)
	for _,userId in ipairs(cancelled.Participants) do self._byUser[userId] = nil end
	task.delay(8,function() if self._sessions[cancelled.Id] == cancelled then self._sessions[cancelled.Id] = nil end end)
end

local function tradeName(saveService: any, userId: number, preferred: string): string
	local base = preferred
	if #base > 32 then base = string.sub(base,1,32) end
	if not saveService:GetBlueprint(userId,base) then return base end
	for index=1,99 do
		local suffix = " [Trade"..(index==1 and "" or " "..tostring(index)).."]"
		local trimmed = string.sub(base,1,40-#suffix)
		local candidate = trimmed..suffix
		if not saveService:GetBlueprint(userId,candidate) then return candidate end
	end
	return "Traded Vehicle "..tostring(os.time()%100000)
end

function Trade:_commit(session: any): (boolean,string?)
	if not Rules.BothAccepted(session) then return false,"BothPlayersMustAccept" end
	local a,b = session.Participants[1],session.Participants[2]
	local offerA,offerB = session.Offers[a],session.Offers[b]
	local currentA = self._save:GetBlueprint(a,offerA)
	local currentB = self._save:GetBlueprint(b,offerB)
	if not currentA or not currentB then return false,"OfferedVehicleMissing" end
	local locked = session.LockedBlueprints
	if type(locked) ~= "table" then return false,"TestDriveRequired" end
	if tonumber(currentA.SavedAt) ~= tonumber(locked[a] and locked[a].SavedAt) or tonumber(currentB.SavedAt) ~= tonumber(locked[b] and locked[b].SavedAt) then
		return false,"OfferChangedAfterTest"
	end

	local originalA,originalB = clone(currentA),clone(currentB)
	self._save:DeleteBlueprint(a,offerA)
	self._save:DeleteBlueprint(b,offerB)
	local incomingNameA = tradeName(self._save,a,tostring(originalB.Name or offerB))
	local incomingNameB = tradeName(self._save,b,tostring(originalA.Name or offerA))
	local okA,reasonA = self._save:SetBlueprint(a,incomingNameA,originalB)
	if not okA then
		self._save:SetBlueprint(a,offerA,originalA); self._save:SetBlueprint(b,offerB,originalB)
		return false,reasonA or "TradeWriteFailed"
	end
	local okB,reasonB = self._save:SetBlueprint(b,incomingNameB,originalA)
	if not okB then
		self._save:DeleteBlueprint(a,incomingNameA)
		self._save:SetBlueprint(a,offerA,originalA); self._save:SetBlueprint(b,offerB,originalB)
		return false,reasonB or "TradeWriteFailed"
	end

	-- Flush both loaded save sessions now rather than waiting for autosave.
	local persistedA = self._save:_save(a,false)
	local persistedB = self._save:_save(b,false)
	if not persistedA or not persistedB then
		warn("[GOD MACHINES] vehicle trade committed in memory but immediate persistence was incomplete",session.Id,persistedA,persistedB)
	end

	self:_closeTest(session,"TradeCommitted")
	local committed = Rules.Commit(session)
	committed.Received = {[a]=incomingNameA,[b]=incomingNameB}
	self._sessions[session.Id] = committed
	self:_push(committed)
	self._byUser[a] = nil; self._byUser[b] = nil
	return true,nil
end

function Trade:_invite(player: Player, targetUserId: any, blueprintName: any): (boolean,any)
	local targetId = tonumber(targetUserId)
	if not targetId or targetId == player.UserId then return false,"InvalidTradePartner" end
	local target = Players:GetPlayerByUserId(targetId)
	if not target then return false,"PlayerUnavailable" end
	if self:_sessionFor(player.UserId) or self:_sessionFor(targetId) then return false,"PlayerAlreadyTrading" end
	if type(blueprintName) ~= "string" or not self._save:GetBlueprint(player.UserId,blueprintName) then return false,"VehicleNotOwned" end

	local id = HttpService:GenerateGUID(false)
	local session = Rules.NewSession(id,player.UserId,targetId)
	local ok,result = Rules.SetOffer(session,player.UserId,blueprintName)
	if not ok then return false,result end
	session = result
	self._sessions[id] = session; self._byUser[player.UserId]=id; self._byUser[targetId]=id
	self:_push(session)
	return true,self:_public(session,player.UserId)
end

function Trade:_setOffer(player: Player, blueprintName: any): (boolean,any)
	local session = self:_sessionFor(player.UserId)
	if not session then return false,"NoActiveTrade" end
	if type(blueprintName) ~= "string" or not self._save:GetBlueprint(player.UserId,blueprintName) then return false,"VehicleNotOwned" end
	local ok,result = Rules.SetOffer(session,player.UserId,blueprintName)
	if not ok then return false,result end
	self._sessions[session.Id] = result
	self:_push(result)
	return true,self:_public(result,player.UserId)
end

function Trade:_startTest(player: Player): (boolean,any)
	local session = self:_sessionFor(player.UserId)
	if not session then return false,"NoActiveTrade" end
	if not Rules.CanStartTest(session) then return false,"BothVehiclesRequired" end
	local a,b = session.Participants[1],session.Participants[2]
	local blueprintA = self._save:GetBlueprint(a,session.Offers[a])
	local blueprintB = self._save:GetBlueprint(b,session.Offers[b])
	if not blueprintA or not blueprintB then return false,"OfferedVehicleMissing" end

	local okCreate,matchId = self._match:Create("Duel",{TradeTest=true})
	if not okCreate then return false,matchId end
	local okA,reasonA = self._match:AddParticipant(matchId,{UserId=a,BlueprintId=session.Offers[b],BlueprintOwnerId=b,Team=1})
	if not okA then return false,reasonA end
	local okB,reasonB = self._match:AddParticipant(matchId,{UserId=b,BlueprintId=session.Offers[a],BlueprintOwnerId=a,Team=2})
	if not okB then return false,reasonB end
	local spawned,spawnReason = self._match:Spawn(matchId)
	if not spawned then return false,spawnReason end

	local started = Rules.StartTest(session,os.clock())
	started.TestMatchId = matchId
	started.LockedBlueprints = {[a]=clone(blueprintA),[b]=clone(blueprintB)}
	self._sessions[session.Id] = started
	self:_push(started)

	local expected = started
	task.delay(Rules.TEST_DRIVE_SECONDS,function()
		if self._sessions[expected.Id] ~= expected or expected.State ~= "Testing" then return end
		self:_closeTest(expected,"TradeTestComplete")
		local review = Rules.Advance(expected,expected.TestEndsAt)
		review.TestMatchId = nil
		self._sessions[expected.Id] = review
		self:_push(review)
	end)
	return true,self:_public(started,player.UserId)
end

function Trade:_accept(player: Player, accepted: any): (boolean,any)
	local session = self:_sessionFor(player.UserId)
	if not session then return false,"NoActiveTrade" end
	if session.State ~= "Testing" and session.State ~= "Review" then return false,"TestDriveRequired" end
	local updated = Rules.SetAccepted(session,player.UserId,accepted == true)
	self._sessions[session.Id] = updated
	self:_push(updated)
	if Rules.BothAccepted(updated) then
		local ok,reason = self:_commit(updated)
		if not ok then
			local reset = clone(updated); reset.Accepted={}; self._sessions[updated.Id]=reset; self:_push(reset)
			return false,reason
		end
	end
	return true,self:_public(self._sessions[session.Id],player.UserId)
end

function Trade:Start()
	self._remote.OnServerInvoke = function(player: Player, request: any)
		if type(request) ~= "table" or type(request.Action) ~= "string" then return false,"BadRequest" end
		local action = request.Action
		if action == "Overview" then return true,self:_overview(player)
		elseif action == "Invite" then return self:_invite(player,request.TargetUserId,request.BlueprintName)
		elseif action == "SetOffer" then return self:_setOffer(player,request.BlueprintName)
		elseif action == "StartTest" then return self:_startTest(player)
		elseif action == "Accept" then return self:_accept(player,request.Accepted)
		elseif action == "Cancel" then local session=self:_sessionFor(player.UserId); if not session then return false,"NoActiveTrade" end; self:_cancel(session,"CancelledByPlayer"); return true,{} end
		return false,"UnknownAction"
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = self:_sessionFor(player.UserId)
		if session then self:_cancel(session,"PlayerLeft") end
	end)
end

return Trade
