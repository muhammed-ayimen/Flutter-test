import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:samansa_flutter_test/graphql/query/trailerVideos.graphql.dart';
import 'package:video_player/controller/video_player_controller.dart';

class TrailerView extends HookConsumerWidget {
  const TrailerView({
    super.key,
    required this.trailer,
    this.controller,
    this.onControllerReady,
    this.onDispose,
  });

  final Query$trailerVideos$trailerVideos$edges$node trailer;
  final VideoPlayerController? controller;
  final void Function(VideoPlayerController)? onControllerReady;
  final void Function()? onDispose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSmall = useMemoized(
      () => MediaQuery.of(context).size.height < 700,
      [context],
    );

    // 最初のコントローラインスタンスを固定 — リビルドを無視して use-after-dispose を防ぐ。/ Lock in the first controller instance — ignores rebuilds to prevent use-after-dispose.
    final lockedController = useMemoized(() => controller);

    useEffect(() {
      if (lockedController == null) return null;
      void listener() {
        if (lockedController.value.initialized) {
          lockedController.removeListener(listener);
          onControllerReady?.call(lockedController);
        }
      }

      lockedController.addListener(listener);
      return () {
        lockedController.removeListener(listener);
        onDispose?.call();
      };
    }, [lockedController]);

    if (lockedController == null) {
      return const ColoredBox(color: Colors.black);
    }

    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          "TrailerViewの実装を完成させてください",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
