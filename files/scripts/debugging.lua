if ModIsEnabled("NoitaDearImGui") then
    imgui = load_imgui({ mod = "noita-online", version = "1.20" })
    implot = imgui.implot
end

local module = {
    open = false,
    active_windows = {},
    searchText = "",
    showChildEntities = false,
}


module.Update = function()
    if InputIsKeyJustDown(12) then -- F1
        module.open = not module.open
    end
end

module.Draw = function()
    if imgui and module.open then
        imgui.SetNextWindowSize(480, 720, imgui.Cond.FirstUseEver)
        local should_draw
        should_draw, module.open = imgui.Begin("Dev Tools", module.open)
        if should_draw then
            if imgui.BeginTabBar("Debug Tabs") then
                if imgui.BeginTabItem("Entities") then
                    module.ShowEntitiesTab()
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem("Cheats") then
                    module.ShowCheatsTab()
                    imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
        end
        imgui.End()

        -- Draw active windows
        for i = #module.active_windows, 1, -1 do
            local window = module.active_windows[i]
            if window.draw_window then
                window.draw_window(window)
            else
                table.remove(module.active_windows, i)
            end
        end
    end
end

module.ShowEntitiesTab = function()
    local entities = EntitySystem.entities or {}
    imgui.Text("Loaded Entities: " .. #entities)

    -- Search bar
    local changed, newText = imgui.InputText("Search", module.searchText, 100)
    if changed then
        module.searchText = newText
    end

    changed, module.showChildEntities = imgui.Checkbox("Show Child Entities", module.showChildEntities)

    imgui.Separator()

    imgui.BeginChild("Entity List", 0, 0)

    if imgui.BeginTable("EntityListTable", 7, imgui.TableFlags.BordersInnerV + imgui.TableFlags.Resizable) then
		imgui.TableSetupColumn("ID", imgui.TableColumnFlags.WidthFixed)
		imgui.TableSetupColumn("Type", imgui.TableColumnFlags.WidthStretch, 6)
		imgui.TableSetupColumn("NetworkID", imgui.TableColumnFlags.WidthStretch, 12)
		imgui.TableSetupColumn("Name", imgui.TableColumnFlags.WidthFixed)
		imgui.TableSetupColumn("Owner", imgui.TableColumnFlags.WidthStretch, 6)
        imgui.TableSetupColumn("Kill", imgui.TableColumnFlags.WidthStretch, 3)
        imgui.TableSetupColumn("Open", imgui.TableColumnFlags.WidthStretch, 3)
        imgui.TableHeadersRow()

        for _, entity in ipairs(entities) do
            local tag_string = table.concat(entity.tags or {}, ", ")
            local entity_name = entity._name or ""

            local show_entity = (module.searchText == "" or string.find(string.lower(tag_string), string.lower(module.searchText)) or string.find(string.lower(entity_name), string.lower(module.searchText)) or string.find(tostring(entity._id), module.searchText))

            if show_entity then
                imgui.TableNextRow()
				imgui.TableNextColumn()
				imgui.Text(tostring(entity._id))
				imgui.TableNextColumn()
				imgui.Text(entity._type)
				imgui.TableNextColumn()
				imgui.Text(tostring(entity.network_id))
				imgui.TableNextColumn()
				imgui.Text(entity._name)
				imgui.TableNextColumn()
				imgui.Text(steam_utils.getTranslatedPersonaName(entity._owner))
                imgui.TableNextColumn()

                -- Kill button without styling
                if imgui.Button("Kill##" .. entity._id) then
                    entity:Destroy()
                end
                imgui.TableNextColumn()

                local window_id = "EntityWindow##" .. entity._id
                local window_open = false
                for _, win in ipairs(module.active_windows) do
                    if win.window_id == window_id then
                        window_open = true
                        break
                    end
                end

                if not window_open then
                    if imgui.Button("Open##" .. entity._id) then
                        local window = {
                            window_id = window_id,
                            window_name = "Entity " .. entity._id .. " - " .. entity_name,
                            entity = entity,
                            draw_window = module.EntityInspector,
                        }
                        table.insert(module.active_windows, window)
                    end
                else
                    if imgui.Button("Close##" .. entity._id) then
                        for idx, win in ipairs(module.active_windows) do
                            if win.window_id == window_id then
                                table.remove(module.active_windows, idx)
                                break
                            end
                        end
                    end
                end
            end
        end

        imgui.EndTable()
    end

    imgui.EndChild()
end

module.EntityInspector = function(window)
    local entity = window.entity
    if entity and EntitySystem.entities[entity._id] then
        imgui.SetNextWindowSize(480, 720, imgui.Cond.FirstUseEver)
        local open = true
        local should_draw
        should_draw, open = imgui.Begin(window.window_name .. "###" .. window.window_id, open)
        if should_draw then
            if imgui.BeginTabBar("EntityInspectorTabs:" .. entity._id) then
                if imgui.BeginTabItem("Attributes") then
                    -- Entity attributes
                    local entity_name = entity._name or ""
                    local changed, new_name = imgui.InputText("Name", entity_name, 100)
                    if changed then
                        entity._name = new_name
                    end
                    imgui.SameLine()

                    -- Kill button without styling
                    if imgui.Button("Kill") then
                        entity:Destroy()
                    end

                    imgui.Separator()

                    if imgui.CollapsingHeader("Transform") then
                        local vec = entity.transform:GetPosition()
						local changed = false
						changed, vec.x, vec.y, vec.z = imgui.InputFloat3("Position", vec.x, vec.y, vec.z)
						
						if(changed)then
							entity.transform:SetPosition(vec)
						end
                    end

                    imgui.EndTabItem()
                end



                imgui.EndTabBar()
            end
        end
        imgui.End()
        if not open then
            -- Close the window
            for idx, win in ipairs(module.active_windows) do
                if win == window then
                    table.remove(module.active_windows, idx)
                    break
                end
            end
        end
    else
        -- Entity no longer exists, remove window
        for idx, win in ipairs(module.active_windows) do
            if win == window then
                table.remove(module.active_windows, idx)
                break
            end
        end
    end
end

module.ShowCheatsTab = function()
    if imgui.Button("WIP") then
        -- Implement your cheat functionality here
        GamePrint("This button does nothing!")
    end
end

return module
