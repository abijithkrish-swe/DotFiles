// dump.mjs <toolshelf dist dir> <manifest> — what toolshelf's parser
// (src/components.ts) makes of a manifest, in the same format as dump.zsh.
// Resolution uses resolveVersion only (no disk checks), and looks tools up by
// exact name like the shell does.
import { readFileSync } from "node:fs";

const [dist, manifest] = process.argv.slice(2);
process.env.COMPONENTS_MANIFEST = manifest;
const c = await import(`${dist}/components.js`);

let m;
try {
  m = c.loadManifest();
} catch {
  console.log("REJECT");
  process.exit(0);
}
const out = ["ACCEPT"];
for (const t of m.tools) {
  out.push(`tool ${t.name} dir=${t.dir} root=${t.root.join("|")} bin=${t.bin.join("|")} check=${t.check ?? ""} home=${t.homeEnv.join(",")}`);
}
for (const t of m.tools) {
  for (const v of c.versionsOf(m, t)) {
    const flags = [v.isDefault && "default", v.autoload && "autoload", v.onPath && "onpath", v.docker && `docker=${v.docker}`]
      .filter(Boolean)
      .map((f) => ` ${f}`)
      .join("");
    out.push(`version ${t.name} ${v.version}${flags}`);
  }
}
for (const k of Object.keys(m.images).sort()) out.push(`image ${k} ${m.images[k]}`);

for (const line of readFileSync(manifest, "utf-8").split("\n")) {
  if (!line.startsWith("# query: ")) continue;
  const [tool, q = "-"] = line.slice("# query: ".length).trim().split(/\s+/);
  const def = m.tools.find((t) => t.name === tool);
  let got = "ERROR";
  try {
    if (def) got = c.resolveVersion(m, def, q === "-" ? "" : q).version;
  } catch {
    /* ERROR */
  }
  out.push(`resolve ${tool} ${q} => ${got}`);
}
console.log(out.join("\n"));
