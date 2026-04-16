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
  Input["Vim selection / whole buffer"]
  Plugin["plugin/llm-translate.vim\ncommands + mappings"]
  Autoload["autoload/llm_translate.vim\nselection / buffer runners"]
  CLI["bin/llm-translate\ntask dispatcher\ntranslate | optimize | bugfix"]
  Compat["lib/openai_compat.sh\nshared chat-completions helper"]
  Input --> Plugin --> Autoload --> CLI
  subgraph Direct_provider_scripts["Direct provider scripts"]
    Direct_provider_scripts_claude["lib/providers/claude.sh"]
    Direct_provider_scripts_deepseek["lib/providers/deepseek.sh"]
    Direct_provider_scripts_openai["lib/providers/openai.sh"]
  end
  subgraph OpenAI_compatible_provider_scripts["OpenAI-compatible provider scripts"]
    OpenAI_compatible_provider_scripts_aliyun_codingplan["lib/providers/aliyun-codingplan.sh"]
    OpenAI_compatible_provider_scripts_doubao["lib/providers/doubao.sh"]
    OpenAI_compatible_provider_scripts_grok["lib/providers/grok.sh"]
    OpenAI_compatible_provider_scripts_kimi["lib/providers/kimi.sh"]
    OpenAI_compatible_provider_scripts_mistral["lib/providers/mistral.sh"]
    OpenAI_compatible_provider_scripts_qwen["lib/providers/qwen.sh"]
    OpenAI_compatible_provider_scripts_zhipu["lib/providers/zhipu.sh"]
  end
  subgraph Local_inference["Local inference"]
    Local_inference_ollama["lib/providers/ollama.sh"]
  end
  subgraph Translation_API["Translation API"]
    Translation_API_mymemory["lib/providers/mymemory.sh"]
  end
  CLI --> Compat
  CLI --> Direct_provider_scripts_claude
  CLI --> Direct_provider_scripts_deepseek
  CLI --> Direct_provider_scripts_openai
  CLI --> Local_inference_ollama
  CLI --> Translation_API_mymemory
  Compat --> OpenAI_compatible_provider_scripts_aliyun_codingplan
  Compat --> OpenAI_compatible_provider_scripts_doubao
  Compat --> OpenAI_compatible_provider_scripts_grok
  Compat --> OpenAI_compatible_provider_scripts_kimi
  Compat --> OpenAI_compatible_provider_scripts_mistral
  Compat --> OpenAI_compatible_provider_scripts_qwen
  Compat --> OpenAI_compatible_provider_scripts_zhipu
```
<!-- ARCHITECTURE_MERMAID:END -->
