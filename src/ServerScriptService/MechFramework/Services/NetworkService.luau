--!strict
-- Snapshot-only remote boundary. Construction mutations belong exclusively to BuildService;
-- machine/control mutations belong to PilotService/ControlService.

local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.MechFramework.Shared.FrameworkConfig)

local Network: any = { _buckets = {} }

local function validString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

function Network:Init(container: any)
	self._mechs = container:Get("MechService")
	self._inventory = container:Get("InventoryService")
	self._remotes = game.ReplicatedStorage.MechFramework.Remotes
end

function Network:_allow(player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player.UserId] or { Tokens = Config.Network.Burst, Time = now }
	bucket.Tokens = math.min(Config.Network.Burst, bucket.Tokens + (now - bucket.Time) * Config.Network.RequestsPerSecond)
	bucket.Time = now
	if bucket.Tokens < 1 then
		self._buckets[player.UserId] = bucket
		return false
	end
	bucket.Tokens -= 1
	self._buckets[player.UserId] = bucket
	return true
end

function Network:Start()
	-- BuildService exclusively owns RequestBuildAction. Keeping this service read-only avoids
	-- bypassing collision, attachment, paint, inventory, history and blueprint invariants.
	print("[MechFramework] NetworkService snapshot boundary ready")

	local inventoryRemote = self._remotes.Functions.RequestInventorySnapshot
	local mechRemote = self._remotes.Functions.RequestMechSnapshot
	if not inventoryRemote:IsA("RemoteFunction") or not mechRemote:IsA("RemoteFunction") then
		error("[NetworkService] Snapshot remotes must be RemoteFunctions")
	end

	inventoryRemote.OnServerInvoke = function(player)
		if not self:_allow(player) then return nil end
		return self._inventory:Snapshot(player.UserId)
	end
	mechRemote.OnServerInvoke = function(player, mechId)
		if not self:_allow(player) or not validString(mechId, 80) then return nil end
		return self._mechs:Snapshot(mechId, player.UserId)
	end

	Players.PlayerRemoving:Connect(function(player)
		self._buckets[player.UserId] = nil
	end)
end

return Network
