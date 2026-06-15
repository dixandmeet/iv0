import { Suspense } from "react";
import { CommunicationPageContent } from "@/components/communication/communication-page-content";

export default function CommunicationPage() {
  return (
    <Suspense>
      <CommunicationPageContent />
    </Suspense>
  );
}
