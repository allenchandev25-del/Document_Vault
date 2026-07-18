final profile = userProfile.firstOrNull;
if (profile == null) return "0 GB of 0 GB";
return profile.used_storage_gb.toString() + " GB of " + profile.total_storage_gb.toString() + " GB";