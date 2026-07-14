# ddd-skills

DDD（ドメイン駆動設計）まわりの Claude Code 用自作スキル集。各ディレクトリが1つのスキル（`SKILL.md`）。

## リポジトリ構成

- `<skill-name>/SKILL.md` — スキル本体。付属物は同ディレクトリの `templates/`（スキャフォールド用の雛形）や `references/`（参照資料）に置く
- `scripts/lint.sh` — スキルの検証（CI でも実行）
- `scripts/update-readme.sh` — README のスキル表を frontmatter から再生成
- `install.sh` — スキルを `~/.claude/skills/` やプロジェクトに symlink 配置する
- `tests/fixtures/<skill-name>/` — レビュー系スキルの評価用フィクスチャ（違反を仕込んだサンプルコード + 期待される指摘 `EXPECTED.md`）

## スキルの規約

### frontmatter

- `name:` — ディレクトリ名と完全一致させる
- `description:` — **日本語・1行**で 2〜3文。構成は「1〜2文目 = 何をするか（README の表にはこの2文だけが載る）」「最終文 = 起動条件（『〜と依頼されたときに使う』の形）」。モデル自動起動させるスキルでは、起動条件にユーザーが言いそうなフレーズを「」で列挙する（必要なら英語フレーズも併記）
- `disable-model-invocation: true` — スラッシュコマンド専用のスキルに付ける。付けないのは依頼文から自動起動してほしいスキルだけ
- `allowed-tools:` — カンマ区切りの1行で書く（例: `Read, Write, Edit, Bash`）。YAML リスト形式は使わない
- `version:` — 任意。テンプレートや状態ファイルとの互換性を持つスキルのみ付け、互換性が壊れる変更で上げる

### 変更後の必須手順

SKILL.md（特に description）を追加・変更したら:

```bash
./scripts/update-readme.sh   # README の表を再生成
./scripts/lint.sh            # 検証
```

CI が同じチェックを走らせるので、忘れるとビルドが落ちる。

### レビュー系スキル（ddd-review 等）の改修時

`tests/fixtures/<skill-name>/` に違反を仕込んだサンプルコードと `EXPECTED.md`（期待される指摘一覧）がある。スキルの検査軸や足切り基準を変えたら、`/スキル名 tests/fixtures/<skill-name>/` を実行して EXPECTED.md と突き合わせ、検出漏れ・過剰指摘が出ていないか確認する。検査軸を追加したらフィクスチャにも対応する違反例と EXPECTED.md のエントリを追加する。

## コミット規約

subject は英語で「Add/Fix/Rename <対象>: <要約>」の形（`git log --oneline` 参照）。
