import math
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

x = np.linspace(-20, 20, 10000)
epsilon = 0.1
avg_a = 0
avg_b = 0.1

z0 = 1 - (1+epsilon) ** -1
y0 = (
    ((math.pi * 2) ** -(1/2)) * np.exp(- (x - avg_a) ** 2 / 2) * z0 + 
    ((math.pi * 2) ** -(1/2)) * np.exp(- (x - avg_b) ** 2 / 2) * (1 - z0)
)
avg = z0 * avg_a + (1 - z0) * avg_b
var = 1
h0 = (math.pi * 2 * var) ** -(1/2) * np.exp(- (x - avg) ** 2 / 2 / var)

z1 = 0.5
y1 = (
    ((math.pi * 2) ** -(1/2)) * np.exp(- (x - avg_a) ** 2 / 2) * z1 + 
    ((math.pi * 2) ** -(1/2)) * np.exp(- (x - avg_b) ** 2 / 2) * (1 - z1)
)
avg = z1 * avg_a + (1 - z1) * avg_b
var = 1
h1 = (math.pi * 2 * var) ** -(1/2) * np.exp(- (x - avg) ** 2 / 2 / var)

plt.plot(x, np.exp(np.abs(np.log((h0 / h1) / (y0 / y1)))) - 1)
plt.show()
