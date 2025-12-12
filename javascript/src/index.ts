// Simple, scriptable entrypoint with permissive typing
import { readFile } from "node:fs/promises";
import { parse } from "csv-parse/sync";

export function main(args: any[] = process.argv.slice(2)): any {
  const cmd = args[0] ?? "greet";
  if (cmd === "greet") {
    const name = args[1] ?? "world";
    const msg = `Hello, ${name}!`;
    console.log(msg);
    return { ok: true, msg };
  }
  console.log("Unknown command:", cmd);
  return { ok: false };
}

export async function csvToJson(filePath: string): Promise<any[]> {
  const input = await readFile(filePath, "utf8");
  const records = parse(input, { columns: true, skip_empty_lines: true });
  return records as any[];
}

// If run directly:
// - greet: `npm start -- [greet] [name]`
// - csv:   `npm start -- csv path/to/file.csv`
if (import.meta.url === `file://${process.argv[1]}`) {
  const [cmd, arg] = process.argv.slice(2);
  if (cmd === "csv") {
    const file = arg ?? "./data.csv";
    const data = await csvToJson(file);
    console.log(JSON.stringify(data, null, 2));
  } else {
    main();
  }
}
