# ddd-skills

DDD（ドメイン駆動設計）まわりの Claude Code 用スキル集。各ディレクトリが1つのスキル（`SKILL.md`）です。

ドメイン知識の取り込み（domain-expert）→ DDD 観点のレビュー（ddd-review）→ 役割分担での開発サイクル（ddd-orchestrate）が連携して動きます。

## スキル一覧

各スキルの説明は `SKILL.md` の frontmatter `description` から自動生成しています（`scripts/update-readme.sh`）。

<!-- SKILLS-TABLE:BEGIN (scripts/update-readme.sh が生成。手で編集しない) -->
| スキル | 起動 | 説明 |
|--------|------|------|
| [ddd-orchestrate](ddd-orchestrate/SKILL.md) | `/` 専用 | DDD の開発サイクルを実装者・レビュアー・テスターの3体のサブエージェントで回すオーケストレーションスキル。domain-expert が永続化したドメイン知識ブリーフを各エージェントのプロンプトに注入し、実装 → DDD 観点レビュー + テストの差し戻しループを合格まで（上限3周）回して結果を報告する。 |
| [ddd-review](ddd-review/SKILL.md) | 自動 | DDD（ドメイン駆動設計）の観点でコードレビューを行う。ユビキタス言語・エンティティ/値オブジェクト・集約・リポジトリ・ドメイン層の純粋性・サービスの責務配置・境界づけられたコンテキストの検出シグナルに沿って差分や指定ファイルを検査し、不変条件の破壊やモデルの劣化につながる具体的な指摘のみを重要度付きで報告する。 |
| [domain-expert](domain-expert/SKILL.md) | 自動 | プロジェクトの仕様と実装を読み込み、そのドメインの知識ブリーフを抽出してメモリに永続化する。ユビキタス言語・中核エンティティ・ビジネスルール/不変条件・主要ワークフロー・境界づけられたコンテキストを構造化し、以後は根拠づけされたドメインエキスパートとして file:line 引用付きで質問に答える。 |
<!-- SKILLS-TABLE:END -->

## ddd-orchestrate の使い方

`/ddd-orchestrate` は現在のセッションをオーケストレーターにして、DDD の開発サイクルを**実装者・レビュアー・テスター**の3体のサブエージェント（Agent tool）で回します。ヘッドレスワーカーや worktree を使わない軽量な構成で、1つのタスクを「合格するまで磨く」役割分担ループに特化しています。

```bash
/ddd-orchestrate <タスクの説明>   # 例: /ddd-orchestrate 注文にクーポン適用を追加
```

流れは「作業ブリーフ作成 → サイクル実行（上限3周）→ 検証と締め」です。

1. プロジェクトのメモリから [domain-expert](domain-expert/SKILL.md) が永続化したドメイン知識（`domain-*.md`）を読み、タスクを**作業ブリーフ**（対象の集約・守るべき不変条件・受け入れ基準・プロジェクト規約）に翻訳する。ブリーフが無い場合は domain-expert の先行実行か、タスク範囲だけの簡易抽出かを選べます
2. 各サイクルは「実装者（直列）→ レビュアー + テスター（並列）→ 判定」。レビュアーは ddd-review の検査軸で差分を読み（実害シナリオが書けない指摘は足切り）、テスターは不変条件を破りにいくテストを追加・実行する
3. テスト失敗か High / Medium 指摘があれば差し戻しブリーフを作って次サイクルへ。合格したらオーケストレーターが done-check を再実行してから1コミットにまとめて報告する（push はしない）。3周で合格しなければ残課題を報告して停止

事前に `domain-expert` でドメインを取り込んでおくと、毎ランのブリーフ品質が安定します。3体のプロンプト雛形は [ddd-orchestrate/templates/](ddd-orchestrate/SKILL.md) にあります。

## 使い方

`install.sh` で symlink を張って配置します。リポジトリが単一の真実源になり、`git pull` するだけで全配置先が更新されます。

```bash
# 全プロジェクト共通で使う場合（~/.claude/skills/）
./install.sh <skill-name>

# 特定プロジェクトだけで使う場合（<project>/.claude/skills/）
./install.sh <skill-name> --project <project>

# 全スキルをまとめて配置
./install.sh all

# 配置状況の確認（link / copy / 未配置、リポジトリとの差分有無）
./install.sh status [--project <project>]

# 配置解除
./install.sh uninstall <skill-name> [--project <project>]
```

プロジェクト固有にカスタマイズしたい場合だけ `--copy` を付けてコピー配置に切り替えます（以降そのプロジェクトには `git pull` が反映されなくなる点に注意。差分は `status` で確認できます）。

配置後は `/スキル名`（例: `/ddd-orchestrate 注文にクーポン適用を追加`）で起動できます。
起動方式はスキル一覧の「起動」列を参照してください。「自動」のスキルは依頼文からモデルが自動起動することもあり、「`/` 専用」（`disable-model-invocation: true`）のスキルはスラッシュコマンドでのみ起動します。
