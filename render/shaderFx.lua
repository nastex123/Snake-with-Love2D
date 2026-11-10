local Fx = {}
Fx.state = {damage = 0, shake = 0}
function Fx.trigger(amount, shakeAmount)
    Fx.state.damage = math.max(Fx.state.damage, amount or 0.7)
    Fx.state.shake = math.max(Fx.state.shake, shakeAmount or 0.6)
end
function Fx.update(dt)
    Fx.state.damage = math.max(0, Fx.state.damage - dt * 2.2)
    Fx.state.shake = math.max(0, Fx.state.shake - dt * 3.0)
end
function Fx.get()
    return Fx.state
end
return Fx
