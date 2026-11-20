class_name DtoContract
extends RefCounted


static func is_primitive_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return true
		TYPE_ARRAY:
			for item in value:
				if not is_primitive_safe(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING:
					return false
				if not is_primitive_safe(value[key]):
					return false
			return true
		_:
			return false


static func is_stable_id(value: String) -> bool:
	return not value.is_empty()
