import 'dart:async';

import 'package:glider/models/descendant_id.dart';
import 'package:glider/models/item.dart';
import 'package:glider/models/item_tree.dart';
import 'package:glider/models/search_parameters.dart';
import 'package:glider/models/story_type.dart';
import 'package:glider/providers/repository_provider.dart';
import 'package:glider/repositories/api_repository.dart';
import 'package:glider/utils/base_notifier.dart';
import 'package:glider/utils/service_exception.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final StateProvider<int> previewIdStateProvider =
    StateProvider<int>((StateProviderRef<int> ref) => -1);

final AutoDisposeFutureProvider<Iterable<int>> favoriteIdsProvider =
    FutureProvider.autoDispose(
  (AutoDisposeFutureProviderRef<Iterable<int>> ref) =>
      ref.read(storageRepositoryProvider).favoriteIds,
);

final AutoDisposeFutureProviderFamily<Iterable<int>, StoryType>
    storyIdsProvider = FutureProvider.autoDispose.family(
  (AutoDisposeFutureProviderRef<Iterable<int>> ref, StoryType storyType) async {
    final ApiRepository apiRepository = ref.read(apiRepositoryProvider);

    if (storyType == StoryType.newTopStories) {
      final Iterable<int> newStoryIds =
          await apiRepository.getStoryIds(StoryType.newStories);
      final Iterable<int> topStoryIds =
          await apiRepository.getStoryIds(StoryType.topStories);
      return newStoryIds.toSet().intersection(topStoryIds.toSet());
    } else {
      return apiRepository.getStoryIds(storyType);
    }
  },
);

final AutoDisposeFutureProviderFamily<Iterable<int>, SearchParameters>
    storyIdsSearchProvider = FutureProvider.autoDispose.family(
  (AutoDisposeFutureProviderRef<Iterable<int>> ref,
          SearchParameters searchParameters) =>
      ref.read(searchApiRepositoryProvider).searchStoryIds(searchParameters),
);

final AutoDisposeFutureProviderFamily<Iterable<int>, SearchParameters>
    itemIdsSearchProvider = FutureProvider.autoDispose.family(
  (AutoDisposeFutureProviderRef<Iterable<int>> ref,
          SearchParameters searchParameters) =>
      ref.read(searchApiRepositoryProvider).searchItemIds(searchParameters),
);

final StateNotifierProviderFamily<ItemNotifier, AsyncValue<Item>, int>
    itemNotifierProvider = StateNotifierProvider.family(
  (StateNotifierProviderRef<ItemNotifier, AsyncValue<Item>> ref, int id) =>
      ItemNotifier(ref.read, id: id),
);

class ItemNotifier extends BaseNotifier<Item> {
  ItemNotifier(Reader read, {required this.id}) : super(read);

  final int id;

  @override
  Future<Item> getData() => read(apiRepositoryProvider).getItem(id);
}

final AutoDisposeStreamProviderFamily<ItemTree, int> itemTreeStreamProvider =
    StreamProvider.autoDispose
        .family((AutoDisposeStreamProviderRef<ItemTree> ref, int id) async* {
  unawaited(loadItemTree(ref.read, id: id));

  final Stream<DescendantId> descendantIdStream = _itemStream(ref.read, id: id);
  final List<DescendantId> descendantIds = <DescendantId>[];

  await for (final DescendantId descendantId in descendantIdStream) {
    descendantIds.add(descendantId);
    yield ItemTree(descendantIds: descendantIds, done: false);
  }

  yield ItemTree(descendantIds: descendantIds, done: true);
});

Stream<DescendantId> _itemStream(Reader read,
    {required int id, Iterable<int> ancestors = const <int>[]}) async* {
  try {
    yield DescendantId(id: id, ancestors: ancestors);

    final Item item = await read(itemNotifierProvider(id).notifier).load();

    final Iterable<int> childAncestors = <int>[id, ...ancestors];

    for (final int partId in item.parts) {
      yield* _itemStream(read, id: partId, ancestors: childAncestors);
    }

    for (final int kidId in item.kids) {
      yield* _itemStream(read, id: kidId, ancestors: childAncestors);
    }
  } on ServiceException {
    // Fail silently.
  }
}

Future<void> loadItemTree(Reader read, {required int id}) => _loadItemTree(
      (int id) => read(itemNotifierProvider(id).notifier).load(),
      id: id,
    );

Future<void> reloadItemTree(Reader read, {required int id}) => _loadItemTree(
      (int id) => read(itemNotifierProvider(id).notifier).forceLoad(),
      id: id,
    );

Future<void> _loadItemTree(Future<Item> Function(int) getItem,
    {required int id}) async {
  try {
    final Item item = await getItem(id);

    await Future.wait(
      item.parts.map((int partId) => _loadItemTree(getItem, id: partId)),
    );

    await Future.wait(
      item.kids.map((int kidId) => _loadItemTree(getItem, id: kidId)),
    );
  } on ServiceException {
    // Fail silently.
  }
}
