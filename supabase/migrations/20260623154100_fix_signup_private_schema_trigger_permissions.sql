-- Profile inserts/updates run as the signed-in user, but the licence trigger
-- calls helpers in the locked-down private schema. Run the trigger as its owner
-- so signup can create the profile without granting private schema access.
alter function private.prevent_locked_profile_licence_mutation()
  security definer;

revoke all on function private.prevent_locked_profile_licence_mutation()
  from public, anon, authenticated;
