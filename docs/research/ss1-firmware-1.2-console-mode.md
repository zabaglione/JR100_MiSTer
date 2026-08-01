# SS1 1.2 と Console Mode の更新調査

- 調査日: 2026-08-01
- 対象: SuperStation One 既存SDカードで `Scripts/update.sh` を実行した場合と、SuperStation 1.2 SD Card Installerを使った場合の差

## 結論

`update.sh` の実行だけでは、SuperStation 1.2 SD Card Installerと同じ状態になったとは判断できない。通常のMiSTer配布物（コアなど）の更新は重なるが、1.2にはSDカードインストーラ自体の修正とSS1向けLinux・無線関連の変更が含まれる。

1.2のうち、CRT対応およびSamsung Evo Plusカード向け信頼性改善はインストーラ工程の変更なので、既存カード上でMiSTerを利用する通常動作には直接影響しない。一方、NSOコントローラのペアリング修正、Bluetooth 4.2対応、WPA3 Wi-Fi修正は実行環境側の差であり、`update.sh` だけで適用済みとはみなせない。公式リリースは、SS1向けLinuxバイナリを維持するため `/MiSTer.version` を `050402` に偽装し、通常の `update.sh` がLinuxバイナリをダウングレードする判定を回避していることも明記している。

出典: [SuperStation v1.2 SD Card Installer](https://github.com/Retro-Remake/SuperStation-SD-Card-Installer/releases/tag/1.2)、[Linux image commit 24ecf64](https://github.com/MiSTer-devel/Linux_Image_creator_MiSTer/commit/24ecf64c0c8751a9aee5e7c8c7e068464bd611e6)

## 1.1から1.2への主な差

1.1と1.2の公式リリースノートを比較すると、1.2で追加された内容は次のとおり。

- インストーラのCRT対応
- Samsung Evo Plusカードでのインストーラ信頼性改善
- 同梱コア等を2026-07-24時点へ更新
- NSOコントローラのペアリング修正
- Bluetooth 4.2対応
- WPA3 Wi-Fi接続修正

SS1向けLinuxバイナリ `24ecf64` と `/MiSTer.version=050402` の回避策は1.1リリースにも記載されているため、1.1イメージからの更新であればこの部分は新規差分ではない。

出典: [SuperStation v1.1 SD Card Installer](https://github.com/Retro-Remake/SuperStation-SD-Card-Installer/releases/tag/1.1)、[SuperStation v1.2 SD Card Installer](https://github.com/Retro-Remake/SuperStation-SD-Card-Installer/releases/tag/1.2)

## Console Modeの既存カードへの導入

Console Mode 1.1.1の公式手順は次のとおり。

1. `Install_Console_Mode.sh` を `/media/fat/Scripts/` にコピーする。
2. Supplementary Filesの `linux.img` と `zImage_dtb` を `/media/fat/linux/` にコピーする。
3. MiSTerのScriptsメニューから「Install Console Mode」を実行する。

公式インストーラは自己展開型で、Console Mode本体、ホスト、menuコア、フォント等を展開する。新規インストール時はルートの映像設定INIを `.bak` へ退避してからConsole Mode用INIへ置換し、最後に再起動する。Supplementary Filesはインストーラに内包されず、存在とハッシュを確認するだけなので、既存カードへ導入する場合は別途配置が必要である。

出典: [Console Mode 1.1.1 release](https://github.com/Retro-Remake/ConsoleMode_Distribution/releases/tag/1.1.1)、[Supplementary Files](https://github.com/Retro-Remake/ConsoleMode_Distribution/releases/tag/supplementary)、[公式インストーラ](https://github.com/Retro-Remake/ConsoleMode_Distribution/releases/download/1.1.1/Install_Console_Mode.sh)

## 取得したインストーラの検証値

- ファイル: `Install_Console_Mode.sh`
- リリース: Console Mode 1.1.1
- サイズ: 21,816,886 bytes
- SHA-256: `34d54d23eb57d01a4ca66f58a75fe1fb801576fde82939eee00c1e4a0ae28337`

この値はGitHub Releases APIが示すアセットdigestと一致した。

出典: [ConsoleMode Distribution releases API](https://api.github.com/repos/Retro-Remake/ConsoleMode_Distribution/releases/tags/1.1.1)

## 実機適用結果

FW 1.2のイメージを入れ直したSS1へConsole Mode 1.1.1とJR-100コアを配置し、JR-BASICの起動を確認した。
さらに、`Computer.ini`へJR-100用MGLを登録し、Console Modeの`Load Game`から機械語PRGのSTAR FIREを起動できた。
`JR100_20260725.rbf`では自動打鍵の先頭が欠ける場合があり、コア内部の転送後待ち時間を延長する修正と回帰テストを追加した。
修正版`JR100_20260801.rbf`では、旧版が失敗したMGL条件でもSTAR FIREが正常に起動した。
通常設定の`delay="2"`へ戻した後も、3回連続でタイトル画面まで進んだ。

この環境では、MGL内の相対パスは`/media/fat/games/`ではなくUSBストレージ側の`../usb2/games/`へ解決された。
設定とトラブルシューティングは[SS1 FW 1.2とConsole ModeでJR-100を使う](../SS1_FW12_CONSOLE_MODE.md)を参照する。
