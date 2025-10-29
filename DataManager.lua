-- DataManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/DataManager.lua

local DataManager = {}
DataManager.__index = DataManager

function DataManager.new(timelineManager)
	local self = setmetatable({}, DataManager)
	self.timelineManager = timelineManager
	return self
end

-- == SERIALIZERS ==
-- Mengubah berbagai tipe data menjadi format string yang dapat disimpan.

function DataManager:serializeColor3(color)
	return string.format("Color3.fromRGB(%.f, %.f, %.f)", color.R * 255, color.G * 255, color.B * 255)
end

function DataManager:serializeColorSequence(sequence)
	local points = {}
	for _, keypoint in ipairs(sequence.Keypoints) do
		local c = keypoint.Value
		table.insert(points, string.format("ColorSequenceKeypoint.new(%.2f, Color3.fromRGB(%.f, %.f, %.f))",
			keypoint.Time, c.R * 255, c.G * 255, c.B * 255))
	end
	return "ColorSequence.new({" .. table.concat(points, ", ") .. "})"
end

function DataManager:serializeNumberSequence(sequence)
	local points = {}
	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(points, string.format("NumberSequenceKeypoint.new(%.2f, %.2f)", keypoint.Time, keypoint.Value))
	end
	return "NumberSequence.new({" .. table.concat(points, ", ") .. "})"
end

function DataManager:serializeNumberRange(range)
	return string.format("NumberRange.new(%.2f, %.2f)", range.Min, range.Max)
end


-- Mengubah tabel data mentah menjadi string yang diformat dengan baik untuk ModuleScript
function DataManager:formatData(trackData)
	local lines = {"return {"}
	for _, data in ipairs(trackData) do
		table.insert(lines, "\t{")
		for key, value in pairs(data) do
			local formattedValue
			local valueType = typeof(value)

			if valueType == "string" then
				formattedValue = string.format("%q", value)
			elseif valueType == "Color3" then
				formattedValue = self:serializeColor3(value)
			elseif valueType == "ColorSequence" then
				formattedValue = self:serializeColorSequence(value)
			elseif valueType == "NumberSequence" then
				formattedValue = self:serializeNumberSequence(value)
			elseif valueType == "NumberRange" then
				formattedValue = self:serializeNumberRange(value)
			else
				formattedValue = tostring(value)
			end
			table.insert(lines, string.format("\t\t%s = %s,", key, formattedValue))
		end
		table.insert(lines, "\t},")
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

-- Fungsi utama untuk menyimpan proyek
function DataManager:saveProject(plugin)
	local selection = game:GetService("Selection"):Get()
	if #selection ~= 1 then
		plugin:SetWarningMessage("Silakan pilih SATU folder atau lokasi tujuan di Explorer.")
		return
	end
	local target = selection[1]

	-- Kumpulkan data dari timeline
	local allTracksData = {}
	for _, track in ipairs(self.timelineManager.timeline:GetChildren()) do
		if track:IsA("TextButton") and track.Name == "TimelineTrack" then
			local data = {}
			for _, key in ipairs(track:GetAttributes()) do
				data[key] = track:GetAttribute(key)
			end
			table.insert(allTracksData, data)
		end
	end

	if #allTracksData == 0 then
		plugin:SetWarningMessage("Timeline kosong. Tidak ada yang bisa disimpan.")
		return
	end

	-- Format data dan buat skrip
	local formattedContent = self:formatData(allTracksData)
	local newScript = Instance.new("ModuleScript")
	newScript.Name = "VFXData"
	newScript.Source = formattedContent
	newScript.Parent = target

	plugin:SetSuccessMessage("Proyek berhasil disimpan ke " .. target:GetFullName())
end

-- Fungsi utama untuk memuat proyek
function DataManager:loadProject(plugin)
	local selection = game:GetService("Selection"):Get()
	if #selection ~= 1 or not selection[1]:IsA("ModuleScript") then
		plugin:SetWarningMessage("Silakan pilih SATU ModuleScript proyek untuk dimuat.")
		return
	end
	local script = selection[1]

	-- Muat data dari skrip (gunakan pcall untuk keamanan)
	local success, trackData = pcall(require, script)
	if not success or not trackData then
		plugin:SetWarningMessage("Gagal memuat data dari skrip. Pastikan formatnya benar.")
		return
	end

	-- Bersihkan timeline dan buat ulang trek
	self.timelineManager:clearTimeline()
	for _, data in ipairs(trackData) do
		self.timelineManager:createTrack(data)
	end

	plugin:SetSuccessMessage("Proyek berhasil dimuat dari " .. script:GetFullName())
end

return DataManager
