import torch

N, H, D = 100000, 32, 4096
A = 100
M = 1000

NAIVE = 2 * D * N
CLUTT = H * (2 * D//H + 1) * (D//H) * (D//H + 1)

print(NAIVE / CLUTT)

with torch.no_grad():
    wq, wk, wv = (
        A * torch.rand(D, D//H) * (torch.rand(D, D//H) - 1/2),
        A * torch.rand(D, D//H) * (torch.rand(D, D//H) - 1/2),
        A * torch.rand(D, D//H) * (torch.rand(D, D//H) - 1/2)
    )
    u, v = (
        A * torch.rand(M, D) * (torch.rand(M, D) - 1/2),
        A * torch.rand(N, D) * (torch.rand(N, D) - 1/2)
    )
    u, v = (
        torch.nn.functional.layer_norm(u, (D, )),
        torch.nn.functional.layer_norm(v, (D, )),
    )

@torch.no_grad()
def clutter(u, v, wq, wk, wv):
    q = u.matmul(wq) * wk.abs().max() * D
    k = v.matmul(wk) / wk.abs().max() / D
    v = v.matmul(wv) / wv.abs().max() / D
    avg = torch.zeros((2*D//H+1, D//H))          # mean of each +/- v & denominator
    var = torch.zeros((2*D//H+1, D//H, D//H))    # variance of each +/- v & enominator
    for i in range(1, N):
        avg += k
        var += var / i
    inv = torch.linalg.inv(var)
