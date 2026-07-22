export type NetworkMembershipRole = "owner" | "admin" | "member";

export interface NetworkSummary {
  id: string;
  name: string;
  code: string;
  operator: string | null;
  territory: string | null;
  status: string;
  setupCompletedAt: string | null;
}

export interface NetworkContextValue {
  network: NetworkSummary;
  membershipRole: NetworkMembershipRole;
  canManage: boolean;
  isPilotNetwork: boolean;
  /** Faux lorsque la migration multi-réseaux n'est pas encore déployée. */
  schemaReady: boolean;
}
