--!strict
-- Reliable session persistence: locking, retries, autosave, migrations, blueprint serialization and shutdown flush.
-- Studio debug sessions intentionally stay local so development does not depend on API Services being enabled.

local Players=game:GetService("Players")
local DataStoreService=game:GetService("DataStoreService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.MechFramework.Shared.FrameworkConfig)
local store=DataStoreService:GetDataStore(Config.SaveKey)

local Save:any={_migrations={},_inventory=nil,_sessions={},_blueprints={},_closing=false}
local SESSION_TIMEOUT=180
local AUTOSAVE_SECONDS=60
local MAX_ATTEMPTS=5
local MAX_BLUEPRINTS=30
local MAX_BLUEPRINT_COMPONENTS=300
local MAX_BLUEPRINT_CONNECTIONS=900
local MAX_BLUEPRINT_STORAGE_BYTES=2_500_000
local TYPE_KEY="__gmType"

local function clone(value:any):any
	if type(value)~="table" then return value end
	local out={}; for key,item in pairs(value) do out[key]=clone(item) end; return out
end
local function retry(callback:()->any):(boolean,any)
	local lastError:any=nil
	for attempt=1,MAX_ATTEMPTS do
		local ok,result=pcall(callback); if ok then return true,result end
		lastError=result; task.wait(math.min(2^(attempt-1),8))
	end
	return false,lastError
end
local function countMap(map:any):number local count=0; for _ in pairs(map or {}) do count+=1 end; return count end
local function cleanName(value:string):string local name=value:match("^%s*(.-)%s*$") or ""; return name:gsub("[%c]","") end
local function finite(value:number):boolean return value==value and value~=math.huge and value~=-math.huge end

-- Roblox DataStores only accept primitive/table data. Blueprint transforms and paint therefore
-- need explicit tagged encoding; decoding happens before migrations and gameplay see the record.
local function encode(value:any,depth:number?):any
	depth=(depth or 0)+1; if depth>48 then error("Save data nesting too deep") end
	local kind=typeof(value)
	if kind=="nil" or kind=="string" or kind=="boolean" then return value end
	if kind=="number" then if not finite(value) then error("Non-finite number in save data") end; return value end
	if kind=="CFrame" then return {[TYPE_KEY]="CFrame",V={value:GetComponents()}} end
	if kind=="Color3" then return {[TYPE_KEY]="Color3",V={value.R,value.G,value.B}} end
	if kind=="Vector3" then return {[TYPE_KEY]="Vector3",V={value.X,value.Y,value.Z}} end
	if kind=="Vector2" then return {[TYPE_KEY]="Vector2",V={value.X,value.Y}} end
	if kind=="EnumItem" then return {[TYPE_KEY]="Enum",E=tostring(value.EnumType),N=value.Name} end
	if kind=="table" then
		local out={}
		for key,item in pairs(value) do
			if type(key)~="string" and type(key)~="number" then error("Unsupported save table key type: "..typeof(key)) end
			out[key]=encode(item,depth)
		end
		return out
	end
	error("Unsupported save value type: "..kind)
end

local function decode(value:any,depth:number?):any
	depth=(depth or 0)+1; if depth>48 then error("Saved data nesting too deep") end
	if type(value)~="table" then return value end
	local tag=value[TYPE_KEY]
	if tag=="CFrame" and type(value.V)=="table" and #value.V==12 then
		local ok,result=pcall(function() return CFrame.new(table.unpack(value.V)) end); if ok then return result end
	elseif tag=="Color3" and type(value.V)=="table" and #value.V>=3 then return Color3.new(tonumber(value.V[1]) or 0,tonumber(value.V[2]) or 0,tonumber(value.V[3]) or 0)
	elseif tag=="Vector3" and type(value.V)=="table" and #value.V>=3 then return Vector3.new(tonumber(value.V[1]) or 0,tonumber(value.V[2]) or 0,tonumber(value.V[3]) or 0)
	elseif tag=="Vector2" and type(value.V)=="table" and #value.V>=2 then return Vector2.new(tonumber(value.V[1]) or 0,tonumber(value.V[2]) or 0)
	elseif tag=="Enum" and type(value.E)=="string" and type(value.N)=="string" then
		local enumName=value.E:match("Enum%.(.+)$")
		if enumName then local ok,result=pcall(function() return (Enum::any)[enumName][value.N] end); if ok then return result end end
	end
	local out={}; for key,item in pairs(value) do out[key]=decode(item,depth) end; return out
end

local function encodedBytes(value:any):number?
	local ok,encodedValue=pcall(encode,value); if not ok then return nil end
	local jsonOk,json=pcall(function() return HttpService:JSONEncode(encodedValue) end); if not jsonOk then return nil end
	return #json
end

function Save:Init(container:any) self._inventory=container:Get("InventoryService") end
function Save:RegisterMigration(fromVersion:number,migrate:(any)->any)
	assert(fromVersion>=0 and self._migrations[fromVersion]==nil,"Invalid duplicate migration"); self._migrations[fromVersion]=migrate
end
function Save:Migrate(record:any):any
	local version=tonumber(record.SchemaVersion) or 0
	while version<Config.SchemaVersion do local migration=self._migrations[version]; if migration then record=migration(record) end; version+=1; record.SchemaVersion=version end
	return record
end
function Save:BuildPlayerRecord(userId:number):any
	return {SchemaVersion=Config.SchemaVersion,UserId=userId,Inventory=self._inventory:Snapshot(userId),Blueprints=clone(self._blueprints[userId] or {}),SavedAt=os.time()}
end
function Save:GetBlueprint(userId:number,blueprintId:string):any?
	local owned=self._blueprints[userId]; local blueprint=owned and owned[blueprintId]; return blueprint and clone(blueprint) or nil
end
function Save:ListBlueprints(userId:number):{any}
	local result={}
	for name,blueprint in pairs(self._blueprints[userId] or {}) do table.insert(result,{Name=name,PartCount=countMap(blueprint.Components),SavedAt=tonumber(blueprint.SavedAt) or 0}) end
	table.sort(result,function(a,b) if a.SavedAt~=b.SavedAt then return a.SavedAt>b.SavedAt end; return a.Name<b.Name end); return result
end
function Save:SetBlueprint(userId:number,blueprintId:string,blueprint:any):(boolean,string?)
	if type(blueprintId)~="string" or type(blueprint)~="table" then return false,"InvalidBlueprint" end
	local name=cleanName(blueprintId); if name=="" or #name>40 then return false,"InvalidBlueprintName" end
	if type(blueprint.Components)~="table" or type(blueprint.Connections)~="table" then return false,"ComponentsRequired" end
	local partCount=countMap(blueprint.Components); if partCount<1 then return false,"EmptyBlueprint" end
	if partCount>MAX_BLUEPRINT_COMPONENTS then return false,"BlueprintTooLarge" end
	if countMap(blueprint.Connections)>MAX_BLUEPRINT_CONNECTIONS then return false,"BlueprintTooConnected" end
	self._blueprints[userId]=self._blueprints[userId] or {}; local owned=self._blueprints[userId]
	if owned[name]==nil and countMap(owned)>=MAX_BLUEPRINTS then return false,"BlueprintLimitReached" end
	local stored=clone(blueprint); stored.Id=name; stored.Name=name; stored.SavedAt=os.time()
	local candidate=clone(owned); candidate[name]=stored
	local bytes=encodedBytes(candidate); if not bytes then return false,"BlueprintNotSerializable" end
	if bytes>MAX_BLUEPRINT_STORAGE_BYTES then return false,"BlueprintStorageFull" end
	owned[name]=stored; return true,nil
end
function Save:DeleteBlueprint(userId:number,blueprintId:string):boolean
	local owned=self._blueprints[userId]; if not owned or owned[blueprintId]==nil then return false end; owned[blueprintId]=nil; return true
end
function Save:_grantStudioBuildInventory(userId:number)
	if RunService:IsStudio() and Config.Debug then self._inventory:EnsureStudioBuildInventory(userId) end
end
function Save:_loadStudio(player:Player)
	local userId=player.UserId; if self._sessions[userId] then return end
	self._sessions[userId]={Id="StudioLocal:"..tostring(userId),Key="",LastSave=os.clock(),LocalOnly=true}; self._inventory:Restore(userId,{}); self._blueprints[userId]={}
	self:_grantStudioBuildInventory(userId); print("[MechFramework] Studio local save session ready",userId)
end
function Save:_load(player:Player)
	if RunService:IsStudio() and Config.Debug then self:_loadStudio(player); return end
	local userId=player.UserId; if self._sessions[userId] then return end
	local sessionId=HttpService:GenerateGUID(false); local key="Player_"..userId; local now=os.time(); local acquired=false
	local ok,record=retry(function()
		return store:UpdateAsync(key,function(old:any)
			old=if type(old)=="table" then old else {SchemaVersion=Config.SchemaVersion,UserId=userId,Inventory={},Blueprints={}}
			local session=old.Session; if session and session.Id~=sessionId and now-(tonumber(session.Heartbeat) or now)<SESSION_TIMEOUT then return nil end
			old.Session={Id=sessionId,Heartbeat=now}; acquired=true; return old
		end)
	end)
	if not ok or not acquired or type(record)~="table" then warn("[MechFramework] Failed to acquire save session",userId,record); player:Kick("Inventory session could not be loaded safely. Please rejoin."); return end
	local decodedOk,decodedRecord=pcall(decode,record)
	if not decodedOk or type(decodedRecord)~="table" then warn("[MechFramework] Saved record decode failed",userId,decodedRecord); player:Kick("Saved machine data could not be decoded safely. Please rejoin."); return end
	record=self:Migrate(decodedRecord); self._sessions[userId]={Id=sessionId,Key=key,LastSave=os.clock(),LocalOnly=false}
	self._inventory:Restore(userId,record.Inventory or {}); self._blueprints[userId]=clone(record.Blueprints or {})
end
function Save:_releaseLocal(userId:number) self._sessions[userId]=nil; self._inventory:RemovePlayer(userId); self._blueprints[userId]=nil end
function Save:_save(userId:number,release:boolean):boolean
	local session=self._sessions[userId]; if not session then return true end
	if session.LocalOnly==true then session.LastSave=os.clock(); if release then self:_releaseLocal(userId) end; return true end
	local encodeOk,payload=pcall(encode,self:BuildPlayerRecord(userId))
	if not encodeOk or type(payload)~="table" then warn("[MechFramework] Save encode failed",userId,payload); return false end
	local ok,result=retry(function()
		return store:UpdateAsync(session.Key,function(old:any)
			if type(old)=="table" and old.Session and old.Session.Id~=session.Id then return nil end
			payload.Session=if release then nil else {Id=session.Id,Heartbeat=os.time()}; return payload
		end)
	end)
	if ok then session.LastSave=os.clock() elseif result then warn("[MechFramework] Save failed",userId,result) end
	if release and ok then self._sessions[userId]=nil; self._inventory:RemovePlayer(userId); self._blueprints[userId]=nil end; return ok
end
function Save:Start()
	Players.PlayerAdded:Connect(function(player) task.spawn(function() self:_load(player) end) end)
	Players.PlayerRemoving:Connect(function(player) self:_save(player.UserId,true) end)
	for _,player in ipairs(Players:GetPlayers()) do task.spawn(function() self:_load(player) end) end
	task.spawn(function()
		while not self._closing do task.wait(10); for userId,session in pairs(self._sessions) do if os.clock()-session.LastSave>=AUTOSAVE_SECONDS then task.spawn(function() self:_save(userId,false) end) end end end
	end)
	game:BindToClose(function()
		self._closing=true; if RunService:IsStudio() then return end
		local pending=0; for userId in pairs(self._sessions) do pending+=1; task.spawn(function() self:_save(userId,true); pending-=1 end) end
		local deadline=os.clock()+25; while pending>0 and os.clock()<deadline do task.wait(.1) end
	end)
end

return Save