local PROFILE_TEMPLATE = require(script.Parent.ProfileTemplate)
local CURRENT_VERSION = "V1.2"

return {
	DataStoreVersion = CURRENT_VERSION,
	ProfileTemplate = PROFILE_TEMPLATE[CURRENT_VERSION],
	
	AutoSaveProfiles = true,
	AutoSaveProfilesDelay = 60,
	
	Verbose = true,
	SendClientAutoSaveMessages = true,
}