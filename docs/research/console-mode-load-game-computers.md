# Console ModeのComputer系Load GameとJR-100接続調査

- 調査日: 2026-08-01
- 対象: Console Mode 1.1.1、MiSTer Main、JR-100コア、および代表的なComputerコア
- 対応表: [referent-table-console-mode-load-game-computers.md](./referent-table-console-mode-load-game-computers.md)

## 結論

1. Console Modeの`Load Game`は、Computerカテゴリでも実装されている。ただし、任意のComputerコアへ汎用的にファイルを渡す仕組みではなく、配布側が機種とメディア受け渡し方法を登録した範囲で成立する。
2. `Computer.ini`の`execs`、`romExts`、`romDirs`だけでは不十分である。これらは主に機種一覧、ファイル探索、およびコア選択候補を作る。選択ファイルをどのRBFのどの`F`または`S`スロットへ渡すかは、別のConsole Modeホスト処理が決める。
3. 選択ファイルは、フロントエンドから専用ホストへ渡され、ホストが一時的なMGLを生成し、MiSTer MainがMGL内の`type`と`index`をコアの`CONF_STR`へ照合する。`F`はファイル転送、`S`はブロックイメージのマウントになる。
4. Console Mode 1.1.1の`Computer.ini`にはJR-100の機種別エントリがない。配布ホストのバイナリから確認できる組込みコア一覧にも`_Computer/JR100`または`JR-100`は見つからない。したがって、`Computer.ini`だけを追加しても、現行配布物のままでは起動時受け渡しまで到達しない可能性が高い。
5. JR-100のPRG/BAS即時ロードは、コア側にすでに標準MiSTerの`F1`、`F2`受け口がある。Console Modeホストへ`.prg -> F1`、`.bas -> F2`の登録を追加すれば、コア側の新しいローダーを作らずに接続できる。
6. テープイメージは既存の`S1,cmt`へマウントできる。しかし、マウントだけではBASICの`LOAD`入力と`Tape Play`操作は実行されない。完全なワンクリック起動には、コア側の自動操作、またはConsole Mode/MGL側の制御拡張が別途必要である。
7. ホストバイナリを変更せず、JR-100用MGLをゲーム一覧へ出す経路は実機で動作した。`Computer.ini`へ`.mgl`だけを登録し、MGLからJR-100の`F1`へ機械語PRGを渡すことで、Console Modeの`Load Game`からSTAR FIREを起動できた。ただし、`JR100_20260725.rbf`では自動打鍵開始が早く、先頭文字を失う場合があった。

確認済み: MiSTer公式MGL資料も、Computerコアはロード後に自動起動する仕組みがなければ一般にMGLとの相性がよくないと明記している。[MGL資料 L1-L6](https://github.com/MiSTer-devel/MkDocs_MiSTer/blob/a592197e7d5e3c7a723d8629c7037c3736b14afa/docs/advanced/mgl.md#L1-L6) したがって「ComputerカテゴリでLoad Gameが使える」と「全Computerコアが選択後に自動実行まで進む」は同義ではない。

実機確認済み: SS1 FW 1.2とConsole Mode 1.1.1では、MGLの`type=F,index=1`がJR-100のPRGローダーへ到達した。`Autostart loaded program`を保存し、`USR=$0D00`マーカーを付けたSTAR FIREを渡すと、`A=USR($0D00)`の自動入力からタイトル画面まで進んだ。旧`JR100_20260725.rbf`では再試行時に先頭数文字が欠け、`R($0D00)`だけが入力される事象も確認した。転送後の待ちを延長した`JR100_20260801.rbf`では、旧版が失敗した条件でも正常に起動した。通常設定の`delay="2"`へ戻した後も、3回連続でタイトル画面まで進んだ。手順と配置は[SS1 FW 1.2とConsole ModeでJR-100を使う](../SS1_FW12_CONSOLE_MODE.md)に記録した。

以下では、ソースで直接確認できた内容を「確認済み」、配布バイナリの文字列・オフセットから確認した内容を「配布物確認」、そこから導いた設計判断を「推論」または「提案」と記す。

## Load Gameの処理経路

### 1. Computer.iniは一覧と探索条件を作る

確認済み: フロントエンドは`CONSOLES.consoleList`を読み、各節の`execs`、`romExts`、`romDirs`をカンマ区切りで格納する。[Configuration.cpp L256-L295](https://github.com/Retro-Remake/Console-Mode/blob/af7add85eeb83a902e7abc145d7d16270678e0df/src/Configuration.cpp#L256-L295)

確認済み: `romExts`はディレクトリ内のファイルを拡張子で絞り込み、該当ファイルを含む下位ディレクトリを一覧へ残すために使われる。[FileManager.cpp L40-L87](https://github.com/Retro-Remake/Console-Mode/blob/af7add85eeb83a902e7abc145d7d16270678e0df/src/FileManager.cpp#L40-L87) [FileManager.cpp L119-L155](https://github.com/Retro-Remake/Console-Mode/blob/af7add85eeb83a902e7abc145d7d16270678e0df/src/FileManager.cpp#L119-L155)

確認済み: 公開ソースで確認できる`execs`の用途は、機種ごとのコア選択候補へ実行ファイル名を追加する処理である。ここにはメディアの`F/S`種別やスロット番号を指定する項目がない。[Settings.h L441-L460](https://github.com/Retro-Remake/Console-Mode/blob/af7add85eeb83a902e7abc145d7d16270678e0df/include/Settings.h#L441-L460)

配布物確認: 1.1.1同梱の`ConsoleMode/themeconfig/section_groups/Computer.ini`では、53機種すべてが`execs = none`である。一方で`Load Game`用の`romExts`と`romDirs`は機種ごとに登録されている。これは`execs`が通常のファイル受け渡し先を直接定義していないこととも整合する。公式配布物は[1.1.1のInstall_Console_Mode.sh](https://github.com/Retro-Remake/ConsoleMode_Distribution/releases/download/1.1.1/Install_Console_Mode.sh)であり、同リリースアセットの35-42行に自己展開方法がある。`Install_Console_Mode.sh`自体は配布リポジトリのGitツリーには含まれないため、存在しないblob URLは根拠に使っていない。抽出した`Computer.ini`のSHA-256は`6071e608b34b8fd5ce7229f9c252eb818189821c84f8b90927235be03e400eee`である。

したがって、`Computer.ini`の3項目でできることは次の範囲である。

| 項目 | 確認できた役割 | これだけでは決められないもの |
|---|---|---|
| `romDirs` | 検索するゲームディレクトリ | 起動するRBF、ロード先スロット |
| `romExts` | 一覧へ出すファイル拡張子 | `F`転送か`S`マウントか、スロット番号 |
| `execs` | コア選択候補 | 拡張子ごとのメディア受け渡し方法 |

### 2. 選択パスは専用ホストへ渡される

確認済み: ゲーム選択後、フロントエンドは選択ファイルのパスを`launchPath`へ入れ、必要なら選択コア情報を付加し、`launchMiSTerRR()`を呼んで終了する。[Application.cpp L3216-L3251](https://github.com/Retro-Remake/Console-Mode/blob/af7add85eeb83a902e7abc145d7d16270678e0df/src/Application.cpp#L3216-L3251)

確認済み: `launchMiSTerRR()`とコア情報付加処理の実装は公開されているMPL部分には含まれない。公開リポジトリ自身も、Retro Remake独自部分を含まず、そのツリー単独ではビルドできないと明記する。[Console-Mode README L8-L13](https://github.com/Retro-Remake/Console-Mode/blob/af7add85eeb83a902e7abc145d7d16270678e0df/README.md#L8-L13)

配布物確認: 1.1.1の`ConsoleMode_arm`には`/dev/MiSTer_RR_cmd`、`?rbf=`、`?core=`が含まれる。`MiSTer_ConsoleMode`には同じデバイス名に加え、次の文字列が含まれる。

| バイトオフセット | 配布ホスト内の文字列 |
|---:|---|
| `0x109064` | `/dev/MiSTer_RR_cmd` |
| `0x10e5fc` | `RR rbf override not supported for direct-load path` |
| `0x10e630` | `RR no matching launcher` |
| `0x10e684` | `<mistergamedescription>` |
| `0x10e6c5` | `<file delay="%d" type="%s" index="%d" path="%s%s"/>` |
| `0x10e748` | `/media/fat/.LASTLAUNCH.mgl` |
| `0x10e82c` | `MiSTer_RR_cmd: launcher=%s system=%s rbf=%s mgl=%s` |
| `0x10e860` | `RR no matching MGL slot` |
| `0x10e878` | `RR unknown core` |

対象ホストのSHA-256は`4b2c79238a480078bb8ea6105e06c06292eda3055e96171a21c6d1b3fc06885d`である。配布物の構成とホストの位置づけは[ConsoleMode_Distribution README L21-L40](https://github.com/Retro-Remake/ConsoleMode_Distribution/blob/62ab6c7aa5b028d3fd2ab3917045242d4c8be7c1/README.md#L21-L40)に記載されている。

推論: これらは、ホストが選択パスを直接コアへ渡すのではなく、機種・拡張子に対応するランチャーとMGLスロットを照合し、`.LASTLAUNCH.mgl`を生成する構造を示す。配布READMEは[Retro-Remake/MiSTer_ConsoleMode](https://github.com/Retro-Remake/MiSTer_ConsoleMode)をホストのGPLソースとして案内しているが、2026-08-01時点ではリポジトリURLとGitHub APIの両方が404であり、組織の公開リポジトリ一覧にも存在しなかった。このため、ホストの対応表はバイナリから見える範囲を越えて確定できない。

### 3. MiSTer MainがMGLのF/Sスロットを実行する

確認済み: MiSTer MainのMGL項目は、パス、遅延、`type`、`index`を持ち、最大6項目を保持する。[mra_loader.h L30-L56](https://github.com/MiSTer-devel/Main_MiSTer/blob/7db21a8135cee70a6fe529fa877d3d6ef998d129/support/arcade/mra_loader.h#L30-L56)

確認済み: MGLの`file`要素で受理される`type`は`F`または`S`であり、`index`と`path`も必須である。MGLから実行できる別の動作は`reset`である。[mra_loader.cpp L1331-L1413](https://github.com/MiSTer-devel/Main_MiSTer/blob/7db21a8135cee70a6fe529fa877d3d6ef998d129/support/arcade/mra_loader.cpp#L1331-L1413)

確認済み: 公式MGL資料では、`rbf`をSDルートからのコア相対パス、`type=f`をメモリへのファイルロード、`type=s`をファイルのマウント、`index`をコア内の対象スロットとして定義する。[MGL資料 L50-L68](https://github.com/MiSTer-devel/MkDocs_MiSTer/blob/a592197e7d5e3c7a723d8629c7037c3736b14afa/docs/advanced/mgl.md#L50-L68)

確認済み: Mainは起動したコアの`CONF_STR`を走査し、先頭が`F`または`S`で、MGLの`type`と`index`が一致する項目を選ぶ。[menu.cpp L2001-L2012](https://github.com/MiSTer-devel/Main_MiSTer/blob/7db21a8135cee70a6fe529fa877d3d6ef998d129/menu.cpp#L2001-L2012)

確認済み: `F`項目は通常`user_io_file_tx()`へ到達し、ファイル内容をコアへ転送する。[menu.cpp L2611-L2715](https://github.com/MiSTer-devel/Main_MiSTer/blob/7db21a8135cee70a6fe529fa877d3d6ef998d129/menu.cpp#L2611-L2715) `S`項目は通常`user_io_file_mount()`へ到達し、選択イメージを指定スロットへマウントする。[menu.cpp L2733-L2818](https://github.com/MiSTer-devel/Main_MiSTer/blob/7db21a8135cee70a6fe529fa877d3d6ef998d129/menu.cpp#L2733-L2818)

以上をまとめると、通常経路は次の順序になる。

1. `Computer.ini`が機種と一覧対象ファイルを決める。
2. フロントエンドが選択ファイルのパスを専用ホストへ送る。
3. ホスト内の登録が、起動RBFとMGLの`F/S`種別・スロット番号を決める。
4. MiSTer MainがRBFを起動し、MGL項目をコアの`CONF_STR`へ照合する。
5. `F`ならファイルをストリーム転送し、`S`ならブロックイメージとしてマウントする。

このため、Computerカテゴリに節を追加してファイルを一覧へ出すことと、選択ファイルがコアへ届くことは別の受入条件である。

## 1.1.1で登録されているFDD系ファイル

次表は、1.1.1同梱`ConsoleMode/themeconfig/section_groups/Computer.ini`から、フロッピーディスク形式と判断できる拡張子を持つ節を抜き出したものである。`zip`、テープ、カートリッジ、およびVHD/CHD/HDFのようなハードディスク形式は除外した。`.img`のように用途が一意でない形式も表から除外した。

| 機種節 | 登録されているFDD系拡張子 | 配布物内の行 |
|---|---|---:|
| AMIGA | `.adf` | 4-7 |
| AMSTRAD CPC | `.dsk` | 14-17 |
| AMSTRAD PCW | `.dsk` | 19-22 |
| APPLE IIE | `.nib`, `.dsk`, `.do`, `.po` | 34-37 |
| ATARI 800XL | `.atr`, `.xfd`, `.atx` | 39-42 |
| BBC MICRO/MASTER | `.ssd`, `.dsd` | 49-52 |
| BK0011M | `.dsk` | 54-57 |
| COMMODORE 16 | `.d64`, `.g64` | 64-67 |
| COMMODORE 64 | `.d64`, `.g64`, `.d81` | 69-72 |
| COMMODORE VIC-20 | `.d64`, `.g64` | 79-82 |
| MSX1 | `.dsk` | 129-132 |
| MACINTOSH PLUS | `.dsk` | 134-137 |
| ORIC | `.dsk` | 154-157 |
| SAM COUPE | `.dsk`, `.mgt`, `.sad` | 184-187 |
| SPECIALIST/MX | `.edd`, `.fdd` | 199-202 |
| TRS-80 | `.dsk` | 209-212 |
| TRS-80 COCO 2 | `.dsk` | 214-217 |
| TATUNG EINSTEIN | `.dsk` | 234-237 |
| X68000 | `.hdm`, `.dim`, `.2hd`, `.xdf` | 254-257 |
| ZX SPECTRUM | `.dsk`, `.trd`, `.scl`, `.fdi`, `.udi`, `.mgn` | 259-262 |

配布物確認: これらは一覧対象としての登録を示すだけで、各拡張子が必ず正しいスロットへ渡ることを`Computer.ini`単独では証明しない。

一方、代表例では実際のコアの`S`スロットまで照合できる。

| 機種 | コアのCONF_STR | コア側の接続 | 判定 |
|---|---|---|---|
| Amstrad CPC | `S0,DSK`と`S1,DSK` | `img_mounted[1:0]`をu765へ接続 | DSKをFDD A/Bとしてマウント可能 |
| Apple II | `S0`と`S2`がNIB/DSK/DO/PO、`S1`がHDV | `img_mounted[0]`と`[2]`で各FDDのディスク変更を通知 | 2台のFDDへマウント可能 |
| BBC Micro | `S1,SSDDSD`と`S2,SSDDSD` | `img_mounted[2:1]`をFDCへ接続 | SSD/DSDを2スロットへマウント可能 |
| X68000 | `S0`と`S1`がD88/XDF/DIM/HDM | `img_mounted[1:0]`をFDD処理へ接続 | FDD0/FDD1へマウント可能 |

根拠は次のとおりである。

- Amstrad: [CONF_STR L48-L59](https://github.com/MiSTer-devel/Amstrad_MiSTer/blob/6c2c39b6607fc870f5b60ca893c40fb9c873c81f/Amstrad.sv#L48-L59)、[hps_io L185-L229](https://github.com/MiSTer-devel/Amstrad_MiSTer/blob/6c2c39b6607fc870f5b60ca893c40fb9c873c81f/Amstrad.sv#L185-L229)、[FDC接続 L745-L774](https://github.com/MiSTer-devel/Amstrad_MiSTer/blob/6c2c39b6607fc870f5b60ca893c40fb9c873c81f/Amstrad.sv#L745-L774)
- Apple II: [CONF_STR L62-L69](https://github.com/MiSTer-devel/Apple-II_MiSTer/blob/79f82092dac6b9784ab444a7800be7e6318bdcf3/Apple-II.sv#L62-L69)、[hps_io L172-L201](https://github.com/MiSTer-devel/Apple-II_MiSTer/blob/79f82092dac6b9784ab444a7800be7e6318bdcf3/Apple-II.sv#L172-L201)、[FDDマウント L476-L488](https://github.com/MiSTer-devel/Apple-II_MiSTer/blob/79f82092dac6b9784ab444a7800be7e6318bdcf3/Apple-II.sv#L476-L488)
- BBC Micro: [CONF_STR L55-L62](https://github.com/MiSTer-devel/BBCMicro_MiSTer/blob/c0fd1250bfa75653a743d5a68bba981ef8568127/BBCMicro.sv#L55-L62)、[hps_io L140-L172](https://github.com/MiSTer-devel/BBCMicro_MiSTer/blob/c0fd1250bfa75653a743d5a68bba981ef8568127/BBCMicro.sv#L140-L172)、[FDC接続 L378-L383](https://github.com/MiSTer-devel/BBCMicro_MiSTer/blob/c0fd1250bfa75653a743d5a68bba981ef8568127/BBCMicro.sv#L378-L383)
- X68000: [CONF_STR L59-L69](https://github.com/MiSTer-devel/X68000_MiSTer/blob/4b13c9f37906c664d3f3d779c7bca01a501c38a1/X68000.sv#L59-L69)、[hps_io L397-L425](https://github.com/MiSTer-devel/X68000_MiSTer/blob/4b13c9f37906c664d3f3d779c7bca01a501c38a1/X68000.sv#L397-L425)、[マウント状態 L657-L663](https://github.com/MiSTer-devel/X68000_MiSTer/blob/4b13c9f37906c664d3f3d779c7bca01a501c38a1/X68000.sv#L657-L663)

配布物確認: `MiSTer_ConsoleMode`には`_Computer/Amstrad`、`_Computer/Apple-II`、`_Computer/BBCMicro`、`_Computer/X68000`もそれぞれ`0x10f810`、`0x10f864`、`0x10f980`、`0x10fc28`に含まれる。したがって、少なくともこれらは、一覧、ホストのコア登録、コアの`S`スロットという3層がそろった実例である。

## JR-100の生ファイル直接起動が失敗する理由

### 第1の不足: Computer.iniに機種節がない

確認済み: 1.1.1の`Computer.ini`の`consoleList`は配布物内2行目にあり、JR-100を含まない。個別の`[JR-100]`または`[JR100]`節も存在しない。このままでは通常のComputer一覧からJR-100用の`.prg`、`.bas`、`.cmt`を探索できない。

### 第2の不足: ホスト側の起動時受け渡し登録がない

配布物確認: `MiSTer_ConsoleMode`の組込みコアパス文字列は`_Computer/AcornAtom`から`_Computer/ZXNext`まで多数存在するが、`_Computer/JR100`、`JR100`、`JR-100`は見つからない。またホストは`no matching launcher`、`no matching MGL slot`、`unknown core`を明示的な失敗として持つ。

推論: JR-100節を`Computer.ini`へ足して一覧表示できるようにしても、ホストがJR-100と拡張子をRBFおよびMGLスロットへ対応付けられず、その先で失敗する可能性が高い。コア選択用の`execs`を設定するだけでは、`.prg`を`F1`と`S0`のどちらへ渡すか、`.cmt`を`S1`へ渡すかを表現できない。

### コア側は受け取り不能ではない

確認済み: 現行JR-100コアは次のスロットを公開する。[JR100.sv L63-L84](../../JR100.sv#L63-L84)

| スロット | 用途 | Console Modeから必要な受け渡し |
|---|---|---|
| `F0,rom` | BASIC ROM | 通常は`boot.rom`として起動時に供給し、ゲーム選択には使わない |
| `F1,prg` | PRG即時ロード | MGLの`type=F,index=1` |
| `F2,bas` | BAS即時ロード | MGLの`type=F,index=2` |
| `S0,prg` | BASIC保存先ファイル | ゲームのPRG読込みには使わない |
| `S1,cmt` | テープイメージ | MGLの`type=S,index=1` |
| `T[4]` | Tape Play | MGLのファイル項目だけでは操作されない |

確認済み: `hps_io`は`ioctl_index`、ファイル転送、および2個のイメージスロットを接続している。[JR100.sv L98-L133](../../JR100.sv#L98-L133) `F1`と`F2`はそれぞれPRG/BASダウンロードとしてデコードされ、コア内部のローダーへ接続される。[JR100.sv L176-L185](../../JR100.sv#L176-L185) [JR100.sv L220-L228](../../JR100.sv#L220-L228)

確認済み: PRG/BASローダーはRAMへ内容を展開する。既存の`Autostart loaded program`を有効にした場合、ロード完了後に`RUN`または`A=USR($hhhh)`を自動入力する。[jr100_top.sv L231-L305](../../rtl/jr100/jr100_top.sv#L231-L305)

確認済み: `S1`はテープバッファへ接続されるが、再生開始は別の`Tape Play`パルスである。[JR100.sv L73-L79](../../JR100.sv#L73-L79) [JR100.sv L150-L158](../../JR100.sv#L150-L158) [JR100.sv L240-L250](../../JR100.sv#L240-L250) [jr100_top.sv L309-L370](../../rtl/jr100/jr100_top.sv#L309-L370)

したがって、問題は「JR-100コアに標準MiSTerの受け口がない」ことではない。Console Modeホストの既存登録に、その受け口へ到達するJR-100の対応がないことが主因である。

## JR-100へ必要な変更

### ホストを変更しない実機確認済み経路: MGLラッパー

一次報告: [Console-Mode Issue #20](https://github.com/Retro-Remake/Console-Mode/issues/20)では、報告者が`Computer.ini`のAmiga/CD32節へ`.mgl`を加え、`execs = none`のままゲームディレクトリ内のMGLを`Load Game`から起動する方法を「tested and verified」と報告している。これはRetro Remake担当者による正式仕様の表明ではなく、利用者による直接の試験報告である。

実機確認済み: この経路では、ホストの組込みランチャー表にJR-100の生ファイル形式を追加しなくても、選択したMGL自身がRBF、`F/S`種別、スロット番号を指定できる。`Computer.ini`には次の最小構成を追加した。

```ini
[JR-100]
execs = none
romExts = .mgl
romDirs = /media/fat/games/JR100/
```

PRG用MGL:

```xml
<mistergamedescription>
  <rbf>_Computer/JR100</rbf>
  <file delay="2" type="f" index="1" path="sample.prg"/>
</mistergamedescription>
```

BAS用MGL:

```xml
<mistergamedescription>
  <rbf>_Computer/JR100</rbf>
  <file delay="2" type="f" index="2" path="sample.bas"/>
</mistergamedescription>
```

CMT用MGL:

```xml
<mistergamedescription>
  <rbf>_Computer/JR100</rbf>
  <file delay="2" type="s" index="1" path="sample.cmt"/>
</mistergamedescription>
```

`rbf`と`path`の基準は公式定義に従い、実際のRBF配置名とゲームディレクトリに合わせる。[MGL資料 L50-L68](https://github.com/MiSTer-devel/MkDocs_MiSTer/blob/a592197e7d5e3c7a723d8629c7037c3736b14afa/docs/advanced/mgl.md#L50-L68)

実機で行った変更は次のとおりである。

1. `Computer.ini`の`consoleList`へ`JR-100`を加え、JR-100節に`romExts = .mgl`とMGL配置ディレクトリを登録する。
2. ゲームごとに、PRG/BAS/CMTと同じ場所関係を保ったMGLを生成する。
3. PRGは`F1`、BASは`F2`、CMTは`S1`を指定する。
4. SS1で、RBF起動、`boot.rom`読込み、MGLの遅延後のファイル受け渡しを確認した。

判定: `delay="2"`、`type="f"`、`index="1"`のMGLでSTAR FIREの自動起動経路が成立した。最初の試行では、MGL内の相対パスが`../usb2/games/JR100/STARFIRE_AUTO.prg`へ解決された一方、対象ファイルを`/media/fat/games/JR100/`にしか置いていなかったため、BASICの`READY`で止まった。実際のゲームルートである`/media/usb2/games/JR100/`へ対象ファイルを置くと解消した。

その後の反復で、`JR100_20260725.rbf`は`A=USR($0D00)`の先頭を失い、`R($0D00)`などの不完全な文字列になる場合があると分かった。MGLの`delay`を2秒から5秒へ延ばしても再現したため、コア起動からPRG転送までの待ち不足ではない。コア内部の転送完了から自動打鍵までの待ちが約0.28秒しかなく、BASIC入力が安定する前に打鍵を始めることが原因だった。修正では待ちを約1.68秒へ延長し、READY前にPRGを渡す回帰テストを追加した。修正版`JR100_20260801.rbf`をSS1へ配置し、旧版が失敗した`delay="5"`の条件でSTAR FIREが正常に起動することを確認した。通常設定の`delay="2"`でも3回連続で起動した。

MGLは機械語PRGだけに限定されない。BASICテキストは`type="f" index="2"`で`F2,bas`へ渡せる。AutostartはBASICロード後に`RUN`を入力するため、機械語PRGで必要な`USR=$hhhh`マーカーは不要である。CMTのMGLは`S1`へのマウントまでしか自動化せず、BASICの`LOAD`入力と`Tape Play`の不足は解消しない。

### 経路A: PRG/BAS即時ロード

最小変更案は次のとおりである。

1. `Computer.ini`の`consoleList`へJR-100を追加し、機種節へ`romExts = .prg,.bas`とゲームディレクトリを登録する。必要なら`.cmt`は同じ節へ追加する。
2. `MiSTer_ConsoleMode`の機種・ランチャー登録へ、JR-100のRBFパスを追加する。現在のQuartusプロジェクト名は`JR100`である。[JR100.qpf L1-L2](../../JR100.qpf#L1-L2)
3. ホストの拡張子対応を`.prg -> type F, index 1`、`.bas -> type F, index 2`とする。
4. `.prg`については`S0`を選ばない。`S0`は保存先であり、読み込みローダーは`F1`である。
5. ワンクリックで実行まで進める場合は、既存の`Autostart loaded program`を有効にする。無効でもファイル自体はRAMへロードできる。
6. 生成された`.LASTLAUNCH.mgl`、コア名、`type/index`、PRG/BASロード後のRAM、BASICポインタ、および自動入力の有無を実機で確認する。

判定: 生の`.prg`、`.bas`を直接選ばせる経路では、現行JR-100 HDLに新しいロード方式を追加する必要はない。必要なのはConsole Mode設定とホスト登録である。ただし、ホスト登録の実装箇所は公開ソースを取得できていないため、Retro Remake側のソースまたはパッチ受入が必要になる。先のMGLラッパー経路は、このホスト変更を避けるための試行案である。

### 経路B: テープマウント後にBASIC LOAD

最小の「マウントだけ」の変更案は次のとおりである。

1. `Computer.ini`で`.cmt`を一覧対象にする。
2. ホストで`.cmt -> type S, index 1`へ対応付ける。
3. MGLによってJR-100を起動し、`S1`へCMTをマウントする。
4. 利用者がBASICで`LOAD`を実行し、`Tape Play`を操作する。

判定: ここまでは現行コアのままで接続できる。ただし、Console Modeの`Load Game`を「選択後に自動でテープ内容を読み込み、実行可能な状態まで進む操作」と定義するなら不十分である。

完全自動化には、次のいずれかが必要になる。

- コア側でCMTマウントを検出し、BASIC起動完了後に`LOAD`の自動入力とテープ再生開始を行う。
- Console ModeホストとMiSTer Main/MGLを拡張し、`T[4]`のような一時ステータス操作とキーボード入力を記述できるようにする。
- CMTを事前解析してPRG/BAS相当へ変換し、経路Aへ渡す。ただし、これは実時間テープ動作を通らない別の互換方式になる。

確認済み: 標準MGLで確認できる動作は`file`と`reset`であり、任意の`O/T`ステータス設定やキーボード文字列入力はここで確認した仕様にはない。このため、`S1`マウントだけで`T[4]`とBASICの`LOAD`まで暗黙に実行されるとはみなせない。

## 残る課題と確認項目

1. 生の`.prg`と`.bas`をMGLなしで直接選ぶには、1.1.1のホストソースまたは正式なランチャー登録仕様をRetro Remakeから取得する。
2. BASICテキスト用MGLはコアの受入試験とMGLの`F2`接続から構成を確定しているが、SS1の`Load Game`からの一連の起動は別途実機確認する。
3. CMTは`S1`へのマウントと、BASICの`LOAD`入力および`Tape Play`を別の受入条件として扱う。
4. Console Modeやストレージ構成を更新した場合は、MGL相対パスの解決先を`/tmp/FULLPATH`で再確認する。

## 調査対象の固定情報

| 対象 | リビジョンまたはSHA-256 |
|---|---|
| ConsoleMode_Distribution | `62ab6c7aa5b028d3fd2ab3917045242d4c8be7c1`、tag `1.1.1` |
| Console-Mode公開ソース | `af7add85eeb83a902e7abc145d7d16270678e0df` |
| MiSTer Main | `7db21a8135cee70a6fe529fa877d3d6ef998d129` |
| MiSTer公式MGL資料 | `a592197e7d5e3c7a723d8629c7037c3736b14afa` |
| Amstrad_MiSTer | `6c2c39b6607fc870f5b60ca893c40fb9c873c81f` |
| Apple-II_MiSTer | `79f82092dac6b9784ab444a7800be7e6318bdcf3` |
| BBCMicro_MiSTer | `c0fd1250bfa75653a743d5a68bba981ef8568127` |
| X68000_MiSTer | `4b13c9f37906c664d3f3d779c7bca01a501c38a1` |
| Install_Console_Mode.sh | `34d54d23eb57d01a4ca66f58a75fe1fb801576fde82939eee00c1e4a0ae28337` |
| 配布MiSTer_ConsoleMode | `4b2c79238a480078bb8ea6105e06c06292eda3055e96171a21c6d1b3fc06885d` |
| 配布ConsoleMode_arm | `3e0f474a38dc684c7c421eb76ccf945f9bafef7b2d63b8a35bfd0e42793a280f` |
| 配布Computer.ini | `6071e608b34b8fd5ce7229f9c252eb818189821c84f8b90927235be03e400eee` |
