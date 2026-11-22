# ERROR 2026 · V1.0

Tony C. Ware · ZX Spectrum 48K PAL

- **Jugar.** Carga `juego/ERROR_2026_V1_0_48K.tap` en modo Spectrum 48K. Desde BASIC, escribe `LOAD ""`. Pulsa SPACE o FIRE para empezar.
- **Leer.** `documentacion/ERROR_2026_V1_0_MANUAL_ATLAS_MEMORIA.pdf` incluye la historia revisada, los controles, el bestiario y el atlas completo. La carátula original se incluye íntegra en `caratula/`.
- **Construir.** Ejecuta `python3 tools/build_error_2026.py` desde `fuentes/`. El resultado se escribe en `fuentes/build/` y coincide byte a byte con el TAP distribuido.
- **Verificar.** Para las pruebas, instala Pillow y ejecuta `python3 build.py`, `python3 tests/test_error2026.py` y `python3 tests/test_error2026_waves.py` desde `fuentes/`.

## Banco de trabajo

| Archivo o carpeta | Contenido |
| --- | --- |
| `banco/programa_8000.bin` | Primer bloque CODE del TAP, dirección $8000 |
| `banco/banco_auxiliar_F300.bin` | Segundo bloque CODE del TAP, dirección $F300 |
| `banco/arte_*.asm` | Recursos generados a partir de los gráficos de fuente |
| `banco/simbolos.json` | Direcciones del ensamblado V1.0 |
| `banco/sprites/` | Extracciones ampliadas de los fotogramas del binario |
| `banco/capturas/` | 40 imágenes de la V1.0 y sus correspondientes volcados de pantalla Spectrum de 6912 bytes |
| `banco/memoria/` | Captura histórica de la Beta 0.1 |

Código y herramientas bajo MIT. Los términos de los recursos gráficos están en `fuentes/LICENCIA_GRAFICOS.md`.
