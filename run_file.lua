local commandqueue = {}

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
			{"move", "mine-coal", priority=2},
			{"build", "burner-mining-drill", {-10,14}, 4, name="miner-built"},
			{"build", "stone-furnace", {-10,16}, 0},
			{"mine", {-11.5,13.5}, amount=2, name="mine-coal"},
			{"auto-refuel", name="auto-refuel"},
		}
	},
	{
		name = "start-2",
    required = {"mine-coal"},
		commands = {
			{"move", "mine-huge-rock", priority=2, name="move-to-rock"},
			{"mine", {-78,22}, name="mine-huge-rock", on_relative_tick = {6, "move-to-rock"}},
      {"craft", {{"iron-gear-wheel", 2}, {"stone-furnace", 9}}},
		}
	},
  {
		name = "start-3",
    required = {"mine-huge-rock"},
		commands = {
      {"mine", {-11.5,17.5}, amount=2, name="mine-iron"},
			{"move", "build-miner"},
      {"craft", "iron-gear-wheel", 1},
      {"craft-build", "burner-mining-drill", {-8,14}, 4, name="build-miner"},
      {"build", "stone-furnace", {-8,16}},
      {"take", {-10,16}},
		}
	},
	{
		name = "final",
		required = {"mine-huge-rock"},
		commands = {
			--{"display-contents", "assembling-machine"},
			{"enable-manual-walking"},
			{"speed", 0.2},
		}
	},
}

return commandqueue
