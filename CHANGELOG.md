# 変更履歴

このプロジェクトの利用者に関係する変更を記録します。
書式は [Keep a Changelog 1.1.0](https://keepachangelog.com/ja/1.1.0/) に基づき、版は [Semantic Versioning 2.0.0](https://semver.org/lang/ja/) に従います。

運用済みの構成を1.0.0から管理します。本体版の正本は [VERSION](VERSION) です。今回の版整合は公開前のため `Unreleased` に置きます。過去の公開版・公開日・タグは補完しません。実機の受け入れ日は [検証履歴](docs/VERIFICATION.md) に記録し、リリース日と区別します。

## [Unreleased]

### Added（追加）

- 本体の版を示す `VERSION` と、本体・任意拡張・生成manifestの版一致の検査。
- 開発時の検査・CI・独立レビュー手順と、証拠の種類を分けた検証履歴。

### Changed（変更）

- 本体と任意のカーソル補助拡張を1.0.0に統一。拡張manifestの旧表記0.1.0は過去リリースとして扱わない。
- READMEを基本導入、拡張READMEを任意拡張の導入・解除、AGENTSをAI規則の入口に整理。古い未実施記述を受け入れ済みの結果と照合し、試験の失敗・未確認点を検証履歴へ集約。

起動・全画面・復元・カーソル判定の挙動と、Chrome/Sunshineの実設定は変更していません。

[Unreleased]: https://github.com/riyonasan/pjivn-moonlight-helper/compare/03fc826...HEAD
