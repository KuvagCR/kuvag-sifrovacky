const assert = require("node:assert/strict");
const { test } = require("node:test");
const { resolveSavedGameView } = require("../game-progress.js");

test("keeps a just-completed station open until its reveal is continued", () => {
  assert.deepEqual(
    resolveSavedGameView({ i: 2, phase: "station" }, 4, new Set([0, 1, 2]), 9),
    { phase: "station", index: 2, completed: true }
  );
});

test("restores saved story and route screens instead of advancing to the next station", () => {
  assert.deepEqual(
    resolveSavedGameView({ i: 2, phase: "reveal-cemetery-history" }, 4, new Set([0, 1, 2]), 9),
    { phase: "reveal-cemetery-history", index: 2, completed: true }
  );
  assert.deepEqual(
    resolveSavedGameView({ i: 5, phase: "post-route" }, 6, new Set([0, 1, 2, 4, 5]), 9),
    { phase: "post-route", index: 5, completed: true }
  );
  assert.deepEqual(
    resolveSavedGameView({ i: 2, phase: "chapel-route-solved" }, 4, new Set([0, 1, 2]), 9),
    { phase: "chapel-route-solved", index: 2, completed: true }
  );
});

test("does not restore stale incomplete progress over the server's next station", () => {
  assert.deepEqual(
    resolveSavedGameView({ i: 2, phase: "station" }, 4, new Set([0, 1]), 9),
    { phase: "station", index: 4, completed: false }
  );
});

test("keeps an active final memory screen and restores a completed game", () => {
  assert.deepEqual(
    resolveSavedGameView({ i: 8, phase: "fountain-memory" }, 8, new Set([0, 1, 2, 4, 5, 6, 7]), 9),
    { phase: "fountain-memory", index: 8, completed: false }
  );
  assert.deepEqual(
    resolveSavedGameView({ i: 8, phase: "finished" }, 9, new Set([0, 1, 2, 4, 5, 6, 7, 8]), 9),
    { phase: "finished", index: 8, completed: true }
  );
});
