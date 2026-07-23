"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useNetwork } from "@/components/network/network-provider";
import { applyEditedStops } from "@/lib/regulation-stop-edits";
import { applyEditorStateToRegulationLine } from "@/lib/line-editor-persistence";
import type { LineEditorState } from "@/lib/line-editor-types";
import {
  createCustomRegulationLine,
  loadCustomRegulationLines,
  saveCustomRegulationLines,
  applyLineInfoUpdate,
  type NewLineInput,
} from "@/lib/regulation-custom-line";
import type { RegulationLine, RegulationStop } from "@/lib/regulation-mock-data";

function persistedId(networkId: string, lineId: string) {
  return `network:${networkId}:${lineId}`;
}

export function useCustomRegulationLines() {
  const { network, canManage, schemaReady } = useNetwork();
  const [customLines, setCustomLines] = useState<RegulationLine[]>([]);
  const [ready, setReady] = useState(false);

  const load = useCallback(async () => {
    if (!schemaReady) {
      setCustomLines(loadCustomRegulationLines(network.id));
      setReady(true);
      return;
    }
    const supabase = createClient();
    const { data } = await supabase
      .from("network_lines")
      .select("line_id, data, editor_state, source, updated_at")
      .eq("network_id", network.id)
      .order("short_name");
    setCustomLines((data ?? []).map((row) => ({
      ...(row.data as RegulationLine),
      routeId: (row.data as RegulationLine).routeId ?? row.line_id,
      editorState: (row.editor_state as LineEditorState | null) ?? null,
      source: row.source as "manual" | "gtfs",
      updatedAt: row.updated_at as string,
    })));
    setReady(true);
  }, [network.id, schemaReady]);

  useEffect(() => { void load(); }, [load]);

  const saveLine = useCallback(async (line: RegulationLine, editorState?: LineEditorState) => {
    if (!schemaReady) {
      const persisted = { ...line, editorState: editorState ?? line.editorState ?? null };
      const next = [persisted, ...loadCustomRegulationLines(network.id).filter((item) => item.id !== line.id)];
      saveCustomRegulationLines(next, network.id);
      return;
    }
    const supabase = createClient();
    const transportMode = line.transportType.toLowerCase().includes("tram") ? "tram"
      : line.transportType.toLowerCase().includes("nav") || line.transportType.toLowerCase().includes("bateau") ? "boat" : "bus";
    const lineId = line.routeId ?? line.shortName;
    const { error } = await supabase.from("network_lines").upsert({
      network_id: network.id,
      line_id: lineId,
      short_name: line.shortName,
      long_name: `${line.origin} ↔ ${line.destination}`,
      transport_mode: transportMode,
      color: line.lineColor ?? "#2563EB",
      source: line.source ?? "manual",
      data: { ...line, editorState: undefined },
      editor_state: editorState ?? line.editorState ?? null,
    }, { onConflict: "network_id,line_id" });
    if (error) throw new Error(error.message);
  }, [network.id, schemaReady]);

  const transportModeOf = (line: RegulationLine) =>
    line.transportType.toLowerCase().includes("tram")
      ? "tram"
      : line.transportType.toLowerCase().includes("nav") ||
          line.transportType.toLowerCase().includes("bateau")
        ? "boat"
        : "bus";

  // Persiste n'importe quelle ligne (y compris une ligne réseau GTFS éditée)
  // dans network_lines, en gardant l'id composite comme clé. La RPC upsert est
  // SECURITY DEFINER : elle autorise les superviseurs/régulateurs, alors que
  // l'upsert direct exigerait un rôle owner/admin (RLS managers).
  const persistLine = useCallback(
    async (line: RegulationLine, editorState?: LineEditorState | null) => {
      const persisted: RegulationLine = {
        ...line,
        editorState: editorState ?? line.editorState ?? null,
        updatedAt: new Date().toISOString(),
      };

      setCustomLines((prev) => [
        persisted,
        ...prev.filter((item) => item.id !== persisted.id),
      ]);

      if (!schemaReady) {
        const next = [
          persisted,
          ...loadCustomRegulationLines(network.id).filter(
            (item) => item.id !== persisted.id,
          ),
        ];
        saveCustomRegulationLines(next, network.id);
        return;
      }

      const supabase = createClient();
      const { error } = await supabase.rpc("upsert_network_line", {
        p_line_id: persisted.id,
        p_short_name: persisted.shortName,
        p_long_name: `${persisted.origin} ↔ ${persisted.destination}`,
        p_transport_mode: transportModeOf(persisted),
        p_color: persisted.lineColor ?? "#2563EB",
        p_source: persisted.source ?? "gtfs",
        p_data: { ...persisted, editorState: undefined },
        p_editor_state: editorState ?? persisted.editorState ?? null,
      });
      if (error) throw new Error(error.message);
    },
    [network.id, schemaReady],
  );

  const addLine = useCallback(async (input: NewLineInput) => {
    if (!canManage) throw new Error("Accès administrateur réseau requis");
    const base = createCustomRegulationLine(input);
    const lineId = input.shortName.trim();
    const line = { ...base, id: persistedId(network.id, lineId), routeId: lineId };
    await saveLine(line);
    setCustomLines((prev) => [line, ...prev.filter((item) => item.id !== line.id)]);
    return line;
  }, [canManage, network.id, saveLine]);

  const deleteLine = useCallback(async (lineId: string) => {
    if (!canManage) return;
    const line = customLines.find((item) => item.id === lineId);
    if (!line) return;
    if (!schemaReady) {
      const next = customLines.filter((item) => item.id !== lineId);
      saveCustomRegulationLines(next, network.id);
      setCustomLines(next);
      return;
    }
    const supabase = createClient();
    const { error } = await supabase
      .from("network_lines")
      .delete()
      .eq("network_id", network.id)
      .eq("line_id", line.routeId ?? line.shortName);
    if (error) throw new Error(error.message);
    setCustomLines((prev) => prev.filter((item) => item.id !== lineId));
  }, [canManage, customLines, network.id, schemaReady]);

  const updateLineLifecycle = useCallback(async (
    lineId: string,
    lifecycleStatus: NonNullable<RegulationLine["lifecycleStatus"]>,
  ) => {
    if (!canManage) throw new Error("Accès administrateur réseau requis");
    const current = customLines.find((line) => line.id === lineId);
    if (!current) throw new Error("Cette ligne n’est pas modifiable dans ce catalogue.");
    const updated: RegulationLine = {
      ...current,
      lifecycleStatus,
      updatedAt: new Date().toISOString(),
    };
    await saveLine(updated, current.editorState ?? undefined);
    setCustomLines((prev) => prev.map((line) => line.id === lineId ? updated : line));
  }, [canManage, customLines, saveLine]);

  const updateLineStops = useCallback(async (lineId: string, stops: RegulationStop[]) => {
    const current = customLines.find((line) => line.id === lineId);
    if (!current) return;
    const updated = applyEditedStops(current, stops);
    setCustomLines((prev) => prev.map((line) => line.id === lineId ? updated : line));
    await saveLine(updated);
  }, [customLines, saveLine]);

  const updateLineFromEditor = useCallback(async (lineId: string, editorState: LineEditorState) => {
    const current = customLines.find((line) => line.id === lineId);
    if (!current) throw new Error("Cette ligne n’est pas disponible dans le catalogue du réseau.");
    const updated = {
      ...applyEditorStateToRegulationLine(current, editorState),
      editorState,
    };
    setCustomLines((prev) => prev.map((line) => line.id === lineId ? updated : line));
    if (!schemaReady) {
      await saveLine(updated, editorState);
      return;
    }

    const supabase = createClient();
    const { error } = await supabase.rpc("save_line_editor_state", {
      p_line_id: current.routeId ?? current.shortName,
      p_editor_state: editorState,
    });
    if (error) throw new Error(error.message);
  }, [customLines, saveLine, schemaReady]);

  const updateLineInfo = useCallback(async (lineId: string, input: NewLineInput) => {
    const current = customLines.find((line) => line.id === lineId);
    if (!current) return;
    const updated = applyLineInfoUpdate(current, input);
    setCustomLines((prev) => prev.map((line) => line.id === lineId ? updated : line));
    await saveLine(updated);
  }, [customLines, saveLine]);

  return {
    customLines,
    ready,
    addLine,
    deleteLine,
    updateLineLifecycle,
    updateLineStops,
    updateLineFromEditor,
    updateLineInfo,
    persistLine,
    refresh: load,
  };
}
