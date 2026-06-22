export interface DriverRegistrationRequest {
  id: string;
  user_id: string;
  email: string;
  display_name: string | null;
  message: string | null;
  depot_id: string | null;
  depot_name: string | null;
  created_at: string;
}

export interface RegisteredDriver {
  id: string;
  email: string;
  display_name: string | null;
  depot_id: string | null;
  depot_name: string | null;
  created_at: string;
  active_session_id: string | null;
  active_session_status: string | null;
}

export interface DriverLookupResult {
  user_id: string;
  email: string;
  display_name: string | null;
  role: string;
  depot_id: string | null;
  has_pending_request: boolean;
}

export interface DepotOption {
  id: string;
  code: string;
  name: string;
}

export interface AddDriverPayload {
  email: string;
  display_name: string;
  depot_id: string | null;
  invite_if_missing?: boolean;
}

export type DriversPageTab = "sessions" | "roster" | "requests";
