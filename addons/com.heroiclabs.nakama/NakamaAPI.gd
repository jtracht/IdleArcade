extends RefCounted
class_name NakamaAPI

## Nakama API model definitions and data representations.

class ApiUser extends RefCounted:
	var id: String = ""
	var username: String = ""
	var display_name: String = ""
	var avatar_url: String = ""
	var lang_tag: String = ""
	var location: String = ""
	var timezone: String = ""
	var metadata: String = "{}"
	var online: bool = false
	var edge_count: int = 0
	var create_time: String = ""
	var update_time: String = ""

	static func from_dict(p_dict: Dictionary) -> ApiUser:
		var u = ApiUser.new()
		u.id = p_dict.get("id", "")
		u.username = p_dict.get("username", "")
		u.display_name = p_dict.get("display_name", "")
		u.avatar_url = p_dict.get("avatar_url", "")
		u.lang_tag = p_dict.get("lang_tag", "")
		u.location = p_dict.get("location", "")
		u.timezone = p_dict.get("timezone", "")
		u.metadata = str(p_dict.get("metadata", "{}"))
		u.online = bool(p_dict.get("online", false))
		u.edge_count = int(p_dict.get("edge_count", 0))
		u.create_time = p_dict.get("create_time", "")
		u.update_time = p_dict.get("update_time", "")
		return u

class ApiAccount extends RefCounted:
	var user: ApiUser = null
	var email: String = ""
	var devices: Array = []
	var custom_id: String = ""
	var verify_time: String = ""
	var disable_time: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiAccount:
		var a = ApiAccount.new()
		if p_dict.has("user") and p_dict["user"] is Dictionary:
			a.user = ApiUser.from_dict(p_dict["user"])
		a.email = p_dict.get("email", "")
		a.devices = p_dict.get("devices", [])
		a.custom_id = p_dict.get("custom_id", "")
		a.verify_time = p_dict.get("verify_time", "")
		a.disable_time = p_dict.get("disable_time", "")
		return a

class ApiLeaderboardRecord extends RefCounted:
	var leaderboard_id: String = ""
	var owner_id: String = ""
	var username: String = ""
	var score: int = 0
	var subscore: int = 0
	var num_score: int = 0
	var metadata: String = "{}"
	var rank: int = 0
	var max_num_score: int = 0
	var create_time: String = ""
	var update_time: String = ""
	var expiry_time: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiLeaderboardRecord:
		var r = ApiLeaderboardRecord.new()
		r.leaderboard_id = p_dict.get("leaderboard_id", "")
		r.owner_id = p_dict.get("owner_id", "")
		r.username = p_dict.get("username", "")
		r.score = int(p_dict.get("score", 0))
		r.subscore = int(p_dict.get("subscore", 0))
		r.num_score = int(p_dict.get("num_score", 0))
		r.metadata = str(p_dict.get("metadata", "{}"))
		r.rank = int(p_dict.get("rank", 0))
		r.max_num_score = int(p_dict.get("max_num_score", 0))
		r.create_time = p_dict.get("create_time", "")
		r.update_time = p_dict.get("update_time", "")
		r.expiry_time = p_dict.get("expiry_time", "")
		return r

class ApiLeaderboardRecordList extends RefCounted:
	var records: Array = []
	var owner_records: Array = []
	var next_cursor: String = ""
	var prev_cursor: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiLeaderboardRecordList:
		var l = ApiLeaderboardRecordList.new()
		for item in p_dict.get("records", []):
			if item is Dictionary:
				l.records.append(ApiLeaderboardRecord.from_dict(item))
		for item in p_dict.get("owner_records", []):
			if item is Dictionary:
				l.owner_records.append(ApiLeaderboardRecord.from_dict(item))
		l.next_cursor = p_dict.get("next_cursor", "")
		l.prev_cursor = p_dict.get("prev_cursor", "")
		return l

class ApiGroup extends RefCounted:
	var id: String = ""
	var creator_id: String = ""
	var name: String = ""
	var description: String = ""
	var avatar_url: String = ""
	var lang_tag: String = ""
	var metadata: String = "{}"
	var open: bool = true
	var edge_count: int = 0
	var max_count: int = 50
	var create_time: String = ""
	var update_time: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiGroup:
		var g = ApiGroup.new()
		g.id = p_dict.get("id", "")
		g.creator_id = p_dict.get("creator_id", "")
		g.name = p_dict.get("name", "")
		g.description = p_dict.get("description", "")
		g.avatar_url = p_dict.get("avatar_url", "")
		g.lang_tag = p_dict.get("lang_tag", "")
		g.metadata = str(p_dict.get("metadata", "{}"))
		g.open = bool(p_dict.get("open", true))
		g.edge_count = int(p_dict.get("edge_count", 0))
		g.max_count = int(p_dict.get("max_count", 50))
		g.create_time = p_dict.get("create_time", "")
		g.update_time = p_dict.get("update_time", "")
		return g

class ApiGroupList extends RefCounted:
	var groups: Array = []
	var cursor: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiGroupList:
		var l = ApiGroupList.new()
		for item in p_dict.get("groups", []):
			if item is Dictionary:
				l.groups.append(ApiGroup.from_dict(item))
		l.cursor = p_dict.get("cursor", "")
		return l

class ApiGroupUser extends RefCounted:
	var user: ApiUser = null
	var state: int = 0

	static func from_dict(p_dict: Dictionary) -> ApiGroupUser:
		var gu = ApiGroupUser.new()
		if p_dict.has("user") and p_dict["user"] is Dictionary:
			gu.user = ApiUser.from_dict(p_dict["user"])
		gu.state = int(p_dict.get("state", 0))
		return gu

class ApiGroupUserList extends RefCounted:
	var group_users: Array = []
	var cursor: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiGroupUserList:
		var l = ApiGroupUserList.new()
		for item in p_dict.get("group_users", []):
			if item is Dictionary:
				l.group_users.append(ApiGroupUser.from_dict(item))
		l.cursor = p_dict.get("cursor", "")
		return l

class ApiStorageObject extends RefCounted:
	var collection: String = ""
	var key: String = ""
	var user_id: String = ""
	var value: String = "{}"
	var version: String = ""
	var permission_read: int = 1
	var permission_write: int = 1
	var create_time: String = ""
	var update_time: String = ""

	static func from_dict(p_dict: Dictionary) -> ApiStorageObject:
		var o = ApiStorageObject.new()
		o.collection = p_dict.get("collection", "")
		o.key = p_dict.get("key", "")
		o.user_id = p_dict.get("user_id", "")
		o.value = str(p_dict.get("value", "{}"))
		o.version = p_dict.get("version", "")
		o.permission_read = int(p_dict.get("permission_read", 1))
		o.permission_write = int(p_dict.get("permission_write", 1))
		o.create_time = p_dict.get("create_time", "")
		o.update_time = p_dict.get("update_time", "")
		return o

class ApiStorageObjects extends RefCounted:
	var objects: Array = []
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiStorageObjects:
		var l = ApiStorageObjects.new()
		for item in p_dict.get("objects", []):
			if item is Dictionary:
				l.objects.append(ApiStorageObject.from_dict(item))
		return l

class ApiStorageObjectAck extends RefCounted:
	var collection: String = ""
	var key: String = ""
	var version: String = ""
	var user_id: String = ""

	static func from_dict(p_dict: Dictionary) -> ApiStorageObjectAck:
		var a = ApiStorageObjectAck.new()
		a.collection = p_dict.get("collection", "")
		a.key = p_dict.get("key", "")
		a.version = p_dict.get("version", "")
		a.user_id = p_dict.get("user_id", "")
		return a

class ApiStorageObjectAcks extends RefCounted:
	var acks: Array = []
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiStorageObjectAcks:
		var l = ApiStorageObjectAcks.new()
		for item in p_dict.get("acks", []):
			if item is Dictionary:
				l.acks.append(ApiStorageObjectAck.from_dict(item))
		return l

class ApiRpc extends RefCounted:
	var id: String = ""
	var payload: String = ""
	var http_key: String = ""
	var _exception: NakamaException = null

	func is_exception() -> bool:
		return _exception != null

	func get_exception() -> NakamaException:
		return _exception

	static func from_dict(p_dict: Dictionary) -> ApiRpc:
		var r = ApiRpc.new()
		r.id = p_dict.get("id", "")
		r.payload = str(p_dict.get("payload", ""))
		r.http_key = p_dict.get("http_key", "")
		return r
