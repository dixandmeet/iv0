import { NextResponse } from "next/server";
import JSZip from "jszip";
import { parse } from "csv-parse/sync";
import { createClient } from "@/lib/supabase/server";
import { loadNetworkContext } from "@/lib/network/server";

export const runtime = "nodejs";

type CsvRow = Record<string, string>;

const REQUIRED_FILES = ["routes.txt", "stops.txt", "trips.txt", "stop_times.txt"] as const;

function modeFromRouteType(routeType: string): "bus" | "tram" | "boat" | "shuttle" {
  if (routeType === "0" || routeType === "1") return "tram";
  if (routeType === "4") return "boat";
  return "bus";
}

function colorOf(value: string | undefined): string {
  const normalized = value?.replace(/^#/, "").trim();
  return normalized && /^[0-9a-f]{6}$/i.test(normalized) ? `#${normalized}` : "#2563EB";
}

function splitDirection(longName: string): [string, string] {
  const parts = longName.split(/\s(?:-|–|—|↔|→)\s/).map((part) => part.trim()).filter(Boolean);
  if (parts.length >= 2) return [parts[0], parts[parts.length - 1]];
  return [longName || "Origine", longName || "Destination"];
}

async function readCsv(zip: JSZip, filename: string): Promise<CsvRow[]> {
  const entry = Object.values(zip.files).find(
    (file) => !file.dir && file.name.toLowerCase().split("/").pop() === filename,
  );
  if (!entry) throw new Error(`Fichier ${filename} manquant`);
  const content = await entry.async("string");
  return parse(content, { columns: true, skip_empty_lines: true, trim: true, bom: true }) as CsvRow[];
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Non authentifié" }, { status: 401 });

  const network = await loadNetworkContext(supabase, user.id);
  if (!network?.canManage) {
    return NextResponse.json({ error: "Accès administrateur réseau requis" }, { status: 403 });
  }

  try {
    const form = await request.formData();
    const file = form.get("file");
    if (!(file instanceof File) || !file.name.toLowerCase().endsWith(".zip")) {
      return NextResponse.json({ error: "Sélectionnez un fichier GTFS au format .zip" }, { status: 400 });
    }
    if (file.size > 50 * 1024 * 1024) {
      return NextResponse.json({ error: "Le fichier GTFS dépasse la limite de 50 Mo" }, { status: 413 });
    }

    const zip = await JSZip.loadAsync(await file.arrayBuffer());
    const presentNames = new Set(
      Object.values(zip.files).filter((entry) => !entry.dir).map((entry) => entry.name.toLowerCase().split("/").pop()),
    );
    const missing = REQUIRED_FILES.filter((filename) => !presentNames.has(filename));
    if (missing.length) {
      return NextResponse.json({ error: `Fichiers GTFS manquants : ${missing.join(", ")}`, missing }, { status: 400 });
    }

    const [routes, stops, trips, stopTimes] = await Promise.all([
      readCsv(zip, "routes.txt"),
      readCsv(zip, "stops.txt"),
      readCsv(zip, "trips.txt"),
      readCsv(zip, "stop_times.txt"),
    ]);
    if (!routes.length) throw new Error("routes.txt ne contient aucune ligne");

    const stopsById = new Map(stops.map((stop) => [stop.stop_id, stop]));
    const firstTripByRoute = new Map<string, string>();
    for (const trip of trips) {
      if (trip.route_id && trip.trip_id && !firstTripByRoute.has(trip.route_id)) {
        firstTripByRoute.set(trip.route_id, trip.trip_id);
      }
    }
    const stopTimesByTrip = new Map<string, CsvRow[]>();
    for (const stopTime of stopTimes) {
      if (!stopTime.trip_id) continue;
      const rows = stopTimesByTrip.get(stopTime.trip_id) ?? [];
      rows.push(stopTime);
      stopTimesByTrip.set(stopTime.trip_id, rows);
    }

    const lines = routes.map((route) => {
      if (!route.route_id) throw new Error("Une ligne de routes.txt ne contient pas route_id");
      const shortName = route.route_short_name || route.route_id;
      const longName = route.route_long_name || shortName;
      const [fallbackOrigin, fallbackDestination] = splitDirection(longName);
      const tripId = firstTripByRoute.get(route.route_id);
      const orderedStops = (tripId ? stopTimesByTrip.get(tripId) ?? [] : [])
        .sort((a, b) => Number(a.stop_sequence) - Number(b.stop_sequence))
        .map((row, index, all) => {
          const stop = stopsById.get(row.stop_id);
          return {
            stopId: row.stop_id,
            name: stop?.stop_name || row.stop_id,
            theoreticalTime: row.arrival_time?.slice(0, 5) || "—",
            isTerminus: index === 0 || index === all.length - 1,
          };
        });
      const origin = orderedStops[0]?.name || fallbackOrigin;
      const destination = orderedStops.at(-1)?.name || fallbackDestination;
      const transportMode = modeFromRouteType(route.route_type);
      const color = colorOf(route.route_color);
      return {
        line_id: route.route_id,
        short_name: shortName,
        long_name: longName,
        transport_mode: transportMode,
        color,
        data: {
          id: `network:${network.network.id}:${route.route_id}`,
          routeId: route.route_id,
          shortName,
          origin,
          destination,
          status: "normal",
          vehicleCount: 0,
          avgDelay: 0,
          incidentCount: 0,
          transportType: transportMode === "tram" ? "Tramway" : transportMode === "boat" ? "Navibus" : "Bus",
          depotCode: "NETWORK",
          stopCount: orderedStops.length,
          maxVehicles: 0,
          punctuality: 100,
          firstDeparture: orderedStops[0]?.theoreticalTime || "—",
          lastDeparture: "—",
          stops: orderedStops,
          segmentQuality: orderedStops.slice(1).map(() => "on-time"),
          vehicles: [],
          lineColor: color,
        },
      };
    });

    const { data: count, error } = await supabase.rpc("replace_network_gtfs_lines", {
      p_network_id: network.network.id,
      p_filename: file.name,
      p_lines: lines,
      p_stop_count: stops.length,
    });
    if (error) throw new Error(error.message);

    return NextResponse.json({ routeCount: Number(count ?? lines.length), stopCount: stops.length });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Import GTFS impossible";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
