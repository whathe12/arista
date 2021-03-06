-- Load specific command types to keep this file cleaner.
arista.file.loadDir("commands/", "Command Library", "Command Libraries")

-- An important. (Very important, do not remove.)
arista.command.add("fuck", "", 0, function(p)
	p:notify("AL_FUCK")
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to change your job title
arista.command.add("job", "", 0, function(ply, arguments)
	local words = table.concat(arguments, " ")
	words = words:sub(1, 64):Trim()

	if not words or words == "" or words == "none" or words == "default" then
		words = team.GetName(ply:Team())
	end

	ply:setAristaVar("job", words)

	ply:notify("AL_YOU_CHANGE_JOB", words)
	arista.logs.event(arista.logs.E.LOG, arista.logs.E.COMMAND, ply:Name(), "(", ply:SteamID(), ") changed their job name to '", words, "'.")
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to change your clan.
arista.command.add("clan", "", 0, function(ply, arguments)
	local words = table.concat(arguments, " ")
	words = words:sub(1, 64):Trim()

	if not words or words == "quit" or words == "none" then
		words = ""
	end

	ply:setAristaVar("clan", words)

	if words == "" then
		ply:notify("AL_YOU_REMOVE_CLAN")
	else
		ply:notify("AL_YOU_CHANGE_CLAN", words)
	end
	arista.logs.event(arista.logs.E.LOG, arista.logs.E.COMMAND, ply:Name(), "(", ply:SteamID(), ") changed their clan to '", words, "'.")
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to change your clan.
arista.command.add("name", "", 0, function(ply, arguments)
	local words = table.concat(arguments, " ")
	words = words:sub(1, 64):Trim()

	if not words or words == "random" or words == "default" then
		ply:generateDefaultRPName()
	return end

	ply:setAristaVar("rpname", words)

	arista.logs.event(arista.logs.E.LOG, arista.logs.E.COMMAND, ply:Name(), "(", ply:SteamID(), ") changed their name to '", words, "'.")
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to change your clan.
arista.command.add("details", "", 0, function(ply, arguments)
	local words = table.concat(arguments, " ")
	words = words:sub(1, 64):Trim()

	if words == "" or words:lower() == "none" then
		ply:setAristaVar("details", "")

		-- Print a message to the player.
		ply:notify("AL_YOU_REMOVE_DETAILS")
	else
		ply:setAristaVar("details", words)

		-- Print a message to the player.
		ply:notify("AL_YOU_CHANGE_DETAILS", words)
	end

	arista.logs.event(arista.logs.E.LOG, arista.logs.E.COMMAND, ply:Name(), "(", ply:SteamID(), ") changed their details to '", words, "'.")
end, "AL_COMMAND_CAT_COMMANDS")

-- A command to give a player some money.
arista.command.add("givemoney", "", 1, function(ply, amt)
	local victim = ply:GetEyeTraceNoCursor().Entity
	if not (IsValid(victim) and victim:IsPlayer()) then
		return false, "AL_INVALID_TARGET"
	end

	amt = tonumber(amt)
	if not amt or amt < 1 then
		return false, "AL_INVALID_AMOUNT"
	end

	amt = math.floor(amt)
	if not ply:canAfford(amt) then
		return false, "AL_YOU_NOT_ENOUGHMONEY"
	end

	ply:giveMoney(-amt)
	victim:giveMoney(amt)

	ply:emote("hands <N> a wad of money.", victim)

	ply:notify("AL_PLAYER_YOU_GAVE", victim:Name(), amt)
	victim:notify("AL_PLAYER_GAVE_YOU", ply:Name(), amt)
end, "Commands", "<amount>", "Give some money to the player you're looking at.", true);

-- A command to drop money.
local moneyDist = 255^2
arista.command.add("dropmoney", "", 1, function(ply, amt)
	-- Prevent fucktards spamming the dropmoney command.
	ply._nextMoneyDrop = ply._nextMoneyDrop or 0

	if ply._nextMoneyDrop > CurTime() then
		return false, "AL_CANNOT_DROPMONEY_FAST", ply._nextMoneyDrop - CurTime()
	end

	local pos = ply:GetEyeTraceNoCursor().HitPos
	if ply:GetPos():DistToSqr(pos) > moneyDist then
		pos = ply:GetShootPos() + ply:GetAimVector() * 255
	end

	amt = tonumber(amt)
	if not amt or amt < 1 then
		return false, "AL_INVALID_AMOUNT"
	end

	amt = math.floor(amt)

	if not ply:canAfford(amt) then
		return false, "AL_YOU_NOT_ENOUGHMONEY"
	elseif amt < 50 then -- Fucking spammers again.
		return false, "AL_YOU_NOT_DROPENOUGH", 50
	end

	ply._nextMoneyDrop = CurTime() + 10
	ply:giveMoney(-amt)

	arista.item.items["money"]:make(pos, amt):CPPISetOwner(ply)
end, "AL_COMMAND_CAT_COMMANDS", true)

-- A command to demote a player.
arista.command.add("demote", "", 2, function(ply, target, ...)
	local victim = arista.player.get(target)
	if not victim then
		return false, "AL_INVALID_TARGET"
	end

	local reason = table.concat({...}, " "):sub(1, 65):Trim()
	if not reason or reason == "" or (reason:len() < 5 and not ply:IsSuperAdmin()) then
		return false, "You must specify a reason!"
	end

	if gamemode.Call("PlayerCanDemote", ply, victim) == false then
		return false
	end

	local tid = victim:Team()
	victim:demote()

	arista.player.notifyAll("AL_PLAYER_DEMOTED", nil, ply:Name(), victim:Name(), team.GetName(tid), reason)
end, "AL_COMMAND_CAT_COMMANDS", true)

do --isolate vars
	local function conditional(ply, pos)
		return ply:IsValid() and ply:GetPos() == pos
	end

	local function success(ply, _, class)
		if not ply:IsValid() then return end
		ply._equipping = false

		local s, f = arista.inventory.update(ply, class, 1)
		if not s then
			ply:emote(arista.config.timers["Equip Message"]["Abort"])

			if f and f ~= "" then
				ply:notify(f)
			end

			return
		end

		ply:StripWeapon(class)
		ply:SelectWeapon("hands")

		local weptype = arista.item.items[class].weaponType
		if weptype then
			ply:emote(arista.config.timers["equipmessage"]["Plugh"]:format(weptype))

			local counts = ply:getAristaVar("gunCounts")
				counts[weptype] = counts[weptype] - 1
			ply:setAristaVar("gunCounts", counts)
		end
	end

	local function failure(ply)
		if not ply:IsValid() then return end

		ply:emote(arista.config.timers["equipmessage"]["Abort"])
		ply._equipping = false
	end

	-- A command to holster your current weapon.
	arista.command.add("holster", "", 0, function(ply)
		local weapon = ply:GetActiveWeapon()

		-- Check if the weapon is a valid entity.
		if not (IsValid(weapon) and arista.item.items[weapon:GetClass()]) then
			return false, "AL_INVALID_WEAPON"
		end

		local nextHolster = ply:getAristaVar("nextHolsterWeapon")

		-- Check if they can holster another weapon yet.
		if not ply:IsAdmin() and nextHolster and nextHolster > CurTime() then
			return false, "AL_CANNOT_HOLSTER", math.ceil(nextHolster - CurTime())
		else
			ply:setAristaVar("nextHolsterWeapon", CurTime() + 2)
		end

		local class = weapon:GetClass()
		if gamemode.Call("PlayerCanHolster", ply, class) == false then
			return false
		end

		ply._equipping = ply:GetPos()
		local delay = arista.config.timers["equiptime"][arista.item.items[class].weaponType or -1] or 0
		if not (delay and delay > 0) then
			success(ply, nil, class)
		return true end

		arista.timer.conditional(ply:UniqueID() .. " holster", delay, conditional, success, failure, ply, ply:GetPos(), class)
		ply:emote(arista.config.timers["equipmessage"]["Start"])
	end, "AL_COMMAND_CAT_COMMANDS")
end

--[[

-- A command to drop your current weapon.
cider.command.add("drop", "b", 0, function()
	return false, "Use /holster instead.";
end, "Commands", nil, "Put in for DarkRP players. Do not use.");

-- A command to warrant a player.
cider.command.add("warrant", "b", 1, function(ply, arguments)
	local target = player.Get(arguments[1])

	-- Get the class of the warrant.
	local class = string.lower(arguments[2] or "");

	-- Check if a second argument was specified.
	if (class == "search" or class == "arrest") then
		if (target) then
			if ( target:Alive() ) then
				if (target._Warranted ~= class) then
					if (!target.cider._Arrested) then
						if (CurTime() > target._CannotBeWarranted) then
							if ( hook.Call("PlayerCanWarrant",GAMEMODE, ply, target, class) ) then
								hook.Call("PlayerWarrant",GAMEMODE, ply, target, class);

								-- Warrant the player.
								target:Warrant(class);
							end
						else
							return false, target:Name().." has only just spawned!";
						end
					else
						return false, target:Name().." is already arrested!";
					end
				else
					if (class == "search") then
						return false, target:Name().." is already warranted for a search!";
					elseif (class == "arrest") then
						return false, target:Name().." is already warranted for an arrest!";
					end
				end
			else
				return false, target:Name().." is dead and cannot be warranted!";
			end
		else
			return false, arguments[1].." is not a valid player!"
		end
	else
		return false, "Invalid warrant type. Use 'search' or 'arrest'"
	end
end, "Commands", "<player> <search|arrest>", "Warrant a player.");

-- A command to unwarrant a player.
cider.command.add("unwarrant", "b", 1, function(ply, arguments)
	local target = player.Get(arguments[1])

	-- Check to see if we got a valid target.
	if (target) then
		if (target._Warranted) then
			if ( hook.Call("PlayerCanUnwarrant",GAMEMODE, ply, target) ) then
				hook.Call("PlayerUnwarrant",GAMEMODE, ply, target);

				-- Warrant the player.
				target:UnWarrant();
			end
		else
			return false, target:Name().." does not have a warrant!"
		end
	else
		return false, arguments[1].." is not a valid player!"
	end
end, "Commands", "<player>", "Unwarrant a player.");

do -- Reduce the upvalues poluting the area.
	local function conditional(ply, pos)
		return IsValid(ply) and ply:GetPos() == pos;
	end

	local function success(ply)
		ply:KnockOut();
		GM:Log(EVENT_EVENT, "%s went to sleep.", ply:Name());
		ply._Sleeping = true;
		ply:Emote("slumps to the floor, asleep.");
		ply:SetCSVar(CLASS_LONG, "_GoToSleepTime");
	end

	local function failure(ply)
		ply:SetCSVar(CLASS_LONG, "_GoToSleepTime");
	end
	-- A command to sleep or wake up.
	cider.command.add("sleep", "b", 0, function(ply)
		if (ply._Sleeping and ply:KnockedOut()) then
			return ply:WakeUp();
		end
		timer.Conditional(ply:UniqueID().." sleeping timer", GM.Config["Sleep Waiting Time"], conditional, success, failure, ply, ply:GetPos());
	end, "Commands", nil, "Go to sleep or wake up from sleeping.");
end

cider.command.add("trip", "b", 0, function(ply,arguments)
	if ply:GetVelocity() == Vector(0,0,0) then
		return false,"You must be moving to trip!"
	elseif ply:InVehicle() then
		return false,"There is nothing to trip on in here!";
	end
	ply:KnockOut(5)
	ply._Tripped = true
	cider.chatBox.addInRadius(ply, "me", "trips and falls heavily to the ground.", ply:GetPos(), GM.Config["Talk Radius"]);
	GM:Log(EVENT_EVENT,"%s fell over.",ply:GetName())
end, "Commands", "", "Fall over while walking. (bind key \"say /trip\")");

cider.command.add("fallover", "b", 0, function(ply,arguments)
	if not (ply:KnockedOut() or ply:InVehicle()) then
		ply:KnockOut(5)
		ply._Tripped = true
		cider.chatBox.addInRadius(ply, "me", "slumps to the ground.", ply:GetPos(), GM.Config["Talk Radius"]);
		GM:Log(EVENT_EVENT,"%s fell over.",ply:GetName())
	end
end, "Commands", "", "Fall over.");

-- Commit mutiny.
cider.command.add("mutiny","b",1,function(ply,arguments)
	local target = player.Get( arguments[1] ) or nil
	if not (ValidEntity(target) and target:IsPlayer()) then
		return false, arguments[1].." is not a valid player!"
	end
	local pteam,tteam = ply:Team(),target:Team()
	if 	cider.team.getGroupByTeam(pteam)	~=	cider.team.getGroupByTeam	(tteam)		or
		cider.team.getGang		 (pteam) 	~=	cider.team.getGang			(tteam)		or
		cider.team.getGang		 (tteam)	==	nil										or
		cider.team.getGroupLevel (pteam)	>=	cider.team.getGroupLevel	(tteam)		or
		not										cider.team.hasAccessGroup	(tteam,"D")	then
			return false,"You cannot mutiny against this person"
	end
	target._Depositions = target._Depositions or {}
	if target._Depositions [ply:UniqueID()] then
		return false,"You have already tried to mutiny against your leader!"
	else
		target._Depositions[ply:UniqueID()] = ply
	end
	for ID,ply in pairs(target._Depositions) do
		if ValidEntity(ply) then
			local pteam = ply:Team()
			if 	cider.team.getGroupByTeam(pteam)	~=	cider.team.getGroupByTeam(tteam)	or
				cider.team.getGang		 (pteam) 	~=	cider.team.getGang		 (tteam)	or
				cider.team.getGroupLevel (pteam)	>=	cider.team.getGroupLevel (tteam)	then
					target._Depositions	 [ID]		 =	nil
			end
		else
			target._Depositions[ID] = nil
		end
	end
	local count	= table.Count(target._Depositions)
	local num	=  math.floor( table.Count( cider.team.getGangMembers( cider.team.getGroupByTeam(tteam), cider.team.getGang(tteam) ) ) * GM.Config["Mutiny Percentage"])
	if  num < GM.Config["Minimum to mutiny"] then
		num = GM.Config["Minimum to mutiny"]
	end
	if count < num then
		ply:Notify("Not enough of the gang agrees with you yet to do anything, but they acknowledge your thoughts...")
		GM:Log(EVENT_EVENT,"%s voted to mutiny against %s. %i/%i",ply:Name(),target:Name(),count,num)
		return
	end
	target:Notify("Your gang has overthrown you!",1)
	target:Demote()
	player.NotifyAll("%s was overthrown as leader.",nil,target:Name())
end, "Commands","<player>","Try to start a mutiny against your leader")
]]
