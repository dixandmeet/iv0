import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

type ServingLineRow = {
  route_short_name?: string | null;
};

export async function GET(request: Request) {
  const ids = [...new Set(
    (new URL(request.url).searchParams.get("ids") ?? "")
      .split(",")
      .map((id) => id.trim())
      .filter(Boolean),
  )].slice(0, 10);

  if (!ids.length) {
    return NextResponse.json({ linesByStopId: {} });
  }

  try {
    const supabase = await createClient();
    const entries = await Promise.all(
      ids.map(async (stopId) => {
        const { data, error } = await supabase.rpc("get_stop_serving_lines", {
          p_stop_id: stopId,
        });
        if (error) throw error;

        const lines = [...new Set(
          ((data as ServingLineRow[] | null) ?? [])
            .map((row) => row.route_short_name?.trim())
            .filter((line): line is string => Boolean(line)),
        )].sort((a, b) => a.localeCompare(b, "fr", { numeric: true }));

        return [stopId, lines] as const;
      }),
    );

    return NextResponse.json({ linesByStopId: Object.fromEntries(entries) });
  } catch {
    return NextResponse.json(
      { error: "Lignes desservant les arrêts indisponibles" },
      { status: 502 },
    );
  }
}
