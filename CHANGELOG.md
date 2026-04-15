# 更新日志

本文件记录本项目的所有重要变更。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.1.0] — 2026-04-15

首个公开版本。

### 新增

- **CLI 分发器** `bin/llm-translate`：从 stdin 读、写到 stdout；支持
  `-p/--provider`、`-m/--model`、`-t/--target`、`-s/--source`、
  `--temperature`、`--list-providers`、`-v/--version`、`-h/--help` 等参数；
  可用环境变量 `LLM_TRANSLATE_PROVIDER` 等设置默认值。
- **五个 provider**（`lib/providers/` 下各一个文件）：
  - `deepseek`（默认，需 `DEEPSEEK_API_KEY`）
  - `openai`（需 `OPENAI_API_KEY`）
  - `claude`（需 `ANTHROPIC_API_KEY`）
  - `ollama`（本地，无需 key，默认 `http://localhost:11434`）
  - `mymemory`（**零配置**，免费额度 5000 词/天/IP，可选 `MYMEMORY_EMAIL`
    提升到 5 万词/天；中国大陆可达）
- **Vim 插件**：
  - `plugin/llm-translate.vim` —— 启动时加载的配置默认值、`:command` 定义、
    默认 `<leader>t` 映射
  - `autoload/llm_translate.vim` —— 首次调用时懒加载的实现（`selection()`、
    `buffer()` 及私有 helper）
  - 命令 `:LLMTranslate`（可视选区）、`:LLMTranslateBuffer`（整个 buffer）
- **语言码归一化**：CLI 内置 `normalize_lang_code()`，把 12 种常用语言的
  自然名、中文称呼、ISO 码互相映射；未知输入原样透传，方便直接传 provider
  专用码。
- **保留格式的系统 prompt**：代码块、命令、路径、标识符、错误码、寄存器名、
  函数名均不翻译；markdown、缩进、换行保持原样。
- **shellcheck CI**：GitHub Actions 工作流 `.github/workflows/shellcheck.yml`
  在每次 push / PR 时 lint 所有 shell 脚本。
- **文档**：
  - `README.md`（英文）：双路线安装（手动 / vim-plug）、无 key 验证步骤、
    完整参数表、语言别名表。
  - `README.zh-CN.md`（中文）：与英文版对齐的完整翻译。
  - `CLAUDE.md`：面向 Claude Code 未来会话的架构说明（CLI↔provider 契约、
    `plugin`/`autoload` 拆分约束、portability 硬约束）。

### 开发过程中修复的问题

以下修复都是在 0.1.0 首次公开之前解决的：

- Vim `E746` 错误：带 `#` 的函数必须位于 `autoload/<prefix>.vim`，不能放在
  `plugin/` 里；相应地把插件拆成 `plugin/` + `autoload/` 两个文件。
- curl 老版本兼容：放弃 `curl --fail-with-body`（curl 7.76+，2021）的依赖，
  改用 `-o` + `-w '%{http_code}'` + mktemp 的写法，在更老的 curl 上也能工作。
- shellcheck `SC2155`：把 `export VAR="$(cmd)"` 拆成两步声明 + export，避免
  掩盖被调用命令的退出码。

### 硬约束（见 CLAUDE.md）

- 运行时只允许依赖 `bash`、`curl`、`jq`。
- 禁用 `curl --fail-with-body`（兼容性问题）。
- 构造 JSON 请求体一律用 `jq --arg` / `--argjson`，不要字符串拼接。

[Unreleased]: https://github.com/MarsDoge/llm-translate/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/MarsDoge/llm-translate/releases/tag/v0.1.0
