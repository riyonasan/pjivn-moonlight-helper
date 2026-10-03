# pjivn-moonlight-helper

`pjivn`は対象ゲームURLの識別子から採った名前です。英語のゲーム名を仮定しません。

イヴンタイトをDemadoの専用Chromeウィンドウで開き、Sunshine/Moonlightへ渡す小さな補助スクリプトです。動いた構成を置いておくためのリポジトリで、環境に合わせて設定やコードを調整する人向けです。インストーラーや公式サポートはありません。

元の環境では、Androidからの閉じた状態からの起動・タッチ操作・全画面表示を利用者が確認しました。このリポジトリへの移植後は構文・設定・モック検査だけを実施しており、実ブラウザー・Demadoインポート・Sunshineサービス経由の再確認はしていません。

## 前提

- Windows 11、Windows PowerShell 5.1、日本語表示のGoogle Chrome、16:9の主画面。
- [Sunshine](https://github.com/LizardByte/Sunshine)、[Moonlight](https://moonlight-stream.org/)、[Demado](https://github.com/otiai10/demado)を、それぞれ公式の案内に従って別途導入済み。
- ゲームを正規に利用できる本人のChromeプロファイル。ログイン、Demadoのサイト権限許可、Moonlightとのペアリングは本人が行います。
- Sunshineの画面選択はデフォルトの主画面を使う想定です。`sunshine.conf`に非空の`output_name`がある場合は停止します。既存設定を確認して自分で調整してください。

ネットワーク・ファイアウォール・ポート公開は利用者側で設定してください。このツールは変更しません。Sunshineはモニター全体をキャプチャするので、通知や手前に出した別アプリも配信されます。

## 初期設定

1. Demadoの設定画面で、必要なら自分の既存設定を別の場所へエクスポートして保管します。
2. `demado/pjivn.import.json`をDemadoの「インポート」から読み込み、1件の設定を確認して保存します。同じJSONを再度インポートすると別カードが増えるので、重複を避けてください。
3. カード名は `イヴンタイト（ゲーム画面 1280×720）`、アドレスバーは有効、サイズは1280×720、ズームは1の想定です。JSONには16:9に合わせるCSSも入っています。編集用の同内容は`demado/pjivn.css`です。CSSファイル単独では自動反映されません。
4. 保存したカードの編集・エクスポート等へのリンクにあるIDを確認します。2.0.60ではエクスポート選択のURLの`?export=カードID`が手掛かりになります。複数選択のカンマ区切りではなく、このカード1件のIDを使ってください。インポートでIDが変わることはコードから確認しましたが、このJSONの実インポートは未検証です。
5. `config.example.json`を`config.local.json`にコピーし、`CardId`を実際のIDへ置き換えます。`Name`はカード表示名と完全に一致させてください。起動はUI Automationで**同名カードが1件だけ**あることを確認して実行します。`CardId`は手動照合用で、UIのカードをIDで検索する実装ではありません。
6. `Profile`をDemadoと本人のログインがあるChromeのディレクトリ名（`Default`、`Profile 1`など）にします。表示上のプロフィール名とは異なります。本人がChromeの`chrome://version`にあるプロファイルパスの末尾で確認できます。プロファイルの中身や認証データをコピーする必要はありません。
7. `ChromePath`は空なら一般的なインストール先を検出します。必要なら`chrome.exe`の絶対パスを指定してください。`SunshineConfigPath`も実際の`sunshine.conf`の絶対パスへ調整します。

設定キーと日本語カード名は命名変更前と同じです。自分で作成済みのローカル設定を使う場合は、新しい保存先へ置き、Sunshineに登録するコマンドを生成し直してください。

ローカル設定と実行時の`.local/`はGit対象外です。設定変更前に配信を終了して復元し、このリポジトリは1ゲーム・1構成で使ってください。

## Sunshineへの登録

設定後、PowerShellで以下を実行すると、貼り付け用の`do` / `undo`コマンドがJSONで表示されます。Sunshine設定を自動更新する処理はありません。

```powershell
& 'E:\development\pjivn-moonlight-helper\show-sunshine-commands.ps1'
```

標準配置の場合のコマンド例です（JSON表示の`\\`はJSONエスケープなので、値として読み取って貼り付けます）。

```text
do:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\development\pjivn-moonlight-helper\launch-pjivn.ps1" -ConfigPath "E:\development\pjivn-moonlight-helper\config.local.json" -Fullscreen
undo:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\development\pjivn-moonlight-helper\launch-pjivn.ps1" -ConfigPath "E:\development\pjivn-moonlight-helper\config.local.json" -Restore
```

SunshineのApplicationsに自分でアプリを追加し、Commandは空、Command Preparationsにこのdo/undoを1組登録します。管理者として実行する指定は不要です。実行ユーザーが本人のデスクトップとChromeプロファイルを利用できる必要があります。Moonlightの接続だけでなく、登録したアプリを選ぶことで準備コマンドを動かします。

## 起動・終了・失敗時

- Moonlightで登録したアプリを選びます。ゲーム窓がなければ専用のDemadoダッシュボードを新しく開き、カードを実行します。ゲーム窓が1つあれば再利用し、Chrome標準メニューで全画面にします。ブラウザーのズームや画面解像度は変更しません。
- Androidは横向き・16:9の配信解像度（720p/1080pなど）から調整してください。画面の縦横比が広い端末で左右余白が出るのは許容する構成です。タッチ座標は利用者が実機で確認してください。
- Sunshineでアプリ終了まで行うとundoが元の全画面状態と窓配置へ復元します。クライアント切断だけではundoが走らない場合があります。終了はゲーム窓を閉じる処理ではありません。
- 手動復元は起動例の`-Fullscreen`を`-Restore`へ置き換えて実行します。保存した窓ハンドル・PID・プロセス開始時刻が合わなければ触りません。元から全画面だった窓は全画面へ復元します。
- ログインや権限確認が出たら本人が手動で完了し、再実行します。曖昧な複数ゲーム窓・複数同名カード・メニュー検出失敗はエラーで停止します。
- 全画面化の途中で失敗したら保存した窓状態へ戻す処理を試みます。復元が失敗した場合は`.local/fullscreen-state.json`を残し、手動復元を試してください。状態ファイルを消すと復元情報を失います。
- 自動で閉じるのは、このツールが開いたDemadoダッシュボードだけです。Chromeプロセスの寿命、窓、1タブ、ドキュメントURLが一致する場合に限ります。ユーザーがタブやページを変えた場合は残します。ゲーム・既存管理画面・他のChromeプロセスを一括終了しません。

## 調整箇所と制約

CSSは`iframe#game_frame`の元サイズ1280×1751から上60pxを除いた1280×720を切り出し、等倍比率で中央に収めます。ゲームのDOMや寸法が変わると調整が必要です。

Demadoのカード階層、Chrome内部メニューID `view_1007`、`F11`で終わるメニュー項目、日本語の全画面終了ボタン、ゲーム窓タイトルに依存しています。汎用ランチャーではありません。カードIDの固定は除去しましたが、実行カード選択は元コード同様に一意の表示名を使います。全画面検出はCSSピクセルではなくネイティブの窓サイズとモニター境界を比較します。

英語Chrome、別バージョンのDemado/Chrome、複数プロファイル併用、別ゲーム、非16:9画面、仮想ディスプレイ、特殊なDPIや複数モニター構成、別ユーザーで動くSunshineは未検証です。復元は同じ窓・同じChromeプロセス寿命だけが対象で、ブラウザー再起動後の復元はできません。

元の動作済みスクリプトからの主な変更は、設定と実行時状態の分離、パスの引用、復元のPID/開始時刻確認、環境固有の診断ログと未使用APIの除去です。現在使っている元スクリプト・Sunshine登録・Chrome/Demado設定には触れていません。

## 検査と出所

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

この検査はブラウザーやゲームを起動せず、PowerShell構文、JSON/CSS整合、空白入りパスとプロファイルの引用、所有窓の識別ガード、モニター境界の判定を確認します。UI操作やサービス経由起動の代替にはなりません。

Demado 2.0.60のインストール済みコードを読み、exportの項目とimportの生成ID動作を確認してJSONを構成しました。拡張のコード本体・ゲーム素材・インストーラーは同梱していません。`timestamp: 0`は実環境の出力日時を残さないための値です。

ライセンスは未指定のため付与していません。公開や第三者による再配布の前に、権利・ライセンス条件は別途決めてください。この作業ではローカルGitリポジトリだけを作成し、GitHub作成・push・外部アップロードは行っていません。
