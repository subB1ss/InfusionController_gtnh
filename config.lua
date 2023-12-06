local shell = require('shell')
local serializer = require('serialization')
local sides = require('sides')
local component = require('component')

local config = {
    redstonePulseSide = sides.north,
    finishedSignalSide = sides.north,
}

local path = shell.getWorkingDirectory() .. '/config.cfg'
local output = io.open(path, 'w')
local content = serializer.serialize(config, 100)
output:write(content)
output:close()

print('complete')