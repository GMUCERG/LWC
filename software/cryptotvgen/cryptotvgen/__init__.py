#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pkg_resources import get_distribution, DistributionNotFound


__project__ = 'cryptotvgen'
__author__ = 'Ekawat (Ice) Homsirikamol and William Diehl'
__package__ = 'cryptotvgen'

try:
    __version__ = get_distribution(__project__).version
except DistributionNotFound:
    __version__ = '(N/A - Local package)'

from .cli import *
