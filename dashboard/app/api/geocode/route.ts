import { NextResponse } from "next/server";

const NANTES_VIEWBOX = "-1.72,47.32,-1.38,47.12";
const USER_AGENT = "Aule-Dashboard/1.0 (line-editor; contact@aule.local)";

type NominatimResult = {
  display_name: string;
  lat: string;
  lon: string;
};

type NominatimReverseResult = NominatimResult & {
  address?: {
    house_number?: string;
    road?: string;
    pedestrian?: string;
    postcode?: string;
    city?: string;
    town?: string;
    village?: string;
    municipality?: string;
  };
};

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const q = searchParams.get("q")?.trim();
  const latParam = searchParams.get("lat");
  const lngParam = searchParams.get("lng");
  const lat = latParam === null ? Number.NaN : Number(latParam);
  const lng = lngParam === null ? Number.NaN : Number(lngParam);

  if (
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180
  ) {
    const reverseUrl = new URL("https://nominatim.openstreetmap.org/reverse");
    reverseUrl.searchParams.set("lat", String(lat));
    reverseUrl.searchParams.set("lon", String(lng));
    reverseUrl.searchParams.set("format", "json");
    reverseUrl.searchParams.set("zoom", "18");
    reverseUrl.searchParams.set("addressdetails", "1");

    try {
      const res = await fetch(reverseUrl, {
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

      const data = (await res.json()) as NominatimReverseResult;
      const street = [data.address?.house_number, data.address?.road ?? data.address?.pedestrian]
        .filter(Boolean)
        .join(" ");
      const city =
        data.address?.city ??
        data.address?.town ??
        data.address?.village ??
        data.address?.municipality;
      const locality = [data.address?.postcode, city].filter(Boolean).join(" ");
      const label = [street, locality].filter(Boolean).join(", ") || data.display_name;

      return NextResponse.json({
        result: {
          label,
          lat: Number(data.lat),
          lng: Number(data.lon),
        },
      });
    } catch {
      return NextResponse.json(
        { error: "Erreur lors de la recherche de l'adresse" },
        { status: 500 },
      );
    }
  }

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
