import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { loadNetworkContext } from "@/lib/network/server";
import { NetworkSetupWizard } from "@/components/network/network-setup-wizard";

export default async function NetworkConfigurationPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?mode=pro");
  const context = await loadNetworkContext(supabase, user.id);
  if (!context) redirect("/onboarding");
  if (!context.canManage) redirect("/dashboard");
  return <NetworkSetupWizard context={context} />;
}

