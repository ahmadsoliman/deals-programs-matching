import { join } from "node:path";
import { csvToJson } from "../index.js";

// Default to the sheet in data/ with spaces in the filename
const DEFAULT_FILE = join(
  "data",
  "Asset type update 2025-09-30 - Sheet1.csv"
);

const file = process.argv[2] ?? DEFAULT_FILE;
const rawData: any[] = await csvToJson(file);

// Transform: split Supabase Value by commas and trim
const data = rawData.map((row: any) => ({
  ...row,
  "Supabase Value": row["Supabase Value"]
    .split(",")
    .map((s: string) => s.trim())
    .filter((s: string) => s.length > 0)
}));

console.log(JSON.stringify(data, null, 2));
