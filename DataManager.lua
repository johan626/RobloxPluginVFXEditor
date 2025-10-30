-- DataManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/DataManager.lua
-- Handles saving and loading timeline data.

local DataManager = {}
DataManager.__index = DataManager

-- Key for storing plugin data
local STORAGE_KEY = "VFXEditor_TimelineData"

function DataManager.new(plugin, timelineManager)
	local self = setmetatable({}, DataManager)
	self.plugin = plugin
	self.timelineManager = timelineManager
	return self
end

--[[
	Serializes all tracks on the timeline into a Lua table.
	Gathers all attributes from each track UI object.
]]
function DataManager:saveTimeline()
	local tracksData = {}
	local timelineUI = self.timelineManager.timeline

	for _, track in ipairs(timelineUI:GetChildren()) do
		if track:IsA("TextButton") and track.Name == "TimelineTrack" then
			local data = {}
			-- Get all attributes from the track instance
			for attributeName, attributeValue in pairs(track:GetAttributes()) do
				data[attributeName] = attributeValue
			end
			table.insert(tracksData, data)
		end
	end

	-- The HttpService is used for robustly encoding the table as a JSON string.
	-- This prevents issues with complex data types that Roblox settings might not handle well.
	local HttpService = game:GetService("HttpService")
	local success, encodedData = pcall(function()
		return HttpService:JSONEncode(tracksData)
	end)

	if success then
		self.plugin:SetSetting(STORAGE_KEY, encodedData)
		print("VFX Timeline Saved!")
		return true
	else
		warn("Failed to encode timeline data:", encodedData)
		return false
	end
end

--[[
	Deserializes timeline data from plugin settings and returns it.
	The main script will then use this data to clear and repopulate the timeline.
]]
function DataManager:loadTimeline()
	local encodedData = self.plugin:GetSetting(STORAGE_KEY)
	if not encodedData or encodedData == "" then
		print("No saved VFX data found.")
		return nil
	end

	local HttpService = game:GetService("HttpService")
	local success, tracksData = pcall(function()
		return HttpService:JSONDecode(encodedData)
	end)

	if success then
		print("VFX Timeline Loaded!")
		return tracksData
	else
		warn("Failed to decode timeline data:", tracksData)
		-- This might happen if the saved data is corrupted or in an old format.
		-- Clearing the corrupted setting to prevent future errors.
		self.plugin:SetSetting(STORAGE_KEY, nil)
		return nil
	end
end

--[[
    Checks if there is any saved data.
    Used to determine if the "Load" button should be enabled.
]]
function DataManager:hasSavedData()
	return self.plugin:GetSetting(STORAGE_KEY) ~= nil
end


return DataManager
