if ModIsEnabled("NoitaDearImGui") then
    imgui = load_imgui({ mod = "noita-online", version = "1.20" })
    implot = imgui.implot
end

local module = {
    open = false,
    active_windows = {},
    searchText = "",
    showChildEntities = false,
	entityPickerActive = false,
}

local GetMousePos = function()
    local input_manager = EntityGetWithName("mp_input_manager")
    if(input_manager == nil or not EntityGetIsAlive(input_manager))then
        input_manager = EntityLoad("mods/evaisa.mp/files/entities/input_manager.xml")
    end

    local b_width = tonumber(game_config.get("internal_size_w")) or 1280
    local b_height = tonumber(game_config.get("internal_size_h")) or 720

    local controls_component = EntityGetFirstComponentIncludingDisabled(input_manager, "ControlsComponent")
    local mouse_raw_x, mouse_raw_y = ComponentGetValue2(controls_component, "mMousePositionRaw")
    local mx, my = mouse_raw_x / b_width, mouse_raw_y / b_height

    return mx, my
end

module.Update = function()
    if InputIsKeyJustDown(12) then -- F1
        module.open = not module.open
    end

	if(module.entityPickerActive)then
		local camera_transform = {
			RenderingSystem.camera.position.x,
			RenderingSystem.camera.position.y,
			RenderingSystem.camera.position.z,
			RenderingSystem.camera.rotation
		}

		local mouse_x, mouse_y = GetMousePos()

		print("Mouse Pos: " .. tostring(mouse_x) .. ", " .. tostring(mouse_y))

		local world_pos = RenderingSystem.screenUVToWorld(mouse_x, mouse_y, camera_transform)

		local point = Vector3(world_pos[1], world_pos[2], 0)

		print("World Pos: " .. tostring(point))
		
		RenderingSystem.DrawLine(point, Vector3(point.x, point.y, 5), 1, 1, 0, 0, 1)
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
				if imgui.BeginTabItem("Debug") then
					module.ShowDebugTab()
					imgui.EndTabItem()
				end
                if imgui.BeginTabItem("Cheats") then
                    module.ShowCheatsTab()
                    imgui.EndTabItem()
                end
				if imgui.BeginTabItem("Camera") then
					module.ShowCameraTab()
					imgui.EndTabItem()
				end
				if imgui.BeginTabItem("Rendering") then
					module.ShowRenderingTab()
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
    local changed, newText = imgui.InputText("Search", module.searchText)
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

            local show_entity = true
            -- check search text against all columns
            if (string.find(string.lower(tostring(entity._id)), string.lower(module.searchText)) == nil and
                string.find(string.lower(entity._type), string.lower(module.searchText)) == nil and
                string.find(string.lower(tostring(entity.network_id)), string.lower(module.searchText)) == nil and
                string.find(string.lower(entity._name), string.lower(module.searchText)) == nil and
                string.find(string.lower(steam_utils.getTranslatedPersonaName(entity._owner)), string.lower(module.searchText)) == nil) then
                show_entity = false
            end

            if (entity:GetParent() ~= nil and not module.showChildEntities) then
                show_entity = false
            end

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

module.ShowCameraTab = function()
	--[[
		local camera_mode = {
		orbit = 1,
		freecam = 2,
		follow = 3,
	}

	CameraSystem = {
		mode = camera_mode.follow,
		position = Vector3.new(0, 0, 25),
		rotation = 0,
		height = 25,
		target_entity = nil,
		follow_distance = 10,
		follow_speed = 0.1,
	}
	]]


	for key, value in pairs(CameraSystem) do
		if type(value) ~= "function" and string.sub(key, 1, 1) ~= "_" then
			local valueType = type(value)
			if key == "mode" then
				-- dropdown with camera modes
				local modes = { "orbit", "freecam", "follow" }
				local mode = CameraSystem.mode
				local changed, new_mode = imgui.Combo("Mode", mode, modes)
				if changed then
					CameraSystem.mode = new_mode
				end
			elseif valueType == "number" then
				local changed, newValue = imgui.DragFloat(key, value)
				if changed then
					CameraSystem[key] = newValue
				end
			elseif valueType == "string" then
				local changed, newValue = imgui.InputText(key, value)
				if changed then
					CameraSystem[key] = newValue
				end
			elseif valueType == "boolean" then
				local changed, newValue = imgui.Checkbox(key, value)
				if changed then
					CameraSystem[key] = newValue
				end
			elseif valueType == "table" then
				-- Check if the table is a Vector or Vector3
				if(value.is_entity)then
					local entity = value
					local entity_name = entity._name or ""
					local window_id = "EntityWindow##" .. entity._id
					local window_open = false
					for _, win in ipairs(module.active_windows) do
						if win.window_id == window_id then
							window_open = true
							break
						end
					end

					imgui.Text(key .. ": " .. entity_name)
					imgui.SameLine()
					if not window_open then
						if imgui.Button("Open##" .. entity._id) then
							local window = {
								window_id = window_id,
								window_name = "Entity " .. entity._id .. " - " .. (entity._name or "Unnamed"),
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
				elseif module.IsVector(value) then
					local vec = { x = value.x or 0, y = value.y or 0, z = value.z }
					local changed = false
					if vec.z ~= nil then
						changed, vec.x, vec.y, vec.z = imgui.DragFloat3(key, vec.x, vec.y, vec.z)
					else
						changed, vec.x, vec.y = imgui.DragFloat2(key, vec.x, vec.y)
					end
					if changed then
						value.x = vec.x
						value.y = vec.y
						if vec.z ~= nil then
							value.z = vec.z
						end
					end
				else
					if imgui.TreeNode(key .. "##" .. tostring(value)) then
						module.DrawTable(value)
						imgui.TreePop()
					end
				end
			else
				imgui.Text(key .. ": " .. tostring(value))
			end
		end
	end
end

module.ShowDebugTab = function()
	-- draw checkbox for Debug Rendering
	local changed, newValue = imgui.Checkbox("Debug Gizmos", RenderingSystem.debug_gizmos)
	if changed then
		RenderingSystem.debug_gizmos = newValue
	end
	-- entity picker checkbox
	changed, newValue = imgui.Checkbox("Entity Picker", module.entityPickerActive)
	if changed then
		module.entityPickerActive = newValue
	end
end

module.ShowRenderingTab = function()
	for key, value in pairs(RenderingSystem) do
		if type(value) ~= "function" and string.sub(key, 1, 1) ~= "_" then
			local valueType = type(value)
			if valueType == "number" then
				local changed, newValue = imgui.DragFloat(key, value)
				if changed then
					RenderingSystem[key] = newValue
				end
			elseif valueType == "string" then
				local changed, newValue = imgui.InputText(key, value)
				if changed then
					RenderingSystem[key] = newValue
				end
			elseif valueType == "boolean" then
				local changed, newValue = imgui.Checkbox(key, value)
				if changed then
					RenderingSystem[key] = newValue
				end
			elseif valueType == "table" then
				-- Check if the table is a Vector or Vector3
				if(value.is_entity)then
					local entity = value
					local entity_name = entity._name or ""
					local window_id = "EntityWindow##" .. entity._id
					local window_open = false
					for _, win in ipairs(module.active_windows) do
						if win.window_id == window_id then
							window_open = true
							break
						end
					end

					imgui.Text(key .. ": " .. entity_name)
					imgui.SameLine()
					if not window_open then
						if imgui.Button("Open##" .. entity._id) then
							local window = {
								window_id = window_id,
								window_name = "Entity " .. entity._id .. " - " .. (entity._name or "Unnamed"),
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
				elseif module.IsVector(value) then
					local vec = { x = value.x or 0, y = value.y or 0, z = value.z }
					local changed = false
					if vec.z ~= nil then
						changed, vec.x, vec.y, vec.z = imgui.DragFloat3(key, vec.x, vec.y, vec.z)
					else
						changed, vec.x, vec.y = imgui.DragFloat2(key, vec.x, vec.y)
					end
					if changed then
						value.x = vec.x
						value.y = vec.y
						if vec.z ~= nil then
							value.z = vec.z
						end
					end
				else
					if imgui.TreeNode(key .. "##" .. tostring(value)) then
						module.DrawTable(value)
						imgui.TreePop()
					end
				end
			else
				imgui.Text(key .. ": " .. tostring(value))
			end
		end
	end
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
                    local changed, new_name = imgui.InputText("Name", entity_name)
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

                        if (changed) then
                            entity.transform:SetPosition(vec)
                        end
                    end

                    imgui.EndTabItem()
                end

                -- Components Tab
                if imgui.BeginTabItem("Components") then
                    module.ShowComponents(entity)
                    imgui.EndTabItem()
                end

                -- Children Tab
                if imgui.BeginTabItem("Children") then
                    module.ShowChildEntities(entity)
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

-- Function to display components
module.ShowComponents = function(entity)
    local components = entity._components or {}
    imgui.Text("Components: " .. #components)
    imgui.Separator()

    if imgui.BeginTable("ComponentListTable", 3, imgui.TableFlags.BordersInnerV + imgui.TableFlags.Resizable) then
        imgui.TableSetupColumn("Type", imgui.TableColumnFlags.WidthStretch)
        imgui.TableSetupColumn("Properties", imgui.TableColumnFlags.WidthStretch)
        imgui.TableSetupColumn("Actions", imgui.TableColumnFlags.WidthFixed)
        imgui.TableHeadersRow()

        for _, component in ipairs(components) do
            imgui.TableNextRow()
            imgui.TableNextColumn()
            imgui.Text(component._type or "Unknown")
            imgui.TableNextColumn()

            if imgui.TreeNode("Properties##" .. tostring(component)) then
                for key, value in pairs(component) do
                    if type(value) ~= "function" and string.sub(key, 1, 1) ~= "_" then
                        imgui.Text(tostring(key) .. ": " .. tostring(value))
                    end
                end
                imgui.TreePop()
            end
            imgui.TableNextColumn()

            -- Open button for component
            local window_id = "ComponentWindow##" .. tostring(component)
            local window_open = false
            for _, win in ipairs(module.active_windows) do
                if win.window_id == window_id then
                    window_open = true
                    break
                end
            end

            if not window_open then
                if imgui.Button("Open##" .. tostring(component)) then
                    local window = {
                        window_id = window_id,
                        window_name = "Component - " .. (component._type or "Unknown"),
                        component = component,
                        draw_window = module.ComponentEditor,
                    }
                    table.insert(module.active_windows, window)
                end
            else
                if imgui.Button("Close##" .. tostring(component)) then
                    for idx, win in ipairs(module.active_windows) do
                        if win.window_id == window_id then
                            table.remove(module.active_windows, idx)
                            break
                        end
                    end
                end
            end
        end

        imgui.EndTable()
    end
end

-- Function to display child entities
module.ShowChildEntities = function(entity)
    local children = entity:GetChildren() or {}
    imgui.Text("Child Entities: " .. #children)
    imgui.Separator()

    if imgui.BeginTable("ChildEntityListTable", 3, imgui.TableFlags.BordersInnerV + imgui.TableFlags.Resizable) then
        imgui.TableSetupColumn("ID", imgui.TableColumnFlags.WidthFixed)
        imgui.TableSetupColumn("Name", imgui.TableColumnFlags.WidthStretch)
        imgui.TableSetupColumn("Actions", imgui.TableColumnFlags.WidthStretch)
        imgui.TableHeadersRow()

        for _, child in ipairs(children) do
            imgui.TableNextRow()
            imgui.TableNextColumn()
            imgui.Text(tostring(child._id))
            imgui.TableNextColumn()
            imgui.Text(child._name or "Unnamed")
            imgui.TableNextColumn()

            local window_id = "EntityWindow##" .. child._id
            local window_open = false
            for _, win in ipairs(module.active_windows) do
                if win.window_id == window_id then
                    window_open = true
                    break
                end
            end

            if not window_open then
                if imgui.Button("Open##" .. child._id) then
                    local window = {
                        window_id = window_id,
                        window_name = "Entity " .. child._id .. " - " .. (child._name or "Unnamed"),
                        entity = child,
                        draw_window = module.EntityInspector,
                    }
                    table.insert(module.active_windows, window)
                end
            else
                if imgui.Button("Close##" .. child._id) then
                    for idx, win in ipairs(module.active_windows) do
                        if win.window_id == window_id then
                            table.remove(module.active_windows, idx)
                            break
                        end
                    end
                end
            end
        end

        imgui.EndTable()
    end
end

-- Function to edit component properties
module.ComponentEditor = function(window)
    local component = window.component
    if component then
        imgui.SetNextWindowSize(400, 600, imgui.Cond.FirstUseEver)
        local open = true
        local should_draw
        should_draw, open = imgui.Begin(window.window_name .. "###" .. window.window_id, open)
        if should_draw then
            imgui.Text("Component Type: " .. (component._type or "Unknown"))
            imgui.Separator()

            -- Editable properties
            for key, value in pairs(component) do
                if type(value) ~= "function" and string.sub(key, 1, 1) ~= "_" then
                    local valueType = type(value)
                    if valueType == "number" then
                        local changed, newValue = imgui.DragFloat(key, value)
                        if changed then
                            component[key] = newValue
                        end
                    elseif valueType == "string" then
                        local changed, newValue = imgui.InputText(key, value)
                        if changed then
                            component[key] = newValue
                        end
                    elseif valueType == "boolean" then
                        local changed, newValue = imgui.Checkbox(key, value)
                        if changed then
                            component[key] = newValue
                        end
                    elseif valueType == "table" then
                        -- Check if the table is a Vector or Vector3
                        if(value.is_entity)then
							local entity = value
							local entity_name = entity._name or ""
							local window_id = "EntityWindow##" .. entity._id
							local window_open = false
							for _, win in ipairs(module.active_windows) do
								if win.window_id == window_id then
									window_open = true
									break
								end
							end
	
							imgui.Text(key .. ": " .. entity_name)
							imgui.SameLine()
							if not window_open then
								if imgui.Button("Open##" .. entity._id) then
									local window = {
										window_id = window_id,
										window_name = "Entity " .. entity._id .. " - " .. (entity._name or "Unnamed"),
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
						elseif module.IsVector(value) then
                            local vec = { x = value.x or 0, y = value.y or 0, z = value.z }
                            local changed = false
                            if vec.z ~= nil then
                                changed, vec.x, vec.y, vec.z = imgui.DragFloat3(key, vec.x, vec.y, vec.z)
                            else
                                changed, vec.x, vec.y = imgui.DragFloat2(key, vec.x, vec.y)
                            end
                            if changed then
                                value.x = vec.x
                                value.y = vec.y
                                if vec.z ~= nil then
                                    value.z = vec.z
                                end
                            end
                        else
                            if imgui.TreeNode(key .. "##" .. tostring(value)) then
                                module.DrawTable(value)
                                imgui.TreePop()
                            end
                        end
                    else
                        imgui.Text(key .. ": " .. tostring(value))
                    end
                end
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
        -- Component no longer exists, remove window
        for idx, win in ipairs(module.active_windows) do
            if win == window then
                table.remove(module.active_windows, idx)
                break
            end
        end
    end
end

-- Helper function to check if a table is a vector
module.IsVector = function(value)
    if type(value) == "table" then
        local has_x = type(value.x) == "number"
        local has_y = type(value.y) == "number"
        if has_x and has_y then
            return true
        end
    end
    return false
end

module.SerializeTable = function(tbl, indent)
    indent = indent or 0
    local formatting = string.rep("    ", indent)
    local result = "{\n"
    for k, v in pairs(tbl) do
        local key
        if type(k) == "string" then
            key = string.format("[\"%s\"]", k)
        else
            key = string.format("[%s]", tostring(k))
        end

        if type(v) == "table" then
            result = result .. formatting .. "    " .. key .. " = " .. module.SerializeTable(v, indent + 1) .. ",\n"
        elseif type(v) == "string" then
            result = result .. formatting .. "    " .. key .. " = \"" .. v .. "\",\n"
        elseif type(v) == "number" or type(v) == "boolean" then
            result = result .. formatting .. "    " .. key .. " = " .. tostring(v) .. ",\n"
        else
            result = result .. formatting .. "    " .. key .. " = \"<unsupported type>\",\n"
        end
    end
    result = result .. formatting .. "}"
    return result
end

module.DrawTable = function(tbl, depth)
    depth = depth or 0

    local keys = {}
    for key, value in pairs(tbl) do
        if type(value) ~= "function" and string.sub(key, 1, 1) ~= "_" then
            table.insert(keys, key)
        end
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        local value = tbl[key]
        local valueType = type(value)
        if valueType == "number" then
            local changed, newValue = imgui.DragFloat(key, value)
            if changed then
                tbl[key] = newValue
            end
        elseif valueType == "string" then
            local changed, newValue = imgui.InputText(key, value)
            if changed then
                tbl[key] = newValue
            end
        elseif valueType == "boolean" then
            local changed, newValue = imgui.Checkbox(key, value)
            if changed then
                tbl[key] = newValue
            end
        elseif valueType == "table" then
            if module.IsVector(value) then
                local vec = { x = value.x or 0, y = value.y or 0, z = value.z }
                local changed = false
                if vec.z ~= nil then
                    changed, vec.x, vec.y, vec.z = imgui.DragFloat3(key, vec.x, vec.y, vec.z)
                else
                    changed, vec.x, vec.y = imgui.DragFloat2(key, vec.x, vec.y)
                end
                if changed then
                    value.x = vec.x
                    value.y = vec.y
                    if vec.z ~= nil then
                        value.z = vec.z
                    end
                end
            else
                if imgui.TreeNode(key .. "##" .. tostring(value)) then
                    module.DrawTable(value, depth + 1)
                    imgui.TreePop()
                end
            end
        else
            imgui.Text(key .. ": " .. tostring(value))
        end
    end

    if depth == 0 then
        if imgui.Button("Export Table") then
            local luaText = module.SerializeTable(tbl)
            steam.utils.setClipboard(luaText)
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
