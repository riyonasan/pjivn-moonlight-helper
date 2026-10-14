# LinuxミニPCで使う

UbuntuのGNOME Wayland上で、ダミープラグの画面をSunshineから配信するためのLinux版です。Windows版のDemadoカードとPowerShellは使わず、**ゲーム専用のChrome/Chromiumで直接全画面表示**します。ゲーム領域の切り出しは既存の `demado/pjivn.css` と同じです。

初回ログインと表示拡張の読込みは本人が行います。配信終了時は専用ブラウザーを閉じます。Windows版の「既存窓を元の位置へ復元」とは異なります。セーブや通信中に終了しないでください。一般利用のブラウザーやWindows版の設定は変更しません。

## 対応範囲

- GNOME Wayland、Python 3.10以上と `python3-gi`、ネイティブ版Sunshine（KMS）。
- 有効な画面は横向き16:9の1台。接続端子名とSunshineの `output_name` は確認済みの値を設定します。GNOMEの倍率125%も診断できます。解像度・倍率は変更しません。
- Chrome/Chromiumの**本体ELF実行ファイル**。Snap/Flatpak・シェルラッパーは終了追跡が異なるため対象外です。インストールと更新はブラウザーの提供元の手順で行います。
- `XDG_DATA_HOME/pjivn-moonlight-helper/browser-profile` を専用領域にします。`XDG_DATA_HOME` 未指定時は `~/.local/share` が基点です。既存の通常プロファイル・認証DBを読取・コピーしません。

Waylandではウィンドウ配置をデスクトップ側が決めるため、複数画面への自動配置は実装していません。リモートデスクトップなどで別の仮想画面が有効なら、本人がGNOME設定で配信用の1台だけにしてください。接続済みでも無効な画面は問題ありません。

Linuxでの実ゲーム・拡張・全画面・タッチ・終了はまだ実機未検証です。Windowsでの受け入れ結果をLinuxの保証には使いません。[検証履歴](VERIFICATION.md)を参照してください。

## 初回準備

運用はmainに統合・検証済みの同じコミットから行います。開発worktreeのファイルを稼働中の配置へ重ねないでください。専用プロファイルはリポジトリの外に残るため、ソース更新でログイン状態を上書きしません。

1. `config.linux.example.json` を初回だけ `config.linux.local.json` にコピーします。既存ファイルは上書きしません。
2. 次の確認済みの値を設定します。端子名の推測・自動変換はしません。

| キー | 値 |
| --- | --- |
| `BrowserPath` | 利用するChrome/Chromium本体の絶対パス |
| `SunshineConfigPath` | 既存 `sunshine.conf` の絶対パス |
| `SunshineOutput` | その設定の `output_name` と完全一致する値 |
| `DesktopOutput` | GNOMEの配信用画面の端子名 |

画面を操作しない診断を、**デスクトップにログインした通常ユーザー**で実行します。`sudo` は使いません。

```bash
python3 launch-pjivn-linux.py doctor
```

診断はGNOMEの `GetCurrentState` とSunshineの `capture` / `output_name`、ブラウザー本体の存在を確認します。ブラウザー起動・画面キャプチャ・プロファイル作成・設定変更はしません。診断合格は、拡張導入・ゲーム表示・配信確認の代わりにはなりません。

3. 通常ウィンドウで初回準備を行います。ここからブラウザーが起動します。

```bash
python3 launch-pjivn-linux.py setup
```

4. 開いた**専用ブラウザー**で `chrome://extensions` を開き、本人がデベロッパーモードを有効にし、「パッケージ化されていない拡張機能を読み込む」から、運用リポジトリの `linux-extension` フォルダを選びます。この拡張は対象ゲームのトップページだけに表示CSSを適用します。内部iframe、他ゲーム、通常ブラウザーには適用しません。ゲーム内カーソルは隠しません。
5. ゲームのタブへ戻って再読込みし、本人がログイン・必要なサイト権限の確認をします。表示CSSがログイン確認やエラー表示を見づらくする場合は、専用ブラウザーの拡張一覧で一時無効にして解決後に再度有効にしてください。
6. 準備が済んだら専用ブラウザーの**全ウィンドウを閉じ**、コマンドが終了することを確認します。準備用ウィンドウを残したまま配信起動はできません。

通常版Chromeでは `--load-extension` に依存できないため、拡張は手動読込みです。ブラウザー設定・拡張の有効状態をスクリプトが認証情報とともに読むことはありません。本人が表示を確認してください。

## 起動とSunshine登録

まず本人が端末から試します。

```bash
python3 launch-pjivn-linux.py run
```

全画面でゲーム領域が表示され、タッチや入力が合うことを確認します。終了は専用ウィンドウを閉じるか、起動した端末で `Ctrl+C` を押してください。このランチャーが起動した子プロセスだけに通常終了を依頼します。ゲーム窓の目視確認をスクリプトによる成功判定と混同しないでください。

Chrome for Testingを使う場合、画面上部のテスト版案内がゲーム領域を狭めるため、配信用の `run` に `--disable-infobars` を付けています。操作不要の案内バーを抑制するオプションで、初回設定用の `setup` には付けません。[Chromiumの説明](https://chromium.googlesource.com/chromium/src/+/main/docs/chrome_for_testing/)を参照してください。Chrome for Testingは自動更新されないため、ブラウザー本体の更新は別途必要です。

Sunshineに登録するアプリのJSONを表示します。自動登録・既存アプリの書換えはしません。

```bash
python3 launch-pjivn-linux.py commands
```

SunshineのApplicationsで、表示された名前のアプリを追加します。`cmd` の値を **Command**、`working-dir` を **Working Directory** に入れ、**Auto-detachを無効、Wait-allを無効、Exit Timeoutを15秒**にします。JSON中のエスケープを含めたまま貼らず、各文字列の値を使ってください。**Command Preparations（do/undo）は空**にします。Windows用のdo/undoを混ぜないでください。

コマンドはSunshineのパーサー用の二重引用符で生成します。保存先・設定ファイル・Python実行ファイルのパスに空白や日本語を使えますが、`$`、二重引用符、バックスラッシュ、制御文字を含むパスは生成時に拒否します。Sunshine独自の環境変数展開や引数分割によって別のパスにならないための制限です。

Linux版はSunshineのCommandとして動き続け、専用ブラウザー終了まで待ちます。Moonlightで「アプリを終了」を選ぶとSunshineからの終了要求を専用ブラウザーに伝えます。切断だけならゲームが動き続ける場合があります。手動復旧は同じ専用ウィンドウを閉じる方法を使います。

Sunshineは同じデスクトップユーザーで実行し、Waylandのセッション環境と同じ `XDG_DATA_HOME` を使ってください。ダミープラグだけでは、ログアウト・ロック画面を解除したり、再起動後にデスクトップへログインしたりする機能は得られません。

## 本人が確認する受け入れ条件

1. `setup` で拡張を読み込み、ゲームへログインできる。専用ブラウザー終了後も次回ログイン状態を使える。
2. `run` でゲーム領域が全画面に収まり、欠け・余白・入力位置を確認できる。他のブラウザーはそのまま残る。
3. Moonlightから登録アプリを選び、表示・音声・タッチを確認できる。
4. Moonlightのアプリ終了で専用ブラウザーが閉じ、デスクトップへ戻る。再起動できる。

これらは本人確認の結果を記録します。ユニットテストや `doctor` だけで合格にはしません。ゲームのLinux互換性、Chromeの全画面挙動、拡張の実適用はこの実機確認で確定します。

## 復旧と更新

- 「使用中」なら、既存の専用ブラウザーを閉じてから再実行します。全Chromeプロセスの終了や通常プロファイルの削除はしません。
- `SingletonLock` が残っていても、同一ホストのPIDが既に存在しないと確認できた場合はChromium自身の回復に進みます。PIDが生存中、別ホスト、権限不足、不明な形式の場合は停止します。スクリプトはロックやプロファイルを削除しません。
- 通常終了が10秒以内に完了しない場合はエラーにし、本人の手動終了を案内します。ランチャーは強制終了をしません。ただしSunshine自身の終了タイムアウト後の動作はSunshine側の管理です。
- Linux版ではWindowsの `.local/` 復元記録を作成・移植しません。専用プロファイルと `profile-owner.txt` はセットで保持します。認証情報をGitやログへ保存しないでください。
- 更新前に専用ブラウザーを終了します。mainの検証済みコミットに揃え、拡張を本人が再読込みして確認します。配置場所を移すと、拡張の読込み先・Sunshineコマンドも変わります。

実装の根拠: [Sunshineのアプリ定義](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2getting__started.html)、[Chromeのcontent_scripts](https://developer.chrome.com/docs/extensions/reference/manifest/content-scripts)、[Chromeのload-extension変更](https://groups.google.com/a/chromium.org/g/chromium-extensions/c/1-g8EFx2BBY/m/S0ET5wPjCAAJ)。
