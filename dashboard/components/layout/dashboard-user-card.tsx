interface DashboardUserCardProps {
  displayName: string;
  role: string;
}

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return name.slice(0, 2).toUpperCase();
}

export function DashboardUserCard({ displayName, role }: DashboardUserCardProps) {
  return (
    <div className="dashboard-user-card">
      <div className="dashboard-user-avatar">{getInitials(displayName)}</div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-white">{displayName}</p>
        <p className="text-xs capitalize text-[#94A3B8]">{role}</p>
      </div>
      <div className="flex items-center gap-1.5">
        <span className="h-2 w-2 rounded-full bg-[#22C55E]" />
        <span className="text-[11px] text-[#22C55E]">En ligne</span>
      </div>
    </div>
  );
}
