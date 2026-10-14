# 変更履歴

このプロジェクトの利用者に関係する変更を記録します。
書式は [Keep a Changelog 1.1.0](https://keepachangelog.com/ja/1.1.0/) に基づき、版は [Semantic Versioning 2.0.0](https://semver.org/lang/ja/) に従います。

運用済みの構成を1.0.0から管理します。本体版の正本は [VERSION](VERSION) です。今回の版整合は公開前のため `Unreleased` に置きます。過去の公開版・公開日・タグは補完しません。実機の受け入れ日は [検証履歴](docs/VERIFICATION.md) に記録し、リリース日と区別します。

## [Unreleased]

### Fixed（修正）

- Linux版で終了済みブラウザーのロックが残ると再起動できない問題を修正。同一ホスト・不存在PIDを確認できる場合だけChromium自身の回復へ進み、ロックや認証データは削除しません。本体と両拡張を1.1.2へ更新。

- Linux版の配信起動時にChrome for Testingの案内バーがゲーム領域を狭める問題に対応し、`--disable-infobars` を追加。初回設定用の通常起動は維持。本体と両拡張の版を1.1.1に統一。

### Added（追加）

- Ubuntu/GNOME WaylandのミニPC向けに、専用ブラウザーの通常起動・全画面起動、読取り専用診断、SunshineのアプリCommand生成を追加。Linuxでは配信終了時に専用ブラウザーを閉じます。
- 既存ゲーム切り出しCSSを使うLinux表示拡張、初回ログイン・手動拡張導入・終了復旧の手順、画面操作なしのPython検査とLinux CIを追加。実ゲーム・Moonlight受け入れは未確認。

- MITライセンスの `LICENSE` を追加し、README・AI向け指示・パッケージのライセンス表記を統一。
- 本体の版を示す `VERSION` と、本体・任意拡張・生成manifestの版一致の検査。
- 開発時の検査・CI・独立レビュー手順と、証拠の種類を分けた検証履歴。

### Changed（変更）

- Linux版の後方互換な追加に合わせ、本体と両拡張を1.1.0へ更新。Windows版の起動・復元と既存カードの挙動は維持。

- 本体と任意のカーソル補助拡張を1.0.0に統一。拡張manifestの旧表記0.1.0は過去リリースとして扱わない。
- READMEを基本導入、拡張READMEを任意拡張の導入・解除、AGENTSをAI規則の入口に整理。古い未実施記述を受け入れ済みの結果と照合し、試験の失敗・未確認点を検証履歴へ集約。

Windows版の起動・全画面・復元・カーソル判定の挙動と、既存Chrome/Sunshineの実設定は変更していません。

[Unreleased]: https://github.com/riyonasan/pjivn-moonlight-helper/compare/03fc826...HEAD
