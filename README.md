> **A 2D continuous exploration platformer featuring a fully destructible terrain system and dynamic (seamless) world loading.**

![Gameplay Showcase GIF](gameplay.gif)

-----

### **About the Project**

This project was developed with the goal of deepening my knowledge of **memory management and performance optimization** within Godot.

The primary technical challenge was creating a world that the player could alter in real-time (block destruction) without causing FPS drops or requiring loading screens. To solve this, I implemented a **Chunk-based architecture**.

### **Technical Highlights**

#### **1. Chunk System and Seamless Loading**

The world is not loaded all at once; it is divided into fixed-size chunks.

  * **Dynamic Loading:** A background **Thread** calculates the player's position and loads/instantiates only the chunks immediately adjacent to them.
  * **Memory Management:** Chunks that are far from the player are saved to memory and unloaded from the active scene to keep RAM usage low.

#### **2. Real-Time Destructible Terrain**

Instead of using heavy static collisions, the terrain is managed through an optimized approach.

  * **TileMap Manipulation:** Advanced use of Godot's TileMap API to update individual cells instantaneously.
  * **Collision Optimization:** Breaking a block recalculates the collision mesh locally without stalling the **Main Thread**.
  * **Data Persistence:** The state of each modified chunk (destroyed blocks) is saved so that if the player returns to the same location, the excavated area remains.

#### **3. State-Based Physics and Movement (FSM)**

Implementation of a **Finite State Machine (FSM)** design pattern to control the player. This ensures that movement is responsive and fluid, while the code remains highly scalable and free of bugs related to multiple simultaneous actions.

-----

### **Technologies and Tools**

  * **Engine:** Godot Engine 4.5
  * **Language:** GDScript
  * **Architecture/Patterns:** Finite State Machine, Multithreading, Spatial Partitioning.
  * **Versioning:** Git and GitHub.

-----
