# jax_linear_mpi.py

from mpi4py import MPI
import jax
import jax.numpy as jnp
import numpy as np
import os

# --- MPI setup ---
comm = MPI.COMM_WORLD
world_size = comm.Get_Size() if hasattr(comm, "Get_Size") else comm.Get_size()
rank = comm.Get_rank()

shared_comm = comm.Split_type(MPI.COMM_TYPE_SHARED)
local_size = shared_comm.Get_size()

# --- Thread / device info ---
omp_threads = os.environ.get("OMP_NUM_THREADS", "default")
backend = jax.default_backend()
devices = jax.devices()

if rank == 0:
    print(f"[JAX] World size (MPI processes) = {world_size}")
    print(f"[JAX] Backend on rank 0: {backend}")
    print(f"[JAX] Devices on rank 0: {[str(d) for d in devices]}")

for r in range(world_size):
    comm.Barrier()
    if r == rank:
        print(
            f"[JAX] Rank {rank}: MPI processes on this node = {local_size}, "
            f"OMP_NUM_THREADS = {omp_threads}"
        )

comm.Barrier()

# --- Minimal distributed training: y = 2x + 1 ---
# 1) Build tiny global dataset
x_global = jnp.array([[1.0], [2.0], [3.0], [4.0]])
y_global = 2.0 * x_global + 1.0

# 2) Shard data across ranks: round-robin partition
x_local = x_global[rank::world_size]
y_local = y_global[rank::world_size]

if x_local.size == 0:
    # If you have more ranks than datapoints, some ranks will be empty.
    # They still participate in MPI, but contribute zero gradients.
    x_local = x_global[:0]
    y_local = y_global[:0]

# 3) Define model and loss
def model(params, x):
    W, b = params  # W: (1, 1), b: (1,)
    return jnp.dot(x, W) + b  # shape (N, 1)

def loss_fn(params, x, y):
    pred = model(params, x)
    return jnp.mean((pred - y) ** 2) if x.size > 0 else 0.0

grad_fn = jax.grad(loss_fn)

# 4) Initialize parameters (same on all ranks)
key = jax.random.PRNGKey(0)
W = jax.random.normal(key, shape=(1, 1))
b = jnp.zeros((1,))
params = (W, b)

def distributed_step(params, x_local, y_local, lr=0.1):
    """
    One SGD step:
    - compute local gradient with JAX
    - average gradients across all MPI ranks
    - update parameters with the global gradient
    """
    # Local gradient (JAX DeviceArrays)
    grads_local = grad_fn(params, x_local, y_local)  # tuple (dW_local, db_local)

    # Move to host numpy for MPI
    grads_host = [np.array(g) for g in grads_local]

    # Allreduce (sum) then average
    for g in grads_host:
        # In-place Allreduce
        comm.Allreduce(MPI.IN_PLACE, g, op=MPI.SUM)
        g /= world_size

    # Back to JAX
    grads_global = tuple(jnp.array(g) for g in grads_host)

    # SGD update (identical on all ranks)
    new_params = tuple(p - lr * g for p, g in zip(params, grads_global))
    return new_params

if rank == 0:
    print("[JAX] Starting distributed training with MPI gradient averaging.")

num_epochs = 10
for epoch in range(num_epochs):
    params = distributed_step(params, x_local, y_local, lr=0.1)

    # Only rank 0 computes/prints full loss for logging
    if rank == 0:
        full_loss = float(loss_fn(params, x_global, y_global))
        print(f"[JAX] Epoch {epoch+1}, Global Loss: {full_loss:.6f}")

# Final check: rank 0 prints trained parameters and predictions
if rank == 0:
    W_trained, b_trained = params
    preds = model(params, x_global)
    print("[JAX] Trained W:", np.array(W_trained))
    print("[JAX] Trained b:", np.array(b_trained))
    print("[JAX] Predictions:", np.array(preds).squeeze())
