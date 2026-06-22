import { z } from "zod";

export const controlPlanFormSchema = z.object({
  name: z.string().min(3, "Le nom doit contenir au moins 3 caractères"),
  description: z.string().min(10, "Description trop courte"),
  objective: z.string().min(3, "Objectif requis"),
  priority: z.enum(["high", "medium", "low"]),
  start_date: z.string().min(1, "Date de début requise"),
  end_date: z.string().min(1, "Date de fin requise"),
  time_slots: z
    .array(
      z.object({
        label: z.string(),
        start: z.string(),
        end: z.string(),
      }),
    )
    .min(1, "Au moins un créneau horaire"),
  lines: z.array(z.string()).min(1, "Sélectionnez au moins une ligne"),
  stations: z.array(z.string()),
  zone_ids: z.array(z.string()).min(1, "Définissez au moins une zone"),
  team_ids: z.array(z.string()).min(1, "Sélectionnez au moins une équipe"),
  agent_ids: z.array(z.string()).min(1, "Sélectionnez au moins un agent"),
  vehicles: z.array(z.string()),
  general_instructions: z.string().min(5, "Consignes requises"),
  specific_instructions: z.string().optional(),
  auto_generate_missions: z.boolean(),
});

export type ControlPlanFormValues = z.infer<typeof controlPlanFormSchema>;

export const defaultControlPlanFormValues: ControlPlanFormValues = {
  name: "",
  description: "",
  objective: "Lutte contre la fraude",
  priority: "medium",
  start_date: "",
  end_date: "",
  time_slots: [{ label: "Matin", start: "07:00", end: "11:00" }],
  lines: [],
  stations: [],
  zone_ids: [],
  team_ids: [],
  agent_ids: [],
  vehicles: [],
  general_instructions: "",
  specific_instructions: "",
  auto_generate_missions: true,
};
