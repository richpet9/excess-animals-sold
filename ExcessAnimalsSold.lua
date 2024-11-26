ExcessAnimalsSold = {}
ExcessAnimalsSold.modName = g_currentModName
ExcessAnimalsSold.modDir = g_currentModDirectory
ExcessAnimalsSold._DEBUG_ = true

ExcessAnimalsSold.sellPriceFactor = 0.5 -- Helps prevent money printing, adjust to liking.

source(ExcessAnimalsSold.modDir .. 'ExcessAnimalsSoldEvent.lua')

-- Add this util function to AnimalCluster since we want to determine if an AnimalCluster will
-- reproduce this period without actually mutating the object.
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
        local animalClusters = spec.clusterSystem:getClusters()
        local totalSellPrice = 0
        local totalAnimalsSold = 0

        for _, animalCluster in ipairs(animalClusters) do
            animalCluster.updateFunctionsAlreadyCalled = false
            animalCluster.newAnimalsThisPeriod = 0

            if animalCluster:isReadyToReproduce() then
                if ExcessAnimalsSold._DEBUG_ then
                    print("[EAS] - Placeable calling our own update functions")
                end

                -- Our function only wants to handle the selling of extra animals, we do not want to handle setting the
                -- farm stats nor updating the animal count for the placeable. To do this, we store the new animals produced
                -- this period on AnimalCluster, and since _we_ called onPeriodChange() and updateReproduction() ourselves,
                -- we flag for the AnimalCluster to not call these again (via self.updateFunctionsAlreadyCalled) when the
                -- superFunc executes. Instead, we return the amount of animals produced this period (self.newAnimalsThisPeriod).
                animalCluster:onPeriodChanged()
                animalCluster.newAnimalsThisPeriod = animalCluster:updateReproduction()
                animalCluster.updateFunctionsAlreadyCalled = true

                local newAnimals = animalCluster.newAnimalsThisPeriod
                if newAnimals > 0 then
                    local numAnimalsToSell = newAnimals - freeSlots
                    local singlePrice = animalCluster:getSellPrice()
                    local feePrice = -animalCluster:getTranportationFee(numAnimalsToSell)
                    local sellPrice = (singlePrice * numAnimalsToSell) + feePrice
                    totalSellPrice = totalSellPrice +
                                         (sellPrice * ExcessAnimalsSold.sellPriceFactor)
                    totalAnimalsSold = totalAnimalsSold + numAnimalsToSell
                end
            end
        end

        if totalSellPrice > 0 then
            local farmId = self:getOwnerFarmId()
            local animalTypeName = string.lower(spec.animalType.name)
            local excessAnimals = g_i18n:getText("rp_EXCESS_ANIMALS_SOLD", ExcessAnimalsSold.modDir)
            local message = ("%s - %d %s"):format(excessAnimals, totalAnimalsSold, animalTypeName)

            g_client:getServerConnection():sendEvent(
                ExcessAnimalsSoldEvent.new(totalSellPrice, farmId, message))
        end
    end
end
PlaceableHusbandryAnimals.onPeriodChanged = Utils.prependedFunction(
    PlaceableHusbandryAnimals.onPeriodChanged, ExcessAnimalsSold.onPeriodChanged)

AnimalCluster.onPeriodChanged = Utils.overwrittenFunction(AnimalCluster.onPeriodChanged,
    function(self, superFunc)
        if ExcessAnimalsSold._DEBUG_ then
            print("[EAS] - AnimalCluster.onPeriodChanged, updateFunctionsAlreadyCalled=" ..
                      tostring(self.updateFunctionsAlreadyCalled))
        end

        if self.updateFunctionsAlreadyCalled then
            return
        end
        return superFunc(self)
    end)

AnimalCluster.updateReproduction = Utils.overwrittenFunction(AnimalCluster.updateReproduction,
    function(self, superFunc)
        if ExcessAnimalsSold._DEBUG_ then
            print("[EAS] - AnimalCluster.updateReproduction, updateFunctionsAlreadyCalled=" ..
                      tostring(self.updateFunctionsAlreadyCalled) .. ", newAnimalsThisPeriod=" ..
                      self.newAnimalsThisPeriod)
        end

        if self.updateFunctionsAlreadyCalled then
            return self.newAnimalsThisPeriod
        end
        return superFunc(self)
    end)

