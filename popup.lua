--@class Popup
Popup = Object:extend()

remove = false 
popupTime = 0.75
function Popup:init()
    self.time = popupTime
    self.text = "+30"
    self.pos = { x = 0, y = 0 }
    self.speed = math.random(-90, 90)
end

function Popup:spawn(amount, type, x, y)
    self.text = amount
    self.time = popupTime
    self.pos.x = x + math.random(-10, 10)
    self.pos.y = y + math.random(-20, 20)
    self:checkType(type)
end

function Popup:checkType(type)
    if type == "chips" then
        self.text = "+" .. self.text
        self.Color = G.C.CHIPS
    elseif type == "money" then
        self.text = "+" .. self.text
        self.Color = G.C.MONEY
    elseif type == "mult" then
        self.text = "+" .. self.text
        self.Color = G.C.MULT
    elseif type == "xmult" then
        self.text = "x" .. self.text
        self.Color = G.C.XMULT
    else 
        self.Color = {0,0,0,0}
        self.noRect = true
    end
end

function Popup:draw()
    love.graphics.setFont(G.FONTS.PIXEL.SMALL)
    local currentFont = love.graphics.getFont()

    local timeFactor = 1 - self.time / popupTime
    timeFactor = math.max(math.min(timeFactor, 1), 0)
    local w = currentFont:getWidth(self.text)
    local h = currentFont:getHeight(self.text)
    local scale = 1 + 2 * timeFactor - 5 * math.pow(timeFactor, 2) + 3 * math.pow(timeFactor, 3) -- Scale up effect

    --Rectangle Behind Text
    if not self.noRect then
        love.graphics.push()
        love.graphics.setColor(self.Color)
        r,g,b,a = love.graphics.getColor()
        love.graphics.setColor(r, g, b, self.time * 2) -- Fade out effect
        love.graphics.translate(self.pos.x, self.pos.y) -- Center Rectangle
        love.graphics.rotate(math.rad(self.speed * timeFactor)) -- Rotate effect
        love.graphics.rectangle("fill", -w*scale/2 - 5, -h*scale/2 - 5, w*scale + 10, h*scale + 10)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, self.time * 2) -- Fade out effect
    love.graphics.print(self.text, self.pos.x - w*scale/2, self.pos.y - h*scale/2, 0, scale, scale)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

function Popup:update(dt)
    self.time = self.time - dt
    if self.time <= 0 then
        self.time = 0
        self.text = ""
        self.remove = true
    end
end