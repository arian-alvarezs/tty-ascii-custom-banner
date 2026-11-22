#!/usr/bin/env bash
# tty-banner - Custom colored ASCII banners for the Linux text console (tty), SSH and MOTD.
# Works on any distribution that uses systemd. Run with --help-es or --help-en.
# Repo of ready-made banners: https://github.com/arian-alvarezs/tty-ascii-custom-banner
set -u
VERSION="1.0.0"
PROG="${0##*/}"
DEF_REPO="arian-alvarezs/tty-ascii-custom-banner"; DEF_BRANCH="main"; DEF_PATH="banners"
R="${TTYB_ROOT:-}"; [ -n "$R" ] && export TTYB_ROOT
LIB="$R/usr/local/lib/tty-banner"; SHARE="$R/usr/local/share/tty-banner"; STATE="$R/var/lib/tty-banner"
BK="$STATE/backup"; CONF="$R/etc/tty-banner.conf"; TTY_IN="${TTYB_TTY:-/dev/tty}"
LANG_UI=en
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in es*) LANG_UI=es;; esac
MODE=install; PREVIEW_ONLY=0; ASSUME_YES=0; NO_DEPS=0
SRC=""; LOCAL_PATH=""; REPO_SEL=""; REPO_SPEC="$DEF_REPO@$DEF_BRANCH:$DEF_PATH"
FLAG_ROTATE=""; FLAG_SSH=""; FLAG_MOTD=""; FONT_OPT="auto"; TTYS="1"; INFO_OPT="auto"; FILL_OPT="ascii"
TMP=""; ENGINE=""; PY=""

say() { if [ "$LANG_UI" = es ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
warn() { printf '[!] '; say "$1" "$2" >&2; }
die() { printf '[x] '; say "$1" "$2" >&2; exit 1; }
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; if [ "${PAL_DIRTY:-0}" = 1 ]; then printf '\033]R' 2>/dev/null; fi; }
trap cleanup EXIT

[ -n "${TTYB_TTY:-}" ] && exec 3<"$TTYB_TTY"
have_tty() { [ -r "$TTY_IN" ] && { : <"$TTY_IN"; } 2>/dev/null; }
readline() { # readline "es" "en" -> REPLY
  local p; if [ "$LANG_UI" = es ]; then p="$1"; else p="$2"; fi
  REPLY=""; have_tty || return 1
  printf '%s ' "$p" >&2
  if [ -n "${TTYB_TTY:-}" ]; then IFS= read -r REPLY <&3 || return 1; echo "$REPLY" >&2; else IFS= read -r REPLY <"$TTY_IN" || return 1; fi
}
confirm() { # confirm "es" "en" default(y|n)
  local d="$3" h="[s/N]"; [ "$LANG_UI" = en ] && h="[y/N]"
  if [ "$d" = y ]; then h="[S/n]"; [ "$LANG_UI" = en ] && h="[Y/n]"; fi
  if [ "$ASSUME_YES" = 1 ] || ! have_tty; then [ "$d" = y ]; return; fi
  readline "$1 $h" "$2 $h" || { [ "$d" = y ]; return; }
  case "$REPLY" in "") [ "$d" = y ];; [sSyY]*) return 0;; *) return 1;; esac
}
sctl() { if [ -n "${TTYB_NO_SYSTEMD:-}" ]; then echo "(sim) systemctl $*" >&2; return 0; fi; systemctl "$@"; }

# ---------------------------------------------------------------- help
help_es() { cat <<'EOF'
tty-banner - Banners ASCII a color para la consola tty de Linux, SSH y MOTD (cualquier distro con systemd)

USO
  tty-banner.sh [opciones]            Instala (asistente interactivo)
  tty-banner.sh --uninstall           Desinstala y restaura todo lo original

ORIGEN DEL BANNER (si no se indica, se pregunta)
  --local RUTA        Imagen o carpeta con imagenes (si es carpeta, se usan todas)
  --repo [NOMBRES]    Repositorio de GitHub; sin nombres muestra un menu. NOMBRES: lista separada
                      por comas (ej. leon.png,dragon.png) o "all"
  --repo-url SPEC     Otro repositorio: usuario/repo[@rama][:carpeta]
                      (por defecto arian-alvarezs/tty-ascii-custom-banner@main:banners)

FORMATOS DE IMAGEN
  Con Pillow instalado: PNG, JPEG/JPG, GIF (1er cuadro), BMP, WebP, TIFF, ICO, PPM/PGM, TGA...
  Sin Pillow: solo PNG (el instalador ofrece instalar Pillow). Un PNG con transparencia usa
  la transparencia como fondo; si no, el color del borde se trata como fondo y se descarta.
  En carpetas/repositorio se reconocen: .png .jpg .jpeg .gif .bmp .webp .tif .tiff

OPCIONES
  --preview           Solo vista previa (no instala, no requiere root)
  --diagnose          Muestra fuente elegida, tamano real de la consola y errores de setfont
  --rotate / --no-rotate   Rotar al azar entre varios banners en cada inicio de consola
  --ssh / --no-ssh         Usar el banner (sin color) como aviso previo al login SSH (/etc/issue.net)
  --motd / --no-motd       Usar el banner (a color) como MOTD tras iniciar sesion (/etc/motd)
  --info LISTA        Datos bajo el banner: auto (por defecto: solo los que traia el banner original),
                      none, o lista de: ip,os,host
  --font NOMBRE       Fuente de la consola mientras se ve el banner (auto por defecto; ver
                      /usr/share/consolefonts o /usr/lib/kbd/consolefonts). --no-font = no cambiar
  --fill ascii|bg     ascii (por defecto): solo simbolos ASCII imprimibles con color, sin fondos de color.
                      bg: ademas rellena zonas solidas con color de fondo (mas fiel, se ven bloques)
  --ttys "1 2"        Consolas donde se aplica (por defecto: 1)
  --no-deps           No instalar paquetes (python3, Pillow, fuentes)
  -y, --yes           Aceptar valores por defecto sin preguntar (rotacion/SSH/MOTD siguen en NO
                      salvo que se indiquen con sus opciones)
  --lang es|en        Idioma de los mensajes
  --help-es / --help-en    Esta ayuda en espanol / ingles
  -v, --version

NOTAS
  * La consola tty solo tiene 16 colores: el banner usa 13 (paleta optima calculada de la imagen);
    Con --fill bg, 6 de ellos tambien se usan como fondo. Los otros 3 se reservan para el texto. Al iniciar sesion se restauran fuente y paleta.
  * El banner se dibuja SOLO con simbolos ASCII imprimibles (codigos 32-126, sin letras ni
    caracteres extendidos); el color se aplica con codigos de escape de la consola.
  * Mas detalle = fuente mas pequena (Terminus 6x12). Si el banner se ve pobre, ejecuta --diagnose.
  * El aviso SSH previo al login va sin color (OpenSSH filtra los codigos de escape).
  * Variable GITHUB_TOKEN (opcional): evita el limite de peticiones anonimas de la API de GitHub.
  * Solo se descargan archivos de imagen; nunca se ejecuta codigo del repositorio.

EJEMPLOS
  sudo bash tty-banner.sh
  bash tty-banner.sh --local mi_logo.png --preview
  sudo bash tty-banner.sh --repo all --rotate --motd -y
  sudo bash tty-banner.sh --local ~/banners/ --ssh --info ip,host
  sudo bash tty-banner.sh --uninstall
EOF
}
help_en() { cat <<'EOF'
tty-banner - Colored ASCII banners for the Linux text console (tty), SSH and MOTD (any systemd distro)

USAGE
  tty-banner.sh [options]             Install (interactive wizard)
  tty-banner.sh --uninstall           Uninstall and restore everything original

BANNER SOURCE (asked interactively if omitted)
  --local PATH        Image or folder of images (a folder uses all of them)
  --repo [NAMES]      GitHub repository; without names shows a menu. NAMES: comma-separated list
                      (e.g. lion.png,dragon.png) or "all"
  --repo-url SPEC     Another repository: user/repo[@branch][:folder]
                      (default arian-alvarezs/tty-ascii-custom-banner@main:banners)

IMAGE FORMATS
  With Pillow installed: PNG, JPEG/JPG, GIF (first frame), BMP, WebP, TIFF, ICO, PPM/PGM, TGA...
  Without Pillow: PNG only (the installer offers to install Pillow). A PNG with transparency
  uses it as background; otherwise the border color is treated as background and dropped.
  Recognized in folders/repository: .png .jpg .jpeg .gif .bmp .webp .tif .tiff

OPTIONS
  --preview           Preview only (installs nothing, no root needed)
  --diagnose          Shows chosen font, real console size and setfont errors
  --rotate / --no-rotate   Randomly rotate among several banners at every console start
  --ssh / --no-ssh         Use the banner (no color) as pre-login SSH banner (/etc/issue.net)
  --motd / --no-motd       Use the banner (colored) as MOTD after login (/etc/motd)
  --info LIST         Data under the banner: auto (default: only what the original banner had),
                      none, or a list of: ip,os,host
  --font NAME         Console font while the banner is shown (auto by default; see
                      /usr/share/consolefonts or /usr/lib/kbd/consolefonts). --no-font = keep font
  --fill ascii|bg     ascii (default): printable ASCII symbols only, colored, no background fills.
                      bg: also fills solid areas with background color (more faithful, shows blocks)
  --ttys "1 2"        Consoles to apply it to (default: 1)
  --no-deps           Do not install packages (python3, Pillow, fonts)
  -y, --yes           Accept defaults without asking (rotation/SSH/MOTD stay OFF unless given
                      with their options)
  --lang es|en        Message language
  --help-es / --help-en    This help in Spanish / English
  -v, --version

NOTES
  * The tty only has 16 colors: the banner uses 13 (optimal palette computed from the image);
    With --fill bg, 6 of them are also used as background. The other 3 are reserved for text.
    Font and palette are restored at login.
  * The banner is drawn ONLY with printable ASCII symbols (codes 32-126, no letters or extended
    characters); color is applied with console escape codes.
  * More detail = smaller font (Terminus 6x12). If the banner looks poor, run --diagnose.
  * The pre-login SSH banner is plain (OpenSSH filters escape codes).
  * GITHUB_TOKEN env var (optional): avoids GitHub's anonymous API rate limit.
  * Only image files are downloaded; no repository code is ever executed.

EXAMPLES
  sudo bash tty-banner.sh
  bash tty-banner.sh --local my_logo.png --preview
  sudo bash tty-banner.sh --repo all --rotate --motd -y
  sudo bash tty-banner.sh --local ~/banners/ --ssh --info ip,host
  sudo bash tty-banner.sh --uninstall
EOF
}

# ---------------------------------------------------------------- system helpers
detect_pm() { for p in apt-get dnf yum pacman zypper; do command -v $p >/dev/null 2>&1 && { echo $p; return; }; done; echo none; }
pkg_install() { # pkg_install kind(python|pillow|fonts)
  [ -n "${TTYB_NO_PKG:-}" ] && return 1
  local pm pk; pm=$(detect_pm)
  case "$1:$pm" in
    python:apt-get) pk="python3";; python:dnf|python:yum|python:zypper) pk="python3";; python:pacman) pk="python";;
    pillow:apt-get) pk="python3-pil";; pillow:dnf|pillow:yum) pk="python3-pillow";; pillow:pacman) pk="python-pillow";; pillow:zypper) pk="python3-Pillow";;
    fonts:apt-get) pk="console-setup kbd";; fonts:dnf|fonts:yum) pk="kbd terminus-fonts-console";; fonts:pacman) pk="kbd terminus-font";; fonts:zypper) pk="kbd terminus-bitmap-fonts";;
    *) return 1;;
  esac
  say "  -> $pm: $pk" "  -> $pm: $pk"
  case "$pm" in
    apt-get) DEBIAN_FRONTEND=noninteractive apt-get install -y $pk;;
    dnf|yum) $pm install -y $pk;;
    pacman) pacman -S --noconfirm --needed $pk;;
    zypper) zypper --non-interactive install $pk;;
  esac
}
ensure_python() {
  PY=$(command -v python3 || true)
  if [ -z "$PY" ] && [ "$NO_DEPS" = 0 ] && [ "$(id -u)" = 0 ]; then
    say "python3 no esta instalado; intentando instalarlo..." "python3 is missing; trying to install it..."
    pkg_install python; PY=$(command -v python3 || true)
  fi
  [ -n "$PY" ] || die "Se necesita python3." "python3 is required."
}
extract_engine() { TMP=$(mktemp -d) || die "No se pudo crear directorio temporal." "Cannot create temp dir."; ENGINE="$TMP/engine.py"; engine_src >"$ENGINE"; }
eng() { "$PY" "$ENGINE" "$@"; }
need_root() { [ "$(id -u)" = 0 ] || [ -n "$R" ] || die "Ejecuta como root (sudo)." "Run as root (sudo)."; }
need_systemd() { [ -n "${TTYB_NO_SYSTEMD:-}" ] && return 0; { [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; } || die "Este sistema no usa systemd." "This system does not use systemd."; }
term_dims() { # prints "rows cols"
  local s; s=$(stty size <"$TTY_IN" 2>/dev/null) && [ -n "$s" ] && { echo "$s"; return; }
  echo "${LINES:-40} ${COLUMNS:-120}"
}
backup_file() { # backup_file path name
  mkdir -p "$BK"
  [ -e "$BK/$2.orig" ] || [ -e "$BK/$2.absent" ] || [ -L "$BK/$2.orig" ] && return 0
  if [ -e "$1" ] || [ -L "$1" ]; then cp -a "$1" "$BK/$2.orig"; else : >"$BK/$2.absent"; fi
}
restore_backup() { # restore_backup name  (puts back the original /etc/<name> and drops the backup)
  if [ -e "$BK/$1.orig" ] || [ -L "$BK/$1.orig" ]; then rm -f "$R/etc/$1"; cp -a "$BK/$1.orig" "$R/etc/$1"; rm -f "$BK/$1.orig"
  elif [ -e "$BK/$1.absent" ]; then rm -f "$R/etc/$1" "$BK/$1.absent"; fi
}
prep_target() { [ -L "$1" ] && rm -f "$1"; mkdir -p "$(dirname "$1")"; }

# ---------------------------------------------------------------- source selection
list_images_dir() { find "$1" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' \) | sort; }
IMGS=()
pick_source() {
  if [ -z "$SRC" ]; then
    { have_tty && [ "$ASSUME_YES" = 0 ]; } || die "Indica el origen con --local o --repo." "Specify the source with --local or --repo."
    say "" ""
    say "Origen del banner:" "Banner source:"
    say "  1) Imagen o carpeta local" "  1) Local image or folder"
    say "  2) Repositorio de GitHub ($REPO_SPEC)" "  2) GitHub repository ($REPO_SPEC)"
    readline "Elige [1-2]:" "Choose [1-2]:"
    case "$REPLY" in 1) SRC=local;; 2) SRC=repo;; *) die "Opcion no valida." "Invalid option.";; esac
  fi
  if [ "$SRC" = local ]; then
    if [ -z "$LOCAL_PATH" ]; then
      local p; if [ "$LANG_UI" = es ]; then p="Ruta de la imagen o carpeta:"; else p="Path of the image or folder:"; fi
      REPLY=""; have_tty || die "Falta --local RUTA." "Missing --local PATH."
      if [ -n "${TTYB_TTY:-}" ]; then
        printf '%s ' "$p" >&2
        IFS= read -r REPLY <&3 || die "Falta --local RUTA." "Missing --local PATH."
        echo "$REPLY" >&2
      else
        IFS= read -r -e -p "$p " REPLY <"$TTY_IN" || die "Falta --local RUTA." "Missing --local PATH."
      fi
      LOCAL_PATH="${REPLY/#\~/${HOME:-}}"
      if [ ! -e "$LOCAL_PATH" ]; then
        while [[ "$LOCAL_PATH" == *[[:space:]] ]]; do LOCAL_PATH="${LOCAL_PATH%?}"; done
      fi
    fi
    if [ -d "$LOCAL_PATH" ]; then mapfile -t IMGS < <(list_images_dir "$LOCAL_PATH")
    elif [ -f "$LOCAL_PATH" ]; then IMGS=("$LOCAL_PATH")
    else die "No existe: $LOCAL_PATH" "Not found: $LOCAL_PATH"; fi
    [ "${#IMGS[@]}" -gt 0 ] || die "No hay imagenes compatibles en $LOCAL_PATH" "No supported images in $LOCAL_PATH"
  else
    fetch_repo
  fi
}
fetch_repo() {
  local spec="$REPO_SPEC" owner repo branch path rest
  owner=${spec%%/*}; rest=${spec#*/}; repo=${rest%%[@:]*}; rest=${rest#"$repo"}
  branch="main"; path="banners"
  case "$rest" in @*) branch=${rest#@}; branch=${branch%%:*};; esac
  case "$rest" in *:*) path=${rest#*:};; esac
  mkdir -p "$TMP/dl"
  local names=() line name
  if [ -n "$REPO_SEL" ] && [ "$REPO_SEL" != all ]; then
    IFS=',' read -ra names <<<"$REPO_SEL"
  else
    say "Consultando el repositorio $owner/$repo..." "Querying repository $owner/$repo..."
    local listing; listing=$(eng list-repo "$owner" "$repo" "$branch" "$path") || die "No se pudo leer el repositorio (ver mensaje anterior)." "Could not read the repository (see message above)."
    [ -n "$listing" ] || die "El repositorio no tiene imagenes en $path." "The repository has no images in $path."
    local all=() i=0
    while IFS=$'\t' read -r name _ _; do all+=("$name"); done <<<"$listing"
    if [ "$REPO_SEL" = all ]; then names=("${all[@]}")
    else
      have_tty && [ "$ASSUME_YES" = 0 ] || die "Indica nombres con --repo NOMBRES o --repo all." "Give names with --repo NAMES or --repo all."
      say "" ""; say "Banners disponibles:" "Available banners:"
      for name in "${all[@]}"; do i=$((i+1)); printf '  %2d) %s\n' "$i" "$name"; done
      readline "Numeros separados por espacio, o 'all':" "Numbers separated by spaces, or 'all':"
      if [ "$REPLY" = all ]; then names=("${all[@]}")
      else for n in $REPLY; do case "$n" in ''|*[!0-9]*) continue;; esac; [ "$n" -ge 1 ] && [ "$n" -le "${#all[@]}" ] && names+=("${all[$((n-1))]}"); done; fi
    fi
  fi
  [ "${#names[@]}" -gt 0 ] || die "No se selecciono ningun banner." "No banner selected."
  for name in "${names[@]}"; do
    case "$name" in */*|..*) warn "Nombre no valido: $name" "Invalid name: $name"; continue;; esac
    say "Descargando $name..." "Downloading $name..."
    local url; url=$(eng raw-url "$owner" "$repo" "$branch" "$path" "$name")
    if eng download "$url" "$TMP/dl/$name"; then IMGS+=("$TMP/dl/$name"); else warn "Se omite $name" "Skipping $name"; fi
  done
  [ "${#IMGS[@]}" -gt 0 ] || die "No se pudo descargar ningun banner." "No banner could be downloaded."
}
TBNS=()
convert_all() {
  mkdir -p "$TMP/tbn"; local f n out
  if [ "$(eng has-pil)" = no ] && [ "$NO_DEPS" = 0 ] && [ "$PREVIEW_ONLY" = 0 ] && [ "$(id -u)" = 0 ]; then
    if confirm "Pillow no esta instalado (opcional: da soporte a JPG/GIF/WebP y es mas rapido). Instalarlo?" "Pillow is not installed (optional: adds JPG/GIF/WebP support and is faster). Install it?" y; then pkg_install pillow || warn "No se pudo instalar Pillow; se usara solo PNG." "Could not install Pillow; PNG only."; fi
  fi
  for f in "${IMGS[@]}"; do
    n=$(basename "$f"); n="${n%.*}"; n=$(printf '%s' "$n" | tr -c 'A-Za-z0-9._-' '_')
    out="$TMP/tbn/$n.tbn"; [ -e "$out" ] && out="$TMP/tbn/${n}_$RANDOM.tbn"
    say "Procesando $(basename "$f")..." "Processing $(basename "$f")..."
    if eng convert "$f" "$out" >/dev/null; then TBNS+=("$out"); else warn "No se pudo convertir $(basename "$f")" "Could not convert $(basename "$f")"; fi
  done
  [ "${#TBNS[@]}" -gt 0 ] || die "Ninguna imagen se pudo convertir." "No image could be converted."
}

# ---------------------------------------------------------------- info analysis / preview
analyze_original() {
  local src="$BK/issue.orig"
  [ -e "$src" ] || src="$R/etc/issue"
  local IP=0 OS=0 HOST=0 URL_TPL=""
  while IFS='=' read -r k v; do case "$k" in IP) IP=$v;; OS) OS=$v;; HOST) HOST=$v;; URL_TPL) URL_TPL=$v;; esac; done < <(eng analyze-issue "$src")
  case "$INFO_OPT" in
    auto) ;;
    none) IP=0; OS=0; HOST=0;;
    *) IP=0; OS=0; HOST=0; case ",$INFO_OPT," in *,ip,*) IP=1;; esac; case ",$INFO_OPT," in *,os,*) OS=1;; esac; case ",$INFO_OPT," in *,host,*) HOST=1;; esac;;
  esac
  INFO_IP=$IP; INFO_OS=$OS; INFO_HOST=$HOST; URL_TPL_V=$URL_TPL
  say "Datos bajo el banner -> IP: $IP  SO: $OS  hostname: $HOST" "Data under the banner -> IP: $IP  OS: $OS  hostname: $HOST"
}
write_info_conf() { printf 'INFO_IP="%s"\nINFO_OS="%s"\nINFO_HOST="%s"\nURL_TPL="%s"\nFILL="%s"\n' "$INFO_IP" "$INFO_OS" "$INFO_HOST" "$URL_TPL_V" "$FILL_OPT"; }
preview_all() {
  local rc dims rows cols f
  write_info_conf >"$TMP/preview.conf"
  dims=$(term_dims); rows=${dims% *}; cols=${dims#* }; rows=$((rows-3))
  for f in "${SEL[@]}"; do
    say "--- Vista previa: $(basename "$f" .tbn) (se ajusta al tamano de cada consola) ---" "--- Preview: $(basename "$f" .tbn) (it adapts to each console size) ---"
    [ "${TERM:-}" = linux ] && PAL_DIRTY=1
    eng render "$f" --mode auto --cols "$cols" --rows "$rows" --conf "$TMP/preview.conf"
    if [ "${#SEL[@]}" -gt 1 ] && have_tty && [ "$ASSUME_YES" = 0 ]; then readline "Enter para continuar" "Press Enter to continue" || true; fi
    [ "${TERM:-}" = linux ] && printf '\033]R'
  done
}

# ---------------------------------------------------------------- install
migrate_old() {
  local old=0 f
  for f in "$R/usr/local/bin/lion-banner" "$R/etc/systemd/system/getty@tty1.service.d/lion.conf" "$R/etc/profile.d/lion-restore.sh" "$R/etc/default/lion-banner"; do [ -e "$f" ] && old=1; done
  [ "$old" = 1 ] || return 0
  say "Se detecto una instalacion anterior (instalar-leon.sh)." "A previous install (instalar-leon.sh) was detected."
  confirm "Quitarla antes de continuar? (necesario)" "Remove it first? (required)" y || die "Cancelado." "Cancelled."
  [ -x "$R/usr/local/bin/lion-restore" ] && [ -z "$R" ] && "$R/usr/local/bin/lion-restore" 2>/dev/null
  rm -f "$R/usr/local/bin/lion-banner" "$R/usr/local/bin/lion-restore" "$R/etc/profile.d/lion-restore.sh" "$R/etc/default/lion-banner" "$R/etc/systemd/system/getty@tty1.service.d/lion.conf"
  rm -rf "$R/usr/local/share/lion"; rmdir "$R/etc/systemd/system/getty@tty1.service.d" 2>/dev/null
  sctl unmask pvebanner.service 2>/dev/null; sctl daemon-reload; sctl start pvebanner.service 2>/dev/null
  return 0
}
ensure_fonts() {
  local f dims w h area
  f=$(eng font-info "$FONT_OPT")
  dims=${f##* }; w=${dims%x*}; h=${dims#*x}; area=999
  case "$f" in none) ;; *) case "$w$h" in *[!0-9]*|"") ;; *) area=$((w*h));; esac;; esac
  if { [ "$f" = none ] || [ "$area" -gt 80 ]; } && [ "$FONT_OPT" = auto ] && [ "$NO_DEPS" = 0 ] && [ "$(id -u)" = 0 ]; then
    if confirm "Mas detalle: no hay una fuente de consola pequena (se encontro: $f). Instalar paquetes de fuentes Terminus?" "More detail: no small console font available (found: $f). Install Terminus font packages?" y; then pkg_install fonts; f=$(eng font-info "$FONT_OPT"); fi
  fi
  if [ "$f" = none ]; then [ "$FONT_OPT" = none ] || warn "Sin fuente pequena: el banner se adaptara a la fuente actual (menos detalle)." "No small font: the banner will adapt to the current font (less detail)."; FONT_OPT=none
  else say "Fuente de consola: $f" "Console font: $f"; fi
}
ssh_enable() {
  local sc="$R/etc/ssh/sshd_config" mode=""
  [ -f "$sc" ] || { warn "No existe $sc; se omite el banner SSH." "No $sc; skipping SSH banner."; return 1; }
  backup_file "$R/etc/issue.net" issue.net; prep_target "$R/etc/issue.net"
  if grep -qiE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$sc" && [ -d "$R/etc/ssh/sshd_config.d" ]; then
    printf '# tty-banner\nBanner /etc/issue.net\n' >"$R/etc/ssh/sshd_config.d/00-tty-banner.conf"; mode=dropin
  else
    cp -a "$sc" "$BK/sshd_config.orig" 2>/dev/null
    { printf '# BEGIN tty-banner\nBanner /etc/issue.net\n# END tty-banner\n'; cat "$sc"; } >"$TMP/sshd_new" && cat "$TMP/sshd_new" >"$sc"; mode=append
  fi
  if [ -z "${TTYB_NO_SYSTEMD:-}" ] && command -v sshd >/dev/null 2>&1 && ! sshd -t 2>/dev/null; then
    warn "sshd -t fallo; se revierte el cambio SSH." "sshd -t failed; reverting the SSH change."
    ssh_disable_cfg "$mode"; return 1
  fi
  echo "ssh_mode=$mode" >>"$STATE/state"
  sctl reload sshd.service 2>/dev/null || sctl reload ssh.service 2>/dev/null || true
  return 0
}
ssh_disable_cfg() {
  case "$1" in
    dropin) rm -f "$R/etc/ssh/sshd_config.d/00-tty-banner.conf";;
    append) sed -i '/^# BEGIN tty-banner$/,/^# END tty-banner$/d' "$R/etc/ssh/sshd_config";;
  esac
}
do_install() {
  need_root; need_systemd; migrate_old
  ensure_fonts
  mkdir -p "$STATE" "$BK" "$LIB" "$SHARE/banners"
  backup_file "$R/etc/issue" issue
  analyze_original
  # rotation / selection
  SEL=("${TBNS[@]}"); local rotate=0
  if [ "${#SEL[@]}" -gt 1 ]; then
    if [ "$FLAG_ROTATE" = 1 ]; then rotate=1
    elif [ -z "$FLAG_ROTATE" ] && confirm "Hay ${#SEL[@]} banners. Rotarlos al azar en cada inicio de consola?" "There are ${#SEL[@]} banners. Rotate randomly at every console start?" n; then rotate=1; fi
    if [ "$rotate" = 0 ]; then
      local pick=1 i=0 f
      if have_tty && [ "$ASSUME_YES" = 0 ]; then
        say "Cual usar?" "Which one to use?"; for f in "${SEL[@]}"; do i=$((i+1)); printf '  %d) %s\n' "$i" "$(basename "$f" .tbn)"; done
        readline "Numero [1]:" "Number [1]:"; case "$REPLY" in ''|*[!0-9]*) ;; *) [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#SEL[@]}" ] && pick=$REPLY;; esac
      fi
      SEL=("${SEL[$((pick-1))]}")
    fi
  elif [ "$FLAG_ROTATE" = 1 ]; then warn "Solo hay un banner: no hay nada que rotar." "Only one banner: nothing to rotate."; fi
  local ssh=0 motd=0
  if [ "$FLAG_SSH" = 1 ]; then ssh=1; elif [ -z "$FLAG_SSH" ] && confirm "Usar tambien el banner como aviso previo al login SSH (sin color)?" "Also use the banner as pre-login SSH banner (no color)?" n; then ssh=1; fi
  if [ "$FLAG_MOTD" = 1 ]; then motd=1; elif [ -z "$FLAG_MOTD" ] && confirm "Usar tambien el banner como MOTD (mensaje tras iniciar sesion, a color)?" "Also use the banner as MOTD (message after login, colored)?" n; then motd=1; fi
  # preview + confirmation
  if [ "$ASSUME_YES" = 0 ] && have_tty && confirm "Ver vista previa antes de aplicar?" "Preview before applying?" y; then preview_all; fi
  confirm "Aplicar el banner ahora?" "Apply the banner now?" y || die "Cancelado; no se modifico nada." "Cancelled; nothing was changed."
  # write files
  engine_src >"$LIB/engine.py"; chmod 644 "$LIB/engine.py"
  cat >"$LIB/restore.sh" <<'EOF'
#!/bin/sh
# tty-banner: restore console font and palette at login
t=${1##*/}; rd=/run/tty-banner
[ -f "$rd/$t.active" ] || exit 0
printf '\033]R\033[0m' >"/dev/$t"
if [ -f "$rd/$t.fnt" ]; then
  if [ -f "$rd/$t.umap" ]; then setfont -C "/dev/$t" "$rd/$t.fnt" -u "$rd/$t.umap" >/dev/null 2>&1 || setfont -C "/dev/$t" "$rd/$t.fnt" >/dev/null 2>&1
  else setfont -C "/dev/$t" "$rd/$t.fnt" >/dev/null 2>&1; fi
else setfont -C "/dev/$t" >/dev/null 2>&1; fi
rm -f "$rd/$t.active"
printf '\033[H\033[2J' >"/dev/$t"
if grep -qs '^MOTD="1"' /etc/tty-banner.conf && [ -r /etc/motd ]; then cat /etc/motd; fi
EOF
  chmod 755 "$LIB/restore.sh"
  mkdir -p "$R/etc/profile.d"
  cat >"$R/etc/profile.d/tty-banner.sh" <<'EOF'
# tty-banner: restore console font/palette on login (virtual consoles only)
case "$(tty 2>/dev/null)" in
  /dev/tty[0-9]*) [ -x /usr/local/lib/tty-banner/restore.sh ] && /usr/local/lib/tty-banner/restore.sh "$(tty)" ;;
esac
EOF
  rm -f "$SHARE"/banners/*.tbn; cp "${SEL[@]}" "$SHARE/banners/"; rm -rf "$STATE/last" "$STATE/cache"
  # reinstall over an existing install: undo features that are no longer requested, keep records
  local prev_ssh="" prev_mask=0
  if [ -e "$STATE/state" ]; then
    prev_ssh=$(sed -n 's/^ssh_mode=//p' "$STATE/state" | tail -1)
    grep -q '^pvebanner_masked=1' "$STATE/state" && prev_mask=1
  fi
  [ -n "$prev_ssh" ] && ssh_disable_cfg "$prev_ssh"
  [ "$ssh" = 0 ] && restore_backup issue.net
  [ "$motd" = 0 ] && restore_backup motd
  : >"$STATE/state"
  [ "$prev_mask" = 1 ] && { sctl mask pvebanner.service; echo "pvebanner_masked=1" >>"$STATE/state"; }
  {
    printf '# tty-banner configuration (managed by tty-banner.sh)\nTTYS="%s"\nFONT="%s"\nROTATE="%s"\nSSH="%s"\nMOTD="%s"\n' "$TTYS" "$FONT_OPT" "$rotate" "$ssh" "$motd"
    printf 'SSH_COLS="80"\nMOTD_COLS="80"\nREMOTE_MAXROWS="40"\n'
    write_info_conf
  } >"$CONF"
  local t
  for t in $TTYS; do
    mkdir -p "$R/etc/systemd/system/getty@tty$t.service.d"
    printf '[Service]\nExecStartPre=-%s /usr/local/lib/tty-banner/engine.py apply --tty tty%s\n' "$PY" "$t" >"$R/etc/systemd/system/getty@tty$t.service.d/tty-banner.conf"
  done
  if [ "$prev_mask" = 0 ] && { sctl cat pvebanner.service >/dev/null 2>&1 || [ -e "$R/lib/systemd/system/pvebanner.service" ] || [ -e "$R/usr/lib/systemd/system/pvebanner.service" ]; }; then
    sctl mask pvebanner.service && echo "pvebanner_masked=1" >>"$STATE/state"
  fi
  [ "$ssh" = 1 ] && ! ssh_enable && sed -i 's/^SSH="1"/SSH="0"/' "$CONF"
  if [ "$motd" = 1 ]; then backup_file "$R/etc/motd" motd; prep_target "$R/etc/motd"; fi
  [ "$ssh" = 1 ] && prep_target "$R/etc/issue.net"
  prep_target "$R/etc/issue"
  sctl daemon-reload
  TTYB_NO_FONT=1 eng_installed_apply
  say "" ""; say "Listo. Instalado en $LIB" "Done. Installed in $LIB"
  say "  Se vera en la proxima vez que arranque la consola (reinicio, o: systemctl restart getty@tty${TTYS%% *})." "  You will see it the next time the console starts (reboot, or: systemctl restart getty@tty${TTYS%% *})."
  say "  Desinstalar: bash $PROG --uninstall" "  Uninstall: bash $PROG --uninstall"
  if [ -z "$R" ] && confirm "Reiniciar getty@tty${TTYS%% *} ahora para verlo? (cierra la sesion de esa consola)" "Restart getty@tty${TTYS%% *} now to see it? (closes that console's session)" n; then sctl restart "getty@tty${TTYS%% *}.service"; fi
}
eng_installed_apply() { "$PY" "$LIB/engine.py" apply --tty "tty${TTYS%% *}" --remote-only; }

# ---------------------------------------------------------------- uninstall
do_uninstall() {
  need_root; need_systemd
  [ -d "$STATE" ] || [ -e "$CONF" ] || { say "tty-banner no esta instalado." "tty-banner is not installed."; return 0; }
  confirm "Desinstalar tty-banner y restaurar los archivos originales?" "Uninstall tty-banner and restore the original files?" y || die "Cancelado." "Cancelled."
  local ttys="1" t f name
  [ -e "$CONF" ] && ttys=$(sed -n 's/^TTYS="\(.*\)"/\1/p' "$CONF")
  [ -n "$ttys" ] || ttys="1"
  for t in $ttys; do [ -x "$LIB/restore.sh" ] && [ -z "$R" ] && "$LIB/restore.sh" "tty$t" 2>/dev/null; done
  for f in "$R"/etc/systemd/system/getty@tty*.service.d/tty-banner.conf; do [ -e "$f" ] && { rm -f "$f"; rmdir "$(dirname "$f")" 2>/dev/null; }; done
  rm -f "$R/etc/profile.d/tty-banner.sh"
  for name in issue issue.net motd; do
    if [ -e "$BK/$name.orig" ] || [ -L "$BK/$name.orig" ]; then rm -f "$R/etc/$name"; cp -a "$BK/$name.orig" "$R/etc/$name"
    elif [ -e "$BK/$name.absent" ]; then rm -f "$R/etc/$name"; fi
  done
  if [ -e "$STATE/state" ]; then
    local mode; mode=$(sed -n 's/^ssh_mode=//p' "$STATE/state" | tail -1)
    [ -n "$mode" ] && { ssh_disable_cfg "$mode"; sctl reload sshd.service 2>/dev/null || sctl reload ssh.service 2>/dev/null || true; }
    if grep -q '^pvebanner_masked=1' "$STATE/state"; then sctl unmask pvebanner.service; sctl start pvebanner.service 2>/dev/null || true; fi
  fi
  rm -rf "$LIB" "$SHARE" "$STATE" "$CONF" "$R/run/tty-banner"
  sctl daemon-reload
  say "Desinstalado. Todo quedo como estaba (reinicia la consola con: systemctl restart getty@tty1)." "Uninstalled. Everything is back as it was (restart the console with: systemctl restart getty@tty1)."
}

# ---------------------------------------------------------------- main
main() {
  local a args=()
  for a in "$@"; do case "$a" in --*=*) args+=("${a%%=*}" "${a#*=}");; *) args+=("$a");; esac; done
  set -- "${args[@]+"${args[@]}"}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --help-es) help_es; exit 0;; --help-en) help_en; exit 0;;
      -h|--help) if [ "$LANG_UI" = es ]; then help_es; else help_en; fi; exit 0;;
      -v|--version) echo "tty-banner $VERSION"; exit 0;;
      --lang) LANG_UI="${2:-en}"; shift;;
      --uninstall) MODE=uninstall;; --preview) PREVIEW_ONLY=1;; --diagnose) MODE=diagnose;;
      --local) SRC=local; LOCAL_PATH="${2:-}"; shift;;
      --repo) SRC=repo; if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then REPO_SEL="$2"; shift; fi;;
      --repo-url) REPO_SPEC="${2:-}"; shift;;
      --font) FONT_OPT="${2:-auto}"; shift;; --no-font) FONT_OPT=none;;
      --ttys) TTYS="${2:-1}"; shift;;
      --fill) FILL_OPT="${2:-ascii}"; shift;;
      --info) INFO_OPT="${2:-auto}"; shift;;
      --rotate) FLAG_ROTATE=1;; --no-rotate) FLAG_ROTATE=0;;
      --ssh) FLAG_SSH=1;; --no-ssh) FLAG_SSH=0;; --motd) FLAG_MOTD=1;; --no-motd) FLAG_MOTD=0;;
      --no-deps) NO_DEPS=1;; -y|--yes) ASSUME_YES=1;;
      *) die "Opcion desconocida: $1 (usa --help-es)" "Unknown option: $1 (use --help-en)";;
    esac; shift
  done
  case "$LANG_UI" in es|en) ;; *) LANG_UI=en;; esac
  case "$FILL_OPT" in ascii|bg) ;; *) die "--fill debe ser ascii o bg." "--fill must be ascii or bg.";; esac
  if [ "$MODE" = uninstall ]; then ensure_python; extract_engine; do_uninstall; return; fi
  if [ "$MODE" = diagnose ]; then ensure_python; extract_engine; eng diagnose; return; fi
  [ "$PREVIEW_ONLY" = 1 ] || need_root
  ensure_python; extract_engine
  pick_source; convert_all
  if [ "$PREVIEW_ONLY" = 1 ]; then SEL=("${TBNS[@]}"); analyze_original; preview_all; return; fi
  do_install
}

engine_src() { cat <<'__TTYB_ENGINE_EOF__'
#!/usr/bin/env python3
# tty-banner engine: convert images -> .tbn, render banners, apply them at getty start.
import math, unicodedata, os, sys, re, zlib, gzip, struct, random, socket, subprocess, glob, hashlib, urllib.request, urllib.error, urllib.parse, json

ROOT = os.environ.get("TTYB_ROOT", "")
def P(p): return ROOT + p
CONF_PATH = os.environ.get("TTYB_CONF") or P("/etc/tty-banner.conf")
BGSLOTS = [1, 2, 3, 4, 5, 6]            # VT slots usable as background (slot 0 = black, 7/15 stay for text)
FGSLOTS = [8, 9, 10, 11, 12, 13, 14]    # foreground-only slots
NCOLORS = len(BGSLOTS) + len(FGSLOTS)
RAMP = " .-',:~;^*+=/?|<[}%$&#@"   # printable ASCII symbols only (no letters, no backslash), ordered by ink density
MAXDIM = 960
MAGIC = b"TTYB2"
EXTS = (".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".tif", ".tiff")
FONT_DIRS = ["/usr/share/consolefonts", "/usr/lib/kbd/consolefonts", "/usr/share/kbd/consolefonts", "/lib/kbd/consolefonts"]
FONT_PREF = ["Lat15-Terminus12x6", "ter-v12n", "ter-u12n", "Lat15-Terminus14", "ter-v14n", "lat0-12", "Lat15-Terminus16", "ter-v16n"]
MAXDL = 10 * 1024 * 1024


def die(msg, code=1):
    sys.stderr.write("tty-banner: %s\n" % msg)
    sys.exit(code)

# ---------------------------------------------------------------- image loading
def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else (b if pb <= pc else c)


def decode_png(path):
    d = open(path, "rb").read()
    if d[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("without Pillow only PNG files are supported")
    pos, idat, plte, trns, hdr = 8, [], None, None, None
    while pos + 8 <= len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        typ, body = d[pos + 4:pos + 8], d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR": hdr = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE": plte = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif typ == b"tRNS": trns = body
        elif typ == b"IDAT": idat.append(body)
        elif typ == b"IEND": break
    w, h, bd, ct, _, _, il = hdr
    if il:
        raise ValueError("interlaced PNG needs Pillow (python3-pil)")
    raw = zlib.decompress(b"".join(idat))
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    bits = ch * bd
    bpp, stride, maxv = max(1, bits // 8), (w * bits + 7) // 8, (1 << bd) - 1
    out, prev, p = [], bytearray(stride), 0
    for y in range(h):
        ft = raw[p]
        ln = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if ft == 1:
            for i in range(bpp, stride): ln[i] = (ln[i] + ln[i - bpp]) & 255
        elif ft == 2:
            for i in range(stride): ln[i] = (ln[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(stride):
                l = ln[i - bpp] if i >= bpp else 0
                ln[i] = (ln[i] + ((l + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                l = ln[i - bpp] if i >= bpp else 0
                ul = prev[i - bpp] if i >= bpp else 0
                ln[i] = (ln[i] + paeth(l, prev[i], ul)) & 255
        prev = ln
        if bd == 8: s = list(ln)
        elif bd == 16: s = list(ln[0::2])
        else:
            s, per = [], 8 // bd
            for byte in ln:
                for k in range(per): s.append((byte >> (8 - bd * (k + 1))) & maxv)
        s = s[:w * ch]
        if ct == 2: out.extend((s[i], s[i + 1], s[i + 2], 255) for i in range(0, w * 3, 3))
        elif ct == 6: out.extend(tuple(s[i:i + 4]) for i in range(0, w * 4, 4))
        elif ct == 0:
            sc = 255 // maxv if bd < 8 else 1
            out.extend((v * sc, v * sc, v * sc, 255) for v in s)
        elif ct == 4: out.extend((s[i], s[i], s[i], s[i + 1]) for i in range(0, w * 2, 2))
        else:
            tr = trns or b""
            out.extend(plte[v] + ((tr[v] if v < len(tr) else 255),) for v in s)
    return w, h, out


def box_down(w, h, px, f):
    w2, h2 = w // f, h // f
    out = []
    n = f * f
    for y in range(h2):
        for x in range(w2):
            r = g = b = a = 0
            for yy in range(y * f, y * f + f):
                o = yy * w + x * f
                for p in px[o:o + f]:
                    r += p[0]; g += p[1]; b += p[2]; a += p[3]
            out.append((r // n, g // n, b // n, a // n))
    return w2, h2, out


def load_image(path):
    Image = None
    if not os.environ.get("TTYB_NO_PIL"):
        try:
            from PIL import Image
        except ImportError:
            Image = None
    if Image:
        im = Image.open(path)
        im = im.convert("RGBA")
        w, h = im.size
        if max(w, h) > MAXDIM:
            s = MAXDIM / float(max(w, h))
            im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
        w, h = im.size
        raw = im.tobytes()
        return w, h, [(raw[i], raw[i + 1], raw[i + 2], raw[i + 3]) for i in range(0, len(raw), 4)]
    w, h, px = decode_png(path)
    f = -(-max(w, h) // MAXDIM)
    if f > 1:
        w, h, px = box_down(w, h, px, f)
    return w, h, px

# ---------------------------------------------------------------- palette / convert
def dist(a, b):
    rm = (a[0] + b[0]) * 0.5
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return (2.0 + rm / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rm) / 256.0) * db * db


def find_non_transition(px, mask, w, h, x0, y0, x1, y1):
    """Ignore edge/anti-aliased transition pixels while preserving solid details, outlines, and smooth gradients."""
    keep = bytearray(mask)
    if (x1 - x0) < 24 or (y1 - y0) < 24:
        return keep
    for y in range(y0, y1):
        row = y * w
        ym1 = (y - 1) * w if y > 0 else row
        yp1 = (y + 1) * w if y + 1 < h else row
        for x in range(x0, x1):
            i = row + x
            if not mask[i]:
                continue
            p = px[i]
            if p[3] < 220:
                keep[i] = 0
                continue
            xm1 = x - 1 if x > 0 else x
            xp1 = x + 1 if x + 1 < w else x
            is_trans = False
            for ia, ib in ((row + xm1, row + xp1), (ym1 + x, yp1 + x)):
                a, b = px[ia], px[ib]
                if a[3] < 64 or b[3] < 64:
                    continue
                if abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]) <= 64:
                    continue
                dr, dg, db = b[0] - a[0], b[1] - a[1], b[2] - a[2]
                len2 = dr * dr + dg * dg + db * db
                if len2 < 4800:
                    continue
                pr, pg, pb = p[0] - a[0], p[1] - a[1], p[2] - a[2]
                t = (pr * dr + pg * dg + pb * db) / float(len2)
                if 0.12 < t < 0.88:
                    qr, qg, qb = pr - t * dr, pg - t * dg, pb - t * db
                    if qr * qr + qg * qg + qb * qb <= min(900.0, 0.12 * len2):
                        is_trans = True
                        break
            if is_trans:
                keep[i] = 0
    return keep


def extract_tile_modes(cnt, merge_dist=900.0):
    """Group non-transition pixels in one area around its local base color modes without diluting small details."""
    items = sorted(cnt.items(), key=lambda kv: -kv[1])
    modes = []
    for kk, n in items:
        c = (kk[0] * 4 + 2.0, kk[1] * 4 + 2.0, kk[2] * 4 + 2.0)
        best_j, best_d = -1, merge_dist
        for j, m in enumerate(modes):
            mc = (m[0] / m[3], m[1] / m[3], m[2] / m[3])
            d = dist(c, mc)
            if d < best_d:
                best_d, best_j = d, j
        if best_j >= 0:
            m = modes[best_j]
            m[0] += c[0] * n; m[1] += c[1] * n; m[2] += c[2] * n; m[3] += n
        else:
            modes.append([c[0] * n, c[1] * n, c[2] * n, float(n)])
    return [((m[0] / m[3], m[1] / m[3], m[2] / m[3]), m[3]) for m in modes]


def make_palette_by_area(px, mask, w, h, x0, y0, x1, y1, k):
    """Identify base colors area by area (ignoring transition pixels) and preserve distinct detail colors."""
    keep = find_non_transition(px, mask, w, h, x0, y0, x1, y1)
    fw, fh = x1 - x0, y1 - y0
    gx = max(1, min(8, fw // 4 or 1))
    gy = max(1, min(8, fh // 4 or 1))
    step = 2 if (fw * fh > 450000) else 1
    area_modes = []
    for ty in range(gy):
        ya = y0 + (ty * fh) // gy
        yb = y0 + ((ty + 1) * fh) // gy
        if yb <= ya:
            continue
        for tx in range(gx):
            xa = x0 + (tx * fw) // gx
            xb = x0 + ((tx + 1) * fw) // gx
            if xb <= xa:
                continue
            cnt, nfg = {}, 0
            for y in range(ya, yb, step):
                row_off = y * w
                for x in range(xa, xb, step):
                    i = row_off + x
                    if keep[i]:
                        p = px[i]
                        key = (p[0] >> 2, p[1] >> 2, p[2] >> 2)
                        cnt[key] = cnt.get(key, 0) + 1
                        nfg += 1
            if not nfg:
                continue
            for col, bw in extract_tile_modes(cnt, merge_dist=900.0):
                if nfg >= 10 and bw < 2.0:
                    continue
                area_modes.append((col, bw))
    if not area_modes:
        fg_cnt = {}
        for i, m in enumerate(mask):
            if m:
                p = px[i]
                key = (p[0] >> 2, p[1] >> 2, p[2] >> 2)
                fg_cnt[key] = fg_cnt.get(key, 0) + 1
        area_modes = [((kk[0] * 4 + 2.0, kk[1] * 4 + 2.0, kk[2] * 4 + 2.0), float(n)) for kk, n in fg_cnt.items()]
    area_modes.sort(key=lambda it: -it[1])
    clusters = []
    for col, bw in area_modes:
        best_j, best_d = -1, 400.0
        for j, cl in enumerate(clusters):
            mc = (cl[0] / cl[3], cl[1] / cl[3], cl[2] / cl[3])
            d = dist(col, mc)
            if d < best_d:
                best_d, best_j = d, j
        if best_j >= 0:
            cl = clusters[best_j]
            cl[0] += col[0] * bw; cl[1] += col[1] * bw; cl[2] += col[2] * bw; cl[3] += bw
        else:
            clusters.append([col[0] * bw, col[1] * bw, col[2] * bw, bw])
    cands = [((cl[0] / cl[3], cl[1] / cl[3], cl[2] / cl[3]), cl[3]) for cl in clusters]
    if len(cands) <= k:
        return [tuple(max(0, min(255, int(round(v)))) for v in c) for c, _ in cands]
    # Diversity-first selection: distinct detail colors beat minor variations of large zones
    first_idx = max(range(len(cands)), key=lambda idx: cands[idx][1])
    cen = [cands[first_idx][0]]
    min_d = [dist(c, cen[0]) for c, _ in cands]
    while len(cen) < k:
        best_i, best_score = None, -1.0
        for idx, (c, wt) in enumerate(cands):
            if min_d[idx] <= 0.0:
                continue
            score = min_d[idx] * (wt ** 0.10)
            if score > best_score:
                best_score, best_i = score, idx
        if best_i is None:
            break
        nc = cands[best_i][0]
        cen.append(nc)
        for idx, (c, _) in enumerate(cands):
            d = dist(c, nc)
            if d < min_d[idx]:
                min_d[idx] = d
    for _ in range(4):                       # Log-weighted Lloyd refinement keeps small details anchored
        sums = [[0.0, 0.0, 0.0, 0.0] for _ in cen]
        for c, wt in cands:
            w = math.log1p(wt)
            j = min(range(len(cen)), key=lambda x: dist(c, cen[x]))
            s = sums[j]
            s[0] += c[0] * w; s[1] += c[1] * w; s[2] += c[2] * w; s[3] += w
        cen = [(s[0] / s[3], s[1] / s[3], s[2] / s[3]) if s[3] else cen[j] for j, s in enumerate(sums)]
    return [tuple(max(0, min(255, int(round(v)))) for v in c) for c in cen]


def tone_lift(c, floor=32.0, gamma=0.82):
    """Raise black floor smoothly while preserving hue and monotonic tonal separation."""
    m = max(c)
    if m <= 0:
        v = int(round(floor))
        return (v, v, v)
    m_new = floor + (255.0 - floor) * ((m / 255.0) ** gamma)
    k = m_new / float(m)
    return tuple(min(255, int(round(v * k))) for v in c)


def lum_of(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def convert(src, dst, thr=14, K=NCOLORS):
    w, h, px = load_image(src)
    border = []
    for x in range(w): border += [px[x], px[(h - 1) * w + x]]
    for y in range(h): border += [px[y * w], px[y * w + w - 1]]
    opq = [p for p in border if p[3] >= 64]
    bg = None if len(opq) < len(border) * 0.5 else tuple(sorted(p[c] for p in opq)[len(opq) // 2] for c in range(3))
    # background = transparent or bg-colored pixels connected to the image border (interior look-alikes are kept)
    like = bytearray(w * h)
    for i, p in enumerate(px):
        if p[3] < 64 or (bg is not None and max(abs(p[0] - bg[0]), abs(p[1] - bg[1]), abs(p[2] - bg[2])) <= thr): like[i] = 1
    isbg = bytearray(w * h)
    stack = []
    for x in range(w): stack += [x, (h - 1) * w + x]
    for y in range(h): stack += [y * w, y * w + w - 1]
    while stack:
        i = stack.pop()
        if isbg[i] or not like[i]: continue
        isbg[i] = 1
        x = i % w
        if x > 0: stack.append(i - 1)
        if x < w - 1: stack.append(i + 1)
        if i >= w: stack.append(i - w)
        if i < w * (h - 1): stack.append(i + w)
    mask = [not (isbg[i] or px[i][3] < 64) for i in range(w * h)]
    y0, y1, x0, x1 = h, 0, w, 0
    for y in range(h):
        row = mask[y * w:(y + 1) * w]
        if any(row):
            if y < y0: y0 = y
            y1 = y + 1
            lx = row.index(True)
            rx = w - row[::-1].index(True)
            if lx < x0: x0 = lx
            if rx > x1: x1 = rx
    if y0 >= y1: die("no content found besides the background: %s" % src)
    pal = make_palette_by_area(px, mask, w, h, x0, y0, x1, y1, K)
    cache, plane = {}, bytearray(w * h)
    for i, (p, m) in enumerate(zip(px, mask)):
        if not m: continue
        key = (p[0] >> 2, p[1] >> 2, p[2] >> 2)
        v = cache.get(key)
        if v is None:
            v = cache[key] = min(range(len(pal)), key=lambda j: dist(p, pal[j])) + 1
        plane[i] = v
    rows = [plane[y * w:(y + 1) * w] for y in range(h)]
    crop = b"".join(bytes(rows[y][x0:x1]) for y in range(y0, y1))
    data = MAGIC + struct.pack("<HHB", x1 - x0, y1 - y0, len(pal)) + b"".join(bytes(c) for c in pal) + zlib.compress(crop, 9)
    open(dst, "wb").write(data)
    return x1 - x0, y1 - y0, len(pal)


def load_tbn(path):
    d = open(path, "rb").read()
    if d[:5] == b"TTYB1": die("old banner format; reinstall with the new tty-banner.sh")
    if d[:5] != MAGIC: die("not a .tbn file: %s" % path)
    w, h, k = struct.unpack("<HHB", d[5:10])
    o = 10
    pal = [tuple(d[o + 3 * i:o + 3 * i + 3]) for i in range(k)]
    plane = zlib.decompress(d[o + 3 * k:])
    return w, h, pal, plane


def render_cells(tbn, H, W):
    w, h, pal, plane = tbn
    lum = [lum_of(c) for c in pal]
    lmax = float(max(max(lum), 60))
    xi = [x * W // w for x in range(w)]
    cx, ry = [0] * W, [0] * H
    for x in range(w): cx[xi[x]] += 1
    for y in range(h): ry[y * H // h] += 1
    fgc, cc = [0] * (W * H), {}
    for y in range(h):
        row = plane[y * w:(y + 1) * w]
        if not any(row): continue
        base = (y * H // h) * W
        for x, v in enumerate(row):
            if v:
                c = base + xi[x]
                fgc[c] += 1
                cc[(c, v)] = cc.get((c, v), 0) + 1
    best, bn = {}, {}
    for (c, v), n in cc.items():
        if n > bn.get(c, 0): bn[c], best[c] = n, v
    rows = []
    for r in range(H):
        line = []
        for c in range(W):
            i = r * W + c
            n = fgc[i]
            if not n:
                line.append((" ", 0, False)); continue
            cov = n / float(ry[r] * cx[c])
            v = best[i]
            nr = len(RAMP) - 1
            if cov >= 0.85:
                lo = int(0.65 * nr)
                idx = lo + int(min(1.0, (lum[v - 1] / lmax) ** 0.6) * (nr - lo) + 0.5); solid = True
            else:
                idx = max(1, int((cov ** 0.7) * nr + 0.5)); solid = False
            line.append((RAMP[min(len(RAMP) - 1, idx)], v, solid))
        rows.append(line)
    return rows


class Style:
    """Maps palette entries to terminal colors for each output mode."""
    def __init__(self, pal, plane, mode, fill="ascii"):
        self.pal, self.mode, self.fill = pal, mode, fill
        k = len(pal)
        lum = [lum_of(c) for c in pal]
        self.col = [tone_lift(c) for c in pal]   # glyph-only colors: preserve hue and tonal differences above black floor
        if mode == "tty":
            order = sorted(range(k), key=lambda i: -plane.count(bytes([i + 1])))
            self.slot = {}
            for rank, i in enumerate(order):
                self.slot[i] = BGSLOTS[rank] if rank < len(BGSLOTS) else FGSLOTS[rank - len(BGSLOTS)]
            self.glyph, self.solid_fg = {}, {}
            for i in range(k if fill == "bg" else 0):
                if lum[i] >= 35 or max(pal[i]) >= 60:
                    self.glyph[i] = self.slot[i]
                else:
                    c = [j for j in range(k) if j != i and (lum[j] >= 35 or max(pal[j]) >= 60) and dist(pal[i], pal[j]) < 12000]
                    self.glyph[i] = self.slot[min(c, key=lambda j: dist(tone_lift(pal[i]), pal[j]))] if c else self.slot[i]
                t = tuple(min(255, int(v * 1.25 + 25)) for v in pal[i])
                c = [j for j in range(k) if j != i and lum[j] > lum[i] + 15 and dist(t, pal[j]) < 9000]
                self.solid_fg[i] = self.slot[min(c, key=lambda j: dist(t, pal[j]))] if c else self.slot[i]

    def rgb(self, i):
        return self.pal[i] if self.fill == "bg" else self.col[i]

    def key(self, i, solid):
        if self.fill != "bg":
            return (self.slot[i] if self.mode == "tty" else self.col[i], None)
        if self.mode == "tty":
            if solid and self.slot[i] in BGSLOTS: return (self.solid_fg[i], self.slot[i])
            return (self.glyph[i], None)
        c = self.pal[i]
        if solid: return (tuple(min(255, int(v * 1.25 + 25)) for v in c), c)
        return (tone_lift(c), None)

    def seq(self, key):
        fg, bg = key
        if self.mode == "tty":
            s = "\033[0;" + ("3%d" % fg if fg < 8 else "1;3%d" % (fg - 8))
            return s + (";4%d" % bg if bg else "") + "m"
        s = "\033[0;38;2;%d;%d;%d" % fg
        return s + (";48;2;%d;%d;%d" % bg if bg else "") + "m"


def emit(cells, style, pad):
    out = []
    for row in cells:
        last = max([i for i, c in enumerate(row) if c[0] != " "] or [-1])
        if last < 0:
            out.append(""); continue
        s, cur = [" " * pad], None
        for ch, v, solid in row[:last + 1]:
            if style.mode == "plain":
                s.append(ch); continue
            if ch == " ":
                if cur is not None and cur[1] is not None: s.append("\033[0m"); cur = None
                s.append(ch); continue
            k = style.key(v - 1, solid)
            if k != cur: s.append(style.seq(k)); cur = k
            s.append(ch)
        if style.mode != "plain": s.append("\033[0m")
        out.append("".join(s))
    return out


def art_lines(path, tbn, mode, H, W, pad, fill):
    key = hashlib.md5(("%s|%s|%d|%d|%d|%d|%s|%s|v2" % (os.path.basename(path), os.path.getmtime(path), os.path.getsize(path), H, W, pad, fill, RAMP)).encode()).hexdigest()
    cf = P("/var/lib/tty-banner/cache/%s.%s" % (key, mode))
    try:
        return open(cf).read().split("\n")
    except OSError:
        pass
    style = Style(tbn[2], tbn[3], mode, fill)
    lines = emit(render_cells(tbn, H, W), style, pad)
    try:
        os.makedirs(os.path.dirname(cf), exist_ok=True)
        open(cf, "w").write("\n".join(lines))
    except OSError:
        pass
    return lines


def build(tbn_path, mode, cols, rows, aspect, info, maxrows=None, fill="ascii"):
    tbn = load_tbn(tbn_path)
    w, h, pal = tbn[0], tbn[1], tbn[2]
    H = max(6, rows - (len(info) + 4))
    if maxrows: H = min(H, maxrows)
    W = int(round(H * w / float(h) * aspect))
    if W > cols - 2:
        W = max(8, cols - 2)
        H = max(4, int(round(W * h / float(w) / aspect)))
    lines = art_lines(tbn_path, tbn, mode, H, W, max(0, (cols - W) // 2), fill)
    out = list(lines)
    if mode == "tty" and out:
        st = Style(pal, tbn[3], "tty", fill)
        out[0] = "".join("\033]P%x%02x%02x%02x" % ((st.slot[i],) + tuple(st.rgb(i))) for i in range(len(pal))) + out[0]
    out.append("")
    for t in info:
        out.append(" " * max(0, (cols - len(t)) // 2) + t)
    if info: out.append("")
    return re.sub(r"[^\x20-\x7e\n\x1b]", "", "\n".join(out) + "\n")   # safety net: printable ASCII (+ESC color codes) only

# ---------------------------------------------------------------- config / info
def load_conf(path=None):
    c = {"FONT": "auto", "ASPECT": "2.0", "ROTATE": "0", "SSH": "0", "MOTD": "0", "INFO_IP": "0", "INFO_OS": "0",
         "INFO_HOST": "0", "URL_TPL": "", "FILL": "ascii", "SSH_COLS": "80", "MOTD_COLS": "80", "REMOTE_MAXROWS": "40"}
    try:
        for l in open(path or CONF_PATH):
            l = l.strip()
            if l and not l.startswith("#") and "=" in l:
                k, v = l.split("=", 1)
                c[k.strip()] = v.strip().strip("\"'")
    except OSError:
        pass
    return c


def os_name():
    for f in ("/etc/os-release", "/usr/lib/os-release"):
        try:
            d = {}
            for l in open(P(f)):
                if "=" in l:
                    k, v = l.strip().split("=", 1); d[k] = v.strip('"\'')
            return d.get("PRETTY_NAME") or d.get("NAME") or "Linux"
        except OSError:
            continue
    return "Linux"


def get_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("192.0.2.1", 9))
        ip = s.getsockname()[0]; s.close()
        if ip and not ip.startswith("0."): return ip
    except Exception:
        pass
    try:
        out = subprocess.check_output(["hostname", "-I"], stderr=subprocess.DEVNULL).decode().split()
        if out: return out[0]
    except Exception:
        pass
    return "(no IP)"


def info_lines(conf):
    L = []
    clean = lambda s: re.sub(r"[^\x20-\x7e]", "", unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()).replace("\\", "/")
    if conf.get("INFO_OS") == "1": L.append("OS: " + clean(os_name()))
    if conf.get("INFO_HOST") == "1": L.append("Host: " + clean(socket.gethostname()))
    if conf.get("INFO_IP") == "1":
        ip = get_ip()
        t = clean(conf.get("URL_TPL") or "")
        L.append(t.replace("{ip}", ip) if t else "IP: " + ip)
    return L


def analyze(text):
    r = {"IP": 0, "OS": 0, "HOST": 0, "URL_TPL": ""}
    m = re.search(r"([a-zA-Z][a-zA-Z0-9+.-]*://)(\d{1,3}(?:\.\d{1,3}){3})((?::\d+)?(?:/\S*)?)", text)
    if m:
        r["IP"] = 1; r["URL_TPL"] = m.group(1) + "{ip}" + m.group(3)
    elif re.search(r"\\[46]|\b\d{1,3}(?:\.\d{1,3}){3}\b", text):
        r["IP"] = 1
    names = set()
    for f in ("/etc/os-release", "/usr/lib/os-release"):
        try:
            for l in open(P(f)):
                if "=" in l:
                    k, v = l.strip().split("=", 1)
                    if k in ("NAME", "PRETTY_NAME") and len(v.strip('"\'')) > 2: names.add(v.strip('"\'').lower())
            break
        except OSError:
            continue
    low = text.lower()
    if re.search(r"\\[Ssrv]", text) or any(n in low for n in names): r["OS"] = 1
    hn = socket.gethostname()
    if re.search(r"\\n", text) or (hn and re.search(r"(?<![\w-])" + re.escape(hn) + r"(?![\w-])", text, re.I)): r["HOST"] = 1
    return r

# ---------------------------------------------------------------- fonts / tty
def find_fonts():
    fonts = {}
    for d in FONT_DIRS:
        for f in glob.glob(P(d) + "/*"):
            b = os.path.basename(f)
            m = re.match(r"(.+?)\.(psf|psfu)(\.gz)?$", b)
            if m: fonts.setdefault(m.group(1), f)
    return fonts


def font_dims(path):
    try:
        op = gzip.open if path.endswith(".gz") else open
        d = op(path, "rb").read(40)
        if d[:2] == b"\x36\x04": return 8, d[3]
        if d[:4] == b"\x72\xb5\x4a\x86":
            f = struct.unpack("<7I", d[4:32]); return f[6], f[5]
    except Exception:
        pass
    return None


def choose_font(pref):
    if pref == "none": return None
    fonts = find_fonts()
    if pref != "auto" and pref in fonts: return pref, fonts[pref]
    for n in FONT_PREF:
        if n in fonts: return n, fonts[n]
    cand = []
    for n, p in fonts.items():
        dm = font_dims(p)
        if dm and dm[0] >= 6 and dm[1] >= 12: cand.append((dm[0] * dm[1], n))
    if cand:
        n = min(cand)[1]; return n, fonts[n]
    return None


def term_size(tty):
    r, c = os.environ.get("TTYB_ROWS"), os.environ.get("TTYB_COLS")
    if r and c: return int(r), int(c)
    try:
        import fcntl, termios
        fd = os.open("/dev/" + tty, os.O_RDONLY | os.O_NOCTTY)
        rr, cc = struct.unpack("HHHH", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))[:2]
        os.close(fd)
        if rr and cc: return rr, cc
    except Exception:
        pass
    return 25, 80


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.islink(path): os.unlink(path)
    with open(path, "w") as f: f.write(text)


def banners():
    return sorted(glob.glob(P("/usr/local/share/tty-banner/banners/*.tbn")))


def pick_banner(conf):
    bl = banners()
    if not bl: die("no banners installed")
    if conf.get("ROTATE") == "1" and len(bl) > 1:
        st = P("/var/lib/tty-banner/last")
        try: last = open(st).read().strip()
        except OSError: last = ""
        ch = random.choice([b for b in bl if os.path.basename(b) != last] or bl)
        try: open(st, "w").write(os.path.basename(ch))
        except OSError: pass
        return ch
    return bl[0]


def apply(tty, remote_only=False):
    conf = load_conf()
    bn = pick_banner(conf)
    info = info_lines(conf)
    aspect = float(conf.get("ASPECT", "2.0") or 2.0)
    cf = choose_font(conf.get("FONT", "auto"))
    if cf:
        dm = font_dims(cf[1])
        if dm: aspect = dm[1] / float(dm[0])
    if not remote_only:
        rd = P("/run/tty-banner")
        os.makedirs(rd, exist_ok=True)
        if cf and not os.environ.get("TTYB_NO_FONT"):
            base = ["setfont", "-C", "/dev/" + tty]
            if not os.path.exists("%s/%s.fnt" % (rd, tty)):
                base += ["-o", "%s/%s.fnt" % (rd, tty), "-ou", "%s/%s.umap" % (rd, tty)]
            for target in (cf[0], cf[1]):
                try:
                    r = subprocess.run(base + [target], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    with open(rd + "/setfont.log", "a") as lg: lg.write("%s rc=%d %s\n" % (target, r.returncode, r.stderr.decode(errors="replace").strip()))
                    if r.returncode == 0: break
                except OSError as ex:
                    with open(rd + "/setfont.log", "a") as lg: lg.write("setfont: %s\n" % ex)
                    break
        open("%s/%s.active" % (rd, tty), "w").close()
        rows, cols = term_size(tty)
        write_text(P("/etc/issue"), build(bn, "tty", cols, rows, aspect, info, None, conf.get("FILL", "ascii")))
    mx = int(conf.get("REMOTE_MAXROWS", "40"))
    if conf.get("SSH") == "1":
        write_text(P("/etc/issue.net"), build(bn, "plain", int(conf.get("SSH_COLS", "80")), 200, 2.0, info, mx, conf.get("FILL", "ascii")))
    if conf.get("MOTD") == "1":
        write_text(P("/etc/motd"), "\n" + build(bn, "ansi", int(conf.get("MOTD_COLS", "80")), 200, 2.0, info, mx, conf.get("FILL", "ascii")))

# ---------------------------------------------------------------- network
def http_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "tty-banner"})
    host = urllib.parse.urlparse(url).hostname or ""
    tok = os.environ.get("GITHUB_TOKEN")
    if tok and (host.endswith("github.com") or host.endswith("githubusercontent.com")):
        req.add_header("Authorization", "Bearer " + tok)
    with urllib.request.urlopen(req, timeout=30) as r:
        d = r.read(MAXDL + 1)
    if len(d) > MAXDL: die("download too large")
    return d


def valid_image(d):
    return d[:8] == b"\x89PNG\r\n\x1a\n" or d[:2] == b"\xff\xd8" or d[:4] == b"GIF8" or d[:2] == b"BM" or \
        (d[:4] == b"RIFF" and d[8:12] == b"WEBP") or d[:4] in (b"II*\0", b"MM\0*")


def cmd_list_repo(owner, repo, branch, path):
    api = os.environ.get("TTYB_API", "https://api.github.com")
    url = "%s/repos/%s/%s/contents/%s?ref=%s" % (api, owner, repo, urllib.parse.quote(path), urllib.parse.quote(branch))
    try:
        data = json.loads(http_get(url).decode())
    except urllib.error.HTTPError as e:
        die("GitHub HTTP %s (%s)%s" % (e.code, e.reason, ". Rate limit? try: export GITHUB_TOKEN=..." if e.code in (403, 429) else ""), 2)
    except Exception as e:
        die("cannot reach the repository: %s" % e, 2)
    if not isinstance(data, list): die("unexpected repository answer", 2)
    for it in sorted(data, key=lambda i: i.get("name", "")):
        if it.get("type") == "file" and it.get("name", "").lower().endswith(EXTS):
            print("%s\t%s\t%s" % (it["name"], it.get("size", 0), it.get("download_url", "")))


def cmd_download(url, dest):
    try:
        d = http_get(url)
    except Exception as e:
        die("download failed: %s (%s)" % (url, e), 2)
    if not valid_image(d): die("not a supported image file: %s" % url, 3)
    open(dest, "wb").write(d)


def raw_url(owner, repo, branch, path, name):
    raw = os.environ.get("TTYB_RAW", "https://raw.githubusercontent.com")
    return "%s/%s/%s/%s/%s/%s" % (raw, owner, repo, branch, path.strip("/"), urllib.parse.quote(name))

# ---------------------------------------------------------------- main
def main(argv):
    if len(argv) < 2: die("usage: engine.py convert|render|apply|analyze-issue|font-info|list-repo|download|raw-url|has-pil ...")
    c, a = argv[1], argv[2:]
    if c == "convert":
        try:
            w, h, k = convert(a[0], a[1]); print("%dx%d %d colors" % (w, h, k))
        except SystemExit:
            raise
        except Exception as ex:
            die("%s: %s" % (a[0], ex))
    elif c == "render":
        tbn, mode, cols, rows, conf = a[0], "auto", 100, 40, None
        i = 1
        while i < len(a):
            if a[i] == "--mode": mode = a[i + 1]
            elif a[i] == "--cols": cols = int(a[i + 1])
            elif a[i] == "--rows": rows = int(a[i + 1])
            elif a[i] == "--conf": conf = a[i + 1]
            i += 2
        if mode == "auto": mode = "tty" if os.environ.get("TERM") == "linux" else "ansi"
        cf_ = load_conf(conf)
        sys.stdout.write(build(tbn, mode, cols, rows, 2.0, info_lines(cf_), None, cf_.get("FILL", "ascii")))
    elif c == "apply":
        tty = "tty1"; ro = False
        for i, x in enumerate(a):
            if x == "--tty": tty = a[i + 1]
            if x == "--remote-only": ro = True
        apply(tty, ro)
    elif c == "analyze-issue":
        try: text = open(a[0], errors="replace").read()
        except OSError: text = ""
        r = analyze(text)
        for k in ("IP", "OS", "HOST", "URL_TPL"): print("%s=%s" % (k, r[k]))
    elif c == "font-info":
        f = choose_font(a[0] if a else "auto")
        print(("%s %dx%d" % ((f[0],) + (font_dims(f[1]) or (0, 0)))) if f else "none")
    elif c == "list-repo": cmd_list_repo(*a)
    elif c == "download": cmd_download(a[0], a[1])
    elif c == "raw-url": print(raw_url(*a))
    elif c == "diagnose":
        conf = load_conf()
        cf = choose_font(conf.get("FONT", "auto"))
        print("python:", sys.version.split()[0], "| Pillow:", "yes" if not os.environ.get("TTYB_NO_PIL") and __import__("importlib.util").util.find_spec("PIL") else "no")
        print("config FONT=%s FILL=%s ROTATE=%s SSH=%s MOTD=%s" % (conf.get("FONT"), conf.get("FILL"), conf.get("ROTATE"), conf.get("SSH"), conf.get("MOTD")))
        print("font chosen:", ("%s %sx%s" % ((cf[0],) + (font_dims(cf[1]) or ("?", "?")))) if cf else "none (current font is used -> less detail)")
        print("fonts found:", len(find_fonts()), "| banners:", len(banners()))
        for t in ("tty1",):
            r_, c_ = term_size(t); print("%s size now: %d rows x %d cols (small font => ~90x320 on 1080p; ~25x80 means no small font)" % (t, r_, c_))
        try: print("setfont log:\n" + open(P("/run/tty-banner/setfont.log")).read())
        except OSError: print("setfont log: (empty; the console service has not run since boot)")
    elif c == "has-pil":
        try:
            import PIL; print("yes")
        except ImportError: print("no")
    else: die("unknown command " + c)


if __name__ == "__main__":
    main(sys.argv)
__TTYB_ENGINE_EOF__
}

main "$@"
exit $?