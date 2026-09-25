extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")
const DefaultNodeService = preload(
	"res://addons/weavly/src/services/implementations/default_node_service.gd"
)
const DefaultVariableService = preload(
	"res://addons/weavly/src/services/implementations/default_variable_service.gd"
)


func _make_engine() -> WeavlyEngine:
	var engine: WeavlyEngine = auto_free(FakeEngine.new())
	add_child(engine)
	return engine


# =====================
# create_service
# =====================


func test_create_service_returns_user_instance_when_extends_base_type() -> void:
	var engine: WeavlyEngine = _make_engine()
	var service: WeavlyService = WeavlyDefaultEngine.create_service(
		engine, DefaultNodeService, DefaultNodeService, WeavlyNodeService
	)
	assert_bool(service is DefaultNodeService).is_true()
	assert_that(service.engine).is_equal(engine)


func test_create_service_falls_back_to_default_when_wrong_base_type() -> void:
	var engine: WeavlyEngine = _make_engine()
	var service: WeavlyService = WeavlyDefaultEngine.create_service(
		engine, DefaultVariableService, DefaultNodeService, WeavlyNodeService
	)
	assert_bool(service is DefaultNodeService).is_true()
	assert_bool(service is DefaultVariableService).is_false()
	assert_that(service.engine).is_equal(engine)
	assert_logged([], ["Falling back to default."])


func test_create_service_uses_default_when_user_script_null() -> void:
	var engine: WeavlyEngine = _make_engine()
	var service: WeavlyService = WeavlyDefaultEngine.create_service(
		engine, null, DefaultNodeService, WeavlyNodeService
	)
	assert_bool(service is DefaultNodeService).is_true()
	assert_that(service.engine).is_equal(engine)
