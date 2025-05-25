import { decodeErrorResult, Hex } from "viem";
import IPOLErrors_JSON from "../out/IPOLErrors.sol/IPOLErrors.json";

// Check if the command line arguments are present
if (process.argv.length < 4) {
  console.log("Usage: ts-node decode.ts error <data>");
  process.exit(1);
}

// Get opcode and data from command line arguments
const opcode = process.argv[2];
const data = process.argv[3];

// Check if opcode is "error"
if (opcode !== "error") {
  console.log('Opcode must be "error"');
  process.exit(1);
}

try {
  // Attempt to decode the error
  const result = decodeErrorResult({
    abi: IPOLErrors_JSON.abi,
    data: data as Hex,
  });
  console.log(`Error name: ${result.errorName}`);
  console.log(`Args: ${result.args}`);
} catch (e) {
  // @ts-ignore
  console.error(`Failed to decode error: ${e.toString()}`);
  process.exit(1);
}
