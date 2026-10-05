# Moonlight canvas cursor helper

## 選定

小さなManifest V3補助拡張を選びました。Demado本体は変更しません。
**これは内部canvasのカーソル非表示だけの任意機能です。** 基本のPC/Moonlightカード表示、
ランチャー起動、全画面/復元、Sunshine/Moonlight利用に拡張導入・生成・拡張設定は不要です。
未導入ならゲーム内部のカーソルが残ります。基本ランチャーに拡張の存在確認はありません。

| 比較 | ユーザースクリプト | 補助拡張（採用） |
| --- | --- | --- |
| PC/Moonlightが同URL | 最内iframeのURLだけでは区別不可 | トップのDemadoカードID・表示名を検査 |
| 二段cross-origin iframe | トップから子への識別中継、管理拡張への依存が必要 | tabIdとframe親子関係・documentIdを検査 |
| 管理・再現性 | 管理拡張の設定・実行world・frame対応も正本化が必要 | 依存パッケージなし。Gitとローカル設定から生成 |
| リロード/iframe再生成 | 各frameの実行時刻と中継を調整 | navigationイベントとdocumentIdで再判定 |
| 解除 | 各frame内のstyleと識別中継の後始末 | 挿入済みdocumentをsession storageで管理しremoveCSS |

ユーザースクリプトでも安全な中継を実装すれば可能ですが、同URLへ一律適用する短い
スクリプトではPC側も隠してしまいます。今回はタブ単位の判断を一か所に集めます。

## 対象と動作

2026-10-05の実ページ読取りで確認した構造:

1. トップ: `https://play.games.dmm.co.jp/game/pjivn_293854`
2. `iframe#game_frame`: `https://osapi.dmm.com/gadgets/ifr`
3. `iframe#gameHTML5Canvas`: `https://iv-n-tight.saikyo.biz/app_data/`
4. `canvas#unity-canvas`: 1280×720、inline/computed `cursor: default`

補助拡張は次の条件をすべて要求します。

- トップURLのorigin/pathが対象と一致。
- Demadoの正確な2つのsessionStorageキーに記録されたカードIDと表示名が
  ローカル設定と一致。保存済みカードIDを優先し、表示名だけで判断しない。
- トップの `iframe#game_frame` が1個で、origin/pathがosapiの対象と一致。
- 該当するDemadoカードのタブがChromeプロファイル内で1つだけ。窓も1タブ。
- Chrome `windows.get` が `fullscreen` を返す。
- navigationのframe親子関係がトップ→osapi→app_dataと一致し、候補が1つ。
- 最内documentに `canvas#unity-canvas` が1個。

適用するのは対象documentだけの `#unity-canvas { cursor: none !important; }` です。
USER originで指定し、Unityの通常inline指定より優先します。DOM内容・ゲーム動作・
他のframe・お知らせ・PCカードのCSSを変えません。全frame注入はありません。
候補の確認後にdocumentIdを指定するので、途中のnavigationで別documentへ適用しません。
DOM上のカード記録は対象選択の根拠であり、悪意ある対象サイトに対する認証機構ではありません。

Demado初期化はトップのisolated worldで1秒ごとに2つのカード設定キーだけを確認し、
識別状態が変わった時だけ通知します。CSS適用後はcanvasがDOM内で再生成されても
同documentのCSSが効き、frame再生成・リロード・SPA navigationは再検査します。
イベント取りこぼしの回復用に1分ごとのauditもあります。

全画面終了・カード識別喪失・別ページ遷移・重複・停止操作で自身のCSSを解除します。
ツールバーアイコンのクリックはpause/resume。`ON`は適用済み、`OFF`は停止中、
`?`は曖昧・権限不足・解除保留等、`ERR`はパッケージ/設定の不備です。
pauseは現在のChromeセッション中だけ有効で、Chrome再起動後は自動判定へ戻ります。
権限が足りなくても自動要求はせず、対象を決められなければ新規適用しません。

## Git正本からの準備（導入は別途承認）

配布名はPCカード `イヴンタイト`、Moonlightカード `イヴンタイト(Moonlight)`。
ChromeのProfileディレクトリ名とは別物です。Demadoインポートは新しいカードIDを発行します。
既存カードを移行する時は再インポートせず、既存カードを名前変更してIDを維持する方法を
推奨します。実画面の変更は承認後です。名前を変えた場合、ローカル設定の `Name` も同時に
一致させてください。既存ローカル設定/旧表示名のカードを勝手に書き換えません。
生成処理は旧Moonlight表示名も受け付け、設定の正確なID・名前で照合します。

補助拡張の生成には、カード識別4項目だけが必要です。`config.cursor.example.json` を参考に、
本人が確認したID・正確な名前を `config.cursor.local.json` に記録します。
この任意拡張専用設定を、基本ランチャーの `config.moonlight.local.json` と分けて保存します。

```json
{
  "Usage": "moonlight",
  "ExtensionId": "dfmhlfpfpbijchleocfbpcdjgnbpdigh",
  "CardId": "REPLACE_AFTER_IMPORT",
  "Name": "イヴンタイト(Moonlight)"
}
```

ChromePath・Profile・SunshineConfigPathは補助拡張が使用しないため生成器では要求しません。
全項目を持つ既存ランチャー設定も入力できますが、未使用項目は生成物へ入れません。
カード識別4項目だけの設定はランチャーには不足します。ランチャーを使う場合だけ、
本人確認済みの環境値を追加してください。生成コマンド:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\prepare-cursor-extension.ps1 -ConfigPath .\config.cursor.local.json
```

生成先はGit対象外の `.local/moonlight-<設定hash>/cursor-extension/`。
JavaScript 4ファイルとmanifest、カード識別だけの `settings.local.json` をコピーします。
生成設定に個人パス・Chromeプロファイル・Sunshine情報は含みません。
依存パッケージ、ビルド、ダウンロードは不要です。既存生成先は上書きしません。
ソース更新時はpause/復元後に別のconfigファイルパスで新しいパッケージを生成し、
導入先の切替を本人が確認してください。ソースフォルダを直接ロードすると設定不足で停止します。

本人の承認後、確認済みのゲーム用Chromeプロファイルで、Chromeの拡張管理画面から
生成したフォルダを「パッケージ化されていない拡張機能」として読み込みます。
これには開発者モードと拡張導入の確認が必要です。今回は実施していません。

必要なAPI権限は `scripting`, `webNavigation`, `storage`, `alarms`。
hostは `https://play.games.dmm.co.jp/*` と `https://iv-n-tight.saikyo.biz/*` の2originだけ。
Chromeのhost権限はorigin単位で、コード内でpathも制限します。
osapiはnavigationの親子関係だけを読み、その内部DOMへスクリプト/CSSを入れないので
osapiのhost権限は要求しません。`tabs`権限、Cookie、履歴、認証DB、nativeMessaging、
全サイト権限、ネットワーク送信、外部メッセージ入口、Demadoの権限変更は不要です。
Demadoから読み取るのはカード用の指定キーだけで、保存領域の列挙はしません。

## 起動・解除と未検証点

導入後はMoonlightカードの初期化と全画面化に合わせ自動適用します。
`launch-pjivn.ps1 -Restore` が通常窓へ戻す場合は自動解除します。
元から全画面だった窓をundoで全画面へ復元した場合は、配信終了をChromeの状態だけでは
区別できません。その場合はpauseを使います。Sunshine配信状態との直接連携はありません。
元のMoonlightカードCSSが隠すトップ文書のcursorはそのままで、pauseは内部canvas用CSSだけを解除します。

通常PCカードとMoonlightカードを同時に開いても、拡張の判断は別カードIDなので
PCタブへCSSを適用しません。ただし前回追加したPowerShellランチャーの窓ガードは
PCゲーム窓がある場合に停止する仕様のままです。同時起動をランチャーで自動処理する
変更は含みません。本人が各カードを開いた場合の拡張の同時利用はテストで検査しています。

補助拡張の無効化・更新・再ロード・アンインストール前はpauseし、解除完了を確認してください。
解除不能と表示された時は、対象ゲームページを本人がリロードするか閉じればdocumentとCSSが
なくなります。拡張を無効化するだけでCSSが必ず即時に消えるとは扱いません。

コード/モック検査済み。本人による生成パッケージの読込み後、手動で開いたMoonlightカードで
通常窓→本人のF11全画面→通常窓を確認しました。内部canvasのcomputed cursorは
default→none→defaultで、本人の目視でも非表示と復帰を確認しました。
PCカードの全画面でカーソルが残ることは本人の目視確認、通常窓のcomputed cursorがdefaultであることはDOM観測で確認済みです。
その後、新規インポートしたカード専用のパッケージを生成・検査して本人が読み込み、スマホMoonlightで起動した全画面ゲーム内のカーソル非表示、終了undo後の復帰、PCカードでの表示維持を本人が確認し、任意機能の受け入れ試験に合格しました。新カードの結果は本人確認で、こちらによるcomputed cursorの再測定はしていません。
カードIDの直接読取り、Chrome APIによるwindow state取得、pause操作、ゲーム進行操作の維持は未実機検証です。基本ランチャーの新規カード作成・生成・Sunshine登録・スマホ起動/全画面/表示/タッチ/終了復元は、補助拡張を新カードへ導入しない別の受け入れ試験で本人確認済みです。
再読込み試験では外側frameが空のままcanvas待ちがタイムアウトしました。
追加の再読込みは行っておらず、frame再生成後の再適用は未実機検証です。
原因は特定できていません。その後、本人がMoonlightカードを開き直してゲームの復帰を確認しました。開き直し後のcomputed cursorと再適用は未観測です。
遷移や全画面操作からイベント処理までの短い非同期遅延があるため、即時・原子的な切替ではありません。

## 再現可能な検査

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
node --test .\tests\cursor-extension.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-cursor-package.ps1
```

Node.jsはテスト時だけ必要で、拡張の利用には不要です。Node組込みtest/assert/vmのみを使用します。
すべてゲーム・Chrome・Sunshineを起動しない検査です。パッケージ検査はTEMPにダミー構成を
作成し、生成内容とPC設定拒否・既存パッケージ保持を確認します。診断用fixtureはTEMPに残します。

公式仕様: [scripting/documentId/CSS](https://developer.chrome.com/docs/extensions/reference/api/scripting)、
[navigation/frame/document](https://developer.chrome.com/docs/extensions/reference/api/webNavigation)、
[session storage](https://developer.chrome.com/docs/extensions/reference/api/storage)、
[window state](https://developer.chrome.com/docs/extensions/reference/api/windows)、
[tabsの権限範囲](https://developer.chrome.com/docs/extensions/reference/api/tabs)、
[Tampermonkey](https://www.tampermonkey.net/documentation.php)。
