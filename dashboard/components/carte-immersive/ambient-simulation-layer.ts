import maplibregl, {
  type CustomLayerInterface,
  type CustomRenderMethodInput,
} from "maplibre-gl";
import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import { AmbientSimulationConfig } from "@/lib/carte-immersive/ambient-simulation-config";
import { CITY_CENTER } from "@/lib/carte-immersive/data";

const LAYER_ID = "ambient-simulation-layer";
const MIN_ZOOM = 14.7;
const FULL_ZOOM = 16.4;
const METERS_PER_LATITUDE = 111_320;

type Coordinate = [number, number];
type RouteMode = "motor" | "foot" | "cycle" | "furniture" | "green";
type AmbientKind =
  | "pedestrian-man"
  | "pedestrian-woman"
  | "pedestrian-student"
  | "pedestrian-senior"
  | "pedestrian-traveler"
  | "cyclist"
  | "scooter"
  | "cargo-bike"
  | "car-city"
  | "car-suv"
  | "car-utility"
  | "car-van"
  | "bench"
  | "tree"
  | "lamp"
  | "bin"
  | "bike-rack"
  | "traffic-light";

type Route = {
  points: Coordinate[];
  lengths: number[];
  length: number;
  speed: number;
  mode: RouteMode;
  sourceKey: string;
};

type Entity = {
  kind: AmbientKind;
  route: number;
  distance: number;
  speedFactor: number;
  direction: 1 | -1;
  phase: number;
  waitingUntil: number;
  lateralOffset: number;
};

type Batch = {
  mesh: THREE.InstancedMesh;
  capacity: number;
};

export type AmbientTransitStop = { lat: number; lng: number };
export type AmbientSimulationLayerOptions = { densityScale?: number };

const MODEL_COLORS: Record<AmbientKind, string> = {
  "pedestrian-man": "#5e736e",
  "pedestrian-woman": "#8a6b63",
  "pedestrian-student": "#54718d",
  "pedestrian-senior": "#81766e",
  "pedestrian-traveler": "#667a6c",
  cyclist: "#547c73",
  scooter: "#426d64",
  "cargo-bike": "#9a7952",
  "car-city": "#788581",
  "car-suv": "#3f4b49",
  "car-utility": "#c7cbc7",
  "car-van": "#69726f",
  bench: "#735d46",
  tree: "#466b57",
  lamp: "#66736f",
  bin: "#455a54",
  "bike-rack": "#899591",
  "traffic-light": "#303c38",
};

const CAPACITY: Record<AmbientKind, number> = {
  "pedestrian-man": 16,
  "pedestrian-woman": 16,
  "pedestrian-student": 16,
  "pedestrian-senior": 16,
  "pedestrian-traveler": 16,
  cyclist: 5,
  scooter: 5,
  "cargo-bike": 3,
  "car-city": 16,
  "car-suv": 12,
  "car-utility": 11,
  "car-van": 11,
  bench: 32,
  tree: 48,
  lamp: 40,
  bin: 24,
  "bike-rack": 18,
  "traffic-light": 20,
};

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function metersBetween(a: Coordinate, b: Coordinate) {
  const latitude = ((a[1] + b[1]) * Math.PI) / 360;
  return Math.hypot(
    (b[1] - a[1]) * METERS_PER_LATITUDE,
    (b[0] - a[0]) * Math.cos(latitude) * METERS_PER_LATITUDE,
  );
}

function makeRoute(
  points: Coordinate[],
  speed: number,
  mode: RouteMode,
  sourceKey: string,
): Route | null {
  if (points.length < 2) return null;
  const lengths = [0];
  for (let index = 1; index < points.length; index += 1) {
    lengths.push(lengths[index - 1] + metersBetween(points[index - 1], points[index]));
  }
  const length = lengths.at(-1) ?? 0;
  const minimumLength = mode === "motor" ? 55 : mode === "furniture" ? 18 : 12;
  return length > minimumLength ? { points, lengths, length, speed, mode, sourceKey } : null;
}

function poseOnRoute(route: Route, distance: number) {
  const normalized = ((distance % route.length) + route.length) % route.length;
  let index = 1;
  while (index < route.lengths.length - 1 && route.lengths[index] < normalized) index += 1;
  const startDistance = route.lengths[index - 1];
  const segmentLength = Math.max(0.001, route.lengths[index] - startDistance);
  const progress = (normalized - startDistance) / segmentLength;
  const a = route.points[index - 1];
  const b = route.points[index];
  return {
    lng: a[0] + (b[0] - a[0]) * progress,
    lat: a[1] + (b[1] - a[1]) * progress,
    heading: Math.atan2(
      (b[0] - a[0]) * Math.cos(((a[1] + b[1]) * Math.PI) / 360),
      b[1] - a[1],
    ),
  };
}

function offsetRoute(points: Coordinate[], meters: number) {
  return points.map((point, index) => {
    const before = points[Math.max(0, index - 1)];
    const after = points[Math.min(points.length - 1, index + 1)];
    const dx = (after[0] - before[0]) * Math.cos((point[1] * Math.PI) / 180);
    const dy = after[1] - before[1];
    const length = Math.max(0.0000001, Math.hypot(dx, dy));
    return [
      point[0] - (dy / length) * (meters / (METERS_PER_LATITUDE * Math.cos((point[1] * Math.PI) / 180))),
      point[1] + (dx / length) * (meters / METERS_PER_LATITUDE),
    ] as Coordinate;
  });
}

function offsetCoordinate(point: Coordinate, heading: number, meters: number): Coordinate {
  const latitudeScale = Math.max(0.2, Math.cos((point[1] * Math.PI) / 180));
  return [
    point[0] - (Math.cos(heading) * meters) / (METERS_PER_LATITUDE * latitudeScale),
    point[1] + (Math.sin(heading) * meters) / METERS_PER_LATITUDE,
  ];
}

function lineStrings(
  geometry: GeoJSON.Geometry,
): Coordinate[][] {
  if (geometry.type === "LineString") return [geometry.coordinates as Coordinate[]];
  if (geometry.type === "MultiLineString") return geometry.coordinates as Coordinate[][];
  return [];
}

function polygonRings(geometry: GeoJSON.Geometry): Coordinate[][][] {
  if (geometry.type === "Polygon") return [geometry.coordinates as Coordinate[][]];
  if (geometry.type === "MultiPolygon") return geometry.coordinates as Coordinate[][][];
  return [];
}

function pointInRing(point: Coordinate, ring: Coordinate[]) {
  let inside = false;
  for (let current = 0, previous = ring.length - 1; current < ring.length; previous = current, current += 1) {
    const a = ring[current];
    const b = ring[previous];
    const crosses =
      a[1] > point[1] !== b[1] > point[1] &&
      point[0] < ((b[0] - a[0]) * (point[1] - a[1])) / (b[1] - a[1]) + a[0];
    if (crosses) inside = !inside;
  }
  return inside;
}

function pointInPolygon(point: Coordinate, rings: Coordinate[][]) {
  if (!rings.length || !pointInRing(point, rings[0])) return false;
  return !rings.slice(1).some((hole) => pointInRing(point, hole));
}

function pointSafelyInsidePolygon(point: Coordinate, rings: Coordinate[][], marginMeters = 6) {
  if (!pointInPolygon(point, rings)) return false;
  const lngMargin =
    marginMeters /
    (METERS_PER_LATITUDE * Math.max(0.2, Math.cos((point[1] * Math.PI) / 180)));
  const latMargin = marginMeters / METERS_PER_LATITUDE;
  return (
    pointInPolygon([point[0] + lngMargin, point[1]], rings) &&
    pointInPolygon([point[0] - lngMargin, point[1]], rings) &&
    pointInPolygon([point[0], point[1] + latMargin], rings) &&
    pointInPolygon([point[0], point[1] - latMargin], rings)
  );
}

function stableHash(value: string) {
  let hash = 2_166_136_261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16_777_619);
  }
  return hash >>> 0;
}

function makeStaticRoute(point: Coordinate, mode: "green", sourceKey: string): Route {
  return {
    points: [point, point],
    lengths: [0, 1],
    length: 1,
    speed: 0,
    mode,
    sourceKey,
  };
}

function coordinateKey(point: Coordinate) {
  return `${point[0].toFixed(5)},${point[1].toFixed(5)}`;
}

function featureKey(
  id: string | number | undefined,
  points: Coordinate[],
  roadClass: string,
  oneWay: number,
) {
  const start = points[0];
  const middle = points[Math.floor(points.length / 2)];
  const end = points.at(-1) ?? start;
  const geometryKey = [coordinateKey(start), coordinateKey(middle), coordinateKey(end)]
    .sort()
    .join("|");
  return `${id ?? "no-id"}:${geometryKey}:${roadClass}:${oneWay}`;
}

function parseOneWay(properties: Record<string, unknown>) {
  const value = properties.oneway;
  if (value === -1 || value === "-1") return -1;
  if (value === 1 || value === "1" || value === true || value === "yes") return 1;
  return 0;
}

function roadClassOf(properties: Record<string, unknown>) {
  return String(properties.class ?? properties.type ?? "").toLowerCase();
}

function isMotorRoad(roadClass: string) {
  return /^(motorway|trunk|primary|secondary|tertiary|minor|street)$/.test(
    roadClass,
  );
}

function allowsMotorVehicles(properties: Record<string, unknown>) {
  const access = String(properties.access ?? properties.motor_vehicle ?? "").toLowerCase();
  const subclass = String(properties.subclass ?? properties.service ?? "").toLowerCase();
  return (
    isMotorRoad(roadClassOf(properties)) &&
    !/^(no|private|agricultural|forestry)$/.test(access) &&
    !/parking|driveway|alley|emergency/.test(subclass)
  );
}

function isCar(kind: AmbientKind) {
  return /^car-/.test(kind);
}

function supportsInferredSidewalk(roadClass: string) {
  return /^(tertiary|minor|street|street_limited)$/.test(roadClass);
}

function isExplicitFootway(roadClass: string, subclass: string) {
  return /^(path|pedestrian)$/.test(roadClass) && !/cycleway/.test(subclass);
}

function isCycleway(roadClass: string, subclass: string) {
  return /cycleway/.test(subclass) || roadClass === "cycleway";
}

function laneOffsetFor(roadClass: string) {
  if (/motorway|trunk/.test(roadClass)) return 3.35;
  if (/primary|secondary/.test(roadClass)) return 2.85;
  if (roadClass === "tertiary") return 2.45;
  if (/minor|street/.test(roadClass)) return 2.05;
  return 1.55;
}

function sidewalkOffsetFor(roadClass: string) {
  if (roadClass === "tertiary") return 5.4;
  if (/minor|street/.test(roadClass)) return 4.6;
  return 3.4;
}

function geometryFromScene(scene: THREE.Object3D) {
  scene.updateMatrixWorld(true);
  const geometries: THREE.BufferGeometry[] = [];
  scene.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    let geometry = object.geometry.clone();
    geometry.applyMatrix4(object.matrixWorld);
    for (const attribute of Object.keys(geometry.attributes)) {
      if (attribute !== "position" && attribute !== "normal") geometry.deleteAttribute(attribute);
    }
    if (geometry.index) geometry = geometry.toNonIndexed();
    geometries.push(geometry);
  });
  const geometry = mergeGeometries(geometries, false);
  if (!geometry) throw new Error("Ambient GLB contains no compatible mesh");
  geometry.computeVertexNormals();
  return geometry;
}

function roadSpeed(properties: Record<string, unknown>) {
  const roadClass = roadClassOf(properties);
  if (/motorway|trunk|primary/.test(roadClass)) return 19.4;
  if (/residential|living|service/.test(roadClass)) return 8.3;
  return 13.9;
}

export class AmbientSimulationLayer implements CustomLayerInterface {
  readonly id = LAYER_ID;
  readonly type = "custom" as const;
  readonly renderingMode = "3d" as const;

  private map: maplibregl.Map | null = null;
  private renderer: THREE.WebGLRenderer | null = null;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.Camera();
  private readonly rootMatrix = new THREE.Matrix4();
  private readonly anchor = maplibregl.MercatorCoordinate.fromLngLat(
    [CITY_CENTER[1], CITY_CENTER[0]],
    0,
  );
  private readonly batches = new Map<AmbientKind, Batch>();
  private readonly entities: Entity[] = [];
  private routes: Route[] = [];
  private stopAnchors: Array<{ route: number; distance: number }> = [];
  private stops: AmbientTransitStop[] = [];
  private enabled: boolean = AmbientSimulationConfig.enabled;
  private ready = false;
  private disposed = false;
  private lastFrame = 0;
  private lastRouteRefresh = 0;
  private elapsed = 0;
  private networkCenter: Coordinate | null = null;
  private readonly matrix = new THREE.Matrix4();
  private readonly position = new THREE.Vector3();
  private readonly quaternion = new THREE.Quaternion();
  private readonly scale = new THREE.Vector3(1, 1, 1);
  private readonly densityScale: number;

  constructor(options: AmbientSimulationLayerOptions = {}) {
    this.densityScale = clamp(options.densityScale ?? 1, 0.1, 1);
  }

  private readonly refresh = () => {
    const map = this.map;
    if (!map || !this.ready || !this.enabled || map.getZoom() < MIN_ZOOM) return;
    const center: Coordinate = [map.getCenter().lng, map.getCenter().lat];
    const moved = this.networkCenter
      ? metersBetween(this.networkCenter, center)
      : Number.POSITIVE_INFINITY;
    if (
      (!this.routes.length || moved > AmbientSimulationConfig.animationDistance * 0.45) &&
      performance.now() - this.lastRouteRefresh > 800
    ) {
      this.rebuildRoutes();
    }
  };

  onAdd(map: maplibregl.Map, gl: WebGLRenderingContext | WebGL2RenderingContext) {
    this.map = map;
    this.renderer = new THREE.WebGLRenderer({ canvas: map.getCanvas(), context: gl, alpha: true });
    this.renderer.autoClear = false;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.82;
    this.scene.add(new THREE.HemisphereLight("#e8eee9", "#18201e", 1.35));
    const sun = new THREE.DirectionalLight("#fff3dc", 1.25);
    sun.position.set(-80, 130, -50);
    this.scene.add(sun);
    map.on("moveend", this.refresh);
    void this.loadModels();
  }

  onRemove() {
    this.disposed = true;
    this.map?.off("moveend", this.refresh);
    for (const batch of this.batches.values()) {
      batch.mesh.geometry.dispose();
      const materials = Array.isArray(batch.mesh.material)
        ? batch.mesh.material
        : [batch.mesh.material];
      materials.forEach((material) => material.dispose());
    }
    this.renderer?.dispose();
    this.batches.clear();
    this.entities.length = 0;
    this.map = null;
    this.renderer = null;
  }

  setEnabled(enabled: boolean) {
    this.enabled = enabled;
    if (!enabled) {
      for (const batch of this.batches.values()) batch.mesh.count = 0;
    } else if (this.ready && !this.routes.length) {
      this.rebuildRoutes();
    }
    this.map?.triggerRepaint();
  }

  setTransitStops(stops: AmbientTransitStop[]) {
    this.stops = stops.filter((stop) => Number.isFinite(stop.lat) && Number.isFinite(stop.lng));
    if (this.ready && !this.routes.length) this.rebuildRoutes();
  }

  moveBelowTransit() {
    const map = this.map;
    if (!map?.getLayer(this.id)) return;
    try {
      const transitLayer = map.getLayer("immersive-vehicle-models");
      if (transitLayer) map.moveLayer(this.id, transitLayer.id);
    } catch {
      // Style transitions are reconciled by the next map repaint.
    }
  }

  private async loadModels() {
    const loader = new GLTFLoader();
    const kinds = Object.keys(CAPACITY) as AmbientKind[];
    try {
      await Promise.all(kinds.map(async (kind) => {
        const gltf = await loader.loadAsync(`/models/ambient/${kind}.glb`);
        if (this.disposed) return;
        const material = new THREE.MeshStandardMaterial({
          color: MODEL_COLORS[kind],
          roughness: kind === "lamp" ? 0.36 : 0.72,
          metalness: /car|scooter|rack|lamp/.test(kind) ? 0.18 : 0.03,
          emissive: kind === "lamp" ? "#826c38" : "#000000",
          emissiveIntensity: kind === "lamp" ? 0.55 : 0,
        });
        const mesh = new THREE.InstancedMesh(geometryFromScene(gltf.scene), material, CAPACITY[kind]);
        mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
        mesh.count = 0;
        mesh.frustumCulled = true;
        this.scene.add(mesh);
        this.batches.set(kind, { mesh, capacity: CAPACITY[kind] });
      }));
      if (this.disposed) return;
      this.ready = true;
      this.rebuildRoutes();
    } catch (error) {
      console.warn("[AmbientSimulationLayer] Modèles ambiants indisponibles", error);
    }
  }

  private rebuildRoutes() {
    const map = this.map;
    if (!map || !this.ready || !this.enabled || map.getZoom() < MIN_ZOOM) return;
    this.lastRouteRefresh = performance.now();
    let features: maplibregl.GeoJSONFeature[] = [];
    try {
      features = map.querySourceFeatures("openmaptiles", {
        sourceLayer: "transportation",
      });
    } catch {
      // The vector source may still be loading. The next moveend will retry.
    }
    if (!features.length) {
      features = map.queryRenderedFeatures().filter((feature) => {
        const layerId = feature.layer.id.toLowerCase();
        return (
          feature.layer.type === "line" &&
          /^(road|bridge|tunnel)_(motorway|service|link|minor|secondary|tertiary|trunk|primary|path|street)/.test(
            layerId,
          ) &&
          !/casing|hatching/.test(layerId)
        );
      });
    }

    const routes: Route[] = [];
    const seen = new Set<string>();
    const center = map.getCenter();
    this.networkCenter = [center.lng, center.lat];
    const canvas = map.getCanvas();
    const pointInSpawnArea = (point: Coordinate) => {
      if (
        metersBetween([center.lng, center.lat], point) >
        Math.min(AmbientSimulationConfig.spawnRadius, AmbientSimulationConfig.animationDistance + 180)
      ) {
        return false;
      }
      const projected = map.project(point);
      return (
        projected.x >= -220 &&
        projected.y >= -220 &&
        projected.x <= canvas.clientWidth + 220 &&
        projected.y <= canvas.clientHeight + 220
      );
    };
    const clipToSpawnArea = (points: Coordinate[]) => {
      const chunks: Coordinate[][] = [];
      let chunk: Coordinate[] = [];
      for (let index = 1; index < points.length; index += 1) {
        const before = points[index - 1];
        const current = points[index];
        if (pointInSpawnArea(before) || pointInSpawnArea(current)) {
          if (!chunk.length) chunk.push(before);
          if (chunk.at(-1) !== current) chunk.push(current);
        } else if (chunk.length) {
          chunks.push(chunk);
          chunk = [];
        }
      }
      if (chunk.length) chunks.push(chunk);
      return chunks;
    };
    const pushRoute = (route: Route | null) => {
      if (route) routes.push(route);
    };

    for (const feature of features) {
      const properties = (feature.properties ?? {}) as Record<string, unknown>;
      const roadClass = roadClassOf(properties);
      const subclass = String(properties.subclass ?? "").toLowerCase();
      if (
        /rail|transit/.test(roadClass) ||
        /bridge|tunnel/.test(String(properties.brunnel ?? ""))
      ) continue;
      const oneWay = parseOneWay(properties);

      for (const rawPoints of lineStrings(feature.geometry)) {
        const validPoints = rawPoints.filter(
          (point) => Number.isFinite(point[0]) && Number.isFinite(point[1]),
        );
        for (const points of clipToSpawnArea(validPoints)) {
          if (points.length < 2) continue;
          const key = featureKey(feature.id, points, roadClass, oneWay);
          if (seen.has(key)) continue;
          seen.add(key);

          if (allowsMotorVehicles(properties)) {
          const speed = roadSpeed(properties);
          const laneOffset = laneOffsetFor(roadClass);
          if (oneWay !== 0) {
            const oriented = oneWay === -1 ? [...points].reverse() : points;
            pushRoute(makeRoute(oriented, speed, "motor", `${key}:oneway`));
          } else {
            const forward = offsetRoute(points, -laneOffset);
            const reverse = offsetRoute([...points].reverse(), -laneOffset);
            pushRoute(makeRoute(forward, speed, "motor", `${key}:forward`));
            pushRoute(makeRoute(reverse, speed, "motor", `${key}:reverse`));
          }

          if (/^(tertiary|minor|service|street|street_limited)$/.test(roadClass)) {
            const cycleOffset = laneOffset + 0.75;
            const forwardCycle = offsetRoute(points, -cycleOffset);
            pushRoute(makeRoute(forwardCycle, 5.2, "cycle", `${key}:cycle-forward`));
            if (oneWay === 0) {
              const reverseCycle = offsetRoute([...points].reverse(), -cycleOffset);
              pushRoute(makeRoute(reverseCycle, 5.2, "cycle", `${key}:cycle-reverse`));
            }
          }

          if (supportsInferredSidewalk(roadClass)) {
            const sidewalkOffset = sidewalkOffsetFor(roadClass);
            pushRoute(
              makeRoute(offsetRoute(points, sidewalkOffset), 1.28, "foot", `${key}:sidewalk-left`),
            );
            pushRoute(
              makeRoute(offsetRoute(points, -sidewalkOffset), 1.28, "foot", `${key}:sidewalk-right`),
            );
            pushRoute(
              makeRoute(
                offsetRoute(points, sidewalkOffset + 1.35),
                0,
                "furniture",
                `${key}:furniture-left`,
              ),
            );
            pushRoute(
              makeRoute(
                offsetRoute(points, -(sidewalkOffset + 1.35)),
                0,
                "furniture",
                `${key}:furniture-right`,
              ),
            );
          }
          } else if (roadClass === "street_limited") {
            pushRoute(makeRoute(points, 1.15, "foot", `${key}:limited-street`));
          } else if (isCycleway(roadClass, subclass)) {
            pushRoute(makeRoute(points, 5.2, "cycle", `${key}:cycleway`));
            if (oneWay === 0) {
              pushRoute(makeRoute([...points].reverse(), 5.2, "cycle", `${key}:cycleway-reverse`));
            }
          } else if (isExplicitFootway(roadClass, subclass)) {
            pushRoute(makeRoute(points, 1.22, "foot", `${key}:footway`));
          }
        }
      }
    }

    const greenFeatures: Array<{
      feature: maplibregl.GeoJSONFeature;
      sourceLayer: "park" | "landcover";
    }> = [];
    for (const sourceLayer of ["park", "landcover"] as const) {
      try {
        for (const feature of map.querySourceFeatures("openmaptiles", { sourceLayer })) {
          const greenClass = String(feature.properties?.class ?? "").toLowerCase();
          if (sourceLayer === "park" || greenClass === "grass" || greenClass === "wood") {
            greenFeatures.push({ feature, sourceLayer });
          }
        }
      } catch {
        // Green areas become available after their vector tiles finish loading.
      }
    }

    const greenPoints: Coordinate[] = [];
    const greenPolygonsSeen = new Set<string>();
    for (const { feature, sourceLayer } of greenFeatures) {
      for (const rings of polygonRings(feature.geometry)) {
        const outer = rings[0];
        if (!outer?.length) continue;
        const minLng = Math.min(...outer.map((point) => point[0]));
        const maxLng = Math.max(...outer.map((point) => point[0]));
        const minLat = Math.min(...outer.map((point) => point[1]));
        const maxLat = Math.max(...outer.map((point) => point[1]));
        const polygonKey = `${sourceLayer}:${feature.id ?? "no-id"}:${minLng.toFixed(5)}:${minLat.toFixed(5)}:${maxLng.toFixed(5)}:${maxLat.toFixed(5)}`;
        if (greenPolygonsSeen.has(polygonKey)) continue;
        greenPolygonsSeen.add(polygonKey);

        const meanLat = (minLat + maxLat) / 2;
        const stepMeters = sourceLayer === "park" ? 34 : 40;
        const stepLat = stepMeters / METERS_PER_LATITUDE;
        const stepLng =
          stepMeters /
          (METERS_PER_LATITUDE * Math.max(0.2, Math.cos((meanLat * Math.PI) / 180)));
        const hash = stableHash(polygonKey);
        const lngJitter = ((hash % 997) / 997) * stepLng;
        const latJitter = (((hash >>> 10) % 991) / 991) * stepLat;
        const startLng = Math.floor(minLng / stepLng) * stepLng + lngJitter;
        const startLat = Math.floor(minLat / stepLat) * stepLat + latJitter;

        for (let lng = startLng; lng <= maxLng; lng += stepLng) {
          for (let lat = startLat; lat <= maxLat; lat += stepLat) {
            if (greenPoints.length >= 96) break;
            const point: Coordinate = [lng, lat];
            if (!pointInSpawnArea(point) || !pointSafelyInsidePolygon(point, rings)) continue;
            if (greenPoints.some((existing) => metersBetween(existing, point) < 22)) continue;
            greenPoints.push(point);
            routes.push(makeStaticRoute(point, "green", `${polygonKey}:${coordinateKey(point)}`));
          }
          if (greenPoints.length >= 96) break;
        }
      }
      if (greenPoints.length >= 96) break;
    }

    this.routes = routes;
    this.stopAnchors = this.buildStopAnchors();
    this.seedEntities();
    this.moveBelowTransit();
    map.triggerRepaint();
  }

  private buildStopAnchors() {
    const map = this.map;
    if (!map) return [];
    const footRoutes = this.routes
      .map((route, index) => ({ route, index }))
      .filter(({ route }) => route.mode === "foot");
    const center = map.getCenter();
    const anchors: Array<{ route: number; distance: number; centerDistance: number }> = [];
    for (const stop of this.stops) {
      const screen = map.project([stop.lng, stop.lat]);
      const canvas = map.getCanvas();
      if (
        screen.x < -80 ||
        screen.y < -80 ||
        screen.x > canvas.clientWidth + 80 ||
        screen.y > canvas.clientHeight + 80
      ) continue;
      let closest: { route: number; distance: number; gap: number } | null = null;
      for (const candidate of footRoutes) {
        for (let pointIndex = 0; pointIndex < candidate.route.points.length; pointIndex += 1) {
          const point = candidate.route.points[pointIndex];
          const gap = metersBetween([stop.lng, stop.lat], point);
          if (gap <= 32 && (!closest || gap < closest.gap)) {
            closest = {
              route: candidate.index,
              distance: candidate.route.lengths[pointIndex],
              gap,
            };
          }
        }
      }
      if (closest) {
        anchors.push({
          route: closest.route,
          distance: closest.distance,
          centerDistance: metersBetween([center.lng, center.lat], [stop.lng, stop.lat]),
        });
      }
    }
    return anchors
      .sort((a, b) => a.centerDistance - b.centerDistance)
      .slice(0, 6)
      .map(({ route, distance }) => ({ route, distance }));
  }

  private seedEntities() {
    this.entities.length = 0;
    if (!this.routes.length) return;
    const zoom = this.map?.getZoom() ?? 0;
    const density =
      clamp((zoom - MIN_ZOOM) / (FULL_ZOOM - MIN_ZOOM), 0, 1) *
      this.densityScale;
    const routeIndices = (mode: RouteMode) =>
      this.routes
        .map((route, index) => ({ route, index }))
        .filter(({ route }) => route.mode === mode)
        .sort((a, b) => b.route.length - a.route.length)
        .map(({ index }) => index);
    const byMode: Record<RouteMode, number[]> = {
      motor: routeIndices("motor"),
      foot: routeIndices("foot"),
      cycle: routeIndices("cycle"),
      furniture: routeIndices("furniture"),
      green: routeIndices("green"),
    };
    const usedMotorRoutes = new Set<number>();
    const usedStaticRoutes = new Set<number>();
    const add = (kind: AmbientKind, count: number, mode: RouteMode, speedFactor = 1) => {
      const available = byMode[mode];
      if (!available.length || count <= 0) return;
      for (let index = 0; index < Math.min(count, CAPACITY[kind]); index += 1) {
        let route: number | null = null;
        for (let attempt = 0; attempt < available.length; attempt += 1) {
          const candidate =
            available[(index * 7 + kind.length * 3 + attempt * 11) % available.length];
          if (mode === "motor" && usedMotorRoutes.has(candidate)) continue;
          if (speedFactor === 0 && usedStaticRoutes.has(candidate)) continue;
          route = candidate;
          break;
        }
        if (route == null) continue;
        if (mode === "motor") usedMotorRoutes.add(route);
        if (speedFactor === 0) usedStaticRoutes.add(route);
        this.entities.push({
          kind,
          route,
          distance:
            ((index * 0.618033 + kind.length * 0.137) % 1) * this.routes[route].length,
          speedFactor: speedFactor * (0.88 + ((index * 17) % 23) / 100),
          direction: mode === "foot" && index % 2 === 0 ? -1 : 1,
          phase: index * 1.73,
          waitingUntil: speedFactor === 0 ? Number.POSITIVE_INFINITY : 0,
          lateralOffset: mode === "foot" ? ((index % 3) - 1) * 0.38 : 0,
        });
      }
    };
    const pedestrianTotal = Math.round(
      AmbientSimulationConfig.maxPedestrians * density * 0.34,
    );
    if (AmbientSimulationConfig.pedestrians) {
      const kinds: AmbientKind[] = ["pedestrian-man", "pedestrian-woman", "pedestrian-student", "pedestrian-senior", "pedestrian-traveler"];
      kinds.forEach((kind, index) =>
        add(
          kind,
          Math.ceil(pedestrianTotal / kinds.length) -
            (index >= pedestrianTotal % kinds.length ? 1 : 0),
          "foot",
        ),
      );
      this.stopAnchors.forEach((anchor, stopIndex) => {
        const passengers = 3 + (stopIndex % 3);
        for (let index = 0; index < passengers; index += 1) {
          this.entities.push({
            kind: kinds[(stopIndex + index) % kinds.length],
            route: anchor.route,
            distance: clamp(
              anchor.distance + (index - (passengers - 1) / 2) * 2.4,
              0.5,
              this.routes[anchor.route].length - 0.5,
            ),
            speedFactor: 0,
            direction: index % 2 === 0 ? 1 : -1,
            phase: stopIndex * 2.1 + index,
            waitingUntil: Number.POSITIVE_INFINITY,
            lateralOffset: ((index % 3) - 1) * 0.65,
          });
        }
      });
    }
    if (AmbientSimulationConfig.cars) {
      const cars = Math.round(AmbientSimulationConfig.maxCars * density * 0.42);
      add("car-city", Math.ceil(cars * 0.4), "motor");
      add("car-suv", Math.ceil(cars * 0.25), "motor", 0.96);
      add("car-utility", Math.ceil(cars * 0.2), "motor", 0.9);
      add("car-van", Math.floor(cars * 0.15), "motor", 0.86);
    }
    if (AmbientSimulationConfig.cyclists) add("cyclist", Math.round(AmbientSimulationConfig.maxCyclists * density), "cycle");
    if (AmbientSimulationConfig.scooters) add("scooter", Math.max(0, Math.round(AmbientSimulationConfig.maxScooters * density)), "cycle", 1.15);
    if (AmbientSimulationConfig.couriers) add("cargo-bike", Math.round(AmbientSimulationConfig.maxCouriers * density), "cycle", 0.82);
    if (AmbientSimulationConfig.streetFurniture && density > 0.35) {
      add("tree", Math.round(12 * density), "green", 0);
      add("lamp", Math.round(12 * density), "furniture", 0);
      add("bench", Math.round(6 * density), "green", 0);
      add("bin", Math.round(5 * density), "furniture", 0);
      add("bike-rack", Math.round(3 * density), "furniture", 0);
    }
  }

  private continueAlongNetwork(entity: Entity, overflow: number) {
    const current = this.routes[entity.route];
    if (!current) return;
    const currentEnd = current.points.at(-1);
    if (!currentEnd) return;
    const currentHeading = poseOnRoute(current, Math.max(0, current.length - 0.5)).heading;
    let best: { index: number; score: number } | null = null;
    for (let index = 0; index < this.routes.length; index += 1) {
      const candidate = this.routes[index];
      if (candidate.mode !== current.mode || index === entity.route) continue;
      if (
        isCar(entity.kind) &&
        this.entities.some(
          (other) =>
            other !== entity &&
            isCar(other.kind) &&
            other.route === index &&
            other.distance < 16,
        )
      ) continue;
      const candidateStart = candidate.points[0];
      const gap = metersBetween(currentEnd, candidateStart);
      if (gap > 24) continue;
      const candidateHeading = poseOnRoute(candidate, 0.5).heading;
      const angle = Math.abs(
        Math.atan2(
          Math.sin(candidateHeading - currentHeading),
          Math.cos(candidateHeading - currentHeading),
        ),
      );
      if (angle > Math.PI * 0.78) continue;
      const score = gap + angle * 7 + ((index + entity.phase * 10) % 7) * 0.08;
      if (!best || score < best.score) best = { index, score };
    }
    if (best) {
      entity.route = best.index;
      entity.distance = Math.min(this.routes[best.index].length - 0.01, overflow);
      return;
    }

    const alternatives = this.routes
      .map((route, index) => ({ route, index }))
      .filter(
        ({ route, index }) =>
          route.mode === current.mode &&
          route.length > 60 &&
          (!isCar(entity.kind) ||
            !this.entities.some(
              (other) => other !== entity && isCar(other.kind) && other.route === index,
            )),
      );
    if (alternatives.length) {
      const replacement = alternatives[Math.floor(entity.phase * 17) % alternatives.length];
      entity.route = replacement.index;
      entity.distance = Math.min(replacement.route.length - 0.01, overflow);
    } else {
      entity.distance = overflow % current.length;
    }
  }

  private carWouldOverlap(entity: Entity, deltaSeconds: number) {
    const route = this.routes[entity.route];
    if (!route || !isCar(entity.kind)) return false;
    const step = route.speed * entity.speedFactor * deltaSeconds;
    const proposedDistance = Math.min(route.length - 0.01, entity.distance + step);
    const proposedPose = poseOnRoute(route, proposedDistance);
    const lookAheadPose = poseOnRoute(
      route,
      Math.min(route.length - 0.01, proposedDistance + 6),
    );
    for (const other of this.entities) {
      if (other === entity || !isCar(other.kind)) continue;
      const otherRoute = this.routes[other.route];
      if (!otherRoute) continue;
      if (
        other.route === entity.route &&
        other.distance >= entity.distance &&
        other.distance - proposedDistance < 14
      ) {
        return true;
      }
      const otherPose = poseOnRoute(otherRoute, other.distance);
      const otherPoint: Coordinate = [otherPose.lng, otherPose.lat];
      if (
        metersBetween([proposedPose.lng, proposedPose.lat], otherPoint) < 3.2 ||
        metersBetween([lookAheadPose.lng, lookAheadPose.lat], otherPoint) < 3.2
      ) {
        return true;
      }
    }
    return false;
  }

  private advanceEntity(entity: Entity, deltaSeconds: number) {
    const route = this.routes[entity.route];
    if (!route || route.speed === 0) return;
    if (this.carWouldOverlap(entity, deltaSeconds)) return;
    entity.distance += route.speed * entity.speedFactor * entity.direction * deltaSeconds;
    if (route.mode === "foot") {
      if (entity.distance >= route.length) {
        entity.distance = route.length - (entity.distance - route.length);
        entity.direction = -1;
      } else if (entity.distance <= 0) {
        entity.distance = -entity.distance;
        entity.direction = 1;
      }
      return;
    }
    if (entity.distance >= route.length) {
      this.continueAlongNetwork(entity, entity.distance - route.length);
    }
  }

  private updateInstances(deltaSeconds: number) {
    const map = this.map;
    if (!map) return;
    const counts = new Map<AmbientKind, number>();
    const center = map.getCenter();
    const mercatorScale = this.anchor.meterInMercatorCoordinateUnits();
    const now = performance.now();
    this.elapsed += deltaSeconds;

    for (const entity of this.entities) {
      const route = this.routes[entity.route];
      if (!route) continue;
      if (entity.waitingUntil <= now) {
        this.advanceEntity(entity, deltaSeconds);
        if (route.mode === "foot" && entity.speedFactor > 0 && Math.sin(this.elapsed * 0.12 + entity.phase) > 0.998) {
          entity.waitingUntil = now + 4_000 + (entity.phase % 5) * 1_000;
        }
      }
      const activeRoute = this.routes[entity.route];
      if (!activeRoute) continue;
      const pose = poseOnRoute(activeRoute, entity.distance);
      const travelHeading = pose.heading + (entity.direction === -1 ? Math.PI : 0);
      const displayPoint = offsetCoordinate(
        [pose.lng, pose.lat],
        travelHeading,
        entity.lateralOffset,
      );
      if (metersBetween([center.lng, center.lat], displayPoint) > AmbientSimulationConfig.animationDistance) continue;
      const screen = map.project(displayPoint);
      if (screen.x < -90 || screen.y < -90 || screen.x > map.getCanvas().clientWidth + 90 || screen.y > map.getCanvas().clientHeight + 90) continue;
      const batch = this.batches.get(entity.kind);
      const index = counts.get(entity.kind) ?? 0;
      if (!batch || index >= batch.capacity) continue;
      const mercator = maplibregl.MercatorCoordinate.fromLngLat(displayPoint, 0);
      const movingPerson = entity.kind.startsWith("pedestrian");
      const bob = movingPerson && entity.waitingUntil <= now ? Math.abs(Math.sin(this.elapsed * 5.2 + entity.phase)) * 0.025 : 0;
      const lean = entity.kind === "scooter" ? Math.sin(this.elapsed * 0.7 + entity.phase) * 0.045 : 0;
      this.position.set(
        (mercator.x - this.anchor.x) / mercatorScale,
        bob,
        (mercator.y - this.anchor.y) / mercatorScale,
      );
      this.quaternion.setFromEuler(new THREE.Euler(0, -travelHeading, lean));
      const lodScale = map.getZoom() < 15.5 && /pedestrian|bench|bin/.test(entity.kind) ? 0.88 : 1;
      this.scale.setScalar(lodScale);
      this.matrix.compose(this.position, this.quaternion, this.scale);
      batch.mesh.setMatrixAt(index, this.matrix);
      counts.set(entity.kind, index + 1);
    }
    for (const [kind, batch] of this.batches) {
      batch.mesh.count = counts.get(kind) ?? 0;
      batch.mesh.instanceMatrix.needsUpdate = true;
      if (kind === "lamp") {
        const material = batch.mesh.material as THREE.MeshStandardMaterial;
        const hour = new Date().getHours();
        material.emissiveIntensity = hour >= 20 || hour < 7 ? 1.35 : 0.12;
      }
    }
  }

  render(_gl: WebGLRenderingContext | WebGL2RenderingContext, options: CustomRenderMethodInput) {
    if (!this.renderer || !this.map || !this.ready || !this.enabled || this.map.getZoom() < MIN_ZOOM || document.hidden) return;
    const now = performance.now();
    const delta = this.lastFrame ? Math.min(0.05, (now - this.lastFrame) / 1_000) : 0;
    this.lastFrame = now;
    this.updateInstances(delta);
    const scale = this.anchor.meterInMercatorCoordinateUnits();
    this.rootMatrix
      .makeTranslation(this.anchor.x, this.anchor.y, this.anchor.z)
      .scale(new THREE.Vector3(scale, -scale, scale))
      .multiply(new THREE.Matrix4().makeRotationX(Math.PI / 2));
    this.camera.projectionMatrix.fromArray(options.defaultProjectionData.mainMatrix).multiply(this.rootMatrix);
    this.camera.projectionMatrixInverse.copy(this.camera.projectionMatrix).invert();
    this.renderer.resetState();
    this.renderer.render(this.scene, this.camera);
    this.map.triggerRepaint();
  }
}
