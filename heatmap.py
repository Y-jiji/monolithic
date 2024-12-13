import numpy as np
import matplotlib.pyplot as plt

# put ten points into range
P = 10
p = np.random.rand(P, 2) * 20 - 10

# Generate x and y values
x = np.linspace(-10, 10, 1000)
y = np.linspace(-10, 10, 1000)

# Define the 2D function
def f(x, y):
    z = np.exp(- 5 * (x-p[:, 0].reshape(P, 1, 1))**2 - 5 * (y-p[:, 1].reshape(P, 1, 1))**2)
    return np.log(z.sum(0))

# Create a meshgrid from x and y values
X, Y = np.meshgrid(x, y)

# Evaluate the function at each point in the meshgrid
Z = f(X, Y)

# Create the heatmap using imshow
plt.imshow(Z, extent=[-10, 10, -10, 10], cmap='hot', origin='lower')
plt.colorbar()  # Add a colorbar to interpret the values
plt.xlabel('x')
plt.ylabel('y')
plt.title('Heatmap of 2D Function')
plt.show()
