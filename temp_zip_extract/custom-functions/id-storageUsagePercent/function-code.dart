final profile = userProfile.firstOrNull;
if (profile == null) return 0.0;
if (profile.total_storage_gb == 0) return 0.0;
return profile.used_storage_gb / profile.total_storage_gb;