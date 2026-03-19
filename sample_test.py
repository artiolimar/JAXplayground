import jax.extend
from jax.lib import xla_bridge
# print(xla_bridge.get_backend().platform) # deprecated
print("Installed JAX backend:",jax.extend.backend.get_backend().platform)
