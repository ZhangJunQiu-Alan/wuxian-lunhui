from math import cos, pi, sin, tau
from random import Random

import bpy
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

from model_props import empty, material, mesh, point, ridge, skin, snowcap


# Profiles are drawn in front elevation. Their stepped depths give the cuts a
# physical edge under grazing light, and leave the individual carvings editable.
def carved_profile(parent, name, outline, depth, mat, bevel=.10):
    back, front = depth
    center = sum((Vector(p) for p in outline), Vector((0, 0))) / len(outline)
    rim = [(x, y, front - (front - back) * .40) for x, y in outline]
    face = [(x + bevel * (center.x - x), y + bevel * (center.y - y), front) for x, y in outline]
    n = len(outline)
    vertices = [(x, y, back) for x, y in outline] + rim + face
    faces = [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    faces += [tuple(index + n for index in quad) for quad in faces]
    # Explicit cap tessellation keeps the jaw and fracture notches open.
    for ring in (0, 2 * n):
        points = [Vector(p) for p in vertices[ring:ring + n]]
        faces += [tuple(ring + i for i in tri) for tri in tessellate_polygon([points])]
    return mesh(parent, name, vertices, faces, mat, uv_axis=1)


def trace(parent, name, points, mat, width=.013):
    radii = [width * (.55 if i in (0, len(points) - 1) else 1) for i in range(len(points))]
    return ridge(parent, name, points, radii, mat, 6)


def dressed_block(parent, name, at, width, height, depth, mat, seed):
    rng = Random(seed)
    cx, cy, cz = at
    boundary = [(-.50, -.28), (-.39, -.48), (.26, -.50), (.48, -.37),
                (.51, .27), (.36, .50), (-.35, .51), (-.51, .26)]
    edge = [(x + rng.uniform(-.048, .046), z + rng.uniform(-.045, .045)) for x, z in boundary]
    rings = []
    for index, (y, shrink) in enumerate(((0, .85), (.14, .99), (.79, 1), (1, .84))):
        rings.append([(cx + x * width * shrink + index * width * .011,
                       cy + (y + rng.uniform(-.035, .035)) * height,
                       cz + z * depth * shrink + rng.uniform(-.019, .019) * depth)
                      for x, z in edge])
    block = skin(parent, name, rings, mat)
    return block, rings[-1]


def drift(parent, name, at, size, mat, seed):
    rng = Random(seed)
    x, y, z = at
    w, h, d = size
    outline = [rng.uniform(.82, 1.16) for _ in range(14)]
    rings = []
    for r, elevation in ((1, -.13), (.92, .34), (.68, .76), (.32, .95), (.045, 1.0)):
        rings.append([(x + cos(i*tau/14)*w*.5*r*k + (1-r)*w*.12,
                       y + h*(elevation + .16*r*sin(i*1.08 + seed)),
                       z + sin(i*tau/14)*d*.5*r*k)
                      for i, k in enumerate(outline)])
    return skin(parent, name, rings, mat, smooth=True)


def braid(parent, name, x, bottom, height, face_z, mat, width=.19, turns=3):
    for side in (-1, 1):
        strand = []
        for i in range(65):
            t = i / 64
            turn = t * tau * turns
            strand.append((x + side * width * .5 * sin(turn), bottom + height * t,
                           face_z + side * .017 * cos(turn)))
        trace(parent, name, strand, mat, .023)
    for y in (bottom, bottom + height):
        trace(parent, name + " return", [(x + .046*cos(i*tau/24), y + .045*sin(i*tau/24), face_z)
                                          for i in range(25)], mat, .018)


def knot_panel(parent, y, z, mat):
    # Two diagonal loops cross over and under on the jamb plinth.
    for phase in (-1, 1):
        strand = []
        for i in range(57):
            t = i*tau/56
            x, yy = .157*cos(t), .086*sin(t)
            strand.append((x*.72 - phase*yy*.69, y + x*phase*.72 + yy*.69,
                           z + .014*sin(2*t + phase*pi/2)))
        trace(parent, "Inlaid plinth knot", strand, mat, .020)


def gate_jamb(root, side, mats, ruined, active):
    x = side * 1.20
    dressed_block(root, "Battered foundation", (x, -.052, .005), .91, .28, .88, mats["basalt"], 4+side)
    jamb = empty("Leaning jamb" if ruined else "Upright jamb", root, (x, .10, 0))
    if ruined:
        jamb.rotation_euler.y = .214
    levels = [(.10, .32, .82, .72, .01), (.41, .55, .73, .67, -.009),
              (.96, .58, .72, .64, .017), (1.54, .54, .68, .65, .02),
              (2.08, .58, .70, .62, -.013), (2.66, .37, .76, .66, -.017)]
    for i, (y, h, w, d, dx) in enumerate(levels):
        dressed_block(jamb, "Dressed jamb ashlar", (dx, y-.10, -.046), w, h, d, mats["stone"], i+27+side)
    carved_profile(jamb, "Carved shaft with chamfer", [(-.25,.40),(.22,.39),(.24,.59),(.215,2.66),
                    (.16,2.77),(-.195,2.79),(-.245,2.63)], (.228, .317), mats["stone"], .045)
    for s in (-1, 1):
        trace(jamb, "Chiselled bead", [(s*.205,.46,.326),(s*.207,1.12,.327),(s*.202,2.70,.326)], mats["edge"], .012)
        braid(jamb, "Interwoven stone relief", s*.137, .59, 2.06, .328, mats["edge"], .097, 5)
    carved_profile(jamb, "Plinth cartouche", [(-.257,.083),(.216,.069),(.25,.14),(.24,.39),
                    (-.211,.414),(-.257,.346)], (.291,.369), mats["stone"])
    knot_panel(jamb, .243, .385, mats["edge"])
    channels = empty("RunesLit" if active else "Dark chisel marks", jamb)
    runes = ([(0,0),(0,1),(.37,.75),(0,.51),(.34,.27)],
             [(-.35,.72),(0,.49),(.37,.27)], [(-.31,.18),(0,.87),(.31,.18)],
             [(-.31,.78),(.34,.22)], [(-.33,.25),(.34,.76)])
    for i in range(7):
        at = .63 + i*.278
        shape = runes[(i+side) % len(runes)]
        strokes = [shape]
        if len(shape) < 4:
            strokes.append([(0,0),(0,1)] if len(shape) == 2 or i % 3 else [(-.23,.36),(.23,.36)])
        for stroke in strokes:
            coords = [(u*.172, at+v*.164, .329) for u, v in stroke]
            trace(jamb, "Rune recess", coords, mats["cut"], .017)
            trace(channels, "Rune inlay", [(a,b,c+.01) for a,b,c in coords],
                  mats["rune"] if active else mats["cut"], .009)
    if ruined:
        trace(jamb, "Split in the upper block", [(-.34,2.37,.282),(-.22,2.32,.33),(-.13,2.34,.337),(.05,2.23,.339),
              (.13,2.23,.335),(.27,2.15,.30)], mats["cut"], .014)
    drift(root, "Drift against footing", (x+side*.29, -.01, .48), (.72,.143,.57), mats["snow"], 40+side)


def wolf_end(parent, side, mats):
    def profile(label, coords, depth, mat):
        return carved_profile(parent, label, [(side*x, y) for x,y in coords], depth, mats[mat])

    profile("Wolf finial · neck, ear and muzzle", [(1.17,-.178),(1.36,-.164),(1.53,-.092),(1.67,-.089),
            (1.86,-.025),(1.99,.014),(2.056,.103),(1.973,.152),(1.83,.191),(1.70,.293),
            (1.599,.458),(1.521,.398),(1.462,.459),(1.424,.278),(1.31,.20),(1.245,.028)], (.09,.290), "wood")
    profile("Wolf finial · carved cheek", [(1.29,-.063),(1.47,.103),(1.56,.188),(1.70,.16),
            (1.76,.093),(1.66,.035),(1.49,-.039),(1.53,.022)], (.282,.339), "carving")
    profile("Wolf finial · lower jaw", [(1.55,-.057),(1.71,-.062),(1.916,.007),(1.977,.014),
            (1.912,-.063),(1.735,-.115),(1.61,-.11)], (.12,.29), "wood")
    profile("Wolf finial · mouth", [(1.689,-.034),(1.860,.016),(1.985,.070),(1.943,.024),
            (1.837,-.001)], (.261,.295), "end")
    profile("Wolf finial · inset eye", [(1.537,.182),(1.632,.222),(1.70,.180),(1.621,.167)], (.316,.353), "end")
    profile("Wolf finial · brow", [(1.524,.218),(1.637,.251),(1.722,.197),(1.634,.222)], (.280,.356), "carving")
    profile("Wolf finial · nose", [(1.936,.135),(2.006,.137),(2.056,.104),(2.021,.057),(1.966,.06)], (.181,.305), "end")
    profile("Wolf finial · tooth", [(1.86,.024),(1.892,.031),(1.881,-.016)], (.261,.302), "carving")
    for i, points in enumerate((((1.331,.004),(1.429,.069),(1.491,.114)),
                                ((1.367,-.069),(1.449,-.037),(1.487,.006)),
                                ((1.478,.238),(1.516,.308),(1.491,.375)))):
        trace(parent, "Finial gouge", [(side*x,y,.304) for x,y in points], mats["end"], .01+i*.001)


def wolf_medallion(parent, mats):
    ring = [(cos(i*tau/48)*.30, sin(i*tau/48)*.228, .304) for i in range(49)]
    trace(parent, "Oval chisel border", ring, mats["end"], .024)
    trace(parent, "Oval raised border", [(x,y,z+.02) for x,y,z in ring], mats["carving"], .013)
    head = [(-.190,.060),(-.186,.292),(-.101,.219),(0,.191),(.101,.219),(.186,.292),(.190,.060),
            (.203,-.025),(.132,-.079),(.100,-.159),(.046,-.214),(-.046,-.214),(-.100,-.159),
            (-.132,-.079),(-.203,-.025)]
    carved_profile(parent, "Central wolf · carved face", head, (.263,.373), mats["carving"], .17)
    for s in (-1, 1):
        def profile(name, coords, depth, mat):
            carved_profile(parent, name, [(s*x,y) for x,y in coords], depth, mats[mat], .14)
        profile("Central wolf · ear cut", [( .127,.140),(.148,.227),(.157,.136)], (.345,.379), "end")
        profile("Central wolf · eye cut", [(.034,.040),(.124,.097),(.172,.065),(.117,.023)], (.364,.395), "end")
        profile("Central wolf · brow", [(.021,.071),(.124,.127),(.173,.081),(.119,.092),(.049,.049)],
                (.370,.418), "carving")
        profile("Central wolf · jaw", [(.042,-.036),(.107,-.005),(.149,-.049),(.089,-.102),(.036,-.169)],
                (.365,.399), "wood")
        trace(parent, "Central wolf · muzzle cut", [(s*.044,-.079,.428),(s*.064,-.12,.423),(0,-.149,.420)], mats["end"], .012)
    carved_profile(parent, "Central wolf · nose bridge", [(-.04,.111),(.04,.111),(.051,-.040),(.087,-.094),
                   (.04,-.145),(-.04,-.145),(-.087,-.094),(-.051,-.040)], (.369,.437), mats["carving"], .18)
    carved_profile(parent, "Central wolf · nose", [(-.076,-.091),(.076,-.091),(.053,-.132),(0,-.150),
                   (-.053,-.132)], (.424,.448), mats["end"])


def carved_lintel(root, side, mats, ruined, active):
    suffix = "L" if side < 0 else "R"
    # Pivot at the post: the complete carvings, snow and iron move with the timber.
    support = side * 1.18
    group = empty("lintel_" + suffix + ("_broken" if ruined else ""), root, (support, 3.22, -.02))
    depth = (-.29,.254)
    if ruined:
        group.rotation_euler.y = .36 if side < 0 else -.27
        group.location.x += .12 if side < 0 else 0
        group.location.z -= .18 if side < 0 else .024
    outer = [(1.77,-.229),(1.84,-.164),(1.85,.150),(1.79,.213),(1.45,.241),(.89,.22),(.41,.233)]
    join = [(0,.219),(0,-.219)]
    if ruined:
        join = [(.09,.237),(-.037,.183),(.113,.139),(-.061,.076),(.084,.054),(.142,-.029),
                (.032,-.038),(.149,-.087),(.065,-.115),(.210,-.160),(.147,-.226)]
    outline = outer + join + [(.36,-.232),(.84,-.216),(1.33,-.242)]
    section = empty("Carved beam section", group, (-support, 0, 0))
    carved_profile(section, "Hewn oak lintel", [(side*x,y) for x,y in outline], depth, mats["wood"], .025)
    if ruined:
        for i, (x, y) in enumerate(join[1:-1]):
            trace(section, "Raw split oak fibers", [(side*(x+.16), y-.018, .251), (side*(x+.037),y,.266),
                  (side*x,y,.269)], mats["carving" if i%3 == 0 else "end"], .014)
    for j in range(3):
        y = -.173 + .165*j
        trace(section, "Chiselled grain on beam", [(side*x,y+.019*sin(x*8+j), .254) for x in (.19,.34,.67,.98,1.32,1.71)],
              mats["end"], .012)
    for phase in (-1, 1):
        path = []
        for i in range(46):
            t = i / 45
            wave = t * tau * 2.1
            path.append((side*(.276+.973*t), .07+phase*.064*sin(wave), .275+phase*.012*cos(wave)))
        trace(section, "Oak lintel interlace", path, mats["carving"], .018)
    wolf_end(section,side,mats)
    if ruined:
        if side > 0:
            badge = empty("Tilted wolf crest on split timber", section, (.33,.025,.00))
            wolf_medallion(badge, mats)
    else:
        if side > 0:
            wolf_medallion(section, mats)
    if active:
        inlay = empty("RunesLit lintel", section)
        for i in range(5):
            x = side * (.38 + i*.17)
            trace(inlay, "Low lintel rune", [(x-.027,-.138,.262),(x,-.075,.263),(x+.025,-.138,.262)], mats["rune"], .009)
    # The top bank has its own silhouette and hangs over the leading edge.
    length = 1.50 if ruined else 1.72
    profile = [(.27,.19),(.44,.23),(.60,.22),(.79,.253),(1.03,.247),(1.26,.27),(1.43,.252),(1.78,.208)]
    edge = [(side*x, y, .224+.042*sin(i*1.9)) for i,(x,y) in enumerate(profile)]
    edge += [(side*x,y, -.254+.037*sin(i*2.1)) for i,(x,y) in reversed(list(enumerate(profile)))]
    if ruined:
        edge = [(side*(.19 + (abs(x)-.19)*length/1.72),y,z) for x,y,z in edge]
    snowcap(section, "Rippled snow across lintel", edge, mats["snow"], .11)


def shutter_board(parent, index, mats, ruined):
    x = (index - 5.5) * .156
    w = .077
    base = -.01 if index % 3 else .026
    tips = (1.55, 1.82, 2.25, .58, .79, 2.08, 2.44, 2.51, 2.75, 2.68, 2.91, 2.95)
    top = tips[index] if ruined else 2.92 + .013*sin(index*1.37)
    lean = .10 if ruined and index in (1, 2) else .029*sin(index)
    back = -.088 - .032 * cos(index * 2)
    front = back + .168
    breakline = [(w+lean, top-.09),(.036+lean,top-.013),(.010+lean,top-.063),
                 (-.029+lean,top+.025),(-w+lean,top-.024)] if ruined else [(w+lean,top),(-w+lean,top+.014)]
    profile = [(-w,base),(w,base+.012),(w,top*.43),(w+lean*.8,top*.81),*breakline,(-w+lean*.27,top*.46)]
    if ruined and index in (3, 4, 8):
        profile[1:1] = [(-.016,base+.033),(-.011,base+.13),(.028,base+.019)]
    carved_profile(parent,"Split oak plank" if ruined else "Planed oak plank", [(x+u,y) for u,y in profile],
                   (back,front), mats["wood"], .030)
    if ruined and index in (0, 2, 5, 6, 10):
        trace(parent,"Open longitudinal split", [(x+lean-.015,top-.02,front+.004),
              (x+lean*.83-.029,top*.75,front+.009),(x+.012,top*.49,front+.004),
              (x+.001,top*.37,front+.002)], mats["end"], .015)


def refined_door(root, palette, mode):
    mats = dict(palette)
    mats["carving"] = material("Bleached oak cuts", (.24,.164,.109), .82)
    mats["edge"] = material("Chiselled stone high points", (.235,.245,.258), .88)
    mats["end"] = material("Dark endgrain and gouges", (.056,.034,.020), .92)
    dormant, active = mode == "dormant", mode == "awakened"
    for side in (-1, 1):
        gate_jamb(root, side, mats, dormant and side < 0, active)
        carved_lintel(root, side, mats, dormant, active)
    if active:
        return
    shutter = empty("GateShutter" if dormant else "EntranceShutter", root)
    for i in range(12):
        shutter_board(shutter, i, mats, dormant)
    straps = [(-.95,.95,.46),(-.95,.95,1.44),(-.95,.95,2.43)]
    if dormant:
        straps = [(-.92,-.38,.40),(.03,.94,.46),(.03,.94,1.34),(.19,.92,2.17)]
    for x1, x2, y in straps:
        carved_profile(shutter, "Pitted wrought-iron strap", [(x1,y-.043),(x2-.044,y-.04),(x2,y-.004),
                (x2-.029,y+.038),(x1+.025,y+.047)], (.083,.130), mats["metal"], .025)
        for i in range(max(2, round((x2-x1)*4))):
            x = x1 + .063 + (x2 - x1 - .125)*i/max(1, round((x2-x1)*4)-1)
            ridge(shutter, "Hammered nail head", [(x,y,.129),(x,y,.157),(x,y,.171)], [.032,.029,.015], mats["metal"], 7)
    if not dormant:
        return
    for i,(at,size) in enumerate([((-.50,-.014,.43),(1.35,.264,.92)),((.57,-.013,.45),(1.10,.227,.74)),
                                  ((.31,-.017,.92),(.79,.146,.48)),((-1.29,-.016,.83),(.88,.178,.59))]):
        drift(root,"Snow bank over shattered threshold",at,size,mats["snow"],14+i)
    debris = [(-1.57,.05,.76,.42,.13),(-.62,.09,.92,.63,.102),(.09,.05,.62,.31,.07),
              (.88,.12,.52,.38,.144),(-.19,.12,.30,.50,.12),(.41,.07,1.0,.21,.06)]
    for i,(x,y,z,length,width) in enumerate(debris):
        chip = empty("Fallen plank fragment",root,(x,y,z))
        chip.rotation_euler.z = (-.64, .32, 1.09, -.94, .45, .88)[i]
        chip.rotation_euler.x = .99 + .07*i
        carved_profile(chip,"Split end and weathered faces",[(-width,0),(width,.015),(width*.88,length*.73),
                       (width*1.08,length*.94),(.04,length*.89),(-.026,length*1.07),(-width*.85,length*.91)],
                       (-.045,.067),mats["wood"],.065)
    for at, size in [((-.70,-.004,.77),(.44,.136,.37)),((.30,-.009,.40),(.39,.138,.46))]:
        drift(root,"Snow partially buries debris",at,size,mats["snow"],32)


# Each course is a separate layout. The collapsed section still retains the
# foundation along the original collision path.
WALL_COURSES = (
    (((-.68,.52,.28),(-.12,.61,.33),(.54,.69,.32)),
     ((-.79,.27,.19),(-.42,.44,.24),(.05,.56,.25),(.61,.54,.24)),
     ((-.67,.42,.14),(-.19,.49,.19),(.30,.36,.14),(.67,.37,.17))),
    (((-.64,.58,.31),(-.05,.55,.28),(.53,.69,.35)),
     ((-.78,.31,.22),(-.24,.63,.25),(.37,.48,.21),(.72,.30,.20)),
     ((-.56,.60,.19),(.03,.49,.16),(.56,.54,.15))),
    (((-.60,.66,.32),(.038,.56,.28),(.637,.59,.32)),
     ((-.68,.48,.24),(-.22,.43,.16),(.61,.53,.22)),
     ((-.62,.51,.17),(.69,.35,.12))),
    (((-.71,.42,.26),(-.22,.55,.28),(.38,.62,.34),(.77,.23,.28)),
     ((-.64,.55,.20),(-.01,.62,.25),(.61,.57,.23)),
     ((-.71,.29,.14),(-.30,.49,.18),(.17,.34,.17),(.52,.29,.14))),
)


def dry_wall(root, mats, variant):
    rng = Random(89 + variant)
    for row, course in enumerate(WALL_COURSES[variant]):
        for i, (x, width, height) in enumerate(course):
            y = (-.03,.22,.415)[row] + rng.uniform(-.023,.027)
            z = rng.uniform(-.068,.067)
            _, rim = dressed_block(root,"Rough split fieldstone",(x,y,z),width,height,
                                    rng.uniform(.48,.66) - row*.031,mats["basalt"],18+variant*33+i+row*13)
            exposed = row == 2 or (variant == 2 and row and abs(x)<.40)
            if exposed and (i+variant)%4 != 3:
                snowcap(root,"Windward snow on broken courses",rim,mats["snow"],rng.uniform(.045,.082))
    for i, (x,z,w,h,d) in enumerate(((-.59,.28,.83,.094,.49),(.21,.30,.88,.125,.54),(.64,-.29,.73,.11,.54))):
        drift(root,"Snow drift caught by wall",(x,-.018,z),(w,h,d),mats["snow"],i+2*variant)
    for i in range(2):
        x = rng.uniform(-.75,.75)
        dressed_block(root,"Tumbled shale",(x,-.017,.29+rng.uniform(.1,.20)),.18+.076*i,.085+.04*i,.16,
                      mats["basalt"],variant*7+i)


def approach_seal(root, mats):
    glow = empty("ApproachSealGlow",root)
    dormant = empty("Approach paving inlays",root)
    for i, z in enumerate((-3.1,-1.58,0,1.52,3.04)):
        at = -.035*cos(i*1.35)
        dressed_block(root,"Weathered threshold sett",(at,-.058,z),.51,.089,.58,mats["stone"],51+i)
        coords = [(at-.12,.039,z+.10),(at,.04,z-.15),(at+.13,.039,z+.10),
                  (at+.066,.039,z+.04),(at-.064,.039,z+.04)]
        trace(dormant,"Groove worn into the threshold",coords,mats["cut"],.023)
        trace(glow,"Frozen runic inlay",[(x,y+.014,zz) for x,y,zz in coords],mats["rune"],.016)
