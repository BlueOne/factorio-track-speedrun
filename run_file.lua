local commandqueue = {}

--[[
/c for _, furnace in pairs(game.player.surface.find_entities_filtered{name="stone-furnace"}) do
    game.print(furnace.position.x .. "_" .. furnace.position.y .. "_" .. furnace.get_item_count("iron-plate") .. "_" .. game.tick)
end

--]]

local function visit_iron_burner(pre_walk_name)
	local move_command

	if pre_walk_name then
		move_command = {"move", {-16,14}, name="walk-to-iron", command_finished=pre_walk_name}
	else
		move_command = {"move", {-16,14}, name="walk-to-iron"}
	end

	return {
		move_command,

	    {"take", {-10, 15}},
	    {"take", {-10, 13}},
		{"take", {-10, 11}},
	    {"take", {-12, 13}},
	    {"take", {-12, 11}},
		{"take", {-8, 15}}, -- take all coal
	}
end

local take_all_coal = {
    {"take", {-10, 15}},
    {"take", {-10, 13}},
	{"take", {-10, 11}},
    {"take", {-12, 13}},
    {"take", {-12, 11}},
	{"take", {-8, 15}},
}

local function refill_early_science(amount)
	return {
		{"put", {-27.5, -6.5}, "copper-plate", amount},
		{"put", {-27.5, -6.5}, "iron-gear-wheel", amount},
	
		{"put", {-14.5, -4.5}, "copper-plate", amount},
		{"put", {-14.5, -4.5}, "iron-gear-wheel", amount},
	
		{"put", {-29.5, -11.5}, "copper-plate", amount},
		{"put", {-29.5, -11.5}, "iron-gear-wheel", amount},
		{"put", {-26.5, -11.5}, "copper-plate", amount},
		{"put", {-26.5, -11.5}, "iron-gear-wheel", amount},
		{"put", {-23.5, -11.5}, "copper-plate", amount},
		{"put", {-23.5, -11.5}, "iron-gear-wheel", amount},
	
		{"put", {-29.5, -15.5}, "copper-plate", amount},
		{"put", {-29.5, -15.5}, "iron-gear-wheel", amount},
		{"put", {-26.5, -15.5}, "copper-plate", amount},
		{"put", {-26.5, -15.5}, "iron-gear-wheel", amount},
		{"put", {-23.5, -15.5}, "copper-plate", amount},
		{"put", {-23.5, -15.5}, "iron-gear-wheel", amount},
	}
end

local function refill_belt_assembler(amount)
	return {
		{"put", {-7.5,7.5}, "iron-plate", amount},
		{"put", {-7.5,7.5}, "iron-gear-wheel", amount},
	}
end

local function take_early_science(amount)
	return {
		{"take", {-29.5, -11.5}, "science-pack-1", amount},
		{"take", {-26.5, -11.5}, "science-pack-1", amount},
		{"take", {-23.5, -11.5}, "science-pack-1", amount},
		
		{"take", {-29.5, -15.5}, "science-pack-1", amount},
		{"take", {-26.5, -15.5}, "science-pack-1", amount},
		{"take", {-23.5, -15.5}, "science-pack-1", amount},
	}
end

local function insert_equal(positions, item, total_amount)
	local amount = math.floor(total_amount / #positions)
	local remainder = total_amount % #positions
	local extra = 1
	
	local commands = {}
	
	for i, pos in pairs(positions) do
		if i > remainder then
			extra = 0
		end
		table.insert(commands, {"put", pos, item, amount + extra})
	end
	
	return commands
end

local function generate_points(pos1, pos2, _space)
	local space = _space or 1
	local coords_exchanged = false
	
	local function exchange_coords(pos)
		return {pos[2], pos[1]}
	end
	
	if pos1[1] ~= pos2[1] then
		pos1 = exchange_coords(pos1)
		pos2 = exchange_coords(pos2)
		
		coords_exchanged = true
	end
	
	if pos1[1] ~= pos2[1] then
		error("generate_points was called with non-aligned points!")
	end
	
	if (pos1[2] - pos2[2]) % space ~= 0 then
		error("generate_points expected the points to be a multiple of " .. space .. "apart!")
	end
	
	if pos1[2] > pos2[2] then
		space = -space
	end
	
	local result = {}
	
	local current_pos = pos1[2]
	
	while current_pos ~= pos2[2] + space do -- we want to include pos2
		if coords_exchanged then
			table.insert(result, {current_pos, pos1[1]})
		else
			table.insert(result, {pos1[1], current_pos})
		end
		
		current_pos = current_pos + space
	end
	
	return result
end

local recipes = {
	["wood"] = {{name="raw-wood", amount=1}},
	["small-electric-pole"] = {{name="wood", amount=2}, {name="copper-cable", amount=2}},
	["iron-chest"] = {{name="iron-plate", amount=8}},
	["stone-furnace"] = {{name="stone", amount=5}},
	["iron-gear-wheel"] = {{name="iron-plate", amount=2}},
	["pipe"] = {{name="iron-plate", amount=1}},
	["copper-cable"] = {{name="copper-plate", amount=1}},
	["electronic-circuit"] = {{name="iron-plate", amount=1}, {name="copper-cable", amount=3}},
	["transport-belt"] = {{name="iron-plate", amount=1}, {name="iron-gear-wheel", amount=1}},
	["underground-belt"] = {{name="iron-plate", amount=10}, {name="transport-belt", amount=5}},
	["inserter"] = {{name="iron-plate", amount=1}, {name="iron-gear-wheel", amount=1}, {name="electronic-circuit", amount=1}},
	["long-handed-inserter"] = {{name="iron-plate", amount=1}, {name="iron-gear-wheel", amount=1}, {name="inserter", amount=1}},
	["fast-inserter"] = {{name="iron-plate", amount=2}, {name="electronic-circuit", amount=2}, {name="inserter", amount=1}},
	["electric-mining-drill"] = {{name="iron-plate", amount=10}, {name="iron-gear-wheel", amount=5}, {name="electronic-circuit", amount=3}},
	["steam-engine"] = {{name="iron-plate", amount=10}, {name="iron-gear-wheel", amount=8}, {name="pipe", amount=5}},
}

local function has_value(table, element)
	for _,v in pairs(table) do
		if v == element then
			return true
		end
	end
	return false
end

local function insert_recipe_except(position, recipe, amount, exceptions)
	local commands = {}
	local exc
	
	if not recipes[recipe] then
		error("Unknown recipe: " .. recipe)
	end
	
	if type(exceptions) == type("") then
		exc = {exceptions}
	elseif type(exceptions) == type({}) then
		exc = exceptions
	elseif type(exceptions) == type(nil) then
		exc = {}
	end
	
	for _,ingredient in pairs(recipes[recipe]) do
		if not has_value(exc, ingredient.name) then
			table.insert(commands, {"put", position, ingredient.name, ingredient.amount * amount})
		end
	end
	
	return commands
end

local function insert_recipe(position, recipe, amount, exceptions)
	return insert_recipe_except(position, recipe, amount)
end

local function change_recipe_and_insert_except(position, recipe, amount, exceptions)
	local commands = insert_recipe_except(position, recipe, amount, exceptions)
	
	for _,cmd in pairs(commands) do
		cmd.command_finished = "recipe-changed"
	end
	
	table.insert(commands, {"recipe", position, recipe, name="recipe-changed"})
	
	return commands
end

local function change_recipe_and_insert(position, recipe, amount)
	return change_recipe_and_insert_except(position, recipe, amount)
end

local bottom_furnace = {-3, 37, entity=true}
local circuit_assembler = {-7.5, 10.5, entity=true}
local belt_assembler = {-7.5, 7.5, entity=true}
local rightmost_cable_chest = {27.5, 11.5, entity=true}
local bottom_gear_chest = {5.5, -1.5, entity=true}
local top_gear_chest = {5.5, -4.5, entity=true}
local stone_furnace_assembler = {-36.5, -7.5}
local stone_furnace_assembler_entity = {-36.5, -7.5, entity=true}
local stone_furnace_chest = {-33.5, -7.5}
local stone_furnace_chest_entity = {-33.5, -7.5, entity=true}

function visit_copper(pre_walk_name)
	local move_command

	if pre_walk_name then
		move_command = {"move", "copper-cable-taken", command_finished=pre_walk_name}
	else
		move_command = {"move", "copper-cable-taken"}
	end

	return {
		move_command,

		{"entity-interaction", {23.5, 11.5}, name="copper-cable-taken"},
	}
end

function visit_gears(insert_iron, pre_walk_name)
	local move_command

	if pre_walk_name then
		move_command = {"move", "gears-taken", command_finished=pre_walk_name}
	else
		move_command = {"move", "gears-taken"}
	end

	return {
		move_command,

		{"entity-interaction", {-7.5,7.5}, name="gears-taken"},
		{"put", {-7.5,7.5}, "iron-plate", insert_iron},
		{"put", {-7.5,10.5}, "iron-plate", insert_iron},
	}
end

commandqueue["settings"] = {
    debugmode = true,
    allowspeed = true,
    end_tick_debug = true,
	enable_high_level_commands = true
}

commandqueue["command_list"] = {
	{
		name = "start-1",
		commands = {
			{"pickup", name="pickup"},
			{"craft", "iron-axe", 1},
			{"tech", "automation"},
			{"move", "miner-built", priority=2},
			{"build", "burner-mining-drill", {-15,15}, 2, name="miner-built"},
			{"build", "stone-furnace", {-13,15}, 0},
			{"mine", {-11.5,12.5}, amount=2, name="mine-coal"},
			{"auto-refuel", name="auto-refuel"},
		}
	},
	{
		name = "start-2",
		required = {"mine-coal"},
		commands = {
			{"move", "mine-rock"},
			{"mine", {-40.5,11.5}, "rock", amount=1, name="mine-rock"},
		}
	},
	{
		name = "start-3",
		required = {"mine-rock"},
		commands = {
			{"move", "mine-coal"},
			{"mine", {-10.5,13.5}, amount=11, name="mine-coal"},
			{"craft", "stone-furnace", 4},
			{"take", {-13,15}, items_available={"iron-plate", 2}, name="iron-taken"},
		}
	},
	{
		name = "start-4",
		required = {"iron-taken"},
		commands = {
			{"craft", "iron-gear-wheel", 3},
			{"take", {-13,15}, "iron-plate", items_available={"iron-plate", 3}},
			{"craft-build", "burner-mining-drill", {-15,17}, 2, name="miner-built"},
		}
	},
	{
		name = "start-5",
		required = {"miner-built"},
		commands = {
			{"build", "stone-furnace", {-13,17}, 0, name="furnace-built"},
		}
	},
	{
		name = "start-6",
		required = {"furnace-built"},
		commands = {
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"mine", {-14.5,11.5}, amount=45, priority=8, command_finished="start-3.mine-coal", name="mine-stone"},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-12,13}, 6, name="miner-built"},
		}
	},
	{
		name = "start-8",
		required = {"miner-built"},
		commands = {
			{"move", {-13.1,13}},
			{"craft", "stone-furnace", 1},
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft", "stone-furnace", 2, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-15,19}, 2, name="miner-built"},
		}
	},
	{
		name = "start-9",
		required = {"miner-built"},
		commands = {
			{"build", "stone-furnace", {-13,19}, 0},
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-17,15}, 6, name="miner-built"},
		}
	},
	{
		name = "start-10",
		required = {"miner-built"},
		commands = {
			{"build", "stone-furnace", {-19,15}, 0},
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"craft", "stone-furnace", 1},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-12,11}, 4, name="miner-built"},
		}
	},
	{
		name = "start-11",
		required = {"miner-built"},
		commands = {
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"craft", "stone-furnace", 1},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-17,17}, 6, name="miner-built"},
		}
	},
	{
		name = "start-12",
		required = {"miner-built"},
		commands = {
			{"move", "furnace-built"},
			{"craft-build", "stone-furnace", {-19,17}, 2, name="furnace-built"},
		}
	},
	{
		name = "start-13",
		required = {"furnace-built"},
		commands = {
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"craft", "stone-furnace", 1},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-15,13}, 2, name="miner-built"},
		}
	},
	{
		name = "start-14",
		required = {"miner-built"},
		commands = {
			{"move", "miner-built"},
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"craft", "stone-furnace", 1},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft", "burner-mining-drill", 1, name="miner-craft"},
			{"build", "burner-mining-drill", {-17,19}, 6, name="miner-built"},
		}
	},
	{
		name = "start-15",
		required = {"miner-built"},
		commands = {
            {"move", "furnace-built", items_available={"stone", 5}},
            {"rotate", {-12,13}, "N"},
            {"rotate", {-15,13}, "W", items_available={"stone", 5}},
			{"craft", "stone-furnace", 1, name="craft-furnace"},
			{"build", "stone-furnace", {-19,19}, 6, name="furnace-built"},
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears", command_finished="craft-furnace"},
			{"craft", "stone-furnace", 1, name="stone-furnace"},
		}
	},
	{
		name = "start-16",
		required = {"gears", "furnace-built"},
		commands = {
            {"auto-take", "iron-plate", 3},
			{"take", {-12, 13}},
			{"craft-build", "burner-mining-drill", {-14, 11}, 6, name="miner-built"},
			{"move", {-15.7,14}},
			{"mine", {-16.5, 11.5}, amount=45, name="mine-stone", priority=8},
            {"auto-take", "iron-plate", 8, exact=true, command_finished="miner-built"},
            {"craft-build", "iron-chest", {-15.5, 11.5}, 0, name="chest"}
		}
	},
	{
		name = "start-17",
		required = {"chest"},
		commands = {
            {"stop-command", "start-6.mine-stone"},
			{"rotate", {-15, 13}, "N"},
			{"auto-take", "iron-plate", 6},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
            {"take", {-15, 11}, type="container", items_total={"stone", 5}, name="take-stone"},
            {"take", {-12, 11}},
            {"take", {-12, 13}},
			{"craft-build", "burner-mining-drill", {-19, 13}, 2, name="miner-built"},
		}
	},
	{
		name = "start-18",
		required = {"miner-built"},
		commands = {
			{"take", {-15, 11}, type="container", items_total={"stone", 5}},
			{"craft-build", "stone-furnace", {-17, 13}, name="furnace-built"},
		}
	},
	{
		name = "start-19",
		required = {"furnace-built"},
        --force_save = true,
		commands = {
			--{"entity-interaction", {-17,19}, name="fuel-furnace"},
			--{"move", "fuel-furnace"},
			{"auto-take", "iron-plate", 6},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft", "stone-furnace", 1},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"take", {-15,11.5}, type="container", items_total={"stone", 5}},
			{"craft-build", "burner-mining-drill", {-10,11}, 6, name="miner-built"},
		}
	},
    {
        name = "start-20",
        required = {"miner-built"},
        commands = {
            {"take", {-12, 11}},
            {"take", {-12, 13}},
            {"auto-take", "iron-plate", 6},
            {"auto-take", "iron-plate", 3, command_finished="gears"},
            {"craft", "iron-gear-wheel", 3, name="gears"},
            {"take", type="container", {-15, 11}, items_total={"stone", 5}},
            {"craft-build", "burner-mining-drill", {-10, 13}, 0, name="miner-built"},
        }
    },
    {
        name = "start-21",
        required = {"miner-built"},
        commands = {
            {"auto-take", "iron-plate", 10, name="take-iron"},
            {"auto-take", "iron-plate", 3, command_finished="take-iron"},
            {"craft", "iron-gear-wheel", 3, name="gears"},
			{"craft", "iron-axe", 1, name="axe"},
            {"take", type="container", {-15, 11}, items_total={"stone", 5}},
            {"craft-build", "burner-mining-drill", {-16, 10}, 4, name="miner-built"},
        }
    },
    {
        name = "start-22",
        required = {"miner-built", "axe"},
        commands = {
            {"take", {-12, 11}},
            {"take", {-12, 13}},
			{"take", {-10, 11}},
            {"auto-take", "iron-plate", 6},
            {"auto-take", "iron-plate", 3, command_finished="gears"},
            {"craft", "iron-gear-wheel", 3, name="gears"},
            {"take", type="container", {-15, 11}, items_total={"stone", 5}},
            {"craft-build", "burner-mining-drill", {-10, 15}, 0, name="miner-built"},
        }
    },
    {
        name = "start-23",
        required = {"miner-built"},
        commands = {
			{"move", "miner-built"},
            {"take", {-12, 11}},
            {"take", {-12, 13}},
			{"take", {-10, 11}},
            {"auto-take", "iron-plate", 6},
            {"auto-take", "iron-plate", 3, command_finished="gears"},
            {"craft", "iron-gear-wheel", 3, name="gears"},
            {"take", type="container", {-15, 11}, items_total={"stone", 5}},
            {"craft-build", "burner-mining-drill", {-11, 9}, 4, name="miner-built"},
        }
    },
    {
        name = "start-24",
        required = {"miner-built"},
        commands = {
			{"move", "miner-built", command_finished="gears"},
            {"auto-take", "iron-plate", 6},
            {"auto-take", "iron-plate", 3, command_finished="gears"},
            {"craft", "iron-gear-wheel", 3, name="gears"},
            {"take", {-15, 11}, items_total={"stone", 5}},
            {"craft-build", "burner-mining-drill", {-8, 15}, 6, name="miner-built"},
        }
    },
    {
        name = "start-25",
        required = {"miner-built"},
        commands = {
			{"move", {-15.8,14}},
			{"move", "miner-built", command_finished="gears"},
            {"auto-take", "iron-plate", 6},
            {"auto-take", "iron-plate", 3, command_finished="gears"},
            {"craft", "iron-gear-wheel", 3, name="gears"},
            {"take", {-15, 11}, items_total={"stone", 5}},
            {"craft-build", "burner-mining-drill", {-8, 13}, 4, name="miner-built"},
			{"put", {-8, 13}, "coal", 3},
			{"take", {-10, 11}},
        }
    },
    {
        name = "start-26",
        required = {"miner-built"},
        commands = {
			{"auto-take", "iron-plate", 6},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
            {"craft", "stone-furnace", 1, name="furnace"},
            {"craft", "stone-furnace", 1},
			{"craft", "iron-gear-wheel", 3, name="gears"},
            {"take", {-15, 11}, type="container", items_total={"stone", 10}},
			{"craft-build", "burner-mining-drill", {-20,11}, 2, name="miner-built"},
            {"build", "stone-furnace", {-18, 11}, command_finished="miner-built"},
		}
    },
    {
        name = "start-27",
        required = {"miner-built"},
        commands = {
			{"move", {-15.8,14}},
            {"take", {-12, 11}},
            {"take", {-12, 13}},
			{"take", {-10, 11}},
			{"auto-take", "iron-plate", 30},
			{"auto-take", "iron-plate", 15, command_finished="gears"},
			{"take", type="container", {-15, 11}, items_total={"stone", 25}},
			{"craft", "burner-mining-drill", 5, name="miner-crafted", command_finished="gears"},
			{"craft", "iron-gear-wheel", 15, name="gears"},
			{"craft", "stone-furnace", 5, name="furnaces-crafted"},
        }
    },
    {
        name = "start-28",
        required = {"miner-crafted", "furnaces-crafted"},
        commands = {
            {"take", {-10, 15}},
            {"take", {-10, 13}},
			{"take", {-10, 11}},
            {"take", {-12, 13}},
            {"take", {-12, 11}},
			{"take", type="container", {-15, 11}, items_total={"stone", 18}},
			{"craft", "stone-furnace", 6, name="furnaces-crafted"},
			{"auto-refuel", min=1, target=2, type="mining-drill", skip_coal_drills=true, name="refuel-drills"},
			{"auto-refuel", min=1, type="furnace", name="refuel-furnaces"},
			{"auto-refuel", min=1, target=3, pos={-11, 9}},
			{"auto-refuel", min=1, target=3, pos={-8, 13}},
        }
    },
    {
        name = "copper-1",
		force_save = "Copper start",
        required = {"furnaces-crafted"},
        commands = {
			{"stop-command", "start-16.mine-stone"},

			{"passive-take", "iron-plate", "furnace", name="passive-take-iron"},
			{"passive-take", "copper-plate", "furnace", name="passive-take-copper"},
			{"passive-take", "stone", "container", name="passive-take-stone"},

			{"move", "miner-built"},

            {"take", {-10, 15}},
            {"take", {-10, 13}},
			{"take", {-10, 11}},
            {"take", {-12, 13}},
            {"take", {-12, 11}},
			{"take", {-8, 15}}, -- take all coal

			{"craft", "boiler", 1},
			{"craft", "iron-gear-wheel", 10},
			{"craft", "transport-belt", 2},

			{"build", "burner-mining-drill", {18, 3}, 4},
			{"build", "burner-mining-drill", {20, 3}, 4},
			{"build", "burner-mining-drill", {22, 3}, 4},
			{"build", "burner-mining-drill", {24, 3}, 4},
			{"build", "burner-mining-drill", {26, 3}, 4, name="miner-built"},

			{"build", "stone-furnace", {18, 5}, 0},
			{"build", "stone-furnace", {20, 5}, 0, priority=1},
			{"build", "stone-furnace", {22, 5}, 0},
			{"build", "stone-furnace", {24, 5}, 0},
			{"build", "stone-furnace", {26, 5}, 0},
        }
    },
    {
        name = "copper-2",
        required = {"miner-built"},
        commands = {
			{"simple-sequence", "mine", {27.5, -2}, {33.5, -6}, pass_arguments = {[3]="tree"}, name="mine-tree"},
        }
    },
    {
        name = "copper-3",
        required = {"mine-tree"},
        commands = {
			{"entity-interaction", {-19, 19}, name="bottom-left"},

            {"take", {-10, 15}},
            {"take", {-10, 13}},
            {"take", {-12, 13}},
			{"take", {-8, 15}}, -- take all coal

			{"move", {-16,14}, name="walk"},

			{"stop-command", "start-28.refuel-drills"},
			{"stop-command", "start-28.refuel-furnaces"},
			{"auto-refuel", min=2, target=4, type="mining-drill", skip_coal_drills=true, name="refuel-drills"},
			{"auto-refuel", min=1, target=2, type="furnace", name="refuel-furnaces"},

			{"craft", {{"iron-gear-wheel", 4}, {"wood", 3}}},
        }
    },
    {
        name = "copper-4",
        required = {"bottom-left"},
        commands = {
			{"stop-command", "copper-3.walk"},

			{"entity-interaction", {26, 5}, name="right"}, -- take all copper

			--{"move", "right", name="walk"},
			{"move", {21, 4}, name="walk"}, -- the top command runs into furnaces

			{"craft", "lab", 1},
			{"craft", "pipe", 11},
        }
    },
    {
        name = "copper-5",
        required = {"right"},
        commands = {
			{"stop-command", "copper-4.walk"},
			{"simple-sequence", "mine", {22.5, -6}, {16, -11}, {14, -13.5}, pass_arguments = {[3]="tree"}, name="mine-tree"}
		}
    },
    {
        name = "copper-6",
        required = {"mine-tree"},
        commands = {
			{"entity-interaction", {26, 5}, name="right"},
			{"move", "right", name="walk"},

			{"craft", "small-electric-pole", 1},
			{"craft", "offshore-pump", 1},
			{"craft", "science-pack-1", 1},
        }
    },
    {
        name = "copper-7",
        required = {"right"},
        commands = {
			{"entity-interaction", {-19, 19}, name="bottom-left"},

            {"take", {-10, 15}},
            {"take", {-10, 13}},
			{"take", {-10, 11}},
            {"take", {-12, 13}},
            {"take", {-12, 11}},
			{"take", {-8, 15}}, -- take all coal

			{"move", {-16,14}, name="walk"},
        }
    },
    {
        name = "copper-8",
        required = {"bottom-left"},
        commands = {
			{"stop-command", "copper-7.walk"},
			{"simple-sequence", "mine", {-4, -37.5}, {-4.5, -39.5}, {-3, -41}, pass_arguments = {[3]="tree"}, name="mine-tree"},
			{"move", "pipe-built", command_finished="mine-tree"},
			{"move", "offshore-pump-built", command_finished="pipe-built"},
			{"move", {-35,-6}, command_finished="offshore-pump-built"},

			{"craft", "steam-engine", 1},
			{"build", "offshore-pump", {-45, -6}, 6, name="offshore-pump-built"},
			{"build", "pipe", {-43.5,-5.5}, 0},
			{"build", "pipe", {-43.5,-6.5}, 0},
			{"build", "pipe", {-43.5,-7.5}, 0},
			{"build", "pipe", {-43.5,-8.5}, 0},
			{"build", "pipe", {-43.5,-9.5}, 0, name="pipe-built"},
			{"build", "boiler", {-43,-11.5}, 2, name="boiler-built"},
			{"build", "steam-engine", {-40,-12}, 2, name="steam-engine"},

			{"build", "lab", {-31.5,-6.5}, 2},
			{"build", "small-electric-pole", {-41.5,-8.5}, 0},
			{"build", "small-electric-pole", {-34.5,-8.5}, 0},

			{"put", {-43,-11.5}, "coal", 5},
			{"put", {-31.5,-6.5}, "science-pack-1", 1},
        }
    },
    {
        name = "copper-9",
        required = {"steam-engine"},
        commands = {
			{"move", {-27,-1}, name="walk-1"},
			{"move", {-17,10}, name="pre-visit-iron-walk", command_finished="science-inserted"},
			{"craft", "science-pack-1", 2},
			{"put", {-31.5,-6.5}, "science-pack-1", 1, name="science-inserted"},
			{"parallel", visit_iron_burner("copper-9.pre-visit-iron-walk"), command_finished = "science-inserted"},
		}
    },
    {
        name = "power-1",
		force_save = "Power finished",
        required = {"parallel-1.walk-to-iron"},
        commands = {
			{"craft", "iron-gear-wheel", 4, name="gears"},
			{"craft", "science-pack-1", 4, command_finished="gears"},

			{"entity-interaction", {26,3}, name="right-furnace"},
			{"move", "right-furnace", name="walk"},
        }
    },
    {
        name = "power-2",
        required = {"walk"},
        commands = {
			{"move", "science-inserted"},
			{"put", {-31.5,-6.5}, "science-pack-1", 2, name="science-inserted"},

			{"craft", {{"small-electric-pole", 2}, {"small-electric-pole", 3}, {"electric-mining-drill", 2}}, command_finished="science-inserted"},
        }
    },
    {
        name = "power-3",
        required = {"science-inserted"},
        commands = {
			{"simple-sequence", "mine", {-18.5, -22}, {-15, -33}, {-13.5, -34.5}, {-11, -36.5}, {-3, -29}, {-2.5, -26.5}, {-1.5, -25.5}, {1.68, -18}, {0.5, -15}, {4.5,-9}, pass_arguments = {[3]="tree"}, name="mine-tree"},
        }
    },
    {
        name = "power-4",
        required = {"mine-tree"},
        commands = {
			{"move", "science-inserted"},
			{"put", {-31.5,-6.5}, "science-pack-1", 3, name="science-inserted"},
			{"auto-build-blueprint", "Bootstrap-1", {-7,17}, set_on_leaving_range=false},

			{"build", "small-electric-pole", {-27.5,-8.5}, 0},
			{"build", "small-electric-pole", {-23.5,-4.5}, 0},
			{"build", "small-electric-pole", {-16.5,-5.5}, 0},
			{"build", "small-electric-pole", {-9.5,-6.5}, 0},

			{"craft", {{"transport-belt", 2}, {"transport-belt", 2}}},
        }
    },
    {
        name = "power-5",
        required = {"science-inserted"},
        commands = {
			{"move", {-6,-3}, name="walk"},
			{"move", {-5.5,21}, name="walk-2", command_finished="walk"},
			{"craft", "science-pack-1", 3},
			{"parallel", visit_iron_burner(), command_finished = "walk-2"},
		}
    },
    {
        name = "power-6",
        required = {"parallel-1.walk-to-iron"},
        commands = {
			{"move", {-11,21}},
        }
    },
    {
        name = "power-7",
        required = {"power-4.bp_{-5.5, 22.5}"},
        commands = {
			{"move", "power-4.bp_{-5.5, 15.5}"},
			{"put", {-31.5,-6.5}, "science-pack-1", 1, name="science-inserted"},
			{"move", "science-inserted", command_finished="power-4.bp_{-5.5, 15.5}"},

			{"craft", {{"stone-furnace", 4}, {"inserter", 2}, {"inserter", 2}}},
        }
    },
    {
        name = "power-8",
        required = {"science-inserted"},
        commands = {
			{"move", {-6,17}, name="walk"},
        }
    },
    {
        name = "power-9",
        required = {"walk"},
        commands = {
			{"move", "science-inserted"},
			{"put", {-31.5,-6.5}, "science-pack-1", 2, name="science-inserted"},
        }
    },
    {
        name = "automation-1",
		force_save = "Automation finished",
        required = {"science-inserted"},
        commands = {
			{"move", {-7,17}, name="walk"},
			{"craft", {{"stone-furnace", 1}, {"iron-gear-wheel", 5}, {"electronic-circuit", 3}, {"iron-gear-wheel", 5}, {"copper-cable", 2}, {"assembling-machine-1", 1}, {"small-electric-pole", 2}}},
			{"build", "stone-furnace", {-3,13}, 0},
			{"build", "assembling-machine-1", {-7.5,10.5}, 0, name="assembler-built"},
			{"put", {-7.5,10.5}, "iron-plate", 34, name="iron-inserted"},
			{"put", {-3,13}, "iron-ore", 10},
			{"recipe", {-7.5,10.5}, "iron-gear-wheel", name="recipe-set"},
			{"move", "assembler-built", command_finished="walk"},
			{"tech", "logistics"},

			{"stop-command", "start-1.pickup"},
			{"parallel", visit_iron_burner(), command_finished = "iron-inserted"},
		}
    },
    {
        name = "automation-2",
        required = {"parallel-1.walk-to-iron"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-copper-1", {20,6}, set_on_leaving_range=false},
			{"move", {1,2}, name="walk"},

			{"craft", {{"assembling-machine-1", 1}, {"small-electric-pole", 1}, {"electronic-circuit", 3}}},

			{"passive-take", "iron-gear-wheel", "assembling-machine", name="passive-take-gears"},
			{"passive-take", "copper-cable", "assembling-machine", name="passive-take-copper-cable-assembler"},
			{"passive-take", "copper-cable", "container", name="passive-take-copper-cable-chest"},


			{"put", {-7.5,10.5}, "iron-plate", 20, name="iron-inserted"},
			{"put", {19.5,8.5}, "copper-plate", 20},

			{"entity-interaction", {26, 5}, name="right-copper"},
			{"move", "right-copper", command_finished="walk"},
        }
    },
    {
        name = "automation-3",
        required = {"right-copper"},
        commands = {
			{"move", "gears-taken"},
			{"entity-interaction", {-7.5,10.5}, name="gears-taken"},

			{"craft", {{"assembling-machine-1", 1}, {"inserter", 1}}, command_finished="gears-taken", items_total={"electronic-circuit", 3}},
        }
    },
    {
        name = "automation-4",
        required = {"gears-taken"},
        commands = {
			{"entity-interaction", {-43,-11.5}, name="refuel-boiler"},
			{"move", "refuel-boiler"},
			{"auto-refuel", min=40, target=50, type="boiler", name="refuel-boilers"},

			{"build", "assembling-machine-1", {-27.5,-6.5}, 0},
			{"build", "inserter", {-29.5,-6.5}, 2},

			{"recipe", {-27.5,-6.5}, "science-pack-1", name="recipe-set"},

			{"put", {-27.5,-6.5}, "copper-plate", 4},
			{"put", {-27.5,-6.5}, "iron-gear-wheel", 4, name="gears-inserted"},

			{"craft", {{"inserter", 3}, {"iron-chest", 1}}, command_finished="gears-inserted"},
        }
    },
    {
        name = "automation-5",
        required = {"refuel-boiler"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-copper-2", {20,6}, set_on_leaving_range=false},

			{"move", "gears-taken", name="walk-1"},
			{"entity-interaction", {-7.5,10.5}, name="gears-taken"},

			{"craft", {{"electric-mining-drill", 1}}, items_available={"copper-cable", 20}},

			{"move", {14.1,8}, command_finished="walk-1"},
		},
    },
    {
        name = "automation-6",
        required = {"automation-5.bp_{19.5, 11.5}"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-2", {-7,17}, set_on_leaving_range=false},

			{"craft", {{"transport-belt", 2}, {"stone-furnace", 1}}},
			{"craft", {{"transport-belt", 2}, {"inserter", 2}, {"electronic-circuit", 1}}, items_available={"iron-gear-wheel", 4}},

			{"move", "gears-taken", name="walk-1"},
			{"entity-interaction", {-7.5,10.5}, name="gears-taken"},
			{"put", {-7.5,10.5}, "iron-plate", 40, name="iron-inserted"},

			{"move", {-2,22}, command_finished="walk-1"},
			{"move", {-2,16}, command_finished="automation-6.bp_{-5.5, 25.5}", name="walk-2"},
			{"parallel", visit_iron_burner(), command_finished = "walk-2"},
		}
    },
    {
        name = "automation-7",
        required = {"parallel-1.walk-to-iron"},
        commands = {
			{"stop-command", "copper-1.passive-take-copper"},
			
			{"simple-sequence", "move", {0, 14}, "automation-7.refuel-right", {21, 7}, {21, 10}, {19, 10}, name="walk"},

			{"craft", {{"small-electric-pole", 1}, {"electronic-circuit", 3}}},
			{"craft", "assembling-machine-1", 1, need_intermediates=true},
			{"craft", {{"inserter", 3}, {"iron-chest", 1}, {"electronic-circuit", 3}}, command_finished="copper-cable-taken"},

			{"put", {23.5,8.5}, "copper-plate", 10},
			{"entity-interaction", {19.5, 11.5}, name="copper-cable-taken"},

			{"entity-interaction", {24,3}, name="refuel-right"},
		},
    },
    {
        name = "automation-8",
        required = {"automation-5.bp_{23.5, 11.5}"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-3", {-7,17}, set_on_leaving_range=false},

			{"move", "gears-taken"},
			{"entity-interaction", {-7.5,10.5}, name="gears-taken"},
			{"put", {-7.5,10.5}, "iron-plate", 20},

			{"craft", {{"electric-mining-drill", 1}, {"transport-belt", 1}, {"electronic-circuit", 6}}},

			{"move", {-4,23}, command_finished="gears-taken", name="walk"},

			{"parallel", visit_iron_burner(), command_finished="automation-8.bp_{-5.5, 28.5}"}
		}
    },
    {
        name = "automation-9",
        required = {"parallel-1.walk-to-iron"},
        commands = {
			{"craft", {{"assembling-machine-1", 1}, {"electronic-circuit", 1}}},
			{"put", {-27.5,-6.5}, "copper-plate", 5},
			{"put", {-27.5,-6.5}, "iron-gear-wheel", 5, name="gears-inserted"},

			{"move", "gears-inserted"},

			{"entity-interaction", {-7.5,10.5}, name="gears-taken"},
			{"simple-sequence", "move", {-10, 8}, {-5, 9.3}, {-5, 27.5}, command_finished="gears-inserted", name="walk-3"},

			{"craft", {{"electric-mining-drill", 1}, {"small-electric-pole", 1}, {"transport-belt", 2}, {"pipe", 5}}, command_finished="gears-taken"},

			{"build", "assembling-machine-1", {-7.5,7.5}, 0},
			{"recipe", {-7.5,7.5}, "iron-gear-wheel"},
			{"put", {-7.5,7.5}, "iron-plate", 20},
			{"put", {-7.5,10.5}, "iron-plate", 20},
		},
    },
    {
        name = "automation-10",
        required = {"automation-8.bp_{-5.5, 31.5}"},
        commands = {
			{"move", "gears-taken"},
			{"entity-interaction", {-7.5,7.5}, name="gears-taken"},
			{"put", {-7.5,7.5}, "iron-plate", 10},
			{"put", {-7.5,10.5}, "iron-plate", 10},

			{"craft", {{"steam-engine", 1}, {"pipe", 1}, {"transport-belt", 2}}, items_available={"pipe", 5}},
			{"craft", "electronic-circuit", 5, items_available={"copper-cable", 15}},

			{"move", "copper-cable-taken", command_finished="gears-taken"},
			{"entity-interaction", {23.5, 11.5}, name="copper-cable-taken"},
		},
    },
    {
        name = "automation-11",
        required = {"copper-cable-taken"},
        commands = {
			{"move", {-6,4}, name="walk"},
			{"move", "steam-engine-built", command_finished="walk"},
			{"take", {-7.5,7.5}, "iron-gear-wheel"},
			{"take", {-7.5,10.5}, "iron-gear-wheel"},
			{"put", {-7.5,7.5}, "iron-plate", 10},

			{"craft", {{"lab", 1}, {"inserter", 1}, {"electronic-circuit", 5}}},

			{"build", "steam-engine", {-33.5,-11.5}, 2},
			{"build", "pipe", {-36.5, -11.5}, name="steam-engine-built"},
			{"build", "lab", {-23.5,-6.5}, 0},
			{"build", "inserter", {-25.5,-6.5}, 6, name="inserter-built"},

			{"move", {-21,-3}, command_finished="steam-engine-built"},
			{"move", {-17,10}, command_finished="inserter-built", name="pre-visit-iron-walk"},
			{"parallel", visit_iron_burner("automation-11.pre-visit-iron-walk"), command_finished = "inserter-built"},
		}
    },
    {
        name = "automation-12",
        required = {"parallel-1.walk-to-iron"},
        commands = {
			{"parallel", visit_gears(14)},

			{"entity-interaction", {-3,11}, name="iron-top"},
			{"entity-interaction", {-3,21}, name="iron-bottom"},

			{"move", "iron-bottom", command_finished="parallel-1.gears-taken"},
			{"move", "iron-top", command_finished="iron-bottom"},

			{"parallel", visit_copper("automation-12.iron-top")},

			{"craft", {{"electric-mining-drill", 2}}, items_available={"electronic-circuit", 5}},
			{"craft", {{"transport-belt", 2}, {"stone-furnace", 2}, {"electric-mining-drill", 1}, {"transport-belt", 2}}, command_finished="parallel-2.copper-cable-taken"},

			{"move", {-3, 29.5}, command_finished="parallel-2.copper-cable-taken", name="walk"},

			{"put", {-3, 23}, "iron-ore", 5},
			{"put", {-3, 25}, "iron-ore", 5},
		},
    },
    {
        name = "automation-13",
		force_save = "Automation midpoint",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-4", {-7,17}, set_on_leaving_range=false},

			{"move", {-4.9, 34.3}},

			{"craft", {{"stone-furnace", 6}, {"inserter", 4, need_intermediates={"iron-gear-wheel"}}}},
			{"craft", "inserter", 4, command_finished="sequence.command-1"},
			
			{"sequence", {
				{"parallel", visit_gears(18)},
				{"parallel", visit_iron_burner()},
				{"parallel", visit_copper()},
			}, name="sequence", command_finished="bp_{-5.5, 40.5}"},

			{"simple-sequence", "move", {-3, 26}, {-4, 26.5}, command_finished="sequence", name="walk"},
			{"craft", {{"transport-belt", 2}, {"assembling-machine-1", 1}}, command_finished="sequence"},
		},
    },
    {
        name = "automation-14",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-5", {-7,17}, set_on_leaving_range=false},

			{"parallel", visit_gears(0)},

			{"craft", {{"lab", 1}, {"inserter", 1}, {"wood", 1}, {"stone-furnace", 2}}, items_available={"iron-gear-wheel", 12}},

			{"move", {-40,-8}, command_finished="parallel-1.gears-taken", name="walk"},

			{"recipe", {-7.5,10.5}, "copper-cable"},

			{"put", {-7.5,10.5}, "copper-plate", 15},
			{"put", {-7.5,7.5}, "iron-plate", 16},

			{"build", "lab", {-18.5, -4.5}, 0},
			{"build", "assembling-machine-1", {-14.5, -4.5}, 0},
			{"build", "inserter", {-16.5, -4.5}, 2, name="inserter-built"},

			{"put", {-14.5, -4.5}, "copper-plate", 4},
			{"put", {-14.5, -4.5}, "iron-gear-wheel", 4},

			{"recipe", {-14.5, -4.5}, "science-pack-1"},

			{"put", {-27.5, -6.5}, "copper-plate", 5},
			{"put", {-27.5, -6.5}, "iron-gear-wheel", 5},

			{"move", {-17, 1.5}, command_finished="walk"},
		},
    },
    {
        name = "automation-15",
        required = {"inserter-built"},
        commands = {
			{"craft", "electronic-circuit", 1},
			{"craft", {{"lab", 1}, {"inserter", 1}}, items_available={"electronic-circuit", 1}, name="craft-lab"},
			{"craft", "electronic-circuit", 5, need_intermediates=true, command_finished="craft-lab"},

			{"move", {-17, 11}, name="pre_visit_iron_walk"},
			{"parallel", visit_iron_burner("automation-15.pre_visit_iron_walk")},

			{"move", {-2, 6}, name="refuel-copper", command_finished="parallel-1.walk-to-iron"},
			{"move", {20, 7}, name="copper-cable-taken", command_finished="refuel-copper"},
			--{"move", {23.5, 11.5}, name="copper-cable-taken", command_finished="refuel-copper"},

			{"put", {-7.5,7.5}, "iron-plate", 30},

			{"take", {22,5}},
			{"take", {24,5}},

			{"build", "inserter", {-12.5, -4.5}, 6, name="inserter-built"},
			{"build", "lab", {-10.5, -4.5}, 0},
			{"build", "small-electric-pole", {-12.5, -3.5}, 0},

			{"move", "inserter-built", command_finished="copper-cable-taken"},
		},
    },
    {
        name = "automation-16",
        required = {"inserter-built"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-6", {-7,17}, area={{-7, -4}, {-1, 16}}, set_on_leaving_range=false, name="Bootstrap-6-top"},
			{"auto-build-blueprint", "Bootstrap-6", {-7,17}, area={{-17, -24}, {-1, 50}}, set_on_leaving_range=false, name="Bootstrap-6-bottom"},

			{"move", {-15,10}, name="pre_visit_iron_walk"},
			{"parallel", visit_iron_burner("automation-16.pre_visit_iron_walk")},

			{"put", {-7.5,7.5}, "iron-plate", 20, name="gears-refilled"},
			{"move", "gears-refilled", command_finished="parallel-1.walk-to-iron", name="walk-1"},

			{"recipe", {-7.5,10.5}, "iron-gear-wheel"},
			{"put", {-7.5,10.5}, "iron-plate", 10},

			{"craft", {{"small-electric-pole", 2}, {"electronic-circuit", 1}}, command_finished="gears-refilled"},
			{"craft", {{"electric-mining-drill", 1}, {"transport-belt", 3}, {"electronic-circuit", 1}, {"electric-mining-drill", 1}}, need_intermediates=true},

			{"entity-interaction", {-3,7}, name="top-furnace"},
			{"entity-interaction", {-3,33}, name="bottom-furnace"},
			{"move", {-4.9,12}, command_finished="walk-1", name="walk-2"},
			{"move", "bp_{-5.5, 43.5}", command_finished="walk-2"},
		},
    },
    {
        name = "automation-17",
        required = {"bp_{-5.5, 43.5}"},
        commands = {
			{"entity-interaction", {-14.5, -4.5}, name="refill-science"},
			{"move", {-5.5, 7}, name="walk-1", command_finished="automation-16.bp_{-4.5, 40.5}"},
			{"move", "refill-science", command_finished="walk-1", name="walk-2"},

			{"put", {-14.5, -4.5}, "iron-gear-wheel", 5},
			{"put", {-14.5, -4.5}, "copper-plate", 5},

			{"put", {-7.5,7.5}, "iron-plate", 20, name="gears-refilled"},
			{"put", {-7.5,10.5}, "iron-plate", 20},

			{"craft", {{"stone-furnace", 3}, {"inserter", 1}, {"small-electric-pole", 1}, {"transport-belt", 4, need_intermediates=true}}},

			{"move", {-4, 10}, command_finished="walk-2", name="walk-3"},
			{"move", {23.5, 11.5, entity=true}, command_finished="automation-16.bp_{-4.5, 4.5}", name="copper-cable-taken"},

			{"craft", {{"electric-mining-drill", 1}, {"transport-belt", 6}}, command_finished="copper-cable-taken"},

			{"move", {-4, 46}, command_finished="copper-cable-taken", name="walk-4"},
			{"move", {-8, 46}, command_finished="walk-4", name="walk-5"},
		},
    },
    {
        name = "automation-18",
        required = {"automation-16.bp_{-14.5, 43.5}"},
        commands = {
			{"stop-command", "automation-17.walk-5"},
			{"simple-sequence", "move", {-5.9, 45.1}, {-5.9, 18}, name="pre_visit_iron_walk"},

			{"parallel", visit_iron_burner("automation-18.pre_visit_iron_walk")},

			{"move", {-4.8, 2}, command_finished="parallel-1.walk-to-iron", name="walk"},

			{"craft", {{"electronic-circuit", 6}, {"inserter", 6, need_intermediates=true},
				{"stone-furnace", 2}, {"assembling-machine-1", 2}, {"iron-chest", 2}}},
		},
    },
    {
        name = "automation-19",
        required = {"automation-16.Bootstrap-6-top"},
        commands = {
			{"move", {-4.8, 31}, command_finished="automation-18.walk", name="walk"},

			{"put", {-7.5,7.5}, "iron-plate", 20},
			{"put", {-7.5,10.5}, "iron-plate", 20},
		},
    },
    {
        name = "automation-20",
        required = {"automation-16.bp_{-4.5, 36.5}"},
        commands = {
			{"tech", "electronics"},
			
			{"stop-command", "automation-19.walk"},
			{"auto-build-blueprint", "Bootstrap-7", {-7,17}, set_on_leaving_range=false, name="Bootstrap-7"},
			{"build", "assembling-machine-1", {-36.5, -7.5}, name="assembler-built"},
			{"recipe", {-36.5, -7.5}, "stone-furnace"},
			{"put", {-36.5, -7.5}, "stone", 50},

			{"craft", {{"inserter", 2}, {"assembling-machine-1", 1}, {"wood", 7}, {"small-electric-pole", 2, need_intermediates=true},
				{"electric-mining-drill", 1, need_intermediates={"electronic-circuit"}}}},

			{"move", {0, -2}},

			{"put", {2.5, -1.5}, "iron-plate", 30},
			{"put", {2.5, -4.5}, "iron-plate", 30},

			{"move", {-7.5, 10.5, entity=true}, command_finished="Bootstrap-7", name="walk-1"},

			{"recipe", {-7.5, 10.5}, "electronic-circuit"},
			{"recipe", {-7.5, 7.5}, "transport-belt"},

			{"put", {-7.5,7.5}, "iron-plate", 10},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 10},

			{"put", {-7.5,10.5}, "copper-cable", 15},
			{"put", {-7.5,10.5}, "iron-plate", 5},
			
			{"put", {-27.5,-6.5}, "copper-plate", 5},
			{"put", {-27.5,-6.5}, "iron-gear-wheel", 5},
			
			{"put", {-14.5,-4.5}, "copper-plate", 3},
			{"put", {-14.5,-4.5}, "iron-gear-wheel", 3},
			
			{"move", {-16, 0}, name="walk-2", command_finished="walk-1"},
			{"move", {-32, -2}, name="walk-3", command_finished="walk-2"},
			{"move", {-8, 6}, command_finished="walk-3", name="walk-4"},
			{"move", {23.5, 11.5, entity=true}, command_finished="walk-4", name="walk-5"},
			
			{"passive-take", "electronic-circuit", "assembling-machine", name="passive-take-circuits-assembler"},
			{"passive-take", "transport-belt", "assembling-machine", name="passive-take-belts-assembler"},
			{"passive-take", "iron-gear-wheel", "container"},
		},
    },
    {
        name = "logistics-1",
        required = {"walk-5"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_belt_1-1", {-7,17}, area={{-16, 20}, {-9, 42}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap-copper-3", {20,6}, set_on_leaving_range=false, name="copper-expanded"},
			
			{"craft", {{"stone-furnace", 6}, {"electric-mining-drill", 1, need_intermediates=true}, {"underground-belt", 1},
				{"assembling-machine-1", 1}, {"burner-mining-drill", 1}, {"inserter", 3}, {"iron-chest", 1}, {"boiler", 1}, {"pipe", 10}}},
			
			{"move", {-7.5, 10.5, entity=true}, name="walk-1"},
			{"move", {5.5, -4.5, entity=true}, name="walk-2", command_finished="walk-1"},
			
			{"parallel", visit_iron_burner("logistics-1.walk-2"), name="visit-iron"},
			
			{"move", {-4.9,18}, name="walk-3", command_finished="visit-iron.walk-to-iron"},
			{"move", {-3,37, entity=true}, name="walk-4", command_finished="walk-3"},
			{"move", "bp_{28, 3}", name="walk-5", command_finished="walk-4"},
			{"move", "bp_{27.5, 11.5}", name="walk-6", command_finished="walk-5"},
			
			{"build", "small-electric-pole", {-9.5, 20.5}},
			
			{"put", {2.5, -1.5}, "iron-plate", 10},
			{"put", {2.5, -4.5}, "iron-plate", 10},
			
			{"put", {-7.5,10.5}, "copper-cable", 45},
			{"put", {-7.5,10.5}, "iron-plate", 15},
			
			{"put", {-7.5,7.5}, "iron-plate", 6},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 6},
		},
    },
    {
        name = "logistics-2",
        required = {"copper-expanded"},
        commands = {
			{"auto-build-blueprint", "Coal_power_connection-1", {-43,-9}, area={{-2, -7}, {7.1, 0}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Coal_belt-1", {4,-1}, area={{-2, -8}, {8, 3}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-44, -16}, {-31, -10}}, set_on_leaving_range=false},
			
			{"move", {5.5, -4.5, entity=true}, name="walk-1"},
			{"move", {2.5, -4.5, entity=true}, name="walk-2", command_finished="walk-1"},
			{"move", {-7.5, 10.5, entity=true}, name="walk-3", command_finished="walk-2"},
			{"move", {-38, -9}, name="walk-4", command_finished="walk-3"},
			--{"move", "bp_{-43, -14.5}", name="walk-4", command_finished="walk-3"},
			
			{"put", {2.5, -1.5}, "iron-plate", 30},
			{"put", {2.5, -4.5}, "iron-plate", 30},
			
			{"put", {-7.5,10.5}, "copper-cable", 42},
			{"put", {-7.5,10.5}, "iron-plate", 14},
			
			{"take", {-36.5, -7.5}},
			{"put", {-36.5, -7.5}, "stone", 50, name="stone-inserted"},
			{"put", {-36.5, -7.5}, "stone", 15, on_relative_tick={130, "stone-inserted"}},
			
			{"craft", {{"steam-engine", 1, need_intermediates=true}, {"steam-engine", 1, need_intermediates={"pipe"}}, {"small-electric-pole", 1}, {"electric-mining-drill", 1}}},
		},
    },
    {
        name = "logistics-3",
        required = {"walk-4"},
        commands = {
			{"parallel", visit_iron_burner(), name="visit-iron"},
			{"simple-sequence", "move", {2, -3}, {18, 10}, {27.5, 11.5, entity=true}, {-3, 37, entity=true},
				{-5.1, 27}, {-3, 3, entity=true}, {-14.5, -4.5, entity=true}, {-27.5, -6.5, entity=true}, name="walk", command_finished="visit-iron.walk-to-iron"},
			
			{"craft", {{"iron-gear-wheel", 4}, {"wood", 6}, {"small-electric-pole", 8, need_intermediates=true},
				{"electric-mining-drill", 3, need_intermediates=true}}},
			
			{"put", {2.5, -1.5}, "iron-plate", 30},
			{"put", {2.5, -4.5}, "iron-plate", 30},
			
			{"put", {-7.5,10.5}, "copper-cable", 45, command_finished="walk.command-3"},
			{"put", {-7.5,10.5}, "iron-plate", 15, command_finished="walk.command-3"},
			
			{"put", {-7.5,7.5}, "iron-plate", 4},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 4},
			
			{"put", {-7.5,7.5}, "iron-plate", 8, command_finished="walk.command-5"},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 8, command_finished="walk.command-5"},
			
			{"put", {-14.5, -4.5}, "copper-plate", 3},
			{"put", {-14.5, -4.5}, "iron-gear-wheel", 3},
			
			{"put", {-27.5, -6.5}, "copper-plate", 3},
			{"put", {-27.5, -6.5}, "iron-gear-wheel", 3},
		},
    },
    {
        name = "logistics-4",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_belt_1-1", {-7,17}, area={{-19, 20}, {-16, 23}}, set_on_leaving_range=false, name="Build"},
			{"auto-build-blueprint", "Furnaces", {-7,17}, set_on_leaving_range=false, command_finished="Build"},
			
			{"simple-sequence", "move", {-17, 10}, {-16.1, 25}, {3.5, 3}, {3.9, 0.9}, {8, 0.9}, {18, 10}, {27.5, 11.5, entity=true},
				 {-3, 37, entity=true}, {-5.1, 27}, {-7.5, 7.5, entity=true}, name="walk"},
			
			{"craft", {{"underground-belt", 1}, {"transport-belt", 1}, {"electric-mining-drill", 1}, {"iron-gear-wheel", 3},
				{"electric-mining-drill", 4, need_intermediates=true}, {"underground-belt", 1}, {"splitter", 1},
				{"electric-mining-drill", 2, need_intermediates=true}}},
			
			{"put", {-10,19}, "iron-ore", 7},
			{"put", {-10,17}, "iron-ore", 7},
			{"put", {-8,17}, "iron-ore", 7},
			{"put", {-22,20}, "iron-ore", 7},
			{"put", {-22,18}, "iron-ore", 7},
			
			{"put", {2.5, -1.5}, "iron-plate", 30},
			{"put", {2.5, -4.5}, "iron-plate", 30},
			
			{"put", {-7.5,10.5}, "copper-cable", 63, command_finished="walk.command-5"},
			{"put", {-7.5,10.5}, "iron-plate", 21, command_finished="walk.command-5"},
			
			{"put", {-7.5,7.5}, "iron-plate", 4, command_finished="walk.command-5"},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 4, command_finished="walk.command-5"},
			
			{"pickup", ticks=120, on_entering_area={{-17, 20}, {-15, 21}}},
		},
    },
    {
        name = "logistics-5",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_belt_1-1", {-7,17}, area={{-21, 19}, {-18, 22}}, set_on_leaving_range=false, name="Build"},
			
			{"simple-sequence", "move", {-7, 16}, {-16, 21}, {-16, 31}, {-20, 14}, name="walk-1"},
			{"parallel", visit_iron_burner("logistics-5.walk-1"), name="visit-iron", command_finished="walk-1"},
			{"simple-sequence", "move", {-7, 14}, {-5.9, 12.9}, {-3, -1, entity=true}, {5.5, -4.5, entity=true}, {-2, -2}, {-27.5, -6.5, entity=true},
				{-36.5, -7.5, entity=true}, {-7.5, 10.5, entity=true}, {-19.9, 17}, name="walk-2", command_finished="visit-iron.walk-to-iron"},
			
			{"craft", {{"iron-gear-wheel", 2}, {"splitter", 1, need_intermediates=true}, {"iron-gear-wheel", 2},
				{"electric-mining-drill", 2, need_intermediates=true}, {"transport-belt", 5}, {"electric-mining-drill", 1, need_intermediates=true}}},
			
			{"put", {-22,20}, "iron-ore", 4},
			{"put", {-22,18}, "iron-ore", 4},
			{"put", {-22,16}, "iron-ore", 4},
			{"put", {-22,14}, "iron-ore", 4},
			{"put", {-22,12}, "iron-ore", 4},
			{"put", {-22,10}, "iron-ore", 4},
			{"put", {-22,8}, "iron-ore", 4},
			
			{"put", {-36.5, -7.5}, "stone", 50},
			{"take", {-36.5, -7.5}, "stone-furnace"},
			
			{"put", {2.5, -1.5}, "iron-plate", 40},
			{"put", {2.5, -4.5}, "iron-plate", 40},
			
			{"put", {-14.5, -4.5}, "copper-plate", 5},
			{"put", {-14.5, -4.5}, "iron-gear-wheel", 5},
			
			{"put", {-27.5, -6.5}, "copper-plate", 5},
			{"put", {-27.5, -6.5}, "iron-gear-wheel", 5},
			
			{"pickup", ticks=240, on_entering_area={{-17, 20}, {-15, 21}}},
		},
    },
    {
        name = "logistics-6",
        required = {"walk-2"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_belt_1-1", {-7,17}, area={{-21, 15}, {-20, 19}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_1-1", {-7,17}, area={{-23, 22}, {-16, 42}}, set_on_leaving_range=false, on_entering_area={{-17, 23}, {-16, 24}}},
			
			{"simple-sequence", "move", {-20, 22}, {-16.2, 37}, {-16.2, 21}, {-7.5,10.5, entity=true}, {3.1, 3}, {5.5,-4.5, entity=true},
				{18, 10}, {22, 10}, {-3, 37, entity=true}, {-5.1, 27}, {-7.5, 7.5, entity=true}, name="walk"},
				
			-- TODO: replace {22, 10} by {27.5, 11.5, entity=true}
			
			{"craft", {{"iron-gear-wheel", 1}, {"electric-mining-drill", 1, need_intermediates=true}, {"underground-belt", 1}, {"stone-furnace", 5}, {"wood", 2},
				{"transport-belt", 2}, {"transport-belt", 7, need_intermediates=true}, {"electric-mining-drill", 2, need_intermediates=true},
				{"underground-belt", 2}}},
			
			{"put", {-22,20}, "iron-ore", 5},
			{"put", {-22,18}, "iron-ore", 5},
			{"put", {-22,16}, "iron-ore", 5},
			{"put", {-22,14}, "iron-ore", 5},
			{"put", {-22,12}, "iron-ore", 5},
			
			{"put", {-10,19}, "iron-ore", 5},
			{"put", {-10,17}, "iron-ore", 5},
			{"put", {-8,17}, "iron-ore", 5},
			
			{"put", {2.5, -1.5}, "iron-plate", 28},
			{"put", {2.5, -4.5}, "iron-plate", 28},
			
			{"put", {-7.5,10.5}, "copper-cable", 90, command_finished="walk.command-5"},
			{"put", {-7.5,10.5}, "iron-plate", 30, command_finished="walk.command-5"},
			
			{"put", {-7.5,7.5}, "iron-plate", 10, command_finished="walk.command-5"},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 10, command_finished="walk.command-5"},
			
			{"pickup", ticks=360},
		},
    },
    {
        name = "logistics-7",
        required = {"walk"},
        commands = {
			{"stop-command", "automation-4.refuel-boilers"},
			{"stop-command", "start-1.auto-refuel"},
			
			{"auto-build-blueprint", "Coal_power_connection-1", {-43,-9}, area={{-7, -7}, {-2, -6}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Coal_belt-1", {4,-1}, area={{-9, -8}, {4, 5}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_1-1", {-7,17}, area={{-21, -4}, {-5, 15}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap-8", {-7,17}, set_on_leaving_range=false},
			--{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-44, -19}, {-31, -16}}, command_finished="walk-1"},
			
			{"build", "boiler", {-43, -17.5}, 2, name="boiler-built"},
			{"build", "steam-engine", {-39.5, -17.5}, 2, command_finished="boiler-built", name="steam-engine-built"},
			{"build", "pipe", {-36.5, -17.5}, command_finished="boiler-built"},
			{"build", "small-electric-pole", {-36.5, -18.5}, command_finished="boiler-built"},
			{"build", "steam-engine", {-33.5, -17.5}, 2, command_finished="steam-engine-built", name="power-finished"},
			
			-- TODO fix on_leaving_range and use auto-build-blueprint instead of the manual build commands
			
			{"put", {-43, -17.5}, "coal", 25},
			
			{"simple-sequence", "move", {-12, 20}, {-20, 20}, {-21, 10}, {-17, 1, entity=true}, {-7, 1, entity=true}, {5.5, -4.5, entity=true},
				{-2,  5}, {-7, -6}, {-36.7, -16}, {-31, -11}, name="walk"},
			
			{"craft", {{"small-electric-pole", 4}, {"electric-mining-drill", 1}, {"boiler", 1}, {"steam-engine", 1, need_intermediates={"iron-gear-wheel"}},
				{"pipe", 6}, {"steam-engine", 1, need_intermediates=true}, {"transport-belt", 2}, {"underground-belt", 1, need_intermediates=true},
				{"electric-mining-drill", 2}}},
				
			{"put", {-36.5, -7.5}, "stone", 50},
			{"take", {-36.5, -7.5}, "stone-furnace"},
			
			{"put", {-22,20}, "iron-ore", 5},
			{"put", {-22,18}, "iron-ore", 5},
			{"put", {-22,16}, "iron-ore", 5},
			{"put", {-22,14}, "iron-ore", 5},
			{"put", {-22,12}, "iron-ore", 5},
			{"put", {-22,10}, "iron-ore", 5},
			{"put", {-22,8}, "iron-ore", 5},
			{"put", {-22,6}, "iron-ore", 5},
			{"put", {-22,4}, "iron-ore", 5},
			
			{"put", {-17,1}, "iron-ore", 5},
			{"put", {-15,1}, "iron-ore", 5},
			{"put", {-13,1}, "iron-ore", 5},
			{"put", {-11,1}, "iron-ore", 5},
			{"put", {-9,1}, "iron-ore", 5},
			{"put", {-7,1}, "iron-ore", 4},
			
			{"put", {-11,3}, "iron-ore", 4},
			{"put", {-9,3}, "iron-ore", 4},
			{"put", {-7,3}, "iron-ore", 4},
			
			{"put", {-9,5}, "iron-ore", 4},
			{"put", {-7,5}, "iron-ore", 4},
			
			{"put", {2.5, -1.5}, "iron-plate", 40},
			{"put", {2.5, -4.5}, "iron-plate", 40},
			
			{"put", {-7.5,7.5}, "iron-plate", 4},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 4},
			
			{"parallel", take_all_coal},
			
			{"pickup", ticks=360, on_entering_area={{-13, 20}, {-12, 21}}},
		},
    },
	
    {
        name = "logistics-8",
        required = {"power-finished"},
        commands = {
			{"auto-build-blueprint", "Bootstrap-8", {-7,17}, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-20, -3}, {-4, -2}, {5.5, -1.5, entity=true}, {-3, 37, entity=true}, {-1, 34}, {-5.1, 29}, {-5.9, 18},
				{-7, 16}, {-12, 20}, {-20, 20}, {-21, 12}, {-21, 9}, {-18, 6}, {-18, 0}, {-7, -1}, {5.5, -4.5, entity=true},
				{1, -3}, {4, -3}, {28, 5, entity=true}, {27.5, 11.5, entity=true}, name="walk"},
			-- TODO walk to "bp_{-4.5, 38.5}" instead
			
			{"craft", {{"underground-belt", 1, need_intermediates=true}, {"inserter", 3}, {"electric-mining-drill", 1}, {"stone-furnace", 5},
				{"iron-gear-wheel", 8}, {"electric-mining-drill", 5, need_intermediates=true}}},
			
			{"put", {2.5, -1.5}, "iron-plate", 20},
			{"put", {2.5, -4.5}, "iron-plate", 20},
				
			{"put", {2.5, -1.5}, "iron-plate", 50, command_finished="walk.command-15"},
			{"put", {2.5, -4.5}, "iron-plate", 50, command_finished="walk.command-15"},
			
			{"put", {-7.5,7.5}, "iron-plate", 5},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 5},
			
			{"put", {-27.5, -6.5}, "copper-plate", 1},
			{"put", {-27.5, -6.5}, "iron-gear-wheel", 1},
			
			{"put", {-22,20}, "iron-ore", 9},
			{"put", {-22,18}, "iron-ore", 9},
			{"put", {-22,16}, "iron-ore", 9},
			{"put", {-22,14}, "iron-ore", 9},
			{"put", {-22,12}, "iron-ore", 9},
			{"put", {-22,10}, "iron-ore", 9},
			{"put", {-22,8}, "iron-ore", 9},
			{"put", {-22,6}, "iron-ore", 9},
			{"put", {-22,4}, "iron-ore", 9},
			
			{"put", {-17,1}, "iron-ore", 9},
			{"put", {-15,1}, "iron-ore", 9},
			{"put", {-13,1}, "iron-ore", 9},
			{"put", {-11,1}, "iron-ore", 9},
			{"put", {-9,1}, "iron-ore", 9},
			{"put", {-7,1}, "iron-ore", 9},
			
			{"put", {-11,3}, "iron-ore", 9},
			{"put", {-9,3}, "iron-ore", 9},
			{"put", {-7,3}, "iron-ore", 9},
			
			{"put", {-9,5}, "iron-ore", 9},
			{"put", {-7,5}, "iron-ore", 9},
			
			{"parallel", take_all_coal},
			
			{"pickup", ticks=360, on_entering_area={{-13, 20}, {-12, 21}}},
		},
    },
	
    {
        name = "logistics-9",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Coal_power_connection-1", {-43,-9}, area={{-18, -7}, {-10, -6}}, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {18, 7}, {-7.5, 10.5, entity=true}, {-13, -2}, {-27.5, -6.5, entity=true}, {-23, 21}, {-23, 32.1}, {-23, 19},
				{-21, 19}, {-21, 9}, {-18, 6}, {-18, 0}, {-7, -1}, name="walk"},
			-- TODO replace {-13, -2} by "bp_{-17.5, -6.5}" and {-23, 32} by "bp_{-17.5, 37.5}"
			
			{"craft", {{"assembling-machine-1", 4}, {"wood", 4}}, command_finished="gears-inserted"},
			
			{"build", "assembling-machine-1", {-22.5, -2.5}},
			{"recipe", {-22.5, -2.5}, "iron-gear-wheel"},
			
			{"put", {-22.5, -2.5}, "iron-plate", 60},
			
			{"put", {-7.5,10.5}, "copper-cable", 90},
			{"put", {-7.5,10.5}, "iron-plate", 30},
			
			{"put", {-7.5,7.5}, "iron-plate", 5},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 5},
			
			{"put", {-27.5, -6.5}, "copper-plate", 2},
			{"put", {-27.5, -6.5}, "iron-gear-wheel", 2, name="gears-inserted"},
			
			{"put", {-14.5, -4.5}, "copper-plate", 2},
			{"put", {-14.5, -4.5}, "iron-gear-wheel", 2},
			
			{"parallel", {
				{"put", {-22,20}, "iron-ore", 9},
				{"put", {-22,18}, "iron-ore", 9},
				{"put", {-22,16}, "iron-ore", 9},
				{"put", {-22,14}, "iron-ore", 9},
				{"put", {-22,12}, "iron-ore", 9},
				{"put", {-22,10}, "iron-ore", 9},
				{"put", {-22,8}, "iron-ore", 9},
				{"put", {-22,6}, "iron-ore", 9},
				{"put", {-22,4}, "iron-ore", 9},
			
				{"put", {-17,1}, "iron-ore", 9},
				{"put", {-15,1}, "iron-ore", 9},
				{"put", {-13,1}, "iron-ore", 9},
				{"put", {-11,1}, "iron-ore", 9},
				{"put", {-9,1}, "iron-ore", 9},
				{"put", {-7,1}, "iron-ore", 9},
			
				{"put", {-11,3}, "iron-ore", 9},
				{"put", {-9,3}, "iron-ore", 9},
				{"put", {-7,3}, "iron-ore", 9},
			
				{"put", {-9,5}, "iron-ore", 9},
				{"put", {-7,5}, "iron-ore", 8},
				}, command_finished="walk.command-5"},
			
			{"pickup", ticks=240, on_entering_area={{-21, 18}, {-20, 19}}},
		},
    },
    {
        name = "logistics-10",
        required = {"walk"},
        commands = {
			{"tech", "automation-2"},
			
			{"auto-build-blueprint", "Coal_power_connection-1", {-43,-9}, area={{-18, -10}, {-17, -7}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Coal_power_connection-1", {-43,-9}, area={{-24, -10}, {-18, -9}}, set_on_leaving_range=false, name="Part-1"},
			{"auto-build-blueprint", "Coal_power_connection-1", {-43,-9}, area={{-46, -10}, {-18, -9}}, set_on_leaving_range=false, command_finished="Part-1"},
			{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-46, -19}, {-44, -10}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Early_science_factory", {-43,-9}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{-7, -4}, {-6, -2}}, set_on_leaving_range=false},
			
			{"rotate", {-17.5, -6.5}, "N"},
			
			{"simple-sequence", "move", {5.5, -4.5, entity=true}, {-7.5, 10.5, entity=true}, {-26, -9.1}, {-7.5, 7.5, entity=true},
				{-42, -9.1}, {-28, -9}, {-28, -19}, {-40, -19}, name="walk"},
			
			{"craft", {{"stone-furnace", 5}, {"assembling-machine-1", 3, need_intermediates=true}, {"underground-belt", 1, need_intermediates=true},
				{"transport-belt", 5}, {"iron-gear-wheel", 2}}},
			{"craft", {{"transport-belt", 5, need_intermediates=true}, {"transport-belt", 2}, {"iron-gear-wheel", 10}}, command_finished="walk.command-4"},
			
			{"put", {2.5, -1.5}, "iron-plate", 20},
			{"put", {2.5, -4.5}, "iron-plate", 20},
			
			{"put", {-7.5,7.5}, "iron-plate", 10},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 10},
			
			{"put", {-36.5, -7.5}, "stone", 50},
			{"take", {-36.5, -7.5}, "stone-furnace"},
			
			{"put", {-27.5, -6.5}, "copper-plate", 2},
			{"put", {-27.5, -6.5}, "iron-gear-wheel", 2},
			
			{"put", {-14.5, -4.5}, "copper-plate", 2},
			{"put", {-14.5, -4.5}, "iron-gear-wheel", 2},
			
			{"put", {-29.5, -11.5}, "copper-plate", 2},
			{"put", {-29.5, -11.5}, "iron-gear-wheel", 2},
			{"put", {-26.5, -11.5}, "copper-plate", 2},
			{"put", {-26.5, -11.5}, "iron-gear-wheel", 2},
			{"put", {-23.5, -11.5}, "copper-plate", 2},
			{"put", {-23.5, -11.5}, "iron-gear-wheel", 2},
			
			{"put", {-29.5, -15.5}, "copper-plate", 2},
			{"put", {-29.5, -15.5}, "iron-gear-wheel", 2},
			{"put", {-26.5, -15.5}, "copper-plate", 2},
			{"put", {-26.5, -15.5}, "iron-gear-wheel", 2},
			{"put", {-23.5, -15.5}, "copper-plate", 2},
			{"put", {-23.5, -15.5}, "iron-gear-wheel", 2},
			
			{"put", {-43, -14.5}, "coal", 2},
			{"put", {-43, -17.5}, "coal", 1},
		},
    },
    {
        name = "electronics-1",
        required = {"walk"},
        commands = {
			{"simple-sequence", "move", {-31, -19}, {-28, -17}, {-28, -10}, {-22, -8}, {-9, -6}, {-7, -4}, {-7, -1}, {-8, 0.3}, {-18, 0},
				{-19, 7}, {-21, 9}, {-21, 12}, {-20, 20}, {-12, 20}, name="walk"},
			
			{"craft", {{"transport-belt", 5}, {"iron-gear-wheel", 15}}},
			
			{"put", {-7.5,7.5}, "iron-plate", 10},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 10},
			
			{"parallel", refill_early_science(1)},
			{"parallel", take_early_science(1)},
			
			{"put", {-31.5, -6.5}, "science-pack-1", 1},
			{"put", {-23.5, -6.5}, "science-pack-1", 2},
			
			{"put", {-18.5, -4.5}, "science-pack-1", 1},
			{"put", {-10.5, -4.5}, "science-pack-1", 2},
			
			{"put", {-22.5, -2.5}, "iron-plate", 40},
			
			{"parallel", insert_equal({
				{-22,20}, {-22,18}, {-22,16}, {-22,14}, {-22,12}, {-22,10}, {-22,8}, {-22,6}, {-22,4},
				{-17,1}, {-15,1}, {-13,1}, {-11,1}, {-9,1}, {-7,1},
				{-11,3}, {-9,3}, {-7,3},
				{-9,5}, {-7,5},
			}, "iron-ore", 200), command_finished="walk.command-5"},
				
			{"parallel", take_all_coal},
			
			{"pickup", ticks=360, on_entering_area={{-8, -5}, {-7, -4}}},
		},
    },
    {
        name = "electronics-2",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{-7, -9}, {-2, -4}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{-3, -11}, {10, -9}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{9, -48}, {16, -11}}, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-7.5, 7.5, entity=true}, {3.3, 6}, {5.5, -4.5, entity=true}, {7, 1}, {18, 10}, {22, 10},
				{-7.5, 7.5, entity=true}, {-2, -4}, {-5, -6.8}, {-14.5, -6.8}, {-17.5, -9.5}, {-27.5, -9.5}, {-22, -10}, {-12, -11},
				{4, -14}, {4, -22}, name="walk"},
				
			-- TODO: replace {22, 10} by {27.5, 11.5, entity=true} and {-27.5, -9.5} by {-29.5, -15.5, entity=true}
			
			{"craft", {{"inserter", 25, need_intermediates=true}, {"stone-furnace", 10}}},
			
			{"put", {-7.5,7.5}, "iron-plate", 10},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 10},
			
			{"put", {-7.5,10.5}, "copper-cable", 15},
			{"put", {-7.5,10.5}, "iron-plate", 5},
			
			{"put", {-7.5,10.5}, "copper-cable", 135, command_finished="walk.command-6"},
			{"put", {-7.5,10.5}, "iron-plate", 45, command_finished="walk.command-6"},
			
			{"put", {2.5, -1.5}, "iron-plate", 50},
			{"put", {2.5, -4.5}, "iron-plate", 50},
			
			{"take", {26, 5}},
			
			{"parallel", refill_early_science(3)},
			{"parallel", take_early_science(2)},
			
			{"put", {-31.5, -6.5}, "science-pack-1", 3},
			{"put", {-23.5, -6.5}, "science-pack-1", 3},
			
			{"put", {-18.5, -4.5}, "science-pack-1", 3},
			{"put", {-10.5, -4.5}, "science-pack-1", 3},
		},
    },
    {
        name = "electronics-3",
        required = {"walk"},
        commands = {
			{"simple-sequence", "move", {5.5, -1.5, entity=true}, {21, 10}, rightmost_cable_chest, bottom_furnace, {-5.3, 27}, belt_assembler, {-5.3, 1},
				{-7, -1}, {-18, -1}, {-29.5, -15.5, entity=true}, {-22, -10}, {2, -8}, {9.1, -14.1}, {9.1, -43}, name="walk"},
				
			{"mine", {7, -26}},
			{"mine", {7.5, -38}},
			{"mine", {7.5, -41.5}},
			
			{"craft", {{"pipe", 20}, {"iron-gear-wheel", 10}, {"transport-belt", 15, need_intermediates=true}, {"wood", 5}}},
			
			{"put", {-7.5,7.5}, "iron-plate", 20},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 20},
			
			{"put", {-7.5,10.5}, "copper-cable", 54},
			{"put", {-7.5,10.5}, "iron-plate", 18},
			
			{"put", {2.5, -1.5}, "iron-plate", 20},
			{"put", {2.5, -4.5}, "iron-plate", 20},
			
			{"put", {2.5, -1.5}, "iron-plate", 100},
			{"put", {2.5, -4.5}, "iron-plate", 100},
			
			{"parallel", take_all_coal},
			
			{"parallel", refill_early_science(3)},
			{"parallel", take_early_science(2)},
			
			{"put", {-31.5, -6.5}, "science-pack-1", 3},
			{"put", {-23.5, -6.5}, "science-pack-1", 3},
			
			{"put", {-18.5, -4.5}, "science-pack-1", 3},
			{"put", {-10.5, -4.5}, "science-pack-1", 3},
			
			{"put", {-22.5,-2.5}, "iron-plate", 40},
			
			{"pickup", ticks=240, on_entering_area={{-7, -1}, {-6, 0}}},
			{"pickup", ticks=240, command_finished="walk.command-9"},
		},
    },
    {
        name = "electronics-4",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{15, -70}, {30, -48}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_power_connection", {29,-98}, set_on_leaving_range=false},
		
			{"simple-sequence", "move", {8.9, -11}, bottom_gear_chest, {-4, 3}, circuit_assembler, {-22, -9.1}, {-31.5, -6.5, entity=true},
				{-29.5, -15.5, entity=true}, {-15, -8.9}, {-2, -27}, {0, -44}, {11, -52}, {12, -63}, {26, -64}, name="walk"},
			
			{"craft", {{"transport-belt", 15}, {"underground-belt", 1}, {"splitter", 2}, {"small-electric-pole", 9, need_intermediates={"wood"}},
				{"small-electric-pole", 3}}},
			
			{"put", {2.5, -1.5}, "iron-plate", 20},
			{"put", {2.5, -4.5}, "iron-plate", 20},
			
			{"parallel", refill_belt_assembler(20)},
			
			{"parallel", refill_early_science(1)},
			{"parallel", take_early_science(2)},
			
			{"put", {-31.5, -6.5}, "science-pack-1", 3},
			{"put", {-23.5, -6.5}, "science-pack-1", 3},
			
			{"put", {-18.5, -4.5}, "science-pack-1", 3},
			{"put", {-10.5, -4.5}, "science-pack-1", 3},
			
			{"put", {-22.5,-2.5}, "iron-plate", 40},
			
			{"parallel", {
				{"put", {-17,1}, "iron-ore", 10},
				{"put", {-15,1}, "iron-ore", 10},
				{"put", {-13,1}, "iron-ore", 10},
				{"put", {-11,1}, "iron-ore", 10},
				{"put", {-9,1}, "iron-ore", 10},
				{"put", {-7,1}, "iron-ore", 10},
			
				{"put", {-11,3}, "iron-ore", 10},
				{"put", {-9,3}, "iron-ore", 10},
				{"put", {-7,3}, "iron-ore", 10},
			
				{"put", {-9,5}, "iron-ore", 10},
				{"put", {-7,5}, "iron-ore", 10},
				}},
			
			{"pickup", ticks=240},
		},
    },
    {
        name = "electronics-5",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{15, -70}, {30, -48}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{29, -102}, {30, -70}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_1-furnaces-1", {29,-98}},
		
			{"simple-sequence", "move", {-25, -10}, {-15, -8.9}, circuit_assembler, top_gear_chest, {9.5, -14}, {9.5, -46}, {15.5, -52.5},
				{15.5, -65.5}, {19.5, -69.5}, {25.5, -69.5}, {27, -94}, {33.8, -96}, {33.8, -51}, name="walk"},
			
			{"craft", "inserter", 21},
			{"craft", "transport-belt", 34, need_intermediates=true, command_finished="walk.command-4"},
			
			{"put", {-7.5,7.5}, "iron-plate", 18},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 18},
			
			{"put", {2.5, -1.5}, "iron-plate", 50},
			{"put", {2.5, -4.5}, "iron-plate", 50},
			
			{"mine", {32.5, -55}},
			
			{"parallel", take_early_science(2)},
			
			{"put", {-31.5, -6.5}, "science-pack-1", 3},
			{"put", {-23.5, -6.5}, "science-pack-1", 3},
			
			{"put", {-18.5, -4.5}, "science-pack-1", 3},
			{"put", {-10.5, -4.5}, "science-pack-1", 3},
			
			{"take", {-12, 11}},
			{"take", {-10, 11}},
			
			{"parallel", {
				{"put", {-17,1}, "iron-ore", 30},
				{"put", {-15,1}, "iron-ore", 30},
				{"put", {-13,1}, "iron-ore", 30},
				{"put", {-11,1}, "iron-ore", 30},
				{"put", {-9,1}, "iron-ore", 30},
				{"put", {-7,1}, "iron-ore", 30},
			
				{"put", {-11,3}, "iron-ore", 30},
				{"put", {-9,3}, "iron-ore", 30},
				{"put", {-7,3}, "iron-ore", 30},
			
				{"put", {-9,5}, "iron-ore", 30},
				{"put", {-7,5}, "iron-ore", 30},
				}},
		},
    },
    {
        name = "electronics-6",
        required = {"walk"},
        commands = {
			{"tech", "steel-processing"},
			
			{"auto-build-blueprint", "Furnace-assembler-1", {-43,-9}, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-25, -9.9}, "bp_{-38.5, -5.5}", "bp_{-34.5, -2.5}", {-22, -8}, {-6, 6}, {-4, 8}, {-2, 8}, {18, 10}, rightmost_cable_chest,
				bottom_furnace, {-5.3, 27}, belt_assembler, {3.5, 6}, top_gear_chest, name="walk"},
			
			{"craft", {{"inserter", 3}, {"fast-inserter", 3, need_intermediates=true}, {"iron-chest", 1}, {"inserter", 1}, {"electric-mining-drill", 3},
				{"wood", 5}, {"assembling-machine-1", 2}, {"electric-mining-drill", 2, need_intermediates=true}, {"assembling-machine-2", 2}}},
			
			{"parallel", take_early_science(1)},
			
			{"mine", {-23.5, -11.5}},
			
			{"put", {-31.5, -6.5}, "science-pack-1", 1},
			{"put", {-23.5, -6.5}, "science-pack-1", 2},
			
			{"put", {-18.5, -4.5}, "science-pack-1", 1},
			{"put", {-10.5, -4.5}, "science-pack-1", 2},
			
			{"put", {-7.5,10.5}, "copper-cable", 90},
			{"put", {-7.5,10.5}, "iron-plate", 30},
			
			{"put", {2.5, -1.5}, "iron-plate", 100},
			{"put", {2.5, -4.5}, "iron-plate", 100},
			
			{"put", stone_furnace_assembler, "stone", 30},
			{"take", stone_furnace_assembler},
		},
    },
    {
        name = "automation-2-1",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_initial", {-10,-35}, area={{-12, -28}, {-2, -22}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_belts", {37,-28}, area={{25, -30}, {36, 0}}, set_on_leaving_range=false, name="Bootstrap_copper_belts"},
			{"auto-build-blueprint", "Bootstrap_copper_belts", {37,-28}, area={{36, -30}, {50, -28.9}}, set_on_leaving_range=false},
			
			{"build", "assembling-machine-1", {-3.5, -20.5}},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "copper-cable", 55)},
			
			{"simple-sequence", "move", {3, 6}, {-16, 14}, {-20, 14}, {-21, 12}, {28, 3, entity=true}, {-5, -22}, {-8, 0},
				circuit_assembler, {1, -3}, {27, -3}, {33.1, -9}, {33.1, -18}, name="walk-1"},
			{"simple-sequence", "mine", {37.5, -18.5}, {32.5, -22.5}, {37, -23.5}, pass_arguments = {[3] = "tree"}, command_finished="walk-1", name="mine-trees"},
			{"simple-sequence", "move", {37, -21}, {37, -25}, {44, -25}, {37, -13}, {37, -9}, {27, 6}, name="walk-2", command_finished="mine-trees"},
			
			{"parallel", take_all_coal},
			
			{"craft", {{"electronic-circuit", 10}, {"electric-mining-drill", 3, need_intermediates=true}, {"underground-belt", 3, need_intermediates=true},
				{"small-electric-pole", 3}, {"electric-mining-drill", 7, need_intermediates=true}, {"transport-belt", 15}}},
			
			{"put", {-7.5,7.5}, "iron-plate", 30},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 30},
			
			{"put", {-3.5, -24.5}, "copper-cable", 144},
			{"put", {-3.5, -24.5}, "iron-plate", 48},
			
			{"put", {-9.5, -25.5}, "iron-plate", 100},
			
			{"put", {2.5, -1.5}, "iron-plate", 40, command_finished="walk-1.command-8"},
			{"put", {2.5, -4.5}, "iron-plate", 40, command_finished="walk-1.command-8"},
			
			{"passive-take", "copper-plate", "furnace", name="passive-take-copper"},
		},
    },
    {
        name = "automation-2-2",
        required = {"walk-2"},
        commands = {
			{"auto-build-blueprint", "Bootstrap_initial", {-10,-35}, area={{-18, -23}, {-15, -19}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_transport", {57,-111}, area={{50, -42}, {56, -29}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_transport", {57,-111}, area={{56, -115}, {59, -41}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_belts-furnaces-1", {57,-111}, area={{60, -115}, {69, -87.9}}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Iron-copper_power_connection", {57,-111}, set_on_leaving_range=false},
			
			{"build", "transport-belt", {59.5, -114.5}, 2},
			{"rotate", {58.5, -114.5}, "E"},
			
			{"simple-sequence", "move", {18, 7}, circuit_assembler, {-1, 0}, top_gear_chest, {-3.5, -24.5, entity=true}, {-11, -22}, 
				stone_furnace_chest_entity, {-23, -8.9}, {-20, 7}, {-16, 14}, {-16, 13}, {-13, 8}, {-12, 2}, {-16.5, -20.5, entity=true},
				{-3.5, -24.5, entity=true}, {20, -19}, {53.5, -29.5}, {55.5, -39.5}, {58.5, -42.5}, {58.5, -91.5}, {46, -100}, {54, -106},
				{57, -109}, {63.1, -109}, {63.1, -88}, name="walk"},
			
			{"craft", {{"assembling-machine-1", 1, need_intermediates=true}, {"assembling-machine-2", 1, need_intermediates=true},
				{"small-electric-pole", 1}, {"splitter", 3, need_intermediates=true}, {"small-electric-pole", 5}, {"transport-belt", 20}}},
			{"craft", {{"inserter", 9, need_intermediates=true}, {"transport-belt", 20, need_intermediates=true}}, command_finished="circuits_inserted"},
				
			{"put", {-7.5,7.5}, "iron-plate", 23},
			{"put", {-7.5,7.5}, "iron-gear-wheel", 23},
			
			{"put", {-9.5, -25.5}, "iron-plate", 80},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 35)},
			
			{"put", {-16.5, -20.5}, "iron-plate", 13},
			{"put", {-16.5, -20.5}, "iron-gear-wheel", 13},
			{"put", {-16.5, -20.5}, "electronic-circuit", 13, name="circuits_inserted"},
			
			{"put", stone_furnace_assembler, "stone", 50},
			{"take", stone_furnace_chest},
			
			{"parallel", take_all_coal},
			
			{"take", {-16.5, -20.5}, command_finished="walk.command-10", name="inserters-taken"},
			{"parallel", change_recipe_and_insert({-16.5, -20.5}, "pipe", 9), command_finished="inserters-taken"},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 11), command_finished="inserters-taken"},
			
			{"put", {-9.5, -25.5}, "iron-plate", 30, command_finished="walk.command-10"},
			
			{"mine", {57.5, -60}},
			
			{"pickup", ticks=240, on_entering_area={{32, -30}, {33, -29}}},
			
			{"parallel", {
				{"put", {61,-108}, "copper-ore", 5},
				{"put", {61,-106}, "copper-ore", 5},
				{"put", {61,-104}, "copper-ore", 5},
				{"put", {61,-102}, "copper-ore", 5},
				{"put", {61,-100}, "copper-ore", 5},
				{"put", {61,-98}, "copper-ore", 6},
				{"put", {61,-96}, "copper-ore", 6},
				{"put", {61,-94}, "copper-ore", 6},
				{"put", {61,-92}, "copper-ore", 6},
				{"put", {61,-90}, "copper-ore", 6},
				{"put", {61,-88}, "copper-ore", 6},
				
				{"put", {68,-108}, "copper-ore", 5},
				{"put", {68,-106}, "copper-ore", 5},
				{"put", {68,-104}, "copper-ore", 5},
				{"put", {68,-102}, "copper-ore", 5},
				{"put", {68,-100}, "copper-ore", 5},
				{"put", {68,-98}, "copper-ore", 5},
				{"put", {68,-96}, "copper-ore", 5},
				{"put", {68,-94}, "copper-ore", 5},
				{"put", {68,-92}, "copper-ore", 5},
				{"put", {68,-90}, "copper-ore", 5},
				{"put", {68,-88}, "copper-ore", 5},
				}},
				
			{"take", {61,-98}, "copper-plate", 1},
			{"take", {61,-96}, "copper-plate", 1},
			{"take", {61,-94}, "copper-plate", 1},
			{"take", {61,-92}, "copper-plate", 2},
			{"take", {61,-90}, "copper-plate", 2},
			{"take", {61,-88}, "copper-plate", 2},
		},
    },
    {
        name = "automation-2-3",
        required = {"walk"},
        commands = {
			{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-46, -25}, {-31, -19}}, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-9.5, -25.5, entity=true}, {-11, -27}, {-43, -25}, name="walk"},
			
			{"craft", {{"inserter", 2}, {"wood", 6}, {"iron-gear-wheel", 4}, {"small-electric-pole", 5, need_intermediates={"wood"}}, {"boiler", 2},
				{"steam-engine", 4, need_intermediates=true}, {"electric-mining-drill", 4, need_intermediates=true}}},
				
			{"put", {-9.5, -25.5}, "iron-plate", 100},
			
			{"take", {-16.5, -20.5}, name="pipes-taken"},
			{"recipe", {-16.5, -20.5}, "copper-cable", command_finished="pipes-taken", name="recipe-changed-1"},
			{"put", {-16.5, -20.5}, "copper-plate", 9, command_finished="recipe-changed-1"},
			
			{"parallel", change_recipe_and_insert({-3.5, -24.5}, "transport-belt", 6), items_available={"electronic-circuit", 30}},
		},
    },
	{
		name = "automation-2-4",
		required = {"walk"},
		commands = {
			{"simple-sequence", "move", {-12, -25}, {24, 7}, {-3.5, -24.5, entity=true}, {-8, 6}, {-9, 9}, {-9, 7}, {-8, -2}, {-16.5, -20.5, entity=true},
				{-3.5, -24.5, entity=true}, name="walk"},
			
			{"parallel", take_all_coal},
			{"craft", {{"splitter", 1, need_intermediates=true}, {"transport-belt", 9, need_intermediates=true}, {"underground-belt", 3, need_intermediates=true},
				{"small-electric-pole", 3, need_intermediates=true}, {"transport-belt", 4}, {"electric-mining-drill", 6, need_intermediates=true}},
				on_entering_area={{-6, -19}, {0, -13}}},
			
			{"parallel", change_recipe_and_insert({-3.5, -24.5}, "electronic-circuit", 16), name="circuits-started"},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "wood", 10)},
			{"parallel", change_recipe_and_insert({-16.5, -20.5}, "electric-mining-drill", 5), command_finished="circuits-started"},
			{"take", {-16.5, -20.5}, "electric-mining-drill", 5},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 50)},
			
			{"put", {2.5, -4.5}, "iron-plate", 80},
			{"put", {2.5, -1.5}, "iron-plate", 80},
			
			{"put", {-7.5, 7.5}, "iron-plate", 2},
			{"put", {-7.5, 7.5}, "iron-gear-wheel", 2},
			
			{"take", {-3.5, -20.5}, "wood", 20, name="wood-taken", priority=7},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "copper-cable", 26), command_finished="wood-taken"},
		}
	},
	{
		name = "automation-2-5",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_iron_coal-1", {-11, -90}, record_order=false, show_ghosts=true},
			{"auto-build-blueprint", "Bootstrap_iron_coal-1-power_connection", {-11, -90}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_coal-1-furnace_connection", {29,-98}, set_on_leaving_range=false, show_ghosts=true},
			
			{"simple-sequence", "move", {-5, -73}, {-10.5, -96}, {-16.5, -94}, {-8, -122}, {33.9, -89.9}, {35.9, -57}, {37, -56},
				{58.5, -75.5}, {58.5, -83.5}, {62, -87}, {62, -105}, {30, -103}, {22, -111}, {22, -122}, {3, -122}, name="walk"},
			
			{"craft", {{"underground-belt", 2}, {"transport-belt", 36}}},
			{"craft", {{"splitter", 1}, {"underground-belt", 7}, {"assembling-machine-1", 2}}, command_finished="walk.command-6"},
			
			{"put", {-9.5, -25.5}, "iron-plate", 80},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 10)},
		}
	},
	{
		name = "automation-2-6",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_initial", {-10,-35}, set_on_leaving_range=false, show_ghosts=true},
			{"auto-build-blueprint", "Bootstrap_extension-1", {-10,-35}, show_ghosts=true, set_on_leaving_range=false},
			
			{"build", "assembling-machine-2", {-3.5, -20.5}},
			{"build", "assembling-machine-2", {-9.5, -28.5}},
			
			{"simple-sequence", "move", {-6, -32}, {-3, -27}, rightmost_cable_chest, {17, 6}, {-11, -24}, {-11, -25}, name="walk"},
			
			{"craft", {{"small-electric-pole", 1}, {"assembling-machine-1", 5}, {"small-electric-pole", 2, need_intermediates=true}}},
			{"craft", {{"small-electric-pole", 2, need_intermediates=true}, {"assembling-machine-2", 2, need_intermediates={"assembling-machine-1"}},
				{"assembling-machine-2", 1}, {"fast-inserter", 2}, {"iron-chest", 1}}, on_entering_area={{10, -16}, {15, -11}}},
			{"craft", {{"assembling-machine-2", 1}, {"assembling-machine-2", 1, need_intermediates=true}, {"stone-furnace", 2},
				{"underground-belt", 5, need_intermediates=true}}, items_available={"fast-inserter", 2}},
			
			{"parallel", insert_recipe({-9.5, -31.5}, "transport-belt", 26)},
			{"parallel", insert_recipe({-9.5, -28.5}, "iron-gear-wheel", 50)},
			
			{"put", {-9.5, -25.5}, "iron-plate", 100},
			
			{"put", {-0.5, -25.5}, "copper-plate", 70},
			{"put", {-0.5, -22.5}, "copper-plate", 70},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 10)},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "iron-gear-wheel", 8)},
			{"parallel", insert_recipe({-0.5, -19.5}, "iron-gear-wheel", 50)},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 25)},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "electronic-circuit", 25), items_available={"copper-cable", 150}},
			
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 4)},
			{"parallel", insert_recipe({-9.5, -19.5}, "transport-belt", 30)},
			
			{"put", {-16.5, -24.5}, "iron-plate", 28},
			{"put", {-16.5, -24.5}, "iron-gear-wheel", 28},
			
			{"parallel", change_recipe_and_insert({-16.5, -20.5}, "inserter", 28)},
		}
	},
	{
		name = "automation-2-7",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Coal_belt-1", {4,-1}, area={{-2, 2}, {8, 11}}, set_on_leaving_range=false},
			{"build", "small-electric-pole", {-1.5, 9.5}},
			
			{"craft", {{"small-electric-pole", 3}, {"stone-furnace", 5}, {"underground-belt", 7, need_intermediates=true}}},
			{"craft", {{"inserter", 3, need_intermediates=true}, {"stone-furnace", 10}, {"inserter", 5}, {"inserter", 5, need_intermediates=true},
				{"long-handed-inserter", 13, need_intermediates=true}, {"iron-gear-wheel", 20}}, command_finished="walk.command-11"},
			
			{"simple-sequence", "move", {-12, 8}, {-13, 12}, {-16, 14}, {-21, -4}, {-28, -4.9}, {-26, -5}, {-25, -8}, {-10, -23}, {-11, -24},
				{0.5, -25.5, entity=true}, {-2, -22}, {-1, -18}, {8, 6}, {18, 10}, rightmost_cable_chest, {-3, 37, entity=true}, {-2, 28},
				{-4, 28}, {-5.5, -2}, {-6.1, -8}, name="walk"},
			
			{"parallel", take_all_coal},
			{"take", {-33.5, -7.5}},
			
			{"take", {-16.5, -28.5}},
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 4), command_finished="walk.command-2"},
			{"parallel", insert_recipe({-16.5, -20.5}, "inserter", 5), command_finished="walk.command-2"},
			{"put", {-16.5, -24.5}, "iron-plate", 5, command_finished="walk.command-2"},
			{"put", {-16.5, -24.5}, "iron-gear-wheel", 5, command_finished="walk.command-2"},
			
			{"parallel", insert_recipe({-9.5, -28.5}, "iron-gear-wheel", 25)},
			{"parallel", insert_recipe({-9.5, -25.5}, "iron-gear-wheel", 25)},
			
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 18)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 18)},
			
			{"parallel", insert_recipe({-9.5, -19.5}, "transport-belt", 20), command_finished="walk.command-10"},
		}
	},
	{
		name = "automation-2-8",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_iron_transport-2", {-10,-35}, area={{-5, -47}, {12, -34}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport-2", {-10,-35}, area={{11, -47}, {35, -46}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_1-furnaces-2", {29,-98}, show_ghosts=true, set_on_leaving_range=false},
			
			{"craft", {{"assembling-machine-1", 3, need_intermediates={"iron-gear-wheel"}}, {"iron-gear-wheel", 6},
				{"assembling-machine-2", 3, need_intermediates=true}, {"stone-furnace", 3}}, command_finished="walk.command-6"},
			
			{"simple-sequence", "move", {-6, -22}, {-11, -24}, {-8, -24}, {32, -50}, {32, -91}, {33, -91}, {36, -90},
				{58, -90}, {62, -91}, {62, -105}, {60, -105}, {39, -84}, {37, -84}, {33.1, -51}, {32, -46.9}, {13, -46.1}, {11.9, -45},
				{11.1, -35}, name="walk"},
			
			{"take", {-13.5, -24.5}},
			
			{"parallel", insert_recipe({0.5, -19.5}, "iron-gear-wheel", 16)},
			{"parallel", insert_recipe({-9.5, -25.5}, "iron-gear-wheel", 40)},
			{"parallel", insert_recipe({-9.5, -28.5}, "iron-gear-wheel", 40)},
			{"parallel", change_recipe_and_insert({-9.5, -31.5}, "iron-gear-wheel", 50)},
			
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 20)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 20)},
			
			{"parallel", insert_recipe({-9.5, -19.5}, "transport-belt", 10)},
			
			{"parallel", change_recipe_and_insert({-16.5, -20.5}, "iron-gear-wheel", 50)},
			
			{"parallel", change_recipe_and_insert({-16.5, -24.5}, "pipe", 54)},
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 5)},
			
			{"pickup", ticks=170, on_entering_area={{31, -48}, {33, -46}}, command_finished="walk.command-10"},
		}
	},
	{
		name = "automation-2-9",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_extension-2", {-10,-35}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"build", "assembling-machine-2", {0.5, -19.5}},
			{"build", "assembling-machine-2", {0.5, -22.5}},
			{"build", "assembling-machine-2", {0.5, -25.5}},
			{"build", "assembling-machine-2", {-9.5, -31.5}, command_finished="walk.command-2"},
			
			{"rotate", {-6.5, -26.5}, "S"},
			
			{"simple-sequence", "move", {-3, -34.1}, {-5, -24}, {-11, -24}, {-11, -33}, {-6.9, -39}, {-7, -34}, {-6.5, -22}, name="walk"},
			
			{"craft", {{"assembling-machine-2", 5, need_intermediates=true}, {"steam-engine", 4, need_intermediates=true}, {"boiler", 4},
				{"steam-engine", 3, need_intermediates=true}, {"inserter", 4}, {"pipe", 3}, {"steam-engine", 1, need_intermediates=true}}},
			
			{"parallel", insert_recipe({-9.5, -36.5}, "electric-mining-drill", 5)},
			{"parallel", insert_recipe({-9.5, -39.5}, "electric-mining-drill", 5)},
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 5)},
			
			{"parallel", insert_recipe({-9.5, -25.5}, "iron-gear-wheel", 40)},
			{"parallel", insert_recipe({-9.5, -28.5}, "iron-gear-wheel", 40)},
			{"parallel", insert_recipe({-9.5, -31.5}, "iron-gear-wheel", 25)},
			
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 13)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 13)},
			{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 13)},
			
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 60)},
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 60)},
			{"parallel", change_recipe_and_insert({0.5, -19.5}, "copper-cable", 70)},
			{"parallel", insert_recipe({-3.5, -40.5}, "copper-cable", 90)},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-9.5, -19.5}, "pipe", 1)},
				{"take", {-9.5, -19.5}},
				{"parallel", change_recipe_and_insert({-9.5, -19.5}, "transport-belt", 30)},
			}},
			
			{"parallel", insert_recipe({-16.5, -20.5}, "iron-gear-wheel", 15)},
			
			{"take", {-13.5, -24.5}},
		}
	},
	{
		name = "automation-2-10",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-46, -37}, {-31, -25}}, name="expansion", set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-11, -24}, {-18, -27}, {-42.5, -31}, {-23, -28.1}, name="walk"},
			
			{"craft", {{"electric-mining-drill", 2}}, command_finished="expansion"},
			
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 8)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 8)},
			
			{"sequence", {
				{"take", {-13.5, -24.5}},
				{"rotate", {-14.5, -24.5}, "N"},
				{"rotate", {-15.5, -22.5}, "E"},
				{"take", {-16.5, -24.5}, "pipe", 3},
				{"parallel", change_recipe_and_insert({-16.5, -24.5}, "transport-belt", 12)},
			}},
		}
	},
	{
		name = "automation-2-11",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_belt_2", {-27,-81}, area={{-41, -77}, {-13, -71}}, on_entering_area={{-20, -77}, {-17, -74}}, set_on_leaving_range=false, name="bottom"},
			{"auto-build-blueprint", "Bootstrap_belt_2", {-27,-81}, area={{-41, -80}, {-12, -77}}, record_order=false, set_on_leaving_range=false, name="center"},
			{"auto-build-blueprint", "Bootstrap_belt_2", {-27,-81}, area={{-41, -91}, {-12, -80}}, record_order=false, set_on_leaving_range=false, name="top"},
			
			{"auto-build-blueprint", "Bootstrap_iron_transport-3", {-23,-128}, area={{-25, -129}, {-24, -91}}, show_ghosts=true, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-6, -23}, {-11, -24}, {-11, -33}, {-8, -35}, {-6.1, -39}, {-5, -42}, {-2, -43}, {-1.7, -46}, {-18, -76},
				{-35, -78}, {-37.1, -87.1}, {-30.9, -87.1}, {-26, -86.1}, {-24, -89}, {-24.1, -97.1}, name="walk"},
			
			{"mine", {1.5, -46.5}},
			
			{"craft", {{"splitter", 2}, {"underground-belt", 6}, {"small-electric-pole", 1}, {"transport-belt", 4}, {"iron-chest", 4}, {"small-electric-pole", 3}}},
			
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 10)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 10)},
			{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 20)},
			
			{"parallel", insert_recipe({-9.5, -19.5}, "transport-belt", 10)},
			
			{"parallel", insert_recipe({-9.5, -31.5}, "iron-gear-wheel", 16)},
			{"parallel", insert_recipe({-9.5, -28.5}, "iron-gear-wheel", 16)},
			{"parallel", insert_recipe({-9.5, -25.5}, "iron-gear-wheel", 21)},
			
			{"parallel", insert_recipe({-16.5, -20.5}, "iron-gear-wheel", 40)},
			{"parallel", insert_recipe_except({-16.5, -24.5}, "transport-belt", 40, "iron-gear-wheel")},
			{"rotate", {-15.5, -22.5}, "S"},
			{"rotate", {-14.5, -24.5}, "W"},
			
			{"take", {-13.5, -24.5}, "transport-belt", 2},
			
			{"sequence", {
				{"take", {-16.5, -28.5}, "electric-mining-drill", 14},
				--{"parallel", change_recipe_and_insert({-16.5, -28.5}, "iron-gear-wheel", 50)},
				-- I don't have enough iron-plate, so this assembler just idles for now :D
			}},
			
			{"sequence", {
				{"take", {-9.5, -39.5}, "electric-mining-drill", 5},
				{"parallel", change_recipe_and_insert({-9.5, -39.5}, "inserter", 35)},
			}},
			
			{"sequence", {
				{"take", {-9.5, -36.5}, "electric-mining-drill", 5},
				{"parallel", change_recipe_and_insert({-9.5, -36.5}, "iron-gear-wheel", 39)},
			}},
		}
	},
	{
		name = "automation-2-12",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_iron_transport-3", {-23,-128}, area={{-24, -129}, {-5, -128}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_2-furnaces-1", {-2,-124}, show_ghosts=true, set_on_leaving_range=false, command_finished="walk.command-9"},
			
			{"auto-build-blueprint", "Bootstrap_extension-3", {-10,-35}, record_order=false, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-23.2, -86.9}, {-12.9, -80.1}, {-7, -34}, {-6.1, -23}, {-11, -24}, {-11, -41}, {-9, -46}, {-12.9, -80.1},
				{-23.1, -86.8}, {-23.9, -91}, {-24.1, -127}, {-8, -128.1}, {-6.1, -75}, name="walk"},
			
			{"take", {-9.5, -39.5}},
			{"take", {-13.5, -24.5}},
			
			{"craft", {{"transport-belt", 2}, {"stone-furnace", 2}, {"fast-inserter", 2}, {"fast-inserter", 10, need_intermediates=true},
				{"splitter", 3, need_intermediates=true}, {"transport-belt", 30}}},
			
			{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 19)},
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 32)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 31)},
			{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 17), command_finished="walk.command-7"},
			
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 40)},
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 40)},
			{"parallel", insert_recipe({0.5, -19.5}, "copper-cable", 40)},
			
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "stone-furnace", 10)},
			
			{"parallel", change_recipe_and_insert({-16.5, -28.5}, "transport-belt", 50)},
			
			{"sequence", {
				{"parallel", insert_recipe({-9.5, -39.5}, "inserter", 6)},
				{"take", {-9.5, -39.5}},
			}},
			
			{"rotate", {-24.5, -128.5}, "E"},
			
			{"mine", {-7.5, -125.5}},
			{"rotate", {-6.5, -125.5}, "N"},
			
			{"pickup", ticks=120, on_entering_area={{-8, -40}, {-6, -38}}},
			{"pickup", ticks=120, command_finished="walk.command-9"},
			
			{"stop-command", "copper-3.refuel-furnaces"},
			
			{"parallel", insert_equal(generate_points({-9, -90}, {-9, -76}, 2), "iron-ore", 61)},
			{"parallel", insert_equal(generate_points({-9, -90}, {-9, -76}, 2), "coal", 8)},
			{"parallel", insert_equal(generate_points({-2, -92}, {-2, -76}, 2), "iron-ore", 73)},
			{"parallel", insert_equal(generate_points({-2, -92}, {-2, -76}, 2), "coal", 9)},
		}
	},
	{
		name = "automation-2-13",
		required = {"walk"},
		commands = {
			{"simple-sequence", "move", {-7.1, -34}, {-6.1, -25}, {-5, -19}, {17, 6}, {18, 10}, rightmost_cable_chest, bottom_furnace, {-2, 28},
				{-4, 28}, {-5.8, 17}, {-7, 16}, {-11, 16}, {-12, 14}, {-16, 14}, {-16, 11}, {-15, 11}, {-15, 10}, {-14, 0}, {-12, -7},
				{-6.1, -22}, {-11, -24}, {-11, -41}, {-2, -52}, {39, -84}, {62, -91}, {62, -105}, {30, -94}, {-3, -93}, {-4.9, -75}, name="walk"},
				
			{"sequence", {
				{"craft", "inserter", 6},
				{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 20)},
				{"parallel", insert_recipe({-9.5, -39.5}, "inserter", 29)},
				{"craft", "transport-belt", 19},
			}},
			
			{"parallel", insert_recipe({-3.5, -40.5}, "copper-cable", 10)},
			
			{"sequence", {
				{"take", {-9.5, -19.5}},
				{"parallel", change_recipe_and_insert({-9.5, -19.5}, "transport-belt", 10)},
			}},
			
			{"craft", {{"inserter", 11}, {"stone-furnace", 16}}, command_finished="walk.command-6"},
			{"craft", {{"underground-belt", 6, need_intermediates=true}, {"small-electric-pole", 4},
				{"splitter", 4}, {"copper-cable", 12}}, command_finished="walk.command-23"},
			
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 23)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 23)},
			
			{"pickup", ticks=120, on_entering_area={{-8, -41}, {-6, -39}}},
			
			{"take", {-13.5, -24.5}},
			
			{"take", {-9.5, -36.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -31.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -28.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -25.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			
			{"parallel", take_all_coal},
			
			{"auto-refuel", min=1, target=2, type="furnace", name="refuel-furnaces", command_finished="walk.command-6"},
			
			{"parallel", {
				{"sequence", {
					{"take", {-9.5, -19.5}},
					{"parallel", change_recipe_and_insert({-9.5, -19.5}, "electric-mining-drill", 10)},
				}},
				{"sequence", {
					{"take", {-9.5, -39.5}},
					{"parallel", change_recipe_and_insert({-9.5, -39.5}, "electric-mining-drill", 5)},
					{"parallel", insert_recipe({-9.5, -39.5}, "electric-mining-drill", 5)},
				}},
				{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 40)},
				{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 40)},
				{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 40)},
				{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 11)},
				
				{"parallel", change_recipe_and_insert({-16.5, -28.5}, "inserter", 50)},
				
				{"parallel", change_recipe_and_insert({-16.5, -20.5}, "transport-belt", 50)},
				
				{"take", {-9.5, -36.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
				{"take", {-9.5, -31.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
				{"take", {-9.5, -28.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
				{"take", {-9.5, -25.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
				
				{"pickup", ticks=208, on_entering_area={{34, -47}, {36, -45}}},
				
				{"mine", {-1, -51.5}},
				{"mine", {0.5, -50.5}},
			}, command_finished="walk.command-6"},
		}
	},
	{
		name = "automation-2-14",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_belt_3", {-27,-81}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport-3", {-23,-128}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_3-furnaces-1", {-2,-124}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-2, -46}, {0, -36}, {1.9, -31}, {-5, -26}, {-11, -24}, {-11, -41}, {-11, -67}, {-24, -68},
				{-25.5, -70}, {-13.9, -70.8}, {-12.9, -73.9}, {-12.9, -80.1}, {-19.1, -86.1}, {-23.1, -86.8}, {-23.1, -123.1},
				{-18.1, -128.1}, {-3, -129.1}, {2.1, -123}, {2.1, -75}, name="walk"},
			
			{"craft", {{"electric-mining-drill", 6, need_intermediates=true}, {"small-electric-pole", 6}}},
			
			{"take", {-9.5, -19.5}},
			{"take", {-16.5, -28.5}},
			{"take", {-9.5, -39.5}},
			{"take", {-13.5, -24.5}},
			{"take", {0.5, -69.5}},
			
			{"mine", {5, -31}},
			{"mine", {1.5, -41}},
			{"mine", {3, -39.5}},
			
			{"mine", {1.5, -125.5}},
			
			{"rotate", {-24.5, -128.5}, "N"},
			{"rotate", {-4.5, -129.5}, "S"},
			{"build", "transport-belt", {-4.5, -128.5}, "S"},
			
			{"craft", {{"stone-furnace", 3}, {"transport-belt", 23}, {"assembling-machine-2", 1}}, command_finished="walk.command-10"},
			
			{"take", {-16.5, -24.5}, "transport-belt", inventory=defines.inventory.assembling_machine_input},
			
			{"take", {-9.5, -36.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -31.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -28.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -25.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			
			{"take", {-16.5, -24.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			
			{"parallel", insert_recipe({-3.5, -40.5}, "copper-cable", 96)},
			
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 100)},
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 100)},
			{"parallel", insert_recipe({0.5, -19.5}, "copper-cable", 100)},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 13)},
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 13)},
			
			{"parallel", insert_recipe({-16.5, -20.5}, "transport-belt", 30)},
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "wood", 6)},
			
			{"parallel", insert_recipe({-9.5, -39.5}, "electric-mining-drill", 9)},
			{"parallel", change_recipe_and_insert({-16.5, -28.5}, "electric-mining-drill", 10)},
			
			{"pickup", ticks=240, on_entering_area={{-8, -41}, {-6, -39}}},
			{"pickup", ticks=60, on_entering_area={{-1, -36}, {1, -34}}},
			
			{"stop-command", "automation-2-13.refuel-furnaces"},
		}
	},
	{
		name = "automation-2-15",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_belt_4", {25,-124}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"build", "assembling-machine-2", {0.5, -45.5}},
			{"sequence", {
				{"craft", "transport-belt", 3},
				{"parallel", change_recipe_and_insert({0.5, -45.5}, "underground-belt", 5)},
				{"craft", {{"splitter", 2}, {"small-electric-pole", 4}, {"underground-belt", 2, need_intermediates=true}, {"electric-mining-drill", 5}, {"transport-belt", 19}}},
			}},
			
			
			{"simple-sequence", "move", {-5, -43}, {-7, -39}, {-7, -34}, {-6.9, -25}, {-6, -23}, {-11, -24}, {-11, -41}, {29.1, -81.1},
				{29.9, -101}, {31, -136}, {18, -126.9}, {4, -127.1}, {-0.1, -126.1}, {-4.1, -123}, {-4.1, -75}, name="walk"},
			
			{"parallel", insert_recipe({-9.5, -39.5}, "electric-mining-drill", 2)},
			
			{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 30)},
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 30)},
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 30)},
			
			{"parallel", insert_recipe({-16.5, -24.5}, "transport-belt", 30)},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-16.5, -28.5}, "transport-belt", 1)},
				{"take", {-16.5, -28.5}, "transport-belt", 2},
				{"parallel", change_recipe_and_insert({-16.5, -28.5}, "inserter", 5)},
			}},
			
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "small-electric-pole", 2)},
			
			{"take", {-9.5, -36.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -31.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -28.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			{"take", {-9.5, -25.5}, "iron-plate", 5, inventory=defines.inventory.assembling_machine_input},
			
			{"take", {-9.5, -39.5}, "electric-mining-drill", 11},
			{"take", {-9.5, -19.5}},
			{"take", {-9.5, -19.5}, "small-electric-pole", 2},
			{"take", {-16.5, -28.5}},
			{"take", {0.5, -45.5}, "underground-belt", 10},
			
			
			{"rotate", {-4.5, -129.5}, "E"},
		}
	},
	{
		name = "automation-2-16",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_belt_2-furnaces-2", {-2,-124}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_4-furnaces-1", {25,-124}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"build", "assembling-machine-2", {0.5, -48.5}},
			
			{"simple-sequence", "move", {-5, -43}, {-7, -39}, {-7, -34}, {-6.9, -25}, {-6, -23}, {-11, -24}, {-15, -19}, {-24, -10},
				{-28, -9.9}, {-25, -10}, {-15, -19}, {-8, -24}, {-8, -27}, {-3, -37}, {-1, -36}, {0, -42}, {4, -47}, {15.1, -58.1}, {15.1, -69.1},
				{19, -75}, {19, -123}, {17, -123}, {-4, -119}, {-4.1, -75}, name="walk"},
			
			{"craft", {{"assembling-machine-2", 1}, {"transport-belt", 5}, {"inserter", 3}}},
			{"craft", {{"inserter", 15}, {"transport-belt", 5}, {"splitter", 1}, {"small-electric-pole", 2}, {"underground-belt", 5},
				{"long-handed-inserter", 6}}, command_finished="walk.command-4"},
				
			{"craft", {{"long-handed-inserter", 12}, {"small-electric-pole", 2}}, command_finished="walk.command-21"},
			
			{"take", {-33.5, -7.5}},
			{"take", {-13.5, -24.5}, command_finished="walk.command-8"},
			{"take", {0.5, -48.5}, "long-handed-inserter", 22},
			{"take", {-16.5, -20.5}, "long-handed-inserter", 8},
			{"take", {0.5, -45.5}, "inserter", 22},
			{"take", {-9.5, -39.5}, "underground-belt", 14},
			
			{"parallel", change_recipe_and_insert({0.5, -48.5}, "long-handed-inserter", 22)},
			{"parallel", change_recipe_and_insert({-3.5, -40.5}, "transport-belt", 20)},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-3.5, -44.5}, "inserter", 21)},
				{"take", {-3.5, -44.5}, "inserter", 21},
				{"parallel", change_recipe_and_insert({-3.5, -44.5}, "electronic-circuit", 27)},
			}},
			
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 60)},
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 60)},
			
			{"parallel", change_recipe_and_insert({-9.5, -39.5}, "underground-belt", 7)},
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "electric-mining-drill", 10)},
			
			{"parallel", change_recipe_and_insert({0.5, -45.5}, "inserter", 22)},
			{"parallel", insert_recipe({-16.5, -24.5}, "transport-belt", 20)},
			
			{"parallel", change_recipe_and_insert({-16.5, -28.5}, "pipe", 49)},
			{"parallel", change_recipe_and_insert({-16.5, -20.5}, "long-handed-inserter", 8)},
			
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 50)},
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 50)},
			{"parallel", insert_recipe({0.5, -19.5}, "copper-cable", 50)},
			
			{"mine", {2, -36.5}},
			{"mine", {19.5, -125.5}},
			
			{"parallel", insert_equal(generate_points({18, -96}, {18, -76}, 2), "coal", 11)},
			{"parallel", insert_equal(generate_points({25, -96}, {25, -76}, 2), "coal", 11)},
		}
	},
	{
		name = "automation-2-17",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-46, -49}, {-31, -37}}, show_ghosts=true, record_order=false, name="expansion-2", set_on_leaving_range=false},
			
			{"parallel", {
				{"auto-build-blueprint", "Bootstrap_extension-4", {-10,-35}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
				{"build", "transport-belt", {-3.5, -70.5}, "E"},
				{"build", "transport-belt", {-4.5, -70.5}, "E"},
				{"rotate", {-5.5, -70.5}, "E"},
			}, command_finished="expansion-2"},
			
			
			{"simple-sequence", "move", {-5, -46}, {-7, -34}, {-6.9, -25}, {-6, -23}, {-11, -24}, {-11, -32}, {-43, -43}, {-32, -40.1}, {-13.5, -30},
				{-11, -43}, {-1.9, -51}, {-1.9, -66}, name="walk"},
			
			{"craft", {{"inserter", 3}, {"boiler", 1}, {"boiler", 3, need_intermediates=true}, {"steam-engine", 8, need_intermediates=true},
				{"assembling-machine-1", 6}, {"assembling-machine-2", 6, need_intermediates=true}, {"small-electric-pole", 1},
				{"fast-inserter", 6, need_intermediates=true}}},
			
			{"parallel", change_recipe_and_insert({0.5, -48.5}, "iron-chest", 6)},
			{"take", {0.5, -48.5}, "iron-chest", 6},
			
			{"parallel", insert_recipe({-3.5, -40.5}, "transport-belt", 40)},
			
			{"parallel", insert_recipe({0.5, -45.5}, "inserter", 6)},
			{"take", {0.5, -45.5}, "inserter", 6},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 30)},
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 30)},
			
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 9)},
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 7)},
			{"parallel", insert_recipe({0.5, -19.5}, "copper-cable", 7)},
			
			{"parallel", change_recipe_and_insert({-16.5, -28.5}, "electronic-circuit", 14)},
			
			{"parallel", change_recipe_and_insert({-9.5, -39.5}, "pipe", 6)},
			{"parallel", change_recipe_and_insert({-16.5, -20.5}, "inserter", 12)},
			{"sequence", {
				{"parallel", change_recipe_and_insert_except({-16.5, -24.5}, "fast-inserter", 12, "inserter")},
				{"take", {-13.5, -24.5}, "fast-inserter", 12},
			}},
			
			{"parallel", change_recipe_and_insert_except({-9.5, -36.5}, "electric-mining-drill", 7, "iron-plate")},
			
			{"take", {-16.5, -28.5}},
			{"take", {-13.5, -24.5}},
			{"take", {-9.5, -19.5}},
			
			{"mine", {-12.5, -46}},
			
			{"sequence", {
				{"take", {-9.5, -39.5}, "pipe", 6},
				{"parallel", change_recipe_and_insert({-9.5, -39.5}, "electric-mining-drill", 1)},
			}},
			
			{"parallel", insert_recipe({-9.5, -19.5}, "electric-mining-drill", 9)},
			
			{"pickup", ticks=240, on_entering_area={{-8, -41}, {-6, -39}}},
		}
	},
	{
		name = "automation-2-18",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Coal_belt-1", {4,-1}, area={{-2, 6}, {8, 17}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_belt_5", {-28,2}, area={{-37, 0}, {-18, 31}}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-1, -44}, {2.1, -43.8}, {-12.5, -36.5, entity=true}, {-7, -34}, {-6.9, -25}, {-5, -19}, {-0.2, 12.2}, {2, 14},
				{-16, 14}, {-16, 18}, {-20, 18}, {-23, 19}, {-29, 26}, {-29, 5}, {-21, -1}, {-17, -3}, {-16, -6}, {-12, -26}, name="walk"},
			
			{"craft", {{"underground-belt", 1}, {"transport-belt", 1}, {"small-electric-pole", 5}, {"underground-belt", 1}}},
			
			{"mine", {5, -42.5}, name="mine-tree"},
			{"recipe", {-9.5, -36.5}, "iron-gear-wheel"},
			{"take", {-12.5, -36.5}},
			{"take", {-9.5, -39.5}},
			
			{"parallel", change_recipe_and_insert({-3.5, -44.5}, "inserter", 9)},
			
			{"sequence", {
				{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 25)},
				{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 26)},
				{"take", {-9.5, -19.5}, "electric-mining-drill", 9},
				{"parallel", change_recipe_and_insert({-9.5, -19.5}, "transport-belt", 9)},
				{"craft", {{"underground-belt", 4}, {"electric-mining-drill", 3}, {"transport-belt", 20}}},
			}},
			
			{"parallel", take_all_coal},
			
			{"pickup", ticks=120, on_entering_area={{-8, -41}, {-6, -39}}},
			
			{"auto-refuel", min=1, target=2, type="furnace", name="refuel-furnaces", command_finished="walk.command-6"},
		}
	},
	{
		name = "automation-2-19",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_copper_belts-furnaces-2", {62,-74}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_transport-2", {62,-74}, area={{62, -73}, {65, -43}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_transport-2", {62,-74}, area={{51, -43}, {63, -38}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_transport-2", {62,-74}, area={{16, -39.1}, {51, -29.9}}, show_ghosts=true, set_on_leaving_range=false},
			
			{"auto-build-blueprint", "Bootstrap_belt_5", {-28,2}, show_ghosts=true, record_order=false, set_on_leaving_range=false, name="remaining"},
			
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{-8, -10}, {-4, -1}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{-4, -12}, {8, -9}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{8, -49}, {14, -11}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{14, -71}, {28, -48}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, area={{28, -103}, {46, -70}}, show_ghosts=true, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-15, -19}, {-17, -2}, {-13, -3}, {-12, -6}, {-2, -39}, {-1, -65}, {-11, -24}, {3, -14}, {8.1, -19.1},
				{9, -44}, {15.9, -64.9}, {29.9, -101.1}, {34, -101.9}, {63.1, -105}, {63.1, -87}, {62.9, -72.9}, {62.1, -49}, {18.9, -38.1}, name="walk"},
			
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "inserter", 20)},
			{"sequence", {
				{"parallel", change_recipe_and_insert({-16.5, -24.5}, "inserter", 11)},
				{"take", {-13.5, -24.5}, "inserter", 11},
				{"parallel", change_recipe_and_insert_except({-16.5, -24.5}, "long-handed-inserter", 30, "inserter")},
			}},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-16.5, -28.5}, "iron-gear-wheel", 22)},
				{"parallel", change_recipe_and_insert({-16.5, -28.5}, "electric-mining-drill", 10), items_available={"iron-gear-wheel", 100}},
			}},
			
			{"parallel", insert_recipe({-16.5, -20.5}, "inserter", 30)},
			
			{"take", {-3.5, -44.5}},
			
			{"craft", {{"underground-belt", 10, need_intermediates=true}, {"splitter", 1, need_intermediates=true},
				{"inserter", 2, need_intermediates=true}, {"long-handed-inserter", 22, need_intermediates=true},
				{"assembling-machine-2", 2}, {"long-handed-inserter", 10}}, command_finished="walk.command-5"},
			
			{"passive-take", "transport-belt", "container", name="passive-take-transport-belt-chest"},
		}
	},
	{
		name = "automation-2-20",
		required = {"walk"},
		commands = {
			{"set-variable", "move_opt_near_buildings", true},
			{"stop-command", "automation-20.passive-take-belts-assembler"},
			
			{"auto-build-blueprint", "Bootstrap_extension-5", {-10,-35}, area={{5, -73}, {22, -72}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_extension-5", {-10,-35}, area={{5, -72}, {6, -51}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_extension-5", {-10,-35}, show_ghosts=true, record_order=false, set_on_leaving_range=false, command_finished="walk.command-14"},
			{"auto-build-blueprint", "Bootstrap_belt_4-furnaces-2", {25,-124}, show_ghosts=true, record_order=false, set_on_leaving_range=false, command_finished="walk.command-9"},
			
			{"simple-sequence", "move", {-1, -27}, {-5, -26}, {-11, -24}, {-11, -33}, {-8, -35}, {-5, -46}, {-1, -71}, {19, -75}, {19, -118},
				{20.1, -118}, {20.1, -75}, {14, -71.1}, {5.1, -51}, {3, -44}, {-1, -26}, {3, -41}, {4, -40}, {2, -42}, {15, -42}, {2, -42},
				{10, -50}, {10, -66}, {21.9, -70.9}, name="walk"},
			
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 100)},
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 100)},
			{"parallel", insert_recipe({0.5, -19.5}, "copper-cable", 100)},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-9.5, -39.5}, "iron-chest", 2)},
				{"take", {-9.5, -39.5}, "iron-chest", 2},
				{"parallel", change_recipe_and_insert({-9.5, -39.5}, "stone-furnace", 10)},
			}},
			
			{"parallel", change_recipe_and_insert({-3.5, -24.5}, "copper-cable", 39)},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "copper-cable", 39)},
			
			{"parallel", change_recipe_and_insert({0.5, -45.5}, "copper-cable", 70)},
			{"parallel", change_recipe_and_insert({0.5, -48.5}, "copper-cable", 29)},
			{"parallel", change_recipe_and_insert({-3.5, -40.5}, "copper-cable", 29)},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-3.5, -44.5}, "electronic-circuit", 9)},
				{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 15)},
			}},
			
			{"craft", {{"long-handed-inserter", 8, need_intermediates=true}, {"underground-belt", 12, need_intermediates=true}, {"inserter", 3},
				{"inserter", 1, need_intermediates=true}, {"fast-inserter", 12, need_intermediates=true}, {"assembling-machine-1", 4, need_intermediates=true},
				{"assembling-machine-2", 4, need_intermediates=true}, {"fast-inserter", 4, need_intermediates=true}, {"splitter", 2}}},
			
			{"take", {-9.5, -19.5}},
			{"take", {-13.5, -24.5}},
			
			{"mine", {6.5, -38}, name="mine-tree-1"},
			{"mine", {18, -42.5}},
			
			{"parallel", {
				{"parallel", change_recipe_and_insert({0.5, -48.5}, "electronic-circuit", 15)},
				{"parallel", change_recipe_and_insert({-3.5, -40.5}, "electronic-circuit", 15)},
				
				{"parallel", change_recipe_and_insert({-3.5, -24.5}, "electronic-circuit", 50)},
				{"parallel", change_recipe_and_insert({-3.5, -20.5}, "electronic-circuit", 50)},
			}, command_finished="walk.command-9"},
			
			{"parallel", {
				{"parallel", change_recipe_and_insert({0.5, -48.5}, "electronic-circuit", 10)},
				{"parallel", change_recipe_and_insert({-3.5, -40.5}, "electronic-circuit", 10)},
				{"parallel", insert_recipe({-3.5, -44.5}, "electronic-circuit", 10)},
			}, command_finished="mine-tree-1"},
		}
	},
	{
		name = "automation-2-21",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_belt_5-furnaces-1", show_ghosts=true, {29,-98}},
			{"auto-build-blueprint", "Bootstrap_copper_transport-2", {62,-74}, area={{4, -32}, {17, -29}}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_extension-6", {-10,-35}, show_ghosts=true, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {28.1, -77.1}, {29.9, -100}, {37, -102.1}, {42.1, -48}, {18.9, -38.1}, {-1, -27}, {-5, -26}, {-11, -24},
				{-11, -33}, {-5, -44}, {-8, -24}, {-8, -33}, {-2, -39}, {15.9, -65.9}, name="walk"},
			
			{"craft", {{"underground-belt", 1}, {"splitter", 1}, {"wood", 8}, {"stone-furnace", 6}, {"splitter", 1, need_intermediates=true},
				{"inserter", 4, need_intermediates=true}}},
				
			{"craft", {{"inserter", 37, need_intermediates=true}}, command_finished="walk.command-9"},
			
			{"parallel", change_recipe_and_insert({-3.5, -24.5}, "electronic-circuit", 30)},
			{"parallel", change_recipe_and_insert({-3.5, -20.5}, "electronic-circuit", 30)},
			
			{"parallel", change_recipe_and_insert({-3.5, -40.5}, "electronic-circuit", 20)},
			{"parallel", change_recipe_and_insert({-3.5, -44.5}, "electronic-circuit", 18)},
			
			{"parallel", insert_recipe({-9.5, -19.5}, "inserter", 20)},
			{"parallel", insert_recipe({-16.5, -20.5}, "inserter", 30)},
			{"parallel", insert_recipe_except({-16.5, -24.5}, "long-handed-inserter", 30, "inserter")},
			
			{"take", {-9.5, -19.5}, "inserter", 9},
			
			{"parallel", {
				{"parallel", change_recipe_and_insert({0.5, -45.5}, "stone-furnace", 10)},
				{"parallel", change_recipe_and_insert({0.5, -48.5}, "stone-furnace", 10)},
			}},
			{"parallel", {
				{"parallel", change_recipe_and_insert({0.5, -45.5}, "stone-furnace", 7)},
				{"parallel", change_recipe_and_insert({0.5, -48.5}, "stone-furnace", 7)},
			}, command_finished="walk.command-11"},
			
			{"sequence", {
				{"parallel", change_recipe_and_insert({-9.5, -39.5}, "small-electric-pole", 8)},
				{"take", {-9.5, -39.5}, "small-electric-pole", 16},
				{"parallel", change_recipe_and_insert({-9.5, -39.5}, "electric-mining-drill", 4)},
			}},
			
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 10)},
			
			{"passive-take", "underground-belt", "container"},
		}
	},
	{
		name = "automation-2-22",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_belt_5-furnaces-2", show_ghosts=true, {29,-98}, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {28.1, -77.1}, {29.9, -93}, {41, -94}, {42.1, -48}, {0, -27}, {-4, -26}, {-10, -24}, {-11, -32}, {7, -51},
				{7, -67}, {5.1, -51}, {2, -44}, {-1, -25}, {-9, -3}, {-10, 9}, name="walk"},
			
			{"mine", {43.5, -50}},
			
			{"craft", {{"small-electric-pole", 2}, {"iron-chest", 2}, {"inserter", 6, need_intermediates=true}, {"fast-inserter", 11, need_intermediates=true},
				{"inserter", 38, need_intermediates=true}}},
			
			{"parallel", insert_recipe({0.5, -25.5}, "copper-cable", 18)},
			{"parallel", insert_recipe({0.5, -22.5}, "copper-cable", 18)},
			{"parallel", insert_recipe({0.5, -19.5}, "copper-cable", 18)},
			
			{"parallel", insert_recipe({-3.5, -24.5}, "electronic-circuit", 18)},
			{"parallel", insert_recipe({-3.5, -20.5}, "electronic-circuit", 18)},
			
			{"parallel", change_recipe_and_insert({0.5, -45.5}, "pipe", 100)},
			{"parallel", change_recipe_and_insert({0.5, -48.5}, "pipe", 100)},
			
			{"parallel", change_recipe_and_insert({-3.5, -44.5}, "iron-gear-wheel", 50)},
			{"parallel", change_recipe_and_insert({-3.5, -40.5}, "iron-gear-wheel", 50)},
			
			{"parallel", {
				{"parallel", insert_recipe_except({-3.5, -24.5}, "electronic-circuit", 100, "copper-cable")},
				{"parallel", insert_recipe_except({-3.5, -20.5}, "electronic-circuit", 100, "copper-cable")},
			}, command_finished="walk.command-13"},
			
			{"take", {-9.5, -19.5}},
			{"take", {-9.5, -39.5}},
			{"take", {-13.5, -24.5}},
			{"take", {-16.5, -28.5}},
			
			{"take", {0.5, -48.5}},
			{"take", {0.5, -45.5}},
			
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "electronic-circuit", 30)},
			
			{"parallel", take_all_coal},
		}
	},
	{
		name = "automation-2-23",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_copper_transport", {57,-111}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_belts-2", show_ghosts=true, {46,-28}, record_order=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_belts-furnaces-3", {57,-111}, show_ghosts=true, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_copper_coal_belt", {57,-111}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"auto-build-blueprint", "Bootstrap_copper_transport-2", {62,-74}, show_ghosts=true, set_on_leaving_range=false},
			
			{"build", "small-electric-pole", {71.5, -75.5}},
			{"build", "transport-belt", {61.5, -75.5}, "S"},
			
			{"simple-sequence", "move", {-5.1, -4}, {37, -8}, {46.8, -14}, {41.7, -26}, {48.9, -29.9}, {59.9, -103}, {65.9, -81.5}, {71.5, -81},
				{71.9, -108.9}, {60, -113}, {52.5, -162}, {30, -162}, {24, -141}, name="walk"},
			
			{"craft", {{"splitter", 3}, {"inserter", 4}, {"long-handed-inserter", 10}, {"small-electric-pole", 6}, {"splitter", 1},
				{"electric-mining-drill", 4}, {"underground-belt", 1}, {"small-electric-pole", 2}}},
			
			{"craft", {{"long-handed-inserter", 18}}, command_finished="walk.command-11"},
			
			{"mine", {39.5, -27.5}},
			{"mine", {49.5, -16}},
			{"mine", {49, -12}},
			
			{"rotate", {58.5, -114.5}, "N"},
			
			{"parallel", insert_equal(generate_points({61, -108}, {61, -78}, 2), "coal", 32)},
			{"parallel", insert_equal(generate_points({68, -108}, {68, -78}, 2), "coal", 32)},
			
			{"parallel", insert_equal(generate_points({61, -82}, {61, -78}, 2), "coal", 6)},
			{"parallel", insert_equal(generate_points({68, -82}, {68, -78}, 2), "coal", 6)},
			
			{"parallel", insert_equal(generate_points({70, -108}, {70, -80}, 2), "coal", 30)},
			{"parallel", insert_equal(generate_points({77, -108}, {77, -80}, 2), "coal", 30)},
			
			{"put", {70, -80}, "coal", 1},
			{"put", {77, -80}, "coal", 1},
		}
	},
	{
		name = "automation-2-24",
		required = {"walk"},
		commands = {
			{"simple-sequence", "move", {4.9, -75}, {5.5, -56.5}, {5.1, -51}, {2, -44}, {-6.9, -25}, {-11, -24}, {-11, -33}, {47, -41.3},
				{20, -38.1}, {-1, -27}, {-3, -26}, name="walk"},
			
			{"parallel", insert_recipe({-9.5, -39.5}, "electric-mining-drill", 7)},
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 7)},
			
			{"parallel", insert_recipe_except({-3.5, -24.5}, "electronic-circuit", 85, "copper-cable")},
			{"parallel", insert_recipe_except({-3.5, -20.5}, "electronic-circuit", 85, "copper-cable")},
			
			{"parallel", change_recipe_and_insert({-9.5, -19.5}, "inserter", 50)},
			
			{"parallel", insert_recipe({-16.5, -20.5}, "inserter", 50)},
			{"parallel", insert_recipe_except({-16.5, -24.5}, "long-handed-inserter", 50, "inserter")},
			
			{"craft", {{"boiler", 10, need_intermediates=true}, {"small-electric-pole", 4}, {"wood", 8}, {"small-electric-pole", 4}}},
			
			{"sequence", {
				{"take", {0.5, -45.5}, "pipe", 50},
				{"parallel", change_recipe_and_insert({-3.5, -44.5}, "steam-engine", 10)},
				{"take", {0.5, -45.5}, "pipe", 50},
				{"parallel", change_recipe_and_insert({0.5, -45.5}, "electric-mining-drill", 6)},
			}},
			
			{"sequence", {
				{"take", {0.5, -48.5}, "pipe", 50},
				{"parallel", change_recipe_and_insert({-3.5, -40.5}, "steam-engine", 10)},
				{"take", {0.5, -48.5}, "pipe", 50},
				{"parallel", change_recipe_and_insert({0.5, -48.5}, "electric-mining-drill", 6)},
			}},
			
			{"sequence", {
				{"take", {-3.5, -44.5}, "steam-engine", 10},
				{"parallel", change_recipe_and_insert({-3.5, -44.5}, "electric-mining-drill", 6)},
			}},
			
			{"passive-take", "electronic-circuit", "container"},
			
			{"mine", {19, -42.5}},
			{"mine", {19.5, -43.5}},
			{"mine", {48, -40}},
			
			{"pickup", ticks=60, on_entering_area={{45, -41}, {47, -39}}},
		}
	},
	{
		name = "automation-2-25",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Power-1", {-43,-9}, area={{-60, -40}, {-46, -10}}, show_ghosts=true, record_order=false, name="expansion-3", set_on_leaving_range=false},
			{"auto-build-blueprint", "Power-1-water-2", {-47,-10}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			{"auto-build-blueprint", "Coal_belt-1", {4,-1}, name="finished", show_ghosts=true, set_on_leaving_range=false},
			
			{"auto-build-blueprint", "Bootstrap_belt_6", {-45,2}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"auto-build-blueprint", "Bootstrap_iron_transport", {29,-98}, show_ghosts=true, set_on_leaving_range=false},
			
			{"simple-sequence", "move", {-2, -42}, {-8, -35}, {-11, -33}, {-11, -24}, {-1, 0, name="A"}, {1.6, 34.8}, {-4, 45}, {-13, 46.1}, {-34, 31.1},
				{-43, 8}, {-36, 8}, {-41.5, 2.5}, {-43, -8}, {-50.5, -35}, {-44, -10}, {-21, 0.1}, {-8.9, -2.9}, name="walk"},
			
			{"craft", "electric-mining-drill", 4},
			{"craft", {{"electric-mining-drill", 4}, {"splitter", 2}, {"offshore-pump", 1}, {"pipe-to-ground", 1},
				{"small-electric-pole", 3}, {"splitter", 1}, {"small-electric-pole", 1}, {"inserter", 5}, {"iron-chest", 2}}, command_finished="walk.A"},
			
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 10)},
			
			{"take", {0.5, -45.5}},
			{"take", {0.5, -48.5}},
			{"take", {-3.5, -44.5}},
			{"take", {-9.5, -39.5}},
			{"take", {-16.5, -28.5}},
			{"take", {-9.5, -19.5}},
			{"take", {-3.5, -40.5}},
			{"take", {-33.5, -7.5}},
			
			{"put", {-13.5, -24.5}, "iron-plate", 1000},
			
			{"mine", {-43.5, -9.5}},
			{"mine", {-43.5, -8.5}},
			
			{"build", "pipe-to-ground", {-43.5, -9.5}, "N"},
			{"build", "pipe-to-ground", {-43.5, -8.5}, "S"},
			
			{"build", "small-electric-pole", {-48.5, -9.5}},
		}
	},
	
	---[[
	{
		name = "testing-phase",
		required = {"walk"},
		commands = {
			{"auto-build-blueprint", "Bootstrap_extension-7", {-10,-35}, show_ghosts=true, set_on_leaving_range=false},
			
			{"auto-build-blueprint", "Bootstrap_belt_6-furnaces", show_ghosts=true, {29,-98}, set_on_leaving_range=false},
			{"auto-build-blueprint", "Bootstrap_iron_transport-2", {-10,-35}, show_ghosts=true, record_order=false, set_on_leaving_range=false},
			
			{"sequence", {
				{"simple-sequence", "move", {-8, -21}, {-11, -24}, {19, -18}},
				{"simple-sequence", "mine", {18.5, -17}, {22, -19}, {19, -22}, {15, -22.5}, pass_arguments={[3] = "tree"}},
				{"simple-sequence", "move", {-1, -41}, {-11, -24}},
			}, name="walk"},
			
			{"recipe", {0.5, -45.5}, "copper-cable"},
			
			{"craft", {{"assembling-machine-1", 2, need_intermediates=true}, {"assembling-machine-2", 2, need_intermediates=true}, {"fast-inserter", 11},
				{"electric-mining-drill", 5}}},
			
			{"sequence", {
				{"take", {-9.5, -19.5}},
				{"parallel", change_recipe_and_insert({-9.5, -19.5}, "electric-mining-drill", 7)},
			}},
			
			{"parallel", insert_recipe_except({-3.5, -24.5}, "electronic-circuit", 80, "copper-cable")},
			{"parallel", insert_recipe_except({-3.5, -20.5}, "electronic-circuit", 80, "copper-cable")},
			
			{"parallel", change_recipe_and_insert_except({-3.5, -44.5}, "electronic-circuit", 100, "copper-cable")},
			{"parallel", change_recipe_and_insert_except({-3.5, -40.5}, "electronic-circuit", 100, "copper-cable")},
			
			{"parallel", insert_recipe({-16.5, -28.5}, "electric-mining-drill", 7)},
			
			{"take", {-16.5, -28.5}, "electric-mining-drill", 15},
			{"take", {-9.5, -19.5}, "electric-mining-drill", 5},
			{"take", {-13.5, -24.5}, "long-handed-inserter", 50},
		}
	},
	--]]
	
	-- Trees to mine: 
	
	-- TODO
	-- Put a pipe at (-44.5, -8.5) and build the other offshore pump to save a pipe
	-- Why does {"put", {-14.5, -4.5}, "copper-plate", 5}, in automation-17 not work?
	
	{
		name = "final",
		required = {"walk"},
		commands = {
			{"display-contents", "assembling-machine"},
			{"enable-manual-walking"},
			{"speed", 0.05},
		}
	},
}

return commandqueue
