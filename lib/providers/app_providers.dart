import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/attachment.dart';
import '../models/character.dart';
import '../models/gallery_image.dart';
import '../models/glossary_term.dart';
import '../models/library.dart';
import '../models/link_attachment.dart';
import '../models/metadata.dart';
import '../models/relationship.dart';
import '../models/series.dart';
import '../models/user.dart';
import '../models/volume.dart';
import '../services/auth_service.dart';
import '../services/data_layer.dart';
import '../services/r2_service.dart';
import '../services/turso_client.dart';

// ─── Service Providers ───────────────────────────────────────────────

final tursoClientProvider = Provider<TursoClient>((ref) {
  final client = TursoClient(
    databaseUrl: AppConfig.defaultTursoDatabaseUrl,
    authToken: AppConfig.defaultTursoAuthToken,
  );
  ref.onDispose(() => client.dispose());
  return client;
});

final r2ServiceProvider = Provider<R2Service>((ref) {
  final service = R2Service(
    accountId: AppConfig.defaultR2AccountId,
    accessKeyId: AppConfig.defaultR2AccessKeyId,
    secretAccessKey: AppConfig.defaultR2SecretAccessKey,
    bucketName: AppConfig.defaultR2BucketName,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final authServiceProvider = Provider<AuthService>((ref) {
  final turso = ref.watch(tursoClientProvider);
  return AuthService(turso);
});

final dataLayerProvider = Provider<DataLayer>((ref) {
  final turso = ref.watch(tursoClientProvider);
  return DataLayer(turso);
});

// ─── Theme Mode Provider ─────────────────────────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ─── Auth State Provider ─────────────────────────────────────────────

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _auth;

  AuthStateNotifier(this._auth) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _auth.getSessionUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _auth.signIn(username: username, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String username,
    required String password,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _auth.signUp(
        username: username,
        password: password,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  final auth = ref.watch(authServiceProvider);
  return AuthStateNotifier(auth);
});

// ─── Library Providers ───────────────────────────────────────────────

final librariesProvider = FutureProvider<List<Library>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return [];

  final dataLayer = ref.watch(dataLayerProvider);
  await dataLayer.ensureSchema();
  return dataLayer.librariesGetAll(user.id);
});

final selectedLibraryIdProvider = StateProvider<int?>((ref) => null);

// ─── Filter & View Mode Providers ────────────────────────────────────

enum ViewMode { grid, list }

final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.grid);

class SeriesFilter {
  final String search;
  final String status;
  final String sortBy;
  final bool sortAsc;

  const SeriesFilter({
    this.search = '',
    this.status = 'All',
    this.sortBy = 'title',
    this.sortAsc = true,
  });

  SeriesFilter copyWith({
    String? search,
    String? status,
    String? sortBy,
    bool? sortAsc,
  }) {
    return SeriesFilter(
      search: search ?? this.search,
      status: status ?? this.status,
      sortBy: sortBy ?? this.sortBy,
      sortAsc: sortAsc ?? this.sortAsc,
    );
  }
}

final seriesFilterProvider =
    StateProvider<SeriesFilter>((ref) => const SeriesFilter());

// ─── Series List Provider ────────────────────────────────────────────

final seriesListProvider = FutureProvider<List<Series>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];

  final dataLayer = ref.watch(dataLayerProvider);
  final selectedLib = ref.watch(selectedLibraryIdProvider);
  final filter = ref.watch(seriesFilterProvider);

  return dataLayer.seriesGetAll(
    user.id,
    libraryId: selectedLib,
    status: filter.status,
    search: filter.search,
    sortBy: filter.sortBy,
    sortAsc: filter.sortAsc,
  );
});

// ─── Series Detail Providers ─────────────────────────────────────────

final seriesDetailProvider =
    FutureProvider.family<Series?, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.seriesGetById(seriesId);
});

final seriesVolumesProvider =
    FutureProvider.family<List<Volume>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.volumesGetBySeries(seriesId);
});

final seriesCharactersProvider =
    FutureProvider.family<List<Character>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.charactersGetBySeries(seriesId);
});

final seriesRelationshipsProvider =
    FutureProvider.family<List<Relationship>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.relationshipsGetBySeries(seriesId);
});

final seriesGalleryProvider =
    FutureProvider.family<List<GalleryImage>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.galleryGetBySeries(seriesId);
});

final seriesLinksProvider =
    FutureProvider.family<List<LinkAttachment>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.linksGetBySeries(seriesId);
});

final seriesAttachmentsProvider =
    FutureProvider.family<List<Attachment>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.attachmentsGetBySeries(seriesId);
});

final seriesGlossaryProvider =
    FutureProvider.family<List<GlossaryTerm>, int>((ref, seriesId) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.glossaryGetBySeries(seriesId);
});

// ─── Metadata Lists Providers ────────────────────────────────────────

final userTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.tagsGetAll(user.id);
});

final allGenresProvider = FutureProvider<List<Genre>>((ref) async {
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.genresGetAll();
});

final userContentWarningsProvider =
    FutureProvider<List<ContentWarning>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.contentWarningsGetAll(user.id);
});

// ─── Stats & Global Settings Providers ───────────────────────────────

final allSeriesForStatsProvider = FutureProvider<List<Series>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.seriesGetAll(user.id);
});

final appSettingsProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return {};
  final dataLayer = ref.watch(dataLayerProvider);
  return dataLayer.settingsGetAll(user.id);
});
