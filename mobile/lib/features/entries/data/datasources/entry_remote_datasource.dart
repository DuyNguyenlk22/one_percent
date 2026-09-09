import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_utils.dart';
import '../models/habit_entry_model.dart';

/// Check-offs against the NestJS backend.
///
/// Throws [AppException] on failure — mapping to a `Failure` is the
/// repository's job.
abstract interface class EntryRemoteDataSource {
  /// `POST /habits/:id/entries` — idempotent, an upsert on `(habitId, date)`.
  Future<HabitEntryModel> checkOff({
    required String habitId,
    required DateTime date,
  });

  /// `GET /habits/:id/entries?from&to`, both bounds inclusive.
  ///
  /// The endpoint responds `{ "entries": [Date] }` — bare days with no ids.
  Future<List<DateTime>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  });

  /// `DELETE /habits/:id/entries/:date`
  Future<void> deleteEntry({required String habitId, required DateTime date});
}

class EntryRemoteDataSourceImpl implements EntryRemoteDataSource {
  const EntryRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<HabitEntryModel> checkOff({
    required String habitId,
    required DateTime date,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.entries(habitId),
      data: {'date': AppDateUtils.toApiDate(date)},
    );
    return HabitEntryModel.fromJson(json);
  }

  @override
  Future<List<DateTime>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiConstants.entries(habitId),
      queryParameters: {
        'from': AppDateUtils.toApiDate(from),
        'to': AppDateUtils.toApiDate(to),
      },
    );
    final entries = json['entries'] as List<dynamic>? ?? const [];
    return entries
        .map((date) => AppDateUtils.fromApiDate(date as String))
        .toList();
  }

  @override
  Future<void> deleteEntry({
    required String habitId,
    required DateTime date,
  }) async {
    await _client.delete<Map<String, dynamic>>(
      ApiConstants.entry(habitId, AppDateUtils.toApiDate(date)),
    );
  }
}
