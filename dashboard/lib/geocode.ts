export interface GeocodeResult {
  label: string;
  lng: number;
  lat: number;
}

export async function searchAddresses(
  query: string,
  signal?: AbortSignal,
): Promise<GeocodeResult[]> {
  const q = query.trim();
  if (q.length < 3) return [];

  const params = new URLSearchParams({ q });
  const res = await fetch(`/api/geocode?${params}`, { signal });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? "Impossible de localiser cette adresse");
  }

  const data = (await res.json()) as { results: GeocodeResult[] };
  return data.results ?? [];
}

export async function reverseGeocodeLocation(
  location: { lng: number; lat: number },
  signal?: AbortSignal,
): Promise<GeocodeResult | null> {
  const params = new URLSearchParams({
    lat: String(location.lat),
    lng: String(location.lng),
  });
  const res = await fetch(`/api/geocode?${params}`, { cache: "no-store", signal });
  if (!res.ok) return null;

  const data = (await res.json()) as { result?: GeocodeResult };
  return data.result ?? null;
}
