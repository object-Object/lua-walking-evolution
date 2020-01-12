--[[
screen is 800x600

Controls:
 up     = increase torque
 down   = decrease torque
 left   = apply torque left
 right  = apply torque right
 space  = start / reset
 enter  = reset torque
 escape = close

set player class for each player to its network num

Inputs:
 angle of each joint
 speed of each joint
 horizontal speed of body
 vertical speed of body
 distance of body from ground

Outputs:
 direction to move each movable part
]]

require("NEAT")
require("print_r")
wf = require("windfield")
gamera = require("gamera")

-- FPS
local FPS = 40
local maxPlaying = 10
local updateDt = 1/60 -- delta time to give windfield each frame
local timerSleep = function () return 1/FPS end
love.window.setMode(800, 600, {vsync = false})

-- settings
screenWidth = 100000 -- multiple of 1000
playerRestitution = 0 -- 0 to 1
startHeight = 290 -- height at which to start the players (represents some point just above the head)
armWidth = 15
armLength = 50
armCorner = armWidth/2
legWidth = 15
legLength = 50
legCorner = legWidth/4
jointSpeed = 8 -- speed (in radians per second) at which the players can move joints
maxJointTorque = 500000 -- max torque (in Nm) of joints
laserStart = 80 -- place at which to start the laser
laserSpeed = 100 -- speed to move the laser
screenMin = 0
playerFriction = 1 -- friction of the players (0.0-1.0)
groundFriction = 1 -- friction of the ground (0.0-1.0)

-- NEAT settings
Settings.Inputs = 11; -- the amount of inputs
Settings.Outputs = 4; -- the amount of outputs

Settings.Population = 100; -- the amount of networks/genomes
Settings.MaxNodes = 16000; -- the maximal amount of nodes

Settings.WeightMutChance = 0.8; -- the chance for the weights to be changed
Settings.NewWeightChance = 0.1; -- the chance for a weight to be completely new
Settings.WeightLrngRate = 0.02; -- the step size of the weight changes
Settings.NewConnectChance = 0.15; -- 0.03 the chance for a new connection
Settings.NewNodeChance = 0.2; -- 0.05 the chance for a new node
Settings.DisableChance = 0.1; -- 0.05 the chance for an aktive connection to get disabled
Settings.EnableChance = 0.2; -- the chance for an inaktive connection to get enabled
Settings.ChanceCrossover = 0.75; -- the chance for breeding to not be asexual
Settings.CoeffDisjointExcess = 0.05;  -- coefficient used during distance calculation. The amount of disjoint and excess nodes is multiplied with it
Settings.CoeffWeightDiff = 1.0; -- coefficient used during distance calculation. The average weight difference between shared connections is multiplied with it
Settings.DistanceThresh = 0.1; -- the distance threshold. Distances above it mean that two genomes belong to separate species
Settings.SigmoidInHL = true; -- this determines whether the sigmoid function is only used for the output node or also for the hidden layer nodes
Settings.BreedersPercentage = 0.2; -- 0.2 this sets the percentage of genomes, per species, that get to breed (Values should not exceed 1.0)
Settings.WeightRange = 1; -- the (new) random connection weights range from -WeightRange/2 to WeightRange/2

LeftThresh = -0.3 -- threshold past which to move joint left
RightThresh = 0.3 -- threshold past which to move joint right

-- NEAT variables
deadGenomes = 0
bestGenomePos=400
bestFitness=-1
bestAlltimeFitness=-1
BOATIncreased = "" -- tracks whether the current generation improved the best fitness of all time
classes={}
startTime=0
currentlyPlaying={} -- used to limit number of players being simulated
currentGroup=1
paused = false

-- functions
function round(num,dec)
    return math.floor((num*10^dec+0.5))/(10^dec)
end
function setupCollider(collider,id)
    collider:setRestitution(playerRestitution)
    collider:setCollisionClass(id)
    collider:setPreSolve(preSolve)
    collider:setFriction(playerFriction)
end

function setupRJoint(joint)
    joint:setMotorEnabled(true)
    joint:setMotorSpeed(0)
    joint:setMaxMotorTorque(maxJointTorque)
end

function preSolve(collider1,collider2,contact)
    if collider2.collision_class ~= "Ground" and collider2.collision_class~="Laser" and collider1.collision_class~=collider2.collision_class then
        contact:setEnabled(false)
    end
end

function setupPlayers(midGame)
    startTime=love.timer.getTime()
    local genomeIDs=1
    for s=1, #pop.species do
        local species = pop.species[s]
        for g=1, #species.genomes do
            local genome = species.genomes[g]
            if not midGame then
                genome.id = genomeIDs
                genomeIDs = genomeIDs + 1
            end
            if currentlyPlaying[genome.id] then
                genome.dead=false
                genome.cleanedUp=false
                genome.fitness=0
                getNetwork(genome)
                
                if not classes[genome.id] then
                    classes[genome.id]=true
                    world:addCollisionClass(genome.id)
                end
                
                genome.head = world:newRectangleCollider(385, startHeight+30, 30, 30)
                setupCollider(genome.head, genome.id)
                genome.body = world:newRectangleCollider(360, startHeight+60, 80, 80)
                setupCollider(genome.body, genome.id)
                genome.neck = world:addJoint("WeldJoint", genome.head, genome.body, 400, startHeight+60)
                --[[
                genome.leftHumerus = world:newBSGRectangleCollider(360-armLength, startHeight+70-armWidth/2, armLength, armWidth, armCorner)
                setupCollider(genome.leftHumerus, genome.id)
                genome.leftForearm = world:newBSGRectangleCollider(360-armLength*2, startHeight+70-armWidth/2, armLength, armWidth, armCorner)
                setupCollider(genome.leftForearm, genome.id)
                genome.leftShoulder = world:addJoint("RevoluteJoint", genome.body, genome.leftHumerus, 360, startHeight+70, false)
                setupRJoint(genome.leftShoulder)
                genome.leftElbow = world:addJoint("RevoluteJoint", genome.leftHumerus, genome.leftForearm, 360-armLength, startHeight+70, false)
                setupRJoint(genome.leftElbow)
                
                genome.rightHumerus = world:newBSGRectangleCollider(440, startHeight+70-armWidth/2, armLength, armWidth, armCorner)
                setupCollider(genome.rightHumerus, genome.id)
                genome.rightForearm = world:newBSGRectangleCollider(440+armLength, startHeight+70-armWidth/2, armLength, armWidth, armCorner)
                setupCollider(genome.rightForearm, genome.id)
                genome.rightShoulder = world:addJoint("RevoluteJoint", genome.body, genome.rightHumerus, 440, startHeight+70, false)
                setupRJoint(genome.rightShoulder)
                genome.rightElbow = world:addJoint("RevoluteJoint", genome.rightHumerus, genome.rightForearm, 440+armLength, startHeight+70, false)
                setupRJoint(genome.rightElbow)
                ]]
                genome.leftThigh = world:newBSGRectangleCollider(370-legWidth/2, startHeight+140, legWidth, legLength, legCorner)
                setupCollider(genome.leftThigh, genome.id)
                genome.leftCalf = world:newBSGRectangleCollider(370-legWidth/2, startHeight+140+legLength, legWidth, legLength, legCorner)
                setupCollider(genome.leftCalf, genome.id)
                genome.leftHip = world:addJoint("RevoluteJoint", genome.body, genome.leftThigh, 370, startHeight+140, false)
                setupRJoint(genome.leftHip)
                genome.leftKnee = world:addJoint("RevoluteJoint", genome.leftThigh, genome.leftCalf, 370, startHeight+140+legLength, false)
                setupRJoint(genome.leftKnee)
                
                genome.rightThigh = world:newBSGRectangleCollider(430-legWidth/2, startHeight+140, legWidth, legLength, legCorner)
                setupCollider(genome.rightThigh, genome.id)
                genome.rightCalf = world:newBSGRectangleCollider(430-legWidth/2, startHeight+140+legLength, legWidth, legLength, legCorner)
                setupCollider(genome.rightCalf, genome.id)
                genome.rightHip = world:addJoint("RevoluteJoint", genome.body, genome.rightThigh, 430, startHeight+140, false)
                setupRJoint(genome.rightHip)
                genome.rightKnee = world:addJoint("RevoluteJoint", genome.rightThigh, genome.rightCalf, 430, startHeight+140+legLength, false)
                setupRJoint(genome.rightKnee)
                
                genome.dead=false
                genome.fitness=0
            end
        end
    end
end

function clearPlayer(genome)
    world:removeJoint(genome.neck)
    --[[world:removeJoint(genome.leftShoulder)
    world:removeJoint(genome.leftElbow)
    world:removeJoint(genome.rightShoulder)
    world:removeJoint(genome.rightElbow)]]
    world:removeJoint(genome.leftHip)
    world:removeJoint(genome.leftKnee)
    world:removeJoint(genome.rightHip)
    world:removeJoint(genome.rightKnee)
    genome.head:destroy()
    genome.body:destroy()
    --[[genome.leftHumerus:destroy()
    genome.leftForearm:destroy()
    genome.rightHumerus:destroy()
    genome.rightForearm:destroy()]]
    genome.leftThigh:destroy()
    genome.leftCalf:destroy()
    genome.rightThigh:destroy()
    genome.rightCalf:destroy()
    genome.head=nil
    genome.body=nil
    genome.leftThigh=nil
    genome.leftCalf=nil
    genome.rightThigh=nil
    genome.rightCalf=nil
    genome.neck=nil
    genome.leftHip=nil
    genome.leftKnee=nil
    genome.rightHip=nil
    genome.rightKnee=nil
end

function map(s, a1, a2, b1, b2)
    return b1 + (s-a1)*(b2-b1)/(a2-a1)
end

function applyForce(joint,input)
    --print(input)
    if input<=LeftThresh then
        joint:setMotorSpeed(-jointSpeed)
    elseif input>=RightThresh then
        joint:setMotorSpeed(jointSpeed)
    else
        joint:setMotorSpeed(0)
    end
end

-- NEAT functions
Settings.getInputs = function(genome)
    local bodyXSpeed, bodyYSpeed = genome.body:getLinearVelocity()
    local inputs={
        --[[map(genome.leftShoulder:getJointSpeed(),-10,10,-1,1),
        map(genome.leftElbow:getJointSpeed(),-10,10,-1,1),
        map(genome.rightShoulder:getJointSpeed(),-10,10,-1,1),
        map(genome.rightElbow:getJointSpeed(),-10,10,-1,1),
        map(genome.leftHip:getJointSpeed(),-10,10,-1,1),
        map(genome.leftKnee:getJointSpeed(),-10,10,-1,1),
        map(genome.rightHip:getJointSpeed(),-10,10,-1,1),
        map(genome.rightKnee:getJointSpeed(),-10,10,-1,1),
        map(genome.leftShoulder:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.leftElbow:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.rightShoulder:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.rightElbow:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.leftHip:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.leftKnee:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.rightHip:getJointAngle(),-math.pi,math.pi,-1,1),
        map(genome.rightKnee:getJointAngle(),-math.pi,math.pi,-1,1),
        map(bodyXSpeed,-2000,2000,-1,1),
        map(bodyYSpeed,-400,400,-1,1),
        map(536-(genome.body:getY()+40),0,536,0,1)]]
        --[[genome.leftShoulder:getJointSpeed(),
        genome.leftElbow:getJointSpeed(),
        genome.rightShoulder:getJointSpeed(),
        genome.rightElbow:getJointSpeed(),]]
        genome.leftHip:getJointSpeed(),
        genome.leftKnee:getJointSpeed(),
        genome.rightHip:getJointSpeed(),
        genome.rightKnee:getJointSpeed(),
        --[[genome.leftShoulder:getJointAngle(),
        genome.leftElbow:getJointAngle(),
        genome.rightShoulder:getJointAngle(),
        genome.rightElbow:getJointAngle(),]]
        genome.leftHip:getJointAngle(),
        genome.leftKnee:getJointAngle(),
        genome.rightHip:getJointAngle(),
        genome.rightKnee:getJointAngle(),
        bodyXSpeed,
        bodyYSpeed,
        536-(genome.body:getY()+40)
    }
    return inputs
end


function drawNetwork(network, startX, startY)
    --[[
    vertical spacing between centers = 18
    radius = vertical spacing / 2 - 2 (7)
    horizontal spacing = 50
    ]]
    
    local nodes=network.nodes
    local nodesPos={}
    local ranks={}
    local connections={}
    local xCounter = 0
    
    for k,v in pairs(nodes) do -- determine coords and put connections in table
        if not ranks[v.rank] then
            ranks[v.rank]={xNum=xCounter,yNum=1}
            xCounter=xCounter+1
        else
            ranks[v.rank].yNum=ranks[v.rank].yNum+1
        end
        nodesPos[k]={x=startX+50*ranks[v.rank].xNum,y=startY+18*ranks[v.rank].yNum}
        for j,u in pairs(v.inps) do
            table.insert(connections,{inp=u.inp, outp=u.outp, enabled=u.enabled})
        end
    end
    
    for k,v in pairs(connections) do -- draw connections
        if v.enabled then
            love.graphics.setColor(0,0,1,0.3)
        else
            love.graphics.setColor(1,0,0,0.3)
        end
        love.graphics.line(nodesPos[v.inp].x, nodesPos[v.inp].y, nodesPos[v.outp].x, nodesPos[v.outp].y)
        love.graphics.setColor(1,1,1,1)
    end
    
    for k,v in pairs(nodesPos) do -- draw nodes
        if k<=Settings.Inputs then
            love.graphics.setColor(24/255,135/255,12/255,1)
        elseif k>Settings.MaxNodes then
            love.graphics.setColor(1,1,0,1)
        else
            love.graphics.setColor(0,0,0,1)
        end
        love.graphics.circle("fill",v.x,v.y,7)
        love.graphics.setColor(1,1,1,1)
    end
end

-- LOVE functions
function love.load()
    setupNEAT()

    love.window.setTitle("WaLkInG sImUlAtOr 2019")
    
    cam = gamera.new(0,0,screenWidth+600,600)
    
    groundSprite = love.graphics.newImage("sprites/ground.png")
    
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 512)

    world:addCollisionClass("Ground")
    world:addCollisionClass("Laser")
    
    pop = newPopulation(); -- creates a new population
    pop.generation = 1; -- set the generation number to one

    for g = 1, Settings.Population do -- create as many first gen genomes as the population's size allows and insert them into matching species
        insertIntoSpecies(firstGenGenome(), pop);
    end
    
    for i=1,maxPlaying do
        currentlyPlaying[i]=true
    end
    
    setupPlayers(false)
    
    laser = world:newRectangleCollider(laserStart,0,5,536)
    laser:setCollisionClass("Laser")
    --do local data=laser:getUserData() data.noDraw=true laser:setUserData(data) end
    
    ground = world:newRectangleCollider(screenMin, 536, screenWidth, 64)
    ground:setType('static') -- Types can be 'static', 'dynamic' or 'kinematic'. Defaults to 'dynamic'
    ground:setCollisionClass("Ground")
    do local data=ground:getUserData() data.noDraw=true ground:setUserData(data) end
    
    ground:setFriction(groundFriction)
    
    laserMotor = world:addJoint("PrismaticJoint",ground,laser,laserStart+5/2,536,1,0,false)
    laser:setLinearVelocity(1000,0)
end

function love.update(dt)
    if paused then return end
    laser:setLinearVelocity(laserSpeed,0)
    world:update(updateDt or dt)
    if deadGenomes<maxPlaying and not (playingBest and deadGenomes==1) then
        for s=1, #pop.species do
            local species = pop.species[s]
            for g=1, #species.genomes do
                local genome = species.genomes[g]
                if currentlyPlaying[genome.id] then
                    if not genome.dead and (genome.head:enter("Ground") or genome.body:enter("Ground") or laser:enter(genome.id)) then
                        genome.dead=true
                    end
                    if genome.dead and not genome.cleanedUp then
                        clearPlayer(genome)
                        genome.cleanedUp=true
                        deadGenomes=deadGenomes+1
                    elseif not genome.dead then
                        --genome.fitness=love.timer.getTime()-startTime -- time-based fitness, method 1
                        genome.fitness=genome.fitness+1 -- time-based fitness, method 2
                        --genome.fitness=genome.body:getX()-400 -- distance-based fitness
                        local output = calcOutputNet(genome)
                        --print("start") print_r(genome.network) print("done")
                        --[[applyForce(genome.leftShoulder, output[1])
                        applyForce(genome.leftElbow, output[2])
                        applyForce(genome.rightShoulder, output[3])
                        applyForce(genome.rightElbow, output[4])
                        applyForce(genome.leftHip, output[5])
                        applyForce(genome.leftKnee, output[6])
                        applyForce(genome.rightHip, output[7])
                        applyForce(genome.rightKnee, output[8])]]
                        applyForce(genome.leftHip, output[1])
                        applyForce(genome.leftKnee, output[2])
                        applyForce(genome.rightHip, output[3])
                        applyForce(genome.rightKnee, output[4])
                        if genome.body:getX()>bestGenomePos then
                            bestGenomePos=genome.body:getX()
                        end
                        if genome.fitness>bestFitness then
                            bestFitness=genome.fitness
                            bestGenome=genome
                        end
                        if genome.fitness>bestAlltimeFitness then
                            bestAlltimeFitness=genome.fitness
                            BOATIncreased=" (+)"
                        end--[[
                        if love.keyboard.isDown("1") then
                            applyForce(genome.leftForearm,1)
                        end
                        if love.keyboard.isDown("2") then
                            applyForce(genome.leftForearm,-1)
                        end
                        if love.keyboard.isDown("3") then
                            applyForce(genome.leftHumerus,1)
                        end
                        if love.keyboard.isDown("4") then
                            applyForce(genome.leftHumerus,-1)
                        end]]
                    end
                end
            end
        end
    else
        
        world:destroy()
        world=nil
        classes={}
        
        world = wf.newWorld(0, 0, true)
        world:setGravity(0, 512)

        world:addCollisionClass("Ground")
        world:addCollisionClass("Laser")
        
        laser = world:newRectangleCollider(laserStart,0,5,536)
        laser:setCollisionClass("Laser")
        --do local data=laser:getUserData() data.noDraw=true laser:setUserData(data) end
        
        ground = world:newRectangleCollider(screenMin, 536, screenWidth, 64)
        ground:setType('static') -- Types can be 'static', 'dynamic' or 'kinematic'. Defaults to 'dynamic'
        ground:setCollisionClass("Ground")
        do local data=ground:getUserData() data.noDraw=true ground:setUserData(data) end
        
        ground:setFriction(groundFriction)
        
        laserMotor = world:addJoint("PrismaticJoint",ground,laser,laserStart+5/2,536,1,0,false)
        laser:setLinearVelocity(1000,0)
        
        if currentlyPlaying[Settings.Population] then -- all genomes have played
            currentGroup="best"
            playingBest=true
            currentlyPlaying={}
            currentlyPlaying[bestGenome.id]=true
            setupPlayers(true)
        elseif playingBest then -- done playing best
            playingBest=false
            currentlyPlaying={}
            for i=1,maxPlaying do
                currentlyPlaying[i]=true
            end
            currentGroup=1
            bestFitness=-1
            newGeneration(pop)
            setupPlayers(false)
            BOATIncreased=""
        else -- mid game
            currentGroup=currentGroup+1
            currentlyPlaying={}
            for i=maxPlaying*(currentGroup-1)+1, maxPlaying+maxPlaying*(currentGroup-1) do
                currentlyPlaying[i]=true
            end
            setupPlayers(true)
        end
        laser:setPosition(laserStart-5/2,536/2)
        bestGenomePos=400
        deadGenomes=0
    end
    
    cam:setPosition(bestGenomePos,0)
end

function camDraw()
    world:draw(0,0,0,1)
    for i=0,screenWidth/1000-1 do
        love.graphics.draw(groundSprite,i*1000,536)
    end
    love.graphics.setColor(1,0,0,1)
    love.graphics.rectangle("fill",laser:getX()-5/2,laser:getY()-536/2,5,536)
    love.graphics.setColor(1,1,1,1)
end

function love.draw()
    love.graphics.setColor(0,230/255,1,1)
    love.graphics.rectangle("fill",0,0,800,600)
    love.graphics.setColor(1,1,1,1)
    cam:draw(camDraw,0,0,800,600)
    local font = love.graphics.getFont()
    local str = "Actual FPS: "..love.timer.getFPS().."\nDesired FPS: "..FPS.."\nGeneration: "..pop.generation.."\nLiving genomes: "..maxPlaying-deadGenomes.."/"..maxPlaying.."\nGroup: "..currentGroup.."/"..math.ceil(Settings.Population/maxPlaying).."\nGenomes per group: "..maxPlaying.."\nTotal population: "..Settings.Population.."\nBest fitness of this gen: "..round(bestFitness,3).."\nBest fitness of all time: "..round(bestAlltimeFitness,3)..BOATIncreased
    local height = font:getHeight(str)*9
    love.graphics.print({{0,0,0,1},str},10,526-height)
    if bestGenome then
        drawNetwork(bestGenome.network,20,20)
    end
    if playingBest then
        local str = "Playing best genome of generation "..pop.generation
        local width = font:getWidth(str)
        local height = font:getHeight(str)
        love.graphics.print({{1,1,1,1},str},400-width/2,585-height/2)
    end
    if paused then
        local oldFont = love.graphics.getFont()
        local newFont = love.graphics.newFont(30)
        love.graphics.setFont(newFont)
        local str = "PAUSED"
        local width = newFont:getWidth(str)
        local height = newFont:getHeight(str)
        love.graphics.print({{0,0,0,1},str},400-width/2,300-height/2)
        love.graphics.setFont(oldFont)
    end
end

function love.run()
	if love.math then
		love.math.setRandomSeed(os.time())
	end
 
	if love.load then love.load(arg) end
 
	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end
 
	local dt = 0
 
	-- Main loop time.
	while true do
		-- Process events.
		local startT = love.timer.getTime()
		
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end
 
		-- Update dt, as we'll be passing it to update
		if love.timer then
			love.timer.step()
			dt = love.timer.getDelta()
		end
 
		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled
 
		if love.graphics and love.graphics.isActive() then
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()
			if love.draw then love.draw() end
			love.graphics.present()
		end
 
		if love.timer then
			local endT = love.timer.getTime()
			love.timer.sleep(timerSleep() - (endT - startT))
		end
	end
end
function love.keypressed(key)
    if key == "escape" then
        paused = not paused
    end
end