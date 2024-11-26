ExcessAnimalsSold = {}
ExcessAnimalsSold.modName = g_currentModName
ExcessAnimalsSold.modDir = g_currentModDirectory
ExcessAnimalsSold._DEBUG_ = true

ExcessAnimalsSold.sellPriceFactor = 0.5 -- Helps prevent money printing, adjust to liking.

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
                    local singlePrice = animalCluster:getSellPrice()
                    local feePrice = -animalCluster:getTranportationFee(numAnimalsToSell)
                    local sellPrice = (singlePrice * numAnimalsToSell) + feePrice
                    totalPrice = totalPrice + (sellPrice * ExcessAnimalsSold.sellPriceFactor)
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
