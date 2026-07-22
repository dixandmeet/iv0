import { mkdir, writeFile } from "node:fs/promises";
import * as THREE from "three";
import { GLTFExporter } from "three/addons/exporters/GLTFExporter.js";

class NodeFileReader {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((value) => {
      this.result = value;
      this.onloadend?.();
    });
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then((value) => {
      this.result = `data:${blob.type};base64,${Buffer.from(value).toString("base64")}`;
      this.onloadend?.();
    });
  }
}
globalThis.FileReader = NodeFileReader;

const output = new URL("../public/models/ambient/", import.meta.url);
await mkdir(output, { recursive: true });

const material = (color, roughness = 0.72, metalness = 0.04) =>
  new THREE.MeshStandardMaterial({ color, roughness, metalness });
const mesh = (geometry, color, position = [0, 0, 0], rotation = [0, 0, 0]) => {
  const value = new THREE.Mesh(geometry, material(color));
  value.position.set(...position);
  value.rotation.set(...rotation);
  value.castShadow = true;
  return value;
};
const box = (size, color, position) => mesh(new THREE.BoxGeometry(...size), color, position);
const cylinder = (radius, height, color, position) =>
  mesh(new THREE.CylinderGeometry(radius, radius, height, 10), color, position);

function person(accent, accessory = "none") {
  const root = new THREE.Group();
  root.add(cylinder(0.17, 0.68, accent, [0, 1.18, 0]));
  root.add(mesh(new THREE.SphereGeometry(0.16, 12, 8), "#b98362", [0, 1.68, 0]));
  root.add(cylinder(0.065, 0.72, "#263533", [-0.1, 0.47, 0]));
  root.add(cylinder(0.065, 0.72, "#263533", [0.1, 0.47, 0]));
  root.add(cylinder(0.05, 0.64, accent, [-0.24, 1.16, 0]));
  root.add(cylinder(0.05, 0.64, accent, [0.24, 1.16, 0]));
  if (accessory === "bag") root.add(box([0.3, 0.4, 0.16], "#394d48", [0, 1.25, 0.2]));
  if (accessory === "case") root.add(box([0.34, 0.48, 0.2], "#303a39", [0.38, 0.35, 0]));
  return root;
}

function bike(cargo = false) {
  const root = new THREE.Group();
  for (const z of [-0.62, 0.62]) {
    const wheel = mesh(new THREE.TorusGeometry(0.34, 0.035, 8, 20), "#18211f", [0, 0.36, z], [0, Math.PI / 2, 0]);
    root.add(wheel);
  }
  root.add(box([0.07, 0.08, 1.18], "#4f9a87", [0, 0.55, 0]));
  root.add(cylinder(0.05, 0.76, "#4f9a87", [0, 0.78, -0.08]));
  if (cargo) root.add(box([0.58, 0.42, 0.62], "#886f4e", [0, 0.72, 0.55]));
  const rider = person("#a67c52", "bag");
  rider.scale.setScalar(0.76); rider.position.set(0, 0.45, -0.1); root.add(rider);
  return root;
}

function scooter() {
  const root = new THREE.Group();
  root.add(box([0.18, 0.08, 0.85], "#426d64", [0, 0.12, 0]));
  root.add(cylinder(0.035, 0.9, "#263836", [0, 0.57, -0.35]));
  root.add(box([0.48, 0.04, 0.04], "#263836", [0, 1.02, -0.35]));
  for (const z of [-0.34, 0.34]) root.add(mesh(new THREE.TorusGeometry(0.13, 0.035, 8, 16), "#131918", [0, 0.14, z], [0, Math.PI / 2, 0]));
  return root;
}

function car(kind) {
  const root = new THREE.Group();
  const long = kind === "van" ? 5.1 : kind === "utility" ? 4.8 : 4.3;
  const high = kind === "van" ? 2.15 : kind === "suv" ? 1.8 : 1.45;
  root.add(box([1.82, high * 0.58, long], "#697875", [0, 0.58, 0]));
  root.add(box([1.62, high * 0.38, long * 0.53], "#263b3a", [0, high * 0.72, -0.15]));
  for (const x of [-0.92, 0.92]) for (const z of [-long * 0.3, long * 0.3]) root.add(mesh(new THREE.CylinderGeometry(0.34, 0.34, 0.16, 12), "#161b1a", [x, 0.36, z], [0, 0, Math.PI / 2]));
  return root;
}

const models = {
  "pedestrian-man": person("#536b68", "bag"),
  "pedestrian-woman": person("#8a665d"),
  "pedestrian-student": person("#4d6b8b", "bag"),
  "pedestrian-senior": person("#786f68"),
  "pedestrian-traveler": person("#586d61", "case"),
  cyclist: bike(false),
  "cargo-bike": bike(true),
  scooter: scooter(),
  "car-city": car("city"),
  "car-suv": car("suv"),
  "car-utility": car("utility"),
  "car-van": car("van"),
  bench: new THREE.Group(),
  tree: new THREE.Group(),
  lamp: new THREE.Group(),
  bin: new THREE.Group(),
  "bike-rack": new THREE.Group(),
  "traffic-light": new THREE.Group(),
};
models.bench.add(box([1.8, 0.12, 0.52], "#755c42", [0, 0.52, 0]), ...[-0.72, 0.72].map((x) => box([0.09, 0.5, 0.42], "#2b3835", [x, 0.25, 0])));
models.tree.add(cylinder(0.16, 2.4, "#685441", [0, 1.2, 0]), mesh(new THREE.IcosahedronGeometry(1.25, 1), "#426b55", [0, 2.75, 0]));
models.lamp.add(cylinder(0.07, 3.4, "#263330", [0, 1.7, 0]), mesh(new THREE.SphereGeometry(0.22, 10, 8), "#f4dca0", [0, 3.45, 0]));
models.bin.add(cylinder(0.3, 0.82, "#405650", [0, 0.41, 0]));
models["bike-rack"].add(...[-0.45, 0, 0.45].map((x) => mesh(new THREE.TorusGeometry(0.34, 0.035, 8, 14, Math.PI), "#81908c", [x, 0.04, 0], [0, 0, 0])));
models["traffic-light"].add(cylinder(0.06, 2.7, "#263330", [0, 1.35, 0]), box([0.3, 0.72, 0.24], "#17211f", [0, 2.55, 0]));

const exporter = new GLTFExporter();
for (const [name, model] of Object.entries(models)) {
  model.name = name;
  const data = await new Promise((resolve, reject) =>
    exporter.parse(model, resolve, reject, { binary: true, onlyVisible: true }),
  );
  await writeFile(new URL(`${name}.glb`, output), Buffer.from(data));
}
