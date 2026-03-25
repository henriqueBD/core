# Core

> [cite_start]**A 2D continuous exploration platformer featuring a fully destructible terrain system and dynamic (seamless) world loading.** [cite: 27, 28, 30]

-----

## About the Project

[cite_start]This project was developed with the goal of deepening my knowledge of **memory management and performance optimization** within Godot. [cite: 27]

[cite_start]The primary technical challenge was creating a world that the player could alter in real-time (block destruction) without causing FPS drops or requiring loading screens. [cite: 29, 30] To solve this, I implemented a **Chunk-based architecture**.

## Technical Highlights

### 1\. Chunk System and Seamless Loading

[cite_start]The world is not loaded all at once; it is divided into fixed-size chunks. [cite: 30]

  * [cite_start]**Dynamic Loading:** A background **Thread** calculates the player's position and loads/instantiates only the chunks immediately adjacent to them. [cite: 21, 30]
  * [cite_start]**Memory Management:** Chunks that are far from the player are saved to memory and unloaded from the active scene to keep RAM usage low. [cite: 15]

\![Chunk System Diagram or GIF](TODO: LINK HERE)

### 2\. Real-Time Destructible Terrain

[cite_start]Instead of using heavy static collisions, the terrain is managed through an optimized approach. [cite: 28, 29]

  * [cite_start]**TileMap Manipulation:** Advanced use of Godot's TileMap API to update individual cells instantaneously. [cite: 16, 29]
  * [cite_start]**Collision Optimization:** Breaking a block recalculates the collision mesh locally without stalling the **Main Thread**. [cite: 21, 29]
  * [cite_start]**Data Persistence:** The state of each modified chunk (destroyed blocks) is saved so that if the player returns to the same location, the excavated area remains. [cite: 15, 22]

### 3\. State-Based Physics and Movement (FSM)

[cite_start]Implementation of a **Finite State Machine (FSM)** design pattern to control the player. [cite: 28] This ensures that movement is responsive and fluid, while the code remains highly scalable and free of bugs related to multiple simultaneous actions.

-----

## Technologies and Tools

  * [cite_start]**Engine:** Godot Engine 4.5 [cite: 16, 27]
  * [cite_start]**Language:** GDScript [cite: 27]
  * [cite_start]**Architecture/Patterns:** Finite State Machine, Multithreading, Spatial Partitioning. [cite: 15, 21]
  * [cite_start]**Versioning:** Git and GitHub. [cite: 4, 16]
