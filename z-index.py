import matplotlib.pyplot as plt
import numpy as np
import copy
import random

# the dimension
S = 2000
D = 32
C = 0.7
H = 512
L = 20

# random number generator
rng = np.random.default_rng(42)

# the data
v = rng.random((S, D))

# nearest neighbor distances by brute-force
f = lambda x: (x > 0.0) * x + (x == 0.0) * 1000
r_dist = f((v - v.reshape(S, 1, D)) ** 2).sum(-1).min(-1) ** (1/2)

# the key by hilbert curve
def keyf(x: np.ndarray):
    o = np.zeros_like(x[:, 0])
    d = (rng.random((S, D)) < 0.5).astype(np.uint)
    m = C ** np.arange(D)
    y = copy.deepcopy(x) + rng.random((D, ))
    for i in range(L):
        z = np.floor(y).astype(np.uint)
        y = (y - z) * (C ** -1)
        p = rng.permutation(D)
        o = ((d - z[:, p]) * m).sum(-1) * (C ** (i * D)) + o
        p = rng.permutation(D)
        d = z[:, p] ^ d
    return o

# the sorting keys, use H generalized hilbert curve
k = np.stack([np.argsort(keyf(v)) for i in range(H)])

# the estimated nearest neighbor distance by hilbert curve
v_sort = v[k, :]
v_dist = ((v_sort[:, :-1, :] - v_sort[:, 1:, :]) ** 2).sum(-1)
v_dist = np.minimum(
    np.concatenate([np.inf * np.ones((H, 1)), v_dist], axis=1),
    np.concatenate([v_dist, np.inf * np.ones((H, 1))], axis=1)
)

# redistribute the distance back to each location
v_dist = v_dist[np.arange(H).reshape(H, 1), np.argsort(k, axis=-1)]
v_dist = v_dist.min(0) ** (1/2)
print(((v_dist - r_dist) / r_dist <= 1e-9).sum() / S)