--!strict
-- Your own shots, for whoever wants them after the fact (the final-kill
-- replay records them: the server's ShotFx goes to everyone but the shooter).

local ShotLog = {}

type Listener = (weaponId: string, origin: Vector3, ends: { Vector3 }) -> ()

local listeners: { Listener } = {}

function ShotLog.listen(fn: Listener)
	table.insert(listeners, fn)
end

function ShotLog.own(weaponId: string, origin: Vector3, ends: { Vector3 })
	for _, fn in listeners do
		task.spawn(fn, weaponId, origin, ends)
	end
end

return ShotLog
