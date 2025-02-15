local types = require("../types")
local Page = require("../protocol/Page")

export type BoxModel = types.BoxModel

local function content_viewport(self: BoxModel): Page.Viewport
	return {
		x = self.content.top_left.x,
		y = self.content.top_left.y,
		width = self.content:width(),
		height = self.content:height(),
		scale = 1,
	}
end

local function padding_viewport(self: BoxModel): Page.Viewport
	return {
		x = self.padding.top_left.x,
		y = self.padding.top_left.y,
		width = self.padding:width(),
		height = self.padding:height(),
		scale = 1,
	}
end

local function border_viewport(self: BoxModel): Page.Viewport
	return {
		x = self.border.top_left.x,
		y = self.border.top_left.y,
		width = self.border:width(),
		height = self.border:height(),
		scale = 1,
	}
end

local function margin_viewport(self: BoxModel): Page.Viewport
	return {
		x = self.margin.top_left.x,
		y = self.margin.top_left.y,
		width = self.margin:width(),
		height = self.margin:height(),
		scale = 1,
	}
end

--- @within BoxModel
local function new(box_model: {
	content: types.ElementQuad,
	padding: types.ElementQuad,
	border: types.ElementQuad,
	margin: types.ElementQuad,
	width: number,
	height: number,
}): BoxModel
	return {
		content = box_model.content,
		padding = box_model.padding,
		border = box_model.border,
		margin = box_model.margin,
		width = box_model.width,
		height = box_model.height,
		content_viewport = content_viewport,
		padding_viewport = padding_viewport,
		border_viewport = border_viewport,
		margin_viewport = margin_viewport,
	}
end

return { new = new }
