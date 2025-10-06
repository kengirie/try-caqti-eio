# try-caqti-eio の使い方

このプロジェクトは `caqti-eio` と SQLite3 を使って、Eio ランタイム上で人事 / KPI 管理の ER 図を実装したサンプルです。
ER 図のテキスト表現（Mermaid）は `docs/er-diagram.md` にまとめています。

## ER 図から拾ったテーブル概要

| テーブル | 主キー | 主な列 | 関連 | 備考 |
|----------|--------|--------|------|------|
| `organizations` | `organization_code` | `start_date`, `end_date`, `name`, `type_code`, `parent_organization_code` | **a**: `organizations` 1 → n `affiliations` | 階層構造を持つ組織マスタ |
| `positions` | `position_code` | `position_name`, `allocation_category` | `affiliations` が参照 | 役職マスタ |
| `employees` | `employee_code` | `name`, `birth_date`, `email`, `address` | **b**: 1 → n 参照（`monthly_*` 系など） | 従業員マスタ |
| `affiliations` | `(employee_code, start_date)` | `organization_code`, `position_code`, 期間属性 | a の n 側、`organizations` / `positions` を参照 | 従業員の所属履歴 |
| `kpis` | `(kpi_code, fiscal_year)` | `name`, `target_value` | `monthly_*` が参照 | KPI マスタ |
| `monthly_individual_targets` | `(employee_code, kpi_code, fiscal_year, month)` | `target_value` | **b** を利用し `employees` と `kpis` を参照 | 月別個人目標 |
| `monthly_individual_performance` | 同上 | `actual_value` | 同上 | 月別個人実績 |

- リレーション **a**: 1 つの組織が複数の `affiliations` を持つ 1 対多。
- リレーション **b**: `employee_code` が外部キーとして様々なテーブル（`affiliations` / `monthly_*`）から参照される。

## 前提条件

- OCaml と opam がインストール済み。
- プロジェクト直下で opam スイッチ（例: `opam switch create . ocaml-base-compiler.5.3.0`）を用意し、`eval "$(opam env)"` を実行して環境を読み込む。
- 依存ライブラリ（`caqti`、`caqti-eio`、`caqti-driver-sqlite3`、`eio`、`eio_main`、`uri` など）がインストール済み。

## ビルド

```bash
eval "$(opam env)"
dune build
```

## 実行

デフォルトでは `sqlite3:./data.sqlite3` を使用します。

```bash
eval "$(opam env)"
dune exec try-caqti-eio
```

別の SQLite データベース URI を指定したい場合は、コマンドライン引数で渡してください。

```bash
dune exec try-caqti-eio sqlite3:./my_database.sqlite3
```

## 実行時の流れ

1. 上表にある 7 テーブルを `CREATE TABLE IF NOT EXISTS` で生成します。
2. 組織・役職・従業員・所属・KPI といったマスタを 1 件ずつ投入します。
3. `monthly_individual_targets` / `monthly_individual_performance` に 2025 年 4 月・5 月のサンプルデータを投入します。
4. KPI 別の月次サマリを結合して取得し、以下の形式で標準出力に表示します。

```
+employee=E0001 name=田中 太郎 org=営業本部 month=2025-04 target=10.0 actual=9.0
+employee=E0001 name=田中 太郎 org=営業本部 month=2025-05 target=12.0 actual=13.5
```

（`+` は `Eio.traceln` を `dune exec` 経由で呼び出した際のプレフィックスです。）

## SQLite3 CLI での確認

処理後もレコードは SQLite ファイルに残るため、CLI で中身を確認できます。

```bash
sqlite3 data.sqlite3
sqlite> .tables
sqlite> SELECT * FROM employees;
sqlite> SELECT * FROM monthly_individual_targets;
sqlite> .quit
```

別ファイルを指定した場合は `data.sqlite3` の部分を変更してください。
