import "chars"
import "stringUtil"
import "mathUtil"
max = @mathUtil.max; min = @mathUtil.min

import "textUtil"
Dialog = textUtil.Dialog
textRow = @textUtil.textRow; textCol = @textUtil.textCol

swatch = chars.inverseOn + chars.buttonCapLeft + " " +
   chars.buttonCapRight + chars.inverseOff

typeColor = {}
typeColor.string = "#FF8888"
typeColor.number = "#00AA00"
typeColor.funcRef = "#FF8800"
typeColor.list = "#8888FF"
typeColor.map = "#CC44CC"

//----------------------------------------------------------------------
// MulticolumnDialog: a Dialog subclass that allows you to explore a tree
// hierarchy. It's a three-column layout: the middle column (1) always contains
// the selection; column 0 is the container of the selection (or "root");
// and column 2 is a preview of the contents of the selected item.
MulticolumnDialog = new Dialog
MulticolumnDialog.width = 50
MulticolumnDialog.listTextColor = "#AAAAFF"
MulticolumnDialog.listBackColor = "#222222"
MulticolumnDialog.curDirBackColor = "#444466"
MulticolumnDialog.selTextColor = "#000044"
MulticolumnDialog.selBackColor = "#FFFF00"
MulticolumnDialog.directoryIcon = "/"
MulticolumnDialog.dirIndColor = function
	return color.lerp(self.listTextColor, self.listBackColor, 0.5)
end function
MulticolumnDialog.origDisp0 = null
MulticolumnDialog.playingSound = null
MulticolumnDialog.selection = "" // item path or unique identifier
MulticolumnDialog.Make = function(title="Select", width=null)
	dlog = Dialog.make(title)
	dlog.__isa = self	// because Dialog.make doesn't use `new self` :(
	dlog.okBtn.caption = "Select"
	dlog.height = 18
	dlog.cancelBtn.visible = true
	dlog.items = []
	if width != null then dlog.width = width
	dlog.colWidth = []
	dlog.colWidth.push floor((dlog.width-4)/3)
	dlog.colWidth.push dlog.colWidth[0]
	dlog.colWidth.push dlog.width - 6 - dlog.colWidth[0]*2
	dlog.colLeft = [dlog.left+2]
	dlog.colLeft.push dlog.colLeft[0] + 1 + dlog.colWidth[0]
	dlog.colLeft.push dlog.colLeft[1] + 1 + dlog.colWidth[1]
	dlog.scroll = [0,0,0]
	dlog.selIdx = 0
	return dlog
end function

MulticolumnDialog.scrollIntoView = function(colNum, items, selectedIndex, padding=2)
	posInView = selectedIndex - self.scroll[colNum]
	if posInView < padding then
		self.scroll[colNum] = max(0, selectedIndex - padding)
		return
	end if
	if items == null then items = self.items
	rows = self.height - 5
	if posInView > rows - padding then
		self.scroll[colNum] = selectedIndex - rows + padding
	end if
end function

MulticolumnDialog.selectIdx = function(newSelIdx, padding=6)
	if not self.items then
		self.selIdx = -1
		return
	end if
	self.selIdx = newSelIdx % self.items.len
	if self.selIdx < 0 then self.selIdx += self.items.len
	self.scrollIntoView 1, self.items, self.selIdx, padding
	self.selectItem self.items[self.selIdx]
	self.drawItems
	self.drawItemPreview
	return true
end function

// Abstract methods that subclasses should implement:
MulticolumnDialog.getItemsForContainer = function(container)
	// Return list of items in the given container
end function

MulticolumnDialog.isLeafItem = function(item)
	// Return true if item has no children (leaf node)
end function

MulticolumnDialog.getChildren = function(item)
	// Return list of child items for non-leaf item
end function

MulticolumnDialog.getParentContainer = function(container)
	// Return parent container of the given container
end function

MulticolumnDialog.getItemIdentifier = function(item)
	// Return unique identifier/path for the item
end function

MulticolumnDialog.selectItem = function(item)
	// Called when an item is selected - subclass can update state
end function

MulticolumnDialog.drawItemPreview = function
	// Draw preview of currently selected item in column 2
end function

MulticolumnDialog.drawCurrentContainer = function
	// Draw the current container path/name
end function

MulticolumnDialog.drawParentContainer = function
	// draw parent and its sibling items in column 0
	self.drawItems 0, self.getItemsForParentContainer
end function

MulticolumnDialog.stopItemPreview = function
	// Stop any active preview (sounds, images, etc.)
end function

MulticolumnDialog.highlightedInColumn = function(colNum)
	// Return index of highlighted item in the given column
	if colNum == 1 then return self.selIdx
	return 0
end function

MulticolumnDialog.drawItems = function(colNum=1, items=null)
	if items == null then items = self.items
	width = self.colWidth[colNum]
	text.row = self.top - 2
	rows = self.height - 5
	highlightedIdx = self.highlightedInColumn(colNum)	
	scroll = self.scroll[colNum]
	
	for row in range(0, rows-1)
		idx = scroll + row
		hilight = false; selected = false; isLeaf = true; hasItem = false; s = ""
		if items and idx < items.len then
			item = items[idx]
			s = str(item.name)
			isLeaf = self.isLeafItem(item)
			hasItem = true
			itemId = self.getItemIdentifier(item)
			if self.selection.startsWith(itemId) then hilight = true
			if colNum == 1 and idx == self.selIdx then selected = true
		end if
		s = s.pad(width)
		if selected then
			text.color = self.selTextColor
			text.backColor = self.selBackColor
		else
			text.color = item.color // ToDo: make this work for FileDialog too!
			text.backColor = self.curDirBackColor * hilight + self.listBackColor * (not hilight)
		end if
		text.column = self.colLeft[colNum]; print s, ""
		if hasItem and not isLeaf then
			text.color = self.dirIndColor
			print char(8) + self.directoryIcon
			text.color = self.listTextColor
		else
			print
		end if
	end for
end function

MulticolumnDialog.drawContent = function(cols, rows)
	self.drawCurrentContainer
	self.drawParentContainer
	self.drawItems
	self.drawItemPreview
end function

MulticolumnDialog.drawPreviewText = function(lines)
	text.color = self.listTextColor
	text.backColor = self.listBackColor
	TAB = char(9)
	for row in range(0, self.height-6)
		text.column = self.colLeft[2]
		if row < lines.len then s = lines[row].replace(TAB, "  ") else s = ""
		text.row = self.top - 2 - row
		print s.pad(self.colWidth[2]), ""
		if s.len == 7 or s.len == 9 and s[0] == "#" then
			// if this is a color string, draw a color swatch!
			isColor = true
			for c in s.upper[1:]
				if not ("0" <= c <= "9") and not ("A" <= c <= "F") then
					isColor = false
					break
				end if
			end for
			if isColor then
				text.color = s
				print char(8) * 4 + swatch
			end if
		end if
	end for	
end function

MulticolumnDialog.cleanup = function
	self.stopItemPreview
end function

MulticolumnDialog.handleKey = function(k)
	self.stopItemPreview
	kcode = k.code
	count = self.items.len
	rows = self.height - 6
	if kcode == 19 then return self.selectIdx(self.selIdx-1)	// up-arrow
	if kcode == 20 then return self.selectIdx(self.selIdx+1)	// down-arrow
	if kcode == 1 then return self.selectIdx(0)					// Home
	if kcode == 5 then return self.selectIdx(count-1)			// End
	if kcode == 21 then return self.selectIdx(
			mathUtil.clamp(self.selIdx - rows, 0, count-1))		// Page Up
	if kcode == 4 then return self.selectIdx(
			mathUtil.clamp(self.selIdx + rows, 0, count-1))		// Page Down
	if kcode == 10 or kcode == 3 or kcode == 18 then	// return or right-arrow
		if not (0 <= self.selIdx < self.items.len) then return false
		item = self.items[self.selIdx]
		if self.isLeafItem(item) then return false
		children = self.getChildren(item)
		if children then 
			// Navigate into the item - subclass handles specifics
			return self.navigateInto(item, children)
		end if
		return true
	else if kcode == 17 then							// left-arrow
		// Navigate up - subclass handles specifics
		return self.navigateUp()
	end if
	for i in self.items.indexes
		if self.items[i].name[0].lower == k then return self.selectIdx(i)
	end for
end function

MulticolumnDialog.navigateInto = function(item, children)
	// Abstract method - subclass should implement navigation into item
	return false
end function

MulticolumnDialog.navigateUp = function
	// Abstract method - subclass should implement navigation up
	return false
end function

MulticolumnDialog.handleMouse = function
	row = textRow(mouse.y)
	if row > self.top-2 or row < self.top-2 - (self.height-6) then return false
	col = textCol(mouse.x)
	if col >= self.colLeft[0] and col < self.colLeft[0]+self.colWidth[0] then
		hitColumn = 0		// parent container column
		items = self.getItemsForParentContainer()
	else if col >= self.colLeft[1] and col < self.colLeft[1]+self.colWidth[1] then
		hitColumn = 1		// selection column
		items = self.items
	else if col >= self.colLeft[2] and col < self.colLeft[2]+self.colWidth[2] then
		hitColumn = 2		// preview column
		items = self.getItemsForPreviewColumn()
		if not items then return false
	else
		return false
	end if
	hitIdx = self.top - 2 - row + self.scroll[hitColumn]
	if not items or hitIdx >= items.len then return false

	// Select the clicked item - subclass handles specifics
	self.selectClickedItem items[hitIdx]
	self.drawItems
	self.drawItemPreview
	while mouse.button; yield; end while
	return true
end function

MulticolumnDialog.getItemsForParentContainer = function
	// Abstract method - subclass should return items for parent container
	return []
end function

MulticolumnDialog.getItemsForPreviewColumn = function
	// Abstract method - subclass should return items for preview column
	return []
end function

MulticolumnDialog.selectClickedItem = function(item)
	// Abstract method - subclass should handle item selection
end function

MulticolumnDialog.handleMouseWheel = function(axisValue)
	if axisValue > 0 then
		self.selectIdx(self.selIdx-1)
	else
		self.selectIdx(self.selIdx+1)
	end if
	wait 0.1  // pause a little between scrolls
end function

//----------------------------------------------------------------------
// FileDialog: a MulticolumnDialog subclass for picking a folder or file.
FileDialog = new MulticolumnDialog

// Implementation of abstract methods for file system navigation
FileDialog.getItemsForContainer = function(container)
	return FileDialog.GetFileInfoForDir(container)
end function

FileDialog.isLeafItem = function(item)
	return not item.isDirectory
end function

FileDialog.getChildren = function(item)
	return file.children(item.path)
end function

FileDialog.getParentContainer = function(container)
	return file.parent(container)
end function

FileDialog.getItemIdentifier = function(item)
	globals.whazit = item
	return item.path
end function

FileDialog.selectItem = function(item)
	self.stopItemPreview
	self.selection = item.path
	dir = file.parent(item.path)
	changedDir = false
	if dir != self.directory then
		self.directory = dir
		self.drawCurrentContainer
		self.drawParentContainer
		self.items = FileDialog.GetFileInfoForDir(self.directory)
		changedDir = true
	end if
	for i in self.items.indexes
		if self.items[i].path == item.path then
			self.selIdx = i
			break
		end if
	end for
	if changedDir then self.scrollIntoView 1, self.items, self.selIdx
end function

FileDialog.navigateInto = function(item, children)
	if children then
		newSelection = file.child(item.path, children[0])
		self.selectItem {"path": newSelection}
	end if
	self.drawItems
	self.drawItemPreview
	return true
end function

FileDialog.navigateUp = function
	parent = file.parent(self.selection)
	if parent == "/" then return true
	self.selectItem {"path": self.directory}
	self.drawItems
	self.drawItemPreview
	return true
end function

FileDialog.getItemsForParentContainer = function
	if self.directory == "/" then
		return [{"name":"(disks)", "path":"", "isDirectory":true}]
	else
		return FileDialog.GetFileInfoForDir(file.parent(self.directory))
	end if
end function

FileDialog.getItemsForPreviewColumn = function
	if not (0 <= self.selIdx < self.items.len) then return []
	f = self.items[self.selIdx]
	if not f.isDirectory then return []
	return FileDialog.GetFileInfoForDir(f.path)
end function

FileDialog.selectClickedItem = function(item)
	self.selectItem item
end function

FileDialog.drawItemPreview = function
	if not (0 <= self.selIdx < self.items.len) then
		self.drawPreviewText []
		return
	end if
	f = self.items[self.selIdx]
	if f.isDirectory then
		self.drawItems 2, FileDialog.GetFileInfoForDir(f.path)
		return
	end if
	n = f.name
	if n.endsWith(".ms") or n.endsWith(".txt") or n.endsWith(".md") or
	  n.endsWith(".json") or n.endsWith(".grfon") then
		inp = file.open(f.path)
		lines = []
		for i in range(0, self.height-6)
			line = inp.readLine; if line == null then break
			lines.push line
		end for
		inp.close
		self.drawPreviewText lines
		return
	end if
	if n.endsWith(".wav") or n.endsWith(".ogg") then
		snd = file.loadSound(f.path)
		if snd != null then
			snd.play
			self.playingSound = snd
			self.drawPreviewText ["Sound", "", "duration:", str(snd.duration)]
			return
		end if
	end if
	if n.endsWith(".jpg") or n.endsWith(".jpeg") or n.endsWith(".png") then
		self.drawPreviewText []
		pic = file.loadImage(f.path)
		if pic != null then
			self.origDisp0 = display(0)
			disp = new PixelDisplay
			disp.clear color.clear
			disp.install 0
			x = (self.colLeft[2] + self.colWidth[2]/2)*14.05
			y = (self.top-2 - (self.height-6)/2) * 25
			w = self.colWidth[2] * 14
			h = (self.height-6) * 24
			scaleH = w/pic.width; scaleV = h/pic.height
			if scaleH < scaleV then scale = scaleH else scale = scaleV
			disp.drawImage pic, x-pic.width*scale/2, y-pic.height*scale/2,
			  pic.width*scale, pic.height*scale
		end if
		return
	end if
	self.drawPreviewText []
end function

FileDialog.drawCurrentContainer = function
	text.color = self.textColor; text.backColor = self.backColor
	text.row = self.top - 1; text.column = self.left + 2
	print self.directory.pad(self.width-4)
end function

//FileDialog.drawParentContainer = function
//	if self.directory == "/" then
//		text.row = self.top - 2
//		text.column = self.colLeft[0]
//		text.color = self.listTextColor
//		text.backColor = self.listBackColor
//		print "(disks)".pad(self.colWidth[0]-1), ""
//		text.color = self.dirIndColor; print self.directoryIcon
//		for row in range(1, self.height-6)
//			text.column = self.colLeft[0]; print " " * self.colWidth[0]
//		end for
//	else
//		items = FileDialog.GetFileInfoForDir(file.parent(self.directory))
//		self.drawItems 0, items
//	end if
//end function

FileDialog.stopItemPreview = function
	if self.playingSound then
		self.playingSound.stop
		self.playingSound = null
	end if	
	if self.origDisp0 then
		self.origDisp0.install 0
		if self.origDisp0.mode == 0 then display(0).mode = 0 // (bug work-around)
		self.origDisp0 = null
	end if
end function

FileDialog.Make = function(title="Select file", width=null)
	dlog = super.Make(title, width)
	dir = file.curdir
	if file.children(file.curdir) == null then dir = "/sys"
	dlog.directory = dir - "/"
	items = file.children(dir)
	if items then dlog.selection = file.child(dir, items[0])
	dlog.items = FileDialog.GetFileInfoForDir(dlog.directory)
	return dlog
end function
FileDialog.make = @FileDialog.Make // (for backwards compatibility)

FileDialog.GetFileInfoForDir = function(dir)
	items = file.children(dir)
	if not items then return []
	for i in range(items.len - 1)
		items[i] = file.info(file.child(dir, items[i]))
		if items[i] == null then
			items.remove i
		else
			items[i].name = file.name(items[i].path)
		end if
	end for
	items.sort "name"
	return items
end function

//----------------------------------------------------------------------
// DataDialog: a multi-column dialog for exploring a data structure
// composed of lists and/or maps.

DataDialog = new MulticolumnDialog
DataDialog.directoryIcon = "•"
DataDialog.root = null // DataDialog.Item at base of our hierarchy
DataDialog.curNode = null // current container, shown in leftmost column

// Helper class to represent one item in our hierarchy.
DataDialog.Item = {}
DataDialog.name = ""
DataDialog.value = null
DataDialog.Item.parent = null
DataDialog.Item.fallbackColor = "#AAAAFF"

DataDialog.Item.Make = function(name, value, parent)
	noob = new self
	noob.name = name
	noob.value = @value
	noob.parent = parent
	return noob
end function

DataDialog.Item.path = function
	names = [self.name]
	p = self.parent
	while p
		names.insert 0, p.name
		p = p.parent
	end while
	return join(names, ".")
end function

DataDialog.Item.children = function
	if not (@self.value isa map or @self.value isa list) then return []
	result = []
	indexes = self.value.indexes
	indexes.sort
	for k in indexes
		childValue = @self.value[@k]
		result.push DataDialog.Item.Make(k, @childValue, self)
	end for
	return result
end function	

DataDialog.Item.color = function
	v = @self.value
	if @v isa funcRef then return typeColor.funcRef
	if v isa string then return typeColor.string
	if v isa number then return typeColor.number
	if v isa list then return typeColor.list
	if v isa map then return typeColor.map
	return self.fallbackColor
end function

// Implementation of abstract methods for data structure navigation
DataDialog.getItemsForContainer = function(container)
	return container.children
end function

DataDialog.isLeafItem = function(item)
	value = @item.value
	return not (@value isa list or @value isa map)
end function

DataDialog.getChildren = function(item)
	return item.children
end function

DataDialog.getParentContainer = function(container)
	return container.parent
end function

DataDialog.getItemIdentifier = function(item)
	return item.path
end function

DataDialog.selectItem = function(item)
	self.stopItemPreview
	self.selection = item.path
	changedDir = false
	if item.parent != self.curNode then
		self.curNode = item.parent
		self.drawCurrentContainer
		self.drawParentContainer
		self.items = self.curNode.children
		changedDir = true
	end if
	for i in self.items.indexes
		if self.items[i].name == item.name then
			self.selIdx = i
			break
		end if
	end for
	if changedDir then self.scrollIntoView 1, self.items, self.selIdx
end function

DataDialog.navigateInto = function(item, children)
	if children then
		globals.newSelection = children[0]
		self.selectItem newSelection
	end if
	self.drawItems
	self.drawItemPreview
	return true
end function

DataDialog.navigateUp = function
	parent = self.items[self.selIdx].parent
	if parent == null or parent == self.root then return true
	self.selectItem parent
	self.drawItems
	self.drawItemPreview
	return true
end function

DataDialog.getItemsForParentContainer = function
	if self.curNode.parent then return self.curNode.parent.children
	return [self.root]
end function

DataDialog.getItemsForPreviewColumn = function
	if not (0 <= self.selIdx < self.items.len) then return []
	item = self.items[self.selIdx]
	return item.children
end function

DataDialog.selectClickedItem = function(item)
	self.selectItem item
end function

DataDialog.drawItemPreview = function
	if not (0 <= self.selIdx < self.items.len) then
		self.drawPreviewText []
		return
	end if
	item = self.items[self.selIdx]
	if not self.isLeafItem(item) then
		self.drawItems 2, item.children
		return
	end if
	v = @item.value
	if @v isa funcRef then
		s = str(@v)
		if s.endsWith("()") then
			self.drawPreviewText [s]
		else
			// Split after "(", before ")", and after any ", " that's not quoted
			parts = []
			i = 0
			inQuote = false
			while i < s.len
				if s[i] == """" then
					inQuote = not inQuote
				else if s[i] == "(" or i+1 < s.len and s[i+1] == ")" then
					parts.push s[:i+1]
					s = s[i+1:]
					i = -1
				else if s[i:i+2] == ", " then
					parts.push s[:i]
					s = s[i+2:]
					i = -1
				end if
				i += 1
			end while
			parts.push s
			self.drawPreviewText parts
		end if
		return
	end if
	if v isa string or v isa number then
		s = str(v)
		self.drawPreviewText s.splitLines
		return
	end if
	if v isa Sound then
		snd.play
		self.playingSound = snd
		self.drawPreviewText ["Sound", "", "duration:", str(snd.duration)]
		return
	end if
	if v isa Image then
		self.drawPreviewText []
		pic = v
		if pic != null then
			self.origDisp0 = display(0)
			disp = new PixelDisplay
			disp.clear color.clear
			disp.install 0
			x = (self.colLeft[2] + self.colWidth[2]/2)*14.05
			y = (self.top-2 - (self.height-6)/2) * 25
			w = self.colWidth[2] * 14
			h = (self.height-6) * 24
			scaleH = w/pic.width; scaleV = h/pic.height
			if scaleH < scaleV then scale = scaleH else scale = scaleV
			disp.drawImage pic, x-pic.width*scale/2, y-pic.height*scale/2,
			  pic.width*scale, pic.height*scale
		end if
		return
	end if
	self.drawPreviewText []
end function

DataDialog.drawCurrentContainer = function
	text.color = self.textColor; text.backColor = self.backColor
	text.row = self.top - 1; text.column = self.left + 2
	print self.curNode.path.pad(self.width-4)
end function

DataDialog.stopItemPreview = function
	if self.playingSound then
		self.playingSound.stop
		self.playingSound = null
	end if	
	if self.origDisp0 then
		self.origDisp0.install 0
		if self.origDisp0.mode == 0 then display(0).mode = 0 // (bug work-around)
		self.origDisp0 = null
	end if
end function

DataDialog.Make = function(name, value, width=null)
	dlog = super.Make("Data Digger", width)
	dlog.root = DataDialog.Item.Make(name, value)
	dlog.curNode = dlog.root
	dlog.items = dlog.root.children
	return dlog
end function

DataDialog.GetItemsForValue = function(mapOrList)
	items = file.children(dir)
	if not items then return []
	for i in range(items.len - 1)
		items[i] = file.info(file.child(dir, items[i]))
		if items[i] == null then
			items.remove i
		else
			items[i].name = file.name(items[i].path)
		end if
	end for
	items.sort "name"
	return items
end function



if locals == globals then
	text.backColor = color.clear
	clear
//	globals.d = FileDialog.Make

	globals.test = {}
	test.foo = {}
	test.bar = 42
	test.foo.baz = "boy"
	test.foo.bamf = "howdy"
	test.testColor = "#FFFF88FF"
	//globals.d = DataDialog.Make("test", @test)
	globals.d = DataDialog.Make("globals", @globals)
	
	hit = d.show
	if hit == d.okBtn then print "You selected: " + d.selection	
end if
