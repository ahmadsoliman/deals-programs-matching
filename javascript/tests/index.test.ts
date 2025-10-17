import { describe, it, expect } from "vitest";
import { main } from "../src/index.js";

describe("main", () => {
  it("greets world by default", () => {
    const res: any = main([]);
    expect(res.msg).toContain("Hello, world!");
  });

  it("greets a provided name", () => {
    const res: any = main(["greet", "Ada"]);
    expect(res.msg).toBe("Hello, Ada!");
  });
});