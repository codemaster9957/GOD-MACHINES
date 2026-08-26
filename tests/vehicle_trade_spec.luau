--!strict
-- Pure behavior contract for safe two-minute vehicle trading.

local failures = {}

local function expect(condition: boolean, message: string)
	if not condition then table.insert(failures, message) end
end

local loaded, Rules = pcall(require, "../src/ReplicatedStorage/MechFramework/Shared/VehicleTradeRules")
expect(loaded, "VehicleTradeRules must exist")

if loaded then
	expect(Rules.TEST_DRIVE_SECONDS == 120, "test drives must last exactly two minutes")

	local session = Rules.NewSession("trade-1", 10, 20)
	expect(session.State == "Selecting", "new trades begin in selection")

	local okA, afterA = Rules.SetOffer(session, 10, "Scout")
	expect(okA == true and afterA.Offers[10] == "Scout", "player A can offer a saved vehicle")
	expect(session.Offers[10] == nil, "offer updates must not mutate caller state")

	local okB, ready = Rules.SetOffer(afterA, 20, "Tank")
	expect(okB == true and Rules.CanStartTest(ready), "both valid offers unlock testing")

	local started = Rules.StartTest(ready, 100)
	expect(started.State == "Testing", "test phase must become active")
	expect(started.TestEndsAt == 220, "test deadline must be exactly 120 seconds")
	expect(Rules.TestRemaining(started, 160) == 60, "test countdown must be deterministic")

	local acceptedA = Rules.SetAccepted(started, 10, true)
	expect(acceptedA.Accepted[10] == true and acceptedA.Accepted[20] ~= true, "acceptance is per player")
	local acceptedBoth = Rules.SetAccepted(acceptedA, 20, true)
	expect(Rules.BothAccepted(acceptedBoth), "both players must accept before commit")

	local changedOfferOk, changed = Rules.SetOffer(acceptedBoth, 10, "Heavy Scout")
	expect(changedOfferOk == true and not Rules.BothAccepted(changed), "changing an offer clears both acceptances")

	local invalid, invalidReason = Rules.SetOffer(session, 999, "Exploit")
	expect(invalid == false and invalidReason == "NotParticipant", "non-participants cannot mutate a trade")

	local timedOut = Rules.Advance(started, 221)
	expect(timedOut.State == "Review", "two-minute test expiry advances to review instead of auto-trading")

	local cancelled = Rules.Cancel(started, "PlayerLeft")
	expect(cancelled.State == "Cancelled" and cancelled.CancelReason == "PlayerLeft", "disconnect cancellation is explicit")
end

if #failures > 0 then
	error("VEHICLE TRADE SPEC FAILED:\n  - " .. table.concat(failures, "\n  - "), 0)
end

print("VEHICLE TRADE SPEC PASSED")
