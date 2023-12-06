--initialization --
local serializer = require('serialization')
local shell = require('shell')
local path = shell.getWorkingDirectory()
local component = require('component')


local function loadConfig()
    local cfgFile = io.open(path .. '/config.cfg')
    if (cfgFile == nil) then
        error('lost config file in --> ' .. path)
    end
    local cfgContent = cfgFile:read('*all')
    cfgFile:close()

    return assert(serializer.unserialize(cfgContent))
end


local function loadRecipes()
    local recipesFile = io.open(path .. '/recipes.cfg')
    if (recipesFile == nil) then
        return {}
    else
        local recipesContent = recipesFile:read('*all')
        recipesFile:close()
        return assert(serializer.unserialize(recipesContent))
    end
end




-- initialization --
local config = loadConfig()
local recipes = loadRecipes()
local trigger = component.redstone
local subNetwork = component.me_controller  -- change in need
local mainNetwork = component.me_interface  -- change in need




local function updateRecipes()
    print('update recipes---')
    local output = io.open(path .. '/recipes.cfg', 'w')
    local content = serializer.serialize(recipes)

    output:write(content)
    output:close()
    print('done---')
end

local function recipesBuilder()
    local function spliter(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
    end
    local newRecipeTable = {
        ingredient = {},
        essentia = {}
    }

    -- ingredient part --
    for k, v in pairs(subNetwork.getItemsInNetwork()) do
        newRecipeTable.ingredient[v.label] = v.size
    end
    print('reading ingredient done...')

    -- essentia part --
    local flag = true
    print('now input the essentia part, split each with a space, and end input with a single \'0\'')
    while flag do
        local u_input = io.read()
        if not(u_input == '0') then
            local t = spliter(u_input)
            newRecipeTable.essentia[t[1]] = tonumber(t[2])
        else
            flag = false
        end
    end

    table.insert(recipes, newRecipeTable)
    print('recipe build complete')

    updateRecipes()
end



local function checkRecipes()

    local function deepcompare(t1, t2, ignore_mt)
        local ty1 = type(t1)
        local ty2 = type(t2)
        if ty1 ~= ty2 then return false end
        -- non-table types can be directly compared
        if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
        -- as well as tables which have the metamethod __eq
        local mt = getmetatable(t1)
        if not ignore_mt and mt and mt.__eq then return t1 == t2 end
        for k1, v1 in pairs(t1) do
            local v2 = t2[k1]
            if v2 == nil or not deepcompare(v1, v2) then return false end
        end
        for k2, v2 in pairs(t2) do
            local v1 = t1[k2]
            if v1 == nil or not deepcompare(v1, v2) then return false end
        end
        return true
    end

    print('Checking recipes ...')
    local n_ingredient = {}
    for _, v in pairs(subNetwork.getItemsInNetwork()) do
        n_ingredient[v.label] = v.size
    end
    for _, v in pairs(recipes) do
        if deepcompare(n_ingredient, v.ingredient) then
            return v.essentia
        end
    end

end


-- check essentia --
local function checkEssentia(t)

    -- request essentai --
    local function requestEssentia(essentia)
        local craftables = mainNetwork.getCraftables()
        local crafting
        for _, v in pairs(craftables) do
            if v.getItemStack().aspect == essentia then
                crafting = v.request(500)
            end
        end
        if crafting == nil then
            error('no craftables found for '.. essentia)
        end
        local _, flag = crafting.isDone()
        if not(flag == nil) then
            error(flag)
        end
        while not (crafting.isDone()) do
            print('crafting ' .. essentia .. ' ---')
            os.sleep(1)
        end
    end


    local essentiaInNetwork_raw = mainNetwork.getEssentiaInNetwork()
    local essentiaInNetwork = {}
    for _, v in pairs(essentiaInNetwork_raw) do
        essentiaInNetwork[v.name] = v.amount
    end
    for k, v in pairs(t) do
        if essentiaInNetwork['gaseous' .. k .. 'essentia'] and essentiaInNetwork['gaseous' .. k .. 'essentia'] >= v then
            goto continue
        else
            requestEssentia(k)
        end
        ::continue::
    end
end



-- main loop --
while true do
    if (#subNetwork.getItemsInNetwork() > 1) then

        local recipeEssentia = checkRecipes()
        if recipeEssentia then
            checkEssentia(recipeEssentia)
            trigger.setOutput(config.redstonePulseSide, 225)
            local flag = true
            while flag do
                if #subNetwork.getItemsInNetwork() == 1 then
                    flag = false
                end
                print('infusion in progress...')
                os.sleep(1)
            end
            print('infusion done... trigger me input bus')
            trigger.setOutput(config.finishedSignalSide, 225)
            while not(#subNetwork.getItemsInNetwork() == 0) do
                os.sleep(0.5)
            end
            trigger.setOutput(config.redstonePulseSide, 0)
            trigger.setOutput(config.finishedSignalSide, 0)
        else
            recipesBuilder()
        end

    end

    os.sleep(1)
end