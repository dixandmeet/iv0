/** Les données fictives sont réservées au développement local explicite. */
export const demoDataEnabled =
  process.env.NODE_ENV !== "production" &&
  process.env.NEXT_PUBLIC_ENABLE_DEMO_DATA === "true";
