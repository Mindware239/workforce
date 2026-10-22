import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// Performance reviews — backend/modules/reviews (mounted at /api/reviews).
///
/// Lists (`/mine`, `/team`) return rows with: id, cycleName, cycleStatus
/// (active|closed), periodStart, periodEnd, selfReviewDue, managerReviewDue,
/// fullName, employeeCode, managerName, goalsStatus (draft|submitted|approved),
/// selfSubmittedAt, managerSubmittedAt, finalizedAt, acknowledgedAt,
/// finalScore, goalCount, stage.
///
/// One review (`GET /:id`, and every write below) returns
/// `{ review, goals, weightTotal, viewer: employee|manager|admin, permissions }`;
/// the server decides what the caller may do and hides what they may not see.
class ReviewRepository {
  final ApiClient apiClient;

  ReviewRepository({required this.apiClient});

  static const List<String> recommendations = ['none', 'increment', 'promotion'];

  Future<List<Map<String, dynamic>>> getMine() async {
    try {
      final response = await apiClient.get('/reviews/mine');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your reviews.');
    }
  }

  /// Reviews where the caller is the reporting manager (empty for most).
  Future<List<Map<String, dynamic>>> getTeam() async {
    try {
      final response = await apiClient.get('/reviews/team');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your team\'s reviews.');
    }
  }

  Future<ReviewView> getReview(int id) =>
      _view(() => apiClient.get('/reviews/$id'), 'Unable to load the review.');

  // ============================================================
  // GOALS
  // ============================================================

  /// POST /api/reviews/:id/goals — title 1-200, weight (0, 100],
  /// description <= 4000, target <= 500.
  Future<ReviewView> addGoal(int id, Map<String, dynamic> goal) => _view(
        () => apiClient.post('/reviews/$id/goals', data: goal),
        'Unable to add the goal.',
      );

  Future<ReviewView> updateGoal(
    int id,
    int goalId,
    Map<String, dynamic> goal,
  ) =>
      _view(
        () => apiClient.put('/reviews/$id/goals/$goalId', data: goal),
        'Unable to update the goal.',
      );

  Future<ReviewView> removeGoal(int id, int goalId) => _view(
        () => apiClient.delete('/reviews/$id/goals/$goalId'),
        'Unable to remove the goal.',
      );

  /// Weights must add up to exactly 100%.
  Future<ReviewView> submitGoals(int id) => _view(
        () => apiClient.post('/reviews/$id/goals/submit'),
        'Unable to submit the goals.',
      );

  Future<ReviewView> approveGoals(int id) => _view(
        () => apiClient.post('/reviews/$id/goals/approve'),
        'Unable to approve the goals.',
      );

  Future<ReviewView> reopenGoals(int id) => _view(
        () => apiClient.post('/reviews/$id/goals/reopen'),
        'Unable to reopen the goals.',
      );

  // ============================================================
  // RATINGS
  // ============================================================

  /// PUT /api/reviews/:id/self
  ///   { submit, goals: [{ id, rating 1-5, comment }], overallComments }
  Future<ReviewView> saveSelf(
    int id, {
    required bool submit,
    required List<Map<String, dynamic>> goals,
    required String overallComments,
  }) =>
      _view(
        () => apiClient.put(
          '/reviews/$id/self',
          data: {
            'submit': submit,
            'goals': goals,
            'overallComments': overallComments,
          },
        ),
        'Unable to save the self review.',
      );

  /// PUT /api/reviews/:id/manager
  ///   { submit, goals, overallRating, strengths, improvements,
  ///     recommendation: none|increment|promotion, incrementPercent }
  Future<ReviewView> saveManager(
    int id, {
    required bool submit,
    required List<Map<String, dynamic>> goals,
    int? overallRating,
    required String strengths,
    required String improvements,
    required String recommendation,
    num? incrementPercent,
  }) =>
      _view(
        () => apiClient.put(
          '/reviews/$id/manager',
          data: {
            'submit': submit,
            'goals': goals,
            'overallRating': overallRating,
            'strengths': strengths,
            'improvements': improvements,
            'recommendation': recommendation,
            'incrementPercent':
                recommendation == 'none' ? null : incrementPercent,
          },
        ),
        'Unable to save the manager review.',
      );

  /// POST /api/reviews/:id/acknowledge { comment }
  Future<ReviewView> acknowledge(int id, String? comment) => _view(
        () => apiClient.post(
          '/reviews/$id/acknowledge',
          data: {
            if (comment != null && comment.trim().isNotEmpty)
              'comment': comment.trim(),
          },
        ),
        'Unable to acknowledge the review.',
      );

  Future<ReviewView> _view(
    Future<dynamic> Function() call,
    String fallback,
  ) async {
    try {
      final response = await call();

      return ReviewView.fromJson(asMap(unwrapData(response.data)));
    } catch (e) {
      throw apiException(e, fallback);
    }
  }
}

/// One review as the caller may see it.
class ReviewView {
  final Map<String, dynamic> review;
  final List<Map<String, dynamic>> goals;
  final num weightTotal;

  /// employee | manager | admin
  final String viewer;
  final Map<String, dynamic> permissions;

  const ReviewView({
    required this.review,
    required this.goals,
    required this.weightTotal,
    required this.viewer,
    required this.permissions,
  });

  factory ReviewView.fromJson(Map<String, dynamic> json) {
    final total = json['weightTotal'];

    return ReviewView(
      review: asMap(json['review']),
      goals: asMapList(json['goals']),
      weightTotal: total is num ? total : num.tryParse('$total') ?? 0,
      viewer: json['viewer']?.toString() ?? 'employee',
      permissions: asMap(json['permissions']),
    );
  }

  bool can(String permission) => permissions[permission] == true;

  bool get isEmployee => viewer == 'employee';

  bool get weightsBalanced => (weightTotal - 100).abs() <= 0.01;
}
