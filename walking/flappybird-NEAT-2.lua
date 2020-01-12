require("NEAT")
require("print_r")
require("save_table")

-- settings
local startVSpeed=-14.2 -- vSpeed when genome jumps
local startHSpeed=4.2 -- hSpeed at start of game
local startGravity=-0.9 -- amount vSpeed decreases each frame
local ups=1000/240 -- 1000 ms (aka 1 s) divided by updates per second
local pipeInterval=350 -- in pixels
local pipeWidth=100 -- width of each pipe

-- NEAT settings
Inputs = 4; -- the amount of inputs
Outputs = 1; -- the amount of outputs

Population = 200; -- the amount of networks/genomes
MaxNodes = 16000; -- the maximal amount of nodes

Iterations = 5 -- number of times each generation should play

WeightMutChance = 0.8; -- the chance for the weights to be changed
NewWeightChance = 0.1; -- the chance for a weight to be completely new
WeightLrngRate = 0.01; -- the step size of the weight changes
NewConnectChance = 0.05; -- 0.03 the chance for a new connection
NewNodeChance = 0.08; -- 0.05 the chance for a new node
DisableChance = 0.05; -- 0.05 the chance for an aktive connection to get disabled
EnableChance = 0.25; -- the chance for an inaktive connection to get enabled
ChanceCrossover = 0.75; -- the chance for breeding to not be asexual
CoeffDisjointExcess = 0.05;  -- coefficient used during distance calculation. The amount of disjoint and excess nodes is multiplied with it
CoeffWeightDiff = 1.0; -- coefficient used during distance calculation. The average weight difference between shared connections is multiplied with it
DistanceThresh = 0.1; -- the distance treshold. Distances above it mean that two genomes belong to separate species
SigmoidInHL = true; -- this determines whether the sigmoid function is only used for the output node or also for the hidden layer nodes
BreedersPercentage = 0.2; -- 0.2 this sets the percentage of genomes, per species, that get to breed (Values should not exceed 1.0)
JumpThresh = 0.0; -- the threshold at which an output leads to a jump
WeightRange = 1; -- the (new) random connection weights range from -WeightRange/2 to WeightRange/2

--[[
IMPORTANT NOTE:
base refers to the top pipe, top refers to the bottom pipe
]]

-- variables
local printNetwork,allowPrintNetwork
local backgroundColor=draw.cyan
local screenWidth,screenHeight
local distance
local gravity
local hSpeed -- horizontal speed
local score
local lastPipeDist
local pipes={}
local exportButton={margin=20}
innovation = Inputs; -- innovation at start
maxnode = Inputs; -- max node, excluding the ouput node, at start
speciesIDs = 0; -- allows us to add an unique ID to each species
currentHeight=0 -- used to calculate height to middle of pipe
currentVSpeed=0 -- used to calculate speed

-- NEAT functions
function getInputs()
    local inputs = {}; -- input array
    -- inputs: relative height to middle of pipe, dist to end of pipe
    local pipeBase=screenH
    local pipeTop=screenH
    local pipeDist=screenW/2+40
    local maxVSpeed=math.ceil(math.sqrt((-gravity*711)/.5))
    if #pipes>0 then
        for k,v in ipairs(pipes) do
            if v.base.x2>=screenW/2-25 then
                pipeDist=v.base.x2-(screenW/2-25)
                pipeBase=v.base.y2
                pipeTop=v.top.y1
                break
            end
        end
    end

    --inputs[1]=(pipeMid-currentHeight)/screenH
    inputs[1]=pipeDist/(screenW/2+40) -- horiz dist to end of pipe
    inputs[2]=currentVSpeed/maxVSpeed -- vertical speed
    inputs[3]=(currentHeight-pipeBase)/screenH -- vert dist to pipe base
    inputs[4]=(pipeTop-currentHeight)/screenH -- vert dist to pipe top
    return inputs; -- table containing inputs, which should be normalized to between 0 and 1, or -1 and 1 (divide by max possible value). final value should be 1, for bias
end

-- functions
local function touchBegan(x,y)
    if allowPrintNetwork and x>exportButton.x and y>exportButton.y then
        printNetwork=true
    end
end
local function setup()
    score=0
    distance=0
    birdHeight=screenH/2
    vSpeed=0
    hSpeed=startHSpeed
    pipeCountdown=pipeInterval
    gravity=startGravity
    dead=false
    onGround=false
    lastPipeDist=-350
    pipes={}
end
local function generatePipe()
    --local gap=math.random(15,18)*10
    local gap=180
    local h=math.random(50,screenH-150-gap)
    return {base={x1=screenW,x2=screenW+pipeWidth,y1=0,y2=h},top={x1=screenW,x2=screenW+pipeWidth,y1=h+gap,y2=screenH-40}}
end
local function movePipes()
    distance=distance+hSpeed
    if distance-lastPipeDist>=pipeInterval then
        lastPipeDist=distance
        table.insert(pipes,generatePipe())
    end
    if #pipes<1 then return end
    for k,v in ipairs(pipes) do
        v.base.x1=v.base.x1-hSpeed
        v.base.x2=v.base.x2-hSpeed
        v.top.x1=v.top.x1-hSpeed
        v.top.x2=v.top.x2-hSpeed
        if v.base.x2<=0 then
            table.remove(pipes,k)
        end
    end
    if score>0 and score%1==0 and not dead then
        --hSpeed=hSpeed+0.005
    end
end
local function moveBird(genome)
    genome.vSpeed=genome.vSpeed-gravity
    genome.height=genome.height+genome.vSpeed
    if genome.height+18>screenH-40 then
        genome.dead=true
    end
    if genome.height<-18 then
        genome.dead=true
    end
    for k,v in ipairs(pipes) do
        if v.base.x1<=screenW/2+26 and v.base.x2>=screenW/2-25 and (genome.height-18<v.base.y2 or genome.height+18>v.top.y1)then
            genome.dead=true
            break
        elseif (v.base.x1+v.base.x2)/2<screenW/2 and not v.passed then
            score=score+1
            v.passed=true
        end
    end
    return genome
end
local function drawBackground()
    draw.fillrect(0,screenH,screenW+1,screenH-40,{25/255,93/255,20/255,1})
end
local function drawPipes()
    if #pipes<1 then return end
    for k,v in ipairs(pipes) do
        draw.fillrect(v.base.x1,v.base.y2-40,v.base.x2,v.base.y2,draw.black)
        draw.fillrect(v.base.x1+4,v.base.y2-36,v.base.x2-4,v.base.y2-4,draw.green)
        draw.fillrect(v.base.x1+4,v.base.y2-36,v.base.x2-4,v.base.y1,draw.black)
        draw.fillrect(v.base.x1+8,v.base.y2-40,v.base.x2-8,v.base.y1,draw.green)

        draw.fillrect(v.top.x1,v.top.y1+40,v.top.x2,v.top.y1,draw.black)
        draw.fillrect(v.top.x1+4,v.top.y1+36,v.top.x2-4,v.top.y1+4,draw.green)
        draw.fillrect(v.top.x1+4,v.top.y2,v.top.x2-4,v.top.y1+40,draw.black)
        draw.fillrect(v.top.x1+8,v.top.y2,v.top.x2-8,v.top.y1+40,draw.green)
    end
end
local function drawBird(genome)
    if genome.vSpeed<0 then
        rotation=-0.6
    elseif genome.vSpeed==0 then
        rotation=0
    else
        rotation=0.6
    end
    if not dead then
        draw.transformedimage("resources/images/flappybird.png",screenW/2,genome.height,3,rotation)
    else
        draw.transformedimage("resources/images/deadbird.png",screenW/2,genome.height,3,rotation)
    end
end
local function drawScore()
    do
        local stringsizeX,stringsizeY=draw.stringsize(score)
        draw.fillrect(screenW/2-stringsizeX/2-7,50-stringsizeY/2-4,screenW/2+stringsizeX/2+7,50+stringsizeY/2+4,draw.black)
        draw.fillrect(screenW/2-stringsizeX/2-5,50-stringsizeY/2-2,screenW/2+stringsizeX/2+5,50+stringsizeY/2+2,draw.white)
        draw.string(score,screenW/2-stringsizeX/2,50-stringsizeY/2,draw.black)
    end
end

-- setup
draw.setscreen(1)
draw.settitle("If you can see this, swipe up with 3 fingers")
screenW,screenH=draw.getport()
draw.cacheimage("resources/images/flappybird.png")
draw.cacheimage("resources/images/deadbird.png")
local file=io.open("flappybird-NEAT-2 results.txt","a")
file:write("\n--------\nBEGIN NEW OUTPUT\n"..os.date().."\n--------\n")
file:close()
local pop = newPopulation(); -- creates a new population
pop.generation = 1; -- set the generation number to one

for g = 1, Population do -- create as many first gen genomes as the population's size allows and insert them into matching species
    insertIntoSpecies(firstGenGenome(), pop);
end

draw.tracktouches(touchBegan,function() end,function() end)

-- prompt to hide title bar
draw.clear()
draw.setfont("Helvetica Bold",40)
local stringsizeX,stringsizeY=draw.stringsize("Swipe up with 3 fingers to start")
draw.string("Swipe up with 3 fingers to start",screenW/2-stringsizeX/2,screenH/2-stringsizeY/2,draw.black)
draw.waittouch()
draw.clear(backgroundColor)

draw.setfont("Helvetica",20)
local stringsizeX,stringsizeY=draw.stringsize("Export")
exportButton.x=screenW-stringsizeX-(exportButton.margin*2)
exportButton.y=screenH-stringsizeY-(exportButton.margin*2)

allowPrintNetwork=true

while true do -- play game
    local avgFitnessGen = 0 -- the average fitness of the current generation
    local highscoreGen = 0 -- the highscore of the current generation (points)
    local highscoreGenFit = 0.0 -- the highscore of the current generation (fitness)
    for i=1,Iterations do -- multiple iterations
        for s=1, #pop.species do -- set up all the genomes
            local species = pop.species[s]
            for g=1, #species.genomes do
                local genome = species.genomes[g]
                genome.fitness=0
                getNetwork(genome)
                genome.height=screenH/2
                genome.vSpeed=0
                genome.dead=false
            end
        end
        local livingGenomes = Population -- number of living genomes
        setup()
        while livingGenomes>0 do -- game loop
            draw.doevents()
            movePipes()
            draw.beginframe()
            draw.clear(backgroundColor)
            drawBackground()
            drawPipes()
            local oldScore=score
            local fitness
            local bestGenome={fitness=0}
            for s=1, #pop.species do -- move all the genomes
                local species = pop.species[s]
                for g=1, #species.genomes do
                    local genome = species.genomes[g]
                    if not genome.dead then
                        if oldScore > highscoreGen then
                            highscoreGen = oldScore;
                        end
                        currentHeight=genome.height
                        currentVSpeed=genome.vSpeed
                        local output = calcOutputNet(genome.network); -- calculates the output
                        if output > JumpThresh then -- if the output is greater than a threshold
                            genome.vSpeed=startVSpeed -- jump
                        end
                        genome=moveBird(genome)
                        if score > highscoreGen then
                            highscoreGen = score;
                        end
                        if genome.dead then
                            livingGenomes=livingGenomes-1
                        else
                            genome.fitness=genome.fitness+1
                            if score>oldScore then
                                genome.fitness=genome.fitness+100
                            end
                            drawBird(genome)
                        end
                        fitness=genome.fitness
                        if genome.fitness>bestGenome.fitness then
                            bestGenome=genome
                        end
                    end
                end
            end
            if printNetwork then
                print(table.save(bestGenome,"flappybird-NEAT-2 bestgenome.txt"))
                print("a")
                printNetwork=false
            end
            -- network visualization
            do
                local network=bestGenome.network
                local xCount=1
                local outputNode = network.nodes[MaxNodes + Outputs]
                local maxRank = outputNode.rank
                local nodeCoords={}
                draw.setfont("Helvetica",30)
                local nodeCount=0
                for _,_ in pairs(network.nodes) do nodeCount=nodeCount+1 end
                draw.string(nodeCount,10,screenH-40,draw.white)
                draw.setfont("Helvetica",20)
                for r=0, maxRank do
                    local yCount=1
                    for num,node in pairs(network.nodes) do
                        if node.rank == r then
                            local colour
                            if r==0 then
                                colour=draw.blue
                            elseif r==maxRank then
                                colour={20/255,150/255,20/255,1}
                            else
                                colour=draw.black
                            end
                            nodeCoords[num]={x=xCount,y=yCount}
                            draw.fillcircle(xCount*40+50,screenH-yCount*20,5,colour)
                            for _,conn in pairs(node.inps) do
                                local coords=nodeCoords[conn.inp]
                                local colour
                                if conn.enabled then
                                    colour=draw.black
                                else
                                    colour=draw.red
                                end
                                draw.line(coords.x*40+50,screenH-coords.y*20,xCount*40+50,screenH-yCount*20,colour)
                            end
                            yCount=yCount+1
                        end
                    end
                    if yCount>1 then xCount=xCount+1 end
                end
            end
            -- stats
            do
                draw.setfont("Helvetica",20)
                draw.string("Generation: "..pop.generation.."\nLiving genomes: "..livingGenomes.."/"..Population.."\nIteration: "..i.."/"..Iterations.."\nHighscore: "..highscoreGen.."\nFitness: "..fitness,10,10,draw.black)
            end
            drawScore()
            draw.fillrect(exportButton.x,exportButton.y,screenW,screenH,draw.black)
            draw.fillrect(exportButton.x+5,exportButton.y+5,screenW-5,screenH-5,draw.white)
            draw.string("Export",exportButton.x+exportButton.margin,exportButton.y+exportButton.margin,draw.black)
            draw.endframe()
        end
    end
    for s=1, #pop.species do
        local species = pop.species[s]
        for g=1, #species.genomes do
            local genome = species.genomes[g]
            genome.fitness = genome.fitness / Iterations; -- after the genome has lost all the games, divide the fitness by iterations to get the genome's average fitness per game
            if genome.fitness > highscoreGenFit then
                highscoreGenFit = genome.fitness;
            end
            avgFitnessGen = avgFitnessGen + genome.fitness; -- adds the current genome's fitness to the generation's average fitness
        end
    end
    avgFitnessGen = avgFitnessGen / Population; -- divides the fitness summ by the size of the population
    local file = io.open("flappybird-NEAT-2 results.txt", "a");
    file:write("Generation: " .. pop.generation);
    file:write("\n Finished: "..os.date())
    file:write("\n Average Fitness: " .. avgFitnessGen);
    file:write("\n Highscore (Points): " .. highscoreGen);
    file:write("\n Highscore (Fitness): " .. highscoreGenFit);
    file:write("\n");
    file:close();
    newGeneration(pop); -- after all genomes of the current generation are done playing, create a new generation and start again
end