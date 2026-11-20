class_name SectorIds
extends RefCounted

# Namespaced ASCII IDs with nonempty segments; no filesystem or node identity.
static func valid(id: String) -> bool:
	if id.length() < 3 or id.length() > 96 or not id.contains("."):
		return false
	var segment_start := true
	for i in id.length():
		var code := id.unicode_at(i)
		var letter := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if code == 46 and not segment_start:
			segment_start = true
		elif letter or (not segment_start and (digit or code == 95 or code == 45)):
			segment_start = false
		else:
			return false
	return not segment_start
