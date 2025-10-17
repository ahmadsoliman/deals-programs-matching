import { csvToJson } from "../index.js";

const [fileArg, expr] = process.argv.slice(2);
const file = fileArg ?? "data/people.csv";

if (!expr || !expr.includes("=")) {
  console.error("Usage: tsx src/scripts/csv_filter.ts <file.csv> <col=value>");
  process.exit(1);
}

const [key, value] = expr.split("=", 2);
const data: any[] = await csvToJson(file);
const filtered = data.filter((row: any) => String(row[key]) === value);
console.log(JSON.stringify(filtered, null, 2));