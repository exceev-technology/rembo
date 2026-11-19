// Public settings of the early-access form. Only the PUBLIC anon (or
// publishable) key goes here, never the service_role key: the form can
// only call join_early_access(), which reveals nothing.
// Left empty, the form sends visitors to the GitHub Discussions instead.
window.REMBO_SITE = {
  supabaseUrl: "",
  anonKey: "",
};
