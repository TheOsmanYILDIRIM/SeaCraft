class_name LanPermissionGate
extends RefCounted

const PERMISSION := "android.permission.ACCESS_LOCAL_NETWORK"
const RESULT_ALLOWED := "allowed"
const RESULT_REQUEST_REQUIRED := "request_required"
const RESULT_REQUESTED := "requested"
const RESULT_DENIED := "local_network_permission_denied"


static func evaluate(platform_name: String, granted_permissions: PackedStringArray) -> String:
	if platform_name != "Android":
		return RESULT_ALLOWED
	return RESULT_ALLOWED if granted_permissions.has(PERMISSION) else RESULT_REQUEST_REQUIRED


func status() -> String:
	return evaluate(OS.get_name(), OS.get_granted_permissions())


func can_open_lan_socket() -> bool:
	return status() == RESULT_ALLOWED


func request_from_user_action() -> String:
	if can_open_lan_socket():
		return RESULT_ALLOWED
	if OS.get_name() != "Android":
		return RESULT_ALLOWED
	return RESULT_REQUESTED if OS.request_permission(PERMISSION) else RESULT_DENIED
