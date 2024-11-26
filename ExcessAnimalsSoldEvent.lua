ExcessAnimalsSoldEvent = {}
ExcessAnimalsSoldEvent_mt = Class(ExcessAnimalsSoldEvent, Event)

InitEventClass(ExcessAnimalsSoldEvent, "ExcessAnimalsSoldEvent")

function ExcessAnimalsSoldEvent.emptyNew()
    local self = Event.new(ExcessAnimalsSoldEvent_mt)
    return self
end

function ExcessAnimalsSoldEvent.new(amount, farmId, message)
    local self = ExcessAnimalsSoldEvent.emptyNew()
    self.amount = amount
    self.farmId = farmId
    self.message = message
    return self
end

function ExcessAnimalsSoldEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.amount)
    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteString(streamId, self.message)
end

function ExcessAnimalsSoldEvent:readStream(streamId, connection)
    self.amount = streamReadFloat32(streamId)
    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.message = streamReadString(streamId)
    self:run(connection)
end

function ExcessAnimalsSoldEvent:run(connection)
    if not connection:getIsServer() then
        g_currentMission:addMoney(self.amount, self.farmId, MoneyType.SOLD_ANIMALS, true)
        if g_currentMission:getFarmId() == self.farmId then
            g_currentMission.hud:showMoneyChange(MoneyType.SOLD_ANIMALS, self.message)
        end
    else
        g_messageCenter:publish(ExcessAnimalsSoldEvent.new(self.amount, self.farmid, self.message))
    end
end
