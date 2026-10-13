#!/usr/bin/env python3
"""Agrandit une map générée (×4 par Real-ESRGAN, puis ramenée au facteur voulu) sans PyTorch : les poids .pth sont
lus directement et le réseau RRDBNet est reconstruit en ONNX (onnxruntime, CPU, par tuiles).

Usage : python3 tools/art/upscale.py <modele.pth> <source.png> <sortie.png> [facteur=2]
Modèle conseillé : RealESRGAN_x4plus.pth (github.com/xinntao/Real-ESRGAN, releases v0.1.0), non versionné.
Dépendances : pip install onnx onnxruntime numpy pillow. Compter ~10 min pour une map de 1254 px sur 4 cœurs.
"""
import collections
import pickle
import sys
import time
import zipfile
import numpy as np
import onnxruntime as ort
from onnx import helper, TensorProto, numpy_helper
from PIL import Image


def load_pth(path):
    zf = zipfile.ZipFile(path)
    prefix = zf.namelist()[0].split('/')[0]
    class Unp(pickle.Unpickler):
        def find_class(self, mod, name):
            if name == '_rebuild_tensor_v2':
                def rebuild(storage, offset, size, stride, *a):
                    return np.lib.stride_tricks.as_strided(storage[offset:], shape=size, strides=[s * storage.itemsize for s in stride]).copy()
                return rebuild
            if mod == 'collections' and name == 'OrderedDict':
                return collections.OrderedDict
            if mod.startswith('torch') and name.endswith('Storage'):
                return name
            # Fichier de poids = données : rien d'autre n'est chargé (un .pth piégé ne peut rien exécuter).
            raise pickle.UnpicklingError(f"objet refusé dans le fichier de poids : {mod}.{name}")
        def persistent_load(self, pid):
            _, kind, key, loc, numel = pid
            dt = {'FloatStorage': np.float32, 'HalfStorage': np.float16}[kind if isinstance(kind, str) else kind]
            return np.frombuffer(zf.read(f'{prefix}/data/{key}'), dtype=dt)
    sd = Unp(zf.open(f'{prefix}/data.pkl')).load()
    if 'params_ema' in sd: sd = sd['params_ema']
    elif 'params' in sd: sd = sd['params']
    return {k: np.asarray(v, dtype=np.float32) for k, v in sd.items()}

def build(sd, nb):
    nodes, inits = [], []
    cnt = [0]
    def name(p): cnt[0] += 1; return f'{p}_{cnt[0]}'
    def conv(x, key):
        w, b = sd[key + '.weight'], sd[key + '.bias']
        inits.extend([numpy_helper.from_array(w, key + '.w'), numpy_helper.from_array(b, key + '.b')])
        o = name('c'); nodes.append(helper.make_node('Conv', [x, key + '.w', key + '.b'], [o], pads=[1, 1, 1, 1])); return o
    def lrelu(x):
        o = name('l'); nodes.append(helper.make_node('LeakyRelu', [x], [o], alpha=0.2)); return o
    def cat(xs):
        o = name('cat'); nodes.append(helper.make_node('Concat', xs, [o], axis=1)); return o
    def axpy(x, y, a):  # x*a + y
        c = name('k'); inits.append(numpy_helper.from_array(np.array(a, np.float32), c))
        m = name('m'); nodes.append(helper.make_node('Mul', [x, c], [m]))
        o = name('a'); nodes.append(helper.make_node('Add', [m, y], [o])); return o
    def add(x, y):
        o = name('a'); nodes.append(helper.make_node('Add', [x, y], [o])); return o
    def up(x):
        s = name('s'); inits.append(numpy_helper.from_array(np.array([1, 1, 2, 2], np.float32), s))
        o = name('u'); nodes.append(helper.make_node('Resize', [x, '', s], [o], mode='nearest')); return o
    feat = conv('in', 'conv_first')
    x = feat
    for i in range(nb):
        r_in = x
        for j in (1, 2, 3):
            p = f'body.{i}.rdb{j}'
            x1 = lrelu(conv(x, p + '.conv1'))
            x2 = lrelu(conv(cat([x, x1]), p + '.conv2'))
            x3 = lrelu(conv(cat([x, x1, x2]), p + '.conv3'))
            x4 = lrelu(conv(cat([x, x1, x2, x3]), p + '.conv4'))
            x5 = conv(cat([x, x1, x2, x3, x4]), p + '.conv5')
            x = axpy(x5, x, 0.2)
        x = axpy(x, r_in, 0.2)
    feat = add(feat, conv(x, 'conv_body'))
    feat = lrelu(conv(up(feat), 'conv_up1'))
    feat = lrelu(conv(up(feat), 'conv_up2'))
    out = conv(lrelu(conv(feat, 'conv_hr')), 'conv_last')
    nodes.append(helper.make_node('Identity', [out], ['out']))
    g = helper.make_graph(nodes, 'rrdb', [helper.make_tensor_value_info('in', TensorProto.FLOAT, [1, 3, None, None])],
                          [helper.make_tensor_value_info('out', TensorProto.FLOAT, [1, 3, None, None])], inits)
    return helper.make_model(g, opset_imports=[helper.make_opsetid('', 17)], ir_version=9)

def run(model_path, src, dst, tile=192, pad=12, factor=4):
    sd = load_pth(model_path)
    nb = len({k.split('.')[1] for k in sd if k.startswith('body.')})
    sess = ort.InferenceSession(build(sd, nb).SerializeToString(), providers=['CPUExecutionProvider'])
    img = np.asarray(Image.open(src).convert('RGB'), np.float32) / 255.0
    h, w, _ = img.shape
    out = np.zeros((h * 4, w * 4, 3), np.float32)
    t = time.time()
    for y in range(0, h, tile):
        for x in range(0, w, tile):
            y0, x0 = max(y - pad, 0), max(x - pad, 0)
            y1, x1 = min(y + tile + pad, h), min(x + tile + pad, w)
            inp = img[y0:y1, x0:x1].transpose(2, 0, 1)[None]
            res = sess.run(None, {'in': inp})[0][0].transpose(1, 2, 0)
            ty, tx = min(tile, h - y), min(tile, w - x)
            oy, ox = (y - y0) * 4, (x - x0) * 4
            out[y * 4:(y + ty) * 4, x * 4:(x + tx) * 4] = res[oy:oy + ty * 4, ox:ox + tx * 4]
        print(f'ligne {y} ({time.time() - t:.0f} s)', flush=True)
    result = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8))
    if factor != 4:
        result = result.resize((w * factor, h * factor), Image.LANCZOS)
    result.save(dst)

if __name__ == '__main__':
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    run(*sys.argv[1:4], factor=int(sys.argv[4]) if len(sys.argv) > 4 else 2)
