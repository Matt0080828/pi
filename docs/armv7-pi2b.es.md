# Ejecutar pi en una Raspberry Pi 2 Model B (ARMv7)

> Idioma／Language：[繁體中文](armv7-pi2b.md) ｜ [English](armv7-pi2b.en.md) ｜ [简体中文](armv7-pi2b.zh-CN.md) ｜ [日本語](armv7-pi2b.ja.md) ｜ [한국어](armv7-pi2b.ko.md) ｜ **Español**

**Veredicto: sí, funciona — medido en una Pi 2B real (11/11 comprobaciones de aceptación).** No hace
falta ningún cambio en el código del agente: basta con instalar el **paquete npm oficial**. Esta rama
solo añade dos pequeños cambios "habilitadores" para que «compilar desde el código fuente en armv7» y
«un futuro helper nativo para armv7» no queden bloqueados por la arquitectura (véase
[Qué cambia esta rama](#4-qué-cambia-esta-rama)).

- Placa objetivo: Raspberry Pi 2 Model B (armv7l, 4×900 MHz, 921 MiB de RAM), Raspbian GNU/Linux 13 (trixie)
- Medición: **2026-09-23 con `@earendil-works/pi-coding-agent@0.87.1`** (ciclo anterior: 2026-09-22, 0.87.0)
- Registro sin procesar: [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md) (con
  [guía en español](armv7-pi2b-verification.es.md))
- La evidencia son **mediciones reales de hardware**, no razonamientos estáticos: 11/11 comprobaciones

---

## 1. Tres hechos decisivos

| Hecho | Evidencia |
| --- | --- |
| **Node 22 tiene compilaciones oficiales para armv7l; Node 23+ no** | `nodejs.org/dist/index.json`: las **35/35** versiones de v22 incluyen `linux-armv7l` (incluidas las 11 que son >= 22.19; la última es v22.23.2); ninguna de las 12 versiones más recientes (v23+) la incluye. Este repositorio exige `engines.node >= 22.19.0` → **solo la línea v22 lo cumple** |
| **Los binarios precompilados oficiales no incluyen armv7** | Los recursos de la versión son solo `linux-x64` / `linux-arm64` / `darwin-x64|arm64` / `windows-x64|arm64`, y `build-binaries.yml` contempla exactamente esos cuatro casos → el tarball oficial **no sirve** |
| **La ruta del paquete npm no tiene obstáculo nativo** | `@earendil-works/pi-coding-agent@0.87.1`: **sin restricción `os`/`cpu`**, incluye una CLI ya empaquetada (`dist/bundle/*.js`), sus dependencias son JS puro o wasm (`photon-node` incluye `photon_rs_bg.wasm`), `canvas` solo está en `devDependencies` y el backend de sesión usa el `node:sqlite` integrado |

La única pérdida funcional: el helper nativo X11/portapapeles de la TUI (`linux-platform-x11.node`)
solo existe precompilado para x64/arm64, y el cargador `packages/tui/src/native-platform.ts` devuelve
`undefined` en cualquier otra arquitectura. El propio `packages/tui/native/linux/README.md` lo dice:
"Coding-agent falls back to command-line tools when native reads are unavailable"; en armv7 esto es una
**degradación prevista y documentada**: nada se cae, solo se pierde la integración con portapapeles e
imágenes.

Medido en la placa con el paquete 0.87.1 ya instalado:

```text
process.arch = arm, process.platform = linux
getNativeClipboard()      -> undefined
getNativePlatformHelper() -> undefined
```

## 2. Mediciones en la placa

| Comprobación | Valor medido |
| --- | --- |
| Arquitectura | `armv7l` (Raspbian 13 trixie) |
| Identidad | uid 1000, **sin sudo en ningún momento** (todo en `$HOME`) |
| Node | **v22.23.2** (tarball oficial `linux-armv7l`, 26.338.176 bytes) |
| `node:sqlite` | **disponible** → el backend de sesión no necesita módulos nativos |
| CLI | **`pi --version` → 0.87.1**; `pi --help` imprime con normalidad |
| Instalación npm | `changed 119 packages in 3m` (npm 10.9.8) |
| Precompilados incluidos | solo `darwin-arm64|x64`, `linux-arm64|x64`, `win32-arm64|x64` — **ningún `linux-arm` (armv7)** |
| Arranque | `pi --version` **4,75–4,92 s** (arranque en frío de la Pi2B, cuatro ejecuciones) |
| Memoria | RSS base de `node` **40 MiB**; 640 MiB disponibles durante la instalación, sin OOM |
| Disco | Node 187 MB + paquete pi 156 MB (6,2 GB libres en `$HOME`) |

> Limitación conocida: **la CLI en sí está verificada**, pero un turno real de modelo necesita una clave
> de API o un endpoint compatible con OpenAI en la misma red (por ejemplo LM Studio). La aceptación de
> esta rama no cubre ese paso.

## 3. Instalación y uso

En la Pi 2B (**no hace falta sudo**; todo se instala en `$HOME`):

```sh
# 1) Node 22 armv7l (tarball oficial; no usar NodeSource ni v23+)
curl -fsSLO https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-armv7l.tar.xz
mkdir -p ~/opt && tar -xJf node-v22.23.2-linux-armv7l.tar.xz -C ~/opt
ln -sfn ~/opt/node-v22.23.2-linux-armv7l ~/opt/node22

# 2) CLI
export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"
node -v                      # v22.23.2
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
pi --version                 # 0.87.1

# 3) Persistencia (añadir a ~/.bashrc)
echo 'export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Para compilar **desde el código fuente** (este repositorio):

```sh
git clone https://github.com/matttest0080-prog/pi.git && cd pi
npm ci && npm run build      # en armv7 requiere el cambio de build.sh descrito abajo
```

> Esa ruta de compilación desde el código fuente **no** se ha verificado de principio a fin en la placa.
> Lo que sí se midió allí es la propia comprobación de arquitectura: el `packages/tui/native/linux/build.sh`
> de upstream sale con **1** ("Unsupported Linux architecture: armv7l"), mientras que el de este fork
> imprime un aviso de omisión y sale con **0**. Lo que viene después (compilar todo el monorepo
> TypeScript en una placa de 921 MiB) sigue sin probarse.

Esta rama incluye tres scripts probados en hardware real y una autoprueba (`scripts/pi2-armv7/`):

```sh
scripts/pi2-armv7/install-pi-on-pi2.sh              # en la Pi: comprobaciones → instalación → verificación → medición
scripts/pi2-armv7/install-pi-on-pi2.sh --dry-run    # solo imprime los pasos, no cambia nada
scripts/pi2-armv7/install-pi-on-pi2.sh --check-only # solo inspecciona el estado actual, no instala
scripts/pi2-armv7/pi2-pi-agent.sh probe|install|verify|all   # se maneja desde el PC por SSH
scripts/pi2-armv7/selftest.sh                       # autoprueba de las herramientas (incluye rutas negativas)
```

Son deliberadamente **fail-closed**: si la arquitectura no es `armv7l`, si se ejecuta como root, si el
Node no es v22, si aparece un precompilado específico de ARMv7, si hay cualquier rastro de un Node que
no sea v22 en el registro, o si falla algún paso, se rechaza de forma explícita con salida distinta de cero.

## 4. Qué cambia esta rama

**Ejecutar la CLI no requiere ningún cambio de código** (el resultado en hardware es la prueba). Los dos
cambios siguientes solo evitan que se bloqueen «compilar desde el código fuente en armv7» y «un helper
nativo para armv7, si alguien lo compila»; ambos llevan el motivo en un comentario:

| Archivo | Cambio | Por qué |
| --- | --- | --- |
| `packages/tui/native/linux/build.sh` | para `armv7l`/`armv6l` imprime un aviso explícito y **sale con 0** (sin compilar) | el `case` original solo conocía `x86_64`/`aarch64` y salía con `exit 1` en todo lo demás, así que `npm run build` fallaba en una Pi 2. ARMv7 no tiene precompilado y el cargador nunca lo pide, así que omitir explícitamente es correcto donde «fallar todo el workspace» no lo es |
| `packages/tui/src/native-platform.ts` | la comprobación de arquitectura del cargador también acepta `arm` | para que quien **compile localmente** un helper ARMv7 pueda usarlo; sin helper el comportamiento no cambia (el `require` falla y la función devuelve `undefined`). Nota: el paquete npm trae JS ya compilado, así que el cambio solo surte efecto tras **recompilar** |

Ninguno de los dos afecta al comportamiento en x64/arm64.

## 5. Revertir

```sh
# quitar solo la parte de pi (~/.local puede compartirse con otras herramientas, p. ej. hermes en la misma placa)
rm -rf ~/.local/lib/node_modules/@earendil-works ~/.local/bin/pi
rm -rf ~/opt/node22 ~/opt/node-v22.23.2-linux-armv7l
```

## 6. Reproducir esta verificación

```sh
scripts/pi2-armv7/selftest.sh                                   # autoprueba (en el PC, sin tocar la placa)
scripts/pi2-armv7/pi2-pi-agent.sh all                            # probe → install → verify
scripts/pi2-armv7/pi2-pi-agent.sh verify docs/armv7-pi2b-verification.md
```

## 7. Notas y errores que atrapó este trabajo

- **Los dos errores reales de la instalación los detectaron las comprobaciones, no se descubrieron
  después**: el tarball oficial de Node se descomprime en un directorio que conserva el prefijo `v`
  (`node-v22.23.2-linux-armv7l`, que al principio omití); y mi primer criterio de aceptación decía
  «`node_modules` no debe contener ningún `.node`», lo cual es incorrecto: el paquete incluye
  legítimamente precompilados de otras plataformas. El invariante correcto es «**no existe un
  precompilado específico de ARMv7** *y* la CLI arranca».
- **Los metadatos del paquete 0.87.1 se revalidaron**: sigue sin restricción `os`/`cpu` y `pi-tui` sigue
  incluyendo exactamente seis precompilados (x64/arm64 para darwin/linux/win32), sin `linux-arm`.
- **La sincronización con upstream no toca el trabajo de ARMv7**: tras fusionar upstream `898ab8040`
  (v0.87.1), los nueve archivos de ARMv7 son idénticos byte a byte y la única diferencia del árbol
  fusionado con upstream es exactamente ese delta de ARMv7.
