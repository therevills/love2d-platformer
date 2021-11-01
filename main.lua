--[[
Love2d Platformer Example
Platformer Grass Tileset Gfx by thomaswp: https://opengameart.org/content/platformer-grass-tileset
]]

camera = require 'libs/hump/camera'
anim8 = require 'libs/anim8'
sti = require 'libs/sti'
wf = require "libs/windfield"

function love.load()
    love.window.setTitle("Love2d Platformer")
    love.graphics.setDefaultFilter("nearest", "nearest")

    myCamera = camera()
    loadImages()
    loadMap()
    createPlayer(playerStartX, playerStartY)
end

function loadImages()
    images = {
        player = love.graphics.newImage('data/images/player.png'),
        background =  love.graphics.newImage('data/images/sky.png')
    }
end

function loadMap()
    gameMap = sti('data/maps/1.lua')

    local meter = 64
    love.physics.setMeter(meter)
    world = wf.newWorld(0, 9.81 * meter, false)

    collisionClasses = {
        PLATFORM = 1,
        PLAYER = 2
    }
    for k, v in pairs(collisionClasses) do
        world:addCollisionClass(collisionClasses[k])
    end

    platforms = {}
    local platformFriction = 0.8
    if gameMap.layers["platforms"] then
        for i, obj in pairs(gameMap.layers["platforms"].objects) do
            if obj.shape == "rectangle" then
                local p = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height, {collision_class = collisionClasses.PLATFORM})
                p:setFriction(platformFriction)
                p:setType('static')
                table.insert(platforms, p)
            elseif obj.shape == "polyline" or obj.shape == "polygon" then
                local polygons = {}
                local polyObj = nil
                if obj.polyline then
                    polyObj = obj.polyline
                elseif obj.polygon then
                    polyObj = obj.polygon
                end
                if polyObj then
                    for vertNum = 1, #polyObj do
                        local vert = polyObj[vertNum]
                        table.insert(polygons, vert.x) 
                        table.insert(polygons, vert.y)
                    end

                    local p = world:newPolygonCollider(polygons, {collision_class = collisionClasses.PLATFORM})
                    p:setFriction(platformFriction)
                    p:setType('static')
                    table.insert(platforms, p)
                end
            end
        end
    end
    for i, obj in pairs(gameMap.layers["gameObjects"].objects) do
        if obj.name == "player" then
            playerStartX = obj.x
            playerStartY = obj.y
        end
    end
end

function createPlayer(startX, startY)
    player = {
        w = 32,
        h = 32,
        speedX = 200,
        speedY = 120,
        scaleX = 1,
        scaleY = 1,
        onGround = true,
        image = images.player,
        grid = anim8.newGrid(32, 32, images.player:getWidth(), images.player:getHeight())
    }

    player.animations = {
        idle = anim8.newAnimation(player.grid(1, 1), 0.2),
        run = anim8.newAnimation(player.grid('2-4', 1), 0.1),
        jump = anim8.newAnimation(player.grid(6, 1), 0.2)
    }
    player.animation = player.animations.idle

    -- setup physics
    local offsetX = 8
    local offsetY = 1
    player.collider = world:newBSGRectangleCollider(startX + offsetX, startY + offsetY, player.w - offsetX * 2, player.h - offsetY * 2, 2)
    player.collider:setFixedRotation(true)
    player.collider:setMass(.5)
    player.collider:setFriction(1)
    player.collider:setCollisionClass(collisionClasses.PLAYER)
end

function love.update(dt)
    playerUpdates(dt)
    world:update(dt)
    cameraLogic()
end

function playerUpdates(dt)
    local isMoving = false

    local px, py = player.collider:getPosition()
    local vx, vy = player.collider:getLinearVelocity()

    --local colliders = world:queryRectangleArea(px - 8, py + 10, 16, 8, {collisionClasses.PLATFORM})
    local colliders = world:queryRectangleArea(px - 7, py + 10, 14, 8, {collisionClasses.PLATFORM})
    
    player.onGround = false
    if #colliders > 0 then
        player.onGround = true
    end

    if love.keyboard.isDown("right") then
        player.collider:setLinearVelocity(0, vy)
        player.collider:setX(player.collider:getX() + player.speedX * dt)
        player.scaleX = 1
        isMoving = true
    end
    if love.keyboard.isDown("left") then
        player.collider:setLinearVelocity(0, vy)
        player.collider:setX(player.collider:getX() - player.speedX * dt)
        player.scaleX = -1
        isMoving = true
    end

    if love.keyboard.isDown("up") and player.onGround then
        player.collider:setLinearVelocity(vx, 0)
        player.collider:applyLinearImpulse(0, -player.speedY)
        player.onGround = false
    end

    if not player.onGround then
        player.animation = player.animations.jump
    elseif isMoving or math.abs(vx)>0.1 then
        player.animation = player.animations.run
    else
        player.animation = player.animations.idle
    end

    local minX = 8
    if px < minX then
        player.collider:setPosition(minX, py)
    end
    if py > gameMap.height * gameMap.tileheight or px > gameMap.width * gameMap.tilewidth then
        playerReset()
    end

    player.animation:update(dt)
end

function playerReset()
    player.collider:setPosition(playerStartX, playerStartY)
end

function cameraLogic()
    local px, py = player.collider:getPosition()
    myCamera:lookAt(px, py)

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    if myCamera.x < w / 2 then
        myCamera.x =  w / 2
    end
    if myCamera.y < h / 2 then
        myCamera.y =  h / 2
    end

    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight

    if myCamera.x > (mapW - w / 2) then
        myCamera.x =  (mapW - w / 2)
    end
    if myCamera.y > (mapH - h / 2 )  then
        myCamera.y =  (mapH - h / 2) 
    end
end

function love.draw()
    love.graphics.draw(images.background, 0, 0)
    myCamera:attach()
        gameMap:drawLayer(gameMap.layers["tiles"])
        local px, py = player.collider:getPosition()
        player.animation:draw(player.image, px, py, 0, player.scaleX, player.scaleY, player.w / 2, player.h / 2)
    myCamera:detach()
end