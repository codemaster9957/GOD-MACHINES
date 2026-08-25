--!strict
-- Reliable session persistence: UpdateAsync locking, retries, autosave, migrations, and shutdown flush.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MechFramework.Shared.FrameworkConfig)
local store = DataStoreService:GetDataStore(Config.SaveKey)

local Save: any = {
	_migrations = {},
	_inventory = nil,
	_sessions = {},
	_blueprints = {},
	_closing = false,
}

local SESSION_TIMEOUT = 180
local AUTOSAVE_SECONDS = 60
local MAX_ATTEMPTS = 5

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out: {[any]: any} = {}
	for key, item in pairs(value) do
		out[key] = clone(item)
	end
	return out
end

local function retry(callback: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(math.min(2 ^ (attempt - 1), 8))
	end
	return false, lastError
end

function Save:Init(container: any)
	self._inventory = container:Get("InventoryService")
end

function Save:RegisterMigration(fromVersion: number, migrate: (any) -> any)
	assert(fromVersion >= 0 and self._migrations[fromVersion] == nil, "Invalid duplicate migration")
	self._migrations[fromVersion] = migrate
end

function Save:Migrate(record: any): any
	local version = tonumber(record.SchemaVersion) or 0
	while version < Config.SchemaVersion do
		local migration = self._migrations[version]
		if migration then
			record = migration(record)
		end
		version += 1
		record.SchemaVersion = version
	end
	return record
end

function Save:BuildPlayerRecord(userId: number): any
	return {
		SchemaVersion = Config.SchemaVersion,
		UserId = userId,
		Inventory = self._inventory:Snapshot(userId),
		Blueprints = clone(self._blueprints[userId] or {}),
		SavedAt = os.time(),
	}
end

function Save:GetBlueprint(userId: number, blueprintId: string): any?
	local owned = self._blueprints[userId]
	local blueprint = owned and owned[blueprintId]
	return blueprint and clone(blueprint) or nil
end

function Save:SetBlueprint(userId: number, blueprintId: string, blueprint: any): (boolean, string?)
	if type(blueprintId) ~= "string" or blueprintId == "" or type(blueprint) ~= "table" then
		return false, "InvalidBlueprint"
	end
	if type(blueprint.Components) ~= "table" then
		return false, "ComponentsRequired"
	end
	self._blueprints[userId] = self._blueprints[userId] or {}
	self._blueprints[userId][blueprintId] = clone(blueprint)
	return true, nil
end

function Save:DeleteBlueprint(userId: number, blueprintId: string): boolean
	local owned = self._blueprints[userId]
	if not owned or owned[blueprintId] == nil then
		return false
	end
	owned[blueprintId] = nil
	return true
end

function Save:_grantStudioBuildInventory(userId: number)
	if not (RunService:IsStudio() and Config.Debug) then
		return
	end
	for _, partType in ipairs({ "StructuralFrame", "SmallReactor", "Autocannon" }) do
		if self._inventory:GetCount(userId, partType) == 0 then
			self._inventory:Grant(userId, partType, 25)
		end
	end
	print("[MechFramework] Granted Studio test build inventory", userId)
end

function Save:_load(player: Player)
	local userId = player.UserId
	local sessionId = HttpService:GenerateGUID(false)
	local key = "Player_" .. userId
	local now = os.time()
	local acquired = false

	local ok, record = retry(function()
		return store:UpdateAsync(key, function(old: any)
			old = if type(old) == "table" then old else {
				SchemaVersion = Config.SchemaVersion,
				UserId = userId,
				Inventory = {},
				Blueprints = {},
			}
			local session = old.Session
			if session and session.Id ~= sessionId and now - (tonumber(session.Heartbeat) or now) < SESSION_TIMEOUT then
				return nil
			end
			old.Session = { Id = sessionId, Heartbeat = now }
			acquired = true
			return old
		end)
	end)

	if not ok or not acquired or type(record) ~= "table" then
		player:Kick("Inventory session could not be loaded safely. Please rejoin.")
		return
	end

	record = self:Migrate(record)
	self._sessions[userId] = { Id = sessionId, Key = key, LastSave = os.clock() }
	self._inventory:Restore(userId, record.Inventory or {})
	self._blueprints[userId] = clone(record.Blueprints or {})
	self:_grantStudioBuildInventory(userId)
end

function Save:_save(userId: number, release: boolean): boolean
	local session = self._sessions[userId]
	if not session then
		return true
	end
	local payload = self:BuildPlayerRecord(userId)
	local ok = retry(function()
		return store:UpdateAsync(session.Key, function(old: any)
			if type(old) == "table" and old.Session and old.Session.Id ~= session.Id then
				return nil
			end
			payload.Session = if release then nil else { Id = session.Id, Heartbeat = os.time() }
			return payload
		end)
	end)
	if ok then
		session.LastSave = os.clock()
	end
	if release and ok then
		self._sessions[userId] = nil
		self._inventory:RemovePlayer(userId)
		self._blueprints[userId] = nil
	end
	return ok
end

function Save:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_save(player.UserId, true)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_load(player)
		end)
	end
	task.spawn(function()
		while not self._closing do
			task.wait(10)
			for userId, session in pairs(self._sessions) do
				if os.clock() - session.LastSave >= AUTOSAVE_SECONDS then
					task.spawn(function()
						self:_save(userId, false)
					end)
				end
			end
		end
	end)
	game:BindToClose(function()
		self._closing = true
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for userId in pairs(self._sessions) do
			pending += 1
			task.spawn(function()
				self:_save(userId, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Save