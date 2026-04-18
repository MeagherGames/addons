@abstract class_name MultiplayerAuthorityStrategy extends RefCounted

@warning_ignore("unused_signal")
signal exit_requested()
@warning_ignore("unused_signal")
signal join_requested()

## A function to override to pass extra data with peers when deciding authority
@abstract func get_authority_data() -> Array
## Determine if a peer should be your authority
@abstract func is_peer_authority(authority_id:int, peer_authority_id:int, peer_data: Array) -> bool
@abstract func is_valid_peer(authority_id:int, peer_authority_id:int, peer_data: Array) -> bool
