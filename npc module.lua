-- Disord user: Bobby36746 Roblox User: Bobbywasabi5888
-- This is an NPC AI combat controller
-- I know its close, but this script is indeed over 200 lines, not including blanks lines.
local module = {} 
local states = require(game.ServerScriptService:WaitForChild("States")) -- This module script handles states like stuns, blocking, and cooldowns.
module.__index = module
local blocking = require(game.ServerScriptService.Blocking)
function module.new(npc, style)
	local self = setmetatable({}, module) -- sets metatable for the npc
	self.Char = npc
	local hum = npc:WaitForChild("Humanoid")
	if not hum then return end
	self.Hum = hum
	self.Style = style -- style is the fighting style chosen when the npc is created
	local stylemodule = require(game.ReplicatedStorage:WaitForChild(style)) -- fighting style module script with functions that perform fighting moves.
	if not stylemodule then print("no module") return end
	self.StyleModule = stylemodule -- stores the fighting style module
	local animator = self.Hum:WaitForChild("Animator")
	if not animator then return end
	self.Animator = animator
	self.Combo = 0 -- stores the m1 combo
	self.LastM1 = 0 -- stores the time of the last m1
	local root = npc:WaitForChild("HumanoidRootPart")
	if not root then return end
	self.Root = root
	local att = Instance.new("Attachment") -- attachment for the align pos
	att.Parent = self.Root
	local align = Instance.new("AlignOrientation") -- align position for facing the current player target
	align.Attachment0 = att
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Responsiveness = 20
	align.Parent = self.Root
	self.Align = align
	self.DoingM1 = false
	self.Target = nil -- this will store the current player target
	local conn2
	conn2 = self.Hum.Died:Connect(function() -- remove the current attacker attribute to the target if the npc dies
		self:Cleanup()
		conn2:Disconnect()
	end)
	self:Start() -- starts the npc loop
	return self
end

function module:GetClosestPlayer()
	local closest = nil
	local range = 20 -- max detect range
	for _, player in pairs(game.Players:GetPlayers()) do -- loops through all the players
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local hum = char.Humanoid
			if not hum or hum.Health <= 0 then continue end
			local distance = (char.HumanoidRootPart.Position - self.Root.Position).Magnitude -- gets the distance between the npc and the closest player
			
			if distance < range then -- if the player is in range then it stores the "closest" variable as that player
				closest = player
			end
		end
	end
	if closest then
	self.Target = closest -- sets the npcs current target as the stored player
	end
end

function module:FollowPlayer(player)
	local char = player.Character
	if not char then return end
	if states.GetState(self.Char, "Stunned") then return end -- if npc is stunned then end
	if states.GetState(self.Char, "Blocking") then return end -- if npc is blocking then end
	local targetRoot = char:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end
	local targetpos = targetRoot.Position -- position of the target
	local myPos = self.Root.Position -- position of the npc
	local dist = (targetpos - myPos).Magnitude
	if char:GetAttribute("CurrentAttacker") and char:GetAttribute("CurrentAttacker")  ~= self.Char.Name then -- This detects if the target is already being attacked by another npc, if so it will stay still.
		self.Hum:MoveTo(myPos) -- stay still
		return
	end
	if not char:GetAttribute("CurrentAttacker") then
		char:SetAttribute("CurrentAttacker", self.Char.Name) -- Set targets current attacker as the npc so they cant be jumped by other npcs.
	end
	local right = targetRoot.CFrame.RightVector
	local offset = right * math.random(-4,4)
	local movePos = targetpos + offset
	self.Hum:MoveTo(movePos)  -- Move to player with a random offset for realism.
end

function module:FaceCharacter(character)
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	self.Align.CFrame = CFrame.lookAt(self.Root.Position, root.Position) -- Align position so the npc faces the player smoothly
end

function module:Dist(char1, char2)
	return (char1.HumanoidRootPart.Position - char2.HumanoidRootPart.Position).Magnitude -- Return the distance from one character to another
end

function module:M1Chain()
	local anims = game.ReplicatedStorage.Anims:WaitForChild(self.Style.."M1s") -- gets the m1 animations for the npcs fighting style
	if states.GetState(self.Char, "Attacking") then return end -- if they are already doing an attack then end
	for i = 1, 4 do -- M1 Loop
		if not self.Target or not self.Target.Character then break end -- if there is no current target then end
		if states.GetState(self.Char, "Stunned") then break end -- if stunned then end
		if states.GetState(self.Char, "Blocking") then break end -- if blocking then end
		local target = self.Target
		if not target or not target.Character then break end
		if self:Dist(self.Char, target.Character) > 10 then break end -- if the npc is too far from the target then end
		local att = target.Character:GetAttribute("CurrentAttacker")
		if att and att ~= self.Char.Name then
		break -- If the players current attacker isnt the npc then it stops to prevent the player from being jumped by multiple npcs
		end
		if os.clock() - self.LastM1 > 1 then -- Resets the m1 combo if its been too long
			self.Combo = 0
		end
		self.Combo = math.clamp(self.Combo + 1, 1, 4) -- sets the current combo with a max of 4
		local anim = self.Animator:LoadAnimation(anims["M"..self.Combo]) -- finds the M1 animation based on the current combo number
		local hitfired = false
		local conn
		conn = anim:GetMarkerReachedSignal("Hit"):Connect(function() -- waits for the hitmarker "Hit" of the animation so the hitbox syncs with the animation.
			if hitfired then return end -- just in case the hitmarker has already been hit.
			hitfired = true
			if self.Combo == 4 then -- if the current combo is 4 then it does the last m1 function in fighting style module, which does more knockback and damage.
				self.StyleModule.LastM1(self.Char) -- here it does the last m1 functions
				states.SetState(self.Char, "M1CD", 0.75) -- sets a longer cooldown for last hit of the combo
			else
				self.StyleModule.M1(self.Char) -- does the regular m1 function in fighting style module
				states.SetState(self.Char, "M1CD", 0.4) -- sets m1 cooldown
			end
			conn:Disconnect()
		end)
		anim:Play()
		self.LastM1 = os.clock() -- stores the time of the last m1
		task.wait(0.42) -- delay between m1s
	end
	self.Combo = 0 -- after the loop it sets the combo back to 0.
end

function module:Block()
	if states.GetState(self.Char, "Stunned") then return end -- they cant block if they are stunned or performing an attack
	if states.GetState(self.Char, "Attacking") then return end
	local anim = self.Animator:LoadAnimation(game.ReplicatedStorage.Anims.Block) -- gets the block animation
	if not anim then return end
	anim:Play() -- plays the block animation
	blocking.Block(self.Char) -- uses the blocking function in the blocking module, which uses the state module to set a blocking state.
	local random = math.random(30,200)/100 -- blocks for a random amount of time for realism
	task.delay(random, function()
		anim:Stop() -- stop blocking animation
		blocking.Unblock(self.Char) -- uses the unblock function which removes the blocking state
	end)
end
function module:Decide(enemy) -- picks an action for the npc to do
	local random = math.random(1,10) -- picks random number
	if enemy:GetAttribute("CurrentAttacker") and enemy:GetAttribute("CurrentAttacker") ~= self.Char.Name then -- again, if there is a current attacker on the player and its not this npc then end
		return
	end
	if states.GetState(enemy, "Attacking") then -- checks what the enemy player is doing and picks an action accordingly
		if random > 6 then -- higher chance of blocking if the enemy player is attacking
			self:Block()
		else
			self:M1Chain()
		end
	elseif states.GetState(enemy, "Blocking") then
		if random > 9 then  -- random action, lower chance of blocking if the enemy player is blocking
		self:Block()
	else
		self:M1Chain()
	end
	else
		if random > 8 then  -- most likely will attack if the enemy player is not attacking
			self:Block()
		else
			self:M1Chain()
		end
	end
end

function module:Start()
	local attacking = false
	task.spawn(function()
	while task.wait(0.1) do -- core npc loop
		if not self.Char or self.Hum.Health <= 0 then self:Cleanup() break end -- if the npc has died then end 
		local target = self.Target
		if not target or not target.Character then continue end -- if theres no enemy target then end 
		local dist = self:Dist(self.Char, self.Target.Character)
		self:FaceCharacter(self.Target.Character)
			if dist < 6 then -- only attacks if the target is in range
			if not attacking then -- only attacks if they are not already attacking
				attacking = true
				task.spawn(function()
					if self.Target.Character:GetAttribute("CurrentAttacker") and self.Target.Character:GetAttribute("CurrentAttacker") ~= self.Char.Name then -- again, if current attacker isnt the npc then end
						attacking = false
						return
					end
					self:Decide(self.Target.Character) -- picks a random action
					attacking = false -- sets attacking back to false after
				end)
			end
		else
			self:FollowPlayer(self.Target) -- if the target is more then 6 studs away follow them
		end
		if dist > 20 then -- resets if the enemy is too far
			self:Cleanup()
		end
	end
	end)
	task.spawn(function() -- find closest player loop
		while task.wait(0.5) do
			self:GetClosestPlayer()
		end
	end)
end

function module:Cleanup()
    if not self.Target then
        return
    end
    if self.Target.Character then
        self.Target.Character:SetAttribute("CurrentAttacker", nil)
    end
    self.Target = nil
end

return module
