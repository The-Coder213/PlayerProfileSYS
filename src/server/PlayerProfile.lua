-- PlayerProfile.lua
local PlayerProfile = {}
PlayerProfile.Profiles = {}
PlayerProfile._Started = false
PlayerProfile.__index = PlayerProfile

local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerDataStore")
local Settings = require(script.Parent.Settings)

-- Utility functions
local function deepCopy(tbl)
	local copy = {}
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function migrateData(currentData, newData)
	for key, value in pairs(newData) do
		if currentData[key] == nil then
			if type(value) == "table" then
				currentData[key] = deepCopy(value)
			else
				currentData[key] = value
			end
		end
	end
	return currentData
end

local function newPrint(msg)
	if Settings.Verbose then
		print("🟢 [PlayerProfile] " .. msg)
	end
end

local function newWarn(msg)
	warn("🟡 [PlayerProfile] " .. msg)
end

-- Stats management
function PlayerProfile:AddStat(name, value)
	if self.Data[name] ~= nil then
		newWarn("Stat '" .. name .. "' already exists")
		return
	end
	if name == "_V" then
		newWarn("_V cannot be used as a stat")
		return
	end

	newPrint("Adding stat '" .. name .. "' for " .. self.Player.Name)
	self.Data[name] = value

	local newBindable = Instance.new("BindableEvent")
	newBindable.Name = name
	self.DataEvents[name] = newBindable
end

function PlayerProfile:SetStat(name, value)
	if self.Data[name] == nil then
		newWarn("Stat '" .. name .. "' does not exist")
		return
	end
	if name == "_V" then
		newWarn("_V cannot be modified")
		return
	end

	local old = self.Data[name]
	self.Data[name] = value
	newPrint(
		"Changed stat '"
			.. name
			.. "' from ["
			.. tostring(old)
			.. "] to ["
			.. tostring(value)
			.. "] for "
			.. self.Player.Name
	)

	local bindable = self.DataEvents[name]
	if not bindable then
		bindable = Instance.new("BindableEvent")
		bindable.Name = name
		self.DataEvents[name] = bindable
	end
	bindable:Fire(value, old)
end

function PlayerProfile:OnStatChanged(statName, callback)
	if self.DataEvents[statName] then
		return self.DataEvents[statName].Event:Connect(callback)
	else
		newWarn("No event exists for stat '" .. statName .. "'")
		return
	end
end

-- Load / Save
function PlayerProfile:LoadData()
	newPrint("Loading data for " .. self.Player.Name .. "...")
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(tostring(self.Player.UserId))
	end)

	if not success then
		newWarn("Failed to load data: " .. data)
		return
	end

	if data then
		newPrint("Data found for " .. self.Player.Name)
		if data._V ~= Settings.DataStoreVersion then
			newPrint("Migrating outdated data for " .. self.Player.Name)
			data = migrateData(data, Settings.ProfileTemplate)
			data._V = Settings.DataStoreVersion
			self._V = data._V
		else
			newPrint("Data version OK for " .. self.Player.Name)
			self._V = data._V
		end

		for name, val in pairs(data) do
			if name ~= "_V" then
				self:AddStat(name, val)
			end
		end
	else
		newPrint("No data found — creating default data for " .. self.Player.Name)
		for name, val in pairs(Settings.ProfileTemplate) do
			self:AddStat(name, val)
		end
		self._V = Settings.DataStoreVersion
	end

	newPrint("✅ Successfully loaded data for " .. self.Player.Name)
	self.Data._V = self._V
	self:FireEvent("Loaded")
end

function PlayerProfile:SaveData()
	local dataBlob = deepCopy(self.Data)
	dataBlob._V = self._V
	newPrint("Saving data for " .. self.Player.Name .. "...")

	local success, err = pcall(function()
		PlayerDataStore:UpdateAsync(tostring(self.Player.UserId), function(old)
			old = old or {}
			for k, v in pairs(dataBlob) do
				old[k] = v
			end
			return old
		end)
	end)

	if success then
		newPrint("✅ Successfully saved data for " .. self.Player.Name)
	else
		newWarn("Failed to save data: " .. err)
	end
end

-- Events
function PlayerProfile:FireEvent(eventName, ...)
	local event = self.ProfileEvents[eventName]
	if event then
		event:Fire(...)
	end
end

function PlayerProfile:OnEvent(eventName, callback)
	if not self.ProfileEvents[eventName] then
		local newBindable = Instance.new("BindableEvent")
		self.ProfileEvents[eventName] = newBindable
	end
	return self.ProfileEvents[eventName].Event:Connect(callback)
end

function PlayerProfile:_initEvent(name)
	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Name = name
	self.ProfileEvents[name] = bindableEvent
	return bindableEvent
end

-- Profile creation
function PlayerProfile.new(player)
	newPrint("Creating profile for " .. player.Name)
	local self = setmetatable({}, PlayerProfile)

	self.Player = player
	self.Character = player.Character or player.CharacterAdded:Wait()
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.Root = self.Character:WaitForChild("HumanoidRootPart")

	self.Connections = {}
	self.Data = {}
	self.DataEvents = {}
	self.ProfileEvents = {}
	self:_initEvent("Loaded")
	self._V = nil

	task.defer(function()
		self:LoadData()
	end)

	self.Connections["CharacterReset"] = player.CharacterAdded:Connect(function(character)
		self.Character = character
		self.Humanoid = character:WaitForChild("Humanoid")
		self.Root = character:WaitForChild("HumanoidRootPart")
	end)

	self.Connections["PlayerLeaving"] = game.Players.PlayerRemoving:Connect(function(plr)
		if plr == self.Player then
			newPrint("Player leaving — saving " .. plr.Name)
			self:SaveData()
			self._AutosaveRunning = false

			for _, connection in pairs(self.Connections) do
				if typeof(connection) == "RBXScriptConnection" then
					connection:Disconnect()
				end
			end

			for _, bindable in pairs(self.DataEvents) do
				bindable:Destroy()
			end

			for _, bindable in pairs(self.ProfileEvents) do
				bindable:Destroy()
			end

			newPrint("Destroyed profile for " .. plr.Name)
			PlayerProfile.Profiles[plr.UserId] = nil
			table.clear(self)
			setmetatable(self, nil)
		end
	end)

	if Settings.AutoSaveProfiles then
		self._AutosaveRunning = true
		task.spawn(function()
			while self._AutosaveRunning and self.Player.Parent do
				task.wait(Settings.AutoSaveProfilesDelay)
				if self._AutosaveRunning then
					newPrint("Autosaving profile for " .. self.Player.Name)
					self:SaveData()
				end
			end
		end)
	end

	PlayerProfile.Profiles[player.UserId] = self
	newPrint("Finished creating profile for " .. player.Name)

	return self
end

function PlayerProfile.getPlayerProfile(plr)
	return PlayerProfile.Profiles[plr.UserId]
end

function PlayerProfile.Start()
	if PlayerProfile._Started then
		return
	end
	PlayerProfile._Started = true

	newPrint("PlayerProfile STARTED")

	game.Players.PlayerAdded:Connect(function(player)
		newPrint("Player joined: " .. player.Name)
		return PlayerProfile.new(player)
	end)

	game:BindToClose(function()
		newPrint("Server shutting down — saving all profiles")
		for _, profile in pairs(PlayerProfile.Profiles) do
			profile:SaveData()
		end
		task.wait(1)
	end)
end

return PlayerProfile
