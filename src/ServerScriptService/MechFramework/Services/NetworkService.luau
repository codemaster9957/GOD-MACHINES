--!strict
-- The sole remote boundary: validate shape, identity, ownership, rate, and server state.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.MechFramework.Shared.FrameworkConfig)
local Network = { _buckets = {} }

local function validString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

function Network:Init(container)
	self._mechs = container:Get("MechService"); self._connections = container:Get("ConnectionService")
	self._inventory = container:Get("InventoryService"); self._combat = container:Get("CombatService")
	self._remotes = game.ReplicatedStorage.MechFramework.Remotes
end

function Network:_allow(player: Player): boolean
	local now = os.clock(); local bucket = self._buckets[player.UserId] or { Tokens = Config.Network.Burst, Time = now }
	bucket.Tokens = math.min(Config.Network.Burst, bucket.Tokens + (now - bucket.Time) * Config.Network.RequestsPerSecond); bucket.Time = now
	if bucket.Tokens < 1 then self._buckets[player.UserId] = bucket; return false end
	bucket.Tokens -= 1; self._buckets[player.UserId] = bucket; return true
end

function Network:_build(player: Player, request: any): any
	if not self:_allow(player) or type(request) ~= "table" or not validString(request.Action, 40) then return { Ok = false, Error = "InvalidRequest" } end
	if request.Action == "CreateMech" then
		return { Ok = true, MechId = self._mechs:Create(player.UserId, {}) }
	elseif request.Action == "AddComponent" then
		if not validString(request.MechId, 80) or not validString(request.PartType, 80) or typeof(request.LocalTransform) ~= "CFrame" then return { Ok = false, Error = "InvalidArguments" } end
		if not self._mechs:IsOwner(player.UserId, request.MechId) then return { Ok = false, Error = "NotAuthorized" } end
		if not self._inventory:Consume(player.UserId, request.PartType, 1) then return { Ok = false, Error = "ItemNotOwned" } end
		local ok, result = self._mechs:AddComponent(request.MechId, player.UserId, request.PartType, request.LocalTransform, {})
		if not ok then self._inventory:Grant(player.UserId, request.PartType, 1) end
		return { Ok = ok, Result = result }
	elseif request.Action == "Attach" then
		if not validString(request.MechId, 80) or not validString(request.A, 80) or not validString(request.B, 80) then return { Ok = false, Error = "InvalidArguments" } end
		local ok, result = self._connections:Attach(request.MechId, player.UserId, request.A, request.B, {})
		return { Ok = ok, Result = result }
	elseif request.Action == "Fire" then
		if not validString(request.MechId, 80) or not validString(request.WeaponId, 80) then return { Ok = false, Error = "InvalidArguments" } end
		local ok, reason = self._combat:RecordFire(player.UserId, request.MechId, request.WeaponId)
		return { Ok = ok, Error = reason }
	end
	return { Ok = false, Error = "UnknownAction" }
end

function Network:Start()
	-- BuildService exclusively owns RequestBuildAction. Rebinding it here used to
	-- replace the Definition/Place protocol after BuildService had started.
	print("[MechFramework] NetworkService leaving RequestBuildAction owned by BuildService")
	self._remotes.Functions.RequestInventorySnapshot.OnServerInvoke = function(player)
		if not self:_allow(player) then return nil end
		return self._inventory:Snapshot(player.UserId)
	end
	self._remotes.Functions.RequestMechSnapshot.OnServerInvoke = function(player, mechId)
		if not self:_allow(player) or not validString(mechId, 80) then return nil end
		return self._mechs:Snapshot(mechId, player.UserId)
	end
	Players.PlayerRemoving:Connect(function(player)
		self._buckets[player.UserId] = nil
	end)
end

return Network
