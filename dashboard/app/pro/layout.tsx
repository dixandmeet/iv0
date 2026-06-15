import { ProLayout } from "@/components/pro/pro-layout";

export default function ProRootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <ProLayout>{children}</ProLayout>;
}
