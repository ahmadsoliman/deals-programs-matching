import { csvToJson } from "../index.js";

const file = process.argv[2] ?? "data/people.csv";
const data: any[] = await csvToJson(file);
for (const row of data) {
  console.log(JSON.stringify(row));
}