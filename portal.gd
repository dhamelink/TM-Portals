
extends Area3D
@export var other_portal : Node3D

@export var cull_layer : int = 4

# Edge case but possible. Adding this to prevent teleporting twice if body lands exactly on portal plane
func _nonzero_sign(value):
	var s = sign(value)
	if s == 0:
		s = 1
	return s

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
	_set_portal_camera_environment_to_world3d_environment_no_tonemap()

func _set_portal_camera_environment_to_world3d_environment_no_tonemap():
	var world_3d = get_viewport().world_3d
	if not world_3d or not world_3d.environment:
		return
	# The tonemap must be disabled/set to linear.
	# This is so the tonemap won't be applied twice in the main camera render.
	$CameraViewport/Camera3D.environment = world_3d.environment.duplicate()
	$CameraViewport/Camera3D.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR


# Copied from https://github.com/V-Sekai/avatar_vr_demo/blob/master/addons/V-Sekai.xr-mirror/mirror.gd
func set_projection_oblique_near_plane(matrix: Projection, clip_plane: Plane):
	# Based on the paper
	# Lengyel, Eric. “Oblique View Frustum Depth Projection and Clipping”.
	# Journal of Game Development, Vol. 1, No. 2 (2005), Charles River Media, pp. 5–16.

	# Calculate the clip-space corner point opposite the clipping plane
	# as (sgn(clipPlane.x), sgn(clipPlane.y), 1, 1) and
	# transform it into camera space by multiplying it
	# by the inverse of the projection matrix
	var q = Vector4(
		(sign(clip_plane.x) + matrix.z.x) / matrix.x.x,
		(sign(clip_plane.y) + matrix.z.y) / matrix.y.y,
		-1.0,
		(1.0 + matrix.z.z) / matrix.w.z)

	var clip_plane4 = Vector4(clip_plane.x, clip_plane.y, clip_plane.z, clip_plane.d)

	# Calculate the scaled plane vector
	var c: Vector4 = clip_plane4 * (2.0 / clip_plane4.dot(q))

	# Replace the third row of the projection matrix
	matrix.x.z = c.x - matrix.x.w
	matrix.y.z = c.y - matrix.y.w
	matrix.z.z = c.z - matrix.z.w
	matrix.w.z = c.w - matrix.w.w
	return matrix

# This function is based on https://github.com/SebLague/Portals/blob/master/Assets/Scripts/Core/Portal.cs
func _update_portal_camera_near_clip_plane(camera):
	if not camera.has_method("set_override_projection"):
		print("doesnt have override projectiondww")
		return # Needs https://github.com/V-Sekai/godot/tree/override_projection_4.2 branch
	
	#near clip offset makes sur the clip plane isnt directly on the portal, to avoid z-fighting on the portal edge
	const NEAR_CLIP_OFFSET = 0.05
	const NEAR_CLIP_LIMIT = 0.1
	
	# Calculate the near clip plane in camera space
	#in godot, -z axis is the forward direction. clip_plane_forward is the direction the other portal is facing
	var clip_plane = other_portal.global_transform
	var clip_plane_forward: Vector3 = -clip_plane.basis.z
	#dot product tells you the angle between the portals forward and the vector from camera to portal. If positive, they point the same way, otherwise they oppose. This makes sure the clip plane always points toward the camera, no matter which side it's on, so you always clip the correct half of space.
	#if clip plane is behind frustum, then the clip plane cuts the front of the scene instead of the back, only rendering whats behind, thus nothing would show
	var portal_side = _nonzero_sign(clip_plane_forward.dot(other_portal.global_transform.origin - camera.global_transform.origin))
 	
	#Since the projection matrix only understands camera-local coordinates, the portals world position and normal are transformed into the cameras coordinate system. Done using the affine inverse, since you find the relative transform
	#.basis is used for the normal since its just a direction vecotr, it just needs to be rotated
	var cam_space_pos = camera.get_camera_transform().affine_inverse() * clip_plane.origin
	var cam_space_normal = (camera.get_camera_transform().affine_inverse().basis * clip_plane_forward) * portal_side
	#gives the planes distance from the camera. negated to match the Lengyel sign convention that the algorithm expects.
	var cam_space_dst = - cam_space_pos.dot(cam_space_normal) + NEAR_CLIP_OFFSET;
	
	# Oblique plane when very close to portal causes glitching/visual artifacts, so only enable if a small distance away
	if abs(cam_space_dst) > NEAR_CLIP_LIMIT:
		var proj : Projection = camera.get_camera_projection()
		var near_clip_plane = Plane(cam_space_normal, cam_space_dst)
		proj = set_projection_oblique_near_plane(proj, near_clip_plane)
		camera.set_override_projection(proj)
	else:
		# Set back to unmodified frustum if camera is very close to portal
		camera.set_override_projection(Projection(Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO))

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
	
	_update_portal_camera_near_clip_plane($CameraViewport/Camera3D)
	
func do_updates():
	$CollisionShape3D.disabled = not self.visible
	



			
	# Note: placing these after above so portal thickening/camera update happen same frame as move

	_update_camera_to_other_portal()

func _process(delta: float) -> void:
	do_updates()

func _physics_process(delta: float) -> void:
	do_updates()
