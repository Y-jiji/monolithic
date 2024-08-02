import matplotlib.pyplot as plt
import numpy as np
import functools
import matplotlib.collections as mcoll
import matplotlib.path as mpath

N = 100
fig, ax = plt.subplots()

@functools.cmp_to_key
def compare(x: tuple[int, int], y: tuple[int, int]):
    for i in reversed(range(20)):
        for j in range(2):
            a = (x[j] & 1 << i)
            b = (y[j] & 1 << i)
            if a < b: return -1
            if a > b: return  1
    return 0

def colorline(
    x, y, z=None, cmap=plt.get_cmap('copper'), norm=plt.Normalize(0.0, 1.0),
        linewidth=3, alpha=1.0):
    """
    http://nbviewer.ipython.org/github/dpsanders/matplotlib-examples/blob/master/colorline.ipynb
    http://matplotlib.org/examples/pylab_examples/multicolored_line.html
    Plot a colored line with coordinates x and y
    Optionally specify colors in the array z
    Optionally specify a colormap, a norm function and a line width
    """

    # Default colors equally spaced on [0,1]:
    if z is None:
        z = np.linspace(0.0, 1.0, len(x))

    # Special case if a single number:
    if not hasattr(z, "__iter__"):  # to check for numerical input -- this is a hack
        z = np.array([z])

    z = np.asarray(z)

    segments = make_segments(x, y)
    lc = mcoll.LineCollection(segments, array=z, cmap=cmap, norm=norm,
                              linewidth=linewidth, alpha=alpha)

    ax = plt.gca()
    ax.add_collection(lc)

    return lc


def make_segments(x, y):
    """
    Create list of line segments from x and y coordinates, in the correct format
    for LineCollection: an array of the form numlines x (points per line) x 2 (x
    and y) array
    """

    points = np.array([x, y]).T.reshape(-1, 1, 2)
    segments = np.concatenate([points[:-1], points[1:]], axis=1)
    return segments

a = np.array(sorted([(i+1, j+1) for i in range(N) for j in range(N)], key=compare)) + 0.1 * np.random.rand(N*N, 2)
a = a / (N+1)
b = mpath.Path(a).interpolated(steps=100).vertices
x, y = b[:, 0], b[:, 1]
z = np.linspace(0, 1, len(x))
colorline(x, y, z, cmap=plt.get_cmap('cool'), linewidth=2, alpha=0.5)
plt.show()
