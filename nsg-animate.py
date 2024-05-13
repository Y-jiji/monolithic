import matplotlib.pyplot as plt
import matplotlib.animation as ani
import numpy as np 
import networkx as nx
from typing import *
import graph_force

class Animator:
    def __init__(self, g: nx.Graph, police_trace: Iterator[Tuple[int]], evader_trace: Iterator[Tuple[int]], rate=120, interval=1):
        # figure and axes
        self.fig, self.ax = plt.subplots()
        # just a graph
        self.g = g
        # the iterators that generate traces of police units and evader units (typically one evader)
        self.police_trace = police_trace
        self.evader_trace = evader_trace
        # get the position of the graph
        self.pos = self.layout()
        self.ax.set_xlim((min(x for x, y in self.pos), max(x for x, y in self.pos)))
        self.ax.set_ylim((min(y for x, y in self.pos), max(y for x, y in self.pos)))
        # last positions, initialized as none
        self.police_pos_last = None
        self.evader_pos_last = None
        # current positions of police and evader
        self.police_pos = next(self.police_trace)
        self.evader_pos = next(self.evader_trace)
        # plot the graph
        def edge_enumerator():
            for i, j in self.g.edges:
                yield [self.pos[i][0], self.pos[j][0]]
                yield [self.pos[i][1], self.pos[j][1]]
        self.ax.plot(*list(edge_enumerator()), color='green', alpha=0.2)
        # initial positions
        self.police_dots,  = self.ax.plot([self.pos[j][0] for i in self.police_pos], [self.pos[j][1] for i in self.police_pos], 'bo')
        self.evader_dots,  = self.ax.plot([self.pos[j][0] for i in self.evader_pos], [self.pos[j][1] for i in self.evader_pos], 'ro')
        self.rate = rate
        self.interval = interval

    def layout(self):
        edges = []
        mapping = {n: i for i, n in enumerate(self.g.nodes)}
        for edge in self.g.edges:
            edges.append((mapping[edge[0]], mapping[edge[1]]))
        pos = graph_force.layout_from_edge_list(len(self.g.nodes), edges, iter=1000)
        return pos

    def update(self, frame: int):
        frame = int(frame/self.interval)
        if frame % self.rate == 0:
            # extract the nodes
            self.police_pos_last = self.police_pos
            self.evader_pos_last = self.evader_pos
            self.police_pos = next(self.police_trace)
            self.evader_pos = next(self.evader_trace)
        def pos_2d(pos_last, pos_curr):
            if len(pos_last) != len(pos_curr):
                raise f"the number of units change! ({pos_last} v.s. {pos_curr})"
            for j in range(len(pos_last)):
                yield tuple((1-frame%self.rate/self.rate)*self.pos[pos_last[j]][i] + frame%self.rate/self.rate*self.pos[pos_curr[j]][i] for i in range(2))
        # generate the positions of units
        police_pos_2d = list(pos_2d(self.police_pos_last, self.police_pos))
        evader_pos_2d = list(pos_2d(self.evader_pos_last, self.evader_pos))
        # move dots on the figure
        self.police_dots.set_data([item[0] for item in police_pos_2d], [item[1] for item in police_pos_2d])
        self.evader_dots.set_data([item[0] for item in evader_pos_2d], [item[1] for item in evader_pos_2d])

    def animate(self, secs: int, savefig: Optional[str] = None):
        animation = ani.FuncAnimation(self.fig, self.update, frames=int(secs*self.rate/self.interval), interval=1/self.rate*self.interval)
        if savefig is None:
            plt.show()
        else:
            animation.save(savefig)

if __name__ == '__main__':
    import random
    # generate a graph
    g = nx.Graph()
    for i in range(100):
        g.add_node(i)
    # generate the graph by randomly adding edges (Erdos graph)
    for i in range(100):
        for j in range(100):
            # if abs(i % 10 - j % 10) <= 1 and abs(i//10 - j//10) <= 1 and i != j:
            #     g.add_edge(i, j)
            if random.random() < 0.1 and i != j:
                g.add_edge(i, j)
    # here for demonstrative purpose, we use random walk
    def random_walk():
        ns = [random.randint(0, 99) for i in range(3)]
        while True:
            ns = [random.choice(list(g.neighbors(l))) for l in ns]
            yield ns
    ptrace = random_walk()
    etrace = random_walk()
    animator = Animator(g, ptrace, etrace, interval=0.1, rate=120)
    animator.animate(2, savefig='./demo.gif')