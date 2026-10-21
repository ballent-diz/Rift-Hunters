"""Convertit RealESRGAN_x4plus.pth (RRDBNet) en ONNX sans PyTorch."""
import pickle
import sys
import zipfile

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper


def load_pth(path):
    z = zipfile.ZipFile(path)
    prefix = z.namelist()[0].split("/")[0]

    class Storage:
        def __init__(self, dtype):
            self.dtype = dtype

    class U(pickle.Unpickler):
        def find_class(self, mod, name):
            if name == "_rebuild_tensor_v2":
                def rebuild(storage, offset, size, stride, *rest):
                    data = np.frombuffer(z.read(f"{prefix}/data/{storage[2]}"), dtype=np.float32)
                    return np.lib.stride_tricks.as_strided(data[offset:], shape=size,
                                                           strides=[s * 4 for s in stride]).copy()
                return rebuild
            if name.endswith("Storage"):
                return name
            if mod == "collections" and name == "OrderedDict":
                import collections
                return collections.OrderedDict
            return super().find_class(mod, name)

        def persistent_load(self, pid):
            return pid

    obj = U(z.open(f"{prefix}/data.pkl")).load()
    return obj.get("params_ema") or obj.get("params") or obj


def build(weights, out):
    nodes, inits = [], []
    counter = [0]

    def name(base):
        counter[0] += 1
        return f"{base}_{counter[0]}"

    def conv(x, key):
        w, b = weights[key + ".weight"], weights[key + ".bias"]
        inits.append(numpy_helper.from_array(w, key + ".weight"))
        inits.append(numpy_helper.from_array(b, key + ".bias"))
        y = name("conv")
        nodes.append(helper.make_node("Conv", [x, key + ".weight", key + ".bias"], [y], pads=[1, 1, 1, 1]))
        return y

    def lrelu(x):
        y = name("lrelu")
        nodes.append(helper.make_node("LeakyRelu", [x], [y], alpha=0.2))
        return y

    def const(v):
        n = name("c")
        inits.append(numpy_helper.from_array(np.array(v, dtype=np.float32), n))
        return n

    def op(t, a, b):
        y = name(t.lower())
        nodes.append(helper.make_node(t, [a, b], [y]))
        return y

    def cat(xs):
        y = name("cat")
        nodes.append(helper.make_node("Concat", xs, [y], axis=1))
        return y

    def rdb(x, k):
        x1 = lrelu(conv(x, k + ".conv1"))
        x2 = lrelu(conv(cat([x, x1]), k + ".conv2"))
        x3 = lrelu(conv(cat([x, x1, x2]), k + ".conv3"))
        x4 = lrelu(conv(cat([x, x1, x2, x3]), k + ".conv4"))
        x5 = conv(cat([x, x1, x2, x3, x4]), k + ".conv5")
        return op("Add", op("Mul", x5, const(0.2)), x)

    def up(x):
        y = name("up")
        nodes.append(helper.make_node("Resize", [x, "", const([1, 1, 2, 2])], [y], mode="nearest"))
        return y

    feat = conv("input", "conv_first")
    body = feat
    blocks = sorted({int(k.split(".")[1]) for k in weights if k.startswith("body.")})
    for i in blocks:
        k = f"body.{i}"
        o = rdb(rdb(rdb(body, k + ".rdb1"), k + ".rdb2"), k + ".rdb3")
        body = op("Add", op("Mul", o, const(0.2)), body)
    feat = op("Add", feat, conv(body, "conv_body"))
    feat = lrelu(conv(up(feat), "conv_up1"))
    feat = lrelu(conv(up(feat), "conv_up2"))
    y = conv(lrelu(conv(feat, "conv_hr")), "conv_last")
    nodes.append(helper.make_node("Identity", [y], ["output"]))
    graph = helper.make_graph(nodes, "rrdbnet", [helper.make_tensor_value_info("input", TensorProto.FLOAT,
                              [1, 3, None, None])], [helper.make_tensor_value_info("output", TensorProto.FLOAT,
                              [1, 3, None, None])], inits)
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)], ir_version=8)
    onnx.save(model, out)


if __name__ == "__main__":
    build(load_pth(sys.argv[1]), sys.argv[2])
