/// Shown under the avatar only when neither username nor display name is a real name.
const bilgiProfileNameFallback = 'Avatar';

/// True when [raw] is empty or the generic avatar label.
bool bilgiProfileNameIsPlaceholder(String raw) {
  final name = raw.trim();
  return name.isEmpty || name.toLowerCase() == bilgiProfileNameFallback.toLowerCase();
}

/// Username wins when it is a real name. Display name fills in when the
/// username is missing or is only the word Avatar. Avatar is the last resort.
String bilgiProfileHeading({required String username, String? displayName}) {
  final user = username.trim();
  final display = (displayName ?? '').trim();
  if (!bilgiProfileNameIsPlaceholder(user)) return user;
  if (!bilgiProfileNameIsPlaceholder(display)) return display;
  if (user.isNotEmpty) return user;
  return bilgiProfileNameFallback;
}
