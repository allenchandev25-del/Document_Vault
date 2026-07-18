final all = files;
final q = searchQuery.toLowerCase();
final t = typeFilter;
final s = securityFilter;

return all.where((f) {
 final nameMatch = q.isEmpty || f.name.toLowerCase().contains(q);
 final typeMatch = t == "All" || f.type == t;
 final securityMatch = s == "all" || (s == "encrypted" && f.isEncrypted);
 return nameMatch && typeMatch && securityMatch;
}).toList();