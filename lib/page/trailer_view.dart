import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:samansa_flutter_test/graphql/query/trailerVideos.graphql.dart';
import 'package:video_player/controller/video_player_controller.dart';
import 'package:video_player/controller/video_player_value.dart';
import 'package:video_player/controls/controls.dart';
import 'package:video_player/player/video_player.dart';

import '../widgets/hit_area.dart';
import '../widgets/info_section.dart';

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

    return VideoPlayerControllerProvider(
      controller: lockedController,
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(
                      controller: lockedController,
                      noProvider: true,
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: lockedController,
                      builder: (context, value, child) {
                        return TrailerHitArea(
                          onTap: () {
                            if (value.isPlaying) {
                              lockedController.pause();
                            } else {
                              lockedController.play();
                            }
                          },
                        );
                      },
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: lockedController,
                      builder: (context, value, child) {
                        if (value.initialized) return const SizedBox.shrink();
                        if (value.errorDescription != null) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '動画を再生できません',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.yellow,
                          ),
                        );
                      },
                    ),
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: MoreButton(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TrailerInfoSection(
                  isSmall: isSmall,
                  trailer: trailer,
                  controller: lockedController,
                ),
              ),
              SizedBox(
                height: 42,
                width: MediaQuery.of(context).size.width,
                child: const MaterialVideoProgressBar(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
