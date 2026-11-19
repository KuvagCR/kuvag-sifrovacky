const assert = require("node:assert/strict");
const { test } = require("node:test");
const { stageHintPenalty, stationProgressPenalty } = require("../scoring.js");

test("multistage hints charge 10 then 20 points independently at each stage", () => {
  assert.equal(stageHintPenalty([0, 0, 0]), 0);
  assert.equal(stageHintPenalty([1, 0, 0]), 10);
  assert.equal(stageHintPenalty([2, 1, 2]), 70);
});

test("multistage station totals include all per-stage hints, wrong attempts, and navigation", () => {
  assert.equal(
    stationProgressPenalty({
      stationOrder: 2,
      hints: 3,
      stageHints: [1, 1, 1],
      wrong: 2,
      navigationUsed: true,
    }),
    70
  );
  assert.equal(
    stationProgressPenalty({
      stationOrder: 2,
      hints: 2,
      stageHints: [0, 0, 0],
      wrong: 0,
      navigationUsed: false,
    }),
    30
  );
});

test("ordinary stations keep the existing first/second hint penalties", () => {
  assert.equal(
    stationProgressPenalty({
      stationOrder: 5,
      hints: 2,
      wrong: 1,
      navigationUsed: true,
    }),
    65
  );
});
