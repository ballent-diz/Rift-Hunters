"""Assemble des régions peintes par un raccord de faible différence, sans doubler leurs textures.

Les pixels proviennent exclusivement des dessins ; un fondu d'un pixel adoucit le raccord.
"""
import numpy as np
from scipy import ndimage


def minimum_seam(cost):
    """Chemin vertical, un déplacement horizontal d'au plus un pixel par ligne."""
    height, width = cost.shape
    previous = cost[0].astype(np.float64).copy()
    parents = np.zeros((height, width), np.int8)
    for row in range(1, height):
        choices = np.stack((np.r_[np.inf, previous[:-1]], previous, np.r_[previous[1:], np.inf]))
        direction = choices.argmin(axis=0)
        parents[row] = direction - 1
        previous = cost[row] + choices[direction, np.arange(width)]
    seam = np.zeros(height, np.int32)
    seam[-1] = previous.argmin()
    for row in range(height - 1, 0, -1):
        seam[row - 1] = seam[row] + parents[row, seam[row]]
    return seam


def insert(canvas, filled, image, x, y, overlap_x=0, overlap_y=0):
    """Insère un rectangle en préservant un seul des deux dessins dans chaque recouvrement."""
    height, width = image.shape[:2]
    previous = canvas[y:y + height, x:x + width]
    occupied = filled[y:y + height, x:x + width]
    mask = np.ones((height, width), dtype=bool)
    difference = np.abs(previous.astype(np.float32) - image.astype(np.float32)).mean(axis=2)
    difference = ndimage.gaussian_filter(difference, 0.5)
    if overlap_x:
        seam = minimum_seam(difference[:, :overlap_x])
        mask[:, :overlap_x] = np.arange(overlap_x)[None, :] >= seam[:, None]
    if overlap_y:
        seam = minimum_seam(difference[:overlap_y, :].T)
        mask[:overlap_y, :] &= np.arange(overlap_y)[:, None] >= seam[None, :]
    weight = ndimage.gaussian_filter(mask.astype(np.float32), 1.0)
    weight[~occupied] = 1.0
    canvas[y:y + height, x:x + width] = np.clip(
        previous * (1 - weight[..., None]) + image * weight[..., None] + 0.5, 0, 255).astype(np.uint8)
    filled[y:y + height, x:x + width] = True
