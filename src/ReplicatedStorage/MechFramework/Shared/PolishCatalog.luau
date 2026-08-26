--!strict
-- Exactly-100 additive polish features for GOD MACHINES.

export type PolishItem = {
	Id: string,
	Group: string,
	Name: string,
	Description: string,
	Scope: string,
	Enabled: boolean,
}

local Catalog = {
	Version = "2026.08.26-100",
	MasterEnabled = true,
	Defaults = {
		ReducedMotion = false,
		CameraMotion = true,
		ScreenFlash = true,
		Vignette = true,
		CrosshairScale = 1,
		TextScale = 1,
	},
	Items = {
		{ Id = "B01", Group = "Builder", Name = "Build Mode Badge", Description = "Shows when construction input is active.", Scope = "Client", Enabled = true },
		{ Id = "B02", Group = "Builder", Name = "Test Edit Badge", Description = "Shows whether the active machine is being edited or tested.", Scope = "Client", Enabled = true },
		{ Id = "B03", Group = "Builder", Name = "Live Component Count", Description = "Surfaces replicated component count when available.", Scope = "Client", Enabled = true },
		{ Id = "B04", Group = "Builder", Name = "Live Mass Readout", Description = "Surfaces replicated machine mass when available.", Scope = "Client", Enabled = true },
		{ Id = "B05", Group = "Builder", Name = "Power Margin Readout", Description = "Shows machine power margin or deficit state.", Scope = "Client", Enabled = true },
		{ Id = "B06", Group = "Builder", Name = "Thermal Margin Readout", Description = "Shows thermal margin or heat risk state.", Scope = "Client", Enabled = true },
		{ Id = "B07", Group = "Builder", Name = "Placement State Feedback", Description = "Turns placement validity into a readable status chip.", Scope = "Client", Enabled = true },
		{ Id = "B08", Group = "Builder", Name = "Rotation Step Feedback", Description = "Shows the current builder rotation step when replicated.", Scope = "Client", Enabled = true },
		{ Id = "B09", Group = "Builder", Name = "Builder Warning Queue", Description = "Prioritizes invalid-placement and engineering warnings.", Scope = "Client", Enabled = true },
		{ Id = "B10", Group = "Builder", Name = "Contextual Build Controls", Description = "Shows concise controls only while build mode is active.", Scope = "Client", Enabled = true },

		{ Id = "V01", Group = "Vehicle", Name = "Speedometer", Description = "Shows live assembly speed in studs per second.", Scope = "Client", Enabled = true },
		{ Id = "V02", Group = "Vehicle", Name = "Vertical Speed", Description = "Shows climb and descent rate.", Scope = "Client", Enabled = true },
		{ Id = "V03", Group = "Vehicle", Name = "Throttle Indicator", Description = "Shows forward and reverse control intent.", Scope = "Client", Enabled = true },
		{ Id = "V04", Group = "Vehicle", Name = "Brake Indicator", Description = "Shows braking control state.", Scope = "Client", Enabled = true },
		{ Id = "V05", Group = "Vehicle", Name = "Reverse Indicator", Description = "Makes reverse intent explicit.", Scope = "Client", Enabled = true },
		{ Id = "V06", Group = "Vehicle", Name = "Airborne Indicator", Description = "Detects when the active assembly is off the ground.", Scope = "Client", Enabled = true },
		{ Id = "V07", Group = "Vehicle", Name = "Low Fuel Warning", Description = "Warns when normalized fuel becomes low.", Scope = "Client", Enabled = true },
		{ Id = "V08", Group = "Vehicle", Name = "Critical Heat Warning", Description = "Warns when normalized heat becomes critical.", Scope = "Client", Enabled = true },
		{ Id = "V09", Group = "Vehicle", Name = "Power Deficit Warning", Description = "Warns when the machine reports a power deficit.", Scope = "Client", Enabled = true },
		{ Id = "V10", Group = "Vehicle", Name = "Critical Damage Warning", Description = "Warns when machine health becomes critical.", Scope = "Client", Enabled = true },

		{ Id = "C01", Group = "Combat", Name = "Precision Crosshair", Description = "Adds a clean center reticle while piloting.", Scope = "Client", Enabled = true },
		{ Id = "C02", Group = "Combat", Name = "Dynamic Bloom Ring", Description = "Expands the reticle while firing and recovers it smoothly.", Scope = "Client", Enabled = true },
		{ Id = "C03", Group = "Combat", Name = "Primary Fire Pulse", Description = "Adds immediate primary-fire visual feedback.", Scope = "Client", Enabled = true },
		{ Id = "C04", Group = "Combat", Name = "Secondary Fire Pulse", Description = "Adds distinct secondary-fire visual feedback.", Scope = "Client", Enabled = true },
		{ Id = "C05", Group = "Combat", Name = "Hit Confirmation Hook", Description = "Displays server combat hit feedback when available.", Scope = "Client", Enabled = true },
		{ Id = "C06", Group = "Combat", Name = "Failure Warning Hook", Description = "Displays server combat rejection reasons when available.", Scope = "Client", Enabled = true },
		{ Id = "C07", Group = "Combat", Name = "Reload Feedback", Description = "Shows reload intent when reload is pressed.", Scope = "Client", Enabled = true },
		{ Id = "C08", Group = "Combat", Name = "Aim Focus FOV", Description = "Applies bounded aim focus while secondary aim is held.", Scope = "Client", Enabled = true },
		{ Id = "C09", Group = "Combat", Name = "Low Health Combat Vignette", Description = "Adds a restrained critical-health edge warning.", Scope = "Client", Enabled = true },
		{ Id = "C10", Group = "Combat", Name = "Fire State Cleanup", Description = "Clears presentation fire state on lifecycle changes.", Scope = "Client", Enabled = true },

		{ Id = "T01", Group = "Trade", Name = "Trade Safety Hint", Description = "Clarifies that a test drive does not transfer ownership.", Scope = "Client", Enabled = true },
		{ Id = "T02", Group = "Trade", Name = "Trade Countdown Hook", Description = "Supports a replicated trade countdown status.", Scope = "Client", Enabled = true },
		{ Id = "T03", Group = "Trade", Name = "Test Drive Banner Hook", Description = "Shows temporary vehicle/test-drive state when exposed.", Scope = "Client", Enabled = true },
		{ Id = "T04", Group = "Trade", Name = "Acceptance State Hook", Description = "Shows ready and not-ready trade state when exposed.", Scope = "Client", Enabled = true },
		{ Id = "T05", Group = "Trade", Name = "Offer Changed Warning Hook", Description = "Surfaces offer-change readiness invalidation.", Scope = "Client", Enabled = true },
		{ Id = "T06", Group = "Trade", Name = "Swap Cooldown Hook", Description = "Shows quick-swap cooldown state when exposed.", Scope = "Client", Enabled = true },
		{ Id = "T07", Group = "Trade", Name = "Quick Swap Slot Labels", Description = "Shows keyboard slot hints for three vehicle slots.", Scope = "Client", Enabled = true },
		{ Id = "T08", Group = "Trade", Name = "Active Slot Highlight", Description = "Highlights the replicated active vehicle slot.", Scope = "Client", Enabled = true },
		{ Id = "T09", Group = "Trade", Name = "Swap Blocked Warning Hook", Description = "Routes swap rejection reasons through the warning surface.", Scope = "Client", Enabled = true },
		{ Id = "T10", Group = "Trade", Name = "Trade Warning Priority", Description = "Ownership-changing warnings outrank cosmetic hints.", Scope = "Client", Enabled = true },

		{ Id = "O01", Group = "Onboarding", Name = "Welcome Objective", Description = "Gives first-session direction in the sandbox.", Scope = "Client", Enabled = true },
		{ Id = "O02", Group = "Onboarding", Name = "First Build Prompt", Description = "Introduces build mode before advanced controls.", Scope = "Client", Enabled = true },
		{ Id = "O03", Group = "Onboarding", Name = "First Part Milestone", Description = "Acknowledges the first placed component.", Scope = "Client", Enabled = true },
		{ Id = "O04", Group = "Onboarding", Name = "Ten Part Milestone", Description = "Acknowledges an early ten-component build milestone.", Scope = "Client", Enabled = true },
		{ Id = "O05", Group = "Onboarding", Name = "First Test Prompt", Description = "Points builders toward testing their machine.", Scope = "Client", Enabled = true },
		{ Id = "O06", Group = "Onboarding", Name = "First Drive Prompt", Description = "Introduces piloting controls after a machine is active.", Scope = "Client", Enabled = true },
		{ Id = "O07", Group = "Onboarding", Name = "First Fire Prompt", Description = "Introduces weapon input only after piloting.", Scope = "Client", Enabled = true },
		{ Id = "O08", Group = "Onboarding", Name = "Return To Edit Hint", Description = "Encourages iteration after a test run.", Scope = "Client", Enabled = true },
		{ Id = "O09", Group = "Onboarding", Name = "Next Step Resolver", Description = "Shows one useful next action instead of every hint.", Scope = "Client", Enabled = true },
		{ Id = "O10", Group = "Onboarding", Name = "Session Hint Cooldown", Description = "Prevents tutorial and milestone spam.", Scope = "Client", Enabled = true },

		{ Id = "A01", Group = "Accessibility", Name = "Auto UI Scale", Description = "Clamps polish HUD scale to viewport size.", Scope = "Client", Enabled = true },
		{ Id = "A02", Group = "Accessibility", Name = "High Contrast Preference", Description = "Allows stronger outlines and contrast through an attribute.", Scope = "Client", Enabled = true },
		{ Id = "A03", Group = "Accessibility", Name = "Reduced Motion Preference", Description = "Removes nonessential UI motion when requested.", Scope = "Both", Enabled = true },
		{ Id = "A04", Group = "Accessibility", Name = "Camera Motion Preference", Description = "Separately controls FOV and camera motion.", Scope = "Both", Enabled = true },
		{ Id = "A05", Group = "Accessibility", Name = "Screen Flash Preference", Description = "Separately controls brief fire and hit flashes.", Scope = "Both", Enabled = true },
		{ Id = "A06", Group = "Accessibility", Name = "Vignette Preference", Description = "Separately controls edge warning overlays.", Scope = "Both", Enabled = true },
		{ Id = "A07", Group = "Accessibility", Name = "Crosshair Scale Preference", Description = "Provides a bounded reticle scale attribute.", Scope = "Both", Enabled = true },
		{ Id = "A08", Group = "Accessibility", Name = "Text Scale Preference", Description = "Provides a bounded polish text scale attribute.", Scope = "Both", Enabled = true },
		{ Id = "A09", Group = "Accessibility", Name = "Input Aware Legend", Description = "Switches help wording between keyboard, gamepad, and touch.", Scope = "Client", Enabled = true },
		{ Id = "A10", Group = "Accessibility", Name = "Shape And Text Status", Description = "Never relies on color alone for important state.", Scope = "Client", Enabled = true },

		{ Id = "P01", Group = "Performance", Name = "Telemetry Rate Cap", Description = "Caps telemetry refresh instead of rebuilding every frame.", Scope = "Client", Enabled = true },
		{ Id = "P02", Group = "Performance", Name = "Lazy Mech Resolution", Description = "Resolves the active assembly only on state change and timed retry.", Scope = "Client", Enabled = true },
		{ Id = "P03", Group = "Performance", Name = "Build Only Hint Work", Description = "Suspends build guidance outside build mode.", Scope = "Client", Enabled = true },
		{ Id = "P04", Group = "Performance", Name = "Warning Object Reuse", Description = "Reuses one warning surface instead of creating labels repeatedly.", Scope = "Client", Enabled = true },
		{ Id = "P05", Group = "Performance", Name = "Reticle Object Reuse", Description = "Creates reticle primitives once and mutates them.", Scope = "Client", Enabled = true },
		{ Id = "P06", Group = "Performance", Name = "Attribute Debounce", Description = "Groups bursts of replicated state refreshes.", Scope = "Client", Enabled = true },
		{ Id = "P07", Group = "Performance", Name = "Adaptive Hidden Updates", Description = "Skips noncritical hidden HUD visual refreshes.", Scope = "Client", Enabled = true },
		{ Id = "P08", Group = "Performance", Name = "Bounded Raycast Rate", Description = "Runs airborne raycasts at telemetry cadence.", Scope = "Client", Enabled = true },
		{ Id = "P09", Group = "Performance", Name = "Bounded Notification Queue", Description = "Caps notifications and evicts stale low-priority items.", Scope = "Client", Enabled = true },
		{ Id = "P10", Group = "Performance", Name = "Connection Cleanup", Description = "Tracks and disconnects all controller event connections.", Scope = "Client", Enabled = true },

		{ Id = "W01", Group = "World", Name = "Heading Tape", Description = "Shows compact cardinal heading while piloting.", Scope = "Client", Enabled = true },
		{ Id = "W02", Group = "World", Name = "High Speed Indicator", Description = "Adds a readable high-speed state above a threshold.", Scope = "Client", Enabled = true },
		{ Id = "W03", Group = "World", Name = "Landing Pulse", Description = "Detects airborne-to-ground transitions for restrained feedback.", Scope = "Client", Enabled = true },
		{ Id = "W04", Group = "World", Name = "Climb Descent Arrow", Description = "Adds shape cues beside vertical speed.", Scope = "Client", Enabled = true },
		{ Id = "W05", Group = "World", Name = "Machine Name Chip", Description = "Shows active assembly name or ID compactly.", Scope = "Client", Enabled = true },
		{ Id = "W06", Group = "World", Name = "Ownership Chip", Description = "Shows owned, test-drive, or foreign state when replicated.", Scope = "Client", Enabled = true },
		{ Id = "W07", Group = "World", Name = "Engineering Alert Merge", Description = "Merges fuel, power, heat, and damage alerts into one surface.", Scope = "Client", Enabled = true },
		{ Id = "W08", Group = "World", Name = "Critical State Urgency", Description = "Pulses severe alerts only when motion is allowed.", Scope = "Client", Enabled = true },
		{ Id = "W09", Group = "World", Name = "Velocity State Label", Description = "Labels parked, rolling, fast, and airborne states.", Scope = "Client", Enabled = true },
		{ Id = "W10", Group = "World", Name = "Safe HUD Fade", Description = "Fades noncritical telemetry while construction is dominant.", Scope = "Client", Enabled = true },

		{ Id = "R01", Group = "Reliability", Name = "Master Polish Flag", Description = "Allows the whole pack to be disabled without deleting code.", Scope = "Both", Enabled = true },
		{ Id = "R02", Group = "Reliability", Name = "Per Improvement Flags", Description = "Gives every catalog record an independent enabled flag.", Scope = "Both", Enabled = true },
		{ Id = "R03", Group = "Reliability", Name = "Catalog Validation", Description = "Validates exact count, required fields, and unique IDs.", Scope = "Server", Enabled = true },
		{ Id = "R04", Group = "Reliability", Name = "Optional Remote Detection", Description = "Missing optional feedback remotes cannot crash the client.", Scope = "Client", Enabled = true },
		{ Id = "R05", Group = "Reliability", Name = "Camera Reacquisition", Description = "Reacquires CurrentCamera after Roblox replaces it.", Scope = "Client", Enabled = true },
		{ Id = "R06", Group = "Reliability", Name = "Late Mech Retry", Description = "Retries active-mech resolution when replication arrives late.", Scope = "Client", Enabled = true },
		{ Id = "R07", Group = "Reliability", Name = "Destroyed Mech Recovery", Description = "Clears destroyed assembly references safely.", Scope = "Client", Enabled = true },
		{ Id = "R08", Group = "Reliability", Name = "Character Respawn Recovery", Description = "Rebinds player-health presentation after respawn.", Scope = "Client", Enabled = true },
		{ Id = "R09", Group = "Reliability", Name = "Payload Shape Validation", Description = "Validates optional server feedback before display use.", Scope = "Client", Enabled = true },
		{ Id = "R10", Group = "Reliability", Name = "Startup Readiness State", Description = "Publishes whether the polish pack loaded successfully.", Scope = "Server", Enabled = true },

		{ Id = "Q01", Group = "QualityOfLife", Name = "Cinematic HUD Toggle", Description = "F10 hides polish HUD for screenshots and recording.", Scope = "Client", Enabled = true },
		{ Id = "Q02", Group = "QualityOfLife", Name = "Compact HUD Toggle", Description = "H collapses noncritical telemetry while preserving warnings.", Scope = "Client", Enabled = true },
		{ Id = "Q03", Group = "QualityOfLife", Name = "Aim Focus Layout", Description = "Hides unrelated helper text around the reticle while aiming.", Scope = "Client", Enabled = true },
		{ Id = "Q04", Group = "QualityOfLife", Name = "Duplicate Toast Suppression", Description = "Refreshes repeated identical warnings instead of stacking them.", Scope = "Client", Enabled = true },
		{ Id = "Q05", Group = "QualityOfLife", Name = "Priority Notification Ordering", Description = "Critical gameplay warnings outrank tutorial hints.", Scope = "Client", Enabled = true },
		{ Id = "Q06", Group = "QualityOfLife", Name = "Stale Notification Expiry", Description = "Expires warnings after their valid display window.", Scope = "Client", Enabled = true },
		{ Id = "Q07", Group = "QualityOfLife", Name = "Safe Area Padding", Description = "Keeps polish HUD away from screen edges and inset areas.", Scope = "Client", Enabled = true },
		{ Id = "Q08", Group = "QualityOfLife", Name = "Critical Health Pulse", Description = "Adds restrained urgency below the critical-health threshold.", Scope = "Client", Enabled = true },
		{ Id = "Q09", Group = "QualityOfLife", Name = "Polish Status Attributes", Description = "Exposes version, readiness, and enabled count in Studio.", Scope = "Server", Enabled = true },
		{ Id = "Q10", Group = "QualityOfLife", Name = "Built In Help Hint", Description = "Makes F10, H, and comfort controls discoverable.", Scope = "Client", Enabled = true },
	} :: {PolishItem},
	ById = {} :: {[string]: PolishItem},
}

for _, item in ipairs(Catalog.Items) do
	assert(item.Id:match("^[A-Z]%d%d$") ~= nil, "invalid polish id " .. item.Id)
	assert(Catalog.ById[item.Id] == nil, "duplicate polish id " .. item.Id)
	Catalog.ById[item.Id] = item
end

assert(#Catalog.Items == 100, "PolishCatalog must contain exactly 100 improvements")

function Catalog.IsEnabled(id: string): boolean
	if not Catalog.MasterEnabled then
		return false
	end
	local item = Catalog.ById[id]
	return item ~= nil and item.Enabled == true
end

return Catalog
