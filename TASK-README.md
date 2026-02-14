# Samansa - Flutter Coding Test

Flutter エンジニア採用のためのコーディングテストリポジトリです。

## 概要

このリポジトリは、予告動画を縦スクロールで閲覧できる単一機能アプリケーションです。
一部の実装が未完成となっており、未完成部分を実装しこのアプリケーションを完成させてください。

## 課題内容

### 必須課題

以下の機能を実装してください:

#### 1. GraphQL ページネーション実装

- `lib/page/trailers_page.dart` の無限スクロール機能を実装
- 重複したデータが表示されないようにする
- 状態管理は Riverpod + Hooks を使用する

#### 2. VideoPlayerController 管理

- `lib/page/trailers_page.dart` および `lib/page/trailer_view.dart` で VideoPlayerController を適切に管理
- 各動画に対して controller を作成・初期化
- メモリリークを防ぐため、適切に dispose
- 表示中の動画のみ再生するように制御
- PageView のスクロールと連携した自動再生・停止

### 技術要件

- **GraphQL**: `graphql_flutter` パッケージを使用
- **状態管理**: Hooks、Riverpod を使用
- **動画再生**: プロジェクトに含まれる `video_player` プラグインを使用

### 完成イメージ動画

https://github.com/user-attachments/assets/cb02ffd6-d241-43b6-8f2e-d1c45311baf7

## セットアップ

このプロジェクトは FVM を使用しています。

```bash
# FVMのインストール (未インストールの場合)
# https://fvm.app/documentation/getting-started/installation

# プロジェクトで指定されたFlutterバージョンをインストール
fvm install

# 依存関係のインストール
fvm flutter pub get

# GraphQLコード生成 (必要に応じて)
fvm flutter pub run build_runner build

# 実行
fvm flutter run
```

**FVM を使わない場合:**
Flutter 3.35.5 以上がインストールされていれば、`fvm` を省いて通常の `flutter` コマンドでも実行可能です。

## GraphQL API

API エンドポイント: `https://develop.api.samansa.com/graphql`

### 使用可能な Query

`trailerVideos` クエリが `lib/graphql/query/trailerVideos.graphql` に定義されています。

```graphql
query trailerVideos($first: Int!, $after: String) {
  trailerVideos(first: $first, after: $after) {
    edges {
      cursor
      node {
        id
        title
        description
        videoUrl
        creator {
          name
        }
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## 提出方法

1. このリポジトリを Fork
2. 実装を完了
3. Pull Request を作成
4. (任意) 実装で工夫した点や設計判断の理由を PR 説明に記載

---

## 提出前チェックリスト

- [ ] 表示中の動画のみ自動再生される
- [ ] 無限スクロールが正しく動作する
- [ ] 重複データが表示されない
- [ ] メモリリークが発生しない
- [ ] Pull-to-refresh が動作する

---

## 参考リンク

- [graphql_flutter Documentation](https://pub.dev/packages/graphql_flutter)
- [flutter_hooks Documentation](https://pub.dev/packages/flutter_hooks)
- [hooks_riverpod Documentation](https://pub.dev/packages/hooks_riverpod)

---

質問がある場合は、Issue を作成してください。
