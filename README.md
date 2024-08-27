# Matchmake

## Overview

Matchmake is an ongoing project aimed at implementing a player matchmaking system using an AVL tree for efficient player ranking and matching. This project is currently in development and demonstrates the use of advanced data structures in Zig.

## Image Illustration (idea)
<img width="1195" alt="Screenshot 1446-02-22 at 4 59 28 PM" src="https://github.com/user-attachments/assets/bc4abc49-e9eb-4f7b-98bc-f8a070acc091">
PS: "24" on Magic Johnson is incorrect

## Video Illustration

https://github.com/user-attachments/assets/d07a377d-f270-47af-b949-6fd739252d27


## Project Structure

The project consists of three main files:

1. `main.zig`: The entry point of the application.
2. `avl.zig`: Implementation of the AVL tree data structure for player ranking.
3. `build.zig`: The build configuration file for the Zig compiler.

## Current Functionality

### main.zig

The current `main.zig` file generates a set of 10,000 random players with scores and writes them to a JSON file. This serves as a data generation step for testing the AVL tree implementation.

### avl.zig

`avl.zig` contains a comprehensive implementation of an AVL tree tailored for a leaderboard system. It includes the following key features:

- Player struct with name and score
- AVL tree node structure
- Insertion, deletion, and search operations
- Tree balancing methods
- Utility functions for traversal and player ranking

### build.zig

The `build.zig` file configures the build process for the project. It sets up the main executable and includes the AVL module.

## Building and Running

To build and run the project:

1. Ensure you have Zig installed (tested with version 0.13.0).
2. Navigate to the project directory.
3. Run the following command:

```
zig build run
```

This will compile the project and run the main application, which currently generates a `players.json` file with random player data.

## Ongoing Development

This project is actively being developed. Future plans
