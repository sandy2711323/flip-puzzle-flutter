# Custom Level Validation Report

Checked custom grids from 2 x 2 through 20 x 20.

Rules verified:

- Only exact match groups are allowed.
- No bonus tile is generated.
- No extra emoji/tile is generated.
- Every generated emoji appears exactly `matchCount` times.
- Total tiles always equals `gridSize * gridSize`.
- The game check logic uses `_matchCount`, so Match 4 opens/checks 4 tiles, Match 18 opens/checks 18 tiles, etc.

Valid custom choices:

```text
2 x 2: Match 2, Match 4
3 x 3: Match 3, Match 9
4 x 4: Match 2, Match 4, Match 8, Match 16
5 x 5: Match 5
6 x 6: Match 2, Match 3, Match 4, Match 6, Match 9, Match 12, Match 18
7 x 7: Match 7
8 x 8: Match 2, Match 4, Match 8, Match 16
9 x 9: Match 3, Match 9
10 x 10: Match 2, Match 4, Match 5, Match 10, Match 20
11 x 11: Match 11
12 x 12: Match 2, Match 3, Match 4, Match 6, Match 8, Match 9, Match 12, Match 16, Match 18
13 x 13: Match 13
14 x 14: Match 2, Match 4, Match 7, Match 14
15 x 15: Match 3, Match 5, Match 9, Match 15
16 x 16: Match 2, Match 4, Match 8, Match 16
17 x 17: Match 17
18 x 18: Match 2, Match 3, Match 4, Match 6, Match 9, Match 12, Match 18
19 x 19: Match 19
20 x 20: Match 2, Match 4, Match 5, Match 8, Match 10, Match 16, Match 20
```

Invalid examples intentionally hidden:

- 20 x 20 Match 3
- 10 x 10 Match 3
- 7 x 7 Match 2
- 5 x 5 Match 2

Reason: they do not divide the grid exactly.
