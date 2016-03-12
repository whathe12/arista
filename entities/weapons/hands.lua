AddCSLuaFile()

-- Check if we're running on the client.
if CLIENT then
	surface.CreateFont("CSKillIcons", {
		font = "csd",
		size = 100,
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = false,
		shadow = false,
		additive = true,
	})

	surface.CreateFont("CSSelectIcons", {
		font = "csd",
		size = 100,
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = false,
		shadow = false,
		additive = true,
	})

	SWEP.PrintName = "Hands"
	SWEP.Slot = 1
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false
	SWEP.IconLetter = "H"
	SWEP.DrawCrosshair = false

	function SWEP:DrawWeaponSelection(x, y, wide, tall, alpha)
		draw.SimpleText(self.IconLetter, "CSSelectIcons", x + 0.59 * wide, y + tall * 0.2, Color(255, 220, 0, 255), TEXT_ALIGN_CENTER )
		self:PrintWeaponInfo(x + wide + 20, y + tall * 0.95, alpha)
	end

	killicon.AddFont("hands", "CSKillIcons", SWEP.IconLetter, Color(255, 80, 0, 255))
end

-- Define some shared variables.
SWEP.Author	= "Lexi"

-- Bitchin smart lookin instructions o/
local title_color = "<color=230,230,230,255>"
local text_color = "<color=150,150,150,255>"
local end_color = "</color>"
SWEP.Instructions =	end_color..title_color.."Primary Fire:\t"..						end_color..text_color.." Punch / Throw\n"..
										end_color..title_color.."Secondary Fire:\t"..					end_color..text_color.." Knock / Pick Up / Drop\n"..
										end_color..title_color.."Sprint+Primary Fire:"..		end_color..text_color.." Lock\n"..
										end_color..title_color.."Sprint+Secondary Fire:"..	end_color..text_color.." Unlock"
SWEP.Purpose = "Picking stuff up, knocking on doors and punching people."

-- Set the view model and the world model to nil.
SWEP.ViewModel = Model("models/weapons/c_arms.mdl")
SWEP.WorldModel = ""

-- Set the animation prefix and some other settings.
SWEP.AnimPrefix	= "admire"
SWEP.Spawnable = false
SWEP.AdminSpawnable = false
SWEP.UseHands	= true
SWEP.ViewModelFOV	= 50

-- Set the primary fire settings.
SWEP.Primary.Damage = 1.5
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Primary.Force = 5
SWEP.Primary.PunchAcceleration = 100
SWEP.Primary.ThrowAcceleration = 200
SWEP.Primary.Super = false
SWEP.Primary.Refire = 1
SWEP.Primary.Sound = Sound("WeaponFrag.Throw")

-- Set the secondary fire settings.
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo	= ""

-- Set the iron sight positions (pointless here).
SWEP.IronSightPos = Vector(0, 0, 0)
SWEP.IronSightAng = Vector(0, 0, 0)
SWEP.NoIronSightFovChange = true
SWEP.NoIronSightAttack = true
SWEP.HeldEnt = NULL

-- Called when the SWEP is initialized.
function SWEP:Initialize()
	self.Primary.NextSwitch = CurTime()
	self:SetWeaponHoldType("normal")
	self.stamina = GAMEMODE:GetPlugin("stamina")
end

function SWEP:Deploy()
	self:SetWeaponHoldType("normal")

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_draw"))

	self:UpdateNextIdle()
end


function SWEP:SetupDataTables()
	self:NetworkVar("Float", 1, "NextIdle")
end

function SWEP:UpdateNextIdle()
	local vm = self.Owner:GetViewModel()
	self:SetNextIdle(CurTime() + vm:SequenceDuration())
end

local range = 128 ^ 2

-- Called when the player attempts to primary fire.
function SWEP:PrimaryAttack()

	self.Weapon:SetNextPrimaryFire(CurTime() + self.Primary.Refire)

	if IsValid(self.HeldEnt)then
		self:dropObject(self.Primary.ThrowAcceleration)

		return
	end

	if not self.Owner:KeyDown(IN_SPEED) and self.Owner:isExausted() then
		return
	end

	-- Set the animation of the weapon and play the sound.
	self.Weapon:EmitSound(self.Primary.Sound)

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_left"))

	self:UpdateNextIdle()

	-- Get an eye trace from the owner.
	local trace = self.Owner:GetEyeTrace()
	local ent = trace.Entity

	-- Check the hit position of the trace to see if it's close to us.
	if IsValid(ent) and self.Owner:GetPos():DistToSqr(trace.HitPos) <= range then
		if ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_ragdoll" and not self.Owner:KeyDown(IN_SPEED) then
			if not self.Primary.Super and trace.Entity:IsPlayer() and ent:Health() - self.Primary.Damage <= 15 then
				if CLIENT then return true end

				arista.logs.event(arista.logs.E.LOG, arista.logs.E.DAMAGE, self.Owner:Name(), "(", self.Owner:SteamID(), ") knocked ", ent:Name(), " out with a punch.")

				ent:setAristaVar("stunned", true)
				ent:knockOut(ent:getAristaVar("knockOutTime") / 2)
			else
				local bullet = {}

				-- Set some information for the bullet.
				bullet.Num = 1
				bullet.Src = self.Owner:GetShootPos()
				bullet.Dir = self.Owner:GetAimVector()
				bullet.Spread = Vector(0, 0, 0)
				bullet.Tracer = 0
				bullet.Force = self.Primary.Force
				bullet.Damage = self.Primary.Damage

				if self.Primary.Super then
					if SERVER and ent:IsPlayer() then
						arista.logs.event(arista.logs.E.LOG, arista.logs.E.DAMAGE, self.Owner:Name(), "(", self.Owner:SteamID(), ") super punched ", ent:Name(), ".")
					end

					bullet.Callback	= function ( attacker, tr, dmginfo )
						if not IsValid(ent) then return end

						local effectData = EffectData()

						-- Set the information for the effect.
						effectData:SetStart(tr.HitPos)
						effectData:SetOrigin(tr.HitPos)
						effectData:SetScale(1)

						-- Create the effect from the data.
						util.Effect("Explosion", effectData)

					end
				end

				-- Fire bullets from the owner which will hit the trace entity.
				self.Owner:FireBullets(bullet)
			end
		else
			if self.Owner:KeyDown(IN_SPEED) then
				self.Weapon:SetNextPrimaryFire(CurTime() + 0.75)
				self.Weapon:SetNextSecondaryFire(CurTime() + 0.75)

				-- Keys!
				if CLIENT then return end

				if arista.entity.isOwnable(ent) and not ent:isJammed() then
					if arista.entity.hasAccess(ent, self.Owner) then
						trace.Entity:lock()
						trace.Entity:EmitSound("doors/door_latch3.wav")
					else
						self.Owner:notify("AL_CANNOT_NOACCESS")
					end
				end

				return
			else
				local phys = ent:GetPhysicsObject()

				if SERVER and IsValid(phys) and phys:IsMoveable() then
					ent:GetPhysicsObject():ApplyForceOffset(self.Owner:GetAimVector() * self.Primary.PunchAcceleration * phys:GetMass(), trace.HitPos)

					if self.Primary.Super then
						ent:TakeDamage(self.Primary.Damage, self.Owner)
					end
				end
			end
		end

		-- Check if the trace hit an entity or the world.
		if (trace.Hit or trace.HitWorld) then self.Weapon:EmitSound("weapons/crossbow/hitbod2.wav") end
	end

	if SERVER and self.stamina and not self.Primary.Super then
		self.Owner:setAristaVar("stamina", math.Clamp(self.Owner:getStamina() - 20, 0, 100))
	end
end

-- Called when the player attempts to secondary fire.
function SWEP:SecondaryAttack()
	self.Weapon:SetNextSecondaryFire(CurTime() + 0.25)

	if IsValid(self.HeldEnt)then
		self:dropObject()

		return
	end

	-- Get a trace from the owner's eyes.
	local trace = self.Owner:GetEyeTrace()
	local ent = trace.Entity

	-- Check the hit position of the trace to see if it's close to us.
	if IsValid(ent) and self.Owner:GetPos():DistToSqr(trace.HitPos) <= range then

		if arista.entity.isOwnable(ent) then
			local vm = self.Owner:GetViewModel()
			vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_right"))

			self:UpdateNextIdle()

			if self.Owner:KeyDown(IN_SPEED) then
				self.Weapon:SetNextPrimaryFire(CurTime() + 0.75)
				self.Weapon:SetNextSecondaryFire(CurTime() + 0.75)

				-- Keys!
				if CLIENT then return end

				if arista.entity.isOwnable(ent) and not ent:isJammed() then
					if arista.entity.hasAccess(ent, self.Owner) then
						trace.Entity:unLock()
						trace.Entity:EmitSound("doors/door_latch3.wav")
					else
						self.Owner:notify("AL_CANNOT_NOACCESS")
					end
				end

				return
			elseif arista.entity.isDoor(ent) then
				self.Weapon:EmitSound("physics/wood/wood_crate_impact_hard2.wav")
				if self.Primary.Super and SERVER and arista.utils.isAdmin(self.Owner, true) then
					arista.entity.openDoor(ent, 0, true, true)
				end

				return
			end
		end

		self:pickUp(ent, trace)
	end
end

function SWEP:Reload()
	if self.Primary.NextSwitch > CurTime() then return false end
	if arista.utils.isAdmin(self.Owner) and self.Owner:KeyDown(IN_SPEED) then

		if self.Primary.Super then
			self.Primary.PunchAcceleration = 100
			self.Primary.ThrowAcceleration = 200
			self.Primary.Damage = 1.5
			self.Primary.Super = false
			self.Primary.Refire = 1
			self.Owner:PrintMessage(HUD_PRINTCENTER, "Super mode disabled")
		else
			self.Primary.PunchAcceleration = 500
			self.Primary.ThrowAcceleration = 1000
			self.Primary.Damage = 200
			self.Primary.Super = true
			self.Primary.Refire = 0
			self.Owner:PrintMessage(HUD_PRINTCENTER, "Super mode enabled")
		end

		self.Primary.NextSwitch = CurTime() + 1
	end
end

function SWEP:Think()
	local vm = self.Owner:GetViewModel()
	local curtime = CurTime()
	local idletime = self:GetNextIdle()

	if idletime > 0 and CurTime() > idletime then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_idle_0" .. math.random(1, 2)))

		self:UpdateNextIdle()
	end

	/*if !self.HeldEnt or CLIENT then return end
	if !IsValid(self.HeldEnt) then
		if IsValid(self.EntWeld) then self.EntWeld:Remove() end
		self.Owner._HoldingEnt, self.HeldEnt.held, self.HeldEnt, self.EntWeld, self.EntAngles, self.OwnerAngles = nil
		self:Speed()
		return
	elseif !IsValid(self.EntWeld) then
		self.Owner._HoldingEnt, self.HeldEnt.held, self.HeldEnt, self.EntWeld, self.EntAngles, self.OwnerAngles = nil
		self:Speed()
		return
	end
	if !self.HeldEnt:IsInWorld() then
		self.HeldEnt:SetPos(self.Owner:GetShootPos())
		self:DropObject()
		return
	end
	if self.NoPos then return end
	local pos = self.Owner:GetShootPos()
	local ang = self.Owner:GetAimVector()
	self.HeldEnt:SetPos(pos+(ang*60))
	self.HeldEnt:SetAngles(Angle(self.EntAngles.p,(self.Owner:GetAngles().y-self.OwnerAngles.y)+self.EntAngles.y,self.EntAngles.r))*/
end

function SWEP:speed(down)
	/*if down then
		self.Owner:SetRunSpeed( GM.Config["Incapacitated Speed"]);
		self.Owner:SetWalkSpeed(GM.Config["Incapacitated Speed"]);
		self.Owner:SetJumpPower( 0 )
	else
		self.Owner:SetRunSpeed( GM.Config["Run Speed"] );
		self.Owner:SetWalkSpeed(GM.Config["Walk Speed"]);
		self.Owner:SetJumpPower( GM.Config["Jump Power"] )
	end*/
end

function SWEP:Holster()
	if CLIENT then return true end

	self:dropObject()
	self.Primary.NextSwitch = CurTime() + 1

	return true
end

function SWEP:pickUp(ent,trace)
	/*if CLIENT or ent.held then return end
	if (constraint.HasConstraints(ent) or ent:IsVehicle()) then
		return false
	end
	local pent = ent:GetPhysicsObject( )
	if !IsValid(pent) then return end
	if pent:GetMass() > 60 or not pent:IsMoveable() then
		return
	end
	if ent:GetClass() == "prop_ragdoll" then
--[[				cider.player.notify(self.Owner,"Temporarily disabled due to bugs. ):",1)
		self.EntWeld = constraint.Weld(ent,self.Owner,trace.PhysicsBone,0,0,1)
		if not IsValid(self.EntWeld) then
			return false
		end
		ent:DeleteOnRemove(self.EntWeld)
		self.NoPos = true
	--	print(self.EntWeld)
	--]]	return false
	else
		ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
		local EntWeld = {}
		EntWeld.ent = ent
		function EntWeld:IsValid() return IsValid(self.ent) end
		function EntWeld:Remove()
			if IsValid(self.ent) then self.ent:SetCollisionGroup( COLLISION_GROUP_NONE ) end
		end
		self.NoPos = false
		self.EntWeld = EntWeld
	end
	--print(self.EntWeld)
--	print("k, pickin up")
	self.Owner._HoldingEnt = true
	self.HeldEnt = ent
	self.HeldEnt = ent
	self.HeldEnt.held = true
	self.EntAngles = ent:GetAngles()
	self.OwnerAngles = self.Owner:GetAngles()
	self:Speed(true)*/
end

function SWEP:dropObject(acceleration)
	/*if CLIENT then return true end
	--[[if not acceleration then
		print("D:")
	end]]
	acceleration = acceleration or 0.1
	if !IsValid(self.HeldEnt) then return true end
	if IsValid(self.EntWeld) then self.EntWeld:Remove() end
	local pent = self.HeldEnt:GetPhysicsObject( )
	if pent:IsValid() then
		pent:ApplyForceCenter(self.Owner:GetAimVector() * pent:GetMass() * acceleration)
		--print(pent:GetMass() , acceleration,pent:GetMass() * acceleration)
	end
	self.Owner._HoldingEnt, self.HeldEnt.held, self.HeldEnt, self.EntWeld, self.EntAngles, self.OwnerAngles = nil
	self:Speed()*/
end

function SWEP:OnRemove( )
	if CLIENT then return true end

	self:dropObject()

	return true
end