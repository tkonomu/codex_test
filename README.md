# analog-dirty-video

MP4動画に、ライブ映像っぽい「荒れたアナログ感（強めの粒子・赤寄り・ハイライトのにじみ・色ズレ）」をかけるCLIツールです。

実処理は `ffmpeg` のフィルタグラフで行い、このRust CLIは以下を担当します。

- プリセット管理（mild / heavy / brutal）
- パラメータ上書き
- 入出力バリデーション
- 再現可能なコマンド実行

## 必要条件

- Rust (開発/ビルド時)
- `ffmpeg`（実行時）

## ビルド

```bash
cargo build --release
```

## 使い方

```bash
cargo run --release -- \
  --input input.mp4 \
  --output output.mp4 \
  --preset heavy
```

### 主なオプション

- `--preset [mild|heavy|brutal]`
- `--noise <0..100>`
- `--bloom <0.0..1.0>`
- `--chroma-shift <0..10>`
- `--crf <0..51>` （小さいほど高画質）
- `--speed <x264 preset>`
- `--dry-run`（実行せず、ffmpegコマンドを表示）

### 例: かなり強め

```bash
cargo run --release -- \
  --input input.mp4 \
  --output dirty.mp4 \
  --preset brutal \
  --noise 55 \
  --bloom 0.52 \
  --chroma-shift 3 \
  --crf 20 \
  --speed fast
```

## エフェクト内容

1. `eq` で彩度/コントラスト/明るさ/ガンマを調整
2. `colorchannelmixer` で赤・青チャンネルを持ち上げ
3. `rgbashift` で色収差（赤/青の水平ズレ）
4. 複製→`gblur`→`screen blend` でハイライトにじみ
5. `noise` で時間変化する粒状感を追加

## 注意

- 音声は `-c:a copy` でそのまま保持します。
- 4Kや長尺は重くなるため、必要に応じて `--speed` を `faster` 側へ調整してください。
