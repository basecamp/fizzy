#!/usr/bin/env bash
# 第1章: 環境構築の実行可能スクリプト

set -eo pipefail

echo "🐍 Python環境セットアップ"

# uv確認
if ! command -v uv &> /dev/null; then
    echo "❌ uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# 仮想環境作成
echo "▸ Creating virtual environment..."
uv venv

# 依存インストール
echo "▸ Installing dependencies..."
uv pip install fastapi uvicorn

echo "✅ Setup complete!"
echo "Run: source .venv/bin/activate"
