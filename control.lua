local event = require("__flib__.event")
local gui = require('script/gui')
local trim = require('script/trim')

script.on_init(function(event)
    gui.onInit()
    trim.onInit()
end)

event.register(defines.events.on_tick, function(event)
    trim.onTick(event.tick)
end)

event.register(defines.events.on_lua_shortcut, function(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    if event.prototype_name ~= "supertrim_open_interface" then return end

    gui.toggleGui(event.player_index)
end)
