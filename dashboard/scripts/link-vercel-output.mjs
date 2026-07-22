import { rm, symlink } from "node:fs/promises";
import path from "node:path";

if (process.env.VERCEL === "1") {
  const repositoryRoot = path.resolve(process.cwd(), "..");
  const outputLink = path.join(repositoryRoot, ".next");

  await rm(outputLink, { force: true, recursive: true });
  await symlink(path.join("dashboard", ".next"), outputLink, "dir");
}
