"""Pixelforge : rendu procédural de sprites pixel art pour Rift Hunters.

Une créature est décrite par des pièces (formes vectorielles en pixels d'art) attachées à un squelette.
Chaque animation pose ce squelette image par image ; le moteur rastérise sans anticrénelage, ombre
chaque pièce avec une rampe de la palette (lumière en haut à gauche), puis pose un contour sélectif.
"""
from .palette import PALETTE, OUTLINE, ramp, hexrgb
from .geometry import Ellipse, Circle, Capsule, Poly, Box
from .rig import Part, Pose, Creature, Anim
from .render import render_frame
from .sheet import EntitySpec, build_entity
