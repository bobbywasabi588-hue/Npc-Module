-- Disord user: Bobby36746 Roblox User: Bobbywasabi5888
local module = {} 
local states = require(game.ServerScriptService:WaitForChild("States"))
module.__index = module
local pathfinding = game:GetService("PathfindingService")
local blocking = require(game.ServerScriptService.Blocking)
function module.new(npc, style)
	local self = setmetatable({}, module)
	self.Char = npc
	self.Hum = npc:WaitForChild("Humanoid")
	self.Style = style
	local module = require(game.ReplicatedStorage:WaitForChild(style)) -- fighting style module script with moves
	if not module then print("no module") return end
	self.StyleModule = module
	self.Animator = self.Hum.Animator
	self.Combo = 0
	self.LastM1 = 0
	self.Root = npc:WaitForChild("HumanoidRootPart")
	local att = Instance.new("Attachment")
	att.Parent = self.Root
	local align = Instance.new("AlignOrientation") -- align position for facing the target
	align.Attachment0 = att
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Responsiveness = 20
	align.Parent = self.Root
	self.Align = align
	self.DoingM1 = false
	self.Target = nil
	local conn2
	conn2 = self.Hum.Died:Connect(function() -- remove the current attacker attribute to the target if the npc dies
		if self.Target and self.Target.Character then
			self.Target.Character:SetAttribute("CurrentAttacker", nil)
		end
		conn2:Disconnect()
	end)
	self:Start()
	return self
end
function module:GetClosestPlayer()
	local closest = nil
	local range = 20
	for _, player in pairs(game.Players:GetPlayers()) do -- set the target as the closest player
		local char = player.Character
		
		if char and char:FindFirstChild("HumanoidRootPart") then
			local hum = char.Humanoid
			if not hum or hum.Health <= 0 then continue end
			local distance = (char.HumanoidRootPart.Position - self.Char.HumanoidRootPart.Position).Magnitude
			
			if distance < range then
				range = distance
				closest = player
			end
		end
		
	end
	if closest then
	self.Target = closest
	end
end

function module:FollowPlayer(player)
	local char = player.Character
	if not char then return end
	if states.GetState(self.Char, "Stunned") then return end -- if npc is stunned then end
	if states.GetState(self.Char, "Blocking") then return end -- if npc is blocking then end
	local targetRoot = char:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local targetpos = targetRoot.Position
	local myPos = self.Root.Position

	local dist = (targetpos - myPos).Magnitude
	if char:GetAttribute("CurrentAttacker") and char:GetAttribute("CurrentAttacker")  ~= self.Char.Name then -- If the enemy player is being attacked by another npc, stay put.
		self.Hum:MoveTo(myPos)
		return
	end
	if not char:GetAttribute("CurrentAttacker") then
		char:SetAttribute("CurrentAttacker", self.Char.Name) -- Set their current attacker as the npc.
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
	local anims = game.ReplicatedStorage.Anims:WaitForChild(self.Style.."M1s")
	if states.GetState(self.Char, "Attacking") then return end
	for i = 1, 4 do -- M1 Loop
		if not self.Target or not self.Target.Character then break end
		if states.GetState(self.Char, "Stunned") then break end
		if states.GetState(self.Char, "Blocking") then break end
		if self:Dist(self.Char, self.Target.Character) > 10 then break end
		local target = self.Target
		if target and target.Character then
			local att = target.Character:GetAttribute("CurrentAttacker")
			if att and att ~= self.Char.Name then
				break -- If the players current attacker isnt the npc then stop.
			end
		end
		if os.clock() - self.LastM1 > 1 then -- Reset the m1 combo if its been too long
			self.Combo = 0
		end
		self.Combo = math.clamp(self.Combo + 1, 1, 4)
		local anim = self.Animator:LoadAnimation(anims["M"..self.Combo]) -- M1 animation
		local hitfired = false
		local conn
		conn = anim:GetMarkerReachedSignal("Hit"):Connect(function()
			if hitfired then return end
			hitfired = true
			if self.Combo == 4 then
				self.StyleModule.LastM1(self.Char) -- do the last m1 function in fighting style module
				states.SetState(self.Char, "M1CD", 0.75) -- longer cooldown for last hit
			else
				self.StyleModule.M1(self.Char)
				states.SetState(self.Char, "M1CD", 0.4) -- do the regular m1 function in fighting style module
			end
			conn:Disconnect()
		end)
		anim:Play()
		self.LastM1 = os.clock()
		task.wait(0.42) -- delay between m1s
	end
	self.Combo = 0
end

function module:Block()
	if states.GetState(self.Char, "Stunned") then return end
	if states.GetState(self.Char, "Attacking") then return end
	local anim = self.Animator:LoadAnimation(game.ReplicatedStorage.Anims.Block)
	anim:Play()
	blocking.Block(self.Char) -- use the blocking function in the blocking module.
	local random = math.random(30,200)/100 -- block for a random amount of time
	task.delay(random, function()
		anim:Stop() -- stop blocking
		blocking.Unblock(self.Char)
	end)
end

function module:Decide(enemy)
	local random = math.random(1,10)
	if enemy:GetAttribute("CurrentAttacker") and enemy:GetAttribute("CurrentAttacker") ~= self.Char.Name then
		return
	end
	if states.GetState(enemy, "Attacking") then -- check what the enemy is doing and pick an action accordingly
		if random > 6 then -- random action
			self:Block()
		else
			self:M1Chain()
		end
	elseif states.GetState(enemy, "Blocking") then
		if random > 9 then  -- random action
		self:Block()
	else
		self:M1Chain()
	end
	else
		if random > 8 then  -- random action
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
		if not self.Char or self.Hum.Health <= 0 then break end
		if not self.Target or not self.Target.Character then continue end -- if theres no enemy target then end 
		local dist = self:Dist(self.Char, self.Target.Character)
		self:FaceCharacter(self.Target.Character)
			if dist < 6 and self.Target.Character:GetAttribute("CurrentAttacker") == self.Char.Name then
			if not attacking then
				attacking = true
				task.spawn(function()
					if self.Target and self.Target.Character then
						if self.Target.Character:GetAttribute("CurrentAttacker") and self.Target.Character:GetAttribute("CurrentAttacker") ~= self.Char.Name then -- again, if currnet attacker isnt the npc then end
							return
						end
					end
					self:Decide(self.Target.Character)
					attacking = false
				end)
			end
		else
			self:FollowPlayer(self.Target) -- if they are more then 6 studs away follow them
		end
		if dist > 20 and self.Target and self.Target.Character then -- reset if the enemy is too far
			self.Target.Character:SetAttribute("CurrentAttacker", nil)
			self.Target = nil
		end
	end
	end)
	task.spawn(function() -- find closest player loop
		while wait(0.5) do
			self:GetClosestPlayer()
		end
	end)
end

return module
