import Link from "next/link";
import styles from "./auth-network-panel.module.css";

type Dot = { cx: number; cy: number; opacity?: number };

type AuthNetworkPanelProps = {
  heading: React.ReactNode;
  tagline: string;
  footnote: string;
  /** Tracé principal (repris aussi pour le fil accentué animé). */
  mainPath: string;
  /** Second tracé, en arrière-plan. */
  secondaryPath: string;
  /** Point pulsé posé sur le tracé principal. */
  accentDot: Dot;
  /** Points fixes complémentaires. */
  fadedDots: Dot[];
  /** Position du dégradé de vignettage, ex. "30% 30%". */
  vignettePosition?: string;
};

export function AuthNetworkPanel({
  heading,
  tagline,
  footnote,
  mainPath,
  secondaryPath,
  accentDot,
  fadedDots,
  vignettePosition = "30% 30%",
}: AuthNetworkPanelProps) {
  return (
    <div className={styles.panel}>
      <svg
        viewBox="0 0 600 900"
        preserveAspectRatio="xMidYMid slice"
        className={styles.networkSvg}
      >
        <path
          d={mainPath}
          fill="none"
          stroke="rgba(255,255,255,0.06)"
          strokeWidth="26"
          strokeLinecap="round"
        />
        <path
          d={secondaryPath}
          fill="none"
          stroke="rgba(255,255,255,0.05)"
          strokeWidth="16"
          strokeLinecap="round"
        />
        <path
          className={styles.driftPath}
          d={mainPath}
          fill="none"
          stroke="#17A08A"
          strokeWidth="3"
          strokeDasharray="10 12"
        />
        <circle
          className={styles.pulseDot}
          cx={accentDot.cx}
          cy={accentDot.cy}
          r="7"
          fill="#33BFA3"
        />
        {fadedDots.map((dot, i) => (
          <circle
            key={i}
            cx={dot.cx}
            cy={dot.cy}
            r="5"
            fill="#fff"
            opacity={dot.opacity ?? 0.85}
          />
        ))}
      </svg>
      <div
        className={styles.vignette}
        style={{
          background: `radial-gradient(ellipse 90% 70% at ${vignettePosition}, transparent 40%, rgba(5,8,7,0.6) 100%)`,
        }}
        aria-hidden
      />

      <div className={styles.content}>
        <Link href="/" data-hover className={styles.logoLink}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/aule-logo.png" alt="Aule" width={32} height={32} className={styles.logoImg} />
          <span className={styles.logoText}>Aule</span>
        </Link>

        <div className={styles.copy}>
          <h1 className={styles.heading}>{heading}</h1>
          <p className={styles.tagline}>{tagline}</p>
        </div>

        <div className={styles.footnote}>
          <span
            className={styles.pulseDot}
            style={{ width: 8, height: 8, borderRadius: "50%", background: "#33BFA3" }}
          />
          {footnote}
        </div>
      </div>
    </div>
  );
}
