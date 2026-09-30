class_name SandboxSpawnRequest
extends RefCounted
## What the sandbox summons (docs/specs/sandbox-arena-control.md): an entry of
## the SandboxRoster, how many, their level and the options. Session state kept
## by the `Session` autoload so "Reintentar" summons the same group.

var entry: int = 0
var count: int = 0
var level: int = 0
var immortal: bool = false
var dummy: bool = false
var respawn: bool = false


static func from_config(config: SandboxConfig) -> SandboxSpawnRequest:
	var request := SandboxSpawnRequest.new()
	request.entry = config.default_entry
	request.count = config.default_count
	request.level = config.default_level
	request.immortal = config.default_immortal
	request.dummy = config.default_dummy
	request.respawn = config.default_respawn
	return request
