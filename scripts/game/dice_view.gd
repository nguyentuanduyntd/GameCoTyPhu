class_name DiceView
extends Node3D
## Hai viên xúc xắc 3D (chấm 1 và 4 màu đỏ như xúc xắc truyền thống).

const SIZE := 0.6
const REST := Vector3(-4.6, 0.1, 2.4)

# Mặt -> pháp tuyến cục bộ. Mặt đối diện cộng lại bằng 7.
const FACE_NORMALS := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.RIGHT, 5: Vector3.LEFT, 3: Vector3.BACK, 4: Vector3.FORWARD}
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), Vector2(0, 0)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}

var dice: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for i in 2:
		var d := _make_die()
		d.position = REST + Vector3(-0.5 + i * 1.0, SIZE / 2 + 0.08, 0)
		add_child(d)
		dice.append(d)


func roll(values: Array, speed: float = 1.0) -> void:
	var dur := 0.75 / speed
	var tw := create_tween().set_parallel(true)
	var count := values.size()
	dice[1].visible = count > 1
	for i in count:
		var d: Node3D = dice[i]
		var x := 0.0 if count == 1 else -0.55 + i * 1.1
		var target := REST + Vector3(x + rng.randf_range(-0.15, 0.15), SIZE / 2 + 0.08, rng.randf_range(-0.2, 0.2))
		d.position = target + Vector3(rng.randf_range(-1.5, 1.5), 3.5, 2.0)
		var final_rot := _face_up_basis(int(values[i]), rng.randf() * TAU).get_euler()
		var spin := Vector3(TAU * rng.randi_range(2, 3), TAU * rng.randi_range(1, 2), TAU * rng.randi_range(2, 3))
		d.rotation = final_rot + spin
		tw.tween_property(d, "position", target, dur).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "rotation", final_rot, dur * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(0.25 / speed).timeout


func _face_up_basis(v: int, yaw: float) -> Basis:
	var b := Basis.IDENTITY
	match v:
		6:
			b = Basis(Vector3.RIGHT, PI)
		2:
			b = Basis(Vector3.BACK, PI / 2)
		5:
			b = Basis(Vector3.BACK, -PI / 2)
		3:
			b = Basis(Vector3.RIGHT, -PI / 2)
		4:
			b = Basis(Vector3.RIGHT, PI / 2)
	return Basis(Vector3.UP, yaw) * b


func _make_die() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * SIZE
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#fffdf7")
	mat.roughness = 0.4
	body.material_override = mat
	root.add_child(body)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("#212121")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#d32f2f")
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.065
	pip_mesh.height = 0.13
	for v in FACE_NORMALS.keys():
		var n: Vector3 = FACE_NORMALS[v]
		var u: Vector3
		var w: Vector3
		if absf(n.y) > 0.5:
			u = Vector3.RIGHT
			w = Vector3.BACK
		elif absf(n.x) > 0.5:
			u = Vector3.UP
			w = Vector3.BACK
		else:
			u = Vector3.RIGHT
			w = Vector3.UP
		for pp in PIPS[v]:
			var pip := MeshInstance3D.new()
			pip.mesh = pip_mesh
			pip.material_override = red if (v == 1 or v == 4) else black
			pip.position = n * (SIZE / 2 - 0.004) + u * pp.x * 0.15 + w * pp.y * 0.15
			pip.scale = Vector3.ONE - n.abs() * 0.7
			root.add_child(pip)
	return root
