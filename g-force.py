import networkx as nx
import graph_force

G = nx.grid_2d_graph(10, 10)
# we have to map the names to integers
# as graph_force only supports integers as node ids at the moment
edges = []
mapping = {n: i for i, n in enumerate(G.nodes)}
i = 0
for edge in G.edges:
    edges.append((mapping[edge[0]], mapping[edge[1]]))

pos = graph_force.layout_from_edge_list(len(G.nodes), edges, iter=1000)
nx.draw(G, {n: pos[i] for n, i in mapping.items()}, node_size=2, width=0.1)