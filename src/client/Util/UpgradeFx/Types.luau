--!strict
-- One ability's client-side upgrade effects (Util/UpgradeFx). Every hook is
-- optional.

export type Handler = {
	-- Once, when ModFxController starts.
	start: (() -> ())?,
	-- Every ModFx event, before ModFxController's own handling. Return true
	-- when this handler took care of it (the default handling is skipped),
	-- e.g. a glitched level drawing its own look. data.id / data.level say
	-- whose and which level it is.
	onFx: ((kind: string, data: { [string]: any }) -> boolean)?,
	-- Every frame (RenderStepped).
	step: ((dt: number) -> ())?,
}

return nil
