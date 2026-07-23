import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { EmailConfirmationResult } from "@/components/auth/email-confirmation-result";

export const metadata: Metadata = {
  title: "Adresse e-mail confirmée — Aule",
  description: "Confirmation de votre adresse e-mail Aule.",
};

type ConfirmationPageProps = {
  searchParams: Promise<{ status?: string; error?: string; mode?: string }>;
};

export default async function EmailConfirmationPage({ searchParams }: ConfirmationPageProps) {
  const params = await searchParams;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const success = params.status === "success";
  const proMode = params.mode === "pro";
  const destination = user
    ? "/dashboard"
    : `/login${proMode ? "?mode=pro&confirmed=1" : "?confirmed=1"}`;

  return (
    <EmailConfirmationResult
      success={success}
      authenticated={Boolean(user)}
      destination={destination}
      error={params.error ?? null}
    />
  );
}
