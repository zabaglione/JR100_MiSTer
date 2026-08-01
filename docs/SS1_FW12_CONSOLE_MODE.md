# SuperStation One FW 1.2とConsole ModeでJR-100を使う

- 実機確認日：2026年8月1日
- 確認環境：SuperStation One FW 1.2、Console Mode 1.1.1
- 確認コア：`JR100_20260801.rbf`

この文書は、SuperStation One（SS1）固有の配置とConsole Modeからの起動手順を記録する。
通常のMiSTerでJR-100コアを使う方法は、[README.ja.md](../README.ja.md)を参照する。

## FW 1.2への更新

既存カード上で`Scripts/update.sh`を実行しても、FW 1.2のSD Card Installerでカードを作り直した状態と同一にはならない。
通常のMiSTer配布物は更新されるが、FW 1.2にはインストーラ、SS1向けLinux、BluetoothおよびWi-Fiに関する変更も含まれる。
今回の実機確認は、FW 1.2のイメージを入れ直した環境で行った。

FW 1.1との差と`update.sh`の適用範囲は、[SS1 1.2とConsole Modeの更新調査](research/ss1-firmware-1.2-console-mode.md)に記録している。

## Console ModeとJR-100コアの配置

Console Mode 1.1.1を既存カードへ導入する場合は、公式リリースの`Install_Console_Mode.sh`を`/media/fat/Scripts/`へ置く。
同リリースが指定するSupplementary Filesの`linux.img`と`zImage_dtb`も、実行前に`/media/fat/linux/`へ配置する。

JR-100コアはComputerコア用ディレクトリへ置く。

```text
/media/fat/_Computer/JR100_20260801.rbf
```

JR-100 BASIC ROMは配布物に含まれない。
利用権を持つ8KiBの`boot.rom`を、MiSTer Mainが選択しているゲームルートの`games/JR100/`へ配置する。

SS1ではSDカードの`/media/fat/games/`とは別に、USBストレージの`/media/usb2/games/`がゲームルートとして選ばれることがある。
今回の確認機では、JR-100の実際のゲームルートは次の場所だった。

```text
/media/usb2/games/JR100/
```

コアとROMを配置した後にConsole Modeを再起動すると、`Load Core`の一覧へJR-100が現れ、JR-BASICが起動する。

## Load GameへJR-100を追加する

Console Mode 1.1.1はJR-100の生の`.prg`や`.bas`を直接扱う機種別ランチャーを持たない。
一方、ゲーム一覧からMGLを選ぶ経路は利用できる。
MGLが、起動するRBFとJR-100コアのロードスロットを指定する。

`/media/fat/ConsoleMode/themeconfig/section_groups/Computer.ini`の`[CONSOLES]`にある`consoleList`へ`JR-100`を加え、次の節を追加する。

```ini
[JR-100]
execs = none
romExts = .mgl
romDirs = /media/fat/games/JR100/
```

この設定では、一覧へ出すMGLを`/media/fat/games/JR100/`から探す。
設定後はConsole Modeのゲームデータベースを再構築し、Console Modeを再起動する。
Console Modeを更新すると`Computer.ini`が置き換わる可能性があるため、更新後はJR-100節を確認する。

## Autostartを一度だけ保存する

JR-100コアのOSDで`Autostart loaded program`を`Yes`にし、設定を保存する。
設定は`/media/fat/config/JR100.CFG`へ保存される。

この初期設定のために、最初の一度だけ`Load Core`からJR-100を起動する必要がある。
保存後は、Console Modeの起動直後から`Load Game`でMGLを選べる。
ゲームを起動するたびに先に`Load Core`を実行する必要はない。
このOSD設定を保存した後に、Console Modeを再起動したりゲームデータベースを再構築したりする必要もない。

FWイメージを入れ直すなどして`JR100.CFG`を失った場合は、Autostartを設定し直す。

`JR100_20260725.rbf`では、PRG転送後の自動打鍵が早く始まり、`A=USR($0D00)`の先頭が欠ける場合がある。
MGLの`delay`を2秒から5秒へ延ばしても解消しない。
MGLの待ちはPRG転送前に適用される一方、問題は転送後のコア内部待ち時間にあるためである。

画面に`R($0D00)`のような後半だけが現れて`SYNTAX ERROR`になる場合、MGLの選択、F1転送、およびAutostart設定の読み出しは完了している。
この場合もConsole Modeの再起動やゲームデータベース再構築では解消せず、修正版RBFが必要になる。

この事象はシミュレーションでも、`A=`が欠けた`USR($1000)`と`SYNTAX ERROR`として再現した。
コア側では転送後の待ちを約0.28秒から約1.68秒へ延ばし、READY前にPRGを渡す回帰テストを追加した。
修正を含む`JR100_20260801.rbf`では、旧版が失敗したMGLの`delay="5"`でもSTAR FIREが正常に起動した。
通常設定の`delay="2"`へ戻した後も、3回連続でタイトル画面まで進むことを確認した。

## 機械語のみの例

STAR FIREはBASIC部分を持たず、`$0D00`から実行する機械語PRGである。
元のPROG形式には実行開始アドレスがないため、まず本リポジトリのツールで`USR=$0D00`マーカーを持つPROG v2を作る。

```bash
python3 tools/prg_autostart.py STARFIRE.prg STARFIRE_AUTO.prg 0D00
```

生成した`STARFIRE_AUTO.prg`を、実際に選択されているゲームルートへ置く。
今回の確認機では次の配置である。

```text
/media/usb2/games/JR100/STARFIRE_AUTO.prg
```

Console Modeが走査するディレクトリへ`STAR FIRE.mgl`を作る。

```xml
<mistergamedescription>
  <rbf>_Computer/JR100</rbf>
  <file delay="2" type="f" index="1" path="STARFIRE_AUTO.prg"/>
</mistergamedescription>
```

```text
/media/fat/games/JR100/STAR FIRE.mgl
```

`type="f" index="1"`はJR-100コアの`F1,prg`へファイルを転送する。
ロード完了後、Autostartがマーカーを読み、`A=USR($0D00)`を自動入力する。
この構成と`JR100_20260801.rbf`で、Console Modeの`Load Game`からSTAR FIREを選び、3回連続でタイトル画面まで進むことを実機で確認した。
旧コアでは前節の文字欠落が断続的に発生するため、修正版RBFを使用する。

## BASICのみの例

BASICテキストは`F2,bas`へ渡す。
Autostartはロード後に`RUN`を入力するため、`USR=$hhhh`マーカーは不要である。

たとえば`twinkle_star.bas`を実際のゲームルートへ置き、Console Modeが走査するディレクトリへ`TWINKLE STAR.mgl`を作る。

```xml
<mistergamedescription>
  <rbf>_Computer/JR100</rbf>
  <file delay="2" type="f" index="2" path="twinkle_star.bas"/>
</mistergamedescription>
```

`type="f" index="2"`はJR-100コアのBASICテキストローダーを選ぶ。
このローダーはプログラムをBASIC領域へ展開し、必要なワークポインタを設定してから、Autostartによる`RUN`へ進む。

## BASIC画面で止まる場合

MGLを選んでも`READY`表示で止まる場合は、Autostartだけでなく、MGL内の相対パスがどのゲームルートへ解決されたかを確認する。
今回の初回設定では、ファイルを`/media/fat/games/JR100/`へ置いた一方、MiSTer Mainは次のパスを開こうとしていた。

```text
../usb2/games/JR100/STARFIRE_AUTO.prg
```

このためF1ロード処理は対象選択まで進んだが、対象ファイルを開けず、JR-BASICの`READY`で止まった。
`STARFIRE_AUTO.prg`を`/media/usb2/games/JR100/`へ置くと自動起動した。

パスを確認する場合は、`/media/fat/MiSTer.ini`の`log_file_entry`を一時的に`1`へ変更し、Console Modeを再起動して対象MGLを実行する。
実際に選ばれたパスは`/tmp/FULLPATH`へ記録される。
確認後は余分な実行時記録を残さないよう、`log_file_entry=0`へ戻す。

次の順序で切り分けると、設定保存とファイル配置を混同せずに済む。

1. `Load Core`でJR-100が起動し、`boot.rom`から`READY`まで進むか確認する。
2. OSDで`Autostart loaded program`が`Yes`になっているか確認する。
3. MGLの`type`と`index`が、PRGでは`F1`、BASICテキストでは`F2`になっているか確認する。
4. `/tmp/FULLPATH`が示す場所に対象ファイルが存在するか確認する。
5. 機械語PRGでは、PROG v2コメントの`USR=$hhhh`と実際の開始アドレスが一致するか確認する。

Console ModeのComputer系`Load Game`とMGLの処理経路は、[Console ModeのComputer系Load GameとJR-100接続調査](research/console-mode-load-game-computers.md)に記録している。
