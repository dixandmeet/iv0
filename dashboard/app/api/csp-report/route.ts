import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > 12_000) {
    return NextResponse.json({ error: "Payload too large" }, { status: 413 });
  }

  const report = await request.json().catch(() => null);
  if (report) console.error("[aule-csp-violation]", report);
  return new NextResponse(null, { status: 204 });
}
