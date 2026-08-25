-- ServerScriptService > PenguinCharacterServer

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PENGUIN_TEMPLATE = ServerStorage:WaitForChild("penguin")

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local RESPAWN_TIME = 3

local WALK_ANIMATION_ID = "rbxassetid://109050079843376"
local IDLE_ANIMATION_ID = "rbxassetid://77527506853580"
local JUMP_ANIMATION_ID = "rbxassetid://92655325972819"

--------------------------------------------------
-- FIND SPAWN
--------------------------------------------------

local function getSpawnCFrame(player)

	if player.RespawnLocation then
		return player.RespawnLocation.CFrame + Vector3.new(0, 4, 0)
	end

	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("SpawnLocation") then

			if object.Neutral or object.TeamColor == player.TeamColor then
				return object.CFrame + Vector3.new(0, 4, 0)
			end

		end
	end

	return CFrame.new(0, 10, 0)
end

--------------------------------------------------
-- CREATE ANIMATION
--------------------------------------------------

local function createAnimationTrack(
	animator,
	animationId,
	looped,
	priority
)

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local track = animator:LoadAnimation(animation)

	track.Looped = looped
	track.Priority = priority

	return track
end

--------------------------------------------------
-- SETUP PENGUIN ANIMATIONS
--------------------------------------------------

local function setupAnimations(character, humanoid)

	--------------------------------------------------
	-- REMOVE DEFAULT ROBLOX ANIMATE SCRIPT
	--------------------------------------------------

	local defaultAnimate = character:FindFirstChild("Animate")

	if defaultAnimate then
		defaultAnimate:Destroy()
	end

	--------------------------------------------------
	-- ANIMATOR
	--------------------------------------------------

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then

		animator = Instance.new("Animator")
		animator.Parent = humanoid

	end

	--------------------------------------------------
	-- LOAD ANIMATIONS
	--------------------------------------------------

	local idleTrack = createAnimationTrack(
		animator,
		IDLE_ANIMATION_ID,
		true,
		Enum.AnimationPriority.Idle
	)

	local walkTrack = createAnimationTrack(
		animator,
		WALK_ANIMATION_ID,
		true,
		Enum.AnimationPriority.Movement
	)

	local jumpTrack = createAnimationTrack(
		animator,
		JUMP_ANIMATION_ID,
		false,
		Enum.AnimationPriority.Action
	)

	--------------------------------------------------
	-- STATE
	--------------------------------------------------

	local currentSpeed = 0
	local airborne = false

	--------------------------------------------------
	-- HELPERS
	--------------------------------------------------

	local function playIdle()

		if airborne then
			return
		end

		if walkTrack.IsPlaying then
			walkTrack:Stop(0.15)
		end

		if not idleTrack.IsPlaying then
			idleTrack:Play(0.15)
		end

	end

	local function playWalk()

		if airborne then
			return
		end

		if idleTrack.IsPlaying then
			idleTrack:Stop(0.15)
		end

		if not walkTrack.IsPlaying then
			walkTrack:Play(0.15)
		end

	end

	local function playJump()

		airborne = true

		if idleTrack.IsPlaying then
			idleTrack:Stop(0.1)
		end

		if walkTrack.IsPlaying then
			walkTrack:Stop(0.1)
		end

		if jumpTrack.IsPlaying then
			jumpTrack:Stop(0)
		end

		jumpTrack:Play(0.05)

	end

	local function returnToGroundAnimation()

		airborne = false

		if jumpTrack.IsPlaying then
			jumpTrack:Stop(0.1)
		end

		if currentSpeed > 0.1 then
			playWalk()
		else
			playIdle()
		end

	end

	--------------------------------------------------
	-- WALKING / IDLE
	--------------------------------------------------

	humanoid.Running:Connect(function(speed)

		currentSpeed = speed

		if airborne then
			return
		end

		if speed > 0.1 then
			playWalk()
		else
			playIdle()
		end

	end)

	--------------------------------------------------
	-- JUMPING
	--------------------------------------------------

	humanoid.StateChanged:Connect(function(_, newState)

		if newState == Enum.HumanoidStateType.Jumping then

			playJump()

		elseif
			newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics
		then

			if airborne then
				returnToGroundAnimation()
			end

		end

	end)

	--------------------------------------------------
	-- START IDLE
	--------------------------------------------------

	idleTrack:Play(0.15)

end

--------------------------------------------------
-- CREATE PENGUIN
--------------------------------------------------

local function spawnPenguin(player)

	--------------------------------------------------
	-- REMOVE OLD CHARACTER
	--------------------------------------------------

	if player.Character then
		player.Character:Destroy()
	end

	--------------------------------------------------
	-- CLONE PENGUIN
	--------------------------------------------------

	local character = PENGUIN_TEMPLATE:Clone()
	character.Name = player.Name

	local humanoid =
		character:FindFirstChildOfClass("Humanoid")

	local rootPart =
		character:FindFirstChild("HumanoidRootPart")

	if not humanoid then

		warn(
			"penguin model needs a Humanoid!"
		)

		character:Destroy()

		return

	end

	if not rootPart then

		warn(
			"penguin model needs a HumanoidRootPart!"
		)

		character:Destroy()

		return

	end

	--------------------------------------------------
	-- UNANCHOR
	--------------------------------------------------

	for _, object in ipairs(character:GetDescendants()) do

		if object:IsA("BasePart") then
			object.Anchored = false
		end

	end

	character.PrimaryPart = rootPart

	--------------------------------------------------
	-- SPAWN
	--------------------------------------------------

	character.Parent = workspace

	character:PivotTo(
		getSpawnCFrame(player)
	)

	player.Character = character

	--------------------------------------------------
	-- ANIMATIONS
	--------------------------------------------------

	setupAnimations(character, humanoid)

	--------------------------------------------------
	-- DEATH
	--------------------------------------------------

	humanoid.Died:Connect(function()

		task.wait(RESPAWN_TIME)

		if player.Parent then
			spawnPenguin(player)
		end

	end)

end

--------------------------------------------------
-- PLAYER HANDLING
--------------------------------------------------

Players.CharacterAutoLoads = false

Players.PlayerAdded:Connect(function(player)

	spawnPenguin(player)

end)

--------------------------------------------------
-- HANDLE EXISTING PLAYERS
--------------------------------------------------

for _, player in ipairs(Players:GetPlayers()) do

	task.spawn(
		spawnPenguin,
		player
	)

end