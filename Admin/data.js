(function () {
  const DEFAULT_CONFIG = {
    refreshMs: 60000,
    auleApiBaseUrl: "",
    auleApiToken: "",
    okinaBearerToken: "",
    supabase: {
      url: "",
      anonKey: "",
      schema: "public",
      tables: {
        sources: "service_sources",
        services: "transport_services",
        segments: "",
        drivers: "drivers",
      },
      limits: {
        sources: 100,
        services: 3000,
        segments: 1000,
        drivers: 500,
      },
    },
    sources: {
      nantesOpenDataBase: "https://data.nantesmetropole.fr/api/explore/v2.1/catalog/datasets",
      bikeAvailability: "244400404_disponibilite-temps-reel-velos-libre-service-naolib-nantes-metropole",
      bikeAvailabilityFallback: "244400404_stations-velos-libre-service-nantes-metropole-disponibilites",
      parkRelays: "244400404_parcs-relais-nantes-metropole-disponibilites",
      publicParkings: "244400404_parkings-publics-nantes-disponibilites",
      trafficAlerts: "244400404_alertes-info-trafic-nantes-metropole",
      carshareStations: "244400404_stations-autopartage-naolib-nantes-metropole",
      transportRealtimeCatalog: "244400404_services_temps_reel_transports_commun_naolib_nantes_metropole_gtfs_rt",
      transportServicesCatalog: "244400404_reseau-transports-collectifs-naolib",
    },
  };

  const timeoutMs = 9000;

  async function loadConfig() {
    if (window.AULE_ADMIN_CONFIG) {
      const config = window.AULE_ADMIN_CONFIG;
      return {
        ...DEFAULT_CONFIG,
        ...config,
        supabase: {
          ...DEFAULT_CONFIG.supabase,
          ...(config.supabase || {}),
          tables: { ...DEFAULT_CONFIG.supabase.tables, ...(config.supabase?.tables || {}) },
          limits: { ...DEFAULT_CONFIG.supabase.limits, ...(config.supabase?.limits || {}) },
        },
        sources: { ...DEFAULT_CONFIG.sources, ...(config.sources || {}) },
      };
    }

    try {
      const response = await fetch("./config.json", { cache: "no-store" });
      if (!response.ok) throw new Error(`config ${response.status}`);
      const config = await response.json();
      return {
        ...DEFAULT_CONFIG,
        ...config,
        supabase: {
          ...DEFAULT_CONFIG.supabase,
          ...(config.supabase || {}),
          tables: { ...DEFAULT_CONFIG.supabase.tables, ...(config.supabase?.tables || {}) },
          limits: { ...DEFAULT_CONFIG.supabase.limits, ...(config.supabase?.limits || {}) },
        },
        sources: { ...DEFAULT_CONFIG.sources, ...(config.sources || {}) },
      };
    } catch (error) {
      return DEFAULT_CONFIG;
    }
  }

  async function fetchJson(url, options = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
        cache: "no-store",
      });
      if (!response.ok) {
        const body = await response.text().catch(() => "");
        throw new Error(`${response.status} ${response.statusText} ${body}`.trim());
      }
      return await response.json();
    } finally {
      clearTimeout(timer);
    }
  }

  function recordsUrl(config, dataset, limit = 100, extra = "") {
    const base = config.sources.nantesOpenDataBase.replace(/\/$/, "");
    const suffix = extra ? `&${extra.replace(/^\?/, "")}` : "";
    return `${base}/${dataset}/records?limit=${limit}${suffix}`;
  }

  async function safe(label, task) {
    try {
      const data = await task();
      return { label, ok: true, data };
    } catch (error) {
      return { label, ok: false, error: error.message };
    }
  }

  async function loadAuleApi(config) {
    if (!config.auleApiBaseUrl) return { configured: false };
    const base = config.auleApiBaseUrl.replace(/\/$/, "");
    const headers = config.auleApiToken ? { Authorization: `Bearer ${config.auleApiToken}` } : {};
    const [overview, users, marketplace, missions] = await Promise.all([
      safe("aule overview", () => fetchJson(`${base}/admin/overview`, { headers })),
      safe("aule users", () => fetchJson(`${base}/admin/users?limit=50`, { headers })),
      safe("aule marketplace", () => fetchJson(`${base}/admin/marketplace/merchants?limit=50`, { headers })),
      safe("aule missions", () => fetchJson(`${base}/admin/missions?limit=50`, { headers })),
    ]);
    return { configured: true, overview, users, marketplace, missions };
  }

  function supabaseTableUrl(config, table, params) {
    const base = config.supabase.url.replace(/\/$/, "");
    return `${base}/rest/v1/${encodeURIComponent(table)}?${params}`;
  }

  function getCachedSupabaseToken(config) {
    try {
      const cacheKey = `aule-admin-supabase-session:${config.supabase.url}`;
      const cached = JSON.parse(localStorage.getItem(cacheKey) || "null");
      if (!cached?.access_token || !cached?.expires_at) return null;
      if (Date.now() > (Number(cached.expires_at) * 1000) - 60000) return null;
      return cached.access_token;
    } catch (error) {
      return null;
    }
  }

  function setCachedSupabaseToken(config, session) {
    try {
      const cacheKey = `aule-admin-supabase-session:${config.supabase.url}`;
      localStorage.setItem(cacheKey, JSON.stringify({
        access_token: session.access_token,
        expires_at: session.expires_at,
      }));
    } catch (error) {
      // localStorage may be unavailable on some file:// contexts; the in-memory response still works.
    }
  }

  async function getSupabaseAccessToken(config) {
    const cached = getCachedSupabaseToken(config);
    if (cached) return cached;

    const base = config.supabase.url.replace(/\/$/, "");
    const session = await fetchJson(`${base}/auth/v1/signup`, {
      method: "POST",
      headers: {
        apikey: config.supabase.anonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    });

    if (!session?.access_token) {
      throw new Error("Supabase anonymous auth did not return an access token");
    }

    setCachedSupabaseToken(config, session);
    return session.access_token;
  }

  async function fetchSupabaseTable(config, table, params, accessToken) {
    const headers = {
      apikey: config.supabase.anonKey,
      Authorization: `Bearer ${accessToken || config.supabase.anonKey}`,
      Accept: "application/json",
    };

    if (config.supabase.schema && config.supabase.schema !== "public") {
      headers["Accept-Profile"] = config.supabase.schema;
    }

    return fetchJson(supabaseTableUrl(config, table, params), { headers });
  }

  async function fetchSupabaseRows(config, table, baseParams, maxRows, accessToken) {
    const rows = [];
    const requestedMax = Number(maxRows || 1000);
    const pageSize = Math.min(1000, requestedMax);

    while (rows.length < requestedMax) {
      const limit = Math.min(pageSize, requestedMax - rows.length);
      const offset = rows.length;
      const separator = baseParams ? "&" : "";
      const page = await fetchSupabaseTable(
        config,
        table,
        `${baseParams}${separator}limit=${limit}&offset=${offset}`,
        accessToken,
      );

      if (!Array.isArray(page)) return page;
      rows.push(...page);
      if (page.length < limit) break;
    }

    return rows;
  }

  async function loadSupabase(config) {
    if (!config.supabase?.url || !config.supabase?.anonKey) {
      return { configured: false, reason: "Renseigner supabase.url et supabase.anonKey dans config.json" };
    }

    const tables = config.supabase.tables;
    const limits = config.supabase.limits;
    const accessToken = await getSupabaseAccessToken(config);
    const serviceSelect = "select=service_key,source_key,depot_code,depot_name,edition,page_label,source_file,source_page,rlt_code,service_no,first_vehicle,start_time,start_place,end_time,end_place,segment_count,amplitude,temps_conduite,convocation,coupure,pause,nbre_voyages,deplacement,temps_travail,dp,temps_recup,prime_payee";
    const segmentSelect = "select=id,service_key,source_key,source_page,line_index,segment_order,rlt_code,service_no,vehicle,debut_tps_paye,heure_convocation_segment,debut_conduite_heure,debut_conduite_lieu,fin_conduite_heure,fin_conduite_lieu,heure_liberation,fin_tps_paye,duree_piece,nbre_voyages_segment";
    const driverSelect = "select=*";

    const [sources, services, segments, drivers] = await Promise.all([
      safe("Supabase sources", () => fetchSupabaseRows(config, tables.sources, "select=*&order=source_key.asc", limits.sources, accessToken)),
      safe("Supabase services", () => fetchSupabaseRows(config, tables.services, `${serviceSelect}&order=service_key.asc`, limits.services, accessToken)),
      tables.segments
        ? safe("Supabase segments", () => fetchSupabaseRows(config, tables.segments, `${segmentSelect}&order=service_key.asc,segment_order.asc`, limits.segments, accessToken))
        : Promise.resolve({ label: "Supabase segments", ok: true, data: [] }),
      tables.drivers
        ? safe("Supabase conducteurs", () => fetchSupabaseRows(config, tables.drivers, driverSelect, limits.drivers, accessToken))
        : Promise.resolve({ label: "Supabase conducteurs", ok: false, error: "table non configurée" }),
    ]);

    return {
      configured: true,
      url: config.supabase.url,
      schema: config.supabase.schema,
      authenticated: true,
      tables,
      sources,
      services,
      segments,
      drivers,
    };
  }

  async function loadOkinaStatus(config, realtimeCatalog) {
    const feeds = realtimeCatalog?.results || [];
    if (!config.okinaBearerToken) {
      return feeds.map((feed) => ({
        id: feed.id,
        description: feed.description,
        url: feed.url,
        ok: false,
        status: "token requis",
      }));
    }

    return Promise.all(feeds.map(async (feed) => {
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 6000);
        const response = await fetch(feed.url, {
          signal: controller.signal,
          cache: "no-store",
          headers: { Authorization: `Bearer ${config.okinaBearerToken}` },
        });
        clearTimeout(timer);
        return {
          id: feed.id,
          description: feed.description,
          url: feed.url,
          ok: response.ok,
          status: response.ok ? "connecté" : `${response.status}`,
        };
      } catch (error) {
        return {
          id: feed.id,
          description: feed.description,
          url: feed.url,
          ok: false,
          status: error.message,
        };
      }
    }));
  }

  async function loadBikeAvailability(config) {
    const primary = await fetchJson(recordsUrl(config, config.sources.bikeAvailability, 100, "order_by=number"));
    if (primary?.results?.length) {
      return { ...primary, sourceDataset: config.sources.bikeAvailability };
    }

    const fallback = await fetchJson(recordsUrl(config, config.sources.bikeAvailabilityFallback, 100, "order_by=number"));
    return { ...fallback, sourceDataset: config.sources.bikeAvailabilityFallback };
  }

  async function load() {
    const config = await loadConfig();
    const sources = config.sources;

    const [
      bikes,
      parkRelays,
      publicParkings,
      trafficAlerts,
      carshareStations,
      realtimeCatalog,
      transportServices,
      auleApi,
      supabase,
    ] = await Promise.all([
      safe("vélos Naolib", () => loadBikeAvailability(config)),
      safe("P+R Naolib", () => fetchJson(recordsUrl(config, sources.parkRelays, 50))),
      safe("parkings publics", () => fetchJson(recordsUrl(config, sources.publicParkings, 50))),
      safe("alertes trafic", () => fetchJson(recordsUrl(config, sources.trafficAlerts, 30, "order_by=date_notification desc"))),
      safe("autopartage", () => fetchJson(recordsUrl(config, sources.carshareStations, 100))),
      safe("GTFS-RT catalogue", () => fetchJson(recordsUrl(config, sources.transportRealtimeCatalog, 10))),
      safe("services transport", () => fetchJson(recordsUrl(config, sources.transportServicesCatalog, 20))),
      safe("API Aule", () => loadAuleApi(config)),
      safe("Supabase", () => loadSupabase(config)),
    ]);

    const okinaFeeds = await loadOkinaStatus(config, realtimeCatalog.data);

    return {
      config,
      loadedAt: new Date().toISOString(),
      sources: {
        bikes,
        parkRelays,
        publicParkings,
        trafficAlerts,
        carshareStations,
        realtimeCatalog,
        transportServices,
        auleApi,
        supabase,
      },
      okinaFeeds,
    };
  }

  async function loadAndExpose() {
    const data = await load();
    window.AuleLastData = data;
    return data;
  }

  window.AuleData = { load: loadAndExpose };
})();
