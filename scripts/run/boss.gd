class_name Boss
extends Node2D
## The Grumpus: a big, grumpy, fuzzy blob that turns up in three out of four levels. It hovers
## ahead of the balloon spitting grumble balls, now and then winds up and rams it, and gives up
## and stomps off after a while if nobody shoots it down. Hit points grow with the crew.

const NAME := "The Grumpus"
const RADIUS := 22.0
const STAY := 45.0           # seconds before it gets bored and leaves
const BALL_DAMAGE := 4.0
const RAM_DAMAGE := 8.0
const WINDUP := 1.1

enum State { ENTER, HOVER, WINDUP, CHARGE, LEAVE, DEAD }

var run: Node
var crew := 2
var hp := 1
var max_hp := 1
var state := State.ENTER
var vel := Vector2.ZERO
var _t := 0.0
var _state_t := 0.0
var _ball_cd := 2.5
var _ram_cd := 9.0
var _flash := 0.0
var _side := 1.0
var _charge_dir := Vector2.ZERO


func _ready() -> void:
	max_hp = 16 + 6 * crew
	hp = max_hp
	z_index = 2


func _exit_tree() -> void:
	if run != null and run.boss == self:
		run.boss = null


func alive() -> bool:
	return state != State.DEAD and state != State.LEAVE


func ball_interval() -> float:
	return maxf(2.2, 4.4 - 0.25 * (crew - 1))


func _physics_process(dt: float) -> void:
	_t += dt
	_state_t += dt
	_flash = maxf(0.0, _flash - dt)
	queue_redraw()
	var b: Balloon = run.balloon
	var home := b.center() + Vector2(_side * 130.0, -40.0 + sin(_t * 1.3) * 24.0)
	match state:
		State.ENTER:
			_seek(home, 160.0, dt)
			if global_position.distance_to(home) < 30.0:
				_to(State.HOVER)
		State.HOVER:
			_seek(home, 90.0, dt)
			if b.frozen:
				return
			_ball_cd -= dt
			_ram_cd -= dt
			if _ball_cd <= 0.0:
				_ball_cd = ball_interval() * randf_range(0.8, 1.2)
				_spit(b)
			if _ram_cd <= 0.0:
				_ram_cd = randf_range(9.0, 12.0)
				_to(State.WINDUP)
				Sfx.play("roar", 1.1)
			if _t > STAY:
				_to(State.LEAVE)
				Sfx.play("roar", 0.7)
				run.hud.message("%s got bored and stomped off" % NAME, Color("d0c0a0"))
		State.WINDUP:
			vel = vel.lerp(Vector2.ZERO, minf(1.0, dt * 6.0))
			global_position += vel * dt
			if _state_t >= WINDUP:
				_charge_dir = (b.center() - global_position).normalized()
				vel = _charge_dir * 260.0
				_to(State.CHARGE)
		State.CHARGE:
			global_position += vel * dt
			run.terrain.damage_circle(global_position, RADIUS * 0.8, 6.0 * dt)
			var local := b.local_of(global_position)
			if b.touches(local, RADIUS * 0.6):
				b.take_damage(RAM_DAMAGE)
				b.knock_crew(_charge_dir * 90.0 + Vector2(0, -50))
				b.velocity += _charge_dir * 50.0
				run.shake(7.0)
				Sfx.play("boom", 0.7)
				_side = -_side
				_to(State.HOVER)
			elif _state_t > 1.4:
				_side = -_side
				_to(State.HOVER)
		State.LEAVE:
			vel = vel.lerp(Vector2(-40.0, -160.0), minf(1.0, dt * 2.0))
			global_position += vel * dt
			if _state_t > 4.0:
				queue_free()
		State.DEAD:
			vel.y += 200.0 * dt
			global_position += vel * dt
			rotation += dt * 3.0
			if _state_t > 3.0:
				queue_free()


func _to(s: State) -> void:
	state = s
	_state_t = 0.0


func _seek(target: Vector2, speed: float, dt: float) -> void:
	var to := target - global_position
	vel = vel.lerp(to.limit_length(speed), minf(1.0, dt * 2.5))
	global_position += vel * dt


func _spit(b: Balloon) -> void:
	var lead := b.center() + b.velocity * 0.6
	var ball := GrumbleBall.new()
	ball.run = run
	ball.position = global_position + Vector2(0, 8)
	ball.vel = (lead - ball.position).normalized() * 95.0
	run.bullets.add_child(ball)
	Sfx.play("spit", randf_range(0.9, 1.1))


func hit(damage: int) -> void:
	if not alive():
		return
	hp -= damage
	_flash = 0.08
	Sfx.play("thud", randf_range(0.8, 1.0), -10.0)
	if hp <= 0:
		_to(State.DEAD)
		vel = Vector2(0, -80)
		run.boss_defeated(self)


func _draw() -> void:
	var frames := Art.boss_frames()
	var f := int(_t * 3.0) % 2
	if state == State.WINDUP or state == State.CHARGE:
		f = 2
	var tex: Texture2D = frames[f]
	var mod := Color.WHITE
	if _flash > 0.0:
		mod = Color(2.5, 1.2, 1.2)
	elif state == State.WINDUP and int(_state_t * 10.0) % 2 == 0:
		mod = Color(1.6, 0.8, 0.8)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 1.5 if state == State.WINDUP else Vector2.ZERO
	var flip := -1.0 if vel.x < -20.0 and state == State.CHARGE else 1.0
	draw_set_transform(shake, 0.0, Vector2(flip, 1))
	draw_texture(tex, -(tex.get_size() / 2.0).floor(), mod)
	draw_set_transform(Vector2.ZERO)


class GrumbleBall:
	extends Node2D
	## A slow, fuzzy spitball. Hurts the balloon; the turret can shoot it down.
	var run: Node
	var vel := Vector2.ZERO
	var _t := 0.0

	func _physics_process(dt: float) -> void:
		_t += dt
		position += vel * dt
		queue_redraw()
		var b: Balloon = run.balloon
		if b.touches(b.local_of(global_position), 4.0):
			b.take_damage(Boss.BALL_DAMAGE)
			run.burst(global_position, Color("e8e4dc"), 10)
			Sfx.play("splat")
			queue_free()
		elif _t > 6.0 or run.terrain.is_solid_at(global_position):
			run.burst(global_position, Color("e8e4dc"), 6)
			queue_free()

	func shot() -> void:
		run.burst(global_position, Color("e8e4dc"), 6)
		Sfx.play("splat", 1.4, -12.0)
		queue_free()

	func _draw() -> void:
		var r := 4.0 + (1.0 if int(_t * 8.0) % 2 == 0 else 0.0)
		draw_circle(Vector2.ZERO, r + 1.0, Color("1a1418"))
		draw_circle(Vector2.ZERO, r, Color("f4f1ea"))
		draw_rect(Rect2(-2, -2, 1, 1), Color("1a1418"))
		draw_rect(Rect2(1, -2, 1, 1), Color("1a1418"))
