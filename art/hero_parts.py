# Renders the hero's body parts in Blender. The game assembles them on a skeleton at run time,
# so every joint moves continuously and actions blend into each other.
# Run:  Blender --background --python art/hero_parts.py -- <output_dir>
import bpy, sys, math
from math import pi
from mathutils import Vector
OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/parts'
U, TILE, PPU = 0.01, 192, 4.8            # Blender units per game pixel, tile size, rendered pixels per game pixel
CY = (TILE / 2 - 40) / PPU               # the top joint sits 40 px below the tile's top edge

def mat(v):
    m = bpy.data.materials.new('m'); m.use_nodes = True; b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (v, v, v, 1); b.inputs['Roughness'].default_value = .28
    for key in ('Emission Color', 'Emission'):
        if key in b.inputs: b.inputs[key].default_value = (v, v, v, 1)
    if 'Emission Strength' in b.inputs: b.inputs['Emission Strength'].default_value = .015
    return m
def P(pt, d=0): return Vector((pt[0] * U, d * U, -pt[1] * U))
def fin(m):
    o = bpy.context.object; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o
def ball(pt, r, m, d=0, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r * U, location=P(pt, d), segments=seg, ring_count=seg // 2); return fin(m)
def bone(a, b, r1, r2, m, d=0):
    A, B = P(a, d), P(b, d); v = B - A
    bpy.ops.mesh.primitive_cone_add(radius1=r1 * U, radius2=r2 * U, depth=v.length, vertices=32, location=(A + B) / 2)
    o = fin(m); o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(v.normalized()); return o

def thigh(m): bone([0, 0], [0, 19.5], 5.6, 4.1, m); ball([0, 0], 5.6, m); ball([0, 19.5], 4.1, m)
def shin(m):  bone([0, 0], [0, 19.5], 4.3, 3.0, m); ball([0, 0], 4.1, m); ball([0, 19.5], 3.0, m)
def foot(m):  bone([-11, CY], [3, CY], 3.7, 2.9, m); ball([-11, CY], 3.7, m); ball([3, CY], 2.9, m)          # ankle at tile x = 60
def uarm(m):  ball([0, 0], 6.5, m); bone([0, 0], [0, 15.5], 4.9, 3.7, m); ball([0, 15.5], 3.7, m)
def farm(m):  ball([0, 0], 3.7, m); bone([0, 0], [0, 15.5], 3.5, 4.4, m); ball([0, 16.5], 6.2, m)            # forearm flares into a fist
def torso(m):
    t = bone([0, 26], [0, 0], 5.8, 12.6, m); t.scale = (1, .8, 1)        # 26 px from shoulder line to hip; the game stretches it per pose
    for d in (-4.5, 4.5):
        c = ball([0, 7.3], 7.8, m, d); c.scale = (1, .8, .85)
    ball([0, 26], 5.6, m); ball([0, -4], 4.3, m)
def head(m):  ball([0, CY], 12.3, m, 0, 48)

sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = 96; sc.cycles.use_denoising = False
sc.render.film_transparent = True; sc.render.resolution_x = sc.render.resolution_y = TILE; sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'; sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (.035, .035, .045, 1)
for i, fn in enumerate([thigh, shin, foot, uarm, farm, torso, head]):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    fn(mat(.9))
    cam = bpy.data.cameras.new('c'); cam.type = 'ORTHO'; cam.ortho_scale = TILE / PPU * U
    co = bpy.data.objects.new('c', cam); sc.collection.objects.link(co); co.location = (0, -5, -CY * U); co.rotation_euler = (pi / 2, 0, 0); sc.camera = co
    for energy, rot in ((2.6, (62, 0, -48)), (6.0, (-62, 0, 140)), (.35, (80, 0, 70))):
        l = bpy.data.lights.new('s', 'SUN'); l.energy = energy; lo = bpy.data.objects.new('s', l); lo.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(lo)
    sc.render.filepath = f'{OUT}/p{i}.png'; bpy.ops.render.render(write_still=True)
print('PARTS_DONE')
