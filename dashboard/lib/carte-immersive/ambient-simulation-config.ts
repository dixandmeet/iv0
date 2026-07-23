export const AmbientSimulationConfig = {
  enabled: true,
  pedestrians: true,
  cars: true,
  cyclists: true,
  scooters: true,
  couriers: true,
  streetFurniture: true,
  maxPedestrians: 80,
  maxCars: 50,
  maxCyclists: 5,
  maxScooters: 5,
  maxCouriers: 3,
  spawnRadius: 1200,
  animationDistance: 800,
  lodEnabled: true,
  instancing: true,
} as const;

export type AmbientSimulationConfigShape = typeof AmbientSimulationConfig;
