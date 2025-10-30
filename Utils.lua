-- Utils.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/Utils.lua

local Utils = {}

function Utils.parseColorSequence(str)
	local keypoints = {}
	pcall(function()
		local parts = str:split(";")
		for _, part in ipairs(parts) do
			local values = part:split(",")
			if #values == 4 then
				local time, r, g, b = tonumber(values[1]), tonumber(values[2]), tonumber(values[3]), tonumber(values[4])
				if time and r and g and b then
					table.insert(keypoints, ColorSequenceKeypoint.new(time, Color3.new(r, g, b)))
				end
			end
		end
	end)

	if #keypoints > 0 then
		return ColorSequence.new(keypoints)
	end
	return ColorSequence.new(Color3.new(1,1,1))
end

function Utils.parseNumberSequence(str)
	local keypoints = {}
	pcall(function()
		local parts = str:split(";")
		for _, part in ipairs(parts) do
			local values = part:split(",")
			if #values == 2 then
				local time, value = tonumber(values[1]), tonumber(values[2])
				if time and value then
					table.insert(keypoints, NumberSequenceKeypoint.new(time, value))
				end
			end
		end
	end)

	if #keypoints > 0 then
		return NumberSequence.new(keypoints)
	end
	return NumberSequence.new(0)
end

function Utils.parseNumberRange(str)
	local min, max
	pcall(function()
		local parts = str:split(" ")
		min = tonumber(parts[1])
		max = tonumber(parts[2]) or min
	end)

	if min then
		return NumberRange.new(min, max)
	end
	return NumberRange.new(1)
end

function Utils.parseVector3(str)
	local x, y, z
	pcall(function()
		local parts = str:split(",")
		x = tonumber(parts[1])
		y = tonumber(parts[2])
		z = tonumber(parts[3])
	end)

	if x and y and z then
		return Vector3.new(x, y, z)
	end
	return Vector3.new()
end

function Utils.parseEnum(enumType, stringValue)
	local success, enumItem = pcall(function()
		return enumType[stringValue]
	end)
	if success and enumItem then
		return enumItem
	end
	return nil
end

return Utils
