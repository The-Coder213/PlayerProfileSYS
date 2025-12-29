local PlayerProfile = require(script.Parent.PlayerProfile)

--local CoinsGiver = workspace.CoinsGiver
--local GemsGiver = workspace.GemsGiver

PlayerProfile.Start()

--CoinsGiver.ClickDetector.MouseClick:Connect(function(playerWhoClicked)
--	local playerProfile = PlayerProfile.getPlayerProfile(playerWhoClicked)
--	if playerProfile then
--		local currentCoins = playerProfile.Data.Coins or 0
--		playerProfile:SetStat("Coins", currentCoins + 10)
--	end
--end)

--GemsGiver.ClickDetector.MouseClick:Connect(function(playerWhoClicked)
--	local playerProfile = PlayerProfile.getPlayerProfile(playerWhoClicked)
--	if playerProfile then
--		local currentGems = playerProfile.Data.Gems or 0
--		playerProfile:SetStat("Gems", currentGems + 10)
--	end
--end)


game.Players.PlayerAdded:Connect(function(plr)
	local plrProfile = PlayerProfile.getPlayerProfile(plr)
	while not plrProfile do
		task.wait()
		plrProfile = PlayerProfile.getPlayerProfile(plr)
	end

	plrProfile:OnEvent("Loaded", function()
		warn("Player data loaded with name " .. plr.Name)
	end)
end)
