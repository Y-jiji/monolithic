import matplotlib.pyplot as plt
import numpy as np
import copy
import random

S = 10000   # dataset size
D = 256     # the dimensions
C = 0.5     # hilbert curve factor
H = 256     # number of hash functions
L = 40      # hilbert layers

# random number generator
rng = np.random.default_rng(42)

# the data
v = rng.random(size=(S, D))

# brute force compute nearest neighbor
def brute_force(v: np.ndarray):
    # nearest neighbor distances by brute-force
    f = lambda x: (x > 0.0) * x + (x == 0.0) * 1000
    return np.concatenate([
        f((v - v.reshape(S, 1, D)[i*100:(i+1)*100, :, :]) ** 2).sum(-1).min(-1) ** (1/2)
        for i in range((S + 99)//100)
    ], axis = 0)

b_dist = brute_force(v)

# the key by hilbert curve
def hilbert(x: np.ndarray):
    o = np.zeros_like(x[:, 0])
    d = (rng.random((S, D)) < 0.5).astype(np.uint)
    m = C ** np.arange(D)
    y = copy.deepcopy(x) + rng.random((D, )) * C
    for i in range(L):
        z = np.floor(y).astype(np.uint)
        y = (y - z) * (C ** -1)
        p = rng.permutation(D)
        o = ((d - z) * m[p]).sum(-1) * (C ** (i * D)) + o
        p = rng.permutation(D)
        d = z
    return o

# the key by projection
def project(x: np.ndarray):
    w = rng.standard_normal(size=(D))
    return x @ w

# the sorting keys, use H generalized hilbert curve
k = np.stack([np.argsort(project(v)) for i in range(H)])

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
print(((v_dist - b_dist) / b_dist <= 1e-9).sum() / S)
