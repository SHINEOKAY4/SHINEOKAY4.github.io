--!strict
-- ServerScriptService/Service/PlayerMultiplier.luau
-- Facade over your class-based `Multiplier` to operate per-player without leaking instances.
-- Keeps the ergonomics: PlayerMultiplier.Upsert(player, ...), Get(player, metric), etc.

local MultiplierModule = require(script.Multiplier)

type MultiplierInstance = MultiplierModule.Multiplier
type OpKind = "additive" | "multiplicative"
type Contributor = MultiplierModule.Contributor

local PlayerMultiplier = {}

-- Per-player cache of Multiplier instances.
local _instances: { [number]: MultiplierInstance } = {}

--[=[
  Returns the Multiplier instance for this player, creating it if needed.

  @param player Player -- The player to resolve.
  @return MultiplierInstance -- The per-player multiplier instance.
]=]
local function GetOrCreateMultiplier(player: Player): MultiplierInstance
	local userId = player.UserId
	local instance = _instances[userId]
	if not instance then
		instance = MultiplierModule.new()
		_instances[userId] = instance
	end
	return instance
end

--[=[
  Insert or update a player-specific multiplier contribution.

  @param player Player
  @param metricName string -- Logical metric bucket (e.g., "Clicks").
  @param sourceName string -- Logical source (e.g., "Pets", "Gamepass").
  @param contributorId string -- Unique id within the source (e.g., pet UID).
  @param operationKind "additive" | "multiplicative"
  @param value number -- For "additive": percent as decimal (0.25 = +25%). For "multiplicative": factor (2 = 2×).
  @param expiresAtTime number? -- Absolute expiry (e.g., os.clock()) or nil for no expiry.
]=]
function PlayerMultiplier.Upsert(
	player: Player,
	metricName: string,
	sourceName: string,
	contributorId: string,
	operationKind: OpKind,
	value: number,
	expiresAtTime: number?
)
	GetOrCreateMultiplier(player):Upsert(metricName, sourceName, contributorId, operationKind, value, expiresAtTime)
end

--[=[
  Remove a specific contribution for this player.

  @param player Player
  @param metricName string
  @param sourceName string
  @param contributorId string
]=]
function PlayerMultiplier.Remove(player: Player, metricName: string, sourceName: string, contributorId: string)
	GetOrCreateMultiplier(player):Remove(metricName, sourceName, contributorId)
end

--[=[
  Clear all contributions for a metric for this player (resets to 1×).

  @param player Player
  @param metricName string
]=]
function PlayerMultiplier.ClearMetric(player: Player, metricName: string)
	GetOrCreateMultiplier(player):ClearMetric(metricName)
end

--[=[
  Clear all contributions from a given source within a metric for this player.

  @param player Player
  @param metricName string
  @param sourceName string
]=]
function PlayerMultiplier.ClearSource(player: Player, metricName: string, sourceName: string)
	GetOrCreateMultiplier(player):ClearSource(metricName, sourceName)
end

--[=[
  Get the current total factor for a metric for this player.
  Lazily purges expired entries internally.

  @param player Player
  @param metricName string
  @return number -- Total factor (>= 0), 1 if none.
]=]
function PlayerMultiplier.Get(player: Player, metricName: string): number
	return GetOrCreateMultiplier(player):Get(metricName)
end

--[=[
  Get the full breakdown for a metric.

  @param player Player
  @param metricName string
  @return number totalFactor
  @return number additiveSum
  @return number multiplicativeProduct
  @return {Contributor} contributors -- Snapshot list (unsorted)
]=]
function PlayerMultiplier.GetBreakdown(player: Player, metricName: string): (number, number, number, { Contributor })
	return GetOrCreateMultiplier(player):GetBreakdown(metricName)
end

--[=[
  Compute the factor contributed only by a specific source within a metric.

  @param player Player
  @param metricName string
  @param sourceName string
  @return number -- (1 + additiveFromSource) * multiplicativeFromSource
]=]
function PlayerMultiplier.GetSourceTotal(player: Player, metricName: string, sourceName: string): number
	return GetOrCreateMultiplier(player):GetSourceTotal(metricName, sourceName)
end

--[=[
  Get a specific contributor if present and not expired.

  @param player Player
  @param metricName string
  @param sourceName string
  @param contributorId string
  @return Contributor? -- Nil if missing or expired (and pruned)
]=]
function PlayerMultiplier.GetContributor(player: Player, metricName: string, sourceName: string, contributorId: string): Contributor?
	return GetOrCreateMultiplier(player):GetContributor(metricName, sourceName, contributorId)
end

--[=[
  Destroy and remove the cached Multiplier instance for a player.
  Call this on PlayerRemoving to avoid lingering connections/state.

  @param player Player
]=]
function PlayerMultiplier.DestroyFor(player: Player)
	local userId = player.UserId
	local instance = _instances[userId]
	if instance then
		instance:Destroy()
		_instances[userId] = nil
	end
end

return PlayerMultiplier
