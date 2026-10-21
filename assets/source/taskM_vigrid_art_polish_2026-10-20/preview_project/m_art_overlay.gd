extends Node2D

var effect := ""
var frame := 0
var guide := false
var radius := 130.0
var arc := false
var angle := PI
var strip: Texture2D

func _ready() -> void:
    if not arc:
        strip = load("res://assets/sprites/effects/gods/" + effect + ".png")

func _draw() -> void:
    if arc:
        if guide:
            var polygon := BossFx.sector(Vector2.ZERO, 290.0, angle, 1.05)
            draw_colored_polygon(polygon, Color(.25, .8, 1, .07))
            polygon.append(polygon[0])
            draw_polyline(polygon, Color(.3, .9, 1, .75), 1.0)
        BossFx.draw(self, "surtr_sword_arc_large", float(frame) / 16.0, Vector2.ZERO,
            angle, Vector2.ONE, Color.WHITE, false, 290.0, 1.05, false)
    else:
        SpriteVisual.draw_frame(self, strip, 8, frame, Vector2.ZERO, Vector2(160,160))
        if guide:
            for i in 32:
                draw_arc(Vector2.ZERO, radius, TAU * i / 32, TAU * (i + .6) / 32, 5, Color(.4,1,.7,.65), 1.0)
