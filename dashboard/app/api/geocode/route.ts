import { NextResponse } from "next/server";

const NANTES_VIEWBOX = "-1.72,47.32,-1.38,47.12";
const USER_AGENT = "Aule-Dashboard/1.0 (line-editor; contact@aule.local)";

type NominatimResult = {
  display_name: string;
  lat: string;
  lon: string;
  name?: string;
  address?: NominatimAddress;
};

type NominatimAddress = {
  house_number?: string;
  road?: string;
  pedestrian?: string;
  footway?: string;
  path?: string;
  postcode?: string;
  neighbourhood?: string;
  suburb?: string;
  city?: string;
  town?: string;
  village?: string;
  municipality?: string;
  county?: string;
  state?: string;
  country?: string;
};

type NominatimReverseResult = NominatimResult;

function normalizeAddressPart(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function extractHouseNumber(query: string) {
  return query.trim().match(/^(\d{1,5}(?:\s?(?:bis|ter|quater|[a-z]))?)\b/i)?.[1];
}

function formatAddressLabel(item: NominatimResult, query?: string) {
  const address = item.address;
  const road = address?.road ?? address?.pedestrian ?? address?.footway ?? address?.path;
  const city =
    address?.city ??
    address?.town ??
    address?.village ??
    address?.municipality ??
    address?.suburb;
  const queryHouseNumber = query ? extractHouseNumber(query) : undefined;
  const normalizedQuery = normalizeAddressPart(query ?? "");
  const houseNumber =
    address?.house_number ??
    (queryHouseNumber && road && normalizedQuery.includes(normalizeAddressPart(road))
      ? queryHouseNumber
      : undefined);
  const street = [houseNumber, road].filter(Boolean).join(" ");

  if (!street && !city) return item.display_name;

  const locality = [address?.postcode, city].filter(Boolean).join(" ");
  const details = [locality, address?.county, address?.state, address?.country]
    .filter(Boolean)
    .filter((value, index, values) => values.indexOf(value) === index);

  return [street || item.name, ...details].filter(Boolean).join(", ") || item.display_name;
}

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
      const label = formatAddressLabel(data);

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
  url.searchParams.set("addressdetails", "1");

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
    const requestedHouseNumber = extractHouseNumber(q);
    const seenLabels = new Set<string>();
    const results = data
      .map((item) => ({
        label: formatAddressLabel(item, q),
        lng: Number(item.lon),
        lat: Number(item.lat),
      }))
      .filter((item) => {
        if (!Number.isFinite(item.lng) || !Number.isFinite(item.lat)) return false;
        if (seenLabels.has(item.label)) return false;
        seenLabels.add(item.label);
        return true;
      })
      .sort((a, b) => {
        if (!requestedHouseNumber) return 0;
        const requestedPrefix = `${requestedHouseNumber} `;
        const aStartsWithNumber = a.label.startsWith(requestedPrefix);
        const bStartsWithNumber = b.label.startsWith(requestedPrefix);
        return Number(bStartsWithNumber) - Number(aStartsWithNumber);
      });

    return NextResponse.json({ results });
  } catch {
    return NextResponse.json(
      { error: "Erreur lors de la recherche d'adresse" },
      { status: 500 },
    );
  }
}
