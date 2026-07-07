import type { Metadata } from "next";
import { UpdatePasswordForm } from "./update-password-form";

export const metadata: Metadata = {
  title: "Nouveau mot de passe — Aule",
  description: "Choisissez un nouveau mot de passe pour votre compte Aule.",
};

export default function UpdatePasswordPage() {
  return <UpdatePasswordForm />;
}
