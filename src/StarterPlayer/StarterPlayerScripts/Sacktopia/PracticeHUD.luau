--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local PracticeHUD = {}

local screenGui: ScreenGui? = nil
local card: Frame? = nil
local labels: {
	deflects: TextLabel,
	combo: TextLabel,
	maxCombo: TextLabel,
	drops: TextLabel,
}? = nil

local function build()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaPractice"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 80) -- under the timing ring area
	frame.Size = UDim2.fromOffset(420, 70)
	frame.BackgroundColor3 = Color3.fromRGB(35, 25, 5)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 200, 80)
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 4)
	title.Size = UDim2.fromScale(0.96, 0.32)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 200, 80)
	title.TextStrokeTransparency = 0.4
	title.Text = "PRACTICE"
	title.Parent = frame

	-- 4 stat columns
	local function statCell(x: number, w: number, name: string, headerText: string): TextLabel
		local cell = Instance.new("Frame")
		cell.Position = UDim2.new(x, 0, 0, 28)
		cell.Size = UDim2.new(w, 0, 0, 38)
		cell.BackgroundTransparency = 1
		cell.Parent = frame
		local h = Instance.new("TextLabel")
		h.Position = UDim2.fromScale(0, 0)
		h.Size = UDim2.new(1, 0, 0, 12)
		h.BackgroundTransparency = 1
		h.Font = Enum.Font.Gotham
		h.TextScaled = true
		h.TextColor3 = Color3.fromRGB(180, 170, 140)
		h.Text = headerText
		h.Parent = cell
		local v = Instance.new("TextLabel")
		v.Name = name
		v.Position = UDim2.fromScale(0, 0.32)
		v.Size = UDim2.new(1, 0, 0, 22)
		v.BackgroundTransparency = 1
		v.Font = Enum.Font.GothamBlack
		v.TextScaled = true
		v.TextColor3 = Color3.fromRGB(255, 255, 255)
		v.TextStrokeTransparency = 0.4
		v.Text = "0"
		v.Parent = cell
		return v
	end
	local deflects = statCell(0, 0.25, "deflects", "DEFLECTS")
	local combo = statCell(0.25, 0.25, "combo", "COMBO")
	local maxCombo = statCell(0.5, 0.25, "maxCombo", "MAX")
	local drops = statCell(0.75, 0.25, "drops", "DROPS")

	frame.Parent = gui
	screenGui = gui
	card = frame
	labels = { deflects = deflects, combo = combo, maxCombo = maxCombo, drops = drops }
end

local function refresh(payload: {
	deflects: number,
	drops: number,
	currentCombo: number,
	maxCombo: number,
	sessionActive: boolean,
})
	if not card or not labels then
		return
	end
	card.Visible = payload.sessionActive
	labels.deflects.Text = tostring(payload.deflects)
	labels.combo.Text = tostring(payload.currentCombo)
	labels.maxCombo.Text = tostring(payload.maxCombo)
	labels.drops.Text = tostring(payload.drops)
	-- combo cell pops when high
	if payload.currentCombo >= 3 then
		labels.combo.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		labels.combo.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

function PracticeHUD.start()
	build()
	Remotes.PracticeStats.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		refresh(payload)
	end)
end

return PracticeHUD
