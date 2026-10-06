# Builds the hero as a 3D model in Blender and renders one sprite per pose.
# Run:  Blender --background --python art/hero_render.py -- <output_dir>
import bpy, sys, math
from math import sin, cos, pi
from mathutils import Vector

OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/hero'
U = 0.01          # one game pixel in Blender units
RES = 224         # pixels per frame (the game draws each frame 128 units square)

def lerp(a, b, t): return a + (b - a) * t
def ik(a, b, L, d):
    dx, dy = b[0] - a[0], b[1] - a[1]
    dist = min(math.hypot(dx, dy), 2 * L - .01) or .01
    h = math.sqrt(L * L - dist * dist / 4)
    return [a[0] + dx / 2 - dy / dist * h * d, a[1] + dy / 2 + dx / dist * h * d]

K = 1.17
def J(hip, neck, head, feet, hands, blade=None):
    """A key pose in game pixels (x forward, y down, feet at 0). hands[0] is the sword hand."""
    return dict(hip=list(hip), neck=list(neck), head=list(head), feet=[list(f) for f in feet], hands=[list(h) for h in hands], blade=blade)

def mix(a, b, t):
    t = t * t * (3 - 2 * t)                      # ease in and out, so moves start and land with weight
    L = lambda p, q: [lerp(p[0], q[0], t), lerp(p[1], q[1], t)]
    bl = None if a['blade'] is None or b['blade'] is None else lerp(a['blade'], b['blade'], t)
    return dict(hip=L(a['hip'], b['hip']), neck=L(a['neck'], b['neck']), head=L(a['head'], b['head']),
                feet=[L(a['feet'][i], b['feet'][i]) for i in (0, 1)], hands=[L(a['hands'][i], b['hands'][i]) for i in (0, 1)], blade=bl)

def track(keys, n):
    """keys: [(time 0..1, pose)], sampled into n frames."""
    out = []
    for i in range(n):
        u = i / (n - 1)
        k = 0
        while k < len(keys) - 2 and u > keys[k + 1][0]: k += 1
        (t0, p0), (t1, p1) = keys[k], keys[k + 1]
        out.append(mix(p0, p1, min(1, max(0, (u - t0) / max(1e-6, t1 - t0)))))
    return out

STANCE = J([-2, -27], [3, -53], [7, -67], [[-15, 0], [16, 0]], [[18, -36], [12, -50]], 0.5)

def run_pose(ph):
    bob = abs(sin(ph)) * 3
    return J([3, -30 + bob], [14, -54 + bob], [21, -66 + bob],
             [[sin(t) * 23, -max(0, cos(t)) * 18] for t in (ph, ph + pi)],
             [[11 + sin(t) * 20, -42 - max(0, sin(t)) * 10] for t in (ph + pi, ph + 2 * pi)])

ANIMS = []          # (name, [poses])
def add(name, poses): ANIMS.append((name, poses))

add('idle', [J([-2, -27 + sin(k / 6 * 2 * pi) * 1.2], [3, -53 + sin(k / 6 * 2 * pi) * 1.6], [7, -67 + sin(k / 6 * 2 * pi) * 1.8],
               [[-15, 0], [16, 0]], [[18, -36 + sin(k / 6 * 2 * pi + 1) * 1.5], [12, -50 + sin(k / 6 * 2 * pi) * 1.5]], 0.5) for k in range(6)])
add('run', [run_pose(k * 2 * pi / 12) for k in range(12)])
add('jump', [J([0, -31], [4, -58], [7, -72], [[-14, -13], [11, -4]], [[-17, -70], [20, -66]])])
add('fall', [J([0, -31], [0, -58], [0, -73], [[-13, -2], [15, -10]], [[-23, -62], [23, -60]])])
add('land', [J([0, -18], [6, -40], [9, -53], [[-14, 0], [14, 0]], [[-16, -22], [20, -24]])])
add('dash', [J([-4, -24], [17, -40], [29, -47], [[-27, -9], [-10, -2]], [[38, -36], [-9, -34]])])
add('surf', [J([-2, -23], [5, -48], [9, -62], [[-15, 0], [15, 0]], [[-24, -44], [27, -50]])])
add('throw', [J([1, -30], [6, -57], [10, -71], [[-15, 0], [14, 0]], [[30, -62], [-13, -38]])])
add('hurt', [J([-4, -29], [-10, -54], [-16, -66], [[-8, 0], [14, -4]], [[-22, -48], [6, -58]])])
# three-hit combo: wind-up, strike with a stepping lunge, held follow-through, return to stance
add('atk1', track([(0, STANCE),
                   (.22, J([-5, -27], [-2, -53], [1, -67], [[-15, 0], [15, 0]], [[-16, -50], [6, -46]], -2.6)),
                   (.5, J([6, -26], [15, -50], [21, -63], [[-18, 0], [24, 0]], [[34, -44], [2, -40]], 0.15)),
                   (.78, J([7, -26], [15, -50], [20, -63], [[-18, 0], [24, 0]], [[26, -30], [0, -40]], 0.95)),
                   (1, STANCE)], 7))
add('atk2', track([(0, STANCE),
                   (.22, J([-3, -24], [1, -49], [4, -63], [[-16, 0], [14, 0]], [[8, -20], [4, -44]], 1.9)),
                   (.5, J([5, -28], [12, -54], [17, -68], [[-16, 0], [22, 0]], [[30, -60], [0, -42]], -0.9)),
                   (.78, J([5, -29], [11, -55], [15, -69], [[-16, 0], [22, 0]], [[18, -76], [-2, -44]], -1.7)),
                   (1, STANCE)], 7))
add('atk3', track([(0, STANCE),
                   (.3, J([-3, -30], [-1, -57], [1, -71], [[-12, 0], [12, -7]], [[-4, -82], [-8, -77]], -1.95)),
                   (.52, J([8, -21], [20, -42], [27, -53], [[-22, 0], [28, 0]], [[40, -30], [34, -28]], 0.45)),
                   (.82, J([8, -20], [20, -41], [27, -52], [[-22, 0], [28, 0]], [[38, -22], [33, -22]], 0.7)),
                   (1, STANCE)], 8))

def solve(j):
    hip, neck, head = [j['hip'][0], j['hip'][1] * K], [j['neck'][0], j['neck'][1] * K], [j['head'][0], j['head'][1] * K + 2]
    feet = [[f[0], f[1] * K] for f in j['feet']]; hands = [[h[0], h[1] * K] for h in j['hands']]
    sh = [neck[0], neck[1] + 4]
    return dict(hip=hip, neck=neck, head=head, sh=sh, feet=feet, hands=hands, blade=j['blade'],
                knees=[ik(hip, f, 19.5, -1) for f in feet], elbows=[ik(sh, h, 15.5, 1) for h in hands])

FRAMES = [solve(p) for _, ps in ANIMS for p in ps]
YAW = math.radians(20)
def anchor(pt, depth): return [round(pt[0] * math.cos(YAW) - depth * math.sin(YAW), 1), round(pt[1], 1)]
META = dict(size=224, cols=8, anim={}, frames=[dict(h=anchor(f['head'], -1), p=anchor(f['hands'][0], -12), b=f['blade']) for f in FRAMES])
_i = 0
for name, ps in ANIMS: META['anim'][name] = [_i, len(ps)]; _i += len(ps)

def mat(name, v, rough=.28, emit=.015):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (v, v, v, 1)
    b.inputs['Roughness'].default_value = rough
    for key in ('Emission Color', 'Emission'):
        if key in b.inputs: b.inputs[key].default_value = (v, v, v, 1)
    if 'Emission Strength' in b.inputs: b.inputs['Emission Strength'].default_value = emit
    return m

def P(pt, depth=0):            # game (x right, y down) -> Blender (X right, Z up, Y depth)
    return Vector((pt[0] * U, depth * U, -pt[1] * U))

def finish(m):
    o = bpy.context.object; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o

def ball(pt, r, m, depth=0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r * U, location=P(pt, depth), segments=24, ring_count=12); return finish(m)

def bone(a, b, r1, r2, m, depth=0):
    A, B = P(a, depth), P(b, depth); d = B - A
    if d.length < 1e-6: return
    bpy.ops.mesh.primitive_cone_add(radius1=r1 * U, radius2=r2 * U, depth=d.length, vertices=24, location=(A + B) / 2)
    o = finish(m); o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized()); return o

def build(j, near, far):
    # muscular build: heavy fists and forearms, broad chest tapering to a narrow waist, solid ball head
    for side, m, dz in ((1, far, 8), (0, near, -8)):
        f, k, h, e = j['feet'][side], j['knees'][side], j['hands'][side], j['elbows'][side]
        bone(j['hip'], k, 5.4, 4.0, m, dz * .7); ball(k, 4.0, m, dz * .7); bone(k, f, 4.2, 3.0, m, dz * .7)
        bone([f[0] - 3, f[1] - 2.8], [f[0] + 10, f[1] - 2.8], 3.6, 2.8, m, dz * .7); ball([f[0] - 3, f[1] - 2.8], 3.6, m, dz * .7); ball([f[0] + 10, f[1] - 2.8], 2.8, m, dz * .7)
        sp = [j['sh'][0], j['sh'][1] + 1]
        ball(sp, 6.4, m, dz * 1.5); bone(sp, e, 4.8, 3.6, m, dz * 1.5); ball(e, 3.6, m, dz * 1.5)
        bone(e, h, 3.4, 4.3, m, dz * 1.5); ball(h, 6.0, m, dz * 1.5)                      # forearm flares into a big fist
    sh, hip = j['sh'], j['hip']
    t = bone(hip, sh, 5.6, 12.5, near); t.scale = (1, .8, 1)
    ch = [lerp(hip[0], sh[0], .72), lerp(hip[1], sh[1], .72)]
    for dz in (-4.5, 4.5):
        c = ball(ch, 7.6, near, dz); c.scale = (1, .8, .85)                                # chest
    ball(hip, 5.8, near); ball(j['neck'], 4.2, near)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=12.2 * U, location=P(j['head'], -1), segments=40, ring_count=20); finish(near)

sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = 64; sc.cycles.use_denoising = False
try: sc.cycles.device = 'CPU'
except Exception: pass
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = RES; sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'
try: sc.view_settings.look = 'None'
except Exception: pass
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (.035, .035, .045, 1)

for i, jf in enumerate(FRAMES):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in list(blk): blk.remove(d)
    near, far = mat('near', .9), mat('far', .66)
    build(jf, near, far)
    cam = bpy.data.cameras.new('c'); cam.type = 'ORTHO'; cam.ortho_scale = 128 * U
    co = bpy.data.objects.new('c', cam); sc.collection.objects.link(co)
    yaw = YAW; co.location = (-math.sin(yaw) * 5, -math.cos(yaw) * 5, 52 * U); co.rotation_euler = (pi / 2, 0, -yaw); sc.camera = co
    for nm, energy, rot in (('key', 2.6, (math.radians(62), 0, math.radians(-48))),
                            ('rim', 6.0, (math.radians(-62), 0, math.radians(140))),
                            ('fill', .35, (math.radians(80), 0, math.radians(70)))):
        l = bpy.data.lights.new(nm, 'SUN'); l.energy = energy
        lo = bpy.data.objects.new(nm, l); lo.rotation_euler = rot; sc.collection.objects.link(lo)
    sc.render.filepath = f'{OUT}/f{i:02d}.png'
    bpy.ops.render.render(write_still=True)
import json; open(f'{OUT}/meta.json', 'w').write(json.dumps(META)); print('HERO_FRAMES', len(FRAMES))
