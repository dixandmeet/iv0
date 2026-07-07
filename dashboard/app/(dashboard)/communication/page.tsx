import { Suspense } from "react";
import { WorkspacePageContent } from "@/components/workspace/workspace-page-content";

export default function CommunicationPage() {
  return (
    <Suspense>
      <WorkspacePageContent />
    </Suspense>
  );
}
