class_name LanRoomBrowser
extends RefCounted

# Presentation-facing discovery boundary. Socket creation remains explicit and
# permission-gated inside the existing network implementation.
var _client := LanDiscoveryClient.new()


func start(port: int) -> Error:
	return _client.start(port)


func stop() -> void:
	_client.stop()


func poll() -> void:
	_client.poll()


func compatible_sessions() -> Array[Dictionary]:
	return _client.compatible_sessions()


func is_active() -> bool:
	return _client.is_active()
