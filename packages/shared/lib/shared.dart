/// Cœur commun aux apps Aule (voyageur & pro).
///
/// Contenu volontairement minimal et stable : configuration Supabase, rôles,
/// profil utilisateur et noms de tables. Aucune logique métier spécifique à une
/// app ne doit être ajoutée ici.
library;

export 'src/supabase_config.dart';
export 'src/constants/tables.dart';
export 'src/models/app_user_role.dart';
export 'src/models/user_profile.dart';
