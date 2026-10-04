@abstract class_name WeavlyLineService
extends WeavlyService

# Whether the dialogue waits for next() after the filled line; line_reached passes it on either way.
@abstract func waits(line: WeavlyModel.LineStatement) -> bool
