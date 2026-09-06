/// D-063: the static pool a lapsed account's notifications rotate through.
/// No personalization, no user data, no manufactured urgency (P-2) — each
/// entry states something true and offers a way forward (D-014). Every
/// entry's tap action opens the paywall (D-023).
class LapsedNotificationPool {
  LapsedNotificationPool._();

  static const List<String> pool = [
    "You deserve to live your best life. Tap to bring your notifications back to life.",
    "Your pyramid is still standing. The Council has been quiet.",
    "Three things hold up everything else. Tap to hear what the Council noticed.",
    "You built this. Tap to keep building it.",
    "Your foundations are where you left them.",
    "The Council is still here when you want them.",
  ];

  /// Rotates deterministically across the three-times-daily cadence
  /// (D-023) rather than randomly — [slotIndex] is 0 (morning), 1
  /// (afternoon), or 2 (evening); [dayIndex] lets the rotation advance day
  /// to day so the same three lines don't repeat every day in the same
  /// order.
  static String forSlot({required int slotIndex, required int dayIndex}) {
    final index = (dayIndex * 3 + slotIndex) % pool.length;
    return pool[index];
  }
}
