-- CurveEditor.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/CurveEditor.lua

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local CurveEditor = {}
CurveEditor.__index = CurveEditor

function CurveEditor.new(parentFrame)
	local self = setmetatable({}, CurveEditor)

	self.ui = {}
	self.activeKeyframe = nil
	self.connections = {}

	self.CurveChanged = {}
	function self.CurveChanged:Connect(callback) table.insert(self, callback) end
	function self.CurveChanged:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self:_createUI(parentFrame)
	self:_connectEvents()

	return self
end

function CurveEditor:_createUI(parentFrame)
	-- Main frame for the editor
	self.ui.MainFrame = Instance.new("Frame")
	self.ui.MainFrame.Name = "CurveEditor"
	self.ui.MainFrame.Size = UDim2.new(1, 0, 1, 0)
	self.ui.MainFrame.BackgroundColor3 = Config.Theme.Properties
	self.ui.MainFrame.BorderColor3 = Config.Theme.ButtonAccent
	self.ui.MainFrame.BorderSizePixel = 1
	self.ui.MainFrame.Visible = false
	self.ui.MainFrame.Parent = parentFrame

	-- Canvas to draw the curve on
	self.ui.CurveCanvas = Instance.new("Frame")
	self.ui.CurveCanvas.Size = UDim2.new(1, -20, 1, -40)
	self.ui.CurveCanvas.Position = UDim2.new(0, 10, 0, 10)
	self.ui.CurveCanvas.BackgroundColor3 = Config.Theme.Background
	self.ui.CurveCanvas.ClipsDescendants = true
	self.ui.CurveCanvas.Parent = self.ui.MainFrame

	-- Control points (handles)
	self.ui.P1 = self:_createHandle(self.ui.CurveCanvas, "P1")
	self.ui.P2 = self:_createHandle(self.ui.CurveCanvas, "P2")

	-- Lines from points to handles
	self.ui.LineP0_P1 = self:_createLine(self.ui.CurveCanvas, "LineP0_P1")
	self.ui.LineP3_P2 = self:_createLine(self.ui.CurveCanvas, "LineP3_P2")
end

function CurveEditor:_createHandle(parent, name)
	local handle = Instance.new("Frame")
	handle.Name = name
	handle.Size = UDim2.new(0, 10, 0, 10)
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	handle.BorderSizePixel = 1
	handle.Parent = parent
	return handle
end

function CurveEditor:_createLine(parent, name)
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	line.BorderSizePixel = 0
	line.Parent = parent
	return line
end

function CurveEditor:_connectEvents()
	local function createDragConnection(handle)
		local isDragging = false
		local dragStart

		local conn1 = handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isDragging = true
				dragStart = input.Position
				handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Highlight
			end
		end)

		local conn2 = handle.InputChanged:Connect(function(input)
			if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local canvasSize = self.ui.CurveCanvas.AbsoluteSize
				local newPos = input.Position - self.ui.CurveCanvas.AbsolutePosition

				-- Clamp position within the canvas
				newPos = Vector2.new(
					math.clamp(newPos.X, 0, canvasSize.X),
					math.clamp(newPos.Y, 0, canvasSize.Y)
				)

				handle.Position = UDim2.fromOffset(newPos.X, newPos.Y)

				-- Update the active keyframe's easing values
				if self.activeKeyframe and self.activeKeyframe.easing then
					local normX = newPos.X / canvasSize.X
					local normY = 1 - (newPos.Y / canvasSize.Y) -- Invert Y

					if handle.Name == "P1" then
						self.activeKeyframe.easing.p1x = normX
						self.activeKeyframe.easing.p1y = normY
					elseif handle.Name == "P2" then
						self.activeKeyframe.easing.p2x = normX
						self.activeKeyframe.easing.p2y = normY
					end

					self:_updateUI()
					self.CurveChanged:Fire(self.activeKeyframe.easing)
				end
			end
		end)

		local conn3 = handle.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isDragging = false
				handle.BackgroundColor3 = Color3.fromRGB(255, 180, 0) -- Unhighlight
			end
		end)

		table.insert(self.connections, conn1)
		table.insert(self.connections, conn2)
		table.insert(self.connections, conn3)
	end

	createDragConnection(self.ui.P1)
	createDragConnection(self.ui.P2)
end

function CurveEditor:loadKeyframe(keyframe)
	self.activeKeyframe = keyframe
	self.ui.MainFrame.Visible = true
	self:_updateUI()
end

function CurveEditor:hide()
	self.activeKeyframe = nil
	self.ui.MainFrame.Visible = false
end

function CurveEditor:_updateUI()
	if not self.activeKeyframe or not self.activeKeyframe.easing then return end

	-- Update handle positions and draw the curve
	local easing = self.activeKeyframe.easing
	local canvasSize = self.ui.CurveCanvas.AbsoluteSize

	-- P0 is bottom-left (0, 1 in UDim scale, but (0, canvasSize.Y) in pixels)
	-- P3 is top-right (1, 0 in UDim scale, but (canvasSize.X, 0) in pixels)
	local p0 = Vector2.new(0, canvasSize.Y)
	local p3 = Vector2.new(canvasSize.X, 0)

	local p1 = Vector2.new(easing.p1x * canvasSize.X, (1 - easing.p1y) * canvasSize.Y)
	local p2 = Vector2.new(easing.p2x * canvasSize.X, (1 - easing.p2y) * canvasSize.Y)

	self.ui.P1.Position = UDim2.fromOffset(p1.X, p1.Y)
	self.ui.P2.Position = UDim2.fromOffset(p2.X, p2.Y)

	self:_updateLine(self.ui.LineP0_P1, p0, p1)
	self:_updateLine(self.ui.LineP3_P2, p3, p2)

	self:_drawCurve()
end

function CurveEditor:_updateLine(line, pos1, pos2)
	local diff = pos2 - pos1
	line.Position = UDim2.fromOffset(pos1.X, pos1.Y)
	line.Size = UDim2.fromOffset(diff.Magnitude, 1)
	line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
end

function CurveEditor:_drawCurve()
	-- Clear existing curve points
	for _, child in ipairs(self.ui.CurveCanvas:GetChildren()) do
		if child.Name == "CurvePoint" then
			child:Destroy()
		end
	end

	if not self.activeKeyframe or not self.activeKeyframe.easing then return end

	local easing = self.activeKeyframe.easing
	local canvasSize = self.ui.CurveCanvas.AbsoluteSize

	local p0y, p3y = 0, 1 -- The Y values of the start and end points
	local p1y, p2y = easing.p1y, easing.p2y

	local p0x, p3x = 0, 1 -- The X values of the start and end points
	local p1x, p2x = easing.p1x, easing.p2x

	local lastPoint
	for t = 0, 1, 0.05 do
		local x = Utils.cubicBezier1D(t, p0x, p1x, p2x, p3x)
		local y = Utils.cubicBezier1D(t, p0y, p1y, p2y, p3y)

		local pixelX = x * canvasSize.X
		local pixelY = (1 - y) * canvasSize.Y -- Invert Y for UI coordinates

		local point = Instance.new("Frame")
		point.Name = "CurvePoint"
		point.Size = UDim2.new(0, 2, 0, 2)
		point.Position = UDim2.fromOffset(pixelX, pixelY)
		point.BackgroundColor3 = Color3.new(1,1,1)
		point.BorderSizePixel = 0
		point.Parent = self.ui.CurveCanvas

		lastPoint = Vector2.new(pixelX, pixelY)
	end
end

function CurveEditor:destroy()
	for _, conn in ipairs(self.connections) do conn:Disconnect() end
	self.ui.MainFrame:Destroy()
end

return CurveEditor
