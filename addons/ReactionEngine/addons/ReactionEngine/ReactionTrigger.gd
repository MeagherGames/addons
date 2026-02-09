class_name ReactionTrigger extends Resource

## A user-friendly text representation of the trigger.
## If not set, it defaults to "ON_<RESOURCE_NAME>".
@export_placeholder("ON TRIGGER") var on_text: String = "":
    get:
        if on_text:
            return on_text
        elif resource_path:
            var filename = resource_path.get_basename().get_file().to_upper()
            return "ON %s" % filename
        return "ON UNKNOWN"