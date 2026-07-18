final all = files.where((f) => f.category == "Photos").toList();
final filter = galleryFilter;
if (filter == "All Photos" || filter == "All") return all;
if (filter == "Favorites") return all.where((f) => f.isFavorite).toList();
return all;