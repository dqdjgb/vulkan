extends Node2D
var objects: Array[Array] = []

@onready var cir_shape := CircleShape2D.new()
@export var tex: Texture2D
@export var spawnRad: float
var texSize: float = 48
var pointer: bool = true
@onready var attrForce: float = get_parent().attrForce
@export var sprayAngle: float = PI  # 喷射角度范围（弧度）
@export var spraySpeed: float = 2000  # 喷射速度
@export var spawnInterval: float = 0.06  # 水滴生成间隔（秒）
@export var particlesPerBurst: int = 30  # 每次喷发的粒子数量

@export var activeDuration: float = 2.0  # 喷发持续时间（秒）
@export var pauseDuration: float = 5.0  # 停顿时间（秒）
@export var particleLifetime: float = 5.0  # 每个粒子的生存周期（秒）

var is_active: bool = true  # 当前是否处于喷发阶段

func _ready() -> void:
	cir_shape.radius = 6
	cir_shape.custom_solver_bias = 0.1
	start_fountain()

# 定时生成水滴
func start_fountain():
	spawn_fountain()

# 喷泉逻辑
func spawn_fountain():
	while true:
		if is_active:
		# 喷发阶段
			for i in range(int(activeDuration / spawnInterval)):
				spawn_particles()
				await get_tree().create_timer(spawnInterval).timeout
			is_active = false
		else:
			await get_tree().create_timer(pauseDuration).timeout
			is_active = true

			
# 生成粒子逻辑
func spawn_particles():
	# 喷发多个粒子
	for i in range(particlesPerBurst):
		var angle = randf() * sprayAngle - sprayAngle / 2  # 随机喷射角度
		var velocity = Vector2(cos(angle), -sin(angle)) * (spraySpeed * randf())  # 初始速度（随机缩放）
		var position = global_position + Vector2(randf() * spawnRad - spawnRad / 2, 0)
		create_object(position, velocity)

func create_object(pos: Vector2, velocity: Vector2):
	var ps := PhysicsServer2D
	var object = ps.body_create()
	ps.body_set_space(object, get_world_2d().space)
	ps.body_add_shape(object, cir_shape)
	# 设置物理属性
	ps.body_set_param(object, ps.BODY_PARAM_FRICTION, 0.1)  # 光滑表面
	ps.body_set_param(object, ps.BODY_PARAM_BOUNCE, 0.8)    # 弹性
	ps.body_set_param(object, ps.BODY_PARAM_MASS, 0.1)      # 质量
	ps.body_set_mode(object, ps.BODY_MODE_RIGID_LINEAR)     # 刚体模式
	var trans := Transform2D(0, pos)
	ps.body_set_state(object, ps.BODY_STATE_TRANSFORM, trans)
	
	# 设置线性速度
	ps.body_set_state(object, ps.BODY_STATE_LINEAR_VELOCITY, velocity)

	var rs := RenderingServer
	var img := rs.canvas_item_create()
	rs.canvas_item_set_parent(img, get_canvas_item())
	rs.canvas_item_add_texture_rect(img, Rect2(texSize/-2, texSize/-2, texSize, texSize), tex)
	rs.canvas_item_set_transform(img, trans)
	
	# 添加生存时间（倒计时方式）
	var remaining_lifetime = particleLifetime
	objects.append([object, img, remaining_lifetime])

func _physics_process(delta):
	var index: int = 0
	for pair in objects:
		var object: RID = pair[0]
		var img: RID = pair[1]
		var remaining_lifetime: float = pair[2]
		# 移除
		if not object.is_valid():
			remove_object(index)
			continue
		remaining_lifetime -= delta
		pair[2] = remaining_lifetime  # 更新剩余时间
		var trans: Transform2D
		if PhysicsServer2D.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM) == null:
			remove_object(index)
			continue
		else:
			trans = PhysicsServer2D.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			trans.origin -= global_position
		if trans.origin.y > 648 - global_position.y or remaining_lifetime <= 0:
			objects.remove_at(index)
			PhysicsServer2D.free_rid(object)
			RenderingServer.free_rid(img)
		else:
			RenderingServer.canvas_item_set_transform(img, trans)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and (get_global_mouse_position() - global_position).distance_to(trans.origin) < 60 * $"../UI/Icon".scale.x and not pointer:
				PhysicsServer2D.body_set_constant_force(object, ((get_global_mouse_position() - global_position) - trans.origin).normalized()*attrForce)
			else:
				PhysicsServer2D.body_set_constant_force(object, Vector2.ZERO)
		index += 1

func _exit_tree():
	for pair in objects:
		var object: RID = pair[0]
		var img: RID = pair[1]
		PhysicsServer2D.free_rid(object)
		RenderingServer.free_rid(img)

func remove_object(index: int):
	if index < 0 or index >= objects.size():
		return  # 确保索引有效
	var object = objects[index][0]
	var img = objects[index][1]

	# 释放刚体资源
	if object.is_valid():
		PhysicsServer2D.free_rid(object)

	RenderingServer.free_rid(img)

	objects.remove_at(index)

func _process(delta: float) -> void:
	attrForce = get_parent().attrForce
	pointer = get_parent().pointer
	if Input.is_action_pressed("ui_accept"):
		var angle = randf() * sprayAngle - sprayAngle / 2  # 随机喷射角度
		var velocity = Vector2(cos(angle), -sin(angle)) * spraySpeed  # 初始速度
		create_object(global_position + Vector2(randf()-0.5, randf()-0.5).normalized()*spawnRad*randf(),velocity)
