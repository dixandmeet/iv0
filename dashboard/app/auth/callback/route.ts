import { NextResponse } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

const EMAIL_OTP_TYPES = new Set<EmailOtpType>([
  "email",
  "signup",
  "invite",
  "magiclink",
  "recovery",
  "email_change",
]);

function confirmationUrl(requestUrl: URL, status: "success" | "error", message?: string) {
  const url = new URL("/auth/confirmation", requestUrl.origin);
  url.searchParams.set("status", status);
  if (requestUrl.searchParams.get("mode") === "pro") url.searchParams.set("mode", "pro");
  if (message) url.searchParams.set("error", message);
  return url;
}
export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const tokenHash = requestUrl.searchParams.get("token_hash");
  const rawType = requestUrl.searchParams.get("type");
  const supabase = await createClient();

  if (tokenHash && rawType && EMAIL_OTP_TYPES.has(rawType as EmailOtpType)) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: rawType as EmailOtpType,
    });
    if (!error) return NextResponse.redirect(confirmationUrl(requestUrl, "success"));
    return NextResponse.redirect(confirmationUrl(requestUrl, "error", error.message));
  }

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(confirmationUrl(requestUrl, "success"));
    return NextResponse.redirect(confirmationUrl(requestUrl, "error", error.message));
  }

  return NextResponse.redirect(
    confirmationUrl(requestUrl, "error", "Le lien de confirmation est incomplet ou a expiré."),
  );
}
