# 開発・検査・レビュー手順

導入する人は [README.md](README.md)、AIは [AGENTS.md](AGENTS.md) から始めます。利用者向け変更は [CHANGELOG.md](CHANGELOG.md)、実機の証拠と残る未確認点は [検証履歴](docs/VERIFICATION.md) に記録します。

## 作業と独立レビュー

1. ブランチ、差分、他のworktreeを確認し、既存の変更とローカル設定を保護します。専用worktreeで作業し、個人設定や `.local/` を持ち込みません。
2. 関連ファイルと依存点を読み、変更前に `tests/verify.ps1` をWindows PowerShell 5.1で実行します。
3. 最小限の変更後に、以下の3検査と差分検査を実行します。文書間のリンク、情報移動の欠落、カード名、復旧・安全条件、公開情報に個人値がないことも確認します。
4. 未commitの差分と検査結果を独立レビューへ渡します。指摘を修正し、関連検査を再実行してからcommitします。
5. main統合と通常pushはユーザーが許可した範囲で行います。force pushせず、更新されたmainや他のworktreeの変更を保護します。push後は対象commitのCI結果を確認して報告します。

この手順自体は公開、タグ、GitHub Release、実機設定変更の許可ではありません。許可が既にある作業はその範囲で進めます。

## 再現可能なファイル検査

リポジトリのルートで実行します。Windows PowerShell 5.1とNode.jsが必要です。依存パッケージのインストールはありません。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
node --test .\tests\cursor-extension.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-cursor-package.ps1
git diff --check
```

| 検査 | 確認すること |
| --- | --- |
| `verify.ps1` | PowerShell構文・ネイティブ宣言、設定例、JSON/CSS同期、PC/Moonlightカード名、引用付きコマンド、窓寿命・所有・ダッシュボードガード、全画面境界・計画、本体と拡張の版一致 |
| Node検査 | カードID/名前・全画面・frame/document判定、適用と解除、権限不足、pause、再読込み、workerのイベント配線をChrome APIモックで検査 |
| `verify-cursor-package.ps1` | ダミー設定からの生成、生成manifestの版とソース一致、識別設定だけの出力、PC/不正設定拒否、既存パッケージ保持、旧形式の全項目設定との互換性 |

Chrome・ゲーム・Sunshineは起動せず、ログイン情報も実Chromeプロファイルも使いません。Node検査は組込みのtest/assert/vmを使用します。Node.jsは検査時だけ必要で、基本利用と拡張の実行には不要です。パッケージ検査はTEMPにダミー設定を作り、診断用fixtureを残します。検査の合格は実機の表示、タッチ、CSS適用、配信・復元を代替しません。

## CI

[GitHub Actions](.github/workflows/ci.yml) はpushとpull request時に、Windows Server 2025の1ジョブで上の3検査と差分の空白検査を実行します。Windows PowerShell 5.1、Node.js 24.15.0に固定し、ダミー設定とChrome APIモックを使います。

公式Actionは完全なcommit SHAに固定しています。トークンはcontentsの読取りだけ、checkout後の資格情報保存とパッケージキャッシュは無効です。同じブランチ/PRの古い実行をキャンセルし、1ジョブを10分で打ち切ります。ActionやNodeの固定版を更新するときも上の検査で確認します。

## 版と配布物の整合

本体はPowerShellスクリプトとDemadoのJSON/CSSをそのまま配布するため、ビルド用packageや版取得処理は追加しません。ルートの [VERSION](VERSION) を本体版の正本とし、任意拡張の [manifest.json](cursor-extension/manifest.json) の `version` を同じ値に揃えます。生成器はmanifestをそのままコピーする既存方式を維持します。拡張の `package.json` はNodeのmodule指定だけで、配布版の正本ではありません。Demado JSONの `version: 2.0.60` と拡張の `manifest_version: 3` は各形式の版で、本体版とは別です。

[Semantic Versioning 2.0.0](https://semver.org/lang/ja/) に従い、運用済み構成の基準版を1.0.0とします。公開するインターフェースは、READMEで案内するスクリプトの引数、設定キー、カード名と配布JSON/CSS、生成パッケージの導入・解除手順です。後方互換の修正はPATCH、互換性を保つ機能追加はMINOR、これらを壊す変更はMAJORを上げます。ゲームDOMや外部アプリの変更で必要になった対応も、利用者への互換性で判断します。

版更新時は `VERSION` とmanifestを揃え、生成検査まで実行し、変更履歴を更新します。既に読み込んだローカルパッケージは書き換えず、[拡張README](cursor-extension/README.md) のpause・復元・新規生成手順を案内します。

[Keep a Changelog 1.1.0](https://keepachangelog.com/ja/1.1.0/) に従い、未公開の変更は `Unreleased` に種類別で記録します。実際の公開を確認した時点で版の節と実際の公開日（YYYY-MM-DD）へ移します。運用・検証日を公開日に転用せず、過去版やタグのリンクを作りません。公開済みの版内容は後から書き換えず、訂正は次の版で記録します。
