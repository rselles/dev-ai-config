import { describe, it, expect, beforeEach } from "vitest";
import {
  createRun,
  appendLog,
  cancelRun,
  getState,
  listRuns,
  updateStatus,
  _resetForTests,
} from "../src/state/run-registry.js";

beforeEach(() => {
  _resetForTests();
});

describe("createRun", () => {
  it("returns a unique ID and sets status to running", () => {
    const id = createRun("developer", "Fix something");
    const state = getState(id);
    expect(state).toBeDefined();
    expect(state!.runId).toBe(id);
    expect(state!.role).toBe("developer");
    expect(state!.task).toBe("Fix something");
    expect(state!.status).toBe("running");
    expect(state!.logs).toEqual([]);
  });

  it("generates unique IDs", () => {
    const a = createRun("developer", "task A");
    const b = createRun("reviewer", "task B");
    expect(a).not.toBe(b);
  });
});

describe("appendLog", () => {
  it("adds log entries", () => {
    const id = createRun("developer", "task");
    appendLog(id, 1, "Reading src/foo.ts");
    appendLog(id, 1, "Writing src/bar.ts");
    const state = getState(id)!;
    expect(state.logs).toHaveLength(2);
    expect(state.logs[0].event).toBe("Reading src/foo.ts");
    expect(state.logs[0].turn).toBe(1);
    expect(state.logs[1].event).toBe("Writing src/bar.ts");
  });

  it("caps log at 500 entries by evicting oldest", () => {
    const id = createRun("developer", "task");
    for (let i = 0; i < 502; i++) appendLog(id, 1, `event ${i}`);
    const state = getState(id)!;
    expect(state.logs).toHaveLength(500);
    expect(state.logs[0].event).toBe("event 2");
    expect(state.logs[499].event).toBe("event 501");
  });

  it("is a no-op for unknown run IDs", () => {
    expect(() => appendLog("unknown", 1, "hello")).not.toThrow();
  });
});

describe("cancelRun", () => {
  it("sets status to cancelled and aborts the controller", () => {
    const id = createRun("developer", "task");
    const state = getState(id)!;
    expect(state.controller.signal.aborted).toBe(false);

    const result = cancelRun(id);

    expect(result).toBe(true);
    expect(state.status).toBe("cancelled");
    expect(state.controller.signal.aborted).toBe(true);
  });

  it("returns false for unknown run ID", () => {
    expect(cancelRun("unknown")).toBe(false);
  });
});

describe("listRuns", () => {
  it("returns all runs newest-first", async () => {
    const a = createRun("developer", "task A");
    await new Promise((r) => setTimeout(r, 5));
    const b = createRun("reviewer", "task B");
    const runs = listRuns();
    expect(runs[0].runId).toBe(b);
    expect(runs[1].runId).toBe(a);
  });
});

describe("updateStatus", () => {
  it("updates run status", () => {
    const id = createRun("developer", "task");
    updateStatus(id, "completed");
    expect(getState(id)!.status).toBe("completed");
  });
});
