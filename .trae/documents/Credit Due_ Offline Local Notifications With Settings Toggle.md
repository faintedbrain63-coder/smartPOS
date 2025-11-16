## Objectives
- Schedule local notifications for credit due dates (offline-only).
- Fire at 8:00 AM local time on the due date (configurable).
- Auto-cancel and reschedule when credits are edited.
- Cancel notifications when a credit is marked paid or deleted.
- Add a Settings toggle to enable/disable credit notifications.

## Package & Initialization
- Dependency: `flutter_local_notifications`.
- Initialize on app startup:
  - Create an `AndroidNotificationChannel` (high importance).
  - Request iOS authorization.
  - Set up timezone handling via `timezone` for accurate local scheduling.
- Service wrapper: `NotificationService` (singleton) with:
  - `init()` to configure plugin/channel.
  - `scheduleCreditDue({required int saleId, required String customerName, required double amount, required DateTime dueDate, int hour=8})`.
  - `cancelForSale(int saleId)`.
  - `rescheduleCreditDue(...)` (cancel + schedule).
  - Use deterministic notification ID equal to `saleId` (no DB mapping needed).

## Scheduling Rules
- On create/edit credit:
  - If notifications enabled and `dueDate != null` and outstanding > 0 → schedule at `dueDate @ 08:00` (local).
  - If dueDate is in the past, do not schedule.
- On update (editCreditSale):
  - Cancel previous `saleId` notification, then schedule new one using the updated values.
- On mark paid/delete:
  - Cancel `saleId` notification immediately.

## Hooks Into Existing Flow
- After sale creation for credits (`SaleProvider.completeSale` when `transactionStatus == 'credit'`): schedule.
- After `SaleRepositoryImpl.editCreditSale` completes: reschedule with the new `dueDate`, amount, customer.
- After `insertCreditPayment` leads to zero outstanding (it already sets `transaction_status='completed'`): cancel.
- After `deleteCreditSale`: cancel.

## Settings Toggle
- New provider `NotificationProvider` backed by `shared_preferences` with key `credit_notifications_enabled`.
  - Expose `bool enabled`, `toggleEnabled(bool)`.
- Settings UI (`SettingsScreen`): add a tile with a `Switch.adaptive` to enable/disable.
- Respect toggle in all scheduling hooks; if disabled, cancel any existing scheduled notifications.

## App Startup Resilience
- On app init, if notifications are enabled:
  - Query local DB for all unpaid credits with future `due_date`.
  - Schedule notifications for each (id = `saleId`) to recover from app restarts.

## Message Format
- Notification content:
  - Title: `Credit due today`
  - Body: `John Doe — ₱450.00`
  - Payload: `{ "saleId": <id> }` (for potential navigation when tapping).

## Platform Notes
- Android: Uses AlarmManager via plugin; exact timing may vary on API ≥31 unless `SCHEDULE_EXACT_ALARM` is granted. No network required.
- iOS: Uses local notifications; request permission at init; no network required.

## Files To Update
- `pubspec.yaml` (add `flutter_local_notifications`, `timezone`).
- `lib/core/services/notification_service.dart` (new singleton service).
- `lib/main.dart` (initialize NotificationService and timezone).
- `lib/presentation/providers/notification_provider.dart` (toggle). 
- `lib/presentation/screens/settings/settings_screen.dart` (toggle UI tile).
- `lib/presentation/providers/sale_provider.dart` (schedule/cancel hooks).
- `lib/data/repositories/sale_repository_impl.dart` (invoke reschedule after edit; cancel after delete/paid paths via provider or a post-transaction callback).

## Testing
- Unit: verify schedule/cancel called on create/edit/markPaid/delete.
- Integration: create credit due tomorrow, ensure notification scheduled; edit due date and confirm reschedule; mark paid/delete and confirm cancellation.

## Acceptance Criteria
- Users receive a local notification at 8:00 AM on due dates for unpaid credits.
- Editing credits reschedules notifications correctly.
- Paid/deleted credits have notifications cancelled immediately.
- Toggle in Settings enables/disables scheduling globally.
- Works entirely offline.