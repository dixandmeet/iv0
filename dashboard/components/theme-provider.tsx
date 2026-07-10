"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useLayoutEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

type Theme = "light" | "dark" | "system";
type ResolvedTheme = "light" | "dark";

type ThemeContextValue = {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  resolvedTheme: ResolvedTheme | undefined;
  systemTheme: ResolvedTheme | undefined;
};

const STORAGE_KEY = "theme";

const ThemeContext = createContext<ThemeContextValue | null>(null);

function getSystemTheme(): ResolvedTheme {
  if (typeof window === "undefined") {
    return "light";
  }

  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function resolveTheme(theme: Theme): ResolvedTheme {
  return theme === "system" ? getSystemTheme() : theme;
}

function applyTheme(theme: ResolvedTheme) {
  const root = document.documentElement;
  root.classList.remove("light", "dark");
  root.classList.add(theme);
  root.style.colorScheme = theme;
}

const useIsomorphicLayoutEffect =
  typeof window === "undefined" ? useEffect : useLayoutEffect;

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>("light");
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme | undefined>(
    undefined,
  );
  const [systemTheme, setSystemTheme] = useState<ResolvedTheme | undefined>(
    undefined,
  );
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    let stored: Theme = "light";

    try {
      stored = (localStorage.getItem(STORAGE_KEY) as Theme | null) ?? "light";
    } catch {
      stored = "light";
    }

    const resolved = resolveTheme(stored);
    setThemeState(stored);
    setResolvedTheme(resolved);
    setSystemTheme(getSystemTheme());
    setMounted(true);
  }, []);

  useIsomorphicLayoutEffect(() => {
    let stored: Theme = "light";

    try {
      stored = (localStorage.getItem(STORAGE_KEY) as Theme | null) ?? "light";
    } catch {
      stored = "light";
    }

    applyTheme(resolveTheme(stored));
  }, []);

  useEffect(() => {
    if (!mounted) {
      return;
    }

    const nextResolved = resolveTheme(theme);
    setResolvedTheme(nextResolved);
    applyTheme(nextResolved);

    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch {
      // Ignore private browsing storage errors.
    }
  }, [theme, mounted]);

  useEffect(() => {
    if (theme !== "system") {
      return;
    }

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    const handleChange = () => {
      const nextSystemTheme = getSystemTheme();
      setSystemTheme(nextSystemTheme);
      setResolvedTheme(nextSystemTheme);
      applyTheme(nextSystemTheme);
    };

    mediaQuery.addEventListener("change", handleChange);
    return () => mediaQuery.removeEventListener("change", handleChange);
  }, [theme]);

  const setTheme = useCallback((nextTheme: Theme) => {
    setThemeState(nextTheme);
  }, []);

  const value = useMemo(
    () => ({
      theme,
      setTheme,
      resolvedTheme,
      systemTheme,
    }),
    [theme, setTheme, resolvedTheme, systemTheme],
  );

  return (
    <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextValue {
  const context = useContext(ThemeContext);

  if (!context) {
    return {
      theme: "light",
      setTheme: () => {},
      resolvedTheme: undefined,
      systemTheme: undefined,
    };
  }

  return context;
}
