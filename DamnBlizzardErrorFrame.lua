local L = {
	["Last"] = "Last",
	["First"] = "First",
	["No errors yet!"] = "No errors yet!",
}

-- Blizzards error handler isn't loaded until all addons are parsed, this overrides the default one and queues the errors for the time being
local errorsQueued = {}

-- Random output
local function output(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Damn Errors|r: " .. msg)
end

local function hookErrorFrame()
	-- Stops a C stack overflow error this mod stopping the highlight
	ScriptErrorsFrameScrollFrameText.cursorOffset = 0
	ScriptErrorsFrameScrollFrameText.cursorHeight = 0

	-- Stop text highlighting
	ScriptErrorsFrameScrollFrameText:SetScript("OnEditFocusGained", nil)
	local Orig_ScriptErrorsFrame_Update = ScriptErrorsFrame_Update
	ScriptErrorsFrame_Update = function(...)
		Orig_ScriptErrorsFrame_Update(...)
		
		ScriptErrorsFrameScrollFrameText:HighlightText(0, 0)
	end
	
	-- Unhighlight text when focus is hit
	ScriptErrorsFrameScrollFrameText:HookScript("OnEscapePressed", function(self)
		self:HighlightText(0, 0)
	end)
	
	-- Add a first button
	local firstButton = CreateFrame("Button", nil, ScriptErrorsFrame, "UIPanelButtonTemplate")
	firstButton:SetPoint("BOTTOMLEFT", ScriptErrorsFrame, "BOTTOMLEFT", 8, 8)
	firstButton:SetText(L["First"])
	firstButton:SetHeight(20)
	firstButton:SetWidth(50)
	firstButton:SetScript("OnClick", function(self)
		ScriptErrorsFrame.index = 1
		ScriptErrorsFrame_Update()
	end)

	-- Also add a Last button for errors
	local lastButton = CreateFrame("Button", nil, ScriptErrorsFrame, "UIPanelButtonTemplate")
	lastButton:SetPoint("BOTTOMLEFT", ScriptErrorsFrame.next, "BOTTOMRIGHT", 2, 0)
	lastButton:SetHeight(20)
	lastButton:SetWidth(60)
	lastButton:SetText(L["Last"])
	lastButton:SetScript("OnClick", function(self)
		ScriptErrorsFrame.index = #(ScriptErrorsFrame.order)
		ScriptErrorsFrame_Update()
	end)
		
	-- Reduce the total size of the buttons to free up more room
	ScriptErrorsFrame.previous:ClearAllPoints()
	ScriptErrorsFrame.previous:SetPoint("BOTTOMLEFT", firstButton, "BOTTOMRIGHT", 0, 0)
	ScriptErrorsFrame.previous:SetWidth(80)
	ScriptErrorsFrame.previous:SetHeight(20)
	
	ScriptErrorsFrame.next:ClearAllPoints()
	ScriptErrorsFrame.next:SetPoint("BOTTOMLEFT", ScriptErrorsFrame.previous, "BOTTOMRIGHT", 0, 0)
	ScriptErrorsFrame.next:SetWidth(60)
	ScriptErrorsFrame.next:SetHeight(20)

	ScriptErrorsFrame.close:ClearAllPoints()
	ScriptErrorsFrame.close:SetPoint("BOTTOMRIGHT", ScriptErrorsFrame, "BOTTOMRIGHT", -4, 8)
	ScriptErrorsFrame.close:SetHeight(20)
	ScriptErrorsFrame.close:SetWidth(50)

	-- Shift the #/# error label to the right more
	ScriptErrorsFrame.indexLabel:ClearAllPoints()
	ScriptErrorsFrame.indexLabel:SetPoint("BOTTOMLEFT", ScriptErrorsFrame, 270, 11)
	
	-- Disable last button when needed
	local Orig_ScriptErrorsFrame_UpdateButtons = ScriptErrorsFrame_UpdateButtons
	ScriptErrorsFrame_UpdateButtons = function(...)
		Orig_ScriptErrorsFrame_UpdateButtons(...)
		
		if( ScriptErrorsFrame.index == 1 ) then
			firstButton:Disable()
		elseif( #(ScriptErrorsFrame.order) > 1 ) then
			firstButton:Enable()
		end
		
		if( ScriptErrorsFrame.index == #(ScriptErrorsFrame.order) ) then
			lastButton:Disable()
		else
			lastButton:Enable()
		end
	end
	
	-- Increase the error frame size
	local BASE_HEIGHT = ScriptErrorsFrame:GetHeight()
	local BASE_WIDTH = ScriptErrorsFrame:GetWidth()
	local NEW_HEIGHT = 95
	local NEW_WIDTH = 16
	
	ScriptErrorsFrame:SetWidth(BASE_WIDTH + NEW_WIDTH)
	ScriptErrorsFrame:SetHeight(BASE_HEIGHT + NEW_HEIGHT)
	ScriptErrorsFrameScrollFrame:SetWidth(ScriptErrorsFrameScrollFrame:GetWidth() + NEW_WIDTH)
	ScriptErrorsFrameScrollFrame:SetHeight(ScriptErrorsFrameScrollFrame:GetHeight() + NEW_HEIGHT + 4)
end

-- Dump all queued errors
local function dumpErrors()
	if( not errorsQueued ) then return end
	
	-- Revert to Blizzards error handler since we're done watching the queue
	seterrorhandler(_ERRORMESSAGE)
	
	if( #(errorsQueued) == 0 ) then return end
	
	-- Dump the queued errors
	for _, data in pairs(errorsQueued) do
		local messageStack = data.message .. data.stack
		local index = ScriptErrorsFrame.seen[messageStack]
		if( index ) then
			ScriptErrorsFrame.count[index] = ScriptErrorsFrame.count[index] + 1
			ScriptErrorsFrame.messages[index] = data.mesasge
			ScriptErrorsFrame.times[index] = data.date
			ScriptErrorsFrame.locals[index] = data.locals
		else
			table.insert(ScriptErrorsFrame.order, data.stack)
			index = #(ScriptErrorsFrame.order)
			
			ScriptErrorsFrame.count[index] = 1
			ScriptErrorsFrame.messages[index] = data.message
			ScriptErrorsFrame.times[index] = data.date
			ScriptErrorsFrame.locals[index] = data.locals
			ScriptErrorsFrame.seen[messageStack] = index
		end
	end

	errorsQueued = nil

	ScriptErrorsFrame.index = 1
	ScriptErrorsFrame:Show()
end

-- Handle watching for the error frame to load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addon)
	-- For some weird reason, we can't call LoadAddon now, so if we have any queued errors will load debug tools
	-- and let that handle dumping them
	if( event == "PLAYER_LOGIN" ) then
		if( errorsQueued and #(errorsQueued) > 0 ) then
			-- Load Blizzards debug tools
			LoadAddOn("Blizzard_DebugTools")
			if( not IsAddOnLoaded("Blizzard_DebugTools") ) then
				output(L["Failed to load Blizzard_DebugTools, can't print queued errors."])
				return
			end
		end
		
	-- Debug tools loaded yay
	elseif( event == "ADDON_LOADED" and addon == "Blizzard_DebugTools" ) then
		self:UnregisterEvent("ADDON_LOADED")

		hookErrorFrame()
		dumpErrors()
	end
end)

-- Add a slash command to force the error frame open
SLASH_ERRORFRAME1 = "/errors"
SLASH_ERRORFRAME2 = "/error"
SLASH_ERRORFRAME3 = "/errorframe"
SlashCmdList["ERRORFRAME"] = function(msg)
	if( not IsAddOnLoaded("Blizzard_DebugTools") or #(ScriptErrorsFrame.order) == 0 ) then
		output(L["No errors yet!"])
	else
		ScriptErrorsFrame.index = tonumber(msg) or #(ScriptErrorsFrame.order)
		ScriptErrorsFrame_Update()
		ScriptErrorsFrame:Show()
	end
end

-- Override Blizzards error handler, this way when PLAYER_LOGIN fires we can process the queue into the normal frame
seterrorhandler(function(message)
	-- Blizzards wasn't loaded yet sadly, queue the error up
	if( not IsAddOnLoaded("Blizzard_DebugTools") ) then
		table.insert(errorsQueued, {message = message, stack = debugstack(2), locals = debuglocals(4), date = date()})
	end
	
	return messages
end)