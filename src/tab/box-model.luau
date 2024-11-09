local ElementQuad = require("./element-quad")
local Page = require("../protocol/Page")

--- @class BoxModel
export type BoxModel = {
	content: ElementQuad.ElementQuad,
	padding: ElementQuad.ElementQuad,
	border: ElementQuad.ElementQuad,
	margin: ElementQuad.ElementQuad,
	width: number,
	height: number,
	contentViewport: (self: BoxModel) -> Page.Viewport,
	paddingViewport: (self: BoxModel) -> Page.Viewport,
	borderViewport: (self: BoxModel) -> Page.Viewport,
	marginViewport: (self: BoxModel) -> Page.Viewport,
}

--- Create a `Page.Viewport` equal to the content-box, using a scale of 1.0
--- @within BoxModel
local function contentViewport(self: BoxModel): Page.Viewport
	return {
		x = self.content.topLeft.x,
		y = self.content.topLeft.y,
		width = self.content:width(),
		height = self.content:height(),
		scale = 1,
	}
end

--- Create a `Page.Viewport` equal to the padding-box, using a scale of 1.0
--- @within BoxModel
local function paddingViewport(self: BoxModel): Page.Viewport
	return {
		x = self.padding.topLeft.x,
		y = self.padding.topLeft.y,
		width = self.padding:width(),
		height = self.padding:height(),
		scale = 1,
	}
end

--- Create a `Page.Viewport` equal to the border-box, using a scale of 1.0
--- @within BoxModel
local function borderViewport(self: BoxModel): Page.Viewport
	return {
		x = self.border.topLeft.x,
		y = self.border.topLeft.y,
		width = self.border:width(),
		height = self.border:height(),
		scale = 1,
	}
end

--- Create a `Page.Viewport` equal to the margin-box, using a scale of 1.0
--- @within BoxModel
local function marginViewport(self: BoxModel): Page.Viewport
	return {
		x = self.margin.topLeft.x,
		y = self.margin.topLeft.y,
		width = self.margin:width(),
		height = self.margin:height(),
		scale = 1,
	}
end

--- @within BoxModel
local function new(boxModel: {
	content: ElementQuad.ElementQuad,
	padding: ElementQuad.ElementQuad,
	border: ElementQuad.ElementQuad,
	margin: ElementQuad.ElementQuad,
	width: number,
	height: number,
}): BoxModel
	return {
		content = boxModel.content,
		padding = boxModel.padding,
		border = boxModel.border,
		margin = boxModel.margin,
		width = boxModel.width,
		height = boxModel.height,
		contentViewport = contentViewport,
		paddingViewport = paddingViewport,
		borderViewport = borderViewport,
		marginViewport = marginViewport,
	}
end

return { new = new }
