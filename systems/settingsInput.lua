local Input = {}
function Input.attach(settings, deps)
    local persistence = deps.persistence
    local helpers = deps.helpers
    local settingsDraw = deps.settingsDraw
    local world = deps.world
    local isLiveKey = deps.isLiveKey
    local applyLiveForKey = deps.applyLiveForKey
    function settings.mousepressed(x, y, button)
        if not settings.visible then return false end
        if button ~= 1 then return true end
        if settings.openDropdown then
            local dd = settings.openDropdown
            if settingsDraw.hitTest(settings, x, y, dd.x, dd.y, dd.w, dd.h) then
                local scrollY = dd.scrollY or 0
                local relY = y - dd.y + scrollY
                local idx = math.floor(relY / dd.itemH) + 1
                if idx >= 1 and idx <= #dd.items then
                    local selected = dd.items[idx]
                    local parts = settingsDraw.checkboxKeyPath(settings, dd.key)
                    settingsDraw.setNested(settings, settings.editing, parts, selected.value)
                    if dd.key == 'graphics.resolution' then
                        if selected.value and selected.value.width and selected.value.height then
                            local ok = false
                            pcall(function() ok = persistence.previewResolution(selected.value) end)
                            if ok then
                                settingsDraw.showToast(settings, '¿Mantener resolución? 5s', false)
                                settings.toastTimer = 5
                                if world and world.state then world.state.resolutionConfirmTimer = 5 end
                            else
                                local applied = false
                                pcall(function()
                                    applied = persistence.previewResolution(selected.value)
                                end)
                                settingsDraw.showToast(settings, '¿Mantener resolución? 5s', false)
                                settings.toastTimer = 5
                            end
                        else
                            settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                        end
                    elseif isLiveKey(dd.key) then
                        pcall(function() persistence.applyLive(settings.editing) end)
                        settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                    else
                        settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                    end
                    settings.openDropdown = nil
                end
                return true
            else
                settings.openDropdown = nil
                return true
            end
        end
        if settings.g.closeBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.closeBtn)) then
            local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
            settings.editing = helpers.deep_copy(settings.lastSaved)
            if diff.audio or diff.ui or diff.filter then
                pcall(function() persistence.applyLive(settings.lastSaved) end)
            end
            if diff.resolution and persistence._previewPrev then
                pcall(function() persistence.revertResolutionPreview() end)
            end
            settings.close()
            return true
        end
        if settings.g.tabs then
            for _, tab in ipairs(settings.g.tabs) do
                if settingsDraw.hitTest(settings, x, y, tab[1], tab[2], tab[3], tab[4]) then
                    if tab.name ~= settings.activeTab then
                        settings.activeTab = tab.name
                        settings.openDropdown = nil
                    end
                    return true
                end
            end
        end
        if settings.activeTab == 'Audio' then
            if settings.g.masterSlider and settingsDraw.hitTest(settings, x, y, settings.g.masterSlider[1], settings.g.masterSlider[2], settings.g.masterSlider[3], 16) then
                local rel = math.max(0, math.min(1, (x - settings.g.masterSlider[1]) / settings.g.masterSlider[3]))
                settings.editing.audio.master = rel
                pcall(function() persistence.applyLive(settings.editing) end)
                settings.dragState = {type = 'master', bx = settings.g.masterSlider[1], bw = settings.g.masterSlider[3]}
                return true
            end
            if settings.g.musicBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.musicBox)) then
                settingsDraw.toggleCheckbox(settings, settings.g.musicBox.key)
                applyLiveForKey(settings.g.musicBox.key)
                return true
            end
            if settings.g.sfxBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.sfxBox)) then
                settingsDraw.toggleCheckbox(settings, settings.g.sfxBox.key)
                applyLiveForKey(settings.g.sfxBox.key)
                return true
            end
        elseif settings.activeTab == 'Gráficos' then
            if settings.g.pixelScaleDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.pixelScaleDrop)) then
                local bx, by, bw, bh = unpack(settings.g.pixelScaleDrop)
                local items = {{label = '1', value = 1}, {label = '2', value = 2}, {label = '3', value = 3}, {label = '4', value = 4}}
                settings.openDropdown = {
                    key = settings.g.pixelScaleDrop.key,
                    items = items, current = settings.editing.graphics.pixelScale,
                    x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28, scrollY = 0
                }
                return true
            end
            if settings.g.resolutionDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.resolutionDrop)) then
                local bx, by, bw, bh = unpack(settings.g.resolutionDrop)
                local items = {}
                local dw, dh = love.window.getDesktopDimensions(1)
                if dw and dh then
                    table.insert(items, {label = 'Escritorio: ' .. dw .. 'x' .. dh, value = {width = dw, height = dh}})
                end
                local commons = {{800, 600}, {1024, 768}, {1280, 720}, {1366, 768}, {1600, 900}, {1920, 1080}}
                for _, r in ipairs(commons) do
                    table.insert(items, {label = r[1] .. 'x' .. r[2], value = {width = r[1], height = r[2]}})
                end
                table.insert(items, {label = 'Auto (actual)', value = nil})
                local ddH = math.min(#items * 28, 240)
                settings.openDropdown = {
                    key = settings.g.resolutionDrop.key,
                    items = items, current = settings.editing.graphics.resolution,
                    x = bx, y = by + bh + 2, w = bw, h = ddH, itemH = 28, scrollY = 0
                }
                return true
            end
            if settings.g.filterDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.filterDrop)) then
                local bx, by, bw, bh = unpack(settings.g.filterDrop)
                local items = {{label = 'nearest', value = 'nearest'}, {label = 'linear', value = 'linear'}}
                settings.openDropdown = {
                    key = settings.g.filterDrop.key,
                    items = items, current = settings.editing.graphics.filter,
                    x = bx, y = by + bh + 2, w = bw, h = 56, itemH = 28, scrollY = 0
                }
                return true
            end
            if settings.g.fullscreenBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.fullscreenBox)) then
                settingsDraw.toggleCheckbox(settings, settings.g.fullscreenBox.key)
                return true
            end
            if settings.g.vsyncBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.vsyncBox)) then
                settingsDraw.toggleCheckbox(settings, settings.g.vsyncBox.key)
                return true
            end
        elseif settings.activeTab == 'Accesibilidad' then
            if settings.g.uiScaleSlider and settingsDraw.hitTest(settings, x, y, settings.g.uiScaleSlider[1], settings.g.uiScaleSlider[2], settings.g.uiScaleSlider[3], 16) then
                local minS, maxS = 0.8, 1.5
                local rel = math.max(0, math.min(1, (x - settings.g.uiScaleSlider[1]) / settings.g.uiScaleSlider[3]))
                settings.editing.accessibility.uiScale = minS + rel * (maxS - minS)
                pcall(function() persistence.applyLive(settings.editing) end)
                settings.dragState = {type = 'uiScale', bx = settings.g.uiScaleSlider[1], bw = settings.g.uiScaleSlider[3], min = minS, max = maxS}
                return true
            end
            if settings.g.highContrastBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.highContrastBox)) then
                settingsDraw.toggleCheckbox(settings, settings.g.highContrastBox.key)
                applyLiveForKey(settings.g.highContrastBox.key)
                return true
            end
            if settings.g.colorblindDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.colorblindDrop)) then
                local bx, by, bw, bh = unpack(settings.g.colorblindDrop)
                local items = {{label = 'Off', value = 'off'}, {label = 'Protanopia', value = 'protanopia'}, {label = 'Deuteranopia', value = 'deuteranopia'}, {label = 'Tritanopia', value = 'tritanopia'}}
                settings.openDropdown = {
                    key = settings.g.colorblindDrop.key,
                    items = items, current = settings.editing.accessibility.colorblind,
                    x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28, scrollY = 0
                }
                return true
            end
            if settings.g.controlModeDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.controlModeDrop)) then
                local bx, by, bw, bh = unpack(settings.g.controlModeDrop)
                local items = {{label = 'Clásico (Auto)', value = 'classic'}, {label = 'Táctico (Sostener)', value = 'tactical'}}
                settings.openDropdown = {
                    key = settings.g.controlModeDrop.key,
                    items = items, current = (settings.editing.gameplay and settings.editing.gameplay.controlMode) or 'classic',
                    x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28, scrollY = 0
                }
                return true
            end
        end
        if settings.g.resetBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.resetBtn)) then
            local def = persistence.defaults()
            settings.editing = helpers.deep_copy(def)
            pcall(function() persistence.applyLive(settings.editing) end)
            settingsDraw.showToast(settings, 'Valores restablecidos (sin guardar)', false)
            return true
        end
        if settings.g.cancelBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.cancelBtn)) then
            local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
            settings.editing = helpers.deep_copy(settings.lastSaved)
            if diff.audio or diff.ui or diff.filter then
                pcall(function() persistence.applyLive(settings.lastSaved) end)
            end
            if diff.resolution and persistence._previewPrev then
                pcall(function() persistence.revertResolutionPreview() end)
            end
            settingsDraw.showToast(settings, 'Cambios descartados', false)
            settings.close()
            return true
        end
        if settings.g.saveBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.saveBtn)) then
            local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
            if diff.empty then
                settingsDraw.showToast(settings, 'Sin cambios', false)
                return true
            end
            if settings.editing and settings.editing.graphics and settings.editing.graphics.resolution then
                local r = settings.editing.graphics.resolution
                if type(r) == 'table' and r.width and r.height then
                    settings.editing.graphics.resolution = {width = math.floor(r.width), height = math.floor(r.height)}
                end
            end
            local ok, err = persistence.saveAndApplySelective(settings.lastSaved, settings.editing)
            if ok then
                if persistence.confirmResolutionPreview then
                    persistence.confirmResolutionPreview()
                end
                settings.lastSaved = helpers.deep_copy(settings.editing)
                settingsDraw.showToast(settings, 'Configuración guardada', false)
                settings.close()
            else
                if err == 'no_changes' then
                    settingsDraw.showToast(settings, 'Sin cambios', false)
                else
                    settingsDraw.showToast(settings, 'Error al guardar: ' .. tostring(err), true)
                end
            end
            return true
        end
        local px, py = settingsDraw.panelXY(settings)
        if x >= px and x <= px + settings.PW and y >= py and y <= py + settings.PH then
            return true
        end
        return true
    end
end
return Input
