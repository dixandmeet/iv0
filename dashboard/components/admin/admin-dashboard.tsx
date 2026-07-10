"use client";

import type * as React from "react";
import Link from "next/link";
import {
  AlertTriangle,
  Bell,
  BusFront,
  CheckCircle2,
  Circle,
  Package,
  Radio,
  Send,
  ShoppingBag,
  TramFront,
  TriangleAlert,
  Users,
} from "lucide-react";
import {
  adminActivity,
  adminAttentionItems,
  adminBusinessMetrics,
  adminHealthServices,
  adminQuickActions,
  adminUserSegments,
} from "./admin-shell";

const toneMap = {
  green: "border-emerald-400/25 bg-emerald-500/10 text-emerald-100",
  blue: "border-blue-400/25 bg-blue-500/10 text-blue-100",
  amber: "border-amber-400/25 bg-amber-500/10 text-amber-100",
  red: "border-red-400/25 bg-red-500/10 text-red-100",
  violet: "border-violet-400/25 bg-violet-500/10 text-violet-100",
};

const metricIcons = [CheckCircle2, Users, BusFront, Package, AlertTriangle, Bell] as const;

export function AdminDashboard() {
  return (
    <main className="admin-app-content">
      <section className="admin-dashboard-hero">
        <div>
          <div className="inline-flex items-center gap-2 rounded-full border border-emerald-400/25 bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-100">
            <span className="h-2 w-2 rounded-full bg-emerald-400" />
            Plateforme opérationnelle
          </div>
          <h2 className="mt-4 text-3xl font-bold tracking-tight text-white">
            Supervision globale de l&apos;écosystème Aule
          </h2>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-400">
            État des services, activité temps réel, exploitation transport, marketplace
            et alertes système depuis un seul poste de commandement.
          </p>
        </div>
        <div className="admin-health-panel">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
                État de la plateforme
              </p>
              <p className="mt-2 text-4xl font-bold text-white">99.98 %</p>
              <p className="text-xs text-slate-400">Disponible</p>
            </div>
            <Radio className="h-9 w-9 text-emerald-300" />
          </div>
          <div className="mt-4 grid grid-cols-2 gap-2">
            {adminHealthServices.map(([service, status]) => (
              <div key={service} className="flex items-center gap-2 text-xs text-slate-300">
                <span
                  className={
                    status === "ok"
                      ? "h-2 w-2 rounded-full bg-emerald-400"
                      : "h-2 w-2 rounded-full bg-amber-400"
                  }
                />
                {service}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="admin-quick-actions">
        {adminQuickActions.map((action) => (
          <Link key={action.label} href={action.href} className="admin-quick-action">
            <action.icon className="h-4 w-4" />
            <span>{action.label}</span>
          </Link>
        ))}
      </section>

      <section className="grid gap-4 xl:grid-cols-6">
        {adminBusinessMetrics.map((metric, index) => {
          const Icon = metricIcons[index] ?? Circle;
          return (
            <article key={metric.label} className="admin-business-card">
              <div className="flex items-center justify-between">
                <Icon className="h-5 w-5 text-blue-200" />
                <span className={`rounded-full border px-2 py-1 text-[11px] font-semibold ${toneMap[metric.tone]}`}>
                  {metric.detail}
                </span>
              </div>
              <p className="mt-4 text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">
                {metric.label}
              </p>
              <p className="mt-2 text-3xl font-bold tracking-tight text-white">
                {metric.value}
              </p>
            </article>
          );
        })}
      </section>

      <section className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]">
        <RealTimeMapPanel />
        <div className="space-y-4">
          <AdminPanel title="Activité récente">
            <div className="space-y-4">
              {adminActivity.map(([time, text]) => (
                <div key={`${time}-${text}`} className="flex gap-3">
                  <span className="mt-1 text-xs font-semibold text-blue-200">{time}</span>
                  <div className="min-w-0 border-l border-white/10 pl-3">
                    <p className="text-sm text-slate-200">{text}</p>
                  </div>
                </div>
              ))}
            </div>
          </AdminPanel>

          <AdminPanel title="À surveiller">
            <div className="space-y-2">
              {adminAttentionItems.map((item) => (
                <div
                  key={item}
                  className="flex items-center gap-2 rounded-lg border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-sm text-amber-100"
                >
                  <TriangleAlert className="h-4 w-4" />
                  {item}
                </div>
              ))}
            </div>
          </AdminPanel>
        </div>
      </section>

      <section className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
        <AdminPanel title="Utilisateurs par métier">
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {adminUserSegments.map((segment) => (
              <Link key={segment.label} href={segment.href} className="admin-segment-card">
                <span className="text-xs text-slate-500">{segment.label}</span>
                <strong>{segment.value}</strong>
                <span className="text-xs font-semibold text-blue-200">Voir →</span>
              </Link>
            ))}
          </div>
        </AdminPanel>

        <AdminPanel title="Notifications">
          <div className="space-y-3">
            <div className="flex items-center justify-between rounded-lg border border-white/10 bg-white/[0.03] px-3 py-3">
              <span className="text-sm text-slate-300">12 envoyées aujourd&apos;hui</span>
              <Send className="h-4 w-4 text-blue-200" />
            </div>
            <div className="flex items-center justify-between rounded-lg border border-white/10 bg-white/[0.03] px-3 py-3">
              <span className="text-sm text-slate-300">3 campagnes programmées</span>
              <Bell className="h-4 w-4 text-violet-200" />
            </div>
          </div>
        </AdminPanel>
      </section>
    </main>
  );
}

function RealTimeMapPanel() {
  return (
    <section className="admin-map-panel">
      <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
        <div>
          <h3 className="text-sm font-semibold text-white">Carte temps réel</h3>
          <p className="text-xs text-slate-500">Bus · Tram · Taxis · VTC · Marketplace</p>
        </div>
        <span className="rounded-full border border-emerald-400/25 bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-100">
          live
        </span>
      </div>
      <div className="relative min-h-[420px] overflow-hidden bg-[#081426]">
        <div className="absolute inset-0 opacity-45 [background-image:linear-gradient(rgba(255,255,255,.08)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.08)_1px,transparent_1px)] [background-size:44px_44px]" />
        <div className="absolute left-[7%] top-[24%] h-1 w-[78%] rotate-[-8deg] rounded-full bg-blue-400" />
        <div className="absolute left-[13%] top-[68%] h-1 w-[70%] rotate-[14deg] rounded-full bg-emerald-400" />
        <div className="absolute left-[42%] top-[12%] h-[76%] w-1 rotate-[5deg] rounded-full bg-amber-300" />
        <MapMarker left="18%" top="34%" icon={BusFront} label="Bus 241" />
        <MapMarker left="38%" top="52%" icon={TramFront} label="Tram 77" />
        <MapMarker left="64%" top="28%" icon={ShoppingBag} label="Commandes" />
        <MapMarker left="76%" top="64%" icon={BusFront} label="Véhicules" />
        <div className="absolute bottom-5 left-5 max-w-md rounded-lg border border-white/10 bg-black/35 p-4 backdrop-blur">
          <p className="text-sm font-semibold text-white">Aucun véhicule actuellement connecté.</p>
          <p className="mt-1 text-xs leading-5 text-slate-400">
            Les véhicules apparaîtront automatiquement lorsqu&apos;ils seront détectés.
          </p>
        </div>
      </div>
    </section>
  );
}

function MapMarker({
  left,
  top,
  icon: Icon,
  label,
}: {
  left: string;
  top: string;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
}) {
  return (
    <div
      className="absolute flex items-center gap-2 rounded-lg border border-white/15 bg-white/10 px-3 py-2 text-xs font-semibold text-white shadow-lg shadow-black/30 backdrop-blur"
      style={{ left, top }}
    >
      <Icon className="h-4 w-4" />
      {label}
    </div>
  );
}

function AdminPanel({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-lg border border-white/10 bg-white/[0.035]">
      <div className="border-b border-white/10 px-4 py-3">
        <h3 className="text-sm font-semibold text-white">{title}</h3>
      </div>
      <div className="p-4">{children}</div>
    </section>
  );
}
