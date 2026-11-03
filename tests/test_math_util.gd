extends GutTest
## F-004: MathUtil helpers.


func test_remap_clamped() -> void:
	assert_almost_eq(MathUtil.remap_clamped(5.0, 0.0, 10.0, 100.0, 200.0), 150.0, 0.001)
	assert_almost_eq(MathUtil.remap_clamped(20.0, 0.0, 10.0, 100.0, 200.0), 200.0, 0.001)
	assert_almost_eq(MathUtil.remap_clamped(-5.0, 0.0, 10.0, 100.0, 200.0), 100.0, 0.001)
	assert_almost_eq(MathUtil.remap_clamped(1.0, 3.0, 3.0, 7.0, 9.0), 7.0, 0.001, "degenerate input range")


func test_safe_div() -> void:
	assert_almost_eq(MathUtil.safe_div(10.0, 4.0), 2.5, 0.001)
	assert_eq(MathUtil.safe_div(10.0, 0.0), 0.0)
	assert_eq(MathUtil.safe_div(10.0, 0.0, -1.0), -1.0)


func test_round_to_step() -> void:
	assert_almost_eq(MathUtil.round_to_step(7.3, 0.5), 7.5, 0.001)
	assert_almost_eq(MathUtil.round_to_step(7.3, 5.0), 5.0, 0.001)
	assert_almost_eq(MathUtil.round_to_step(7.3, 0.0), 7.3, 0.001)


func test_percent_of() -> void:
	assert_almost_eq(MathUtil.percent_of(200.0, 120.0), 240.0, 0.001)


func test_planar_helpers() -> void:
	assert_eq(MathUtil.flatten_y(Vector3(1, 5, 2)), Vector3(1, 0, 2))
	assert_almost_eq(MathUtil.planar_distance(Vector3(0, 0, 0), Vector3(3, 100, 4)), 5.0, 0.001)


func test_wrap_degrees() -> void:
	assert_almost_eq(MathUtil.wrap_degrees(540.0), 180.0, 0.001)
	assert_almost_eq(MathUtil.wrap_degrees(-180.0), 180.0, 0.001)
	assert_almost_eq(MathUtil.wrap_degrees(190.0), -170.0, 0.001)
	assert_almost_eq(MathUtil.wrap_degrees(-725.0), -5.0, 0.001)
