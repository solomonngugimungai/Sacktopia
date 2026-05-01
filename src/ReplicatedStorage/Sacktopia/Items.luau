--!strict
-- Static catalog of cosmetic items and sack skins.
-- Items are grouped by slot. "None" entries are valid (empty slot).

export type Item = {
	id: string,
	name: string,
	slot: string, -- "Head" | "Hand" | "SackSkin"
	rarity: string, -- "Starter" | "Common" | "Rare" | "Event"
	-- Render data (consumed by EquipController on the server)
	render: {
		shape: string?, -- "Cone" | "Cylinder" | "None" for stub primitives in v2
		color: Color3?,
		size: Vector3?,
		offsetCFrame: CFrame?,
		material: Enum.Material?,
	},
}

export type SackSkin = {
	id: string,
	name: string,
	rarity: string,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	-- optional pulse/cycle behavior for animated skins (Disco)
	cycleColors: { Color3 }?,
	cycleSpeed: number?, -- cycles per second
}

local Items = {}

Items.Items = {
	-- Head
	BasicCap = {
		id = "BasicCap",
		name = "Basic Cap",
		slot = "Head",
		rarity = "Starter",
		render = {
			shape = "Cylinder",
			color = Color3.fromRGB(60, 60, 60),
			size = Vector3.new(0.4, 1.6, 1.6),
			offsetCFrame = CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Fabric,
		},
	} :: Item,
	FratCap = {
		id = "FratCap",
		name = "Frat Cap",
		slot = "Head",
		rarity = "Common",
		render = {
			-- Backwards-facing fitted cap stub; swap for real mesh later.
			shape = "Cylinder",
			color = Color3.fromRGB(170, 30, 50),
			size = Vector3.new(0.45, 1.7, 1.7),
			offsetCFrame = CFrame.new(0, 0.7, -0.05) * CFrame.Angles(math.rad(-8), 0, math.rad(90)),
			material = Enum.Material.Fabric,
		},
	} :: Item,

	-- Hand
	None = {
		id = "None",
		name = "Bare Hands",
		slot = "Hand",
		rarity = "Starter",
		render = { shape = "None" },
	} :: Item,
	LacrosseStick = {
		id = "LacrosseStick",
		name = "Lacrosse Stick",
		slot = "Hand",
		rarity = "Common",
		render = {
			shape = "Cylinder",
			color = Color3.fromRGB(200, 180, 140),
			size = Vector3.new(0.25, 4.5, 0.25),
			offsetCFrame = CFrame.new(0, -2.0, 0) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Wood,
		},
	} :: Item,
}

Items.Skins = {
	Classic = {
		id = "Classic",
		name = "Classic Sack",
		rarity = "Starter",
		color = Color3.fromRGB(220, 60, 70),
		material = Enum.Material.Fabric,
		transparency = 0,
	} :: SackSkin,
	Disco = {
		id = "Disco",
		name = "Disco Sack",
		rarity = "Rare",
		color = Color3.fromRGB(255, 255, 255),
		material = Enum.Material.Neon,
		transparency = 0,
		cycleColors = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(80, 220, 120),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(220, 80, 220),
		},
		cycleSpeed = 1.5,
	} :: SackSkin,
	Glitter = {
		id = "Glitter",
		name = "Glitter Sack",
		rarity = "Event",
		color = Color3.fromRGB(245, 220, 90),
		material = Enum.Material.Neon,
		transparency = 0.05,
	} :: SackSkin,
	Flame = {
		id = "Flame",
		name = "Flame Sack",
		rarity = "Rare",
		color = Color3.fromRGB(255, 110, 40),
		material = Enum.Material.Neon,
		transparency = 0,
		cycleColors = {
			Color3.fromRGB(255, 80, 30),
			Color3.fromRGB(255, 200, 80),
			Color3.fromRGB(255, 60, 0),
		},
		cycleSpeed = 4,
	} :: SackSkin,
	Frozen = {
		id = "Frozen",
		name = "Frozen Sack",
		rarity = "Rare",
		color = Color3.fromRGB(160, 230, 255),
		material = Enum.Material.Glass,
		transparency = 0.15,
	} :: SackSkin,
	Void = {
		id = "Void",
		name = "Void Sack",
		rarity = "Event",
		color = Color3.fromRGB(40, 10, 60),
		material = Enum.Material.Neon,
		transparency = 0.2,
		cycleColors = {
			Color3.fromRGB(40, 10, 60),
			Color3.fromRGB(120, 20, 200),
			Color3.fromRGB(20, 0, 40),
		},
		cycleSpeed = 0.6,
	} :: SackSkin,
}

function Items.getItem(id: string): Item?
	return Items.Items[id]
end

function Items.getSkin(id: string): SackSkin?
	return Items.Skins[id]
end

function Items.itemsForSlot(slot: string): { Item }
	local out = {}
	for _, item in Items.Items do
		if item.slot == slot then
			table.insert(out, item)
		end
	end
	return out
end

function Items.allSkins(): { SackSkin }
	local out = {}
	for _, s in Items.Skins do
		table.insert(out, s)
	end
	return out
end

return Items
