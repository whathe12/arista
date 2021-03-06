include("sh_init.lua")

-- Settup function
function PLUGIN:LoadData()
	self.group = arista.team.getGroup("Officials")

	self.mayor = arista.team.getByMember("mayor")
	if not self.mayor then error("OFFICALS: No mayor team found!") end

	self.vicemayor = arista.team.getByMember("vicemayor")

	self.commander = arista.team.getByMember("commander")
	if not self.commander then error("OFFICALS: No commander team found!") end

	self.officer = arista.team.getByMember("officer")
	if not self.officer then error("OFFICALS: No police officer team found!") end
end

--Check if they're the right group/gang
function PLUGIN:IsAuthorised(player, ingang)
	if not self.mayor then self:LoadData() end

	if self.group == arista.team.getGroupByTeam(player:Team()) then
		if ingang then
			return arista.team.getGang(player:Team()) == GANG_POLICE
		end

		return true
	end

	return false
end

-- Say a message as a request.
function PLUGIN:SayRequest(ply, text)
	if not self.mayor then self:LoadData() end

	local filter = {ply}
	for k, v in ipairs(player.GetAll()) do
		if self:IsAuthorised(v, true) then
			filter[#filter+1] = v
		end
	end

	arista.chatbox.add(filter, ply, "request", text)
end

-- Say a message as a broadcast.
function PLUGIN:SayBroadcast(ply, text)
	arista.chatbox.add(nil, ply, "broadcast", text)
end

-- Called when a player's radio recipients should be adjusted.
function PLUGIN:PlayerAdjustRadioRecipients(ply, text, recipients)
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply) then
		return
	end

	for k in pairs(recipients) do
		recipients[k] = nil
	end

	for _,id in pairs(self.group.teams) do
		table.Add(recipients, team.GetPlayers(id))
	end
end

function PLUGIN:PlayerDestroyedContraband(ply, ent)
	--[[local data = GM.Config["Contraband"][ent:GetClass()]
	if (not data or not self:IsAuthorised(ply)) then
		return
	end
	ply:sayRadio("I have destroyed a " .. data.name .. ".")]]
	-- todo: contra
end

-- Called when a player dies.
function PLUGIN:PlayerDeath(ply, inflictor, killer)
	if not self.mayor then self:LoadData() end

	local team = arista.team.get(ply:Team())
	if not team then return end

	if killer:IsPlayer() and self:IsAuthorised(killer) and ply ~= killer then
		killer:sayRadio("I have killed " .. ply:rpName() .. ".")

		return
	elseif team.mayor and not ply:getAristaVar("changeTeam") then
		for _, pl in ipairs(player.GetAll()) do
			pl:unWarrant() -- Loop through all players and dewarrant them.
		end

		-- joinTeam vice-mayor to mayor

		self.Lockdown = false -- Disable the lockdown
		SetGlobalBool("lockdown", false)

		ply:demote() -- Drop dem to da bttom
	end
end

-- Called when a player attempts to arrest another player.
function PLUGIN:PlayerCanArrest(ply, target)
	if ply:IsAdmin() then return end -- Light abuse
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply, true) then
		ply:notify("AL_OFFICALS_ARREST_NOACCESS")

		return false
	elseif self:IsAuthorised(target) then
		return false
	end
end

-- Called when a player attempts to stun a player.
function PLUGIN:PlayerCanStun(ply, target)
	if ply:IsAdmin() then return end -- Light abuse
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply, true) then
		ply:notify("AL_OFFICALS_STUN_NOACCESS")

		return false
	elseif self:IsAuthorised(target) then
		return false
	end
end

-- Called when a player attempts to knock out a player.
function PLUGIN:PlayerCanKnockOut(ply, target)
	if ply:IsAdmin() then return end -- Light abuse
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply, true) then
		ply:notify("AL_OFFICALS_KNOCKOUT_NOACCESS")

		return false
	elseif self:IsAuthorised(target) then
		return false
	end
end

-- Called when a player attempts to wake up a player.
function PLUGIN:PlayerCanWakeUp(ply, target)
	if ply:IsAdmin() then return end -- Light abuse
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply, true) then
		ply:notify("AL_OFFICALS_WAKEUP_NOACCESS")

		return false
	end
end

-- Called when a player attempts to unarrest another player.
function PLUGIN:PlayerCanUnarrest(ply, target)
	if ply:IsAdmin() then return end -- Light abuse
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply, true) then
		ply:notify("AL_OFFICALS_UNARREST_NOACCESS")

		return false
	end

	return true
end

local function tmr(ply)
	if IsValid(ply) then
		ply:GodDisable()
	end
end

-- Called when a player spawns.
function PLUGIN:PostPlayerSpawn(ply, light, teamchange)
	if not self.mayor then self:LoadData() end

	if self:IsAuthorised(ply, true) then
		ply:setAristaVar("scaleDamage", 0.5) -- Free kevlar
	end

	local team = arista.team.get(ply:Team())
	if not team then return end

	-- Check if the player is the Mayor.
	if not team.mayor then
		timer.Destroy("Spawn Immunity: " .. ply:SteamID64())
		ply:setAristaVar("spawnImmunityTime", 0)

		return
	end

	if light then
		return -- Spawn immunity is only for the freshly spawned
	end

	ply:GodEnable()

	local duration = arista.config.plugins.officalsMayorGod or 60 -- Players will be immune for 60 seconds
	ply:networkAristaVar("spawnImmunityTime", CurTime() + duration) -- Tell the client they're immune

	timer.Create("Spawn Immunity: " .. ply:SteamID64(), duration, 1, function() tmr(ply) end) -- Make a timer to stop the immunity later
end

-- Called when a player attempts to warrant another player.
function PLUGIN:PlayerCanWarrant(ply, target, class)
	if not self.mayor then self:LoadData() end

	local words = class
	if class == "search" then
		words = "a search"
	elseif class == "arrest" then
		words = "an arrest"
	end

	if (self:IsAuthorised(target) and class ~= "search") then -- You can't arrest police, so don't let them try.
		ply:Notify("You cannot arrest city officials!", 1)
		return false
	end

	local team = arista.team.get(ply:Team())
	if not team then return end

	if team.mayor or team.vicemayor then -- The mayor can always warrant.
		return true
	end

	-- if there is a vice-mayor ask them first rather than bothering the mayor

	if self.vicemayor then
		if team.NumPlayers(self.vicemayor.index) > 0 then -- If there's a vice-mayor and we're not him, we gotta beg.
			if self:IsAuthorised(ply) then
				ply:sayRadio(self.vicemayor.name .. ", could you warrant " .. target:rpName() .. " for " .. words .. " please?")
			else
				self:SayRequest(ply, self.vicemayor.name .. ", I suggest you warrant " .. target:rpName() .. " for " .. words .. ".")
			end

			return false -- Only the vice mayor can fufil our wish.
		end
	end

	if team.NumPlayers(self.mayor.index) > 0 then -- If there's a mayor and we're not him, we gotta beg.
		if self:IsAuthorised(ply) then
			ply:sayRadio(self.mayor.name .. ", could you warrant " .. target:rpName() .. " for " .. words .. " please?")
		else
			self:SayRequest(ply, self.mayor.name .. ", I suggest you warrant " .. target:rpName() .. " for " .. words .. ".")
		end

		return false -- Only the mayor can fufil our wish.
	end

	if team.commander then -- If there's no mayor then the police commander handles warrants.
		return true
	end

	if team.NumPlayers(self.commander.index) > 0 then -- If there's no mayor and we're not the commander, then we gotta pester the commander about it.
		if (self:IsAuthorised(ply)) then
			ply:sayRadio(self.commander.name .. ", could you warrant " .. target:rpName() .. " for " .. words .. " please?")
		else
			self:SayRequest(ply, self.commander.name .. "Commander, I suggest you warrant " .. target:rpName() .. " for " .. words .. ".")
		end

		return false -- We still can't do it ourself.
	end

	if team.officer then -- The cat is away so the mice do play.
		return true
	end

	if team.NumPlayers(self.officer.index) > 0 then -- I guess there might be police officers for us to pester?
		if self:IsAuthorised(ply) then
			ply:sayRadio("Could an officer warrant " .. target:rpName() .. " for " .. words .. " please?")
		else
			self:SayRequest(ply, "I suggest that an officer warrants " .. target:rpName() .. " for " .. words .. ".")
		end

		return false -- Whodathunk it? Still impotent.
	end

	ply:notify("AL_OFFICALS_CANNOT_REQUEST")
	return false
end

function PLUGIN:PlayerWarrantExpired(ply, class)
	if not IsValid(ply) then return end -- You'd be surprised
	if not self.mayor then self:LoadData() end

	if team.NumPlayers(self.mayor.index) > 0 then
				team.GetPlayers(self.mayor.index)[1]:sayRadio("The " .. class .. " warrant for " .. ply:rpName() .. " has expired.")
	elseif team.NumPlayers(self.vicemayor.index) > 0 then
		team.GetPlayers(self.vicemayor.index)[1]:sayRadio("The " .. class .. " warrant for " .. ply:rpName() .. " has expired.")
	elseif team.NumPlayers(self.commander.index) > 0 then
		team.GetPlayers(self.commander.index)[1]:sayRadio("The " .. class .. " warrant for " .. ply:rpName() .. " has expired.")
	elseif team.NumPlayers(self.officer.index) > 0 then
			team.GetPlayers(self.officer.index)[1]:sayRadio("The " .. class .. " warrant for " .. ply:rpName() .. " has expired.")
	end
end

-- Called when a player warrants another player.
function PLUGIN:PlayerWarrant(ply, target, class)
	if not self.mayor then self:LoadData() end

	if not self:IsAuthorised(ply) then
		return
	elseif class == "search" then
		ply:sayRadio("I have warranted " .. target:rpName() .. " for a search.")
	elseif class == "arrest" then
		ply:sayRadio("I have warranted " .. target:rpName() .. " for an arrest.")
	end
end

-- Called when a player unwarrants another player.
function PLUGIN:PlayerUnwarrant(ply, target)
	if not self.mayor then self:LoadData() end

	if self:IsAuthorised(ply) then
		ply:sayRadio("I have unwarranted " .. target:rpName() .. ".")
	end
end

--[[
local doors = {
	{"prop_dynamic","models/props_lab/elevatordoor.mdl",Angle(000,000,000),Vector(-6866.8232421875,-9445.345703125,73.03125),"Lift Access"},
	{"prop_dynamic","models/props_lab/elevatordoor.mdl",Angle(000,000,000),Vector(-6768.6274414063,-9500.35546875,841.03125),"Cells + Commander's Office"},
	{"prop_dynamic","models/props_lab/elevatordoor.mdl",Angle(000,000,000),Vector(-7552.4541015625,-9159.3251953125,841.03125),"Cells"},
	{"prop_dynamic","models/props_lab/elevatordoor.mdl",Angle(000,090,000),Vector(-6919.013671875,-9440.412109375,1481.03125),"Quartermaster's Office"},
	{"prop_dynamic","models/props_lab/elevatordoor.mdl",Angle(000,090,000),Vector(-6829.3862304688,-9431.8671875,2617.03125),"Mayor's Suite"},
	{"prop_dynamic","models/props_lab/elevatordoor.mdl",Angle(000,000,000),Vector(-6965.9765625,-9148.5576171875,2489.03125),"Mayor's Office"},
}
function PLUGIN:InitPostEntity()
	if (game.GetMap():lower() ~= "rp_evocity_v2d") then return end
	for _,tab in ipairs(doors) do
		ent = ents.Create(tab[1])
		if (not IsValid(ent)) then
			ErrorNoHalt("couldn't create a  "..tab[1].."!")
		else
			ent:SetAngles(tab[3])
			ent:SetModel(tab[2])
			ent:SetPos(tab[4])
			if (tab[1] == "prop_dynamic") then
				ent:SetKeyValue("solid",6)
				ent:SetKeyValue("MinAnimTime",	1)
				ent:SetKeyValue("MaxAnimTime",	5)
			else
				ent:SetKeyValue("hardware",		1)
				ent:SetKeyValue("distance",		90)
				ent:SetKeyValue("speed",		100)
				ent:SetKeyValue("returndelay",	-1)
				ent:SetKeyValue("spawnflags",	8192)
				ent:SetKeyValue("forceclosed",	0)
			end
			ent:Spawn()
			ent:Activate()
			ent.PhysgunDisabled = true
			ent.m_tblToolsAllowed = {}
			ent._DoorState = "closed"
			ent._Autoclose = 5
			arista.entity.makeOwnable(ent)
			arista.entity.setOwnerGang(ent,1,1)
			arista.entity.setName(ent,tab[5])
			ent:Lock()
			ent:SetNWString("Name","GHQ")
		end
	end
end]]

function PLUGIN:PlayerKnockedOut(victim, attacker)
	if not self.mayor then self:LoadData() end

	if IsValid(attacker) and self:IsAuthorised(attacker) then
		attacker:sayRadio("I have knocked out " .. victim:rpName() .. ".")
	end
end

function PLUGIN:PlayerWokenUp(victim, attacker)
	if not self.mayor then self:LoadData() end

	if IsValid(attacker) and self:IsAuthorised(attacker) then
		attacker:sayRadio("I have woken up " .. victim:rpName() .. ".")
	end
end

-- Called when a player arrests another player.
function PLUGIN:PlayerArrest(ply, target)
	if not self.mayor then self:LoadData() end

	if self:IsAuthorised(ply) then
		ply:sayRadio("I have arrested " .. target:rpName() .. ".")
	end
end

-- Called when a player unarrests another player.
function PLUGIN:PlayerUnarrest(ply, target)
	if not self.mayor then self:LoadData() end

	if self:IsAuthorised(ply) then
		ply:sayRadio("I have unarrested " .. target:rpName() .. ".")
	end
end

-- Called when a player attempts to unwarrant another player.
function PLUGIN:PlayerCanUnwarrant(ply, target)
	if not self.mayor then self:LoadData() end

	if ply:Team() == self.mayor.index or (self.vicemayor and ply:Team() == self.vicemayor.index) or ply:Team() == self.commander.index then
		return true
	end
end

-- Called when a player attempts to change the city laws
function PLUGIN:PlayerCanChangeLaws(ply)
	if not self.mayor then self:LoadData() end

	if ply:Team() == self.mayor.index then
		return true
	end
end

-- Called when a player attempts to demote another.
function PLUGIN:PlayerCanDemote(ply,target)
	if not self.mayor then self:LoadData() end

	if (ply:Team() == self.mayor.index or (self.vicemayor and ply:Team() == self.vicemayor.index)) and self:IsAuthorised(target) then
		return true
	end
end

-- A command to broadcast to all players.
arista.command.add("broadcast", "", 1, function(ply, args)
	local self = GAMEMODE:GetPlugin("officals")
	if not self.mayor then self:LoadData() end

	local team = ply:Team()
	if team ~= self.mayor.index and (not self.vicemayor or team ~= self.vicemayor.index) and team ~= self.commander.index then
		return false, "You cannot make broadcasts!"
	end

	local words = table.concat(args, " "):Trim()
	if words == "" then
		return false, "You did not specify enough text!"
	end

	if team == self.commander.index then
		words = "(POLICE) " .. words
	end

	arista.chatbox.add(nil, ply, "broadcast", words)
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to request assistance from the Police and Mayor.
arista.command.add("request", "", 1, function(ply, args)
	local self = GAMEMODE:GetPlugin("officals")

	local words = table.concat(args, " "):Trim()

	if words == "" then
		return false, "You did not specify enough text!"
	end

	if self:IsAuthorised(ply) then
		ply:sayRadio(words)
	else
		self:SayRequest(ply, words)
	end
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to initiate lockdown.
arista.command.add("lockdown", "", 0, function(ply)
	if (self.Lockdown) then
		return false, "There is already a lockdown active!"
	elseif (ply:Team() == TEAM_MAYOR) then
		self:SayBroadcast(ply, "A lockdown is in progress. Please return to your homes.")
		self.Lockdown = true
		SetGlobalBool("lockdown", true)
		return true
	elseif (team.NumPlayers(TEAM_MAYOR) > 0) then -- If there's a mayor and we're not him, we gotta beg.
		if (self:IsAuthorised(ply)) then
			ply:sayRadio("Mayor, could you initiate a lockdown please?")
		else
			self:SayRequest(ply,"Mayor, I suggest you initiate a lockdown.")
		end
		return false -- Only the mayor can fufil our wish.
	end
	return false, "Only the Mayor can initiate a lockdown!"
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to cancel lockdown.
arista.command.add("unlockdown", "b", 0, function(ply)
	if (not self.Lockdown) then
		return false, "There isn't an active lockdown!"
	elseif (ply:Team() == TEAM_MAYOR) then
		self:SayBroadcast(ply, "The lockdown has been cancelled.")
		self.Lockdown = false
		SetGlobalBool("lockdown", false)
		return true
	elseif (team.NumPlayers(TEAM_MAYOR) > 0) then -- If there's a mayor and we're not him, we gotta beg.
		if (self:IsAuthorised(ply)) then
			ply:sayRadio("Mayor, could you end the lockdown please?")
		else
			self:SayRequest(ply,"Mayor, I suggest you end the lockdown.")
		end
		return false -- Only the mayor can fufil our wish.
	end
	return false, "Critical error 2194" -- Lockdown without a mayor? This is not possible.
end, "AL_COMMAND_CAT_COMMANDS")
