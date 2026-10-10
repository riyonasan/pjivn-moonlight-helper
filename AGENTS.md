# このリポジトリを扱うAI向け

## Shared configuration reference

The approved shared policy and separately distributed guides are maintained in private [riyonasan/agent-config](https://github.com/riyonasan/agent-config). Adopted version: `v2.0.0` (candidate; no tag/Release). Full central commit SHA: `567cd35aa3660df77687a1280ae0e429111a5830`. Read the [pinned shared policy](https://github.com/riyonasan/agent-config/blob/567cd35aa3660df77687a1280ae0e429111a5830/AGENTS.md) through the active Codex home (`CODEX_HOME`, otherwise the user profile's `.codex`). Do not copy shared policy or guides into this project. Placement and instruction loading are separate checks; this reference alone does not prove they succeeded.

Shared review/model selection, approval, and Notion rules follow that adopted policy, including when older workflow documents contain superseded general guidance. Preserve project-specific product, data, and permission constraints. Notion holds current overview, usage, behavior, limitations, and agreed decisions; routine progress and task-status updates are excluded. Task administration requires a separate explicit request.

このリポジトリはイヴンタイトのゲームURL識別子`pjivn`を使う小さな補助ツールです。[README](README.md)を読んでから作業してください。任意拡張は[拡張README](cursor-extension/README.md)、検査・CI・独立レビュー・版更新は[DEV_WORKFLOW](DEV_WORKFLOW.md)、実機の証拠は[検証履歴](docs/VERIFICATION.md)を参照します。ここにはAIの作業規則を置きます。ユーザーの明示的な指示がこの手順より優先します。

- 最初はファイル・構文・設定例を確認し、`tests/verify.ps1`をWindows PowerShell 5.1で実行してください。この検査はUIを起動しません。
- 環境固有の値は推測しないでください。使用するChromeプロファイル、Demadoインポート後のカードID/表示名、拡張ID、日本語Chrome・16:9主画面・Sunshine表示選択を、本人の確認または許可された読み取りで確かめてください。設定例の`Default`や標準インストール先は仮の値です。
- `ChromePath`の一般的な場所の検出と、本人指定パスの存在確認は可能です。プロファイル内のCookies、Login Data、認証DB、セッション情報は読取・コピー・移植しないでください。他ゲームの設定も持ち出さないでください。
- 本人がDemadoで1件のJSONをインポートして保存すると新しいカードIDになります。再インポートで重複します。`CardId`は手動照合用で、起動は一意の`Name`を使うことを説明してください。
- PC用カードは`イヴンタイト`、Moonlight用カードは`イヴンタイト(Moonlight)`です。調整はGit対象外のPC用`config.local.json`、Moonlight用`config.moonlight.local.json`を分け、対応する設定例と配布JSON/CSSを正本にします。実際の保存先とMoonlight用ConfigPathから`show-sunshine-commands.ps1`でdo/undoを生成してください。元の個人パスをコードへ埋め込まないでください。
- カーソル非表示の補助拡張は任意です。本人が希望する場合だけ`config.cursor.local.json`を準備し、基本ランチャーとの独立性を保ちます。Chromeプロファイル、認証情報、Sunshine情報を生成設定へ加えず、既存パッケージを上書きしないでください。
- ログイン、サイト権限、ペアリングは本人が行います。ゲーム・ブラウザーのUI操作、既存Sunshine/Demado登録の変更、公開やpushは、その作業をユーザーが依頼した範囲だけで行ってください。既存の動作済み構成を無断で置き換えないでください。
- 全Chromeプロセスの終了、既存プロファイルの初期化、ファイアウォールやポートの自動変更、汎用インストーラー化はこの補助ツールの導入には不要です。
- 問題を直す場合はエラー箇所とREADMEの依存点から最小限で修正し、関連検査を再実行してください。CSSを変えた場合はPC用・Moonlight用それぞれのCSSと配布JSON内の`stylesheet`を一致させます。文書更新では旧結果と後の受け入れを照合し、失敗や未確認点を消さず検証履歴へ移してリンクしてください。
- `.local/`の復元情報は、本人が復元を終えるまで削除しないでください。窓ハンドル・PID・プロセス開始時刻と、ダッシュボードの1タブ・URL照合を弱めないでください。
- 報告は「ファイル検査済み」「本人のPCで確認済み」「Moonlight経由で確認済み」を実際の証拠に合わせて書き分けます。第三者実機と移植後のUIは未検証なので、必ず動くとは説明しないでください。

ライセンスは未指定です。第三者コードやゲーム素材を追加して配布しないでください。個人設定・ログ・認証情報をコミット対象にしないでください。

## Reliability and acceptance

For this personal project, prioritize the requested representative workflow, a clear failure result, and practical manual recovery. Add automatic recovery, persistent retry tracking, rare-state handling, or stricter recognition only for an observed need and agreed scope. Preserve all project-specific constraints on data integrity, uncertain irreversible actions, credentials, purchases, and third-party assets.

Define completion by the user action and observable result, with acceptable limitations. Use the existing specification and HANDOFF (or the documented restart file); record the objective, unmet criteria, latest evidence, and next action briefly. Apply the shared review process once per coherent feature rather than once per small patch.
