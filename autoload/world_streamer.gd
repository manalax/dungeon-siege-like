extends Node
## WorldStreamer: Threaded loading/unloading of dungeon chunks around the party leader (GDD §2.9).
##
## Stub (F-002). Implemented in F-062, F-063.
## Planned public API:
##   load_graph(graph: DungeonGraph), teleport_to(start_point)
##   loaded_chunks, load_radius, unload_radius
##   emits EventBus.chunk_loaded / chunk_unloaded
