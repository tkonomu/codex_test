# analog-dirty-video

## 方針変更: iOSアプリ化

「PCで変換が面倒」という要望に合わせて、iPhone上で完結する実装方針を追加しました。
このリポジトリには、Core Image + AVFoundation を使った iOS 実装のたたき台を含めています（`ios/AnalogDirtyVideo`）。

> 結論: **iPhone 16 Pro なら十分現実的**です。  
> 特に 1080p の短〜中尺は問題なく処理できる見込みです。4K長尺は時間と発熱が増えるため、品質プリセットを調整する運用が実用的です。

## iOS実装（新規）

- `ios/AnalogDirtyVideo/AnalogDirtyVideoApp.swift`: アプリエントリ
- `ios/AnalogDirtyVideo/ContentView.swift`: 動画選択・プリセット選択・変換開始UI
- `ios/AnalogDirtyVideo/VideoProcessor.swift`: AVAssetExportSession + CIFilter の処理本体
- `ios/AnalogDirtyVideo/EffectPreset.swift`: `mild / heavy / brutal` のプリセット定義

### エフェクト構成

1. 色調補正（彩度・コントラスト・明るさ・ガンマ）
2. 赤青チャンネルのリフト
3. 色収差（赤/青チャンネルを逆方向にシフト）
4. ブラー + 合成によるハイライトのにじみ
5. ノイズ重畳で粒状感を追加

## iPhone 16 Proでの実用性

- **可能**: 1080p・短尺クリップのSNS用途
- **条件付きで可能**: 4K・長尺（数分以上）は時間/発熱/電池消費が重い
- **推奨運用**:
  - まず `heavy` で検証
  - 4Kで重い場合は 1080p 書き出し導線を追加
  - 進捗表示とキャンセル導線を必ず用意

## 次に詰めたい要件

- 入力: 写真ライブラリのみか、Files対応も必要か
- 出力: 写真アプリ保存だけでよいか、共有シートも必要か
- 画質方針: 4K優先か、速度優先（1080p）か
- 1本ずつか、バッチ処理が必要か

## 旧Rust CLIについて

既存のRust CLI版（ffmpeg前提）もこのブランチに残っていますが、今後はiOS実装を主軸に進める想定です。
