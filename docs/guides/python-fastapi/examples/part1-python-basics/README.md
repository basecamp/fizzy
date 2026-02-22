# Part I: Python基礎 - コード例

このディレクトリには、Part I（第1-4章）の実行可能なコード例が含まれています。

## 構成

```
part1-python-basics/
├── ch1-environment/    # 第1章: 環境構築
│   └── setup.sh        # セットアップスクリプト
├── ch2-syntax/         # 第2章: Python文法
│   └── list_comprehension.py
├── ch3-type-hints/     # 第3章: 型ヒントとPydantic
│   └── pydantic_example.py
└── ch4-packages/       # 第4章: パッケージ管理
    └── pyproject.toml
```

## 実行方法

### 第1章: 環境構築

```bash
cd ch1-environment
bash setup.sh
```

### 第2章: List Comprehension

```bash
cd ch2-syntax
python list_comprehension.py
```

### 第3章: Pydanticバリデーション

```bash
cd ch3-type-hints
uv pip install pydantic
python pydantic_example.py
```

## 前提条件

- Python 3.12以上
- uv インストール済み
