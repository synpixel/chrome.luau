type Point = { x: number, y: number }

--- @class ElementQuad
export type ElementQuad = {
	topLeft: Point,
	topRight: Point,
	bottomRight: Point,
	bottomLeft: Point,
	height: (self: ElementQuad) -> number,
	width: (self: ElementQuad) -> number,
	aspectRatio: (self: ElementQuad) -> number,
	mostLeft: (self: ElementQuad) -> number,
	mostRight: (self: ElementQuad) -> number,
	mostTop: (self: ElementQuad) -> number,
	mostBottom: (self: ElementQuad) -> number,
	strictlyAbove: (self: ElementQuad, other: ElementQuad) -> boolean,
	above: (self: ElementQuad, other: ElementQuad) -> boolean,
	strictlyBelow: (self: ElementQuad, other: ElementQuad) -> boolean,
	below: (self: ElementQuad, other: ElementQuad) -> boolean,
	strictlyLeftOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	leftOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	strictlyRightOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	rightOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	withinHorizontalBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	withinVerticalBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	withinBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
}

--- @within ElementQuad
local function height(self: ElementQuad): number
	return self.bottomLeft.y - self.topLeft.y
end

--- @within ElementQuad
local function width(self: ElementQuad): number
	return self.topRight.x - self.topLeft.x
end

--- The width divided by the height
--- @within ElementQuad
local function aspectRatio(self: ElementQuad): number
	return self:width() / self:height()
end

--- The most left (smallest) x-coordinate
--- @within ElementQuad
local function mostLeft(self: ElementQuad): number
	return math.min(self.topRight.x, self.topLeft.x, self.bottomRight.x, self.bottomLeft.x)
end

--- The most right (largest) x-coordinate
--- @within ElementQuad
local function mostRight(self: ElementQuad): number
	return math.max(self.topRight.x, self.topLeft.x, self.bottomRight.x, self.bottomLeft.x)
end

--- The most top (smallest) y-coordinate
--- @within ElementQuad
local function mostTop(self: ElementQuad): number
	return math.min(self.topRight.y, self.topLeft.y, self.bottomRight.y, self.bottomLeft.y)
end

--- The most bottom (largest) y-coordinate
--- @within ElementQuad
local function mostBottom(self: ElementQuad): number
	return math.max(self.topRight.y, self.topLeft.y, self.bottomRight.y, self.bottomLeft.y)
end

--- If the most bottom point of `self` is above the most top point of `other`
--- @within ElementQuad
local function strictlyAbove(self: ElementQuad, other: ElementQuad): boolean
	return self:mostBottom() < other:mostTop()
end

--- If the most bottom point of `self` is above or on the same line as the
--- most top point of `other`
--- @within ElementQuad
local function above(self: ElementQuad, other: ElementQuad): boolean
	return self:mostBottom() <= other:mostTop()
end

--- If the most top point of `self` is below the most bottom point of `other`
--- @within ElementQuad
local function strictlyBelow(self: ElementQuad, other: ElementQuad): boolean
	return self:mostTop() > other:mostBottom()
end

--- If the most top point of `self` is below or on the same line as the
--- most bottom point of `other`
--- @within ElementQuad
local function below(self: ElementQuad, other: ElementQuad): boolean
	return self:mostTop() >= other:mostBottom()
end

--- If the most right point of `self` is left of the most left point of `other`
--- @within ElementQuad
local function strictlyLeftOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostRight() < other:mostLeft()
end

--- If the most right point of `self` is left or on the same line as the
--- most left point of `other`
--- @within ElementQuad
local function leftOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostRight() <= other:mostLeft()
end

--- If the most left point of `self` is right of the most right point of `other`
--- @within ElementQuad
local function strictlyRightOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostLeft() > other:mostRight()
end

--- If the most left point of `self` is right or on the same line as the
--- most right point of `other`
--- @within ElementQuad
local function rightOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostLeft() >= other:mostRight()
end

--- If `self` is within the left/right boundaries defined by `other`.
--- @within ElementQuad
local function withinHorizontalBoundsOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostLeft() >= other:mostLeft() and self:mostRight() <= other:mostRight()
end

--- If `self` is within the top/bottom boundaries defined by `other`.
--- @within ElementQuad
local function withinVerticalBoundsOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostTop() >= other:mostTop() and self:mostBottom() <= other:mostBottom()
end

--- If `self` is within the boundaries defined by `other`.
--- @within ElementQuad
local function withinBoundsOf(self: ElementQuad, other: ElementQuad): boolean
	return self:withinHorizontalBoundsOf(other) and self:withinVerticalBoundsOf(other)
end

--- @within ElementQuad
local function fromRawPoints(rawQuad: { number }): ElementQuad
	return {
		topLeft = { x = rawQuad[1], y = rawQuad[2] },
		topRight = { x = rawQuad[3], y = rawQuad[4] },
		bottomRight = { x = rawQuad[5], y = rawQuad[6] },
		bottomLeft = { x = rawQuad[7], y = rawQuad[8] },
		height = height,
		width = width,
		aspectRatio = aspectRatio,
		mostLeft = mostLeft,
		mostRight = mostRight,
		mostTop = mostTop,
		mostBottom = mostBottom,
		strictlyAbove = strictlyAbove,
		above = above,
		strictlyBelow = strictlyBelow,
		below = below,
		strictlyLeftOf = strictlyLeftOf,
		leftOf = leftOf,
		strictlyRightOf = strictlyRightOf,
		rightOf = rightOf,
		withinHorizontalBoundsOf = withinHorizontalBoundsOf,
		withinVerticalBoundsOf = withinVerticalBoundsOf,
		withinBoundsOf = withinBoundsOf,
	}
end

return { fromRawPoints = fromRawPoints }
