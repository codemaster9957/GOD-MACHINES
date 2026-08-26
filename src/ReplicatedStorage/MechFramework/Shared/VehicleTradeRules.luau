--!strict
-- Pure immutable state transitions for player-to-player saved vehicle trades.

local Rules = {}
Rules.TEST_DRIVE_SECONDS = 120
Rules.OFFER_NAME_LIMIT = 40

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = clone(item) end
	return out
end

local function participant(session: any, userId: number): boolean
	return session and session.Participants and (session.Participants[1] == userId or session.Participants[2] == userId)
end

local function cleanName(value: any): string?
	if type(value) ~= "string" then return nil end
	local name = value:match("^%s*(.-)%s*$") or ""
	name = name:gsub("[%c]", "")
	if name == "" or #name > Rules.OFFER_NAME_LIMIT then return nil end
	return name
end

function Rules.NewSession(id: string, userA: number, userB: number): any
	assert(type(id) == "string" and id ~= "", "trade id required")
	assert(userA ~= userB, "trade requires two players")
	return {
		Id = id,
		Participants = {userA, userB},
		State = "Selecting",
		Offers = {},
		OfferVersions = {[userA]=0,[userB]=0},
		Accepted = {},
		CreatedAt = os.clock(),
	}
end

function Rules.IsParticipant(session: any, userId: number): boolean return participant(session, userId) end

function Rules.OtherUser(session: any, userId: number): number?
	if not participant(session, userId) then return nil end
	return if session.Participants[1] == userId then session.Participants[2] else session.Participants[1]
end

function Rules.SetOffer(session: any, userId: number, blueprintName: any): (boolean, any)
	if not participant(session, userId) then return false, "NotParticipant" end
	if session.State == "Committed" or session.State == "Cancelled" then return false, "TradeClosed" end
	local name = cleanName(blueprintName)
	if not name then return false, "InvalidBlueprintName" end
	local nextState = clone(session)
	nextState.Offers[userId] = name
	nextState.OfferVersions[userId] = (tonumber(nextState.OfferVersions[userId]) or 0) + 1
	nextState.Accepted = {}
	if nextState.State == "Testing" or nextState.State == "Review" then
		nextState.State = "Selecting"
		nextState.TestStartedAt = nil
		nextState.TestEndsAt = nil
	end
	return true, nextState
end

function Rules.CanStartTest(session: any): boolean
	if not session or session.State ~= "Selecting" then return false end
	local a,b = session.Participants[1],session.Participants[2]
	return cleanName(session.Offers[a]) ~= nil and cleanName(session.Offers[b]) ~= nil
end

function Rules.StartTest(session: any, now: number): any
	assert(Rules.CanStartTest(session), "both offers required")
	local nextState = clone(session)
	nextState.State = "Testing"
	nextState.TestStartedAt = now
	nextState.TestEndsAt = now + Rules.TEST_DRIVE_SECONDS
	nextState.Accepted = {}
	return nextState
end

function Rules.TestRemaining(session: any, now: number): number
	if not session or session.State ~= "Testing" then return 0 end
	return math.max(0, (tonumber(session.TestEndsAt) or now) - now)
end

function Rules.Advance(session: any, now: number): any
	if not session or session.State ~= "Testing" or Rules.TestRemaining(session, now) > 0 then return clone(session) end
	local nextState = clone(session)
	nextState.State = "Review"
	return nextState
end

function Rules.SetAccepted(session: any, userId: number, accepted: boolean): any
	assert(participant(session,userId), "NotParticipant")
	local nextState = clone(session)
	if nextState.State ~= "Testing" and nextState.State ~= "Review" then return nextState end
	nextState.Accepted[userId] = accepted == true
	return nextState
end

function Rules.BothAccepted(session: any): boolean
	if not session or (session.State ~= "Testing" and session.State ~= "Review") then return false end
	local a,b = session.Participants[1],session.Participants[2]
	return session.Accepted[a] == true and session.Accepted[b] == true
end

function Rules.Cancel(session: any, reason: string): any
	local nextState = clone(session)
	if nextState.State ~= "Committed" then
		nextState.State = "Cancelled"
		nextState.CancelReason = reason
		nextState.Accepted = {}
	end
	return nextState
end

function Rules.Commit(session: any): any
	assert(Rules.BothAccepted(session), "both players must accept")
	local nextState = clone(session)
	nextState.State = "Committed"
	nextState.CommittedAt = os.clock()
	return nextState
end

function Rules.PublicSnapshot(session: any, now: number): any
	local out = clone(session)
	out.TestRemaining = Rules.TestRemaining(session, now)
	return out
end

return table.freeze(Rules)
