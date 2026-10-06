# Verificación ARMv7 / Pi 2B — guía en español

> Idioma／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ **Español**

Esta guía explica el **registro sin procesar de la placa** que está en
[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md). El registro es la evidencia y se conserva
literalmente: el propio script de instalación imprime en chino y reescribirlo destruiría su valor como
registro. Lo de abajo es explicación y traducción de referencia; si algo difiere, manda el registro original.

- Placa: Raspberry Pi 2 Model B (armv7l, 921 MiB de RAM), Raspbian GNU/Linux 13 (trixie)
- Ciclo: 2026-10-06, instalando `@earendil-works/pi-coding-agent@1.0.4`
- Comando: `scripts/pi2-armv7/pi2-pi-agent.sh all` (probe → install → verify), ejecutado desde el PC por SSH
- Resultado: **11/11 comprobaciones de aceptación superadas**, `verify` exit 0

## Qué significa cada bloque del registro

| Bloque | Contenido |
| --- | --- |
| `=== 0) 基本環境` | Entorno: `uname -m = armv7l`, Raspbian 13 (trixie), 921 MiB totales / 718 MiB libres, 5,6 GB libres en `$HOME`. Después pasan las tres primeras comprobaciones: la arquitectura es armv7l; se ejecuta como usuario sin privilegios (uid 1000) y todo va a `$HOME`; existe un descargador (`curl`). |
| `=== 1) Node 22 armv7l` | Ya está Node v22.23.2 (`/home/<user>/opt/node22/bin/node`, la línea de compilación oficial para armv7l) y `node:sqlite` está disponible → el backend de sesión no necesita módulos nativos. |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8 instala el paquete oficial en `/home/<user>/.local`: `added 4 packages, removed 5 packages, and changed 117 packages in 4m`. Aparece un aviso de obsolescencia (`node-domexception@1.0.0`) que es de upstream y es inocuo. |
| `=== 3) 驗收（可量測的項目）` | El ejecutable existe y **`pi --version` imprime 1.0.4**; `pi --help` también funciona. Se listan los seis precompilados incluidos y todos son x64/arm64 (darwin/linux/win32) — **ningún `linux-arm`**, así que en esta placa nunca se carga nada nativo; lo que realmente prueba el punto es que `pi --version` haya funcionado. |
| `=== 4) 量測（給日後比對用）` | Mediciones para comparar más adelante: `pi --version` 5,09 s, RSS base de `node` 39 MiB, Node 187 MB, paquete pi 165 MB. |
| `=== 5) 接下來（可選）` | Cómo persistir el PATH en `~/.bashrc` y cómo ejecutar un turno real de modelo (necesita una clave, o un servidor de modelos local propio — la ruta local integrada de 1.0.4 es el router de llama.cpp vía `LLAMA_BASE_URL`, no la API compatible con OpenAI de LM Studio). |
| `完成。記錄檔請用 --check-only 重跑輸出存證。` | Última línea de la instalación («Hecho. Para dejar constancia, vuelve a ejecutar con `--check-only` y guarda la salida»). |

## Comprobaciones de aceptación (`pi2-pi-agent.sh verify`)

El verificador busca patrones en el registro y falla en cerrado ante cualquier desviación
(`✓` = debe aparecer, `✗` = no debe aparecer):

| Resultado | Marca en el registro | Significado |
| --- | --- | --- |
| ✓ | `架構是 armv7l` | Se ejecutó en armv7l (Pi 2B) |
| ✓ | `以一般使用者執行` | Se ejecutó como usuario normal, no root |
| ✓ | `Node v22\.` | Node está en la línea v22 |
| ✓ | `node:sqlite 可用` | El backend de sesión SQLite integrado está disponible |
| ✓ | `pi 執行檔存在` | El ejecutable `pi` existe |
| ✓ | `pi --version → v?\d` | `pi --version` produjo salida |
| ✗ | `prebuilds/linux-arm/` | No apareció ningún precompilado específico de ARMv7 |
| ✗ | `以 root 身分執行中` | No se ejecutó como root |
| ✗ | `Node v(?!22\.)\d` | No hay rastro de un Node distinto de v22 en el registro |
| ✗ | `意外發現原生 .node` | No apareció ningún `.node` nativo inesperado |
| ✗ | `中止（fail-closed）` | No se abortó ningún paso |

## Remedición independiente (misma placa, 1.0.4)

Tres ejecuciones adicionales de `pi --version` tras la instalación, y el estado de la placa en ese momento:

```text
  run1: 4.98 s (1.0.4)
  run2: 4.93 s (1.0.4)
  run3: 4.90 s (1.0.4)
  node RSS: 39 MiB
  free: 611 MiB available
  disk HOME: 5.0G
```

## Otra evidencia medida en la placa (registrada en otros archivos)

- El cargador instalado no entrega ningún helper nativo en esta arquitectura — remedido con el
  paquete 1.0.4: con `process.arch = arm`, `getNativeClipboard()` devuelve `undefined`
  (`getNativePlatformHelper()` ya no se reexporta desde `@earendil-works/pi-tui`), que es el fallback
  documentado a herramientas de línea de comandos.
- La comprobación del build desde fuentes se comporta como está documentado: el
  `packages/tui/native/linux/build.sh` de upstream sale con **1** en armv7l
  (`Unsupported Linux architecture: armv7l`), mientras que el de este fork imprime un aviso de omisión y
  sale con **0**. La compilación completa **desde fuentes** en la placa sigue sin verificar.

Manual completo: [`armv7-pi2b.es.md`](armv7-pi2b.es.md); original en chino tradicional: [`armv7-pi2b.md`](armv7-pi2b.md).

## Turno de modelo local a la placa (2026-10-01)

Salida en bruto de la compilación cruzada, del router en la placa y de dos turnos reales de pi con el modelo y el servidor en la propia placa. Receta: `armv7-pi2b.es.md` §8.

```text
=== host: cross toolchain without sudo + llama-server build ===
  arm-linux-gnueabihf-gcc 11.4.0   (sysroot 2.35, target ld-linux-armhf.so.3)
  source: llama.cpp @ 121201a7b, cmake 3.22 toolchain file (no CMakePresets v4)
  flags: -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
         -DGGML_NATIVE=OFF -DGGML_NEON=ON -DGGML_CPU_ARM_ARCH=armv7-a -DGGML_OPENMP=ON -DLLAMA_CURL=OFF
         -static-libstdc++ -static-libgcc
  bin/llama-server  13.5 MB
  ELF 32-bit LSB pie executable, ARM, EABI5 version 1 (GNU/Linux), dynamically linked,
      interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0
  NEEDED: libgomp.so.1, libm.so.6, libc.so.6, ld-linux-armhf.so.3

=== board: llama-server --version ===
  version: 0.3.0-dev (build 10734, commit 121201a7b)
  built with GNU 11.4.0 for Linux arm

=== board: router mode (llama-server --models-preset <ini>) ===
  load_models: Loaded 2 local model presets from /home/<user>/models
  Available models (2) (*: custom preset)
      functiongemma-270m-it-q4_k_m
      qwen2.5-0.5b-instruct-q4_k_m
  llama_server:     router mode

=== board: GET /models and /props ===
  functiongemma-270m-it-q4_k_m   status=unloaded  source=preset
  qwen2.5-0.5b-instruct-q4_k_m   status=unloaded  source=preset
  /props -> {"role":"router","max_instances":4,"models_autoload":true,"model_path":"none", ...}

=== board: pi real turn 1 - 270M Q4_K_M (46 s wall) ===
  slot print_timing: id  3 | task 0 | prompt eval time =  6577.32 ms /  72 tokens ( 10.95 tokens per second)
  slot print_timing: id  3 | task 0 |        eval time =  6877.79 ms /  20 tokens (  2.76 tokens per second)
  slot print_timing: id  3 | task 0 |       total time = 13455.10 ms /  92 tokens
  pi rc=0  wall=46s   (answer printed; 20 generated tokens, finish_reason=stop)

=== board: pi real turn 2 - 0.5B Q4_K_M, --mode json ===
  pi rc=0  wall=77s
  stopReason: stop | raw: stop
  usage: input 55 output 19 total 74
  answer: "台大山是台灣最高的山，海拔為1,253公尺。"
  # the pipeline is what was verified; a 0.5B model's factual accuracy is not a pass criterion

=== board: same loaded model, warm second turn ===
  wall=16s   (prompt eval 11 tokens, eval 7 tokens)

=== board: resources during the turns ===
  Mem: 921 total / 636 available MiB
  llama-server child RSS: 530 MiB
  KV cache type k/v: q8_0, ctx-size 8192, threads 4
```

Two findings that made the difference and are worth keeping next to these numbers:

- pi's router client only accepts models reported as `source=preset` (with `models_autoload: true`).
  Starting `llama-server --models-dir` makes `/models` list them with `source=models_dir`, and pi then
  reports `Unknown provider "llama.cpp"` because `modelIsSelectable()` filters them out.
- `clampMaxTokensToContext()` (`packages/ai/src/api/simple-options.ts`, `CONTEXT_SAFETY_TOKENS = 4096`,
  `MIN_MAX_TOKENS = 1`) computes `contextWindow - estimatedPrompt - 4096` and floors at 1. Declaring
  `contextWindow: 2048` in `~/.pi/agent/models.json` therefore sent `max_completion_tokens: 1` and every
  turn ended after a single token with `finish_reason=length`. Declaring 8192 (router `ctx-size` kept in
  step, q8_0 KV) produced the turns above.

## Turnos locales con 1.0.4 (2026-10-06)

Se repitió la medición local en la placa con `pi` 1.0.4 instalado, sobre el mismo router local de la
placa. Ambos turnos devolvieron `rc=0` (frío 771 s, caliente 721 s — sin timeouts) y terminaron en un
mensaje final con `stopReason: stop` tras una ronda de uso de herramientas, a ~0.99–1.65 tok/s. La salida
en bruto está registrada literalmente en [armv7-pi2b-verification.md](armv7-pi2b-verification.md).
