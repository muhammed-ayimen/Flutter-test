import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:samansa_flutter_test/graphql/query/trailerVideos.graphql.dart';
import 'package:samansa_flutter_test/page/trailer_view.dart';
import 'package:video_player/configurations/configurations.dart';
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

    final controllerCache = useRef<Map<String, VideoPlayerController>>({});

    final queryResult = useQuery$trailerVideos(
      Options$Query$trailerVideos(
        variables: Variables$Query$trailerVideos(first: _pageSize),
      ),
    );

    final data = queryResult.result.parsedData;
    final loading = queryResult.result.isLoading;
    final hasError = queryResult.result.hasException;

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

    void fetchMoreIfNeeded() {
      final pageInfo = data?.trailerVideos.pageInfo;
      if (pageInfo == null || !pageInfo.hasNextPage) return;
      if (isFetchingMore.value) return;

      final threshold = edges.value.length - 3;
      if (currentIndex.value >= threshold) {
        isFetchingMore.value = true;
        queryResult.fetchMore(
          FetchMoreOptions$Query$trailerVideos(
            variables: Variables$Query$trailerVideos(
              first: _pageSize,
              after: pageInfo.endCursor,
            ),
            updateQuery: (previousResult, fetchMoreResult) =>
                fetchMoreResult ?? previousResult,
          ),
        );
      }
    }

    Future<void> refresh() async {
      edges.value = [];
      currentIndex.value = 0;
      await queryResult.refetch();
      refreshKey.value = refreshKey.value + 1;
    }

    VideoPlayerController controllerFor(String cursor, String fileUrl) {
      return controllerCache.value.putIfAbsent(
        cursor,
        () => VideoPlayerController(
          configuration: VideoPlayerConfiguration(
            autoPlay: false,
            hidesControls: true,
            aspectRatio: 16 / 9,
            controlsConfiguration: VideoPlayerControlsConfiguration(
              progressBarPlayedColor: Colors.yellow[600]!,
              progressBarHandleColor: Colors.yellow[600]!,
              progressBarBackgroundColor: Colors.white24,
            ),
          ),
          dataSource: VideoPlayerDataSource(
            sourceType: VideoPlayerDataSourceType.network,
            fileUrl: fileUrl,
          ),
        ),
      );
    }

    if (loading && edges.value.isEmpty) {
      return const Loading();
    }

    if (hasError && edges.value.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'エラーが発生しました',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: refresh,
                child: const Text('再試行'),
              ),
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

    final itemCount = edges.value.length + (isFetchingMore.value ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: Colors.yellow,
        backgroundColor: Colors.black,
        onRefresh: refresh,
        child: PageView.builder(
          controller: pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
          itemCount: itemCount,
          onPageChanged: (index) {
            final prevEdge = edges.value.elementAtOrNull(currentIndex.value);
            if (prevEdge != null) {
              controllerCache.value[prevEdge.cursor]?.pause();
            }
            currentIndex.value = index;
            final nextEdge = edges.value.elementAtOrNull(index);
            if (nextEdge != null) {
              controllerCache.value[nextEdge.cursor]?.play();
            }
            fetchMoreIfNeeded();
          },
          itemBuilder: (context, index) {
            if (index >= edges.value.length) {
              return const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.yellow),
                ),
              );
            }
            final edge = edges.value[index];
            final trailer = edge.node!;
            final fileUrl = trailer.fileUrl;
            return TrailerView(
              key: ValueKey(edge.cursor),
              trailer: trailer,
              controller:
                  fileUrl != null ? controllerFor(edge.cursor, fileUrl) : null,
              onControllerReady: (c) {
                if (currentIndex.value == index) c.play();
              },
              onDispose: () {
                // VideoPlayer がコントローラを破棄するため、次回のために削除。/ VideoPlayer owns disposal; remove from cache so next visit starts fresh.
                controllerCache.value.remove(edge.cursor);
              },
            );
          },
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
