"use client";

import Link from "next/link";
import { Space_Grotesk } from "next/font/google";
import type { ReactNode } from "react";
import styles from "./auth-form.module.css";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

type AuthShellProps = {
  brandPanel: ReactNode;
  children: ReactNode;
};

/** Structure commune aux écrans d'authentification : panneau de marque + formulaire. */
export function AuthShell({ brandPanel, children }: AuthShellProps) {
  return (
    <div className={`${styles.root} ${spaceGrotesk.variable}`}>
      <div className={styles.brandPanelWrap}>{brandPanel}</div>

      <div className={styles.formPanel}>
        <div className={styles.formInner}>
          <Link href="/" data-hover className={`${styles.mobileLogo} ${styles.mobileLogoLink}`}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/aule-logo.png" alt="Aule" width={30} height={30} style={{ objectFit: "contain" }} />
            <span style={{ fontWeight: 600, fontSize: 18 }}>Aule</span>
          </Link>
          {children}
        </div>
      </div>
    </div>
  );
}
