# Advent of Code 2023

My solution, this time in zig. My personal goal is to keep the running
time for each day well below 0.1s (on my Raspberry Pi 2).

The following build targets are supported

  - `zig build runXX` where `XX` is the number of the day (01..24), run the code for day XX
  - `zig build test` runs all unit tests
  - `zig build times` runs all codes in `ReleaseFast` mode with timings.
