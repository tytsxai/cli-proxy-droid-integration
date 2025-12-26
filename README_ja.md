# CLI Proxy API 統合ツール - Factory CLI (Droid)

> ローカルプロキシサーバーを通じて、Factory CLI (Droid) でサードパーティAIモデル（GPT-5.2など）を使用

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

[English](README.md) | [中文](README_zh-CN.md) | **日本語**

## 概要

このツールキットは、Factory CLI (Droid) をローカルプロキシ経由でサードパーティAIモデルプロバイダーに接続できるようにします。

1. **認証情報の自動検出** - 複数のソースから自動読み取り
2. **カスタムモデルの設定** - Factory CLI で使用
3. **ローカルプロキシの実行** - 安定したAPI転送サービス

## クイックスタート

### 前提条件

- Factory CLI (Droid) がインストール済み
- サードパーティAPI認証情報
- macOS または Linux

### インストール

```bash
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
# config.yaml を編集してAPI認証情報を入力
./setup.sh
```

### 使用方法

```bash
droid
```

1. `/model` でモデル一覧を表示
2. `gpt-5.2` を選択
3. 会話開始！

## アーキテクチャ

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Droid CLI  │────▶│  ローカルプロキシ │────▶│  サードパーティ  │
│             │     │  (ポート 8317)   │     │  AIプロバイダー  │
└─────────────┘     └──────────────────┘     └─────────────────┘
```

## トラブルシューティング

### 設定の検証

```bash
./verify-integration.sh
```

### ポート 8317 が使用中

```bash
lsof -i :8317
kill <PID>
./setup.sh
```

## ライセンス

MIT License - [LICENSE](LICENSE) を参照
