"""Formes signées (SDF) vectorisées avec numpy, en coordonnées de pixels d'art."""
import numpy as np


class Shape:
    def sdf(self, x, y):
        raise NotImplementedError

    def thickness(self) -> float:
        """Demi-épaisseur caractéristique (normalise l'ombrage pseudo-3D)."""
        return 2.0


class Circle(Shape):
    def __init__(self, cx, cy, r):
        self.cx, self.cy, self.r = cx, cy, r

    def sdf(self, x, y):
        return np.hypot(x - self.cx, y - self.cy) - self.r

    def thickness(self):
        return self.r


class Ellipse(Shape):
    def __init__(self, cx, cy, rx, ry, rot=0.0):
        self.cx, self.cy, self.rx, self.ry, self.rot = cx, cy, rx, ry, rot

    def sdf(self, x, y):
        c, s = np.cos(-self.rot), np.sin(-self.rot)
        px, py = x - self.cx, y - self.cy
        qx, qy = px * c - py * s, px * s + py * c
        k0 = np.hypot(qx / self.rx, qy / self.ry)
        k1 = np.hypot(qx / (self.rx * self.rx), qy / (self.ry * self.ry))
        return np.where(k1 > 1e-6, k0 * (k0 - 1.0) / np.maximum(k1, 1e-6), -min(self.rx, self.ry))

    def thickness(self):
        return min(self.rx, self.ry)


class Capsule(Shape):
    """Segment épaissi, rayon interpolé de ra à rb (membres, queues, cornes)."""

    def __init__(self, ax, ay, bx, by, ra, rb=None):
        self.ax, self.ay, self.bx, self.by = ax, ay, bx, by
        self.ra, self.rb = ra, ra if rb is None else rb

    def sdf(self, x, y):
        pax, pay = x - self.ax, y - self.ay
        bax, bay = self.bx - self.ax, self.by - self.ay
        h = np.clip((pax * bax + pay * bay) / max(bax * bax + bay * bay, 1e-6), 0.0, 1.0)
        return np.hypot(pax - bax * h, pay - bay * h) - (self.ra + (self.rb - self.ra) * h)

    def thickness(self):
        return max(self.ra, self.rb)


class Box(Shape):
    def __init__(self, cx, cy, hw, hh, radius=0.0, rot=0.0):
        self.cx, self.cy, self.hw, self.hh, self.radius, self.rot = cx, cy, hw, hh, radius, rot

    def sdf(self, x, y):
        c, s = np.cos(-self.rot), np.sin(-self.rot)
        px, py = x - self.cx, y - self.cy
        qx, qy = np.abs(px * c - py * s) - self.hw + self.radius, np.abs(px * s + py * c) - self.hh + self.radius
        outside = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0))
        inside = np.minimum(np.maximum(qx, qy), 0.0)
        return outside + inside - self.radius

    def thickness(self):
        return min(self.hw, self.hh)


class Poly(Shape):
    def __init__(self, points, depth=None):
        self.points = [(float(a), float(b)) for a, b in points]
        self._depth = depth

    def sdf(self, x, y):
        v = self.points
        n = len(v)
        d = (x - v[0][0]) ** 2 + (y - v[0][1]) ** 2
        s = np.ones_like(x)
        j = n - 1
        for i in range(n):
            ex, ey = v[j][0] - v[i][0], v[j][1] - v[i][1]
            wx, wy = x - v[i][0], y - v[i][1]
            h = np.clip((wx * ex + wy * ey) / max(ex * ex + ey * ey, 1e-6), 0.0, 1.0)
            bx, by = wx - ex * h, wy - ey * h
            d = np.minimum(d, bx * bx + by * by)
            c1 = y >= v[i][1]
            c2 = y < v[j][1]
            c3 = ex * wy > ey * wx
            flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
            s = np.where(flip, -s, s)
            j = i
        return s * np.sqrt(d)

    def thickness(self):
        if self._depth:
            return self._depth
        xs = [p[0] for p in self.points]
        ys = [p[1] for p in self.points]
        return max(1.0, min(max(xs) - min(xs), max(ys) - min(ys)) / 2.0)
