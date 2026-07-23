"use client";

import { createContext, useContext, type ReactNode } from "react";
import type { NetworkContextValue } from "@/lib/network/types";

const NetworkContext = createContext<NetworkContextValue | null>(null);

export function NetworkProvider({
  value,
  children,
}: {
  value: NetworkContextValue;
  children: ReactNode;
}) {
  return <NetworkContext.Provider value={value}>{children}</NetworkContext.Provider>;
}

export function useNetwork(): NetworkContextValue {
  const value = useContext(NetworkContext);
  if (!value) throw new Error("useNetwork doit être utilisé dans un <NetworkProvider>");
  return value;
}
