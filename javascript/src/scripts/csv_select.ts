import { csvToJson } from "../index.js";

const [fileArg, colsArg] = process.argv.slice(2);
const file = fileArg ?? "data/people.csv";
const cols = (colsArg ?? "").split(",").map((s) => s.trim()).filter(Boolean);
if (cols.length === 0) {
  console.error("Usage: tsx src/scripts/csv_select.ts <file.csv> <col1,col2,...>");
  process.exit(1);
}

const data: any[] = await csvToJson(file);
const selected = data.map((row: any) => {
  const out: any = {};
  for (const c of cols) out[c] = row[c];
  return out;
});
console.log(JSON.stringify(selected, null, 2));