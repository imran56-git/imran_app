library ratings_badges_system;

// ==========================================
// 1. MODELS
// ==========================================
export 'models/badge_model.dart';
export 'models/rating_summary_model.dart';
export 'models/review_model.dart';
export 'models/season_model.dart';

// ==========================================
// 2. UTILS
// ==========================================
export 'utils/rating_calculator.dart';

// ==========================================
// 3. SERVICES
// ==========================================
export 'services/badge_evaluator_service.dart';
export 'services/rating_service.dart';
export 'services/review_service.dart';
export 'services/season_service.dart';
export 'services/verification_service.dart';

// ==========================================
// 4. PROVIDERS / STATE MANAGEMENT
// ==========================================
export 'services/leaderboard_provider.dart';
export 'services/rating_provider.dart';

// ==========================================
// 5. CUSTOM WIDGETS
// ==========================================
export 'widgets/leaderboard_card_widget.dart';
export 'widgets/rating_dialog_widget.dart';
export 'widgets/teacher_badge_widget.dart';
export 'widgets/teacher_card_widget.dart';

// ==========================================
// 6. UI SCREENS
// ==========================================
export 'screens/leaderboard_screen.dart';
export 'screens/teacher_reviews_screen.dart';
