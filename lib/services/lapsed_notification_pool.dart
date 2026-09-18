/// D-049: the static pool a lapsed account's notifications rotate through.
/// No personalization, no user data, no manufactured urgency (P-2) — each
/// entry states something true and offers a way forward (D-012). Every
/// entry's tap action opens the paywall (D-021).
class LapsedNotificationPool {
  LapsedNotificationPool._();

  static const List<String> pool = [
    'Your pyramid still stands',
    'Keep building your foundations',
    'Small steps still matter',
    'Your next step awaits',
    'Return to what matters',
    'Council of Advisors, ready',
  ];

  /// Rotates deterministically across the three-times-daily cadence
  /// (D-021) rather than randomly — [slotIndex] is 0 (morning), 1
  /// (afternoon), or 2 (evening); [dayIndex] lets the rotation advance day
  /// to day so the same three lines don't repeat every day in the same
  /// order.
  static String forSlot({required int slotIndex, required int dayIndex}) {
    final index = (dayIndex * 3 + slotIndex) % pool.length;
    return pool[index];
  }
}
