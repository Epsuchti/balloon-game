class_name Enemy
extends Node2D
## A flying enemy in the world. Bats ram the balloon, harpies and goblins try to land in the
## basket, bombers fly close and explode (blowing a crater in the terrain too).

const STATS := {
	"bat": {"hp": 2, "speed": 50.0, "radius": 6.0, "damage": 5.0, "gold": 3,
		"drops": {"ammo": 0.35, "fuel": 0.2, "gold": 0.15}},
	"harpy": {"hp": 3, "speed": 42.0, "radius": 7.0, "damage": 0.0, "gold": 5,
		"drops": {"ammo": 0.3, "fuel": 0.25, "gold": 0.25}},
	"goblin": {"hp": 3, "speed": 34.0, "radius": 7.0, "damage": 0.0, "gold": 6,
		"drops": {"ammo": 0.25, "fuel": 0.3, "gold": 0.35}},
	"bomber": {"hp": 2, "speed": 30.0, "radius": 7.0, "damage": 18.0, "gold": 10,
		"drops": {"ammo": 0.2, "fuel": 0.3, "gold": 0.5}},
}
const FUSE := 0.7
const BAT_RAMS := 3     # a bat flies off after ramming this many times

var kind := "bat"
var run: Node
var hp := 1
var radius := 6.0
var vel := Vector2.ZERO
var dying := false     # shoved overboard, tumbling away
var _t := 0.0
var _cooldown := 0.0
var _fuse := -1.0
var _flash := 0.0
var _wobble := randf() * TAU
var _rams := 0


func _ready() -> void:
	var s: Dictionary = STATS[kind]
	hp = s["hp"]
	radius = s["radius"]


func _physics_process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	_flash = maxf(0.0, _flash - dt)
	queue_redraw()
	if dying:
		vel.y += 220.0 * dt
		position += vel * dt
		rotation += dt * 9.0
		if _t > 3.0:
			queue_free()
		return
	var b: Balloon = run.balloon
	if b.frozen:
		position += vel * dt
		return
	if b.global_position.x - global_position.x > 900.0:
		queue_free()
		return
	var target := b.center()
	if _rams >= BAT_RAMS:
		target = global_position + Vector2(-200, -120)  # had enough, flying off
	elif kind == "harpy" or kind == "goblin":
		target = b.world_of(Vector2(0, -16))
	var to := target - global_position
	var speed: float = STATS[kind]["speed"]
	var desired := to.normalized() * speed + Vector2(0, sin(_t * 4.0 + _wobble) * 18.0)
	vel = vel.lerp(desired, minf(1.0, dt * 2.0))
	_step(dt)
	var local := b.local_of(global_position)
	var touching := b.touches(local, radius)
	match kind:
		"bat":
			if touching and _cooldown <= 0.0 and _rams < BAT_RAMS:
				b.take_damage(STATS[kind]["damage"])
				b.knock_crew(Vector2(signf(vel.x) * 30.0, -30.0))
				vel = -to.normalized() * 90.0
				_cooldown = 1.5
				_rams += 1
				Sfx.play("hit")
		"harpy", "goblin":
			if Balloon.BASKET.grow(10.0).has_point(local):
				b.add_boarder(kind, global_position)
				queue_free()
		"bomber":
			if _fuse < 0.0 and global_position.distance_to(b.center()) < 50.0:
				_fuse = 0.0
	if _fuse >= 0.0:
		if int(_fuse * 7.0) != int((_fuse + dt) * 7.0) or _fuse == 0.0:
			Sfx.play("beep", 1.0 + _fuse, -8.0)
		_fuse += dt
		if _fuse >= FUSE:
			explode()


## Move, steering around terrain instead of flying through it.
func _step(dt: float) -> void:
	var t: Terrain = run.terrain
	var next := global_position + vel * dt
	if not t.is_solid_at(next):
		global_position = next
		return
	var vert := global_position + Vector2(0, vel.y * dt)
	var horiz := global_position + Vector2(vel.x * dt, 0)
	if not t.is_solid_at(vert):
		global_position = vert
		vel.x *= 0.5
	elif not t.is_solid_at(horiz):
		global_position = horiz
		vel.y *= 0.5
	else:
		vel = -vel * 0.5


func hit(damage: int) -> void:
	if dying:
		return
	hp -= damage
	_flash = 0.1
	Sfx.play("hit", 1.6, -14.0)
	if hp <= 0:
		if kind == "bomber":
			explode()
		else:
			run.enemy_killed(self)
			queue_free()


func explode() -> void:
	run.explosion(global_position, 28.0, STATS["bomber"]["damage"])
	run.enemy_killed(self)
	queue_free()


func shoved(v: Vector2) -> void:
	dying = true
	vel = v
	_t = 0.0


func _draw() -> void:
	var frame := int(_t * 8.0) % 2
	var tex := Art.sprite("%s_%d" % [kind, frame])
	var mod := Color.WHITE
	if _flash > 0.0:
		mod = Color(3, 3, 3)
	elif _fuse >= 0.0 and int(_fuse * 12.0) % 2 == 0:
		mod = Color(1.8, 0.6, 0.6)
	var flip := -1.0 if vel.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1))
	draw_texture(tex, -(tex.get_size() / 2.0).floor(), mod)
	draw_set_transform(Vector2.ZERO)
