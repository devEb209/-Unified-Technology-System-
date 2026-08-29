import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
createServer(async (_, res) => res.end(await readFile('./index.html'))).listen(8080);
