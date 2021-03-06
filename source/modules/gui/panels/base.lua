local gui = require("gui")

require("extensions.table")

local PANEL = {}

local graphics = love.graphics

function PANEL:Initialize()
	self.m_tChildren = {}
	self.m_tOrphans = {}
	self.m_iWorldPosX = 0
	self.m_iWorldPosY = 0
	self.m_fScaleX = 1
	self.m_fScaleY = 1
	self.m_iPosX = 0
	self.m_iPosY = 0
	self.m_iWidth = 42
	self.m_iHeight = 24
	self.m_bHovered = false
	self.m_pParent = nil
	self.m_iZPos = 0
	self.m_bScissorEnabled = true
	self.m_bValidated = false
	self.m_bVisible = true
	self.m_bFocusable = true
	self.m_bOrphaned = false
	self.m_bDeleted = false
	self.m_iDock = 0
	self.m_tDockMargins = { left = 4, top = 4, right = 4, bottom = 4 }
	self.m_tDockPadding = { left = 4, top = 4, right = 4, bottom = 4 }
end

function PANEL:GetClassName()
	return self.__classname
end

function PANEL:__tostring()
	return ("Panel[%q]"):format(self.__classname)
end

function PANEL:GetConfig()
	local w, h = self:GetActualSize()
	local sx, sy = self:GetScale()

	local config = {
		classname = self:GetClassName(),
		pos = { x = self:GetX(), y = self:GetY(), z = self:GetZPos() },
		size = { width = w, height = h },
		scale = { x = sx, y = sy },
		visible = self:IsVisible(),
		accessors = self.__accessors,
	}

	if self.m_iDock ~= 0 then
		config.dock = {
			mode = self.m_iDock,
			margins = self.m_tDockMargins,
			padding = self.m_tDockPadding,
		}
	end

	return config
end

function PANEL:SetVisible(b)
	self.m_bVisible = b
end

function PANEL:IsVisible()
	return self.m_bVisible
end

function PANEL:SetFocusable(b)
	self.m_bFocusable = b
end

function PANEL:IsFocusable()
	return self.m_bFocusable
end

function PANEL:BringToFront()
	local parent = self.m_pParent
	if not parent then return end -- There's nothing for it to go in front of!
	
	local highest = nil

	for _,child in ipairs(parent.m_tChildren) do
		if not highest or child:GetZPos() > highest:GetZPos() then
			highest = child
		end
	end

	-- No panels or the highest is already ourself
	if not highest or highest == self then return end

	-- Get the position of the highest panel
	local replace = highest:GetZPos()

	-- Set the highest panel to our current position
	highest:SetZPos(self:GetZPos())

	-- Set our position to where the highest panel used to be
	self:SetZPos(replace)
end

function PANEL:Dock(i)
	self.m_iDock = i
	self:InvalidateLayout()
end

function PANEL:GetDock()
	return self.m_iDock
end

function PANEL:DockMargin(left, top, right, bottom)
	self.m_tDockMargins.left = left
	self.m_tDockMargins.top = top
	self.m_tDockMargins.right = right
	self.m_tDockMargins.bottom = bottom
end

function PANEL:GetDockMargin()
	return self.m_tDockMargins
end

function PANEL:DockPadding(left, top, right, bottom)
	self.m_tDockPadding.left = left
	self.m_tDockPadding.top = top
	self.m_tDockPadding.right = right
	self.m_tDockPadding.bottom = bottom
end

function PANEL:GetDockPadding()
	return self.m_tDockPadding
end

function PANEL:GetWidthPlusMargin()
	if not self:IsVisible() then return 0 end
	local margins = self:GetDockMargin()
	return margins.left + margins.right + self:GetWidth()
end

function PANEL:GetHeightPlusMargin()
	if not self:IsVisible() then return 0 end
	local margins = self:GetDockMargin()
	return margins.top + margins.bottom + self:GetHeight()
end

function PANEL:GetSizePlusMargin()
	local w, h = self:GetWidthPlusMargin(), self:GetHeightPlusMargin()

	--[[for _,child in ipairs(self.m_tChildren) do
		if child:IsVisible() then
			margins = child:GetDockMargin()
			padding = child:GetDockPadding()
			w = w + margins.left + margins.right + padding.left + padding.right
			h = h + margins.top + margins.bottom + padding.top + padding.bottom
		end
	end]]

	return w, h
end

--[[function PANEL:GetSpaceAround(panel)
	local margins = panel:GetDockMargin()
	local padding = panel:GetDockPadding()

	local w = margins.left + margins.right + padding.left + padding.right
	local h = margins.top + margins.bottom + padding.top + padding.bottom

	for _,child in ipairs(self.m_tChildren) do
		if child ~= panel and child:IsVisible() then
			local margins = child:GetDockMargin()
			local padding = child:GetDockPadding()
			w = w + margins.left + margins.right + padding.left + padding.right + child:GetWidth()
			h = h + margins.top + margins.bottom + padding.top + padding.bottom + child:GetHeight()
		end
	end

	local width, height = self:GetSize()

	return w, h
end]]

function PANEL:SetZPos(i)
	self.m_iZPos = i
	self:GetParent():ReorderChildren()
end

function PANEL:ReorderChildren()
	table.sort(self.m_tChildren, function(a, b) return a.m_iZPos < b.m_iZPos end)
end

function PANEL:GetZPos()
	return self.m_iZPos
end

function PANEL:CallAll(func, ...)
	if not self:IsVisible() then return end
	self[ func ](self, ...)
	for _,child in ipairs(self.m_tChildren) do
		child:CallAll(func, ...)
	end
end

function PANEL:CallSelfAndParents(func, ...)
	if not self:IsVisible() then return end
	if self[ func ](self, ...) then return end
	local parent = self.m_pParent
	if not parent then return end
	parent:CallSelfAndParents(func, ...)
end

function PANEL:Remove()
	local parent = self:GetParent()
	if parent then
		parent:OnChildRemoved(self)
	end

	self.m_bDeleted = true
	self:OnRemoved()

	for zpos, child in ipairs(self.m_tChildren) do
		child:Remove()
	end
end

function PANEL:Clear()
	for zpos, child in ipairs(self.m_tChildren) do
		child:Remove()
	end
end

function PANEL:InvalidateLayout()
	self.m_bValidated = false
	for _,child in ipairs(self.m_tChildren) do
		child:InvalidateLayout()
	end
end

function PANEL:InvalidateParent()
	if not self.m_pParent then return end
	self.m_pParent:InvalidateLayout()
end

function PANEL:MarkAsOrphan()
	self.m_bOrphaned = true
end

function PANEL:CleanupOrphans()
	for key, child in reversedipairs(self.m_tChildren) do
		child:CleanupOrphans()
		if child.m_bOrphaned then
			table.remove(self.m_tChildren, key)
		end
	end
end

function PANEL:CleanupDeleted()
	for key, child in reversedipairs(self.m_tChildren) do
		child:CleanupDeleted()
		if child.m_bDeleted then
			self.m_tChildren[key] = nil
			table.remove(self.m_tChildren, key)
		end
	end
end

function PANEL:SetParent(parent)
	if self.m_pParent then
		self:MarkAsOrphan()
	end
	self.m_pParent = parent
	if parent then
		table.insert(parent.m_tChildren, self)
		parent:OnChildAdded(self)
		self:SetZPos(#parent.m_tChildren)
	end
end

function PANEL:HasParent()
	return self:GetParent() ~= nil
end

function PANEL:GetParent()
	return self.m_pParent
end

function PANEL:GetParents()
	local parents = {}
	
	local parent = self:GetParent()
	
	while parent do
		table.insert(parents, parent)
		parent = parent:GetParent()
	end
	return parents
end

function PANEL:GetChildren()
	return self.m_tChildren
end

function PANEL:GetFamily(family)
	local family = family or {}
	
	local children = self.m_tChildren
	family[self] = children
	
	for _,child in ipairs(children) do
		child:GetFamily(family[self])
	end
	
	return family
end

function PANEL:SizeToScreen()
	self:SetSize(graphics.getPixelDimensions())
end

function PANEL:SizeToChildren(doWidth, doHeight)
	local w,h = 0, 0
	local padding = self:GetDockPadding()

	w = padding.left	-- + padding.right
	h = padding.top		-- + padding.bottom

	local lw, lh = 0, 0

	for _,child in ipairs(self.m_tChildren) do
		if child:IsVisible() then
			local x, y = child:GetPos()
			local margin = child:GetDockMargin()
			local cw, ch = child:GetSize()

			-- Position + size + margins = maximum bounds
			cw = x + cw + margin.left + margin.right
			ch = y + ch + margin.top + margin.bottom

			-- Update the largest widths and heights
			if cw > lw then lw = cw end
			if ch > lh then lh = ch end
		end
	end
	if doWidth then self:SetWidth(w + lw) end
	if doHeight then self:SetHeight(h + lh) end
end

function PANEL:Add(class)
	return gui.create(class, self)
end

function PANEL:SetScale(x, y)
	y = y or x
	self.m_fScaleX, self.m_fScaleY = x, y
end

function PANEL:GetScale()
	return self.m_fScaleX, self.m_fScaleY
end

function PANEL:SetPos(x, y)
	self.m_iPosX, self.m_iPosY = x, y
end

function PANEL:GetPos()
	return self.m_iPosX, self.m_iPosY
end

function PANEL:SetWorldPos(x, y)
	self.m_iWorldPosX, self.m_iWorldPosY = x, y
end

function PANEL:GetWorldPos()
	return self.m_iWorldPosX, self.m_iWorldPosY
end

function PANEL:LocalToWorld(x, y)
	local sx, sy = self:GetPos()
	x = x + sx
	y = y + sy
	
	local parent = self:GetParent()
	
	while parent do
		local px, py = parent:GetPos()
		x = x + px
		y = y + py
		parent = parent:GetParent()
	end
	
	return x, y
end
PANEL.LocalToScreen = PANEL.LocalToWorld

function PANEL:WorldToLocal(x, y)
	local sx, sy = self:LocalToScreen(0, 0)
	return x - sx, y - sy
end
PANEL.ScreenToLocal = PANEL.WorldToLocal

function PANEL:SetX(x)
	self.m_iPosX = x
end

function PANEL:GetX()
	return self.m_iPosX
end

function PANEL:SetY(y)
	self.m_iPosY = y
end

function PANEL:GetY()
	return self.m_iPosY
end

function PANEL:SetSize(w, h)
	self:SetWidth(w)
	self:SetHeight(h)
	self:OnResize(w, h)
end

function PANEL:GetSize()
	return self.m_iWidth * self.m_fScaleX, self.m_iHeight * self.m_fScaleY
end

function PANEL:GetActualSize()
	return self.m_iWidth, self.m_iHeight
end

function PANEL:SetWidth(w)
	if self.m_iWidth ~= w then
		self.m_iWidth = w
		self:InvalidateLayout()
	end
end

function PANEL:GetWidth()
	return self.m_iWidth * self.m_fScaleX
end

function PANEL:SetHeight(h)
	if self.m_iHeight ~= h then
		self.m_iHeight = h
		self:InvalidateLayout()
	end
end

function PANEL:GetHeight()
	return self.m_iHeight * self.m_fScaleY
end

function PANEL:IsWorldPointInside(x, y)
	local px, py = self:LocalToScreen(0, 0)
	return x > px and x < px + self:GetWidth() and y > py and y < py + self:GetHeight()
end

function PANEL:Render()
	if not self:IsVisible() then return end

	local x, y = self:LocalToScreen(0, 0)
	local w, h = self:GetSize()
	
	local parent = self:GetParent()
	
	-- Start the scissor position and size with our own values
	local sx, sy = x, y
	local sw, sh = w, h

	while self.m_bScissorEnabled and parent do
		-- If we have a parent, fit the scissor to fit inside their bounds
		local px, py = parent:LocalToScreen(0, 0)
		local pw, ph = parent:GetSize()

		if sx < px then
			sw = math.max(0, sw + sx - px)
			sx = px
		end
		if sx + sw > px + pw then
			sw = math.max(0, sw - ((sx + sw) - (px + pw)))
			sx = math.min(sx, px + pw)
		end
		if sy < py then
			sh = math.max(0, sh + sy - py)
			sy = py
		end
		if sy + sh > py + ph then
			sh = math.max(0, sh - ((sy + sh) - (py + ph)))
			sy = math.min(sy, py + ph)
		end

		parent = parent:GetParent()
	end

	graphics.push() -- Push the current graphics state
		if self.m_bScissorEnabled then
			graphics.setScissor(sx, sy, sw, sh) -- Set our scissor so things can't be drawn outside the panel
		end
			graphics.translate(x, y) -- Translate so Paint has localized position values for drawing objects
			graphics.scale(self:GetScale())
				local uw, uh = self:GetActualSize()
				self:SetWorldPos(x, y)
				graphics.setColor(255, 255, 255, 255)
				self:PrePaint(uw, uh)
				graphics.setColor(255, 255, 255, 255)
				self:Paint(uw, uh)
				graphics.setColor(255, 255, 255, 255)
				self:PostPaint(uw, uh)
			graphics.origin()
		if self.m_bScissorEnabled then
			graphics.setScissor()
		end
	graphics.pop() -- Reset the graphics state to what it was

	-- recently added panels are drawn last, thus, ontop of older panels
	for _, child in ipairs(self.m_tChildren) do
		child:Render()
	end

	graphics.push()
		if self.m_bScissorEnabled then
			graphics.setScissor(sx, sy, sw, sh) -- Set our scissor so things can't be drawn outside the panel
		end
			graphics.translate(x, y)
			graphics.scale(self:GetScale())
				graphics.setColor(255, 255, 255, 255)
				self:PaintOverlay(self:GetActualSize())
			graphics.origin()
		if self.m_bScissorEnabled then
			graphics.setScissor()
		end
	graphics.pop() -- Reset the graphics state to what it was

	if self.m_bDebug then
		-- Debug the scissor rect
		graphics.setColor(255, 0, 0, 25)
		graphics.rectangle("fill", sx, sy, sw, sh)
	end
end

function PANEL:DisableScissor()
	self.m_bScissorEnabled = false
end

function PANEL:ValidateLayout()
	if self:IsVisible() and not self.m_bValidated then
		self.m_bValidated = true
		self:DockLayout()
		self:PerformLayout()
	end

	for _,child in ipairs(self.m_tChildren) do
		child:ValidateLayout()
	end
end

function PANEL:Center(vertical, horizontal)
	local parent = self:GetParent()

	local w, h = self:GetSize()
	local pw, ph = graphics.getPixelDimensions() -- Default to window size if no parent
	if parent then
		pw, ph = parent:GetSize()
	end

	-- If both vertical and horizontal aren't set, center to both?
	local all = not vertical and not horizontal

	if vertical or all then
		self:SetY((ph / 2) - (h / 2))
	end
	if horizontal or all then
		self:SetX((pw / 2) - (w / 2))
	end
end

function PANEL:CenterVertical()
	self:Center(true, false)
end

function PANEL:CenterHorizontal()
	self:Center(false, true)
end

function PANEL:DockLayout()
	local x, y = 0, 0
	local w, h = self:GetSize()
	
	local padding = self.m_tDockPadding
	
	for _,child in ipairs(self.m_tChildren) do
		local margin = child.m_tDockMargins
	
		local dx = x + padding.left
		local dy = y + padding.top
		local dw = w - (padding.left + padding.right)
		local dh = h - (padding.top + padding.bottom)
	
		local dock = child.m_iDock
		if dock ~= DOCK_NONE and child:IsVisible() then
			if(dock == DOCK_TOP) then
				child:SetPos(dx + margin.left, dy + margin.top)
				child:SetSize(dw - margin.left - margin.right, child:GetHeight())
				local height = margin.top + margin.bottom + child:GetHeight()
				y = y + height
				h = h - height
			elseif(dock == DOCK_LEFT) then
				child:SetPos(dx + margin.left, dy + margin.top)
				child:SetSize(child:GetWidth(), dh - margin.top - margin.bottom)
				local width = margin.left + margin.right + child:GetWidth()
				x = x + width
				w = w - width
			elseif(dock == DOCK_RIGHT) then
				child:SetPos((dx + dw) - child:GetWidth() - margin.right, dy + margin.top)
				child:SetSize(child:GetWidth(), dh - margin.top - margin.bottom)
				local width = margin.left + margin.right + child:GetWidth()
				w = w - width
			elseif(dock == DOCK_BOTTOM) then
				child:SetPos(dx + margin.left, (dy + dh) - child:GetHeight() - margin.bottom)
				child:SetSize(dw - margin.left - margin.right, child:GetHeight())
				h = h - (child:GetHeight() + margin.bottom + margin.top)
			end
		end
	end
	
	for _,child in ipairs(self.m_tChildren) do
		local dock = child.m_iDock
		
		if dock ~= DOCK_NONE and child:IsVisible() then
			local margin = child.m_tDockMargins
		
			local dx = x + padding.left
			local dy = y + padding.top
			local dw = w - (padding.left + padding.right)
			local dh = h - (padding.top + padding.bottom)
			
			if(dock == DOCK_FILL) then
				child:SetPos(dx + margin.left, dy + margin.top)
				child:SetSize(dw - margin.left - margin.right, dh - margin.top - margin.bottom)
			end
		end
	end
end

function PANEL:GiveFocus()
	gui.setFocusedPanel(self)
end

function PANEL:MakePopup()
	self:BringToFront()
	self:GiveFocus()
end

function PANEL:HasFocus(checkchildren)
	if checkchildren then
		for _,child in ipairs(self.m_tChildren) do
			if child:HasFocus(checkchildren) then
				return true
			end
		end
	end
	return gui.getFocusedPanel() == self
end

function PANEL:IsHovered()
	return gui.getHoveredPanel() == self
end

function PANEL:GetHoveredChild(x, y, ignore)
	local panel = nil
	for _,child in reversedipairs(self.m_tChildren) do
		if child:IsVisible() and child:IsFocusable() and child:IsWorldPointInside(x, y) and ((ignore and child ~= ignore) or not ignore) then
			panel = child:GetHoveredPanel(x, y)
			break
		end
	end
	return panel
end

function PANEL:GetHoveredPanel(x, y, ignore)
	local panel = self
	for _,child in reversedipairs(self.m_tChildren) do
		if child:IsVisible() and child:IsFocusable() and child:IsWorldPointInside(x, y) and ((ignore and child ~= ignore) or not ignore) then
			panel = child:GetHoveredPanel(x, y)
			break
		end
	end
	return panel
end

-- PANEL OVERRIDE DEFAULTS

function PANEL:PerformLayout()
	-- Called when we are Validating the layout.
	-- Good for manually positioning child panels.
end

function PANEL:PrePaint(w, h)
end

function PANEL:Paint(w, h)
	-- Called every frame, when we are drawing the panel to the screen.
	-- Used to draw custom things within the panel.
end

function PANEL:PostPaint(w, h)
end

function PANEL:PaintOverlay(w, h)
end

function PANEL:OnResize(w, h)
	-- Called when the size of the panel has changed.
	-- Good for manually positioning child panels, like in PerformLayout.
end

function PANEL:OnFocusChanged(b)
	-- Called when the panels focus has either been gained or lost
end

function PANEL:OnKeyPressed(key, hex)
	-- Called when the panel is focused, and a keyboard key has been pressed
end

function PANEL:OnKeyReleased(key)
	-- Called when the panel is focused, and a keyboard key has been released
end

function PANEL:OnTextInput(text)
	-- Called when the panel is focused.
	-- Good for a text input panel.
end

function PANEL:OnJoyPressed(joy, but)
	-- Override
end

function PANEL:OnJoyReleased(joy, but)
	-- Override
end

function PANEL:OnMouseMoved(x, y, dx, dy, istouch)
	--[[
	Called when when the mouse has been moved.

	number x
		The mouse position on the x-axis.
	number y
		The mouse position on the y-axis.
	number dx
		The amount moved along the x-axis since the last time love.mousemoved was called.
	number dy
		The amount moved along the y-axis since the last time love.mousemoved was called.

	Returning true will stop the event from going up the family tree
	Child->Parent->Parent->Parent->etc, etc..
	]]
	
	return false
end

function PANEL:OnMousePressed(x, y, button, istouch, presses)
	--[[
	Called when a mouse press event has been made.

	number x
		The mouse position on the x-axis.
	number y
		The mouse position on the y-axis.
	number dx
		The amount moved along the x-axis since the last time love.mousemoved was called.
	number dy
		The amount moved along the y-axis since the last time love.mousemoved was called.

	Returning true will stop the event from going up the family tree
	Child->Parent->Parent->Parent->etc, etc..
	]]
	
	return false
end

function PANEL:OnMouseReleased(x, y, button, istouch, presses)
	--[[
	Called when a mouse release event has been made.

	number x
		The mouse position on the x-axis.
	number y
		The mouse position on the y-axis.
	number dx
		The amount moved along the x-axis since the last time love.mousemoved was called.
	number dy
		The amount moved along the y-axis since the last time love.mousemoved was called.

	Returning true will stop the event from going up the family tree
	Child->Parent->Parent->Parent->etc, etc..
	]]
	
	return false
end

function PANEL:OnMouseWheeled(x, y)
	--[[
	Called when the scrollwheel has been turned.

	number x
		Amount of horizontal mouse wheel movement. Positive values indicate movement to the right.
	number y
		Amount of vertical mouse wheel movement. Positive values indicate upward movement.

	See an example in..
	gui/panels/core/scrollpanel.lua 
	&
	gui/panels/core/scrollbar.lua 

	Returning true will stop the event from going up the family tree
	Child->Parent->Parent->Parent->etc, etc..
    ]]

	return false
end

function PANEL:OnChildAdded(panel)
	-- Called when a panel has been added
end

function PANEL:OnRemoved()
	
end

function PANEL:OnChildRemoved(panel)
	-- Called when a panel has been removed
end

function PANEL:Think(dt)
	-- Called every frame
end

gui.register("Base", PANEL)