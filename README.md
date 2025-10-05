# try-caqti-eio の使い方

このプロジェクトは `caqti-eio` と SQLite3 を使って、Eio ランタイム上でシンプルな CRUD デモを実行する OCaml アプリケーションです。以下の手順で実行できます。

## 前提条件

- OCaml と opam がインストール済みであること。
- プロジェクト直下で opam スイッチ（例: `opam switch create . ocaml-base-compiler.5.3.0`）を用意し、`eval "$(opam env)"` を実行して環境を読み込むこと。
- 依存ライブラリ（`caqti`、`caqti-eio`、`caqti-driver-sqlite3`、`eio`、`eio_main`、`uri` など）がインストール済みであること。

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

コマンドを流すと以下の処理が走ります。

1. `notes` テーブルを作成（無ければ）。
2. サンプルのメモを 3 件挿入。
3. 各メモを SELECT して挿入内容をログ出力。
4. タイトルを書き換えて UPDATE を実行。
5. UPDATE 後の内容を再度 SELECT し、ログに出力。
6. レコードを削除せずに保持し、最後に `Persisted note ids=...` を表示。

標準出力の例:

```
+Inserted note: id=1 title=Hello body=Eio + SQLite
+Inserted note: id=2 title=Bonjour body=Multi-row insert
+Inserted note: id=3 title=Konnichiwa body=multi-row demo
+Updated note: id=1 title=Updated title 1 body=Eio + SQLite
+Updated note: id=2 title=Updated title 2 body=Multi-row insert
+Updated note: id=3 title=Updated title 3 body=multi-row demo
+Persisted note ids=1, 2, 3
```

（行頭の `+` は `Eio.traceln` を `dune exec` 経由で呼び出した際に付くプレフィックスです。）

## SQLite3 CLI での確認

処理後もレコードは SQLite ファイルに残っているため、必要に応じて CLI で中身を確認できます。

```bash
sqlite3 data.sqlite3
sqlite> .tables
sqlite> SELECT * FROM notes;
sqlite> .quit
```

別ファイルを指定した場合は `data.sqlite3` の部分を変更してください。
