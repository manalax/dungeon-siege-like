class_name MathUtil
extends RefCounted
## Small static math helpers. Add only what features actually need.


## Maps v from [in_a, in_b] to [out_a, out_b], clamped to the output range.
static func remap_clamped(v: float, in_a: float, in_b: float, out_a: float, out_b: float) -> float:
	if is_equal_approx(in_a, in_b):
		return out_a
	var t := clampf((v - in_a) / (in_b - in_a), 0.0, 1.0)
	return lerpf(out_a, out_b, t)


static func safe_div(a: float, b: float, fallback: float = 0.0) -> float:
	return fallback if is_zero_approx(b) else a / b


static func round_to_step(v: float, step: float) -> float:
	return v if is_zero_approx(step) else roundf(v / step) * step


## pct is a percentage (120.0 = 120%).
static func percent_of(value: float, pct: float) -> float:
	return value * pct / 100.0


static func flatten_y(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Distance on the XZ plane (ignores height), for top-down range checks.
static func planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Wraps to (-180, 180].
static func wrap_degrees(deg: float) -> float:
	var w := fposmod(deg + 180.0, 360.0) - 180.0
	return 180.0 if is_equal_approx(w, -180.0) else w
