# pjivn-moonlight-helper

## ンポ向けの説明

PCブラウザ版のイヴンタイトを、スマホから遊びやすくするための設定・補助ツール集です。ゲームは自宅のWindows PCで動かし、Sunshine/Moonlightを使ってスマホへ映像を送り、スマホから操作します。遊ぶときはPCが必要です。

PC用カードは **イヴンタイト**、Moonlight用カードは **イヴンタイト(Moonlight)** です。**カーソル非表示の補助拡張は任意です。拡張なしでも基本の表示・起動・全画面化・復元・配信を利用でき、ゲーム内部のカーソルが残ります。**

## できること

- 1280×720のゲーム領域を切り出し、16:9の画面に比率を保って表示します。
- 保存したDemadoカード名で専用ウィンドウを起動し、Chrome標準の全画面表示へ切り替えます。
- 全画面化前の状態と位置を保存し、終了時に同じウィンドウへ復元します。
- Sunshineへ登録するdo/undoコマンドを、リポジトリと設定ファイルの実際の保存先から生成します。
- 任意の補助拡張で、Moonlightカードの全画面ウィンドウだけにゲーム内部のカーソル非表示を追加できます。

ゲームへのログイン、Demadoのインポート、Sunshine登録、Moonlightのペアリングは手動です。ChromeプロファイルやSunshineの設定を一括変更するインストーラーはありません。

## 必要環境

- Windows 11、Windows PowerShell 5.1、日本語表示のGoogle Chrome、16:9の主画面。
- [Demado](https://github.com/otiai10/demado)、[Sunshine](https://github.com/LizardByte/Sunshine)、[Moonlight](https://moonlight-stream.org/)を各提供元の案内に従って導入済み。
- 対象ゲームを利用できるChromeプロファイル。ログインとサイト権限はそのプロファイルで設定してください。

Demadoの配布JSONは2.0.60形式です。Sunshineはデフォルトの主画面を使う構成を想定し、`sunshine.conf`に空でない`output_name`がある場合は全画面処理を停止します。ブラウザーのズームやディスプレイ解像度は変更しません。

## AIに導入・設定作業を頼む場合

このリポジトリを読めるAIへ、次のように依頼できます。まずファイルの確認とローカル設定の準備から始め、未確認の環境値を推測で埋めないでください。調整の入口は揃っていますが、他の環境での動作や未確認の工程を自動完了できる保証はありません。

```text
このリポジトリのREADME.mdとAGENTS.mdを読んで、私のWindows環境で
pjivnの補助ツールを動かせるようにしてください。
まず画面を操作しない確認とtests/verify.ps1を実行してください。
PC用とMoonlight用は別カード・別設定にし、PC用はイヴンタイト、
Moonlight用はイヴンタイト(Moonlight)の配布JSON/CSSを正本にしてください。
既存の変更と設定を保護し、Gitの配布ファイルからPC設定を再現できる手順を示してください。
Chromeの実行ファイルとSunshine設定の場所は存在を確認し、
利用するChromeプロファイル、Demadoの保存済みカードID/表示名、
日本語Chrome・16:9主画面・Sunshineの表示選択は確認済みの値を使ってください。
分からない値は私に確認し、PC用config.local.jsonと、必要なら
Moonlight用config.moonlight.local.jsonを別々に準備してください。
既存ローカル設定を上書きせず、個人パスやカードIDをGitに入れないでください。
内部ゲームcanvasのカーソルを隠す任意の補助拡張は、私が希望する場合だけ扱い、
cursor-extension/README.mdに従ってconfig.cursor.local.jsonとパッケージを準備してください。
補助拡張なしでも基本起動は独立して使える構成を保ってください。
認証情報や別ゲームの設定は読み取らず、既存設定の一括変更はしないでください。
実際の保存先とMoonlight用ConfigPathからdo/undoコマンドを生成し、導入と復元の手順を示してください。
権限・認証・ファイアウォール・公開範囲を勝手に変更せず、pushや公開をしないでください。
ゲームやブラウザーUI操作、Sunshine登録・再起動・配信反映の前に私へ確認してください。
ログイン・インポート・権限許可・拡張の読込み・ペアリングと実機確認は私が行います。
静的検査の合格を実機動作済みとせず、確認済みと未確認を分けて報告してください。
エラー時は原因に関係する最小限の修正を行い、再検査してください。
```

AIが確認する入力は以下です。設定例の値は、その人の環境で確認できた値とは限りません。

| 入力 | 確認方法・設定先 |
| --- | --- |
| リポジトリ保存先 | 現在の実際の場所。コマンドは実際の保存先で生成します。 |
| Chrome実行ファイル | `ChromePath`。一般的な場所の自動検出、または本人指定の絶対パスの存在確認。 |
| Chromeプロファイル | `Profile`。本人が使うプロファイルの`chrome://version`のパス末尾。例の`Default`を決め打ちしない。 |
| Demado拡張ID | `ExtensionId`。例は公式ストア版のIDです。別の導入形態なら本人が確認。 |
| インポート後のカード | `CardId`と`Name`。本人が保存後に確認。元環境のIDやJSON内のURLからIDを推測しない。 |
| 表示環境 | 日本語Chrome、16:9主画面。非空のSunshine `output_name`はこのままでは非対応。 |
| Sunshine設定 | `SunshineConfigPath`。実際の`sunshine.conf`の場所。設定ファイル全体をチャットやGitへ貼らない。 |

導入は「公式アプリ準備 → 本人がDemadoインポート・カード確認 → ローカル設定 → ファイル検査とコマンド生成 → 本人がPCで起動・復元 → Sunshine登録 → Moonlight確認」の順です。画面を操作しない検査だけでは、カードのUI構造や実行ユーザーの相違は分かりません。

最小の実機確認は、本人が生成されたdoコマンドをPCで実行し、対象ゲーム1窓・全画面・他のChrome窓が残ることを確認してから、undoで元の窓状態へ戻すことです。その後Moonlightで、閉じた状態からの起動、タッチ座標、アプリ終了後の復元を確認してください。コマンド表示と静的検査はログイン不要ですが、ゲーム起動には本人のログインが必要です。

任意の補助拡張を使う場合は、基本利用の確認後にカード識別専用設定からパッケージを生成し、本人が読み込んでMoonlightカードのカーソル非表示・復帰とPCカードの維持を確認します。再読込み後の再適用やpause操作など、未確認の工程は別途実機確認してください。

## 最短の基本導入

リポジトリを任意の場所に保存し、以下のコマンドはそのフォルダで実行します。

1. 既存のDemadoカードを変更する場合は、対象カードをエクスポートして保管します。
2. PC用の [demado/pjivn.import.json](demado/pjivn.import.json) をDemadoへ1回インポートし、名前が`イヴンタイト`であることを確認して保存します。既存カードを使う場合は再インポートせず、名前とCSSを配布ファイルに合わせる方法もあります。
3. 保存後のカードIDを記録します。カード1件のエクスポートリンクにある`?export=<ID>`のIDを使ってください。インポートし直すと新しいIDになり、カードが重複します。
4. 初回だけ設定例をコピーし、確認済みの環境値へ編集します。既存のローカル設定は上書きしないでください。

PC配布カードはサイズ1280×720、ズーム1、アドレスバー非表示（Demadoではpopup窓）の構成です。Moonlight配布カードのアドレスバーは有効です。配布JSONの変更は保存済みカードへ自動反映されないため、既存PCカードは本人が設定を変更するか、重複に注意してインポートしてください。PCのpopup窓で補助スクリプトの全画面メニュー操作が成立するかは未検証です。

```powershell
Copy-Item -LiteralPath .\config.example.json -Destination .\config.local.json
```

| 設定 | 入れる値 |
| --- | --- |
| `ChromePath` | `chrome.exe`の絶対パス。空なら一般的なインストール先を検出します。 |
| `Profile` | 使用するChromeプロファイルのディレクトリ名。例の`Default`を決め打ちせず、`chrome://version`のプロファイルパス末尾で確認します。 |
| `ExtensionId` | 使用するDemadoの拡張ID。設定例はChrome Web Store版です。 |
| `CardId` | 保存後のカードID。配布JSONに固定IDは含まれていません。 |
| `Name` | カードの正確な表示名。基本ランチャーは一意の名前でカードを選択します。 |
| `SunshineConfigPath` | 実際の`sunshine.conf`の絶対パス。設定例のパスは環境に合わせてください。 |

Chromeの`Profile`とDemadoカードの表示名は別物です。認証DBやプロファイルの内容をコピーする必要はありません。`config.local.json`、`*.local.json`、実行状態の`.local/`はGit対象外です。

画面を動かさないファイル検査を実行できます。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

## PCで使う

通常のPC利用はDemadoの`イヴンタイト`カードから開きます。PC用CSSはカーソルを隠しません。編集用CSSは [demado/pjivn.css](demado/pjivn.css) で、配布JSONの`stylesheet`と同じ内容です。

ランチャーをPCで試す場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch-pjivn.ps1 -ConfigPath .\config.local.json -Fullscreen
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch-pjivn.ps1 -ConfigPath .\config.local.json -Restore
```

ログインや権限確認が表示されたら手動で完了してから再実行します。カード名の重複、複数のゲーム窓、必要なChromeメニューが見つからない場合は停止します。

## Moonlightで使う

**起動前に、手動で開いているイヴンタイトのゲーム窓を閉じてください。** カードを削除しても開いているゲーム窓は閉じません。未所有窓が残っていると、PC窓を保護するため準備コマンドは停止します。他のChrome窓は閉じる必要がありません。

1. [demado/pjivn-moonlight.import.json](demado/pjivn-moonlight.import.json) を別カードとして1回インポートし、`イヴンタイト(Moonlight)`で保存します。PCカードのCSSは変更しません。
2. `config.moonlight.example.json`を`config.moonlight.local.json`へコピーし、そのカードのID・名前と確認済みの環境値を設定します。`Usage`は`moonlight`のままにします。
3. do/undoを生成します。このコマンドはSunshineへ自動登録しません。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\show-sunshine-commands.ps1 -ConfigPath .\config.moonlight.local.json
```

SunshineのApplicationsでアプリを作成し、Commandは空、Command Preparationsへ生成したdo/undoを1組登録します。JSON出力中の`\\`はJSONのエスケープ表現なので、コマンド値として読み取って貼り付けます。実行ユーザーはゲーム用Chromeプロファイルを使えるデスクトップユーザーにしてください。管理者として実行する指定は不要です。

最初はPC上で同じdo/undoを試し、ゲーム1窓・全画面・元の位置への復元を確認します。その後Moonlightから登録アプリを選択し、横画面・16:9の配信解像度でタッチ座標と復元を確認してください。接続だけではなく、アプリの選択で準備コマンドが実行されます。

Moonlightランチャーは、保存した構成・窓ハンドル・PID・プロセス開始時刻が一致する所有窓だけを再利用します。未所有のPCゲーム窓がある場合は閉じずに停止するため、PC窓を手動で閉じてから起動してください。`-VerifyDemadoLaunch`も既存Moonlightゲーム窓がある場合は停止します。

Sunshineでアプリを終了するとundoで復元します。クライアントの切断だけではundoが実行されないことがあるため、必要なら同じ設定で手動復元します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch-pjivn.ps1 -ConfigPath .\config.moonlight.local.json -Restore
```

復元はゲームを閉じる処理ではありません。Sunshineは画面全体を配信するため、他アプリや通知が映り込むことがあります。ネットワーク、ファイアウォール、ポート設定はこのツールでは変更しません。

## 任意: ゲーム内部のカーソルを隠す

基本利用にはこの手順は不要です。DemadoのCSSはトップ文書だけに適用され、ゲーム内部のiframeには届きません。MoonlightカードのトップCSSに加え、内部canvasのカーソルも消したい場合だけ [補助拡張](cursor-extension/README.md) を導入します。

拡張用の設定は`config.cursor.example.json`を参考に`config.cursor.local.json`へ保存します。必要なのは`Usage`、Demadoの`ExtensionId`、Moonlightの`CardId`、正確な`Name`だけです。ChromeやSunshineのパスは不要で、基本ランチャーの設定と分離します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\prepare-cursor-extension.ps1 -ConfigPath .\config.cursor.local.json
```

表示されたGit対象外の生成フォルダを、ゲーム用Chromeでunpacked拡張として手動で読み込みます。開発者モード、必要な許可、識別条件、pause/resumeと実機確認は [導入・検証手順](cursor-extension/README.md) を参照してください。既存の生成先は上書きしません。

補助拡張はMoonlightカードID・名前・全画面状態とframe構造を確認し、最内documentの`canvas#unity-canvas`だけへカーソルCSSを入れます。PCカードには適用しません。全画面終了や識別喪失で解除しますが、元から全画面だった窓をundoで全画面へ戻す場合は配信終了を判別できないためpauseが必要です。

## 更新と復旧

- 更新前に配信を終了し、元の設定ファイルでundoを実行します。設定内容や保存先が変わると、Moonlightの所有・復元記録も別扱いになります。
- 既存カードの名前を変えた場合は、同時にローカル設定の`Name`を一致させます。名前変更はIDを維持できますが、再インポートは新しいIDを発行します。旧名でもカードと設定が一致すれば使用できます。
- `.local/`の復元情報は、復元完了まで残してください。復元途中の失敗時は記録を保持し、必要なら対象窓を手動で元の表示・位置へ戻します。
- 復元できるのは同じChromeプロセス寿命の同じ窓です。ブラウザー再起動後の復元には使えません。
- 補助拡張を更新・無効化・再ロードする前はpauseして解除を確認します。新しいパッケージへ切り替える場合、古い拡張を停止してから別の設定ファイルパスで生成してください。

## トラブルシューティング

| 症状 | 確認すること |
| --- | --- |
| 設定読取りで停止する | 必須項目、保存後のCardId、ChromePath、Profile、SunshineConfigPath。設定例の仮値が残っていないか確認します。 |
| Demadoカードが見つからない | 使用プロファイル・拡張ID・一意の表示名・サイト権限を確認します。ログインや権限確認は手動で完了してください。 |
| Moonlight起動が所有窓ガードで停止する | 未所有PCゲーム窓を手動で閉じます。設定変更前の窓が残っている場合は元の設定で復元します。 |
| 全画面化できない | 日本語Chrome、標準メニューを有効にしたカード、16:9の主画面、Sunshineの`output_name`を確認します。 |
| 復元できない | 同じ設定・窓・Chromeプロセスか確認します。記録を削除せず、必要なら対象窓を手動復元します。 |
| ゲーム内部のカーソルが残る | 補助拡張なしでは通常の動作です。導入済みならカードID/名前、全画面状態、拡張の許可・表示状態を確認します。 |
| タッチがずれる／余白がある | 横画面と16:9の配信解像度を確認します。端末の画面比率が違う場合、余白は生じ得ます。 |

## 制限と検証状況

ゲーム領域の切り出しは`iframe#game_frame`の1280×1751から上60pxを除く1280×720に依存します。ゲームDOMや寸法が変わった場合はCSSの調整が必要です。

ランチャーはDemadoのUI階層、Chrome内部メニューID `view_1007`、日本語の全画面関連表示、ゲーム窓タイトルに依存します。全画面判定はネイティブ窓サイズとモニター境界を使い、ブラウザーのズームと画面解像度は変更しません。

英語Chrome、他のDemado/Chrome版、複数プロファイル・モニター、非16:9画面、仮想ディスプレイ、特殊なDPI、別ユーザーのSunshineは未検証です。全Chromeプロセスの終了やプロファイルの初期化は行いません。このツールが開いたダッシュボードも、プロセス・窓・1タブ・URLが一致する場合だけ閉じます。

ゲームページの二段iframeとUnity canvasの構造は実環境で読取り確認済みです。PowerShell・設定・所有窓ガード・拡張の判定/解除・パッケージ生成には画面を起動しない検査があります。補助拡張を本人が読み込んだ後、手動で開いたMoonlightカードで通常窓→F11全画面→通常窓を確認し、内部canvasのcomputed cursorはdefault→none→defaultでした。本人の目視でも非表示と復帰を確認し、PCカードの全画面ではカーソルが残ることを確認しました。PCカードの通常窓でもcomputed cursorはdefaultでした。カードIDの直接読取りとChrome APIのwindow stateは観測していません。再読込み試験では外側frameが空のままcanvas待ちがタイムアウトしたため、frame再生成後の再適用は実機未検証です。その後、本人がMoonlightカードを開き直してゲームの復帰を確認しました。再読込み時に空になった原因は不明です。2026-10-05、このリポジトリの配布JSONから新規カードを作り、新IDと本人確認済みプロファイルで設定・do/undoを生成し、Sunshineへ登録する基本導入の受け入れ試験に合格しました。本人がスマホMoonlightからの起動・全画面・欠けなしの表示・タッチ位置一致・終了undoを確認し、ランチャー出力にも全画面準備完了と元の窓配置への復元成功を確認しました。基本試験では新カード用の補助拡張を導入せず、基本利用が独立して使えることを確認しました。その後、新カード専用パッケージを生成・検査して本人が読み込み、スマホMoonlight全画面時のゲーム内カーソル非表示、終了undo後の復帰、PCカードでのカーソル表示維持も本人が確認し、任意機能の受け入れ試験に合格しました。新カードでの結果は本人確認で、内部canvasのcomputed cursorを直接観測した先の試験とは区別しています。初回は準備コマンドが終了コード1で停止し、残存ゲーム窓を閉じた後に成功しました。初回の例外本文がなく、原因は断定していません。補助拡張のpause操作と再読込み・frame再生成後の再適用は未実機検証です。他の環境での動作を保証するものではありません。

## ファイル検査

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
node --test .\tests\cursor-extension.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-cursor-package.ps1
```

Node.jsは拡張コードのテスト時だけ必要です。基本利用と補助拡張の実行には不要です。検査はChrome・ゲーム・Sunshineを起動せず、実機確認の代わりにはなりません。パッケージ生成テストはTEMPにダミー設定を作り、診断用に残します。

開発時の作業規約は [AGENTS.md](AGENTS.md) を参照してください。

## ライセンス

ソースコードのライセンスは現在未設定です（LICENSEファイルなし）。ゲーム素材やDemado本体は含まれません。ゲームと外部ソフトウェアの利用条件は、それぞれの提供元の案内をご確認ください。
