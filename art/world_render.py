# Renders the enemy sprites and the backdrop scenes in Blender.
# Run:  Blender --background --python art/world_render.py -- <output_dir>
import bpy, sys, math, random
from math import pi, sin, cos, radians
from mathutils import Vector, Euler

OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/world'
sc = bpy.context.scene

def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in list(blk): blk.remove(d)

def setup(w, h, samples, transparent, world=(0, 0, 0)):
    sc.render.engine = 'CYCLES'; sc.cycles.samples = samples
    try: sc.cycles.use_denoising = True
    except Exception: pass
    sc.render.film_transparent = transparent
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = w, h, 100
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA' if transparent else 'RGB'
    sc.view_settings.view_transform = 'Standard'
    wd = sc.world or bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True
    wd.node_tree.nodes['Background'].inputs[0].default_value = (*world, 1)

def pbr(name, col, metal=.9, rough=.25, emit=None, strength=0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        for key in ('Emission Color', 'Emission'):
            if key in b.inputs: b.inputs[key].default_value = (*emit, 1)
        if 'Emission Strength' in b.inputs: b.inputs['Emission Strength'].default_value = strength
    return m

T = 1 / math.sqrt(2)
SHAPES = {
    'tetra': ([(1, 0, -T), (-1, 0, -T), (0, 1, T), (0, -1, T)], [(0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)]),
    'octa': ([(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1.35), (0, 0, -1.35)],
             [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]),
    'dart': ([(-1.5, 0, 0), (.9, .75, 0), (.9, -.38, .65), (.9, -.38, -.65), (.35, 0, 0)],
             [(0, 1, 2), (0, 2, 3), (0, 3, 1), (4, 2, 1), (4, 3, 2), (4, 1, 3)]),
}

def solid(kind, loc=(0, 0, 0), scale=1, rot=(0, 0, 0), body=None, edge=None, wire=.035):
    if kind == 'cube': bpy.ops.mesh.primitive_cube_add(size=1.45)
    elif kind == 'ico': bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
    else:
        v, f = SHAPES[kind]; me = bpy.data.meshes.new(kind); me.from_pydata(v, [], f); me.update()
        o = bpy.data.objects.new(kind, me); sc.collection.objects.link(o); bpy.context.view_layer.objects.active = o
    o = bpy.context.view_layer.objects.active
    o.location, o.scale, o.rotation_euler = loc, (scale,) * 3, rot
    o.data.materials.append(body)
    if edge:
        w = o.copy(); w.data = o.data.copy(); sc.collection.objects.link(w)
        w.data.materials.clear(); w.data.materials.append(edge)
        md = w.modifiers.new('wire', 'WIREFRAME'); md.thickness = wire; md.use_replace = True
    return o

def sun(energy, rot, col=(1, 1, 1)):
    l = bpy.data.lights.new('s', 'SUN'); l.energy = energy; l.color = col
    o = bpy.data.objects.new('s', l); o.rotation_euler = [radians(a) for a in rot]; sc.collection.objects.link(o)

def camera(loc, look, lens=35, ortho=None):
    cam = bpy.data.cameras.new('c'); o = bpy.data.objects.new('c', cam); sc.collection.objects.link(o)
    if ortho: cam.type = 'ORTHO'; cam.ortho_scale = ortho
    else: cam.lens = lens
    cam.clip_end = 500
    o.location = loc; o.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); sc.camera = o

def grid_floor(z, size, cuts, mat_line, mat_floor):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z)); bpy.context.object.data.materials.append(mat_floor)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=cuts, y_subdivisions=cuts, size=size, location=(0, 0, z + .01))
    g = bpy.context.object; g.data.materials.append(mat_line)
    md = g.modifiers.new('wire', 'WIREFRAME'); md.thickness = .035; md.use_replace = True

# ---------------- enemy sprites: 5 kinds x 8 rotation frames, 160 px ----------------
KINDS = [('tetra', 1.25), ('cube', 1.0), ('octa', 1.0), ('ico', 1.12), ('dart', 1.0)]
for ki, (kind, s) in enumerate(KINDS):
    for fr in range(8):
        reset(); setup(160, 160, 40, True, (.02, .02, .03))
        body = pbr('body', (.05, .06, .09), .95, .22)
        edge = pbr('edge', (1, 1, 1), 0, .5, (1, 1, 1), 7)
        a = fr / 8 * 2 * pi
        rot = (a, 0, 0) if kind == 'dart' else (radians(-18) if kind == 'tetra' else radians(28), radians(12 if kind != 'tetra' else 0), a / (3 if kind == 'tetra' else 4 if kind == 'cube' else 1))
        if kind in ('octa', 'ico'): rot = (radians(15), 0, a if kind == 'octa' else a / 5)
        solid(kind, (0, 0, 0), s, rot, body, edge, .05 if kind != 'ico' else .04)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=.2 if kind != 'ico' else .26, location=(0, 0, 0))
        bpy.context.object.data.materials.append(pbr('core', (1, .8, .2), 0, .4, (1, .78, .18), 14))
        camera((0, -6, 0), (0, 0, 0), ortho=3.3)
        sun(3.5, (55, 0, -35)); sun(5, (-60, 0, 150), (.6, .8, 1))
        sc.render.filepath = f'{OUT}/foe_{ki}_{fr}.png'; bpy.ops.render.render(write_still=True)

# ---------------- backdrops, 960 x 540 ----------------
def scatter(n, seed, edge_col, strength, spread=(46, 26), depth=(14, 120), body_col=(.03, .035, .05)):
    rnd = random.Random(seed); body = pbr('b', body_col, .9, .3)
    for i in range(n):
        d = rnd.uniform(*depth); k = d / depth[1]
        e = pbr('e%d' % i, edge_col, 0, .5, edge_col, strength * (1 - k * .75))
        solid(rnd.choice(['tetra', 'cube', 'octa', 'ico', 'ico']), (rnd.uniform(-spread[0], spread[0]) * (.4 + k), d, rnd.uniform(-spread[1], spread[1]) * (.4 + k)),
              rnd.uniform(1.2, 4.5) * (.6 + k * 1.6), (rnd.uniform(0, 6), rnd.uniform(0, 6), rnd.uniform(0, 6)), body, e, .03)

def bg(name, build, world=(0, 0, 0)):
    reset(); setup(960, 540, 56, False, world); build()
    sc.render.filepath = f'{OUT}/bg_{name}.png'; bpy.ops.render.render(write_still=True)

def b_void():
    scatter(70, 3, (.75, .85, 1), 3.2); camera((0, -6, 0), (0, 30, 0), 30); sun(1.2, (60, 0, -30), (.6, .7, 1))
def b_lab():
    grid_floor(-7, 420, 70, pbr('l', (.2, .6, 1), 0, .5, (.25, .6, 1), 2.6), pbr('f', (.01, .012, .02), .6, .25))
    scatter(16, 9, (.4, .7, 1), 1.6, (60, 14), (40, 150)); camera((0, -6, 1.5), (0, 40, 2), 28); sun(.8, (50, 0, 20), (.6, .8, 1))
def b_arena():
    grid_floor(-6, 300, 44, pbr('l', (1, .7, .25), 0, .5, (1, .65, .2), 2.2), pbr('f', (.02, .015, .01), .8, .18))
    col = pbr('c', (.05, .04, .03), .9, .3); edge = pbr('ce', (1, .8, .4), 0, .5, (1, .75, .3), 3.5)
    for i in range(9):
        for sx in (-1, 1):
            bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=2.2, depth=60, location=(sx * (16 + i * 1.5), 18 + i * 16, 22)); o = bpy.context.object; o.data.materials.append(col)
            w = o.copy(); w.data = o.data.copy(); sc.collection.objects.link(w); w.data.materials.clear(); w.data.materials.append(edge)
            md = w.modifiers.new('wire', 'WIREFRAME'); md.thickness = .12; md.use_replace = True
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 190, 26), rotation=(pi / 2, 0, 0)); bpy.context.object.data.materials.append(pbr('glow', (1, .7, .3), 0, .5, (1, .62, .22), 5))
    camera((0, -8, 1), (0, 40, 7), 26); sun(.6, (50, 0, 0), (1, .8, .5))
def b_sky():
    bpy.ops.mesh.primitive_plane_add(size=1600, location=(0, 0, -14)); bpy.context.object.data.materials.append(pbr('sea', (.02, .05, .09), .2, .08))
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 420, 2), rotation=(pi / 2, 0, 0)); o = bpy.context.object; o.scale = (900, 26, 1); o.data.materials.append(pbr('hz', (.3, .8, 1), 0, .5, (.25, .75, 1), 9))
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 430, 70), rotation=(pi / 2, 0, 0)); o = bpy.context.object; o.scale = (900, 110, 1); o.data.materials.append(pbr('hz2', (.05, .1, .3), 0, .5, (.03, .08, .28), 3))
    scatter(26, 21, (.7, .9, 1), 2.4, (70, 18), (40, 200), (.04, .06, .1)); camera((0, -6, 2), (0, 60, 5), 24); sun(1.4, (70, 0, 10), (.6, .8, 1))
def b_gold():
    scatter(46, 14, (1, .78, .25), 3.4, (44, 24), (16, 110), (.25, .17, .04)); camera((0, -6, 0), (0, 30, 0), 30); sun(2.2, (55, 0, -25), (1, .8, .5)); sun(2.5, (-50, 0, 160), (1, .6, .2))

for nm, fn, wc in (('void', b_void, (0, 0, .004)), ('lab', b_lab, (0, .002, .006)), ('arena', b_arena, (.004, .002, 0)), ('sky', b_sky, (.004, .01, .03)), ('gold', b_gold, (.012, .007, 0))):
    bg(nm, fn, wc)
print('WORLD_DONE')
