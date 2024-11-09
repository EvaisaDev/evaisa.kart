if(ModIsEnabled("NoitaDearImGui"))then
	imgui = load_imgui({mod="noita-online", version="1.20"})
	implot = imgui.implot
end

local module = {
	open = false
}

module.Update = function()
	if(InputIsKeyJustDown(12))then
		module.open = not module.open
	end
end

module.Draw = function()
	if(imgui and module.open)then
		imgui.SetNextWindowSize(480, 200, imgui.Cond.FirstUseEver)
		local should_draw
		should_draw, module.open = imgui.Begin("Entities", module.open)

		local table_flags = bit.bor(imgui.TableFlags.Resizable, imgui.TableFlags.Hideable, imgui.TableFlags.RowBg)

		if imgui.TableGetSortSpecs then
			table_flags = bit.bor(table_flags, imgui.TableFlags.Sortable)
		end

		if imgui.BeginTable("entity_table", 5, table_flags) then
			imgui.TableSetupColumn("ID", imgui.TableColumnFlags.WidthFixed)
			imgui.TableSetupColumn("Type", imgui.TableColumnFlags.WidthStretch, 6)
			imgui.TableSetupColumn("NetworkID", imgui.TableColumnFlags.WidthStretch, 12)
			imgui.TableSetupColumn("Name", imgui.TableColumnFlags.WidthFixed)
			imgui.TableSetupColumn("Owner", imgui.TableColumnFlags.WidthStretch, 6)
			imgui.TableHeadersRow() -- *
	
			for _, entity in pairs(EntitySystem.entities) do
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

			end
	
			imgui.EndTable()
		end
		imgui.End()
	end
end

return module