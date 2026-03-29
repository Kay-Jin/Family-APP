# 持续集成（CI）说明

CI（Continuous Integration）会在你**推送代码**或**发起 Pull Request** 时，在 GitHub 提供的虚拟机上自动执行测试和静态检查。通过绿勾/红叉可以快速发现「合并后会不会坏」。

本项目使用 **GitHub Actions**，配置文件在：

`.github/workflows/ci.yml`

## 当前会跑什么

| 任务 | 内容 |
|------|------|
| **Flutter** | `flutter pub get` → `flutter analyze` → `flutter test`（目录 `mobile/`） |
| **Python** | 安装 `backend/requirements.txt` → `pytest tests`（目录 `backend/`，使用临时 SQLite） |
| **Supabase** | 若配置了密钥，则执行 `supabase/tests/schema_checks.sql` 校验数据库结构是否与 `supabase/schema.sql` 一致 |

## 第一次怎么用

1. 在 [GitHub](https://github.com/new) 新建一个空仓库（不要勾选自动添加 README，避免冲突）。
2. 在本项目根目录执行（把地址换成你的仓库）：

   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```

3. 打开 GitHub 上该仓库的 **Actions** 标签页，确认工作流在运行。

默认分支名若是 `master`，工作流里已包含 `master`，与 `main` 一样会触发。

## （可选）让 CI 也检查线上 Supabase

1. GitHub 仓库 → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**。
2. **Name**：`SUPABASE_DB_URL`  
   **Value**：Supabase 项目 **Settings → Database** 里的连接串（需包含密码）。可用 Session pooler 的 URI，便于从公网连接。
3. 保存后，下次 push/PR 会多跑一步 schema 检查；若库未按 `schema.sql` 对齐，CI 会失败并打印 `details` JSON。

未配置该密钥时，Supabase 这一步会**自动跳过**，不影响 Flutter / Python 任务。

## 本地对照命令

- 全量（仅 Flutter）：`powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
- Supabase SQL（需本机安装 `psql` 并设置 `SUPABASE_DB_URL`）：`powershell -ExecutionPolicy Bypass -File scripts/run_supabase_schema_checks.ps1`

## Schema 检查失败时怎么办

若 `schema_checks.sql` 的 `failed_count` 大于 0，日志里的 `details` 会列出缺列、缺函数、缺 Storage 桶/策略等。请先在 Supabase **SQL Editor** 执行与线上一致的迁移，例如：

- [`supabase/migrations/20260328_answer_images_and_storage.sql`](../supabase/migrations/20260328_answer_images_and_storage.sql)（`daily_answers.image_path` + `family_answer_images` 桶）
- [`supabase/migrations/20260329_family_album.sql`](../supabase/migrations/20260329_family_album.sql)（`family_photos` 表 + `family_album_images` 桶）
- [`supabase/migrations/20260330_family_album_engagement.sql`](../supabase/migrations/20260330_family_album_engagement.sql)（相册点赞与评论）

执行后再跑一次检查，直到 `failed_count = 0`。完整基线仍以 [`supabase/schema.sql`](../supabase/schema.sql) 为准。

## GitHub Actions：Python 测试说明

后端集成测试里 multipart 上传**不要**手写 `Content-Type: multipart/form-data`（缺少 boundary 会在 Linux runner 上解析失败）。由 Flask `test_client` 在传入 `data` 含文件字段时自动带 boundary。
