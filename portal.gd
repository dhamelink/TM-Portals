
extends Area3D
@export var other_portal : Node3D

@export var cull_layer : int = 4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	$PortalVisual.set_layer_mask_value(1, false)
	$PortalVisual.set_layer_mask_value(cull_layer, true)
	$CameraViewport/Camera3D.set_cull_mask_value(other_portal.cull_layer, false)
		# Godot normally does order _process/_phys_process -> internal physics step moving bodies -> draw immediately
	# We must call do_updates on the frame_pre_draw signal or there will be 1 frame where the body has not actually teleported
	# This will mess up the view and cause flicker for 1 frame on  player controllers
	#RenderingServer.frame_pre_draw.connect(do_updates)
	# Or so I would think. It only works with this + _process + _physics_process all calling do_updates.
	# Otherwise there is flicker. I'm not sure why just frame_pre_draw doesn't work.
func _update_camera_to_other_portal():
	var cur_camera = get_viewport().get_camera_3d()
	if not cur_camera:
		return
	
	# first, get the relative position/rotation of the camera to this portal
	var cur_camera_transform_rel_to_this_portal = self.global_transform.affine_inverse() * cur_camera.global_transform
	var moved_to_other_portal = other_portal.global_transform * cur_camera_transform_rel_to_this_portal
	# then, set the portal camera's transform to that relative position/rotation, but relative to other_portal
	$CameraViewport/Camera3D.global_transform = moved_to_other_portal
	$CameraViewport/Camera3D.fov = cur_camera.fov
	
	$CameraViewport/Camera3D.cull_mask = cur_camera.cull_mask
	$CameraViewport/Camera3D.set_cull_mask_value(other_portal.cull_layer, false)
	# make sure that the portals camera settings are the same as the players, to prevent artifacts
	$CameraViewport.size = get_viewport().get_visible_rect().size
	$CameraViewport.msaa_3d = get_viewport().msaa_3d
	$CameraViewport.screen_space_aa = get_viewport().screen_space_aa
	$CameraViewport.use_taa = get_viewport().use_taa
	$CameraViewport.use_debanding = get_viewport().use_debanding
	$CameraViewport.use_occlusion_culling = get_viewport().use_occlusion_culling
	$CameraViewport.mesh_lod_threshold = get_viewport().mesh_lod_threshold
	
func do_updates():
	$CollisionShape3D.disabled = not self.visible
	



			
	# Note: placing these after above so portal thickening/camera update happen same frame as move

	_update_camera_to_other_portal()

func _process(delta: float) -> void:
	do_updates()

func _physics_process(delta: float) -> void:
	do_updates()
