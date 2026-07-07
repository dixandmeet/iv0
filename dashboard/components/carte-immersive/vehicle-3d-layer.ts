import maplibregl, {
  type CustomLayerInterface,
  type CustomRenderMethodInput,
  type MapMouseEvent,
} from "maplibre-gl";
import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import type { FilterKey } from "./filters-panel";
import {
  normalizeHeading,
  shortestHeadingDelta,
  type MapVehicle,
} from "@/lib/carte-immersive/vehicles";
import { CITY_CENTER, type VehicleType } from "@/lib/carte-immersive/data";

const LAYER_ID = "immersive-vehicle-models";
const LOD_SOURCE_ID = "immersive-vehicle-lod-source";
const LOD_LAYER_ID = "immersive-vehicle-lod-layer";
const MAX_INSTANCES = 256;
const STALE_AFTER_MS = 30_000;
const EXPIRE_AFTER_MS = 120_000;
const SNAP_DISTANCE_METERS = 300;
const INTERPOLATION_MS = 5_000;

type FocusMode = "ride" | "shop" | null;
type VehicleFilter = Exclude<FilterKey, "shop">;

type MotionState = {
  vehicle: MapVehicle;
  startLat: number;
  startLng: number;
  startHeading: number;
  targetLat: number;
  targetLng: number;
  targetHeading: number;
  startedAt: number;
  durationMs: number;
};

type ModelPart = {
  geometry: THREE.BufferGeometry;
  name: string;
};

type ModelTemplate = {
  parts: ModelPart[];
};

type VehicleBatch = {
  parts: THREE.InstancedMesh<THREE.BufferGeometry, THREE.MeshStandardMaterial>[];
  shadows: THREE.InstancedMesh<THREE.CircleGeometry, THREE.MeshBasicMaterial>;
};

type ControllerOptions = {
  onSelect: (id: string) => void;
};

const MODEL_CONFIG: Record<
  VehicleType,
  { asset: string; dimensions: [number, number, number]; color: string }
> = {
  bus: {
    asset: "/models/vehicles/bus.glb",
    dimensions: [2.55, 3.2, 11],
    color: "#566c66",
  },
  tram: {
    asset: "/models/vehicles/tram.glb",
    dimensions: [2.65, 3.35, 28],
    color: "#22b99d",
  },
  vtc: {
    asset: "/models/vehicles/car.glb",
    dimensions: [1.9, 1.55, 4.6],
    color: "#222c29",
  },
  taxi: {
    asset: "/models/vehicles/car.glb",
    dimensions: [1.9, 1.55, 4.6],
    color: "#f2a93b",
  },
};

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function distanceMeters(a: MapVehicle, b: MapVehicle) {
  const latScale = 111_320;
  const lngScale = Math.cos(((a.lat + b.lat) * Math.PI) / 360) * latScale;
  return Math.hypot((a.lat - b.lat) * latScale, (a.lng - b.lng) * lngScale);
}

function modelBrightness(vehicle: MapVehicle, selected: boolean, focus: FocusMode) {
  const age = vehicle.recordedAt ? Date.now() - new Date(vehicle.recordedAt).getTime() : 0;
  const staleFactor = age > STALE_AFTER_MS ? 0.48 : 1;
  const focusFactor =
    focus === "shop"
      ? 0.24
      : focus === "ride" && vehicle.type !== "vtc" && vehicle.type !== "taxi"
        ? 0.24
        : 1;
  return clamp(staleFactor * focusFactor * (selected ? 1.18 : 1), 0.18, 1.18);
}

function roundedRect(
  context: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number,
) {
  context.beginPath();
  context.moveTo(x + radius, y);
  context.lineTo(x + width - radius, y);
  context.quadraticCurveTo(x + width, y, x + width, y + radius);
  context.lineTo(x + width, y + height - radius);
  context.quadraticCurveTo(
    x + width,
    y + height,
    x + width - radius,
    y + height,
  );
  context.lineTo(x + radius, y + height);
  context.quadraticCurveTo(x, y + height, x, y + height - radius);
  context.lineTo(x, y + radius);
  context.quadraticCurveTo(x, y, x + radius, y);
  context.closePath();
}

function createLodIcon(type: VehicleType, color: string): ImageData {
  const canvas = document.createElement("canvas");
  canvas.width = 64;
  canvas.height = 64;
  const context = canvas.getContext("2d");
  if (!context) return new ImageData(64, 64);

  context.clearRect(0, 0, 64, 64);
  context.shadowColor = "rgba(0,0,0,.42)";
  context.shadowBlur = 8;
  context.shadowOffsetY = 3;
  context.fillStyle = color;
  context.strokeStyle = "rgba(255,255,255,.92)";
  context.lineWidth = 4;
  context.lineJoin = "round";
  const isTram = type === "tram";
  const bodyX = isTram ? 19 : 16;
  const bodyWidth = isTram ? 26 : 32;
  roundedRect(context, bodyX, 5, bodyWidth, 52, isTram ? 7 : 10);
  context.fill();
  context.stroke();

  context.shadowColor = "transparent";
  context.fillStyle = "#10211f";
  roundedRect(context, bodyX + 5, 10, bodyWidth - 10, 11, 3);
  context.fill();
  roundedRect(context, bodyX + 5, 40, bodyWidth - 10, 9, 3);
  context.fill();

  if (isTram) {
    context.strokeStyle = "rgba(255,255,255,.8)";
    context.lineWidth = 2;
    context.beginPath();
    context.moveTo(bodyX + 2, 31);
    context.lineTo(bodyX + bodyWidth - 2, 31);
    context.stroke();
  } else {
    context.fillStyle = "#ffe79b";
    context.beginPath();
    context.arc(bodyX + 6, 10, 2, 0, Math.PI * 2);
    context.arc(bodyX + bodyWidth - 6, 10, 2, 0, Math.PI * 2);
    context.fill();
  }

  return context.getImageData(0, 0, 64, 64);
}

function bodyMaterial(type: VehicleType, partName: string) {
  const lower = partName.toLowerCase();
  const isGlass = /window|black/.test(lower);
  const isDark = /wheel|bottom|bumper|detail/.test(lower);
  const isLight = /light/.test(lower);

  const color = isGlass
    ? "#10211f"
    : isDark
      ? "#171d1b"
      : isLight
        ? "#f8e7b0"
        : MODEL_CONFIG[type].color;

  const emissive = isLight
    ? new THREE.Color("#5e4a20")
    : new THREE.Color(color).multiplyScalar(isGlass || isDark ? 0.06 : 0.16);
  return new THREE.MeshStandardMaterial({
    color,
    roughness: isGlass ? 0.18 : isDark ? 0.7 : 0.38,
    metalness: isGlass ? 0.55 : isDark ? 0.1 : 0.22,
    emissive,
    emissiveIntensity: isLight ? 0.45 : 1,
    vertexColors: true,
  });
}

function standardizeTemplate(
  scene: THREE.Object3D,
  dimensions: [number, number, number],
): ModelTemplate {
  scene.updateMatrixWorld(true);
  const parts: ModelPart[] = [];

  scene.traverse((object) => {
    if (!(object instanceof THREE.Mesh) || !(object.geometry instanceof THREE.BufferGeometry)) {
      return;
    }
    const geometry = object.geometry.clone();
    geometry.applyMatrix4(object.matrixWorld);
    parts.push({
      geometry,
      name: `${object.name} ${Array.isArray(object.material) ? "" : object.material.name}`,
    });
  });

  if (parts.length === 0) throw new Error("vehicle model has no mesh");

  const aggregate = new THREE.Box3();
  for (const part of parts) {
    part.geometry.computeBoundingBox();
    if (part.geometry.boundingBox) aggregate.union(part.geometry.boundingBox);
  }

  const initialSize = aggregate.getSize(new THREE.Vector3());
  if (initialSize.x > initialSize.z) {
    const rotateToForward = new THREE.Matrix4().makeRotationY(-Math.PI / 2);
    for (const part of parts) part.geometry.applyMatrix4(rotateToForward);
  }

  aggregate.makeEmpty();
  for (const part of parts) {
    part.geometry.computeBoundingBox();
    if (part.geometry.boundingBox) aggregate.union(part.geometry.boundingBox);
  }

  const size = aggregate.getSize(new THREE.Vector3());
  const [width, height, length] = dimensions;
  const scale = new THREE.Matrix4().makeScale(
    width / Math.max(size.x, 0.001),
    height / Math.max(size.y, 0.001),
    length / Math.max(size.z, 0.001),
  );
  for (const part of parts) part.geometry.applyMatrix4(scale);

  aggregate.makeEmpty();
  for (const part of parts) {
    part.geometry.computeBoundingBox();
    if (part.geometry.boundingBox) aggregate.union(part.geometry.boundingBox);
  }
  const center = aggregate.getCenter(new THREE.Vector3());
  const translation = new THREE.Matrix4().makeTranslation(
    -center.x,
    -aggregate.min.y + 0.08,
    -center.z,
  );
  for (const part of parts) {
    part.geometry.applyMatrix4(translation);
    part.geometry.computeVertexNormals();
  }

  const grouped = new Map<string, THREE.BufferGeometry[]>();
  for (const part of parts) {
    const lower = part.name.toLowerCase();
    const category = /window|black/.test(lower)
      ? "windows"
      : /wheel|bottom|bumper|detail/.test(lower)
        ? "details"
        : /light/.test(lower)
          ? "lights"
          : "body";
    let geometry = part.geometry;
    for (const attribute of Object.keys(geometry.attributes)) {
      if (attribute !== "position" && attribute !== "normal") {
        geometry.deleteAttribute(attribute);
      }
    }
    if (geometry.index) geometry = geometry.toNonIndexed();
    const bucket = grouped.get(category) ?? [];
    bucket.push(geometry);
    grouped.set(category, bucket);
  }

  const mergedParts: ModelPart[] = [];
  for (const [name, geometries] of grouped) {
    const geometry = mergeGeometries(geometries, false);
    if (geometry) mergedParts.push({ geometry, name });
  }
  return { parts: mergedParts };
}

export class Vehicle3DLayer implements CustomLayerInterface {
  readonly id = LAYER_ID;
  readonly type = "custom" as const;
  readonly renderingMode = "3d" as const;

  private map: maplibregl.Map | null = null;
  private renderer: THREE.WebGLRenderer | null = null;
  private readonly camera = new THREE.Camera();
  private readonly scene = new THREE.Scene();
  private readonly rootMatrix = new THREE.Matrix4();
  private readonly anchor = maplibregl.MercatorCoordinate.fromLngLat(
    [CITY_CENTER[1], CITY_CENTER[0]],
    0,
  );
  private readonly motions = new Map<string, MotionState>();
  private readonly batches = new Map<VehicleType, VehicleBatch>();
  private readonly filters: Record<VehicleFilter, boolean> = {
    bus: true,
    tram: true,
    vtc: true,
    taxi: true,
  };
  private readonly onSelect: (id: string) => void;
  private selectedId: string | null = null;
  private focus: FocusMode = null;
  private view3D = true;
  private ready = false;
  private failed = false;
  private lodRefreshAt = 0;
  private ring: THREE.Mesh<THREE.RingGeometry, THREE.MeshBasicMaterial> | null = null;
  private disposed = false;

  private readonly handleZoom = () => this.updateRenderMode();
  private readonly handleClick = (event: MapMouseEvent) => {
    const id = this.pick(event.point);
    if (id) this.onSelect(id);
  };

  constructor(options: ControllerOptions) {
    this.onSelect = options.onSelect;
  }

  onAdd(map: maplibregl.Map, gl: WebGLRenderingContext | WebGL2RenderingContext) {
    this.map = map;
    this.renderer = new THREE.WebGLRenderer({
      canvas: map.getCanvas(),
      context: gl,
      antialias: true,
      alpha: true,
    });
    this.renderer.autoClear = false;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;

    this.scene.add(new THREE.HemisphereLight("#d9fff7", "#07100e", 1.65));
    const key = new THREE.DirectionalLight("#fff5df", 2.4);
    key.position.set(-30, 45, -20);
    this.scene.add(key);
    const rim = new THREE.DirectionalLight("#55d8bd", 1.1);
    rim.position.set(35, 20, 40);
    this.scene.add(rim);

    this.ensureLodLayer();
    map.on("zoom", this.handleZoom);
    map.on("click", this.handleClick);
    void this.loadModels();
  }

  onRemove() {
    this.disposed = true;
    this.map?.off("zoom", this.handleZoom);
    this.map?.off("click", this.handleClick);
    for (const batch of this.batches.values()) {
      for (const part of batch.parts) {
        part.geometry.dispose();
        part.material.dispose();
      }
      batch.shadows.geometry.dispose();
      batch.shadows.material.dispose();
    }
    this.ring?.geometry.dispose();
    this.ring?.material.dispose();
    this.renderer?.dispose();
    this.batches.clear();
    this.map = null;
    this.renderer = null;
  }

  private async loadModels() {
    try {
      const loader = new GLTFLoader();
      const [bus, tram, car] = await Promise.all([
        loader.loadAsync(MODEL_CONFIG.bus.asset),
        loader.loadAsync(MODEL_CONFIG.tram.asset),
        loader.loadAsync(MODEL_CONFIG.vtc.asset),
      ]);
      if (this.disposed) return;

      const templates = {
        bus: standardizeTemplate(bus.scene, MODEL_CONFIG.bus.dimensions),
        tram: standardizeTemplate(tram.scene, MODEL_CONFIG.tram.dimensions),
        car: standardizeTemplate(car.scene, MODEL_CONFIG.vtc.dimensions),
      };
      this.batches.set("bus", this.createBatch("bus", templates.bus));
      this.batches.set("tram", this.createBatch("tram", templates.tram));
      this.batches.set("vtc", this.createBatch("vtc", templates.car));
      this.batches.set("taxi", this.createBatch("taxi", templates.car));

      this.ring = new THREE.Mesh(
        new THREE.RingGeometry(2.4, 3.05, 48),
        new THREE.MeshBasicMaterial({
          color: "#72f4d9",
          transparent: true,
          opacity: 0.82,
          depthWrite: false,
          side: THREE.DoubleSide,
        }),
      );
      this.ring.rotation.x = -Math.PI / 2;
      this.ring.position.y = 0.04;
      this.ring.visible = false;
      this.scene.add(this.ring);
      this.ready = true;
      this.updateRenderMode();
      this.map?.triggerRepaint();
    } catch {
      this.failed = true;
      this.updateRenderMode();
    }
  }

  private createBatch(type: VehicleType, template: ModelTemplate): VehicleBatch {
    const parts = template.parts.map((part) => {
      const mesh = new THREE.InstancedMesh(
        part.geometry.clone(),
        bodyMaterial(type, part.name),
        MAX_INSTANCES,
      );
      mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      mesh.count = 0;
      mesh.frustumCulled = false;
      this.scene.add(mesh);
      return mesh;
    });

    const shadowGeometry = new THREE.CircleGeometry(
      type === "tram" ? 4.2 : type === "bus" ? 2.5 : 1.3,
      32,
    );
    shadowGeometry.rotateX(-Math.PI / 2);
    const shadows = new THREE.InstancedMesh(
      shadowGeometry,
      new THREE.MeshBasicMaterial({
        color: "#000000",
        transparent: true,
        opacity: 0.22,
        depthWrite: false,
      }),
      MAX_INSTANCES,
    );
    shadows.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    shadows.count = 0;
    shadows.frustumCulled = false;
    this.scene.add(shadows);
    return { parts, shadows };
  }

  private ensureLodLayer() {
    const map = this.map;
    if (!map) return;

    for (const type of ["bus", "tram", "vtc", "taxi"] as VehicleType[]) {
      const imageId = `immersive-vehicle-${type}`;
      if (!map.hasImage(imageId)) {
        map.addImage(imageId, createLodIcon(type, MODEL_CONFIG[type].color), {
          pixelRatio: 2,
        });
      }
    }

    if (!map.getSource(LOD_SOURCE_ID)) {
      map.addSource(LOD_SOURCE_ID, {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
    }
    if (!map.getLayer(LOD_LAYER_ID)) {
      map.addLayer({
        id: LOD_LAYER_ID,
        type: "symbol",
        source: LOD_SOURCE_ID,
        layout: {
          "icon-image": ["concat", "immersive-vehicle-", ["get", "type"]],
          "icon-size": ["case", ["==", ["get", "selected"], true], 1.04, 0.68],
          "icon-rotate": ["get", "heading"],
          "icon-rotation-alignment": "map",
          "icon-pitch-alignment": "viewport",
          "icon-allow-overlap": true,
          "icon-ignore-placement": true,
        },
        paint: {
          "icon-opacity": ["get", "opacity"],
        },
      });
    }
    this.refreshLodSource(true);
  }

  private currentPose(motion: MotionState, now = performance.now()) {
    const progress =
      motion.durationMs === 0
        ? 1
        : clamp((now - motion.startedAt) / motion.durationMs, 0, 1);
    return {
      lat: motion.startLat + (motion.targetLat - motion.startLat) * progress,
      lng: motion.startLng + (motion.targetLng - motion.startLng) * progress,
      heading: normalizeHeading(
        motion.startHeading +
          shortestHeadingDelta(motion.startHeading, motion.targetHeading) * progress,
      ),
    };
  }

  setVehicles(vehicles: MapVehicle[]) {
    const now = performance.now();
    const incomingIds = new Set(vehicles.map((vehicle) => vehicle.id));
    const previewTransitActive = vehicles.some(
      (vehicle) =>
        vehicle.mode === "preview" && (vehicle.type === "bus" || vehicle.type === "tram"),
    );

    for (const vehicle of vehicles.slice(0, MAX_INSTANCES * 4)) {
      const existing = this.motions.get(vehicle.id);
      if (!existing) {
        this.motions.set(vehicle.id, {
          vehicle,
          startLat: vehicle.lat,
          startLng: vehicle.lng,
          startHeading: vehicle.heading,
          targetLat: vehicle.lat,
          targetLng: vehicle.lng,
          targetHeading: vehicle.heading,
          startedAt: now,
          durationMs: 0,
        });
        continue;
      }

      const pose = this.currentPose(existing, now);
      const snap = distanceMeters(existing.vehicle, vehicle) > SNAP_DISTANCE_METERS;
      existing.vehicle = vehicle;
      existing.startLat = snap ? vehicle.lat : pose.lat;
      existing.startLng = snap ? vehicle.lng : pose.lng;
      existing.startHeading = snap ? vehicle.heading : pose.heading;
      existing.targetLat = vehicle.lat;
      existing.targetLng = vehicle.lng;
      existing.targetHeading = vehicle.heading;
      existing.startedAt = now;
      existing.durationMs = vehicle.mode === "live" && !snap ? INTERPOLATION_MS : 0;
    }

    for (const [id, motion] of this.motions) {
      if (incomingIds.has(id)) continue;
      if (motion.vehicle.mode === "preview" || previewTransitActive) {
        this.motions.delete(id);
      }
    }
    this.refreshLodSource(true);
    this.map?.triggerRepaint();
  }

  setPreviewPose(id: string, lat: number, lng: number, heading: number) {
    const motion = this.motions.get(id);
    if (!motion || motion.vehicle.mode !== "preview") return;
    motion.startLat = lat;
    motion.startLng = lng;
    motion.startHeading = heading;
    motion.targetLat = lat;
    motion.targetLng = lng;
    motion.targetHeading = heading;
    motion.startedAt = performance.now();
    motion.durationMs = 0;
    motion.vehicle.lat = lat;
    motion.vehicle.lng = lng;
    motion.vehicle.heading = heading;
    this.refreshLodSource();
  }

  setFilter(type: VehicleFilter, visible: boolean) {
    this.filters[type] = visible;
    this.refreshLodSource(true);
    this.map?.triggerRepaint();
  }

  setFocus(focus: FocusMode) {
    this.focus = focus;
    this.refreshLodSource(true);
    this.map?.triggerRepaint();
  }

  setSelected(id: string | null) {
    this.selectedId = id;
    this.moveToTop();
    this.refreshLodSource(true);
    this.map?.triggerRepaint();
  }

  setView3D(enabled: boolean) {
    this.view3D = enabled;
    this.updateRenderMode();
    this.moveToTop();
  }

  moveToTop() {
    const map = this.map;
    if (!map) return;
    try {
      if (map.getLayer(LAYER_ID)) map.moveLayer(LAYER_ID);
      if (map.getLayer(LOD_LAYER_ID)) map.moveLayer(LOD_LAYER_ID);
    } catch {
      // Le style peut être en transition ; le prochain repaint remettra les véhicules à jour.
    }
  }

  pick(point: { x: number; y: number }, radiusPx = 34): string | null {
    const map = this.map;
    if (!map) return null;
    let closest: { id: string; distance: number } | null = null;

    for (const motion of this.visibleMotions()) {
      const pose = this.currentPose(motion);
      const projected = map.project([pose.lng, pose.lat]);
      const distance = Math.hypot(projected.x - point.x, projected.y - point.y);
      if (distance <= radiusPx && (!closest || distance < closest.distance)) {
        closest = { id: motion.vehicle.id, distance };
      }
    }
    return closest?.id ?? null;
  }

  private visibleMotions() {
    const now = Date.now();
    const visible: MotionState[] = [];
    for (const [id, motion] of this.motions) {
      const age = motion.vehicle.recordedAt
        ? now - new Date(motion.vehicle.recordedAt).getTime()
        : 0;
      if (age > EXPIRE_AFTER_MS) {
        this.motions.delete(id);
        continue;
      }
      if (!this.filters[motion.vehicle.type]) continue;
      visible.push(motion);
    }
    return visible;
  }

  private use3DModels() {
    if (!this.map || !this.ready || this.failed || !this.view3D) return false;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return false;
    const mobile = window.matchMedia("(pointer: coarse)").matches;
    return this.map.getZoom() >= (mobile ? 15.2 : 14.5);
  }

  private updateRenderMode() {
    const map = this.map;
    if (!map?.getLayer(LOD_LAYER_ID)) return;
    const use3D = this.use3DModels();
    map.setLayoutProperty(LOD_LAYER_ID, "visibility", use3D ? "none" : "visible");
    for (const batch of this.batches.values()) {
      for (const part of batch.parts) part.visible = use3D;
      batch.shadows.visible = use3D;
    }
    if (this.ring) this.ring.visible = false;
    this.refreshLodSource(true);
    this.moveToTop();
    map.triggerRepaint();
  }

  private refreshLodSource(force = false) {
    const now = performance.now();
    if (!force && now - this.lodRefreshAt < 100) return;
    this.lodRefreshAt = now;
    const source = this.map?.getSource(LOD_SOURCE_ID) as maplibregl.GeoJSONSource | undefined;
    if (!source) return;

    const features = this.visibleMotions().map((motion) => {
      const pose = this.currentPose(motion, now);
      const selected = motion.vehicle.id === this.selectedId;
      return {
        type: "Feature" as const,
        properties: {
          id: motion.vehicle.id,
          type: motion.vehicle.type,
          heading: pose.heading,
          selected,
          opacity: modelBrightness(motion.vehicle, selected, this.focus),
        },
        geometry: {
          type: "Point" as const,
          coordinates: [pose.lng, pose.lat],
        },
      };
    });
    source.setData({ type: "FeatureCollection", features });
  }

  private updateInstances() {
    const grouped: Record<VehicleType, MotionState[]> = {
      bus: [],
      tram: [],
      vtc: [],
      taxi: [],
    };
    for (const motion of this.visibleMotions()) {
      if (grouped[motion.vehicle.type].length < MAX_INSTANCES) {
        grouped[motion.vehicle.type].push(motion);
      }
    }

    const mercatorScale = this.anchor.meterInMercatorCoordinateUnits();
    const matrix = new THREE.Matrix4();
    const position = new THREE.Vector3();
    const rotation = new THREE.Quaternion();
    const scale = new THREE.Vector3();
    const color = new THREE.Color();
    const selectedPosition = new THREE.Vector3();
    let hasSelectedPosition = false;

    for (const type of ["bus", "tram", "vtc", "taxi"] as VehicleType[]) {
      const batch = this.batches.get(type);
      if (!batch) continue;
      const motions = grouped[type];
      const zoom = this.map?.getZoom() ?? 16;
      const zoomEmphasis = clamp(3.6 - (zoom - 14.5) * 0.55, 1.35, 3.6);
      const typeEmphasis =
        type === "tram" ? 0.72 : type === "vtc" || type === "taxi" ? 1.18 : 1;
      const emphasis = zoomEmphasis * typeEmphasis;

      motions.forEach((motion, index) => {
        const pose = this.currentPose(motion);
        const selected = motion.vehicle.id === this.selectedId;
        const mercator = maplibregl.MercatorCoordinate.fromLngLat([pose.lng, pose.lat], 0);
        position.set(
          (mercator.x - this.anchor.x) / mercatorScale,
          selected ? 0.18 : 0,
          (mercator.y - this.anchor.y) / mercatorScale,
        );
        rotation.setFromAxisAngle(
          new THREE.Vector3(0, 1, 0),
          -(pose.heading * Math.PI) / 180,
        );
        scale.setScalar(selected ? emphasis * 1.28 : emphasis);
        matrix.compose(position, rotation, scale);

        const brightness = modelBrightness(
          motion.vehicle,
          selected,
          this.focus,
        );
        color.setRGB(brightness, brightness, brightness);
        for (const part of batch.parts) {
          part.setMatrixAt(index, matrix);
          part.setColorAt(index, color);
        }

        const shadowScale = new THREE.Vector3(emphasis, 1, emphasis);
        const shadowPosition = position.clone();
        shadowPosition.y = 0.03;
        matrix.compose(shadowPosition, rotation, shadowScale);
        batch.shadows.setMatrixAt(index, matrix);

        if (selected) {
          selectedPosition.copy(position);
          hasSelectedPosition = true;
        }
      });

      for (const part of batch.parts) {
        part.count = motions.length;
        part.instanceMatrix.needsUpdate = true;
        if (part.instanceColor) part.instanceColor.needsUpdate = true;
      }
      batch.shadows.count = motions.length;
      batch.shadows.instanceMatrix.needsUpdate = true;
    }

    if (this.ring) {
      this.ring.visible = hasSelectedPosition;
      if (hasSelectedPosition) {
        this.ring.position.x = selectedPosition.x;
        this.ring.position.z = selectedPosition.z;
      }
    }
  }

  render(
    _gl: WebGLRenderingContext | WebGL2RenderingContext,
    options: CustomRenderMethodInput,
  ) {
    if (!this.renderer || !this.map || !this.use3DModels()) return;

    this.updateInstances();
    const scale = this.anchor.meterInMercatorCoordinateUnits();
    this.rootMatrix
      .makeTranslation(this.anchor.x, this.anchor.y, this.anchor.z)
      .scale(new THREE.Vector3(scale, -scale, scale))
      .multiply(new THREE.Matrix4().makeRotationX(Math.PI / 2));

    this.camera.projectionMatrix
      .fromArray(options.defaultProjectionData.mainMatrix)
      .multiply(this.rootMatrix);
    this.camera.projectionMatrixInverse.copy(this.camera.projectionMatrix).invert();
    this.renderer.resetState();
    this.renderer.render(this.scene, this.camera);

    if (!document.hidden) this.map.triggerRepaint();
  }
}
