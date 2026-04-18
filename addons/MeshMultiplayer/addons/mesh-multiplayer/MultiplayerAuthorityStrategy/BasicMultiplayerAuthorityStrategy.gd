class_name BasicMultiplayerAuthorityStrategy extends MultiplayerAuthorityStrategy

func get_authority_data() -> Array:
	return []
	
func is_peer_authority(authority_id:int, peer_authority_id:int, peer_data: Array) -> bool:
	return peer_authority_id <= authority_id
	
func is_valid_peer(authority_id:int, peer_authority_id:int, peer_data: Array) -> bool:
	return true
