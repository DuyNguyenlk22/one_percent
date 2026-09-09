import 'package:mobile/core/network/network_info.dart';
import 'package:mobile/features/entries/data/datasources/entry_remote_datasource.dart';
import 'package:mobile/features/entries/data/models/habit_entry_model.dart';
import 'package:mobile/features/entries/domain/repositories/entry_repository.dart';
import 'package:mobile/features/habits/data/datasources/habit_remote_datasource.dart';
import 'package:mobile/features/habits/data/models/daily_habit_model.dart';
import 'package:mobile/features/habits/data/models/habit_model.dart';
import 'package:mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:mobile/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/models/user_model.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Shared test doubles.
///
/// Mocks live here rather than in individual test files so a change to an
/// interface is fixed once.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockHabitRemoteDataSource extends Mock implements HabitRemoteDataSource {}

class MockEntryRemoteDataSource extends Mock implements EntryRemoteDataSource {}

class MockHabitRepository extends Mock implements HabitRepository {}

class MockEntryRepository extends Mock implements EntryRepository {}

/// A representative user, so tests do not each invent their own.
UserModel buildUserModel({
  String id = '11111111-1111-4111-8111-111111111111',
  String email = 'alex.bloom@example.com',
  DateTime? createdAt,
}) {
  return UserModel(
    id: id,
    email: email,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

/// Registers fallbacks for any type passed to a mocktail matcher.
/// Call once from a test file's `setUpAll`.
/// A representative habit, so tests do not each invent their own.
HabitModel buildHabitModel({
  String id = 'bbbbbbbb-0000-4000-8000-000000000001',
  String userId = '11111111-1111-4111-8111-111111111111',
  String name = 'Read',
  String? color = '#4D6054',
  DateTime? createdAt,
  DateTime? archivedAt,
}) {
  return HabitModel(
    id: id,
    userId: userId,
    name: name,
    color: color,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    archivedAt: archivedAt,
  );
}

/// A representative decorated habit.
DailyHabitModel buildDailyHabit({
  HabitModel? habit,
  bool doneToday = false,
  int currentStreak = 0,
}) {
  return DailyHabitModel(
    habit: habit ?? buildHabitModel(),
    doneToday: doneToday,
    currentStreak: currentStreak,
  );
}

/// A representative entry.
HabitEntryModel buildHabitEntryModel({
  String id = 'eeeeeeee-0000-4000-8000-000000000001',
  String habitId = 'bbbbbbbb-0000-4000-8000-000000000001',
  DateTime? date,
  DateTime? createdAt,
}) {
  return HabitEntryModel(
    id: id,
    habitId: habitId,
    date: date ?? DateTime(2026, 3, 10),
    createdAt: createdAt ?? DateTime.utc(2026, 3, 10, 8),
  );
}

void registerFallbacks() {
  registerFallbackValue(buildUserModel());
  registerFallbackValue(buildHabitModel());
  registerFallbackValue(DateTime(2026, 1, 1));
}
