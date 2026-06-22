"use client";

import { useCallback, useEffect, useState } from "react";
import { applyEditedStops } from "@/lib/regulation-stop-edits";
import { applyEditorStateToRegulationLine } from "@/lib/line-editor-persistence";
import type { LineEditorState } from "@/lib/line-editor-types";
import {
  createCustomRegulationLine,
  isCustomRegulationLine,
  loadCustomRegulationLines,
  saveCustomRegulationLines,
  applyLineInfoUpdate,
  type NewLineInput,
} from "@/lib/regulation-custom-line";
import type { RegulationLine, RegulationStop } from "@/lib/regulation-mock-data";

export function useCustomRegulationLines() {
  const [customLines, setCustomLines] = useState<RegulationLine[]>([]);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setCustomLines(loadCustomRegulationLines());
    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) return;
    saveCustomRegulationLines(customLines);
  }, [customLines, ready]);

  const addLine = useCallback((input: NewLineInput) => {
    const line = createCustomRegulationLine(input);
    setCustomLines((prev) => [line, ...prev]);
    return line;
  }, []);

  const deleteLine = useCallback((lineId: string) => {
    if (!isCustomRegulationLine(lineId)) return;
    setCustomLines((prev) => prev.filter((line) => line.id !== lineId));
  }, []);

  const updateLineStops = useCallback((lineId: string, stops: RegulationStop[]) => {
    if (!isCustomRegulationLine(lineId)) return;
    setCustomLines((prev) =>
      prev.map((line) =>
        line.id === lineId ? applyEditedStops(line, stops) : line,
      ),
    );
  }, []);

  const updateLineFromEditor = useCallback(
    (lineId: string, editorState: LineEditorState) => {
      if (!isCustomRegulationLine(lineId)) return;
      setCustomLines((prev) =>
        prev.map((line) =>
          line.id === lineId
            ? applyEditorStateToRegulationLine(line, editorState)
            : line,
        ),
      );
    },
    [],
  );

  const updateLineInfo = useCallback((lineId: string, input: NewLineInput) => {
    if (!isCustomRegulationLine(lineId)) return;
    setCustomLines((prev) =>
      prev.map((line) =>
        line.id === lineId ? applyLineInfoUpdate(line, input) : line,
      ),
    );
  }, []);

  return {
    customLines,
    ready,
    addLine,
    deleteLine,
    updateLineStops,
    updateLineFromEditor,
    updateLineInfo,
  };
}
