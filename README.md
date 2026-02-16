# 予告動画閲覧アプリ - Samansa 技術課題 / コーディングテスト

GraphQL APIから取得した予告動画を縦スクロールで閲覧できるFlutterアプリケーション。PageViewによる縦スクロール、無限スクロール（ページネーション）、表示中動画のみの自動再生・停止、およびVideoPlayerControllerの適切なライフサイクル管理を実装しています。

> **Note:** [English version](#trailer-video-app---samansa-coding-challenge) is available below.

## 目次

- [設計概要](#設計概要)
- [プロジェクト構造](#プロジェクト構造)
- [GraphQL利用](#graphql利用)
- [主要な設計判断](#主要な設計判断)
- [セットアップと実行](#セットアップと実行)
- [技術スタック](#技術スタック)

---

## 設計概要

### 定義された要件

仕様に基づき、以下の要件を特定し実装しました:

1. **縦スクロール閲覧** — PageView（縦方向）で予告動画を1本ずつ表示。TikTok/Reels風の体験。
2. **GraphQLページネーション** — `trailerVideos` クエリの `first` / `after` によるカーソルベースの無限スクロール。重複データを防ぐため `cursor` をキーとして管理。
3. **VideoPlayerController管理** — 各動画に対応する controller を `controllerCache` で管理。PageView の `onPageChanged` で表示中の動画のみ再生し、非表示の動画は一時停止。
4. **メモリリーク防止** — `TrailerView` が dispose される際に `onDispose` で controller をキャッシュから削除。次回の訪問時は新規作成で再利用を避ける。
5. **Pull-to-refresh** — RefreshIndicator で一覧を再取得し、状態をリセット。

---

## プロジェクト構造

```
lib/
├── main.dart                          # エントリポイント、GraphQL/Riverpod設定
├── page/
│   ├── trailers_page.dart             # メイン画面：PageView、無限スクロール、controller管理
│   └── trailer_view.dart              # 単一動画カード：VideoPlayer、情報セクション
├── providers/
│   └── graphql_client.dart            # GraphQL クライアント（HiveStore、カスタムHTTPヘッダ）
├── graphql/
│   ├── query/
│   │   ├── trailerVideos.graphql      # ページネーション付きクエリ定義
│   │   └── trailerVideos.graphql.dart # コード生成済み
│   └── schema.graphql
└── widgets/
    ├── info_section.dart              # タイトル、作成者、説明、進捗バー
    ├── hit_area.dart                  # 再生/一時停止タップ領域
    └── loading.dart                  # 初回ローディング表示

plugins/
└── video_player/                      # カスタム動画再生プラグイン
    └── lib/
        ├── controller/               # VideoPlayerController
        ├── player/                   # VideoPlayer ウィジェット
        ├── controls/                 # プログレスバー、全画面、その他UI
        └── ...
```

### 画面フロー

| 画面 | 説明 |
|------|------|
| **TrailersPage** | 縦スクロールの PageView。各ページが TrailerView。スクロール先読みで追加読み込み。 |
| **TrailerView** | 動画プレイヤー（16:9）、タイトル・作成者・説明、プログレスバー。タップで再生/一時停止。 |

---

## GraphQL利用

### 使用クエリ

**`trailerVideos`** — カーソルベースのページネーションで予告動画一覧を取得。

| 引数 | 型 | 説明 |
|------|-----|------|
| `first` | Int | 取得件数（例: 10） |
| `after` | String | 前回の `pageInfo.endCursor`（続き取得時） |

返却される `edges`（`cursor`, `node`）および `pageInfo`（`hasNextPage`, `endCursor`）を使用して無限スクロールを実装しています。

### クエリ例

```graphql
query trailerVideos($first: Int, $after: String) {
  trailerVideos(first: $first, after: $after) {
    edges {
      cursor
      node {
        id
        title
        description
        fileUrl
        creator { name avatar }
        # ... その他フィールド
      }
    }
    pageInfo {
      endCursor
      hasNextPage
    }
  }
}
```

### エンドポイント

`https://develop.api.samansa.com/graphql`

---

## 主要な設計判断

### 1. 重複排除

GraphQL の `refetch` や `fetchMore` がキャッシュ上の同一オブジェクトを返すことがあるため、`edges` をローカル状態で保持し、`cursor` の Set で重複をチェック。既存にない `cursor` のエッジのみ追加。

### 2. 無限スクロールのトリガー

`onPageChanged` 内で、`currentIndex >= edges.length - 3` のときに `fetchMore` を呼び出し。表示終端の3件手前で次ページを先読み。

### 3. refreshKey による強制再実行

`refetch()` がキャッシュの同一オブジェクトを返す場合、`useEffect` の依存が変わらないため再実行されない。`refreshKey` を依存に含め、Pull-to-refresh 時にインクリメントして強制的に再マージ。

### 4. VideoPlayerController のライフサイクル

- **作成:** `controllerFor(cursor, fileUrl)` で `putIfAbsent` による遅延生成。
- **破棄:** `TrailerView` の `onDispose` でキャッシュから削除。VideoPlayer が controller を dispose するため、次回訪問時は新規作成。
- **再生制御:** `onPageChanged` で前のページの controller を `pause()`、現在ページの controller を `play()`。

### 5. lockedController による use-after-dispose 防止

`TrailerView` は `useMemoized(() => controller)` で最初の controller インスタンスを固定。リビルドで `controller` が差し替わっても `lockedController` は変更せず、dispose 済み controller へのアクセスを防ぐ。

### 6. 状態管理（Riverpod + Hooks）

- **Riverpod:** `graphQLClientProvider` で GraphQL クライアントを注入。`useQuery$trailerVideos` でクエリ実行。
- **Hooks:** `useState`, `useEffect`, `useMemoized`, `useRef` でページネーション・controller キャッシュ・ライフサイクルを管理。

---

## セットアップと実行

### 前提条件

- Flutter 3.35.5 以上（推奨: FVM でバージョン管理）
- Dart SDK 3.3.1 以上

### クイックスタート

```bash
# FVM のインストール（未インストールの場合）
# https://fvm.app/documentation/getting-started/installation

# プロジェクトで指定された Flutter バージョンをインストール
fvm install

# 依存関係のインストール
fvm flutter pub get

# GraphQL コード生成（必要に応じて）
fvm flutter pub run build_runner build

# 実行
fvm flutter run
```

FVM を使わない場合: `fvm` を省いて `flutter` コマンドでも実行可能です。

---

## 技術スタック

| コンポーネント | 技術 |
|----------------|------|
| フレームワーク | Flutter |
| 言語 | Dart 3.3.1+ |
| GraphQL | graphql_flutter、graphql_codegen |
| 状態管理 | hooks_riverpod、flutter_hooks |
| 動画再生 | カスタム video_player プラグイン（`plugins/video_player`） |
| キャッシュ | HiveStore（GraphQL） |
| HTTP | http |

---

# Trailer Video App - Samansa Coding Challenge

A Flutter application for browsing trailer videos in a vertical scroll. Fetches data from a GraphQL API and implements infinite scroll pagination, viewport-based auto play/pause, and proper VideoPlayerController lifecycle management.

> **Note:** [日本語版](#予告動画閲覧アプリ---samansa-技術課題--コーディングテスト) is available at the top.

## Table of Contents

- [Design Overview](#design-overview)
- [Project Structure](#project-structure)
- [GraphQL Usage](#graphql-usage)
- [Key Design Decisions](#key-design-decisions)
- [Setup & Running](#setup--running)
- [Tech Stack](#tech-stack)

---

## Design Overview

### Requirements Defined

Based on the specification, the following requirements were identified and implemented:

1. **Vertical Scroll Browsing** — PageView (vertical) displays trailer videos one at a time, similar to TikTok/Reels.
2. **GraphQL Pagination** — Cursor-based infinite scroll with `trailerVideos` query (`first` / `after`). Uses `cursor` as a key to prevent duplicate entries.
3. **VideoPlayerController Management** — Controllers are managed in `controllerCache`. Only the visible video plays; off-screen videos are paused via `onPageChanged`.
4. **Memory Leak Prevention** — When `TrailerView` is disposed, `onDispose` removes the controller from the cache. Next visit creates a fresh controller.
5. **Pull-to-refresh** — RefreshIndicator resets state and refetches the list.

---

## Project Structure

```
lib/
├── main.dart                          # Entry point, GraphQL/Riverpod setup
├── page/
│   ├── trailers_page.dart             # Main screen: PageView, infinite scroll, controller management
│   └── trailer_view.dart              # Single video card: VideoPlayer, info section
├── providers/
│   └── graphql_client.dart            # GraphQL client (HiveStore, custom HTTP headers)
├── graphql/
│   ├── query/
│   │   ├── trailerVideos.graphql      # Paginated query definition
│   │   └── trailerVideos.graphql.dart # Generated code
│   └── schema.graphql
└── widgets/
    ├── info_section.dart              # Title, creator, description, progress bar
    ├── hit_area.dart                  # Tap area for play/pause
    └── loading.dart                  # Initial loading indicator

plugins/
└── video_player/                      # Custom video player plugin
    └── lib/
        ├── controller/               # VideoPlayerController
        ├── player/                   # VideoPlayer widget
        ├── controls/                 # Progress bar, fullscreen, etc.
        └── ...
```

### Screen Flow

| Screen | Description |
|--------|-------------|
| **TrailersPage** | Vertical PageView. Each page is a TrailerView. Preloads next page near scroll end. |
| **TrailerView** | 16:9 video player, title/creator/description, progress bar. Tap to play/pause. |

---

## GraphQL Usage

### Query Used

**`trailerVideos`** — Fetches trailer video list with cursor-based pagination.

| Argument | Type | Description |
|----------|------|-------------|
| `first` | Int | Page size (e.g. 10) |
| `after` | String | Previous `pageInfo.endCursor` (for next page) |

Uses `edges` (`cursor`, `node`) and `pageInfo` (`hasNextPage`, `endCursor`) for infinite scroll.

### Query Example

```graphql
query trailerVideos($first: Int, $after: String) {
  trailerVideos(first: $first, after: $after) {
    edges {
      cursor
      node {
        id
        title
        description
        fileUrl
        creator { name avatar }
        # ... other fields
      }
    }
    pageInfo {
      endCursor
      hasNextPage
    }
  }
}
```

### Endpoint

`https://develop.api.samansa.com/graphql`

---

## Key Design Decisions

### 1. Deduplication

`refetch` and `fetchMore` may return the same cached objects. Local `edges` state is maintained and deduplicated by `cursor`; only edges with new cursors are appended.

### 2. Infinite Scroll Trigger

When `currentIndex >= edges.length - 3`, `fetchMore` is called in `onPageChanged`. Preloads the next page when the user is 3 items from the end.

### 3. refreshKey for Forced Re-run

When `refetch()` returns the same cached object, `useEffect` deps may not change, so it won't re-run. `refreshKey` is included in deps and incremented on pull-to-refresh to force re-merge.

### 4. VideoPlayerController Lifecycle

- **Create:** `controllerFor(cursor, fileUrl)` uses `putIfAbsent` for lazy creation.
- **Dispose:** `TrailerView`'s `onDispose` removes the controller from cache. VideoPlayer disposes the controller; next visit creates a new one.
- **Playback control:** `onPageChanged` pauses the previous page's controller and plays the current one.

### 5. lockedController to Prevent use-after-dispose

`TrailerView` uses `useMemoized(() => controller)` to lock the first controller instance. Rebuilds that pass a different `controller` do not change `lockedController`, avoiding access to a disposed controller.

### 6. State Management (Riverpod + Hooks)

- **Riverpod:** `graphQLClientProvider` injects the GraphQL client. `useQuery$trailerVideos` runs the query.
- **Hooks:** `useState`, `useEffect`, `useMemoized`, `useRef` manage pagination, controller cache, and lifecycle.

---

## Setup & Running

### Prerequisites

- Flutter 3.35.5+ (FVM recommended for version management)
- Dart SDK 3.3.1+

### Quick Start

```bash
# Install FVM (if not installed)
# https://fvm.app/documentation/getting-started/installation

# Install project Flutter version
fvm install

# Install dependencies
fvm flutter pub get

# GraphQL code generation (if needed)
fvm flutter pub run build_runner build

# Run
fvm flutter run
```

Without FVM: Omit `fvm` and use `flutter` directly.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| Language | Dart 3.3.1+ |
| GraphQL | graphql_flutter, graphql_codegen |
| State Management | hooks_riverpod, flutter_hooks |
| Video Playback | Custom video_player plugin (`plugins/video_player`) |
| Cache | HiveStore (GraphQL) |
| HTTP | http |
