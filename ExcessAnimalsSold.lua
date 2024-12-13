-- This software is the intellectual property of Richard Petrosino (owner of
-- this LUA code) and GIANTS Software GmbH. (owner of the software this code
-- utelizes) as of December, 2024.
--
-- This work may be reproduced and/or redstributed for non-commercial purposes
-- with the written consent of the author, Richard Petrosino. This work may
-- be reproduced and/or redstributed by GIANTS Software GmbH. for any purpose.
-- The author can be contacted at: https://github.com/richpet9
ExcessAnimalsSold = {}
ExcessAnimalsSold.modName = g_currentModName
ExcessAnimalsSold.modDir = g_currentModDirectory
ExcessAnimalsSold._DEBUG_ = false

source(ExcessAnimalsSold.modDir .. 'ExcessAnimalsSoldEvent.lua')

-- Add this util function to AnimalCluster since we want to determine if an AnimalCluster will
-- reproduce without actually mutating the object.
function AnimalCluster:isReadyToReproduce()
    if self:getCanReproduce() then
        local subType = g_currentMission.animalSystem:getSubTypeByIndex(self:getSubTypeIndex())
        local reproductionDelta = self:getReproductionDelta(subType.reproductionDurationMonth)

        if reproductionDelta > 0 then
            local old = self.reproduction
            local next = old + reproductionDelta
            if next >= 100 then
                return true
            end
        end
    end
    return false
end

function ExcessAnimalsSold:onPeriodChanged()
    if self.isServer then
        local spec = self.spec_husbandryAnimals
        local totalNumAnimals = self:getNumOfAnimals()
        local freeSlots = math.max(spec.maxNumAnimals - totalNumAnimals, 0)
        local totalPrice = 0
        local totalAnimalsSold = 0

        for _, animalCluster in ipairs(spec.clusterSystem:getClusters()) do
            if animalCluster:isReadyToReproduce() then
                local numAnimalsToSell = math.max(animalCluster.numAnimals - freeSlots, 0)

                if numAnimalsToSell > 0 then
                    local singlePrice = g_currentMission.animalSystem:getAnimalBuyPrice(
                        animalCluster:getSubTypeIndex(), 0) -- 0 is the age.
                    local sellPrice = singlePrice * numAnimalsToSell

                    totalPrice = totalPrice + sellPrice
                    totalAnimalsSold = totalAnimalsSold + numAnimalsToSell
                end
            end
        end

        if totalPrice > 0 then
            local farmId = self:getOwnerFarmId()
            local animalTypeName = string.lower(spec.animalType.name)
            local excessAnimals = g_i18n:getText("rp_EXCESS_ANIMALS_SOLD", ExcessAnimalsSold.modDir)
            local message = ("%s - %d %s"):format(excessAnimals, totalAnimalsSold, animalTypeName)

            g_client:getServerConnection():sendEvent(
                ExcessAnimalsSoldEvent.new(totalPrice, farmId, message))
        end
    end
end
PlaceableHusbandryAnimals.onPeriodChanged = Utils.prependedFunction(
    PlaceableHusbandryAnimals.onPeriodChanged, ExcessAnimalsSold.onPeriodChanged)
