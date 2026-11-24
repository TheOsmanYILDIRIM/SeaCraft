class_name LanPermissionGate
extends RefCounted

const PERMISSION := "android.permission.ACCESS_LOCAL_NETWORK"
const LOCAL_NETWORK_SDK := 37
const RESULT_ALLOWED := "allowed"
const RESULT_REQUEST_REQUIRED := "request_required"
const RESULT_REQUESTED := "requested"
const RESULT_DENIED := "local_network_permission_denied"
const RESULT_TIMEOUT := "local_network_permission_timeout"


# SeaCraft targets API 37. Earlier Android releases do not implement this
# runtime permission for normal LAN sockets. Unknown SDK stays fail-closed.
static func evaluate(platform_name: String, granted_permissions: PackedStringArray, sdk: int = LOCAL_NETWORK_SDK) -> String:
	if platform_name != "Android" or (sdk > 0 and sdk < LOCAL_NETWORK_SDK):
		return RESULT_ALLOWED
	return RESULT_ALLOWED if granted_permissions.has(PERMISSION) else RESULT_REQUEST_REQUIRED


static func android_sdk() -> int:
	if Engine.has_singleton("JavaClassWrapper"):
		var wrapper = Engine.get_singleton("JavaClassWrapper")
		var version = wrapper.wrap("android.os.Build$VERSION")
		if version != null:
			var sdk := int(version.SDK_INT)
			if sdk > 0:
				return sdk
	# Godot 4.7 documents Android's alias as e.g. "15 (SDK 35 build ...)".
	var alias := OS.get_version_alias()
	var marker := alias.find("SDK ")
	if marker >= 0:
		var number := alias.substr(marker + 4).get_slice(" ", 0).trim_suffix(")")
		if number.is_valid_int():
			return int(number)
	return 0


func status() -> String:
	if OS.get_name() != "Android":
		return RESULT_ALLOWED
	var sdk := android_sdk()
	if sdk > 0 and sdk < LOCAL_NETWORK_SDK:
		return RESULT_ALLOWED
	# Read Android's PackageManager directly when available, including custom
	# permissions not known to an older engine permission enumeration.
	if Engine.has_singleton("AndroidRuntime"):
		var runtime = Engine.get_singleton("AndroidRuntime")
		var context = runtime.getApplicationContext()
		if context != null:
			return RESULT_ALLOWED if int(context.checkSelfPermission(PERMISSION)) == 0 else RESULT_REQUEST_REQUIRED
	return evaluate("Android", OS.get_granted_permissions(), sdk)


func can_open_lan_socket() -> bool:
	return status() == RESULT_ALLOWED


func request_from_user_action() -> String:
	if can_open_lan_socket():
		return RESULT_ALLOWED
	# Godot's bool is NOT the result of the asynchronous Android prompt.
	OS.request_permission(PERMISSION)
	return RESULT_ALLOWED if can_open_lan_socket() else RESULT_REQUESTED


func request_and_wait(tree: SceneTree, on_pending: Callable = Callable(), timeout_ms: int = 60000) -> String:
	if can_open_lan_socket():
		return RESULT_ALLOWED
	# Register before requesting: Android can respond immediately, including denial.
	var response: Array[bool] = []
	var callback := func(permission: String, granted: bool) -> void:
		if permission == PERMISSION:
			response.append(granted)
	tree.on_request_permissions_result.connect(callback)
	var result := request_from_user_action()
	if result == RESULT_REQUESTED:
		if on_pending.is_valid():
			on_pending.call()
		var deadline := Time.get_ticks_msec() + maxi(0, timeout_ms)
		while not can_open_lan_socket() and response.is_empty() and Time.get_ticks_msec() < deadline:
			await tree.create_timer(0.2, true, false, true).timeout
		# Always re-read the OS grant; a callback by itself cannot open sockets.
		if can_open_lan_socket():
			result = RESULT_ALLOWED
		elif not response.is_empty() and not response.back():
			result = RESULT_DENIED
		elif not response.is_empty():
			# Some devices deliver the callback just before permission state updates.
			await tree.create_timer(0.2, true, false, true).timeout
			result = RESULT_ALLOWED if can_open_lan_socket() else RESULT_DENIED
		else:
			result = RESULT_TIMEOUT
	tree.on_request_permissions_result.disconnect(callback)
	return result


static func user_message(result: String) -> String:
	if result == RESULT_TIMEOUT:
		return "İzin yanıtı alınamadı. Android uygulama izinlerini kontrol edip tekrar deneyin."
	return "Yerel ağ izni verilmedi. Ayarlar > Uygulamalar > SeaCraft > İzinler bölümünden Yakındaki cihazlar / Yerel ağ iznini açıp tekrar deneyin."
