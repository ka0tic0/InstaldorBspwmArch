#!/usr/bin/env bash
#
# setup-catppuccin-bspwm.sh
# ---------------------------------------------------------------------------
# Instala y configura un entorno bspwm completo con estética Catppuccin Mocha
# sobre una instalación mínima/base de Arch Linux.
#
# USO:
#   1) Ejecutar como root:            sudo ./setup-catppuccin-bspwm.sh
#      (el script detecta el usuario "real" con SUDO_USER para instalar
#       las configuraciones en su $HOME, nunca en /root)
#   2) Seguir las preguntas interactivas para paquetes opcionales.
#
# ---------------------------------------------------------------------------

set -e   # Detener el script ante cualquier error no controlado
set -u   # Tratar variables no definidas como error
set -o pipefail

# =============================================================================
# 0. COLORES Y HELPERS DE MENSAJES
# =============================================================================
readonly C_RESET='\033[0m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_RED='\033[0;31m'
readonly C_BLUE='\033[0;34m'

log_ok()    { echo -e "${C_GREEN}[OK]${C_RESET} $1"; }
log_warn()  { echo -e "${C_YELLOW}[AVISO]${C_RESET} $1"; }
log_err()   { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
log_info()  { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }

pause_step() {
    echo -e "${C_BLUE}--------------------------------------------------------${C_RESET}"
    read -rp "Presiona ENTER para continuar..."
}

ask_yes_no() {
    # $1 = pregunta. Devuelve 0 (sí) o 1 (no)
    local answer
    read -rp "$1 [s/N]: " answer
    case "$answer" in
        [sS]|[sS][iI]) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# 1. MANEJO DE ERRORES / ROLLBACK
# =============================================================================
ROLLBACK_LOG="/tmp/bspwm_setup_rollback.log"
: > "$ROLLBACK_LOG"

register_rollback() {
    # Guarda una acción de reversa (se ejecuta en orden inverso si algo falla)
    echo "$1" >> "$ROLLBACK_LOG"
}

trap_on_error() {
    log_err "Se produjo un error crítico en la línea $1. Iniciando rollback..."
    if [[ -s "$ROLLBACK_LOG" ]]; then
        tac "$ROLLBACK_LOG" | while read -r cmd; do
            log_warn "Revirtiendo: $cmd"
            eval "$cmd" || true
        done
    fi
    log_err "El script se detuvo. Revisa los mensajes anteriores para más detalles."
    exit 1
}
trap 'trap_on_error $LINENO' ERR

# =============================================================================
# 2. VARIABLES GLOBALES
# =============================================================================
if [[ "$EUID" -ne 0 ]]; then
    log_err "Este script debe ejecutarse como root (usa: sudo ./setup-catppuccin-bspwm.sh)"
    exit 1
fi

if [[ -z "${SUDO_USER:-}" ]]; then
    log_err "No se detectó SUDO_USER. Ejecuta el script con 'sudo', no como root puro."
    exit 1
fi

TARGET_USER="$SUDO_USER"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
CONFIG_DIR="$TARGET_HOME/.config"
LOCAL_BIN="$TARGET_HOME/.local/bin"
WALLPAPER_DIR="$TARGET_HOME/Pictures/wallpapers"

# Ejecuta un comando como el usuario objetivo (no como root)
as_user() {
    sudo -u "$TARGET_USER" bash -c "$1"
}

# =============================================================================
# 3. VERIFICACIÓN INICIAL
# =============================================================================
check_internet() {
    log_info "Verificando conexión a internet..."
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_ok "Conexión a internet detectada."
    else
        log_err "No hay conexión a internet. Conéctate y vuelve a ejecutar el script."
        exit 1
    fi
}

update_system() {
    log_info "Actualizando el sistema (pacman -Syu)..."
    pacman -Syu --noconfirm
    log_ok "Sistema actualizado."
    if ! ask_yes_no "¿Deseas continuar con la instalación del entorno bspwm?"; then
        log_warn "Instalación cancelada por el usuario."
        exit 0
    fi
}

# =============================================================================
# 4. INSTALACIÓN DE PAQUETES
# =============================================================================
install_yay() {
    if command -v yay &>/dev/null; then
        log_ok "yay ya está instalado."
        return
    fi
    log_info "Instalando yay (AUR helper)..."
    pacman -S --needed --noconfirm base-devel git
    as_user "cd /tmp && rm -rf yay && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
    if command -v yay &>/dev/null; then
        log_ok "yay instalado correctamente."
    else
        log_err "Falló la instalación de yay."
        exit 1
    fi
}

install_packages() {
    log_info "Instalando paquetes principales desde los repositorios oficiales..."

    local PACMAN_PKGS=(
        # Servidor X
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
        # BSPWM
        bspwm sxhkd
        # Terminal
        kitty
        # Barra
        polybar
        # Lanzador
        rofi
        # Compositor
        picom
        # Notificaciones
        dunst
        # Visualizador de imágenes / wallpaper
        feh
        # Gestor de archivos
        thunar thunar-volman
        # Red
        networkmanager network-manager-applet
        # Audio
        pipewire pipewire-pulse pipewire-alsa wireplumber
        # Fuentes
        ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji ttf-font-awesome ttf-nerd-fonts-symbols
        # Temas
        lxappearance
        # Utilidades
        git curl wget base-devel scrot
    )

    pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
    log_ok "Paquetes de pacman instalados."

    # --- Paquetes opcionales interactivos ---
    local AUR_PKGS=()

    if ask_yes_no "¿Deseas instalar yay (AUR helper)?"; then
        install_yay
    fi

    if ask_yes_no "¿Deseas instalar Firefox?"; then
        pacman -S --needed --noconfirm firefox
    fi

    if ask_yes_no "¿Deseas instalar Brave (desde AUR: brave-bin)?"; then
        AUR_PKGS+=(brave-bin)
    fi

    if ask_yes_no "¿Deseas instalar Neovim?"; then
        pacman -S --needed --noconfirm neovim
    fi

    if ask_yes_no "¿Deseas instalar htop y fastfetch?"; then
        pacman -S --needed --noconfirm htop fastfetch
    fi

    if ask_yes_no "¿Deseas instalar el tema catppuccin-gtk-theme-mocha (AUR)?"; then
        AUR_PKGS+=(catppuccin-gtk-theme-mocha)
    fi

    if ask_yes_no "¿Deseas instalar el tema de iconos Tela-circle (AUR: tela-icon-theme)?"; then
        AUR_PKGS+=(tela-icon-theme)
    fi

    if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
        if ! command -v yay &>/dev/null; then
            log_warn "yay no está instalado; se omiten los paquetes AUR seleccionados: ${AUR_PKGS[*]}"
        else
            log_info "Instalando paquetes AUR: ${AUR_PKGS[*]}"
            as_user "yay -S --needed --noconfirm ${AUR_PKGS[*]}"
            log_ok "Paquetes AUR instalados."
        fi
    fi
}

# =============================================================================
# 5. BACKUP DE CONFIGURACIONES EXISTENTES
# =============================================================================
backup_if_exists() {
    local target="$1"
    if [[ -e "$target" ]]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Se encontró una configuración existente en $target. Se respalda en $backup"
        as_user "mv '$target' '$backup'"
    fi
}

# =============================================================================
# 6. ESTRUCTURA DE DIRECTORIOS
# =============================================================================
create_directories() {
    log_info "Creando estructura de directorios de configuración..."
    local dirs=(
        "$CONFIG_DIR/bspwm"
        "$CONFIG_DIR/sxhkd"
        "$CONFIG_DIR/polybar"
        "$CONFIG_DIR/picom"
        "$CONFIG_DIR/dunst"
        "$CONFIG_DIR/rofi"
        "$CONFIG_DIR/kitty"
        "$CONFIG_DIR/gtk-3.0"
        "$CONFIG_DIR/gtk-4.0"
        "$LOCAL_BIN"
        "$WALLPAPER_DIR"
    )
    for d in "${dirs[@]}"; do
        as_user "mkdir -p '$d'"
    done
    log_ok "Directorios creados."
}

# =============================================================================
# 7a. CONFIGURACIÓN DE BSPWM
# =============================================================================
configure_bspwm() {
    log_info "Configurando bspwmrc..."
    local file="$CONFIG_DIR/bspwm/bspwmrc"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
#!/usr/bin/env bash
#
# bspwmrc - configuración principal de bspwm
# Se ejecuta cada vez que bspwm arranca.

# --- Autostart de servicios ---
# sxhkd: demonio de atajos de teclado
pgrep -x sxhkd > /dev/null || sxhkd &

# picom: compositor (transparencias, sombras, vsync)
pgrep -x picom > /dev/null || picom --config ~/.config/picom/picom.conf &

# dunst: demonio de notificaciones
pgrep -x dunst > /dev/null || dunst &

# nm-applet: icono de gestión de red en la bandeja del sistema
pgrep -x nm-applet > /dev/null || nm-applet &

# Restaurar el wallpaper guardado (o el predeterminado)
if [ -f "$HOME/.config/bspwm/wallpaper_path" ]; then
    feh --bg-scale "$(cat "$HOME/.config/bspwm/wallpaper_path")" &
fi

# Barra de estado (polybar), lanzada mediante script propio
~/.local/bin/launch_polybar &

# --- Configuración de pantalla ---
# Ajusta la resolución/salida detectada automáticamente. Si tienes un
# monitor concreto, edita este comando (xrandr --output <SALIDA> --auto).
xrandr --auto

# --- Configuración de escritorios (workspaces) ---
bspc monitor -d I:Web II:Term III:Code IV:Misc

# --- Configuración general de bspwm ---
bspc config border_width         2
bspc config window_gap           10

bspc config split_ratio          0.52
bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config focus_follows_pointer true

# --- Reglas de ventanas ---
# Ventanas flotantes y centradas para utilidades específicas
bspc rule -a Rofi state=floating center=true
bspc rule -a Thunar state=floating center=true
bspc rule -a Lxappearance state=floating center=true
bspc rule -a Pavucontrol state=floating center=true
bspc rule -a "*:*:*" state=floating center=true  # ventanas sin clase definida se centran

EOF
    as_user "true" # no-op para mantener consistencia de permisos con as_user
    chown "$TARGET_USER:$TARGET_USER" "$file"
    chmod +x "$file"   # Permisos de ejecución requeridos por .xinitrc
    log_ok "bspwmrc creado y marcado como ejecutable."
}

# =============================================================================
# 7b. CONFIGURACIÓN DE SXHKD
# =============================================================================
configure_sxhkd() {
    log_info "Configurando sxhkdrc..."
    local file="$CONFIG_DIR/sxhkd/sxhkdrc"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
#
# sxhkdrc - atajos de teclado globales para bspwm
#

# --- Aplicaciones ---
super + Return
    kitty

super + q
    bspc node -c

# --- Escritorios ---
super + {1-4}
    bspc desktop -f '^{1-4}'

super + shift + {1-4}
    bspc node -d '^{1-4}'

# --- Navegación entre ventanas (vim keys: j,k,l,;) ---
super + {j,k,l,semicolon}
    bspc node -f {west,south,north,east}

super + shift + {j,k,l,semicolon}
    bspc node -s {west,south,north,east}

# --- Layouts ---
super + t
    bspc desktop -l tiled

super + m
    bspc desktop -l monocle

super + f
    bspc node -t ~fullscreen

super + space
    bspc desktop -l next

# --- Ajuste de gaps ---
super + ctrl + h
    bspc config -d focused window_gap "$(( $(bspc config -d focused window_gap) - 2 ))"

super + ctrl + l
    bspc config -d focused window_gap "$(( $(bspc config -d focused window_gap) + 2 ))"

# --- Rofi ---
super + d
    rofi -show drun

super + r
    rofi -show run

super + w
    rofi -show window

# --- Multimedia ---
XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# --- Capturas de pantalla ---
Print
    scrot ~/Pictures/screenshot_%Y-%m-%d_%H-%M-%S.png

super + Print
    scrot -s ~/Pictures/screenshot_%Y-%m-%d_%H-%M-%S.png

EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "sxhkdrc creado."
}

# =============================================================================
# 7c. CONFIGURACIÓN DE POLYBAR
# =============================================================================
configure_polybar() {
    log_info "Configurando polybar..."
    local file="$CONFIG_DIR/polybar/config.ini"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
; ============================================================
; Polybar - tema Catppuccin Mocha
; ============================================================

[colors]
base   = #1e1e2e
text   = #cdd6f4
blue   = #89b4fa
green  = #a6e3a1
red    = #f38ba8
yellow = #f9e2af
mauve  = #cba6f7
transparent = #00000000

[bar/main]
width = 100%
height = 30px
radius = 0
fixed-center = true

background = ${colors.base}
foreground = ${colors.text}

line-size = 2px

border-size = 0
padding-left = 1
padding-right = 1

module-margin = 1

font-0 = "JetBrains Mono Nerd Font:size=11;2"

modules-left = bspwm
modules-center = date time
modules-right = cpu memory volume network battery

cursor-click = pointer
cursor-scroll = ns-resize

[module/bspwm]
type = internal/bspwm

label-focused = %index%
label-focused-background = ${colors.blue}
label-focused-foreground = ${colors.base}
label-focused-padding = 2

label-occupied = %index%
label-occupied-foreground = ${colors.text}
label-occupied-padding = 2

label-empty = %index%
label-empty-foreground = ${colors.mauve}
label-empty-padding = 2

label-urgent = %index%
label-urgent-background = ${colors.red}
label-urgent-padding = 2

[module/date]
type = internal/date
interval = 1
date = %d/%m/%Y
label = %date%
label-foreground = ${colors.green}

[module/time]
type = internal/date
interval = 1
time = %H:%M:%S
label = %time%
label-foreground = ${colors.yellow}

[module/cpu]
type = internal/cpu
interval = 2
label = CPU %percentage%%
label-foreground = ${colors.blue}

[module/memory]
type = internal/memory
interval = 2
label = MEM %percentage_used%%
label-foreground = ${colors.mauve}

[module/volume]
type = internal/pulseaudio
label-volume = VOL %percentage%%
label-volume-foreground = ${colors.green}
label-muted = MUTED
label-muted-foreground = ${colors.red}

[module/network]
type = internal/network
interface-type = wired
interval = 3.0
label-connected = NET %local_ip%
label-connected-foreground = ${colors.blue}
label-disconnected = SIN RED
label-disconnected-foreground = ${colors.red}

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC
full-at = 98
label-charging = CARGANDO %percentage%%
label-discharging = BAT %percentage%%
label-full = BATERÍA COMPLETA
label-charging-foreground = ${colors.green}
label-discharging-foreground = ${colors.text}

[settings]
screenchange-reload = true

EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "Configuración de polybar creada."
}

# =============================================================================
# 7d. CONFIGURACIÓN DE PICOM
# =============================================================================
configure_picom() {
    log_info "Configurando picom.conf..."
    local file="$CONFIG_DIR/picom/picom.conf"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
# ============================================================
# picom.conf - compositor con transparencias y sombras suaves
# ============================================================

backend = "glx";
vsync = true;

# --- Transparencias ---
opacity-rule = [
    "80:class_g = 'kitty'"
];
active-opacity   = 1.0;
inactive-opacity = 0.8;
inactive-opacity-override = false;

# --- Sombras ---
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;

# --- Esquinas redondeadas ---
corner-radius = 10;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

# --- Difuminado (fade) ---
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;

# --- Otros ---
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-damage = true;

EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "Configuración de picom creada."
}

# =============================================================================
# 7e. CONFIGURACIÓN DE DUNST
# =============================================================================
configure_dunst() {
    log_info "Configurando dunstrc..."
    local file="$CONFIG_DIR/dunst/dunstrc"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
[global]
    monitor = 0
    follow = mouse
    origin = top-right
    offset = 10x10
    width = 300
    height = 100
    notification_limit = 5
    separator_height = 10
    padding = 10
    horizontal_padding = 10
    frame_width = 2
    frame_color = "#89b4fa"
    font = JetBrains Mono Nerd Font 11
    format = "<b>%s</b>\n%b"
    transparency = 20
    corner_radius = 8

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#89b4fa"
    timeout = 5

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#89b4fa"
    timeout = 8

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#f38ba8"
    timeout = 0

EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "Configuración de dunst creada."
}

# =============================================================================
# 7f. CONFIGURACIÓN DE KITTY
# =============================================================================
configure_kitty() {
    log_info "Configurando kitty.conf..."
    local file="$CONFIG_DIR/kitty/kitty.conf"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
# ============================================================
# kitty.conf - Catppuccin Mocha
# ============================================================

font_family      JetBrains Mono Nerd Font
font_size        12.0

background_opacity 0.85
mouse_hide_wait  3.0
scrollback_lines 10000

# --- Colores Catppuccin Mocha ---
foreground              #cdd6f4
background              #1e1e2e
selection_foreground    #1e1e2e
selection_background    #45475a

cursor                  #f5e0dc
cursor_text_color       #1e1e2e

url_color               #89b4fa

# Colores normales
color0  #45475a
color1  #f38ba8
color2  #a6e3a1
color3  #f9e2af
color4  #89b4fa
color5  #cba6f7
color6  #94e2d5
color7  #bac2de

# Colores brillantes
color8  #585b70
color9  #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #cba6f7
color14 #94e2d5
color15 #a6adc8

confirm_os_window_close 0

EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "Configuración de kitty creada."
}

# =============================================================================
# 7g. .xinitrc
# =============================================================================
configure_xinitrc() {
    log_info "Configurando .xinitrc..."
    local file="$TARGET_HOME/.xinitrc"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
#!/bin/sh
# .xinitrc - inicia bspwm al arrancar X con "startx"
exec bspwm
EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    chmod +x "$file"
    log_ok ".xinitrc creado."
}

# =============================================================================
# 7h/i. CONFIGURACIÓN GTK (3.0 y 4.0)
# =============================================================================
configure_gtk() {
    log_info "Configurando temas GTK..."
    local gtk3_file="$CONFIG_DIR/gtk-3.0/settings.ini"
    local gtk4_file="$CONFIG_DIR/gtk-4.0/settings.ini"
    backup_if_exists "$gtk3_file"
    backup_if_exists "$gtk4_file"

    local gtk_settings='[Settings]
gtk-theme-name=Catppuccin-Mocha
gtk-icon-theme-name=Tela-circle
gtk-font-name=JetBrains Mono Nerd Font 11
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
'

    echo "$gtk_settings" > "$gtk3_file"
    echo "$gtk_settings" > "$gtk4_file"
    chown "$TARGET_USER:$TARGET_USER" "$gtk3_file" "$gtk4_file"
    log_ok "Configuración GTK 3.0 y 4.0 creada (tema: Catppuccin-Mocha, iconos: Tela-circle)."
}

# =============================================================================
# 8. SCRIPTS ADICIONALES (~/.local/bin)
# =============================================================================
setup_scripts() {
    log_info "Creando scripts auxiliares en ~/.local/bin..."

    # --- launch_polybar ---
    local polybar_script="$LOCAL_BIN/launch_polybar"
    cat > "$polybar_script" <<'EOF'
#!/usr/bin/env bash
# launch_polybar - lanza polybar en cada monitor activo detectado por xrandr

# Mata cualquier instancia previa de polybar de forma silenciosa
killall -q polybar

# Espera a que el proceso anterior termine completamente
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; done

# Detecta los monitores conectados y lanza una barra por cada uno
if type "xrandr" >/dev/null; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR="$m" polybar --reload main -c "$HOME/.config/polybar/config.ini" &
    done
else
    polybar --reload main -c "$HOME/.config/polybar/config.ini" &
fi
EOF

    # --- wallpaper_setup ---
    local wallpaper_script="$LOCAL_BIN/wallpaper_setup"
    cat > "$wallpaper_script" <<'EOF'
#!/usr/bin/env bash
# wallpaper_setup - descarga (si hace falta) y aplica un wallpaper de Catppuccin

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/catppuccin-default.png"
PATH_RECORD="$HOME/.config/bspwm/wallpaper_path"

mkdir -p "$WALLPAPER_DIR"

if [ ! -f "$DEFAULT_WALLPAPER" ]; then
    echo "Descargando wallpaper de Catppuccin..."
    curl -sL -o "$DEFAULT_WALLPAPER" \
        "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/mountain.png" \
        || echo "No se pudo descargar el wallpaper; usa uno propio en $WALLPAPER_DIR"
fi

if [ -f "$DEFAULT_WALLPAPER" ]; then
    echo "$DEFAULT_WALLPAPER" > "$PATH_RECORD"
    feh --bg-scale "$DEFAULT_WALLPAPER"
else
    echo "No hay wallpaper disponible para aplicar."
fi
EOF

    # --- statusbar_launcher ---
    local statusbar_script="$LOCAL_BIN/statusbar_launcher"
    cat > "$statusbar_script" <<'EOF'
#!/usr/bin/env bash
# statusbar_launcher - inicia polybar y servicios auxiliares de la barra

"$HOME/.local/bin/launch_polybar"
pgrep -x nm-applet > /dev/null || nm-applet &
EOF

    chmod +x "$polybar_script" "$wallpaper_script" "$statusbar_script"
    chown "$TARGET_USER:$TARGET_USER" "$polybar_script" "$wallpaper_script" "$statusbar_script"
    log_ok "Scripts auxiliares creados y marcados como ejecutables."
}

# =============================================================================
# 9. DESCARGA DE WALLPAPER
# =============================================================================
download_wallpaper() {
    log_info "Descargando wallpaper de Catppuccin..."
    as_user "$LOCAL_BIN/wallpaper_setup" || log_warn "No se pudo aplicar el wallpaper automáticamente (puedes ejecutar 'wallpaper_setup' manualmente más tarde)."
}

# =============================================================================
# 10. ROFI (config mínima con estética Catppuccin)
# =============================================================================
configure_rofi() {
    log_info "Configurando rofi..."
    local file="$CONFIG_DIR/rofi/config.rasi"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
configuration {
    modi: "drun,run,window";
    font: "JetBrains Mono Nerd Font 11";
    show-icons: true;
}

* {
    bg0: #1e1e2eee;
    bg1: #313244;
    fg0: #cdd6f4;
    accent: #cba6f7;

    background-color: @bg0;
    text-color: @fg0;
    border-color: @accent;
}

window {
    width: 40%;
    border: 2px;
    border-radius: 10px;
}

element selected {
    background-color: @accent;
    text-color: @bg0;
}
EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "Configuración de rofi creada."
}

# =============================================================================
# 11. .Xresources (colores Catppuccin para apps de terminal)
# =============================================================================
configure_xresources() {
    log_info "Configurando ~/.Xresources..."
    local file="$TARGET_HOME/.Xresources"
    backup_if_exists "$file"

    cat > "$file" <<'EOF'
! Catppuccin Mocha - colores base para aplicaciones de terminal (Xresources)
*.foreground:  #cdd6f4
*.background:  #1e1e2e
*.cursorColor: #f5e0dc

*.color0:  #45475a
*.color1:  #f38ba8
*.color2:  #a6e3a1
*.color3:  #f9e2af
*.color4:  #89b4fa
*.color5:  #cba6f7
*.color6:  #94e2d5
*.color7:  #bac2de
*.color8:  #585b70
*.color9:  #f38ba8
*.color10: #a6e3a1
*.color11: #f9e2af
*.color12: #89b4fa
*.color13: #cba6f7
*.color14: #94e2d5
*.color15: #a6adc8
EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok ".Xresources creado."
}

# =============================================================================
# 12. user-dirs.dirs
# =============================================================================
configure_user_dirs() {
    log_info "Configurando ~/.config/user-dirs.dirs..."
    if command -v xdg-user-dirs-update &>/dev/null; then
        as_user "xdg-user-dirs-update"
        log_ok "Directorios de usuario (Descargas, Documentos, etc.) configurados con xdg-user-dirs."
    else
        log_warn "xdg-user-dirs no está instalado; se omite este paso (instálalo con: pacman -S xdg-user-dirs)."
    fi
}

# =============================================================================
# 13. BASHRC - ALIAS ÚTILES
# =============================================================================
configure_bashrc() {
    log_info "Añadiendo alias útiles a ~/.bashrc..."
    local file="$TARGET_HOME/.bashrc"
    local marker="# >>> bspwm-catppuccin setup >>>"

    if [[ -f "$file" ]] && grep -qF "$marker" "$file"; then
        log_warn "Los alias ya estaban presentes en .bashrc; se omite."
        return
    fi

    cat >> "$file" <<'EOF'

# >>> bspwm-catppuccin setup >>>
alias ll='ls -lah --color=auto'
alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'
alias rc-bspwm='$EDITOR ~/.config/bspwm/bspwmrc'
alias rc-sxhkd='$EDITOR ~/.config/sxhkd/sxhkdrc'
alias reload-sxhkd='pkill -USR1 -x sxhkd'
alias reload-polybar='~/.local/bin/launch_polybar'
# <<< bspwm-catppuccin setup <<<
EOF
    chown "$TARGET_USER:$TARGET_USER" "$file"
    log_ok "Alias añadidos a .bashrc."
}

# =============================================================================
# 14. POST-INSTALACIÓN
# =============================================================================
post_install() {
    log_info "Ejecutando pasos de post-instalación..."

    # Habilitar NetworkManager
    systemctl enable NetworkManager --now
    log_ok "NetworkManager habilitado e iniciado."

    # Habilitar servicios de audio (pipewire) a nivel de usuario
    as_user "systemctl --user enable pipewire pipewire-pulse wireplumber --now" \
        || log_warn "No se pudieron habilitar los servicios de usuario de pipewire (revisa manualmente con 'systemctl --user status pipewire')."
    log_ok "Servicios de audio configurados."

    # Agregar el usuario a los grupos necesarios
    usermod -aG audio,video,network,storage,wheel "$TARGET_USER"
    log_ok "Usuario '$TARGET_USER' añadido a los grupos: audio, video, network, storage, wheel."

    configure_user_dirs
    configure_bashrc
    configure_xresources
}

# =============================================================================
# 15. RESUMEN FINAL
# =============================================================================
print_summary() {
    echo ""
    echo -e "${C_GREEN}========================================================${C_RESET}"
    echo -e "${C_GREEN}  Instalación completada: entorno bspwm + Catppuccin    ${C_RESET}"
    echo -e "${C_GREEN}========================================================${C_RESET}"
    echo -e "Usuario configurado : ${C_BLUE}$TARGET_USER${C_RESET}"
    echo -e "Directorio config.  : ${C_BLUE}$CONFIG_DIR${C_RESET}"
    echo -e "Scripts personales  : ${C_BLUE}$LOCAL_BIN${C_RESET}"
    echo -e "Wallpapers          : ${C_BLUE}$WALLPAPER_DIR${C_RESET}"
    echo ""
    echo "Componentes instalados y configurados:"
    echo "  - bspwm + sxhkd (window manager y atajos)"
    echo "  - kitty (terminal)"
    echo "  - polybar (barra de estado)"
    echo "  - rofi (lanzador)"
    echo "  - picom (compositor: transparencias/sombras)"
    echo "  - dunst (notificaciones)"
    echo "  - thunar (gestor de archivos)"
    echo "  - NetworkManager + nm-applet"
    echo "  - pipewire (audio)"
    echo "  - Fuentes Nerd Font / Noto / Font Awesome"
    echo "  - Tema GTK: Catppuccin-Mocha | Iconos: Tela-circle"
    echo ""
    echo "Para iniciar el entorno gráfico ejecuta: startx"
    echo -e "${C_GREEN}========================================================${C_RESET}"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    log_info "Iniciando instalación del entorno bspwm con estética Catppuccin Mocha..."
    pause_step

    check_internet
    update_system

    install_packages
    register_rollback "pacman -Rns --noconfirm bspwm sxhkd kitty polybar rofi picom dunst || true"

    create_directories
    configure_bspwm
    configure_sxhkd
    configure_polybar
    configure_picom
    configure_dunst
    configure_kitty
    configure_gtk
    configure_rofi
    configure_xinitrc
    setup_scripts
    download_wallpaper
    post_install

    print_summary

    if ask_yes_no "¿Deseas reiniciar el sistema ahora para aplicar todos los cambios?"; then
        log_info "Reiniciando..."
        reboot
    else
        log_info "Puedes reiniciar más tarde o ejecutar 'startx' para probar el entorno."
    fi
}

main "$@"
