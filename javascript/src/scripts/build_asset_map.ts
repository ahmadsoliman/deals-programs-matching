import { join, dirname } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import { csvToJson } from "../index.js";

const DEFAULT_IN = join("data", "Asset type update 2025-09-30 - Sheet1.csv");
const DEFAULT_OUT = join("data", "asset-type-map.json");

const [inArg, outArg] = process.argv.slice(2);
const inPath = inArg ?? DEFAULT_IN;
const outPath = outArg ?? DEFAULT_OUT;

const rows: any[] = await csvToJson(inPath);

const map = new Map<string, string[]>();
for (const row of rows) {
  const key = String(row["CPD Value"] ?? "").trim();
  if (!key) continue;
  const parts = String(row["Supabase Value"] ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const acc = map.get(key) ?? [];
  for (const p of parts) if (!acc.includes(p)) acc.push(p);
  map.set(key, acc);
}

const obj: Record<string, string[]> = Object.fromEntries(map);
await mkdir(dirname(outPath), { recursive: true });
await writeFile(outPath, JSON.stringify(obj, null, 2), "utf8");
console.log(`Wrote ${outPath} (${Object.keys(obj).length} keys)`);