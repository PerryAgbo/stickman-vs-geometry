# Builds the hero as a 3D model in Blender and renders one sprite per pose.
# Run:  Blender --background --python art/hero_render.py -- <output_dir>
import bpy, sys, math
from math import sin, cos, pi
from mathutils import Vector

OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/hero'
U = 0.01          # one game pixel in Blender units
RES = 256         # pixels per frame (game draws 128 units, so 2x)

def lerp(a, b, t): return a + (b - a) * t
def ik(a, b, L, d):
    dx, dy = b[0] - a[0], b[1] - a[1]
    dist = min(math.hypot(dx, dy), 2 * L - .01) or .01
    h = math.sqrt(L * L - dist * dist / 4)
    return [a[0] + dx / 2 - dy / dist * h * d, a[1] + dy / 2 + dx / dist * h * d]

def pose(name, ph=0, swing=0):
    hip, neck, head = [0, -31], [0, -58], [0, -73]
    if name == 'run':
        bob = abs(sin(ph)) * 2.5
        hip, neck, head = [2, -31 + bob], [11, -56 + bob], [17, -69 + bob]
        feet = [[sin(t) * 22, -max(0, cos(t)) * 17] for t in (ph, ph + pi)]
        hands = [[9 + sin(t) * 19, -43 - max(0, sin(t)) * 9] for t in (ph + pi, ph + 2 * pi)]
    elif name == 'jump':
        neck, head = [4, -58], [7, -72]; feet = [[-14, -13], [11, -4]]; hands = [[-17, -70], [20, -66]]
    elif name == 'fall':
        feet = [[-13, -2], [15, -10]]; hands = [[-23, -62], [23, -60]]
    elif name == 'surf':
        hip, neck, head = [-2, -23], [5, -48], [9, -62]; feet = [[-15, 0], [15, 0]]; hands = [[-24, -44], [27, -50]]
    elif name == 'throw':
        hip, neck, head = [1, -30], [6, -57], [10, -71]; feet = [[-15, 0], [14, 0]]; hands = [[-13, -38], [30, -62]]
    elif name == 'slash':
        a = lerp(-2.3, .9, swing)
        hip, neck, head = [2, -30], [8, -56], [13, -70]; feet = [[-16, 0], [17, 0]]
        hands = [[8 + cos(a) * 17, -52 + sin(a) * 15], [-11, -38]]
    elif name == 'dash':
        hip, neck, head = [-4, -24], [17, -40], [29, -47]; feet = [[-27, -9], [-10, -2]]; hands = [[38, -36], [-9, -34]]
    else:
        feet = [[-10, 0], [10, 0]]; hands = [[-14, -35], [14, -35]]
    K = 1.17
    for q in [hip, neck] + feet + hands: q[1] *= K
    head[1] = head[1] * K + 2
    sh = [neck[0], neck[1] + 4]
    return dict(hip=hip, neck=neck, head=head, sh=sh, feet=feet, hands=hands,
                knees=[ik(hip, f, 19.5, -1) for f in feet], elbows=[ik(sh, h, 15.5, 1) for h in hands])

FRAMES = [('idle', 0, 0)] + [('run', k * 2 * pi / 8, 0) for k in range(8)] + \
         [('jump', 0, 0), ('fall', 0, 0), ('surf', 0, 0), ('throw', 0, 0), ('dash', 0, 0)] + \
         [('slash', 0, s) for s in (0, .25, .5, .75, 1)]

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
    for side, m, dz in ((1, far, 7), (0, near, -7)):
        f, k, h, e = j['feet'][side], j['knees'][side], j['hands'][side], j['elbows'][side]
        bone(j['hip'], k, 4.2, 3.4, m, dz); ball(k, 3.4, m, dz); bone(k, f, 3.4, 2.7, m, dz)
        bone([f[0] - 2, f[1] - 2.4], [f[0] + 9, f[1] - 2.4], 3.0, 2.4, m, dz); ball([f[0] - 2, f[1] - 2.4], 3.0, m, dz); ball([f[0] + 9, f[1] - 2.4], 2.4, m, dz)
        sp = [j['sh'][0] + (0 if side else 0), j['sh'][1]]
        ball(sp, 4.6, m, dz * 1.25); bone(sp, e, 3.6, 2.9, m, dz * 1.25); ball(e, 2.9, m, dz * 1.25); bone(e, h, 2.9, 2.4, m, dz * 1.25); ball(h, 3.7, m, dz * 1.25)
    t = bone(j['hip'], j['sh'], 5.2, 10.5, near); t.scale = (1, .62, 1)       # V-shaped torso
    ball(j['hip'], 5.2, near); ball(j['neck'], 3.4, near)
    bpy.ops.mesh.primitive_torus_add(major_radius=10.6 * U, minor_radius=2.9 * U, major_segments=48, minor_segments=16,
                                     location=P(j['head'], -2), rotation=(pi / 2, 0, 0)); finish(near)

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

for i, (name, ph, sw) in enumerate(FRAMES):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in list(blk): blk.remove(d)
    near, far = mat('near', .92), mat('far', .58)
    build(pose(name, ph, sw), near, far)
    cam = bpy.data.cameras.new('c'); cam.type = 'ORTHO'; cam.ortho_scale = 128 * U
    co = bpy.data.objects.new('c', cam); sc.collection.objects.link(co)
    co.location = (0, -5, 52 * U); co.rotation_euler = (pi / 2, 0, 0); sc.camera = co
    for nm, energy, rot in (('key', 2.6, (math.radians(62), 0, math.radians(-48))),
                            ('rim', 6.0, (math.radians(-62), 0, math.radians(140))),
                            ('fill', .35, (math.radians(80), 0, math.radians(70)))):
        l = bpy.data.lights.new(nm, 'SUN'); l.energy = energy
        lo = bpy.data.objects.new(nm, l); lo.rotation_euler = rot; sc.collection.objects.link(lo)
    sc.render.filepath = f'{OUT}/f{i:02d}.png'
    bpy.ops.render.render(write_still=True)
print('HERO_FRAMES', len(FRAMES))
