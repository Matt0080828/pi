# Verificación ARMv7 / Pi 2B — guía en español

> Idioma／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ **Español**

Esta guía explica el **registro sin procesar de la placa** que está en
[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md). El registro es la evidencia y se conserva
literalmente: el propio script de instalación imprime en chino y reescribirlo destruiría su valor como
registro. Lo de abajo es explicación y traducción de referencia; si algo difiere, manda el registro original.

- Placa: Raspberry Pi 2 Model B (armv7l, 921 MiB de RAM), Raspbian GNU/Linux 13 (trixie)
- Ciclo: 2026-09-23, instalando `@earendil-works/pi-coding-agent@0.87.1`
- Comando: `scripts/pi2-armv7/pi2-pi-agent.sh all` (probe → install → verify), ejecutado desde el PC por SSH
- Resultado: **11/11 comprobaciones de aceptación superadas**, `verify` exit 0

## Qué significa cada bloque del registro

| Bloque | Contenido |
| --- | --- |
| `=== 0) 基本環境` | Entorno: `uname -m = armv7l`, Raspbian 13 (trixie), 921 MiB totales / 640 MiB libres, 6,2 GB libres en `$HOME`. Después pasan las tres primeras comprobaciones: la arquitectura es armv7l; se ejecuta como usuario sin privilegios (uid 1000) y todo va a `$HOME`; existe un descargador (`curl`). |
| `=== 1) Node 22 armv7l` | Ya está Node v22.23.2 (`/home/<user>/opt/node22/bin/node`, la línea de compilación oficial para armv7l) y `node:sqlite` está disponible → el backend de sesión no necesita módulos nativos. |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8 instala el paquete oficial en `/home/<user>/.local`: `changed 119 packages in 3m`. Aparece un aviso de obsolescencia (`node-domexception@1.0.0`) que es de upstream y es inocuo. |
| `=== 3) 驗收（可量測的項目）` | El ejecutable existe y **`pi --version` imprime 0.87.1**; `pi --help` también funciona. Se listan los seis precompilados incluidos y todos son x64/arm64 (darwin/linux/win32) — **ningún `linux-arm`**, así que en esta placa nunca se carga nada nativo; lo que realmente prueba el punto es que `pi --version` haya funcionado. |
| `=== 4) 量測（給日後比對用）` | Mediciones para comparar más adelante: `pi --version` 4,92 s, RSS base de `node` 40 MiB, Node 187 MB, paquete pi 156 MB. |
| `=== 5) 接下來（可選）` | Cómo persistir el PATH en `~/.bashrc` y cómo ejecutar un turno real de modelo (necesita una clave, o un endpoint compatible con OpenAI en la misma red, p. ej. LM Studio). |
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

## Remedición independiente (misma placa, 0.87.1)

Tres ejecuciones adicionales de `pi --version` tras la instalación, y el estado de la placa en ese momento:

```text
  run1: 4.75 s (0.87.1)
  run2: 4.83 s (0.87.1)
  run3: 4.81 s (0.87.1)
  node RSS: 40 MiB
  free: 655 MiB available
  disk HOME: 6.2G
```

## Otra evidencia medida en la placa (registrada en otros archivos)

- El cargador instalado no entrega ningún helper nativo en esta arquitectura — medido con el paquete
  0.87.1: con `process.arch = arm`, tanto `getNativeClipboard()` como `getNativePlatformHelper()`
  devuelven `undefined`, que es el fallback documentado a herramientas de línea de comandos.
- La comprobación del build desde fuentes se comporta como está documentado: el
  `packages/tui/native/linux/build.sh` de upstream sale con **1** en armv7l
  (`Unsupported Linux architecture: armv7l`), mientras que el de este fork imprime un aviso de omisión y
  sale con **0**. La compilación completa **desde fuentes** en la placa sigue sin verificar.

Manual completo: [`armv7-pi2b.es.md`](armv7-pi2b.es.md); original en chino tradicional: [`armv7-pi2b.md`](armv7-pi2b.md).
