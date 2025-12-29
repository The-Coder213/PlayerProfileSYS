# PlayerProfile System

A scalable, server-authoritative Roblox player data system with
versioned DataStore migration, stat events, and autosaving.

## Features
- Server-only data handling
- Versioned profile migration
- Autosave support
- Stat change events
- Clean OOP design

## Folder Structure
src/
  server/
    PlayerProfile.lua
    Settings.lua
    ProfileTemplate.lua
    run.server.lua

## Usage
1. Install with Rojo
2. Require `PlayerProfile`
3. Call `PlayerProfile.Start()`

## Example
```lua
local PlayerProfile = require(ServerScriptService.PlayerProfile)
PlayerProfile.Start()
