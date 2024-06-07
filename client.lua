-- ## CLASS ##

---@class MyGroup : OxClass
MyGroup = lib.class('MyGroup')
function MyGroup:constructor(data)
    self.id = data?.id
    self.owner = data?.owner
    self.members = data?.members
    self.tasks = data?.tasks
    self.currentTask = data?.currentTask
    self.looking_jobs = data?.looking_jobs
    self.job = data?.job
    self.job_label = data?.job_label
    self.entities = {}
    self.data = {}
    return self
end

function MyGroup:MainMenu()
    local context = {}

    if not self.id then
        context[#context+1] = {
            title = locale('create_group_title'),
            description = locale('create_group_description'),
            icon = 'fa-solid fa-users',
            iconColor = '#6abae9',
            onSelect = function()
                self:Create()
            end
        }
    end

    if self.id then
        context[#context+1] = {
            title = locale('current_job', self.job_label or locale('none')),
            icon = 'fa-solid fa-user-tie',
            iconColor = self.job and '#2a9d6b' or '#e63946',
            readOnly = true
        }

        context[#context+1] = {
            title = locale('members_title'),
            description = locale('members_description'),
            icon = 'fa-solid fa-user-group',
            iconColor = '#2a9d6b',
            arrow = true,
            onSelect = function()
                self:ManageMembers()
            end
        }

        context[#context+1] = {
            title = locale('tasks_title'),
            description = locale('tasks_description'),
            icon = 'fa-solid fa-list-check',
            iconColor = self.currentTask ~= (#self.tasks) and (table.type(self.tasks) == 'array' and '#6abae9' or '#e63946') or '#2a9d6b',
            arrow = table.type(self.tasks) ~= 'empty',
            readOnly = table.type(self.tasks) == 'empty',
            onSelect = function()
                self:ViewTasks()
            end
        }

        context[#context+1] = {
            title = locale('leave_group'),
            icon = 'fa-solid fa-xmark',
            iconColor = '#e63946',
            arrow = true,
            onSelect = function()
                TriggerServerEvent('zf-groups:server:leaveGroup')
            end
        }
    end

    lib.registerContext({
        id = 'zf-jobs:groups',
        title = locale('title'),
        options = context
    })
    lib.showContext('zf-jobs:groups')
end

function MyGroup:ViewTasks()
    local context = {}

    if #self.tasks == 0 then
        context[#context+1] = {
            title = locale('no_task_available'),
            icon = 'fa-regular fa-square-minus',
            readOnly = true,
        }
    else
        for i=1, #self.tasks do
            local task = self.tasks[i]
            local taskIcon
            local taskIconColor

            if task.completed then
                taskIcon = 'fa-regular fa-square-check'
                taskIconColor = '#2a9d6b'
            elseif not task.completed and i == self.currentTask then
                taskIcon = 'fa-regular fa-square'
                taskIconColor = '#e9c46a'
            elseif not task.completed and i ~= self.currentTask then
                taskIcon = 'fa-regular fa-square-minus'
                taskIconColor = '#e63946'
            end

            context[#context+1] = {
                title = task.title,
                description = locale('task_steps_status', task.current_step, task.steps),
                icon = taskIcon,
                iconColor = taskIconColor,
                readOnly = task.completed or (not task.completed and i == self.currentTask),
                disabled = not task.completed and i ~= self.currentTask,
            }
        end
    end

    lib.registerContext({
        id = 'zf-jobs:groups-tasks',
        title = locale('title'),
        options = context,
        menu = true,
        onBack = function()
            self:MainMenu()
        end
    })
    lib.showContext('zf-jobs:groups-tasks')
end

function MyGroup:Invite()
    local closestPlayers = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 7.5, false)
    local players = {}

    if not closestPlayers[1] then
        lib.notify({
            title = locale('title'),
            description = locale('no_player_nearby'),
            type = 'error',
        })
        self:ManageMembers()
    else
        for _,player in pairs(closestPlayers) do
            players[#players+1] = {
                value = GetPlayerServerId(player.id),
                label = 'ID #' .. GetPlayerServerId(player.id)
            }
        end

        local res = lib.inputDialog('Inviter', {
            {
                type = 'select',
                label = locale('players'),
                options = players,
                icon = 'fa-solid fa-envelope-open-text',
                required = true,
                searchable = true,
            }
        })

        if res then
            lib.notify({
                title = locale('title'),
                description = locale('invite_sent', tostring(res[1])),
                type = 'info',
            })

            local accepted = lib.callback.await('zf-groups:server:invitePlayer', false, res[1])
            if accepted == 'joined' then
                self:ManageMembers()
            elseif accepted == 'declined' then
                lib.notify({
                    title = locale('title'),
                    description = locale('invite_refused'),
                    type = 'error',
                })
                self:ManageMembers()
            elseif accepted == 'already_in_group' then
                lib.notify({
                    title = locale('title'),
                    description = locale('invite_already_in_group'),
                    type = 'error',
                })
                self:ManageMembers()
            end
        else
            lib.notify({
                title = locale('title'),
                description = locale('no_choice'),
                type = 'error',
            })
            self:ManageMembers()
        end
    end
end

function MyGroup:Kick(identifier)
    local _ = lib.callback.await('zf-groups:server:kickPlayer', false, identifier)
    self:ManageMembers()
end

function MyGroup:ManageMembers()
    local context = {}

    context[#context+1] = {
        title = locale('invite_member'),
        icon = 'fa-solid fa-user-plus',
        iconColor = '#6abae9',
        onSelect = function()
            self:Invite()
        end
    }

    for _,member in pairs(self.members) do
        context[#context+1] = {
            title = member.name,
            description = member.citizenid == self.owner.citizenid and locale('member_owner') or locale('member_kick'),
            icon = member.citizenid == self.owner.citizenid and 'fa-solid fa-crown' or 'fa-solid fa-user-xmark',
            iconColor = member.citizenid == self.owner.citizenid and '#fdc500' or '#e9c46a',
            readOnly = member.citizenid == self.owner.citizenid,
            onSelect = function()
                self:Kick(member.citizenid)
            end
        }
    end

    lib.registerContext({
        id = 'zf-jobs:groups-members',
        title = locale('title'),
        options = context,
        menu = true,
        onBack = function()
            self:MainMenu()
        end
    })
    lib.showContext('zf-jobs:groups-members')
end

function MyGroup:Update(data)
    self.id = data?.id or nil
    self.owner = data?.owner or nil
    self.members = data?.members or nil
    self.tasks = data?.tasks or nil
    self.currentTask = data?.currentTask or nil
    self.looking_jobs = data?.looking_jobs or nil
    self.job = data?.job or nil
    self.job_label = data?.job_label or nil
    self.entities = data?.entities or self.entities
    self.data = data?.data or self.data
end

function MyGroup:Create()
    local group = lib.callback.await('zf-groups:server:createGroup', false)
    if group then
        lib.hideContext()
        self:Update(group)
        self:MainMenu()
    end
end

function MyGroup:Notify(data)
    TriggerServerEvent('zf-groups:server:sendNotification', data)
end

function MyGroup:SyncEntity(netId, data)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity then return end
    if not self.entities then self.entities = {} end
    if not self.entities[netId] then self.entities[netId] = {} end

    for field,value in pairs(data) do
        self.entities[netId][field] = value
    end
end

function MyGroup:GetEntity(netId)
    if not netId then return false end
    if not self.entities then return false end
    return self.entities[netId] or false
end

function MyGroup:SetBlip(data)
    if MyGroup.blip then RemoveBlip(MyGroup.blip) end
    MyGroup.blip = AddBlipForCoord(data.coords[1], data.coords[2], data.coords[3])
    SetBlipSprite(MyGroup.blip, data.sprite)
    SetBlipDisplay(MyGroup.blip, 4)
    SetBlipScale(MyGroup.blip, 0.8)
    SetBlipColour(MyGroup.blip, data.color)
    SetBlipAsShortRange(MyGroup.blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.label)
    EndTextCommandSetBlipName(MyGroup.blip)
    if data.route then
        SetBlipRoute(MyGroup.blip, true)
    end
end

function MyGroup:RemoveBlip()
    if MyGroup.blip then
        RemoveBlip(MyGroup.blip)
        MyGroup.blip = nil
    end
end





-- ## CALLBACKS ##

lib.callback.register('zf-groups:client:invitePlayer', function(identifier)
    local res = lib.alertDialog({
        header = locale('title'),
        content = locale('invite_received', identifier),
        centered = true,
        size = 'md',
        labels = {
            confirm = locale('accept'),
            cancel = locale('refuse')
        }
    })
    return res == 'confirm' or false
end)





-- ## EVENTS ##

AddEventHandler('onResourceStart', function(resname)
    if resname == GetCurrentResourceName() then
        MyGroup:new()
    end
end)

RegisterNetEvent('zf-groups:onPlayerLoaded', function()
    MyGroup:new()
end)

RegisterNetEvent('zf-groups:client:updateGroup', function(data)
    MyGroup:Update(data)
end)

RegisterNetEvent('zf-groups:client:syncEntity', function(netId, data)
    MyGroup:SyncEntity(netId, data)
end)

RegisterNetEvent('zf-groups:client:setBlip', function(data)
    MyGroup:SetBlip(data)
end)

RegisterNetEvent('zf-groups:client:removeBlip', function()
    MyGroup:RemoveBlip()
end)




-- ## MENU ##

lib.addKeybind({
    name = 'zf-groups-menu',
    description = locale('open_group_menu'),
    defaultKey = 'GRAVE',
    defaultMapper = 'keyboard',
    onPressed = function()
        MyGroup:MainMenu()
    end
})