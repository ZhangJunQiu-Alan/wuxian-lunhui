extends GodZone
static var timings := [0,0,0]
func _process(delta: float) -> void:
	var start:=Time.get_ticks_usec()
	super._process(delta)
	var elapsed:=Time.get_ticks_usec()-start
	timings[0]+=1
	timings[1]+=elapsed
	timings[2]=maxi(timings[2],elapsed)
