local Inventory = require(script:WaitForChild("Inventory"))
local EquipController = require(script:WaitForChild("EquipController"))
local RoundManager = require(script:WaitForChild("RoundManager"))

print("[Sacktopia] server boot")
Inventory.start()
EquipController.start()
RoundManager.start()
