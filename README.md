# Comfy-Github-Downloaders

🇬🇧 [English](#english) | 🇧🇷 [Português (Brasil)](#português-brasil)

---

## English

Cross-platform installer scripts for ComfyUI custom nodes. Each installer is shipped as a matching `.bat` (Windows) / `.sh` (Linux/macOS) pair that you drop into your **ComfyUI root folder** and run.

### What they do

Every installer:

- **Auto-detects your Python runtime** — checks `.venv`, `venv`, and portable `python_embeded` installs before falling back to system Python.
- **Clones or syncs each node** into `custom_nodes/`:
  - Existing git repo → `fetch` + `reset --hard` + `clean -fdx` (clean sync to latest).
  - Stale non-git folder → removed and re-cloned.
  - Not present → fresh clone.
- **Purges `__pycache__` and `.pyc`/`.pyo` files** after every run to avoid stale bytecode issues.

### Installers included

| Script | Installs |
|---|---|
| `install_video_nodes` | Full node set for the SmoothMix Wan 2.2 workflow (13 nodes: adaptive prompts, mtb, rgthree, MMAudio, WanVideoWrapper, VideoHelperSuite, VFI, KJNodes, Easy-Use, NAG, Comfyroll, GGUF, mxToolkit) |
| `install_wan2_2_img2vid_nodes` | Node set for the WAN 2.2 Smooth img2vid workflow (mtb, rgthree, KJNodes, Easy-Use, GGUF, VideoHelperSuite, Frame-Interpolation, mxToolkit) |
| `install_workflow_to_api_converter` | [comfyui-workflow-to-api-converter-endpoint](https://github.com/SethRobinson/comfyui-workflow-to-api-converter-endpoint) |
| `install_queue_manager` | [ac-comfyui-queue-manager](https://github.com/abdullahceylan/ac-comfyui-queue-manager) |

### Where to place the scripts

Each script locates everything **relative to its own location**, not a fixed path. So the rule is simple: place the `.bat`/`.sh` file directly in your **ComfyUI root folder** — the same folder that contains (or will contain) `custom_nodes/`, `main.py`, `models/`, etc. Do **not** put it inside `custom_nodes/` itself.

```
ComfyUI/                      ← put install_*.bat / .sh HERE
├── custom_nodes/
├── main.py
├── .venv/            (Desktop or venv install → .venv/Scripts/python.exe or .venv/bin/python)
├── venv/             (manual venv install     → venv/Scripts/python.exe or venv/bin/python)
└── python_embeded/   (portable Windows build  → python_embeded/python.exe)
```

`custom_nodes/` doesn't need to exist beforehand — it's created automatically on the first clone. If none of `.venv`, `venv`, or `python_embeded` are found next to the script, it falls back to whatever `python`/`python3` is on your system `PATH` (with a warning).

**Sanity check:** after running the script, `custom_nodes/` should sit right next to it. If a new `custom_nodes/` shows up one level up or down instead, the script was placed in the wrong folder.

### Usage

1. Copy the script(s) you need into your ComfyUI root folder as described above.
2. Windows: double-click the `.bat` file. Linux/macOS: `chmod +x install_*.sh && ./install_*.sh`.
3. Restart ComfyUI when it finishes.

### Requirements

- [Git](https://git-scm.com) available on `PATH`
- A working ComfyUI install (portable, venv, or Desktop)

### Notes

- Scripts are safe to re-run — they sync existing installs to a clean latest state rather than duplicating anything.
- Some nodes need special dependency handling (e.g. `ComfyUI-Frame-Interpolation`, which needs CUDA-aware `cupy`); the affected scripts run that node's own installer instead of a generic install step.

---

## Português (Brasil)

Scripts instaladores multiplataforma para custom nodes do ComfyUI. Cada instalador é distribuído em um par `.bat` (Windows) / `.sh` (Linux/macOS) que você coloca na **pasta raiz do ComfyUI** e executa.

### O que eles fazem

Todo instalador:

- **Detecta automaticamente seu runtime Python** — verifica instalações `.venv`, `venv` e `python_embeded` (portátil) antes de recorrer ao Python do sistema.
- **Clona ou sincroniza cada node** dentro de `custom_nodes/`:
  - Repositório git já existente → `fetch` + `reset --hard` + `clean -fdx` (sincronização limpa com a versão mais recente).
  - Pasta antiga sem `.git` → removida e clonada novamente.
  - Ainda não existe → clone novo.
- **Limpa `__pycache__` e arquivos `.pyc`/`.pyo`** a cada execução, para evitar problemas com bytecode desatualizado.

### Instaladores incluídos

| Script | Instala |
|---|---|
| `install_video_nodes` | Conjunto completo de nodes do workflow SmoothMix Wan 2.2 (13 nodes: adaptive prompts, mtb, rgthree, MMAudio, WanVideoWrapper, VideoHelperSuite, VFI, KJNodes, Easy-Use, NAG, Comfyroll, GGUF, mxToolkit) |
| `install_wan2_2_img2vid_nodes` | Conjunto de nodes do workflow WAN 2.2 Smooth img2vid (mtb, rgthree, KJNodes, Easy-Use, GGUF, VideoHelperSuite, Frame-Interpolation, mxToolkit) |
| `install_workflow_to_api_converter` | [comfyui-workflow-to-api-converter-endpoint](https://github.com/SethRobinson/comfyui-workflow-to-api-converter-endpoint) |
| `install_queue_manager` | [ac-comfyui-queue-manager](https://github.com/abdullahceylan/ac-comfyui-queue-manager) |

### Onde colocar os scripts

Cada script localiza tudo **em relação à sua própria posição**, não a um caminho fixo. Então a regra é simples: coloque o arquivo `.bat`/`.sh` diretamente na **pasta raiz do ComfyUI** — a mesma pasta que contém (ou vai conter) `custom_nodes/`, `main.py`, `models/`, etc. **Não** coloque dentro de `custom_nodes/`.

```
ComfyUI/                      ← coloque o install_*.bat / .sh AQUI
├── custom_nodes/
├── main.py
├── .venv/            (instalação Desktop ou venv → .venv/Scripts/python.exe ou .venv/bin/python)
├── venv/             (venv manual                → venv/Scripts/python.exe ou venv/bin/python)
└── python_embeded/   (build portátil do Windows  → python_embeded/python.exe)
```

`custom_nodes/` não precisa existir de antemão — ela é criada automaticamente no primeiro clone. Se nenhuma das pastas `.venv`, `venv` ou `python_embeded` for encontrada ao lado do script, ele recorre ao `python`/`python3` disponível no `PATH` do sistema (com um aviso).

**Checagem rápida:** depois de rodar o script, a pasta `custom_nodes/` deve ficar bem ao lado dele. Se uma nova `custom_nodes/` aparecer um nível acima ou abaixo do esperado, o script foi colocado na pasta errada.

### Uso

1. Copie o(s) script(s) que precisar para a pasta raiz do ComfyUI, como descrito acima.
2. Windows: dê duplo clique no arquivo `.bat`. Linux/macOS: `chmod +x install_*.sh && ./install_*.sh`.
3. Reinicie o ComfyUI quando terminar.

### Requisitos

- [Git](https://git-scm.com) disponível no `PATH`
- Uma instalação funcional do ComfyUI (portátil, venv ou Desktop)

### Observações

- Os scripts são seguros para rodar mais de uma vez — eles sincronizam instalações existentes para o estado mais recente, em vez de duplicar qualquer coisa.
- Alguns nodes exigem tratamento especial de dependências (ex.: `ComfyUI-Frame-Interpolation`, que precisa de `cupy` compatível com a versão do CUDA); os scripts afetados rodam o instalador próprio do node em vez de uma etapa genérica.
