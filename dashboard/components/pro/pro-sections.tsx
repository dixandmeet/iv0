import { Building2 } from "lucide-react";

export function ProHero({
  title,
  description,
  icon: Icon = Building2,
}: {
  title: string;
  description: string;
  icon?: React.ComponentType<{ className?: string }>;
}) {
  return (
    <section className="section-padding border-b border-border bg-muted/30">
      <div className="section-container">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <Icon className="h-7 w-7" aria-hidden />
        </div>
        <h1 className="mt-6 text-3xl font-bold tracking-tight sm:text-4xl">
          {title}
        </h1>
        <p className="mt-4 max-w-2xl text-lg text-muted-foreground">
          {description}
        </p>
      </div>
    </section>
  );
}

export function ProFeatureList({
  features,
}: {
  features: { title: string; description: string }[];
}) {
  return (
    <ul className="grid gap-4 sm:grid-cols-2">
      {features.map((f) => (
        <li key={f.title} className="glass-card p-6">
          <h3 className="font-semibold">{f.title}</h3>
          <p className="mt-2 text-sm text-muted-foreground">{f.description}</p>
        </li>
      ))}
    </ul>
  );
}
