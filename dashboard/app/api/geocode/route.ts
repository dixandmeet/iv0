import { NextResponse } from "next/server";

const NANTES_VIEWBOX = "-1.72,47.32,-1.38,47.12";
const USER_AGENT = "Aule-Dashboard/1.0 (line-editor; contact@aule.local)";

type NominatimResult = {
  display_name: string;
  lat: string;
  lon: string;
};

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const q = searchParams.get("q")?.trim();

  if (!q || q.length < 3) {
    return NextResponse.json(
      { error: "Saisissez au moins 3 caractères" },
      { status: 400 },
    );
  }

  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", q);
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "6");
  url.searchParams.set("countrycodes", "fr");
  url.searchParams.set("viewbox", NANTES_VIEWBOX);
  url.searchParams.set("bounded", "1");
  url.searchParams.set("addressdetails", "0");

  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent": USER_AGENT,
        "Accept-Language": "fr",
      },
      cache: "no-store",
    });

    if (!res.ok) {
      return NextResponse.json(
        { error: "Service de géocodage indisponible" },
        { status: 502 },
      );
    }

    const data = (await res.json()) as NominatimResult[];
    const results = data.map((item) => ({
      label: item.display_name,
      lng: Number(item.lon),
      lat: Number(item.lat),
    }));

    return NextResponse.json({ results });
  } catch {
    return NextResponse.json(
      { error: "Erreur lors de la recherche d'adresse" },
      { status: 500 },
    );
  }
}
