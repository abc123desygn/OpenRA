--[[
   Copyright (c) The OpenRA Developers and Contributors
   This file is part of OpenRA, which is free software. It is made
   available to you under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of
   the License, or (at your option) any later version. For more
   information, see COPYING.
]]

AtreidesReinforcements =
{
	easy =
	{
		{ "light_inf", "light_inf" }
	},

	normal =
	{
		{ "light_inf", "light_inf" },
		{ "light_inf", "light_inf", "light_inf" },
		{ "light_inf", "trike" }
	},

	hard =
	{
		{ "light_inf", "light_inf" },
		{ "trike", "trike" },
		{ "light_inf", "light_inf", "light_inf" },
		{ "light_inf", "trike" },
		{ "trike", "trike" }
	}
}

AtreidesEntryWaypoints = { AtreidesWaypoint1.Location, AtreidesWaypoint2.Location, AtreidesWaypoint3.Location, AtreidesWaypoint4.Location }
AtreidesAttackDelay = DateTime.Seconds(30)

AtreidesAttackWaves =
{
	easy = 1,
	normal = 5,
	hard = 12
}

ToHarvest =
{
	easy = 2500,
	normal = 3000,
	hard = 3500
}

HarkonnenReinforcements = { "light_inf", "light_inf", "light_inf", "trike" }
HarkonnenEntryPath = { HarkonnenWaypoint.Location, HarkonnenRally.Location }

Messages =
{
	"Build a concrete foundation before placing your buildings.",
	"Build a Wind Trap for power.",
	"Build a Refinery to collect Spice.",
	"Build a Silo to store additional Spice."
}

Tick = function()
	if AtreidesArrived and atreides.HasNoRequiredUnits() then
		player.MarkCompletedObjective(KillAtreides)
	end

	if player.Resources > SpiceToHarvest - 1 then
		player.MarkCompletedObjective(GatherSpice)
	end

	-- player has no Wind Trap
	if (player.PowerProvided <= 20 or player.PowerState ~= "Normal") and DateTime.GameTime % DateTime.Seconds(32) == 0 then
		HasPower = false
		Media.DisplayMessage(Messages[2], "Mentat")
	else
		HasPower = true
	end

	-- player has no Refinery and no Silos
	if HasPower and player.ResourceCapacity == 0 and DateTime.GameTime % DateTime.Seconds(32) == 0 then
		Media.DisplayMessage(Messages[3], "Mentat")
	end

	if HasPower and player.Resources > player.ResourceCapacity * 0.8 and DateTime.GameTime % DateTime.Seconds(32) == 0 then
		Media.DisplayMessage(Messages[4], "Mentat")
	end

	UserInterface.SetMissionText("Harvested resources: " .. player.Resources .. "/" .. SpiceToHarvest, player.Color)
end

WorldLoaded = function()
	player = Player.GetPlayer("Harkonnen")
	atreides = Player.GetPlayer("Atreides")

	SpiceToHarvest = ToHarvest[Difficulty]

	InitObjectives(player)
	KillHarkonnen = atreides.AddPrimaryObjective("Kill all Harkonnen units.")
	GatherSpice = player.AddPrimaryObjective("Harvest " .. tostring(SpiceToHarvest) .. " Solaris worth of Spice.")
	KillAtreides = player.AddSecondaryObjective("Eliminate all Atreides units and reinforcements\nin the area.")

	local checkResourceCapacity = function()
		Trigger.AfterDelay(0, function()
			if player.ResourceCapacity < SpiceToHarvest then
				Media.DisplayMessage("We don't have enough silo space to store the required amount of Spice!", "Mentat")
				Trigger.AfterDelay(DateTime.Seconds(3), function()
					harkonnen.MarkCompletedObjective(KillAtreides)
				end)

				return true
			end
		end)
	end

	Trigger.OnRemovedFromWorld(HarkonnenConyard, function()

		-- Mission already failed, no need to check the other conditions as well
		if checkResourceCapacity() then
			return
		end

		local refs = Utils.Where(Map.ActorsInWorld, function(actor) return actor.Type == "refinery" and actor.Owner == player end)

		if #refs == 0 then
			atreides.MarkCompletedObjective(KillHarkonnen)
		else
			Trigger.OnAllRemovedFromWorld(refs, function()
				atreides.MarkCompletedObjective(KillHarkonnen)
			end)

			local silos = Utils.Where(Map.ActorsInWorld, function(actor) return actor.Type == "silo" and actor.Owner == player end)
			Utils.Do(refs, function(actor) Trigger.OnRemovedFromWorld(actor, checkResourceCapacity) end)
			Utils.Do(silos, function(actor) Trigger.OnRemovedFromWorld(actor, checkResourceCapacity) end)
		end
	end)

	Media.DisplayMessage(Messages[1], "Mentat")

	Trigger.AfterDelay(DateTime.Seconds(25), function()
		Media.PlaySpeechNotification(player, "Reinforce")
		Reinforcements.Reinforce(player, HarkonnenReinforcements, HarkonnenEntryPath)
	end)

	WavesLeft = AtreidesAttackWaves[Difficulty]
	SendReinforcements()
end

SendReinforcements = function()
	local units = AtreidesReinforcements[Difficulty]
	local delay = Utils.RandomInteger(AtreidesAttackDelay - DateTime.Seconds(2), AtreidesAttackDelay)
	AtreidesAttackDelay = AtreidesAttackDelay - (#units * 3 - 3 - WavesLeft) * DateTime.Seconds(1)
	if AtreidesAttackDelay < 0 then AtreidesAttackDelay = 0 end

	Trigger.AfterDelay(delay, function()
		Reinforcements.Reinforce(atreides, Utils.Random(units), { Utils.Random(AtreidesEntryWaypoints) }, 10, IdleHunt)

		WavesLeft = WavesLeft - 1
		if WavesLeft == 0 then
			Trigger.AfterDelay(DateTime.Seconds(1), function() AtreidesArrived = true end)
		else
			SendReinforcements()
		end
	end)
end
