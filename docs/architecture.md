# Architecture

This document contains the detailed Mermaid architecture diagram for the
repository. Regenerate the diagram from the current repository layout with:

```bash
./scripts/render-readme-diagrams.sh
```

The script rewrites only the section between the markers below.

<!-- ARCHITECTURE_MERMAID:START -->
```mermaid
flowchart LR
  Terminal["Terminal stdin / pipe"]
  Input["Vim selection / whole buffer"]
  Plugin["plugin/llm-translate.vim\ncommands + mappings"]
  Autoload["autoload/llm_translate.vim\nselection / buffer runners"]
  MacInput["macOS selected text\nany app"]
  MacApp["macos/LLMTranslateMac\nSwift menu-bar app\ntranslate | speak"]
  Speech["macOS NSSpeechSynthesizer\nsystem text-to-speech"]
  CLI["bin/llm-translate\ntask dispatcher\ntranslate | optimize | bugfix"]
  Compat["lib/openai_compat.sh\nshared chat-completions helper"]
  Terminal --> CLI
  Input --> Plugin --> Autoload --> CLI
  MacInput --> MacApp --> CLI
  MacApp --> Speech
  subgraph direct["Direct provider scripts"]
    direct_claude["lib/providers/claude.sh"]
    direct_deepseek["lib/providers/deepseek.sh"]
    direct_openai["lib/providers/openai.sh"]
  end
  subgraph compat_group["OpenAI-compatible provider scripts"]
    compat_group_aliyun_codingplan["lib/providers/aliyun-codingplan.sh"]
    compat_group_doubao["lib/providers/doubao.sh"]
    compat_group_grok["lib/providers/grok.sh"]
    compat_group_kimi["lib/providers/kimi.sh"]
    compat_group_mistral["lib/providers/mistral.sh"]
    compat_group_qwen["lib/providers/qwen.sh"]
    compat_group_zhipu["lib/providers/zhipu.sh"]
  end
  subgraph local["Local inference"]
    local_ollama["lib/providers/ollama.sh"]
  end
  subgraph translation["Translation API"]
    translation_mymemory["lib/providers/mymemory.sh"]
  end
  CLI --> Compat
  CLI --> direct_claude
  CLI --> direct_deepseek
  CLI --> direct_openai
  CLI --> local_ollama
  CLI --> translation_mymemory
  Compat --> compat_group_aliyun_codingplan
  Compat --> compat_group_doubao
  Compat --> compat_group_grok
  Compat --> compat_group_kimi
  Compat --> compat_group_mistral
  Compat --> compat_group_qwen
  Compat --> compat_group_zhipu
```
<!-- ARCHITECTURE_MERMAID:END -->
