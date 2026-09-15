--!strict

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

local ROOT_NAME = "LeMorneStormResort"

local palette = {
	stone = Color3.fromRGB(54, 58, 56),
	stoneLight = Color3.fromRGB(105, 103, 92),
	timber = Color3.fromRGB(91, 61, 42),
	cream = Color3.fromRGB(218, 207, 181),
	teal = Color3.fromRGB(26, 88, 88),
	emergency = Color3.fromRGB(240, 83, 52),
	vegetation = Color3.fromRGB(35, 82, 48),
	ocean = Color3.fromRGB(20, 55, 72),
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.Size = size
	item.Position = position
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function label(facePart: BasePart, text: string, face: Enum.NormalId?)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Signage"
	surface.Face = face or Enum.NormalId.Front
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0.25
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 36
	surface.Parent = facePart
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = text
	textLabel.TextColor3 = Color3.fromRGB(244, 238, 217)
	textLabel.TextScaled = true
	textLabel.TextStrokeColor3 = Color3.fromRGB(17, 24, 25)
	textLabel.TextStrokeTransparency = 0.35
	textLabel.Parent = surface
end

local function wall(parent: Instance, position: Vector3, size: Vector3)
	return part(parent, "VolcanicStoneWall", size, position, palette.stone, Enum.Material.Slate)
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	yaw: number
): WedgePart
	local item = Instance.new("WedgePart")
	item.Name = name
	item.Anchored = true
	item.Size = size
	item.Position = position
	item.Orientation = Vector3.new(0, yaw, 0)
	item.Color = Color3.fromRGB(25, 35, 38)
	item.Material = Enum.Material.Rock
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function addLight(
	parent: Instance,
	position: Vector3,
	color: Color3,
	range: number,
	emergency: boolean?
)
	local fixture = part(
		parent,
		if emergency then "EmergencyLight" else "HouseLight",
		Vector3.new(1.6, 0.3, 0.6),
		position,
		color,
		Enum.Material.Neon
	)
	fixture.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = range
	light.Shadows = true
	light.Parent = fixture
end

local function addRoom(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector2,
	openSide: string?
)
	local room = Instance.new("Model")
	room.Name = name
	room.Parent = parent
	part(
		room,
		"Floor",
		Vector3.new(size.X, 1, size.Y),
		center,
		palette.cream,
		Enum.Material.Limestone
	)
	local height = 12
	local ceiling = part(
		room,
		"Ceiling",
		Vector3.new(size.X - 1, 0.6, size.Y - 1),
		center + Vector3.new(0, height + 0.3, 0),
		Color3.fromRGB(43, 54, 53),
		Enum.Material.Slate
	)
	ceiling.CastShadow = true
	local gap = 8
	local horizontalSegment = math.max(2, (size.X - gap) / 2)
	local horizontalOffset = gap / 2 + horizontalSegment / 2
	local verticalSegment = math.max(2, (size.Y - gap) / 2)
	local verticalOffset = gap / 2 + verticalSegment / 2
	if openSide ~= "North" then
		wall(
			room,
			center + Vector3.new(-horizontalOffset, height / 2, -size.Y / 2),
			Vector3.new(horizontalSegment, height, 1)
		)
		wall(
			room,
			center + Vector3.new(horizontalOffset, height / 2, -size.Y / 2),
			Vector3.new(horizontalSegment, height, 1)
		)
	end
	if openSide ~= "South" then
		wall(
			room,
			center + Vector3.new(-horizontalOffset, height / 2, size.Y / 2),
			Vector3.new(horizontalSegment, height, 1)
		)
		wall(
			room,
			center + Vector3.new(horizontalOffset, height / 2, size.Y / 2),
			Vector3.new(horizontalSegment, height, 1)
		)
	end
	if openSide ~= "West" then
		wall(
			room,
			center + Vector3.new(-size.X / 2, height / 2, -verticalOffset),
			Vector3.new(1, height, verticalSegment)
		)
		wall(
			room,
			center + Vector3.new(-size.X / 2, height / 2, verticalOffset),
			Vector3.new(1, height, verticalSegment)
		)
	end
	if openSide ~= "East" then
		wall(
			room,
			center + Vector3.new(size.X / 2, height / 2, -verticalOffset),
			Vector3.new(1, height, verticalSegment)
		)
		wall(
			room,
			center + Vector3.new(size.X / 2, height / 2, verticalOffset),
			Vector3.new(1, height, verticalSegment)
		)
	end
	return room
end

local function addHiding(
	parent: Instance,
	id: string,
	position: Vector3,
	capacity: number,
	kind: string,
	facing: number?
)
	local model = Instance.new("Model")
	model.Name = `{kind}_{id}`
	model:SetAttribute("HidingId", id)
	model:SetAttribute("Capacity", capacity)
	model.Parent = parent
	local anchor = part(
		model,
		"Interaction",
		Vector3.new(4.8, 7, 2.8),
		position + Vector3.new(0, 3.5, 0),
		palette.timber,
		Enum.Material.WoodPlanks
	)
	anchor.Transparency = 0.08
	anchor.CFrame *= CFrame.Angles(0, math.rad(facing or 0), 0)
	model.PrimaryPart = anchor
	local trim = part(
		model,
		"BrassTrim",
		Vector3.new(5.1, 0.25, 3.05),
		position + Vector3.new(0, 7, 0),
		Color3.fromRGB(171, 136, 72),
		Enum.Material.Metal
	)
	trim.CanCollide = false
	local hidden = part(
		model,
		"HiddenPoint",
		Vector3.new(1, 1, 1),
		position + Vector3.new(0, 2.5, 0),
		Color3.new(1, 1, 1)
	)
	hidden.Transparency = 1
	hidden.CanCollide = false
	local approach = part(
		model,
		"HunterApproach",
		Vector3.new(1, 1, 1),
		position + Vector3.new(0, 0.5, 5),
		Color3.new(1, 0, 0)
	)
	approach.Transparency = 1
	approach.CanCollide = false
	local peek = part(
		model,
		"PeekPoint",
		Vector3.new(1, 1, 1),
		position + Vector3.new(0, 4.7, 0) + anchor.CFrame.LookVector * 2.2,
		Color3.new(0, 1, 1)
	)
	peek.CFrame = CFrame.lookAt(peek.Position, peek.Position + anchor.CFrame.LookVector * 12)
	peek.Transparency = 1
	peek.CanCollide = false
	CollectionService:AddTag(model, "HideHidingSpot")
end

local function addDoor(parent: Instance, id: string, position: Vector3, yaw: number?)
	local model = Instance.new("Model")
	model.Name = `ServiceDoor_{id}`
	model:SetAttribute("DoorId", id)
	model.Parent = parent
	local panel = part(
		model,
		"DoorPanel",
		Vector3.new(6, 9, 0.8),
		position + Vector3.new(0, 4.5, 0),
		palette.teal,
		Enum.Material.Metal
	)
	panel.CFrame *= CFrame.Angles(0, math.rad(yaw or 0), 0)
	model.PrimaryPart = panel
	local openPoint = part(
		model,
		"OpenPoint",
		Vector3.new(1, 1, 1),
		panel.Position + panel.CFrame.RightVector * 5,
		Color3.new(1, 1, 1)
	)
	openPoint.Transparency = 1
	openPoint.CanCollide = false
	CollectionService:AddTag(model, "HideDoor")
end

local function addPatrolPoint(parent: Instance, name: string, position: Vector3)
	local point = part(parent, name, Vector3.new(1, 1, 1), position, Color3.new(1, 1, 1))
	point.Transparency = 1
	point.CanCollide = false
	CollectionService:AddTag(point, "HidePatrolPoint")
end

local function addFlag(parent: Instance, position: Vector3)
	part(
		parent,
		"FlagPole",
		Vector3.new(0.35, 18, 0.35),
		position,
		Color3.fromRGB(180, 180, 180),
		Enum.Material.Metal
	)
	local colors = {
		Color3.fromRGB(234, 40, 57),
		Color3.fromRGB(27, 60, 142),
		Color3.fromRGB(255, 211, 0),
		Color3.fromRGB(0, 161, 81),
	}
	for index, color in ipairs(colors) do
		local stripe = part(
			parent,
			`MauritiusFlagStripe{index}`,
			Vector3.new(5, 0.75, 0.12),
			position + Vector3.new(2.6, 7.85 - index * 0.75, 0),
			color,
			Enum.Material.Fabric
		)
		stripe.CanCollide = false
	end
end

local function addPalm(parent: Instance, position: Vector3, height: number)
	local trunk = part(
		parent,
		"PalmTrunk",
		Vector3.new(1.1, height, 1.1),
		position + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(105, 76, 48),
		Enum.Material.Wood
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	for index = 1, 6 do
		local leaf = part(
			parent,
			"PalmFrond",
			Vector3.new(0.5, 0.3, 8),
			position + Vector3.new(0, height, 0),
			palette.vegetation,
			Enum.Material.Grass
		)
		leaf.CanCollide = false
		leaf.CFrame = CFrame.new(position + Vector3.new(0, height, 0))
			* CFrame.Angles(math.rad(-18), math.rad((index - 1) * 60), 0)
	end
end

local function addFilao(parent: Instance, position: Vector3, height: number)
	local trunk = part(
		parent,
		"FilaoTrunk",
		Vector3.new(0.7, height, 0.7),
		position + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(82, 66, 49),
		Enum.Material.Wood
	)
	trunk.CanCollide = false
	for index = 1, 7 do
		local tier = index / 7
		local crown = part(
			parent,
			"FilaoNeedles",
			Vector3.new(6.5 * (1 - tier * 0.45), 0.35, 6.5 * (1 - tier * 0.45)),
			position + Vector3.new(0, height * (0.42 + tier * 0.08), 0),
			Color3.fromRGB(36, 72, 49),
			Enum.Material.Grass
		)
		crown.Shape = Enum.PartType.Cylinder
		crown.CanCollide = false
	end
end

local function addRavenala(parent: Instance, position: Vector3, height: number)
	part(
		parent,
		"RavenalaTrunk",
		Vector3.new(1, height * 0.55, 1),
		position + Vector3.new(0, height * 0.275, 0),
		Color3.fromRGB(105, 83, 54),
		Enum.Material.Wood
	).CanCollide =
		false
	for index = -3, 3 do
		local leaf = part(
			parent,
			"TravellersPalmLeaf",
			Vector3.new(2.3, 0.3, 8),
			position + Vector3.new(0, height * 0.58, 0),
			Color3.fromRGB(47, 111, 62),
			Enum.Material.Grass
		)
		leaf.CFrame = CFrame.new(position + Vector3.new(0, height * 0.58, 0))
			* CFrame.Angles(math.rad(-18 - math.abs(index) * 4), math.rad(index * 14), 0)
		leaf.CanCollide = false
	end
end

local function addListener(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "TheListener"
	model.Parent = parent
	local root = part(
		model,
		"HumanoidRootPart",
		Vector3.new(2.2, 3, 1.6),
		position + Vector3.new(0, 3, 0),
		Color3.fromRGB(16, 18, 20),
		Enum.Material.SmoothPlastic
	)
	root.Anchored = false
	root.Transparency = 1
	root.CanCollide = true
	local body = part(
		model,
		"ListenerBody",
		Vector3.new(3.6, 7, 2),
		position + Vector3.new(0, 4.4, 0),
		Color3.fromRGB(22, 25, 27),
		Enum.Material.Fabric
	)
	body.Anchored = false
	body.CanCollide = false
	body.Shape = Enum.PartType.Block
	local head = part(
		model,
		"Head",
		Vector3.new(2.8, 2.2, 2.8),
		position + Vector3.new(0, 8.6, 0),
		Color3.fromRGB(42, 44, 41),
		Enum.Material.Slate
	)
	head.Anchored = false
	head.CanCollide = false
	for _, visual in ipairs({ body, head }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = visual
		weld.Parent = visual
	end
	for side = -1, 1, 2 do
		local ear = part(
			model,
			"ListeningFin",
			Vector3.new(0.35, 3.2, 2.2),
			position + Vector3.new(side * 2, 9, 0),
			palette.emergency,
			Enum.Material.Neon
		)
		ear.Anchored = false
		ear.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = ear
		weld.Parent = ear
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HipHeight = 1.5
	humanoid.WalkSpeed = 14
	-- The Listener is an original welded rig, not an R6/R15 avatar. Without this,
	-- Roblox eventually kills the Humanoid because the rig intentionally has no Neck Motor6D.
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model.PrimaryPart = root
	CollectionService:AddTag(model, "HideHunter")
end

local function configureLighting()
	Lighting.ClockTime = 17.72
	Lighting.Brightness = 2.05
	Lighting.Ambient = Color3.fromRGB(70, 82, 86)
	Lighting.OutdoorAmbient = Color3.fromRGB(80, 92, 96)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.08
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "CycloneAtmosphere"
	atmosphere.Color = Color3.fromRGB(134, 158, 166)
	atmosphere.Decay = Color3.fromRGB(48, 62, 68)
	atmosphere.Density = 0.42
	atmosphere.Haze = 2.2
	atmosphere.Glare = 0.05
	atmosphere.Parent = Lighting
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		or Instance.new("ColorCorrectionEffect")
	correction.Name = "StormGrade"
	correction.TintColor = Color3.fromRGB(181, 204, 204)
	correction.Contrast = 0.12
	correction.Saturation = -0.18
	correction.Parent = Lighting
end

function WorldBuilder.Build(): Model
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing ~= nil and existing:IsA("Model") then
		return existing
	end
	configureLighting()
	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	root:SetAttribute("Source", "GitHub/Rojo WorldBuilder")
	root:SetAttribute("MapId", "mauritius-le-morne-storm-resort")
	root.Parent = Workspace

	part(
		root,
		"ResortGround",
		Vector3.new(210, 2, 160),
		Vector3.new(0, -1, 0),
		palette.stoneLight,
		Enum.Material.Slate
	)
	part(
		root,
		"StormIndianOcean",
		Vector3.new(210, 1, 85),
		Vector3.new(0, -1.5, -120),
		palette.ocean,
		Enum.Material.Water
	)
	local lobby =
		addRoom(root, "ArrivalReception", Vector3.new(0, 0, 40), Vector2.new(54, 34), "South")
	local sign = part(
		lobby,
		"ReceptionSign",
		Vector3.new(28, 3.4, 0.5),
		Vector3.new(0, 9.4, 23.65),
		palette.teal,
		Enum.Material.WoodPlanks
	)
	label(sign, "LE MORNE  •  MAURITIUS", Enum.NormalId.Back)
	local identityFlag = Instance.new("Model")
	identityFlag.Name = "LobbyMauritiusFlag"
	identityFlag.Parent = lobby
	for index, color in ipairs({
		Color3.fromRGB(234, 40, 57),
		Color3.fromRGB(27, 60, 142),
		Color3.fromRGB(255, 211, 0),
		Color3.fromRGB(0, 161, 81),
	}) do
		local stripe = part(
			identityFlag,
			`Stripe{index}`,
			Vector3.new(5.8, 0.55, 0.16),
			Vector3.new(-19, 8.5 - index * 0.55, 23.65),
			color,
			Enum.Material.Fabric
		)
		stripe.CanCollide = false
	end
	local guestWing =
		addRoom(root, "GuestWing", Vector3.new(-55, 0, 4), Vector2.new(62, 34), "East")
	local lounge =
		addRoom(root, "RestaurantLounge", Vector3.new(53, 0, 6), Vector2.new(52, 38), "West")
	local kitchen =
		addRoom(root, "KitchenService", Vector3.new(51, 0, -33), Vector2.new(48, 30), "North")
	local maintenance =
		addRoom(root, "LaundryMaintenance", Vector3.new(-48, 0, -35), Vector2.new(56, 30), "North")
	local generator =
		addRoom(root, "GeneratorRoom", Vector3.new(0, 0, -61), Vector2.new(34, 24), "North")
	local guestFloor = guestWing:FindFirstChild("Floor") :: BasePart
	guestFloor.Material = Enum.Material.Carpet
	guestFloor.Color = Color3.fromRGB(75, 91, 84)
	local loungeFloor = lounge:FindFirstChild("Floor") :: BasePart
	loungeFloor.Material = Enum.Material.WoodPlanks
	loungeFloor.Color = Color3.fromRGB(116, 82, 55)
	for _, serviceRoom in ipairs({ kitchen, maintenance, generator }) do
		local serviceFloor = serviceRoom:FindFirstChild("Floor") :: BasePart
		serviceFloor.Material = Enum.Material.DiamondPlate
		serviceFloor.Color = Color3.fromRGB(83, 89, 88)
	end
	part(
		root,
		"CoveredWalkway",
		Vector3.new(28, 1, 86),
		Vector3.new(0, 0, -9),
		palette.cream,
		Enum.Material.Limestone
	)
	-- Corridor walls turn the central spine into chase geometry instead of an open plaza.
	for _, spec in ipairs({
		{ Vector3.new(-13.5, 6, 10), Vector3.new(1, 12, 30) },
		{ Vector3.new(13.5, 6, 10), Vector3.new(1, 12, 30) },
		{ Vector3.new(-13.5, 6, -34), Vector3.new(1, 12, 20) },
		{ Vector3.new(13.5, 6, -34), Vector3.new(1, 12, 20) },
		{ Vector3.new(-43, 6, 4), Vector3.new(1, 12, 22) },
		{ Vector3.new(-58, 6, 4), Vector3.new(1, 12, 22) },
		{ Vector3.new(45, 6, 6), Vector3.new(1, 12, 24) },
		{ Vector3.new(60, 6, 6), Vector3.new(1, 12, 24) },
	}) do
		wall(root, spec[1] :: Vector3, spec[2] :: Vector3)
	end
	for _, spec in ipairs({
		{ "LobbySofa", Vector3.new(12, 3, 4), Vector3.new(10, 1.5, 36) },
		{ "ReceptionDesk", Vector3.new(14, 4, 2), Vector3.new(-7, 2, 29) },
		{ "KitchenIsland", Vector3.new(12, 4, 5), Vector3.new(51, 2, -33) },
		{ "LaundryStack", Vector3.new(8, 6, 4), Vector3.new(-48, 3, -34) },
		{ "ServiceCrates", Vector3.new(7, 5, 6), Vector3.new(4, 2.5, -35) },
	}) do
		part(
			root,
			spec[1] :: string,
			spec[2] :: Vector3,
			spec[3] :: Vector3,
			palette.timber,
			Enum.Material.WoodPlanks
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalSpawn"
	spawn.Size = Vector3.new(12, 1, 8)
	spawn.Position = Vector3.new(0, 1, 48)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 0.25
	spawn.Color = palette.teal
	spawn.Parent = root
	local spectatorCamera = part(
		root,
		"SpectatorCamera",
		Vector3.new(1, 1, 1),
		Vector3.new(0, 48, 92),
		Color3.new(1, 1, 1)
	)
	spectatorCamera.Transparency = 1
	spectatorCamera.CanCollide = false
	spectatorCamera.CFrame = CFrame.lookAt(spectatorCamera.Position, Vector3.new(0, 3, 0))
	local spectatorSpawn = part(
		root,
		"SpectatorSpawn",
		Vector3.new(8, 1, 8),
		Vector3.new(0, 13, 40),
		Color3.new(1, 1, 1)
	)
	spectatorSpawn.Transparency = 1
	spectatorSpawn.CanCollide = false

	local phone = part(
		root,
		"ReceptionPhone",
		Vector3.new(1.3, 0.5, 1.2),
		Vector3.new(-7, 4.25, 29),
		Color3.fromRGB(34, 35, 33),
		Enum.Material.SmoothPlastic
	)
	phone.CanCollide = false
	local generatorEvent = part(
		root,
		"GeneratorEventPoint",
		Vector3.new(1, 1, 1),
		Vector3.new(0, 2, -61),
		Color3.new(1, 1, 1)
	)
	generatorEvent.Transparency = 1
	generatorEvent.CanCollide = false

	local hidingSpecs = {
		{ "lobby-linen", Vector3.new(-19, 0.5, 32), 2, "LinenCloset", 0 },
		{ "lounge-cabinet", Vector3.new(62, 0.5, 10), 1, "Cabinet", 90 },
		{ "suite-wardrobe", Vector3.new(-68, 0.5, 10), 2, "Wardrobe", 0 },
		{ "guest-linen", Vector3.new(-75, 0.5, -7), 3, "LinenCloset", 90 },
		{ "kitchen-dry-store", Vector3.new(62, 0.5, -40), 1, "DryStore", 180 },
		{ "maintenance-locker", Vector3.new(-34, 0.5, -42), 1, "UtilityLocker", 0 },
	}
	for _, spec in ipairs(hidingSpecs) do
		addHiding(
			root,
			spec[1] :: string,
			spec[2] :: Vector3,
			spec[3] :: number,
			spec[4] :: string,
			spec[5] :: number
		)
	end

	-- Each brace panel occupies the eight-stud opening authored by addRoom.
	addDoor(root, "guest-service", Vector3.new(-86, 0, 4), 90)
	addDoor(root, "kitchen-service", Vector3.new(51, 0, -18), 0)
	addDoor(root, "generator-firedoor", Vector3.new(0, 0, -49), 0)
	-- Seal the unused generator-side opening so the fire door is the route.
	wall(root, Vector3.new(0, 6, -73), Vector3.new(34, 12, 1))

	local extraction = part(
		root,
		"StormEvacuationGate",
		Vector3.new(18, 10, 1),
		Vector3.new(0, 5, 72),
		palette.emergency,
		Enum.Material.Metal
	)
	extraction:SetAttribute("ExtractionId", "arrival-evacuation-gate")
	label(extraction, "CYCLONE EVACUATION  •  SORTIE / EXIT / SORTI", Enum.NormalId.Front)
	CollectionService:AddTag(extraction, "HideExtraction")
	local serviceExtraction = part(
		root,
		"ServiceCoastGate",
		Vector3.new(1, 10, 16),
		Vector3.new(-102, 5, -20),
		palette.emergency,
		Enum.Material.Metal
	)
	serviceExtraction:SetAttribute("ExtractionId", "service-coast-gate")
	label(serviceExtraction, "SORTI  •  SERVICE COAST EXIT", Enum.NormalId.Right)
	CollectionService:AddTag(serviceExtraction, "HideExtraction")

	for index, position in ipairs({
		Vector3.new(0, 2, 38),
		Vector3.new(-52, 2, 5),
		Vector3.new(52, 2, 4),
		Vector3.new(48, 2, -34),
		Vector3.new(-48, 2, -34),
		Vector3.new(0, 2, -57),
		Vector3.new(0, 2, 5),
		Vector3.new(0, 2, 59),
	}) do
		addPatrolPoint(root, `Patrol{index}`, position)
	end

	addFlag(root, Vector3.new(-12, 9, 68))
	addFlag(root, Vector3.new(12, 9, 68))
	for _, position in ipairs({
		Vector3.new(-88, 0, 63),
		Vector3.new(88, 0, 55),
		Vector3.new(-91, 0, -15),
		Vector3.new(91, 0, -28),
	}) do
		addPalm(root, position, 16)
	end
	for _, position in ipairs({
		Vector3.new(-95, 0, -92),
		Vector3.new(-72, 0, -105),
		Vector3.new(75, 0, -105),
		Vector3.new(96, 0, -86),
	}) do
		addFilao(root, position, 18)
	end
	for _, position in ipairs({
		Vector3.new(-28, 0, 58),
		Vector3.new(30, 0, 55),
		Vector3.new(78, 0, 31),
	}) do
		addRavenala(root, position, 15)
	end
	local chimney = part(
		root,
		"SugarMillChimney",
		Vector3.new(5, 42, 5),
		Vector3.new(92, 20, -142),
		Color3.fromRGB(78, 69, 61),
		Enum.Material.Brick
	)
	chimney.CanCollide = false
	local busShelter = part(
		root,
		"MauritianBusShelterRoof",
		Vector3.new(15, 0.8, 5),
		Vector3.new(-79, 6, 69),
		palette.teal,
		Enum.Material.Metal
	)
	busShelter.CanCollide = false
	local dodoSign = part(
		root,
		"DodoMotif",
		Vector3.new(5, 4, 0.4),
		Vector3.new(-20, 5, 23.6),
		palette.teal,
		Enum.Material.WoodPlanks
	)
	label(dodoSign, "DODO  •  RAVINALA NOIR", Enum.NormalId.Back)

	local mountain = Instance.new("Model")
	mountain.Name = "LeMorneSilhouette"
	mountain.Parent = root
	part(
		mountain,
		"LeMorneBase",
		Vector3.new(158, 20, 34),
		Vector3.new(0, 9, -174),
		Color3.fromRGB(25, 35, 38),
		Enum.Material.Rock
	)
	wedge(mountain, "LeMorneWestSlope", Vector3.new(34, 54, 76), Vector3.new(-47, 33, -174), 90)
	wedge(mountain, "LeMorneEastSlope", Vector3.new(34, 49, 82), Vector3.new(44, 30, -174), -90)
	local monolith = part(
		mountain,
		"LeMorneMonolith",
		Vector3.new(68, 50, 35),
		Vector3.new(-13, 49, -175),
		Color3.fromRGB(25, 35, 38),
		Enum.Material.Rock
	)
	monolith.Orientation = Vector3.new(0, 0, 2)
	local summit = part(
		mountain,
		"LeMorneSummitPlateau",
		Vector3.new(50, 6, 35),
		Vector3.new(-18, 76, -175),
		Color3.fromRGB(25, 35, 38),
		Enum.Material.Rock
	)
	summit.Orientation = Vector3.new(0, 0, 1)
	wedge(
		mountain,
		"LeMorneFrontRidgeWest",
		Vector3.new(26, 36, 38),
		Vector3.new(-38, 37, -157),
		90
	)
	wedge(
		mountain,
		"LeMorneFrontRidgeEast",
		Vector3.new(22, 31, 36),
		Vector3.new(25, 31, -157),
		-90
	)
	local basaltFace = part(
		mountain,
		"LeMorneBasaltFace",
		Vector3.new(42, 32, 4),
		Vector3.new(-15, 52, -156),
		Color3.fromRGB(31, 43, 43),
		Enum.Material.Rock
	)
	basaltFace.Orientation = Vector3.new(0, 0, 3)

	for _, position in ipairs({
		Vector3.new(0, 10, 37),
		Vector3.new(-52, 10, 5),
		Vector3.new(52, 10, 3),
		Vector3.new(0, 10, -36),
		Vector3.new(0, 10, -58),
	}) do
		addLight(root, position, palette.emergency, 25, true)
	end
	for _, position in ipairs({
		Vector3.new(0, 9, 46),
		Vector3.new(-55, 9, 4),
		Vector3.new(53, 9, 6),
		Vector3.new(51, 9, -33),
		Vector3.new(-48, 9, -35),
		Vector3.new(0, 9, -61),
	}) do
		addLight(root, position, Color3.fromRGB(190, 210, 201), 32, false)
	end
	addListener(root, Vector3.new(0, 2, -57))
	return root
end

return WorldBuilder
