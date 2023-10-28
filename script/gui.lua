local gui = require("lib.gui")
local event = require("__flib__.event")
local trim = require("script/trim")

local windowName = "supertrim-host"

function createWindow(player_index)
    local player = game.get_player(player_index)
    local dialog_settings = ensureDialogSettings(player_index)
    
    if dialog_settings.delete_on_empty == nil then
        dialog_settings.delete_on_empty = true
    end
    
    dialog_settings.surface_state = dialog_settings.surface_state or {}
    
    local surfaces = getSurfaceDescriptors()
    
    -- Clean up any dead surfaces
    for k, v in pairs(dialog_settings.surface_state) do
        if not game.surfaces[k] or not game.surfaces[k].valid then
            dialog_settings.surface_state[k] = nil
        end
    end
    
    -- Add any new surfaces
    for k, surfaceDesc in ipairs(surfaces) do
        if not surfaceDesc.hidden and dialog_settings.surface_state[surfaceDesc.index] == nil then
            dialog_settings.surface_state[surfaceDesc.index] = true
        end
    end

    local rootgui = player.gui.screen
    local dialog = gui.build(rootgui, {
        {type="frame", direction="vertical", save_as="main_window", name=windowName, children={
            -- Title Bar
            {type="flow", save_as="titlebar.flow", children={
                {type="label", style="frame_title", caption={"supertrim.window-title"}, elem_mods={ignored_by_interaction=true}},
                {template="drag_handle"},
                {template="close_button", handlers="supertrim_handlers.close_button"}}},
            {type="flow", direction="vertical", style_mods={horizontal_align="left"}, children={
                {type="label", caption={"supertrim.search-warning"}, style_mods={single_line=false, horizontally_squashable=true} },
                {type="flow", style_mods={horizontal_align="left"}, save_as="surface_view_container", children={
                    renderSurfaces(surfaces, dialog_settings.surface_state),
                    renderSurfaceView(dialog_settings.active_surface)
                }},
                {type="flow", style_mods={horizontal_align="right"}, children={
                    {type="empty-widget", style_mods={horizontally_stretchable=true}},
                    {template="frame_action_button", sprite="utility/no_storage_space_icon", handlers="supertrim_handlers.supertrim" }}}}}}
            }})

    dialog.titlebar.flow.drag_target = dialog.main_window
    dialog_settings.dialog = dialog

    if dialog_settings.location then
        dialog.main_window.location = dialog_settings.location
    else
        dialog.main_window.force_auto_center()
    end

    player.opened = dialog.main_window
end

function renderSurfaceView(surface)
    if surface == nil or not surface.valid then return nil end
    return {type="minimap", surface_index=surface.index, name="surface_view", style_mods={horizontally_stretchable=true, vertically_stretchable=true}}
end

function renderSurfaces(surfaces, surface_state)
    local childRows = {}
    for k, surfaceDesc in ipairs(surfaces) do
        if not surfaceDesc.hidden then
            table.insert(childRows, {type="checkbox", state=surface_state[surfaceDesc.index] or false, tags={surface_index=surfaceDesc.index}, handlers="supertrim_handlers.check_surface"})
            table.insert(childRows, {type="label", caption=surfaceDesc.name})
            table.insert(childRows, {type="sprite-button", sprite="utility/search_icon", style_mods={maximal_height=20, maximal_width=20}, tags={surface_index=surfaceDesc.index}, handlers="supertrim_handlers.view_surface"})
        end
    end
    return {type="scroll-pane", direction="vertical", style_mods={maximal_height=800}, children={
        {type="table", column_count=3, style_mods={vertical_align="center"}, children=childRows}
    }}
end

function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function getSurfaceDescriptors()
    local descs = {}
    for _, surface in pairs(game.surfaces) do
        if surface.valid then
            table.insert(descs, getSurfaceDescriptor(surface))
        end
    end
    return descs
end

function getSurfaceDescriptor(surface)
    if surface.name == 'aai-signals' then
        return { hidden=true, warning = "AAI internal surface; should not be trimmed.", name = surface.name, index=surface.index }
    end
    if surface.name == 'starmap-1' then
        return { hidden=true, warning = "SE UI internal surface; should not be trimmed.", name = surface.name, index=surface.index }
    end
    if remote.interfaces['space-exploration'] and remote.interfaces['space-exploration']['get_surface_type'] then
        local type = remote.call('space-exploration', 'get_surface_type', { surface_index = surface.index })
        if type == 'vault' then 
            return { hidden=true, warning = "SE vault internal surface; should not be trimmed.", name = surface.name, index=surface.index }
        end
        if type == 'spaceship' then 
            return { hidden=true, warning = "SE spaceship surface; should not be trimmed.", name = surface.name, index=surface.index }
        end
    end
    if remote.interfaces['space-exploration'] and remote.interfaces['space-exploration']['get_zone_from_surface_index'] then
        local zone = remote.call('space-exploration', 'get_zone_from_surface_index', { surface_index = surface.index })
        return { name = getZonePrintName(zone), index=surface.index }
    end
    return { name = surface.name, index=surface.index }
end

function getZonePrintName(zone, no_icon, no_color)
  local zone_type = getZoneFullType(zone)
  local suffix = (zone_type == "spaceship") and
    string.format(" [font=default-small][%d][/font]", zone.index) or ""
  local name = no_color and (zone.name .. suffix) or
    "[color=" .. zoneColorCodes[zone_type] .. "]".. zone.name .. suffix .. "[/color]"

  return (no_icon and "" or "[img=virtual-signal/" .. getZoneSignalName(zone) .. "] ") .. name
end

zoneColorCodes = {
  ["anomaly"] = "#B77DFF",
  ["asteroid-field"] = "#8AA1FF",
  ["asteroid-belt"] = "#98D4FE",
  ["star"] = "#FFA850",
  ["star-orbit"] = "#FFA850",
  ["planet"] = "#5CFF66",
  ["planet-orbit"] = "#8FFF99",
  ["moon"] = "#F9FF82",
  ["moon-orbit"] = "#F9FFB5",
  ["spaceship"] = "#6ED1D6"
}

function getZoneSignalName(zone)
  -- used for rich text
  local se_prefix = 'se-'
  local parentType = getZoneParentType(zone)
  if zone.type == "orbit" and parentType == "star" then
    return se_prefix.."star"
  elseif zone.type == "orbit" and parentType == "planet" then
    return se_prefix.."planet-orbit"
  elseif zone.type == "orbit" and parentType == "moon" then
    return se_prefix.."moon-orbit"
  else
    return se_prefix..zone.type
  end
end

function getZoneParentType(zone)
    if zone.parent_index then
       local parentZone = remote.call('space-exploration', 'get_zone_from_zone_index', {zone_index=zone.parent_index})
       return parentZone.type
    end
end

---Returns the full type of a given zone, allowing easier differentiation of different orbit types.
---@param zone AnyZoneType|StarType|SpaceshipType Zone whose type to get
---@return string type
function getZoneFullType(zone)
  local type
  local parentType = getZoneParentType(zone)
  if zone.type == "orbit" then
    if parentType == "star" then
      type = "star-orbit"
    elseif parentType == "planet" then
      type = "planet-orbit"
    elseif parentType == "moon" then
      type = "moon-orbit"
    end   
  else
    type = zone.type
  end

  return type
end

function ensureDialogSettings(player_index)
    global.dialog_settings = global.dialog_settings or {}
    global.dialog_settings[player_index] = global.dialog_settings[player_index] or {}
    return global.dialog_settings[player_index]
end

function registerHandlers()
    gui.add_handlers({
        supertrim_handlers = {
            close_button = {
                on_gui_click = function(e)
                    closeGui(e.player_index)
                end
            },
            supertrim = {
                on_gui_click = function(e)
                    for k, v in pairs(ensureDialogSettings(e.player_index).surface_state or {}) do
                        if v then
                            trim.supertrim(game.surfaces[k], 1, 10)
                        end
                    end
                end
            },
            check_surface = {
                on_gui_checked_state_changed = function(e)
                    ensureDialogSettings(e.player_index).surface_state[e.element.tags.surface_index] = e.element.state
                end
            },
            view_surface = {
                on_gui_click = function(e)
                    local settings = ensureDialogSettings(e.player_index)
                    settings.active_surface = game.surfaces[e.element.tags.surface_index]
                    if settings.dialog.surface_view_container.surface_view then
                        settings.dialog.surface_view_container.surface_view.destroy()
                    end
                    local location = {x = 0, y = 0}
                    if not goTo(game.players[e.player_index], location, settings.active_surface) then
                        gui.build(settings.dialog.surface_view_container, {renderSurfaceView(settings.active_surface)})
                    end
                end
            },
            delete_on_empty = {
                on_gui_checked_state_changed = function(e)
                    ensureDialogSettings(e.player_index).delete_on_empty = e.element.state
                end
            }
        },
    })
    gui.register_handlers()
end

function isNavsatAvailable(player)
    if not remote.interfaces['space-exploration'] then return false end
    if not remote.interfaces['space-exploration'].remote_view_is_unlocked then return false end
    return remote.call('space-exploration', 'remote_view_is_unlocked', {player=player})
end

function goTo(player, location, surface)
    if isNavsatAvailable(player) then
        local zone = remote.call('space-exploration', 'get_zone_from_surface_index', { surface_index=surface.index })
        if zone then        
            remote.call('space-exploration', 'remote_view_start', { player = player, zone_name = zone.name, position={x=location.x, y=location.y}, location_name="", freeze_history=true })
            return true
        end
    end
    return false
end

function registerTemplates()
  gui.add_templates{
    frame_action_button = {type="sprite-button", style="frame_action_button", mouse_button_filter={"left"}},
    drag_handle = {type="empty-widget", style="flib_titlebar_drag_handle", elem_mods={ignored_by_interaction=true}},
    close_button = {template="frame_action_button", sprite="utility/close_white", hovered_sprite="utility/close_black"},
  }
end

registerHandlers()
registerTemplates()

event.on_load(function()
  gui.build_lookup_tables()
end)

function onInit()
  global.dialog_settings = {}
  gui.init()
  gui.build_lookup_tables()
end

function passthroughGuiEvent(event)
    return gui.dispatch_handlers(event)
end

function closeGui(player_index)
    local player = game.get_player(player_index)
    local rootgui = player.gui.screen
    if rootgui[windowName] then
        rootgui[windowName].destroy()
    end
end

event.register(defines.events.on_gui_location_changed, function(e)
    if not e.element or e.element.name ~= windowName then return end
    ensureDialogSettings(e.player_index).location = e.element.location
end)

function toggleGui(player_index)
    local player = game.get_player(player_index)
    local rootgui = player.gui.screen
    if rootgui[windowName] then
        closeGui(player_index)
    else
        createWindow(player_index)
    end
end

return { toggleGui = toggleGui, onInit = onInit, passthroughGuiEvent = passthroughGuiEvent }
