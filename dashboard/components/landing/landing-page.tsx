import { Space_Grotesk } from "next/font/google";
import { ScrollyLanding } from "./scrolly-landing";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

export function LandingPage() {
  return <ScrollyLanding fontClassName={spaceGrotesk.variable} />;
}
