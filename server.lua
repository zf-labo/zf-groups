local Bridge = require 'bridge.server'
lib.locale()

Groups = {}
local JobQueue = {}

--[[
    JobQueue = {
        source = source,
        groupId = groupId,
        job = jobId,
        data = jobData
    }

    jobData = {
        event = 'event:to:trigger',
        eventType = 'server' or 'client',
        waiting = {1, 5} -- minutes to wait before triggering the event
    }
]]

local function progressQueue()
    for id,queue in pairs(JobQueue) do
        if queue then
            local group = Groups[queue.groupId]
            if group.id then
                if queue.time_waited >= queue.jobData.waiting then
                    if queue.eventType == 'server' then
                        TriggerEvent(queue.event, queue)
                    elseif queue.eventType == 'client' then
                        TriggerClientEvent(queue.event, queue.source, queue)
                    end
                    table.remove(JobQueue, id)
                else
                    queue.time_waited = (queue.time_waited or 0) + 1
                end
            end
        end
    end
    SetTimeout(60000, progressQueue)
end progressQueue()





-- ## CLASS ##

---@class Group : OxClass
Group = lib.class('Group')
function Group:constructor(playerId)
    local cid = Bridge.GetIdentifier(playerId)
    local name = Bridge.GetName(playerId)

    self.id = cid .. '-' .. math.random(1000,9999)
    self.owner = {
        source = playerId,
        citizenid = cid,
        name = name
    }
    self.members = { [cid] = self.owner }
    self.tasks = {}
    self.currentTask = nil
    self.job = nil
    self.job_label = nil
    self.data = {}

    return self
end

function Group:GetMembers()
    return self.members
end

function Group:GetSize()
    local size = 0
    for k,v in pairs(self.members) do size += 1 end
    return size
end

function Group:GetLeader()
    return self.owner
end

function Group:Destroy()
    local ids = {}
    for _,member in pairs(self.members) do table.insert(ids, member.source) end
    lib.triggerClientEvent('zf-groups:client:updateGroup', ids, nil)
    Groups[self.id] = nil
end

function Group:IsLeader(identifier)
    if type(identifier) == 'number' then identifier = Bridge.GetIdentifier(identifier) end
    return self.owner.citizenid == identifier
end

function Group:Notify(data)
    local ids = {}
    for _,member in pairs(self.members) do table.insert(ids, member.source) end
    lib.triggerClientEvent('ox_lib:notify', ids, data)
end

function Group:Invite(playerId, targetId)
    local accepted = lib.callback.await('zf-groups:client:invitePlayer', targetId, playerId)
    if accepted then
        local targetCid = Bridge.GetIdentifier(targetId)
        local targetName = Bridge.GetName(targetId)
        self.members[targetCid] = {
            source = targetId,
            citizenid = targetCid,
            name = targetName
        }

        self:Notify({
            title = locale('title'),
            description = locale('player_joined', self.members[targetCid].name),
            type = 'success',
            icon = 'fa-solid fa-user-plus'
        })

        return self.members[targetCid]
    end
    return false
end

function Group:KickPlayer(identifier)
    if self:IsLeader(identifier) then return false end

    local member_name = self.members[identifier].name
    self.members[identifier] = nil
    self:UpdateMembers()
    self:Notify({
        title = locale('title'),
        description = locale('player_kicked', member_name),
        type = 'error',
        icon = 'fa-solid fa-user-xmark'
    })

    return not self.members[identifier]
end

function Group:Leave(identifier)
    if self:IsLeader(identifier) then
        self:Notify({
            title = locale('title'),
            description = locale('group_disbanded'),
            type = 'error',
            icon = 'fa-solid fa-user-xmark'
        })
        self:Destroy()
    else
        local member_name = self.members[identifier].name
        self.members[identifier] = nil
        self:UpdateMembers()

        self:Notify({
            title = locale('title'),
            description = locale('player_left', member_name),
            type = 'error',
            icon = 'fa-solid fa-user-xmark'
        })
    end

    return self:IsLeader(identifier) and self == nil or not self.members[identifier]
end

function Group:UpdateMembers()
    local ids = {}
    for _,member in pairs(self.members) do table.insert(ids, member.source) end
    self.size = #self.members
    lib.triggerClientEvent('zf-groups:client:updateGroup', ids, self)
end

function Group:SetTasks(tasks)
    self.tasks = tasks
    self.currentTask = 1
    return self.tasks == tasks
end

function Group:AddTask(task)
    local current_tasks_amount = #self.tasks
    self.tasks[#self.tasks+1] = task
    return #self.tasks == (current_tasks_amount + 1)
end

function Group:RemoveTask(taskId)
    for id,task in pairs(self.tasks) do
        if task.id == taskId then
            table.remove(self.tasks, id)
            return true
        end
    end
    return false
end

function Group:CompleteTask()
    for id,task in pairs(self.tasks) do
        if task.id == self.currentTask then
            task.completed = true
            self.currentTask = self.currentTask + 1
            self:Notify({
                type = 'success',
                description = locale('task_completed')
            })
            TriggerEvent('zf-groups:server:onCompleted', self.id, self.currentTask)
            return true
        end
    end
    return false
end

function Group:NextStep()
    local task = self.tasks[self.currentTask]
    if not task then return end
    task.current_step = task.current_step + 1
    self.tasks[self.currentTask] = task
    if task.current_step >= task.steps then self:CompleteTask() end
    self:UpdateMembers()
end

function Group:UpdateTasks(tasks)
    self.tasks = tasks
    return self.tasks == tasks
end

function Group:GetTasks()
    return self.tasks
end

function Group:SetJob(job, label)
    self.job = job
    self.job_label = label
    self:UpdateMembers()
end

function Group:LeaveJob()
    self.job = nil
    self.job_label = nil
    self.data = {}
    self.tasks = {}
    self.currentTask = nil
    self:UpdateMembers()
end

function Group:ResetJobData()
    self.tasks = {}
    self.currentTask = nil
    self.data = {}
    self:UpdateMembers()
end

function Group:SyncEntity(netId, data)
    local ids = {}
    for _,member in pairs(self.members) do table.insert(ids, member.source) end
    lib.triggerClientEvent('zf-groups:client:syncEntity', ids, netId, data)
    return true
end

function Group:SetDataValue(value, state)
    self.data[value] = state
    self:UpdateMembers()
end

function Group:SetBlip(data)
    local ids = {}
    for _,member in pairs(self.members) do table.insert(ids, member.source) end
    lib.triggerClientEvent('zf-groups:client:setBlip', ids, data)
    return true
end

function Group:RemoveBlip()
    local ids = {}
    for _,member in pairs(self.members) do table.insert(ids, member.source) end
    lib.triggerClientEvent('zf-groups:client:removeBlip', ids)
    return true
end




-- ## EXPORTS ##

---Gives the groupId of a player using it's source or citizenid
---@param identifier number|string
---@return table|boolean Group
function GetGroupId(identifier)
    if type(identifier) == 'number' then identifier = Bridge.GetIdentifier(identifier) end
    if not Groups then return false end
    for _,group in pairs(Groups) do
        if group.members[identifier] then
            return group.id
        end
    end
    return false
end

exports('getMembers', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:GetMembers()
end)

exports('getSize', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:GetSize()
end)

exports('getLeader', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:GetLeader()
end)

exports('destroyGroup', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:Destroy()
end)

exports('isLeader', function(groupId, identifier, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:IsLeader(identifier)
end)

exports('notifyGroup', function(groupId, data, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:Notify(data)
end)

exports('leaveGroup', function(groupId, identifier, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:Leave(identifier)
end)

exports('updateMembers', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:UpdateMembers()
end)

exports('addTask', function(groupId, task, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:AddTask(task)
end)

exports('removeTask', function(groupId, taskId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:RemoveTask(taskId)
end)

exports('completeTask', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:CompleteTask()
end)

exports('nextStep', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:NextStep()
end)

exports('updateTasks', function(groupId, tasks, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:UpdateTasks(tasks)
end)

exports('getTasks', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:GetTasks()
end)

exports('setJob', function(groupId, job, label, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:SetJob(job, label)
end)

exports('leaveJob', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:LeaveJob()
end)

exports('resetJobData', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:ResetJobData()
end)

exports('syncEntity', function(groupId, netId, data, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:SyncEntity(netId, data)
end)

exports('setBlip', function(groupId, data, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:SetBlip(data)
end)

exports('removeBlip', function(groupId, isSource)
    if isSource then groupId = GetGroupId(groupId) end
    return Groups[groupId]:RemoveBlip()
end)




-- ## EVENTS ##

RegisterNetEvent('zf-groups:server:setJob', function(job, label)
    source = source if not source then return end
    Groups[GetGroupId(source)]:SetJob(job, label)
end)

RegisterNetEvent('zf-groups:server:leaveJob', function()
    source = source if not source then return end
    Groups[GetGroupId(source)]:LeaveJob()
end)

RegisterNetEvent('zf-groups:server:nextStep', function()
    source = source if not source then return end
    Groups[GetGroupId(source)]:NextStep()
end)

RegisterNetEvent('zf-groups:server:sendNotification', function(data)
    source = source if not source then return end
    Groups[GetGroupId(source)]:Notify(data)
end)

RegisterNetEvent('zf-groups:server:queueGroup', function(groupId, jobId, jobData, _source)
    if not _source then source = source else source = _source end if not source then return end
    JobQueue[#JobQueue+1] = {
        source = source,
        groupId = groupId,
        job = jobId,
        data = jobData
    }
end)

RegisterNetEvent('zf-groups:server:setDataValue', function(value, state)
    source = source if not source then return end
    Groups[GetGroupId(source)]:SetDataValue(value, state)
end)

RegisterNetEvent('zf-groups:server:leaveGroup', function()
    source = source if not source then return end
    local group = Groups[GetGroupId(source)]
    local identifier = Bridge.GetIdentifier(source)
    group:Leave(identifier)
end)





-- ## CALLBACKS ##

lib.callback.register('zf-groups:server:createGroup', function(source)
    local group = Group:new(source)
    Groups[group.id] = group
    group:Notify({
        title = locale('title'),
        description = locale('group_created'),
        type = 'success',
        icon = 'fa-solid fa-user-group'
    })
    return group
end)

lib.callback.register('zf-groups:server:getGroup', function(source)
    local groupId = GetGroupId(source)
    return Groups[groupId]
end)

lib.callback.register('zf-groups:server:invitePlayer', function(source, targetId)
    local group = Groups[GetGroupId(source)]
    local tarGetGroupId = GetGroupId(targetId)
    if tarGetGroupId then return 'already_in_group' end

    local joined = group:Invite(source, targetId)
    if joined then
        group:UpdateMembers()
        return 'joined'
    else
        return 'declined'
    end
end)

lib.callback.register('zf-groups:server:kickPlayer', function(source, identifier)
    local group = Groups[GetGroupId(source)]
    TriggerClientEvent('zf-groups:client:updateGroup', group.members[identifier].source, nil)
    return group:KickPlayer(identifier)
end)

lib.callback.register('zf-groups:server:setTasks', function(source, tasks)
    local group = Groups[GetGroupId(source)]
    return group:SetTasks(tasks)
end)

lib.callback.register('zf-groups:server:addTask', function(source, task)
    local group = Groups[GetGroupId(source)]
    return group:AddTask(task)
end)

lib.callback.register('zf-groups:server:removeTask', function(source, taskId)
    local group = Groups[GetGroupId(source)]
    return group:RemoveTask(taskId)
end)

lib.callback.register('zf-groups:server:completeTask', function(source)
    local group = Groups[GetGroupId(source)]
    return group:CompleteTask()
end)

lib.callback.register('zf-groups:server:updateTasks', function(source, tasks)
    local group = Groups[GetGroupId(source)]
    return group:UpdateTasks(tasks)
end)

lib.callback.register('zf-groups:server:getTasks', function(source)
    local group = Groups[GetGroupId(source)]
    return group:GetTasks()
end)

lib.callback.register('zf-groups:server:syncEntity', function(source, netId, data)
    local group = Groups[GetGroupId(source)]
    return group:SyncEntity(netId, data)
end)

lib.versionCheck('zf-labo/zf-groups')