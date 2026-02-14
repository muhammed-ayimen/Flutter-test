import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:samansa_flutter_test/graphql/query/trailerVideos.graphql.dart';
import 'package:samansa_flutter_test/page/trailer_view.dart';
import 'package:video_player/controller/controller.dart';

import '../widgets/loading.dart';

const int _pageSize = 10;

class TrailersPage extends HookConsumerWidget {
  const TrailersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentIndex = useState(0);
    final edges = useState<List<Query$trailerVideos$trailerVideos$edges>>([]);
    final isFetchingMore = useState(false);
    // refetch() がキャッシュの同一オブジェクトを返す場合があるため、refreshKey で useEffect を強制再実行する。/ refetch() may return the same cache object, so refreshKey forces useEffect to re-fire.
    final refreshKey = useState(0);

    final queryResult = useQuery$trailerVideos(
      Options$Query$trailerVideos(
        variables: Variables$Query$trailerVideos(first: _pageSize),
      ),
    );

    final loading = queryResult.result.isLoading;
    final hasError = queryResult.result.hasException;

    final data = queryResult.result.parsedData;

    useEffect(() {
      if (data == null) return null;
      final newEdges = data.trailerVideos.edges ?? [];
      if (newEdges.isEmpty) return null;

      final existing = edges.value;
      final existingCursors = existing.map((e) => e.cursor).toSet();
      final toAdd =
          newEdges.where((e) => !existingCursors.contains(e.cursor)).toList();

      if (toAdd.isNotEmpty) {
        edges.value = [...existing, ...toAdd];
      }
      isFetchingMore.value = false;
      return null;
    }, [data, refreshKey.value]);

    if (loading && edges.value.isEmpty) {
      return const Loading();
    }

    if (hasError && edges.value.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppBar(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'エラーが発生しました',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    if (edges.value.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppBar(),
        body: const Center(
          child: Text(
            "動画がありません",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => {
          // データの再取得処理をここに追加
        },
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final trailer = trailers![index].node!;
            return TrailerView(
              trailer: trailer,
              // controller: ここにVideoPlayerControllerを渡す
            );
          },
          itemCount: trailers?.length,
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      title: const Text(
        "Trailers",
        style: TextStyle(
          color: Colors.yellow,
          fontSize: 20,
        ),
      ),
    );
  }
}
