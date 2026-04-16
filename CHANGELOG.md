# 更新日志

本文件记录本项目的所有重要变更。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 新增

- **一键安装脚本 `install.sh`**（[#1](https://github.com/MarsDoge/llm-translate/issues/1)）：
  - 两种模式：`--mode manual`（默认，clone 到 `~/.local/share/llm-translate` +
    写入 vimrc 的 `runtimepath`）和 `--mode vim-plug`（自动 bootstrap vim-plug
    + 写入 `Plug 'MarsDoge/llm-translate'` + 无头跑 `:PlugInstall`）。
  - 已在本地 checkout 运行时自动复用当前目录，不再二次 clone。
  - 幂等：重复执行只会补齐缺失的链接/配置，不会重复注入。
  - 检测已有的 `plug#begin` 块时不会破坏用户配置，而是预先克隆仓库并提示
    用户手动添加一行。
  - 只有当 `~/.config/nvim/init.vim` 已存在时才触碰 Neovim 配置，避免误伤
    init.lua 用户。
  - `install.sh --uninstall` 可完整回滚脚本写入的标记块和符号链接。
  - 其他参数：`--prefix`、`--dir`、`--skip-vim`。
  - 安装完成后会跑一次 mymemory 冒烟测试验证链路。
- **`--task` 任务分发**：同一条管线现在支持三种任务，provider 脚本无需改动。
  - `translate`（默认）—— 文本翻译，保留原有行为。
  - `optimize` —— 代码重写为更清晰、更地道的版本；保留 public API、缩进和
    观测行为；提示词强约束"仅输出代码、无 markdown 围栏"。
  - `bugfix` —— 针对程序员常见的边界/空值/off-by-one/用错运算符/并发/资源
    泄漏等缺陷做最小改动修复；每处改动上方会带一条
    `FIX: <原因>` 注释，方便 `grep FIX:` 审阅。
  - 两个代码类任务对 `mymemory` 会显式报错（它只做翻译）。
- **Vim 对照 diff**：`:LLMOptimize` / `:LLMBugfix` 及默认映射
  `<leader>o` / `<leader>b`，结果开在新 tab 的左右两栏里并自动 `:diffthis`，
  用 `:diffget`/`:diffput` 按行拣选，`:tabclose` 一键丢弃。
- **`LLM_TRANSLATE_TASK` 环境变量** 可设置默认任务；Vim 端新增
  `g:llm_translate_map_optimize` 和 `g:llm_translate_map_bugfix` 开关。

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
