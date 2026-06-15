/** Erreurs Supabase fréquentes côté dashboard régulateur. */
export function isMissingTableError(message: string): boolean {
  return (
    message.includes("does not exist") ||
    message.includes("42P01") ||
    message.includes("Could not find the table")
  );
}

export function isRelationshipError(message: string): boolean {
  return (
    message.includes("Could not find a relationship") ||
    message.includes("PGRST200")
  );
}
