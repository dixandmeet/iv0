"use client";

import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { useTheme } from "@/components/theme-provider";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const isDark = resolvedTheme === "dark";

  return (
    <Button
      variant="ghost"
      size="icon"
      className="relative"
      onClick={() => setTheme(isDark ? "light" : "dark")}
      aria-label={
        mounted
          ? isDark
            ? "Activer le mode clair"
            : "Activer le mode sombre"
          : "Changer le thème"
      }
      suppressHydrationWarning
    >
      <Sun
        className={`h-5 w-5 transition-all ${
          mounted && isDark
            ? "rotate-90 scale-0"
            : "rotate-0 scale-100"
        }`}
      />
      <Moon
        className={`absolute h-5 w-5 transition-all ${
          mounted && isDark
            ? "rotate-0 scale-100"
            : "rotate-90 scale-0"
        }`}
      />
    </Button>
  );
}
