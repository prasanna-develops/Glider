import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:glider/models/search_parameters.dart';
import 'package:glider/pages/item_page.dart';
import 'package:glider/pages/item_search_page.dart';
import 'package:glider/providers/item_provider.dart';
import 'package:glider/widgets/common/refreshable_body.dart';
import 'package:glider/widgets/items/comment_tile_loading.dart';
import 'package:glider/widgets/items/item_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ItemSearchBody extends HookConsumerWidget {
  const ItemSearchBody({Key? key, required this.storyId}) : super(key: key);

  final int storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshableBody<Iterable<int>>(
      provider: itemIdsSearchNotifierProvider(
        SearchParameters(
          query: ref.watch(itemSearchQueryStateProvider).state,
          order: ref.watch(itemSearchOrderStateProvider).state,
          parentStoryId: storyId,
          maxResults: 50,
        ),
      ),
      loadingBuilder: () => <Widget>[
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, __) => const CommentTileLoading(),
          ),
        ),
      ],
      dataBuilder: (Iterable<int> ids) => <Widget>[
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, int index) {
              final int id = ids.elementAt(index);
              return ItemTile(
                id: id,
                onTap: (_) => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ItemPage(id: id)),
                ),
                loading: () => const CommentTileLoading(),
              );
            },
            childCount: ids.length,
          ),
        ),
      ],
    );
  }
}