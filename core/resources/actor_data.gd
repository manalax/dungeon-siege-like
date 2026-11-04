class_name ActorData extends Resource
## Shared body/movement tuning for any walking actor (party members, monsters, mules,
## customers, shopkeeper). ClassData (F-030) may override move_speed.

@export var id: StringName
@export var display_name: String = ""
@export_group("Movement")
@export var move_speed: float = 4.0  ## m/s
@export var acceleration: float = 40.0  ## m/s² (≈0.1 s to full speed at 4 m/s)
@export var turn_speed: float = 720.0  ## deg/s
@export_group("Body")
## Must be ≤ the navmesh agent radius (0.5, decision #38) so paths keep the capsule clear.
@export var capsule_radius: float = 0.4
@export var capsule_height: float = 1.75
@export var color: Color = Color(0.25, 0.55, 0.9)
