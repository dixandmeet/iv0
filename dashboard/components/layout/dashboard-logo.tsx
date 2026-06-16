export function DashboardLogo() {
  return (
    <div className="dashboard-logo">
      <div className="dashboard-logo-icon" aria-hidden>
        <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
          <path
            d="M8 6L14 3L20 6V14L14 21L8 14V6Z"
            stroke="#2563EB"
            strokeWidth="1.5"
            fill="none"
          />
          <path
            d="M14 3V21M8 6L20 14M20 6L8 14"
            stroke="#2563EB"
            strokeWidth="1"
            opacity="0.5"
          />
        </svg>
      </div>
      <div>
        <p className="dashboard-logo-title">Aule</p>
        <p className="dashboard-logo-subtitle">Poste de contrôle · BLX · TTX · SHX</p>
      </div>
    </div>
  );
}
