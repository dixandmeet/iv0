"use client";

import { useMemo } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import type { ControlPlanMissionView } from "@/lib/control-plans/types";
import { displayStatusColor, displayStatusLabel } from "@/lib/msr-mock-data";

const DAY_LABELS = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];
const HOURS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

interface ControlPlanCalendarProps {
  missions: ControlPlanMissionView[];
  weekStart: Date;
  onWeekChange: (date: Date) => void;
}

function getMonday(d: Date): Date {
  const date = new Date(d);
  const day = date.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0);
  return date;
}

function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

export function ControlPlanCalendar({
  missions,
  weekStart,
  onWeekChange,
}: ControlPlanCalendarProps) {
  const monday = useMemo(() => getMonday(weekStart), [weekStart]);

  const days = useMemo(() => {
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      return d;
    });
  }, [monday]);

  const weekLabel = `${days[0].toLocaleDateString("fr-FR", { day: "numeric", month: "short" })} – ${days[6].toLocaleDateString("fr-FR", { day: "numeric", month: "short", year: "numeric" })}`;

  function prevWeek() {
    const d = new Date(monday);
    d.setDate(d.getDate() - 7);
    onWeekChange(d);
  }

  function nextWeek() {
    const d = new Date(monday);
    d.setDate(d.getDate() + 7);
    onWeekChange(d);
  }

  return (
    <div className="msr-calendar-panel">
      <div className="msr-calendar-header">
        <h3 className="msr-panel-title">Calendrier hebdomadaire</h3>
        <div className="msr-calendar-nav">
          <button type="button" className="msr-btn msr-btn--icon" onClick={prevWeek} aria-label="Semaine précédente">
            <ChevronLeft className="h-4 w-4" />
          </button>
          <span className="msr-calendar-week-label">{weekLabel}</span>
          <button type="button" className="msr-btn msr-btn--icon" onClick={nextWeek} aria-label="Semaine suivante">
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>
      </div>

      <div className="msr-calendar-grid">
        <div className="msr-calendar-corner" />
        {days.map((day, i) => (
          <div key={i} className="msr-calendar-day-header">
            <span className="msr-calendar-day-name">{DAY_LABELS[i]}</span>
            <span className="msr-calendar-day-num">{day.getDate()}</span>
          </div>
        ))}

        {HOURS.map((hour) => (
          <div key={hour} className="msr-calendar-row">
            <div className="msr-calendar-hour">{`${hour}:00`}</div>
            {days.map((day, di) => {
              const cellMissions = missions.filter((m) => {
                const start = new Date(m.start_time);
                return sameDay(start, day) && start.getHours() === hour;
              });

              return (
                <div key={di} className="msr-calendar-cell">
                  {cellMissions.map((m) => {
                    const color = displayStatusColor(m.status);
                    return (
                      <button
                        key={m.id}
                        type="button"
                        className="msr-calendar-event"
                        style={{
                          background: `${color}22`,
                          borderColor: `${color}55`,
                          color: "#e2e8f0",
                        }}
                        title={`${m.title} — ${m.teamName}`}
                      >
                        <span className="msr-calendar-event-title">{m.title}</span>
                        <span className="msr-calendar-event-meta">
                          {displayStatusLabel(m.status)}
                        </span>
                      </button>
                    );
                  })}
                </div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}
