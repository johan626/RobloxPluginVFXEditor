-- DataManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/DataManager.lua
-- Handles saving and loading timeline data.

local UIManager = require(script.Parent.UIManager)
local DataManager = {}
DataManager.__index = DataManager

-- Key for storing plugin data
local STORAGE_KEY = "VFXEditor_TimelineData"

function DataManager.new(plugin, timelineManager, ui)
	local self = setmetatable({}, DataManager)
	self.plugin = plugin
	self.timelineManager = timelineManager
	self.ui = ui
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
	Shows a confirmation dialog before loading. If confirmed, deserializes timeline data 
	from plugin settings and passes it to the onLoaded callback.
]]
function DataManager:loadTimeline(onLoaded)
	UIManager.showConfirmationDialog(
		self.ui,
		"Load Project",
		"Are you sure you want to load a project? Any unsaved changes will be lost.",
		function()
			local encodedData = self.plugin:GetSetting(STORAGE_KEY)
			if not encodedData or encodedData == "" then
				print("No saved VFX data found.")
				return
			end

			local HttpService = game:GetService("HttpService")
			local success, tracksData = pcall(function()
				return HttpService:JSONDecode(encodedData)
			end)

			if success then
				print("VFX Timeline Loaded!")
				if onLoaded then onLoaded(tracksData) end
			else
				warn("Failed to decode timeline data:", tracksData)
				self.plugin:SetSetting(STORAGE_KEY, nil)
			end
		end
	)
end

--[[
    Checks if there is any saved data.
    Used to determine if the "Load" button should be enabled.
]]
function DataManager:hasSavedData()
	return self.plugin:GetSetting(STORAGE_KEY) ~= nil
end


return DataManager
