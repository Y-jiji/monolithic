import matplotlib.pyplot as plt
import matplotlib.animation as ani
import numpy as np 
import networkx as nx
from typing import *
import graph_force
from tqdm import tqdm

class Animator:
    def __init__(self, g: nx.Graph, police_trace: Iterator[Tuple[int]], evader_trace: Iterator[Tuple[int]], rate=120, interval=1, initial_position=None):
        # figure and axes
        self.fig, self.ax = plt.subplots()
        # just a graph
        self.g = g
        # the iterators that generate traces of police units and evader units (typically one evader)
        self.police_trace = police_trace
        self.evader_trace = evader_trace
        # get the position of the graph
        self.pos = self.layout(initial_position)
        dx = max(x for x, y in self.pos) - min(x for x, y in self.pos)
        dy = max(y for x, y in self.pos) - min(y for x, y in self.pos)
        self.ax.set_xlim((-dx*0.1+min(x for x, y in self.pos), max(x for x, y in self.pos)+dx*0.1))
        self.ax.set_ylim((-dy*0.1+min(y for x, y in self.pos), max(y for x, y in self.pos)+dy*0.1))
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

    def layout(self, initial_position):
        edges = []
        mapping = {n: i for i, n in enumerate(self.g.nodes)}
        for edge in self.g.edges:
            edges.append((mapping[edge[0]], mapping[edge[1]]))
        pos = graph_force.layout_from_edge_list(len(self.g.nodes), edges, iter=2000, initial_pos=initial_position)
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
                raise f"the number of units change, if you want to remove one of them, use None! ({pos_last} v.s. {pos_curr})"
            for j in range(len(pos_last)):
                if pos_curr[j] is None: continue
                r = (frame%self.rate)/self.rate
                yield tuple((1-r)*self.pos[pos_last[j]][i] + r*self.pos[pos_curr[j]][i] for i in range(2))
        # generate the positions of units
        police_pos_2d = list(pos_2d(self.police_pos_last, self.police_pos))
        evader_pos_2d = list(pos_2d(self.evader_pos_last, self.evader_pos))
        # move dots on the figure
        self.police_dots.set_data([item[0] for item in police_pos_2d], [item[1] for item in police_pos_2d])
        self.evader_dots.set_data([item[0] for item in evader_pos_2d], [item[1] for item in evader_pos_2d])

    def animate(self, secs: int, savefig: Optional[str] = None):
        animation = ani.FuncAnimation(self.fig, self.update, frames=tqdm(range(int(secs*self.rate/self.interval))), interval=1/self.rate*self.interval)
        if savefig is None:
            plt.show()
        else:
            animation.save(savefig)

if __name__ == '__main__':
    import random
    initial_pos = []
    # generate a graph
    g = nx.Graph()
    for i in range(100):
        g.add_node(i)
        initial_pos.append((i%10/10, i//10/10))
    # generate the graph by randomly adding edges (Erdos graph)
    for i in range(100):
        for j in range(100):
            if abs(i % 10 - j % 10) + abs(i//10 - j//10) == 1 and i != j:
                g.add_edge(i, j)
    # here for demonstrative purpose, we use random walk
    p_ns = [random.randint(0, 99) for i in range(3)]
    e_ns = [random.randint(0, 99) for i in range(3)]
    def random_walk(ns, stop):
        while True:
            for i in range(len(ns)):
                if stop(ns[i]) or ns[i] is None:
                    ns[i] = None
                    continue
                ns[i] = random.choice(list(g.neighbors(ns[i])))
            yield ns
    ptrace = random_walk(p_ns, lambda _: False)
    etrace = random_walk(e_ns, lambda e: e in p_ns)
    animator = Animator(g, ptrace, etrace, interval=0.01, rate=120, initial_position=initial_pos)
    animator.animate(100)