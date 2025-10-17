import { csvToJson } from "../index.js";

const file = process.argv[2] ?? "data/people.csv";
const data = await csvToJson(file);
console.log(JSON.stringify(data, null, 2));