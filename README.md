# tty-ascii-custom-banner

**Banners ASCII a color para la pantalla de inicio de sesión de Linux (consola tty), SSH y MOTD.**
Convierte cualquier imagen en un banner dibujado solo con símbolos ASCII imprimibles, lo ajusta al tamaño real de tu consola y lo instala como pantalla de bienvenida. Funciona en cualquier distribución que use **systemd** (Debian, Ubuntu, Proxmox VE, Fedora, Arch, openSUSE...).

> [English summary at the end of this file](#english-summary) - full English help: `bash tty-banner.sh --help-en`

---

## Qué hace

- Muestra tu imagen (logo, mascota, escudo...) como arte ASCII **a color** en la pantalla de login de la consola física o de la consola de una máquina virtual (tty1, tty2...).
- Reduce el tamaño de la letra **solo mientras se muestra el banner** para que quepan más caracteres (más detalle) y **devuelve la fuente original al iniciar sesión**.
- Se adapta automáticamente a la resolución de la consola: el banner siempre se ve completo.
- Origen de los banners: una **imagen o carpeta local**, o el **repositorio de banners ya diseñados** de este proyecto (carpeta `banners/`).
- Opcional: rotar varios banners al azar y usar el banner como aviso previo al login **SSH** y como **MOTD**.
- Muestra **IP, sistema operativo y hostname** bajo el banner, pero solo los que traía la pantalla de login original.
- **Vista previa** antes de aplicar y **desinstalación limpia** que restaura todo lo original.

## Requisitos

| Requisito | Detalle |
|---|---|
| Sistema | Linux con **systemd** y consola virtual (tty1-tty6) |
| Permisos | `root` (o `sudo`) para instalar/desinstalar. La vista previa no lo necesita |
| python3 | Se instala automáticamente si falta (apt, dnf/yum, pacman o zypper) |
| Pillow (opcional) | Necesario para imágenes que no sean PNG (JPG, GIF, WebP...). El instalador ofrece instalarlo |
| Fuentes de consola | Fuente pequeña Terminus 6x12 (`Lat15-Terminus12x6` en Debian/Ubuntu, `ter-v12n` en Fedora/Arch). El instalador ofrece instalarla |
| Red | Solo si usas el repositorio de GitHub |

## Instalación rápida

```bash
git clone https://github.com/arian-alvarezs/tty-ascii-custom-banner.git
cd tty-ascii-custom-banner
chmod +x tty-banner.sh
sudo bash tty-banner.sh
```

El asistente pregunta, en este orden:

1. **Origen del banner:** imagen/carpeta local o repositorio de GitHub (con menú para elegir uno o varios).
2. **Rotación** (si elegiste varios banners): rotarlos al azar o usar solo uno.
3. **SSH** y **MOTD:** si quieres usar también el banner ahí (ambos opcionales, por defecto *no*).
4. **Vista previa** del banner en tu terminal.
5. **Confirmación** para aplicar.

Para verlo de inmediato en la consola: `sudo systemctl restart getty@tty1` (cierra la sesión de esa consola). Si no, se verá en el siguiente arranque.

## Ejemplos de uso

```bash
# Asistente interactivo
sudo bash tty-banner.sh

# Solo vista previa de una imagen (no instala nada, no requiere root)
bash tty-banner.sh --local mi_logo.png --preview

# Un banner del repositorio, por nombre
sudo bash tty-banner.sh --repo leon.png

# Todos los banners del repositorio, rotando, y también como MOTD, sin preguntas
sudo bash tty-banner.sh --repo all --rotate --motd -y

# Carpeta local con varias imágenes, banner SSH y solo IP y hostname bajo el banner
sudo bash tty-banner.sh --local ~/banners/ --ssh --info ip,host

# Desinstalar y restaurar todo
sudo bash tty-banner.sh --uninstall
```

## Opciones

| Opción | Descripción |
|---|---|
| `--local RUTA` | Imagen o carpeta con imágenes (si es carpeta, se usan todas) |
| `--repo [NOMBRES]` | Repositorio de GitHub. Sin nombres: menú. `NOMBRES`: lista separada por comas (`leon.png,dragon.png`) o `all` |
| `--repo-url SPEC` | Otro repositorio: `usuario/repo[@rama][:carpeta]` (por defecto `arian-alvarezs/tty-ascii-custom-banner@main:banners`) |
| `--preview` | Solo vista previa: no instala y no requiere root |
| `--rotate` / `--no-rotate` | Rotar al azar entre varios banners en cada inicio de consola |
| `--ssh` / `--no-ssh` | Usar el banner (sin color) como aviso previo al login SSH (`/etc/issue.net`) |
| `--motd` / `--no-motd` | Usar el banner (a color) como MOTD tras iniciar sesión (`/etc/motd`) |
| `--info LISTA` | Datos bajo el banner: `auto` (por defecto), `none` o lista de `ip,os,host` |
| `--fill ascii\|bg` | `ascii` (por defecto): solo símbolos ASCII con color. `bg`: además rellena zonas sólidas con color de fondo (más fiel, se ven bloques) |
| `--font NOMBRE` | Fuente de la consola mientras se ve el banner (`auto` por defecto). Ver `ls /usr/share/consolefonts` o `/usr/lib/kbd/consolefonts` |
| `--no-font` | No cambiar la fuente |
| `--ttys "1 2"` | Consolas donde se aplica (por defecto: `1`) |
| `--no-deps` | No instalar paquetes (python3, Pillow, fuentes) |
| `-y`, `--yes` | Aceptar valores por defecto sin preguntar (rotación, SSH y MOTD siguen desactivados salvo que los indiques) |
| `--uninstall` | Desinstala y restaura los archivos originales |
| `--diagnose` | Muestra la fuente elegida, el tamaño real de la consola y errores de `setfont` |
| `--lang es\|en` | Idioma de los mensajes |
| `--help-es` / `--help-en` | Ayuda completa en español / inglés |
| `-v`, `--version` | Versión |

## Formatos de imagen compatibles

| Con Pillow instalado | Sin Pillow |
|---|---|
| PNG, JPEG/JPG, GIF (primer cuadro), BMP, WebP, TIFF, ICO, PPM/PGM, TGA y los que Pillow pueda abrir | Solo PNG (los PNG entrelazados requieren Pillow) |

- En carpetas y en el repositorio se reconocen las extensiones `.png .jpg .jpeg .gif .bmp .webp .tif .tiff`.
- **Fondo:** un PNG con transparencia usa la transparencia como fondo. Si no la tiene, el color del borde de la imagen se trata como fondo y se descarta (puede ser negro, blanco u otro color). Los detalles interiores del mismo color que el fondo se conservan.
- Las imágenes grandes se reducen automáticamente (dimensión máxima de trabajo: 960 px).

**Consejos para un buen banner:** logos, mascotas e ilustraciones de colores planos con buen contraste y fondo uniforme o transparente funcionan mejor que las fotografías. Cuanto más simple y definida la silueta, mejor se ve en ASCII.

## Cómo se dibuja el banner

- **Solo símbolos ASCII imprimibles** (códigos 32 a 126). No usa letras, números ni caracteres extendidos; la escala va de ligero a denso: ``.-',:~;^*+=/?|<[}%$&#@``.
- **Colores:** la consola tty solo admite 16 colores. El script calcula la **paleta óptima de 13 colores** a partir de tu imagen y la carga en la consola; los otros 3 se reservan para el texto (login, hostname, etc.). Al iniciar sesión se restauran la paleta y la fuente originales.
- **Tamaño:** con la fuente Terminus 6x12 en una pantalla de 1920x1080 caben unas 320 columnas x 90 filas. Con una fuente más grande el banner es más pequeño y con menos detalle.
- En terminales modernas (vista previa, MOTD) se usan colores de 24 bits.

## Datos bajo el banner (IP, SO, hostname)

Durante la instalación se analiza la pantalla de login **original** (`/etc/issue`) y solo se muestra lo que ya traía:

| Dato | Se muestra si el banner original... |
|---|---|
| IP | contenía una dirección IP, `\4` o `\6` |
| Sistema operativo | contenía el nombre del SO o `\S`, `\s`, `\r`, `\v` |
| Hostname | contenía `\n` o el nombre del equipo |

Si el original traía una URL con IP (por ejemplo Proxmox VE: `https://IP:8006/`), se conserva el formato con la IP actual. Puedes forzarlo con `--info ip,os,host` o desactivarlo con `--info none`.

> La IP se lee cuando arranca la consola. Si tu red tarda en levantar, ejecuta `sudo systemctl restart getty@tty1`.

## Rotación de banners

Solo si la activas (`--rotate` o aceptándolo en el asistente) y hay más de un banner: en cada arranque de la consola (arranque del sistema o cierre de sesión) se elige uno al azar, evitando repetir el anterior.

## Banner para SSH y MOTD

Ambos son **opcionales** y se activan con `--ssh` / `--motd` o aceptándolo en el asistente.

- **SSH (`--ssh`):** usa el banner como aviso previo al login. Va **sin color** (OpenSSH filtra los códigos de escape). Se configura con un archivo `/etc/ssh/sshd_config.d/00-tty-banner.conf` si tu `sshd_config` incluye ese directorio; si no, se agrega un bloque marcado al inicio de `sshd_config`. Se valida con `sshd -t` antes de recargar el servicio y se revierte si falla. Ancho 80 columnas, máximo 40 filas.
- **MOTD (`--motd`):** escribe el banner a color en `/etc/motd`. En la consola tty, tras iniciar sesión se vuelve a mostrar. Ancho 80 columnas, máximo 40 filas.
- Si tu `sshd_config` ya define `Banner` antes de la línea `Include`, esa configuración prevalece.

## Qué se instala y qué se modifica

| Ruta | Para qué sirve |
|---|---|
| `/usr/local/lib/tty-banner/` | Motor (`engine.py`) y script de restauración (`restore.sh`) |
| `/usr/local/share/tty-banner/banners/` | Banners convertidos (`.tbn`) |
| `/etc/tty-banner.conf` | Configuración |
| `/etc/systemd/system/getty@ttyN.service.d/tty-banner.conf` | Genera el banner cada vez que arranca la consola |
| `/etc/profile.d/tty-banner.sh` | Restaura fuente y paleta al iniciar sesión en la consola |
| `/var/lib/tty-banner/` | Copias de seguridad de los originales, estado y caché |
| `/etc/issue` | Pantalla de login (respaldo del original antes de modificar) |
| `/etc/issue.net`, `/etc/motd`, configuración de `sshd` | Solo si activas SSH / MOTD (con respaldo) |
| `pvebanner.service` | En **Proxmox VE** se enmascara para que no sobrescriba el banner (se reactiva al desinstalar) |

### Configuración (`/etc/tty-banner.conf`)

Los cambios se aplican en el siguiente arranque de la consola (`sudo systemctl restart getty@tty1`).

| Clave | Significado |
|---|---|
| `TTYS` | Consolas donde se aplica |
| `FONT` | Fuente (`auto`, `none` o nombre) |
| `FILL` | `ascii` o `bg` |
| `ROTATE`, `SSH`, `MOTD` | `1` activado, `0` desactivado |
| `INFO_IP`, `INFO_OS`, `INFO_HOST` | Datos bajo el banner |
| `URL_TPL` | Plantilla de URL con IP, por ejemplo `https://{ip}:8006/` |
| `SSH_COLS`, `MOTD_COLS`, `REMOTE_MAXROWS` | Tamaño para SSH y MOTD |

## Desinstalar

```bash
sudo bash tty-banner.sh --uninstall
```

Restaura `/etc/issue`, `/etc/issue.net`, `/etc/motd` y la configuración de `sshd` a su estado original, elimina todos los archivos instalados, devuelve la fuente y la paleta de la consola y, en Proxmox VE, reactiva `pvebanner.service`.

## Solución de problemas

| Problema | Qué hacer |
|---|---|
| El banner se ve pobre o pequeño | Ejecuta `bash tty-banner.sh --diagnose`. Con la fuente pequeña en 1080p debe indicar unas 90 filas x 320 columnas; si ves 25x80, no se aplicó. Instala las fuentes Terminus (`apt install console-setup kbd`, `dnf install kbd terminus-fonts-console`, `pacman -S kbd terminus-font` o `zypper install kbd terminus-bitmap-fonts`) y reinstala |
| No cambia nada al reiniciar la consola | `sudo systemctl restart getty@tty1` y revisa `--diagnose` |
| La fuente no vuelve a la normal tras el login | La restauración usa `/etc/profile.d`, que leen las shells de login tipo bash/sh. Con otras shells (por ejemplo zsh) ejecuta `/usr/local/lib/tty-banner/restore.sh "$(tty)"` desde tu perfil |
| Error al leer el repositorio (HTTP 403/429) | Límite de peticiones anónimas de GitHub: `export GITHUB_TOKEN=tu_token` y vuelve a ejecutar |
| Una imagen JPG/GIF/WebP no se convierte | Falta Pillow: `apt install python3-pil` (o `python3-pillow`, `python-pillow`) |

## Limitaciones

- Solo consolas virtuales (tty1-tty6); no aplica a consolas serie.
- La consola tty admite 16 colores; con `--fill ascii` los colores muy oscuros se aclaran para que se vean.
- El aviso SSH previo al login no puede llevar color.
- Requiere systemd.

## Agregar banners al repositorio

Coloca tus imágenes **PNG** en la carpeta `banners/` (nombres sin espacios ni barras). Los mejores resultados: fondo transparente o uniforme, colores planos, buen contraste y silueta definida. Cualquiera podrá elegirlas desde el menú `--repo`.

---

## Créditos

- **Idea y concepto:** [arian-alvarezs](https://github.com/arian-alvarezs)
- **Programación:** Claude, asistente de IA de [Anthropic](https://www.anthropic.com)

---

## English summary

**tty-ascii-custom-banner** turns any image into a colored ASCII login banner for the Linux text console (tty), and optionally for the SSH pre-login banner and MOTD. Works on any **systemd** distribution (Debian, Ubuntu, Proxmox VE, Fedora, Arch, openSUSE...).

- Drawn only with **printable ASCII symbols** (codes 32-126), colored with an optimal 13-color palette computed from your image.
- Uses a small console font **only while the banner is shown** (more characters = more detail) and **restores the original font at login**. The banner always fits the console size.
- Source: a local image/folder, or the ready-made banners in this repository's `banners/` folder.
- Optional: random rotation, SSH banner (no color), colored MOTD. IP / OS / hostname are shown only if the original login screen had them.
- Preview before applying, and a clean uninstall that restores every original file.

```bash
git clone https://github.com/arian-alvarezs/tty-ascii-custom-banner.git
cd tty-ascii-custom-banner
chmod +x tty-banner.sh
sudo bash tty-banner.sh              # interactive wizard
bash tty-banner.sh --local logo.png --preview   # preview only, no root
sudo bash tty-banner.sh --repo all --rotate -y  # all repo banners, rotating
sudo bash tty-banner.sh --uninstall  # restore everything
```

Image formats: PNG always; with Pillow also JPEG, GIF (first frame), BMP, WebP, TIFF and more. Full option reference: `bash tty-banner.sh --help-en`. Troubleshooting: `bash tty-banner.sh --diagnose`.

**Credits:** idea and concept by [arian-alvarezs](https://github.com/arian-alvarezs); programmed by Claude, an AI assistant by [Anthropic](https://www.anthropic.com).
