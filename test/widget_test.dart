import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaarchive_mobile/main.dart';
import 'package:myaarchive_mobile/models/user.dart';
import 'package:myaarchive_mobile/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Override auth state with a mock/empty user to prevent async network timers in tests
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _MockAuthStateNotifier(),
          ),
        ],
        child: const MyaarchiveApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(MyaarchiveApp), findsOneWidget);
  });
}

class _MockAuthStateNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthStateNotifier {
  _MockAuthStateNotifier() : super(const AsyncValue.data(null));

  @override
  Future<void> signIn(String username, String password) async {}

  @override
  Future<void> signUp({
    required String username,
    required String password,
    String? securityQuestion,
    String? securityAnswer,
  }) async {}

  @override
  Future<void> signOut() async {}
}
