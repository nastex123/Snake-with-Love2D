
local f1 = function(t) return t * t end
local f2 = function() print('done') end
local i1 = debug.getinfo(f1, 'u')
local i2 = debug.getinfo(f2, 'u')
print('f1 nparams:', i1.nparams)
print('f2 nparams:', i2.nparams)
