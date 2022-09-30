from pkg_resources import get_distribution, DistributionNotFound

__project__ = "cryptotvgen"

try:
    __version__ = get_distribution(__project__).version
except DistributionNotFound:
    __version__ = "(N/A)"
