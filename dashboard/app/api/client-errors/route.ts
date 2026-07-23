import { NextResponse, type NextRequest } from "next/server";

const MAX_BODY_SIZE = 12_000;
const MAX_FIELD_SIZE = 2_000;

function clean(value: unknown) {
  return typeof value === "string" ? value.slice(0, MAX_FIELD_SIZE) : undefined;
}

export async function POST(request: NextRequest) {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > MAX_BODY_SIZE) {
    return NextResponse.json({ error: "Payload too large" }, { status: 413 });
  }

  const origin = request.headers.get("origin");
  if (origin) {
    try {
      if (new URL(origin).host !== request.nextUrl.host) {
        return NextResponse.json({ error: "Invalid origin" }, { status: 403 });
      }
    } catch {
      return NextResponse.json({ error: "Invalid origin" }, { status: 403 });
    }
  }

  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) return NextResponse.json({ error: "Invalid payload" }, { status: 400 });

  console.error("[aule-client-error]", {
    type: clean(body.type),
    message: clean(body.message),
    path: clean(body.path),
    digest: clean(body.digest),
    stack: clean(body.stack),
    userAgent: clean(request.headers.get("user-agent")),
  });

  return new NextResponse(null, { status: 204 });
}
