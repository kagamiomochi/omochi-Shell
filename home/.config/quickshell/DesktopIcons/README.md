# QuickShell Desktop Icons

xfdesktop の「デスクトップにアイコンを並べて表示する」機能だけを
QuickShell + Hyprland で再現するモジュール。`~/Desktop` の中身を
壁紙の上・通常ウィンドウの下のレイヤーに並べ、ダブルクリックで起動できる。
アイコンはドラッグで自由に動かせて、位置は再起動後も保持される。

## 構成

```
DesktopIcons/
├── DesktopIcons.qml       # 本体 (Scope)。shell.qml から読み込む
├── DesktopIconItem.qml    # アイコン1個分のドラッグ/起動ロジック
└── scripts/
    └── list-desktop-icons.sh  # ~/Desktop を走査してJSONを返すスクリプト
```

## インストール

1. `DesktopIcons/` フォルダをまるごと、自分の QuickShell 設定ディレクトリ
   (`shell.qml` があるフォルダ、例: `~/.config/quickshell/omochi-shell/`)
   の直下にコピーする。フォルダ名は `DesktopIcons` のままにしておくと、
   `DesktopIcons.qml` 内の `scriptPath` の既定値がそのまま使える。

2. `scripts/list-desktop-icons.sh` に実行権限を付ける。

   ```bash
   chmod +x DesktopIcons/scripts/list-desktop-icons.sh
   ```

   `python3` を JSON エスケープに使っているので、入っていない場合は
   `sudo pacman -S python` を入れておく。

3. `shell.qml` に追記する。

   ```qml
   import "./DesktopIcons" as DesktopIconsModule
   // または import qs.DesktopIcons が使える環境ならそちらでも良い

   ShellRoot {
       // ...既存のバーなど...

       DesktopIcons {}
   }
   ```

   相対 import の書き方は QuickShell のバージョンによって挙動が変わるので、
   うまく読み込めない場合は `DesktopIcons.qml` の中身を直接
   既存の `shell.qml` と同じディレクトリに置いてしまってもよい。

4. QuickShell を再起動 (`qs -c omochi-shell` など普段の起動コマンド) すれば、
   `~/Desktop` にあるファイルと `.desktop` ショートカットがアイコンとして
   デスクトップに並ぶ。

## Hyprland 側の設定

レイヤーシェル (`zwlr_layer_shell_v1`) の `Bottom` レイヤーに出しているので、
Hyprland 側で特別な `windowrulev2` は基本的に不要。通常ウィンドウは自動的に
このレイヤーの上に重なる。挙動を確認・調整したいときは以下が使える。

```bash
hyprctl layers   # DesktopIcons が namespace "quickshell-desktop-icons" として
                  # 各モニターの layer=0 (background/bottom側) に出ているか確認
```

フルスクリーンアプリの下に完全に隠したい、複数モニターのうち1枚だけに
出したい、といった調整は `DesktopIcons.qml` の `targetScreens` プロパティで
`Quickshell.screens` の代わりに `[Quickshell.screens[0]]` のように絞り込めば良い。

## カスタマイズできるプロパティ (`DesktopIcons.qml`)

| プロパティ | 説明 | 既定値 |
|---|---|---|
| `desktopPath` | 走査するディレクトリ | `~/Desktop` |
| `scriptPath` | スキャン用スクリプトのパス | `<shellDir>/DesktopIcons/scripts/list-desktop-icons.sh` |
| `positionsFile` | アイコン位置の保存先JSON | `~/.local/state/quickshell/desktop-icons.json` |
| `targetScreens` | アイコンを表示するモニター一覧 | 全モニター |
| `cellWidth` / `cellHeight` | 初期配置のグリッド間隔 | 90 / 100 |
| `columns` | 初期配置の列数 | 6 |
| `rescanIntervalMs` | `~/Desktop` の再走査間隔(ms)。0以下で無効 | 5000 |

## 既知の制約・今後の課題

- ファイル監視 (inotify) ではなく単純なポーリング(既定5秒間隔)で
  `~/Desktop` の変化を拾っている。即時反映が必要ならタイマー間隔を短くするか、
  `FileView` の `watchChanges` をディレクトリ監視に置き換える改修が必要。
- 右クリックメニュー(名前変更・削除・新規作成など)は未実装。
  `MouseArea.acceptedButtons` に `Qt.RightButton` を足して
  `QsMenuAnchor` 等でコンテキストメニューを追加すると発展させられる。
- アイコンはグリッドにスナップせず自由配置。スナップさせたい場合は
  `onPositionChanged` で `cellWidth`/`cellHeight` に丸める処理を挟むとよい。
- QuickShell は開発が活発で破壊的変更が入ることがある
  (例: `Quickshell.shellRoot` → `Quickshell.shellDir` への改名)。
  手元のバージョンで `scriptPath` の解決がうまくいかない場合は
  絶対パスを直接指定するのが一番確実。
