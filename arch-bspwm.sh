cat >setup-catppuccin-bspwm.sh <<'SCRIPT_EOF'
#!/usr/bin/env bash
###############################################################################
# Script de instalación automatizada: BSPWM + Catppuccin Mocha en Arch Linux  #
# Autor: Generado automáticamente                                             #
# Descripción: Instala y configura un entorno bspwm completo desde Arch base  #
###############################################################################

set -euo pipefail

#==============================================================================
# VARIABLES GLOBALES
#==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/var/log/bspwm-setup.log"
BACKUP_DIR="$HOME/.config/.backup-$(date +%Y%m%d-%H%M%S)"

# Colores
CLR_RESET='\033[0m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[0;33m'
CLR_RED='\033[0;31m'
CLR_BLUE='\033[0;34m'
CLR_CYAN='\033[0;36m'
CLR_MAGENTA='\033[0;35m'

# Usuario objetivo (se detectará o preguntará)
TARGET_USER=""
TARGET_HOME=""

# Flags de control
INSTALL_YAY=false
INSTALL_BROWSER=""
INSTALL_EDITOR=""
INSTALL_UTILS=false
ROLLBACK_DONE=false

#==============================================================================
# FUNCIONES DE UTILIDAD
#==============================================================================

msg_info() {
    echo -e "${CLR_CYAN}[INFO]${CLR_RESET} $1" | tee -a "$LOG_FILE"
}

msg_ok() {
    echo -e "${CLR_GREEN}[OK]${CLR_RESET} $1" | tee -a "$LOG_FILE"
}

msg_warn() {
    echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} $1" | tee -a "$LOG_FILE"
}

msg_err() {
    echo -e "${CLR_RED}[ERROR]${CLR_RESET} $1" | tee -a "$LOG_FILE"
}

msg_step() {
    echo -e "\n${CLR_MAGENTA}══════════════════════════════════════════════════════════════════${CLR_RESET}"
    echo -e "${CLR_MAGENTA}  $1${CLR_RESET}"
    echo -e "${CLR_MAGENTA}══════════════════════════════════════════════════════════════════${CLR_RESET}\n"
}

pause() {
    read -rp "Presiona Enter para continuar..."
}

# Función de rollback
do_rollback() {
    if [[ "$ROLLBACK_DONE" == true ]]; then
        return
    fi
    ROLLBACK_DONE=true
    msg_err "Error crítico detectado. Iniciando rollback..."
    
    # Restaurar backups si existen
    if [[ -d "$BACKUP_DIR" ]]; then
        msg_info "Restaurando configuraciones desde backup..."
        for dir in "$BACKUP_DIR"/*; do
            if [[ -d "$dir" ]]; then
                local name=$(basename "$dir")
                if [[ -d "$TARGET_HOME/.config/$name" ]]; then
                    rm -rf "$TARGET_HOME/.config/$name"
                fi
                cp -r "$dir" "$TARGET_HOME/.config/"
                msg_ok "Restaurado: ~/.config/$name"
            fi
        done
    fi
    
    msg_warn "Rollback completado. Revisa el log en: $LOG_FILE"
    exit 1
}

# Trap para errores
trap 'msg_err "Error en línea $LINENO"; do_rollback' ERR

# Backup de configuración existente
backup_config() {
    local config_dir="$1"
    local name=$(basename "$config_dir")
    
    if [[ -d "$config_dir" ]] && [[ ! -L "$config_dir" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$config_dir" "$BACKUP_DIR/"
        msg_warn "Backup creado para: $name"
    fi
}

# Verificar si un paquete está instalado
is_installed() {
    pacman -Q "$1" &>/dev/null
}

# Ejecutar como usuario objetivo
run_as_user() {
    su - "$TARGET_USER" -c "$1"
}

#==============================================================================
# VERIFICACIÓN INICIAL
#==============================================================================

check_root() {
    msg_step "Verificación inicial"
    
    if [[ "$EUID" -ne 0 ]]; then
        msg_err "Este script debe ejecutarse como root (usa sudo o su)"
        exit 1
    fi
    msg_ok "Ejecutando como root"
}

check_internet() {
    msg_info "Verificando conexión a internet..."
    if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
        msg_err "No hay conexión a internet. Conéctate e intenta de nuevo."
        exit 1
    fi
    msg_ok "Conexión a internet activa"
}

detect_user() {
    msg_info "Detectando usuario normal..."
    
    # Buscar usuarios normales (UID >= 1000, no nobody/nologin)
    local users
    users=$(awk -F: '$3 >= 1000 && $3 < 65534 && $7 !~ /nologin|false/ {print $1}' /etc/passwd)
    
    local count=$(echo "$users" | grep -c '^' || true)
    
    if [[ "$count" -eq 1 ]]; then
        TARGET_USER="$users"
    elif [[ "$count" -gt 1 ]]; then
        echo "Usuarios encontrados:"
        echo "$users"
        read -rp "Ingresa el nombre de usuario para configurar el entorno: " TARGET_USER
    else
        read -rp "No se encontró usuario normal. Ingresa nombre de usuario a crear o usar: " TARGET_USER
        if ! id "$TARGET_USER" &>/dev/null; then
            msg_info "Creando usuario $TARGET_USER..."
            useradd -m -G wheel,audio,video,network,storage -s /bin/bash "$TARGET_USER"
            passwd "$TARGET_USER"
            msg_ok "Usuario $TARGET_USER creado"
        fi
    fi
    
    TARGET_HOME="$(eval echo ~"$TARGET_USER")"
    msg_ok "Usuario objetivo: $TARGET_USER (home: $TARGET_HOME)"
}

update_system() {
    msg_step "Actualización del sistema"
    msg_info "Ejecutando pacman -Syu..."
    pacman -Syu --noconfirm
    msg_ok "Sistema actualizado"
    
    read -rp "¿Deseas continuar con la instalación? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        msg_warn "Instalación cancelada por el usuario"
        exit 0
    fi
}

#==============================================================================
# INSTALACIÓN DE PAQUETES
#==============================================================================

install_packages() {
    msg_step "Instalación de paquetes"
    
    # Paquetes oficiales
    local official_pkgs=(
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
        bspwm sxhkd
        kitty
        polybar
        rofi
        picom
        dunst
        feh
        thunar thunar-volman
        networkmanager network-manager-applet
        pipewire pipewire-pulse pipewire-alsa wireplumber
        ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
        ttf-font-awesome ttf-nerd-fonts-symbols
        lxappearance
        git curl wget base-devel
        scrot
        xdg-user-dirs
        polkit-gnome
        gnome-keyring
    )
    
    msg_info "Instalando paquetes oficiales (${#official_pkgs[@]} paquetes)..."
    pacman -S --needed --noconfirm "${official_pkgs[@]}"
    msg_ok "Paquetes oficiales instalados"
    
    # Paquetes AUR (opcionales, requieren yay)
    local aur_pkgs=(
        catppuccin-gtk-theme-mocha
        tela-circle-icon-theme
        nitrogen-git
    )
    
    if [[ "$INSTALL_YAY" == true ]]; then
        msg_info "Instalando paquetes AUR..."
        for pkg in "${aur_pkgs[@]}"; do
            if ! run_as_user "yay -Q $pkg" &>/dev/null; then
                run_as_user "yay -S --noconfirm $pkg" || msg_warn "No se pudo instalar $pkg"
            fi
        done
        msg_ok "Paquetes AUR instalados"
    else
        msg_warn "yay no se instalará. Los siguientes paquetes AUR se omiten:"
        msg_warn "  - catppuccin-gtk-theme-mocha"
        msg_warn "  - tela-circle-icon-theme"
        msg_warn "  - nitrogen-git"
        msg_warn "Puedes instalarlos manualmente más tarde con yay."
    fi
    
    # Paquetes opcionales
    if [[ -n "$INSTALL_BROWSER" ]]; then
        msg_info "Instalando navegador: $INSTALL_BROWSER"
        pacman -S --needed --noconfirm "$INSTALL_BROWSER" || msg_warn "No se pudo instalar $INSTALL_BROWSER"
    fi
    
    if [[ -n "$INSTALL_EDITOR" ]]; then
        msg_info "Instalando editor: $INSTALL_EDITOR"
        pacman -S --needed --noconfirm "$INSTALL_EDITOR" || msg_warn "No se pudo instalar $INSTALL_EDITOR"
    fi
    
    if [[ "$INSTALL_UTILS" == true ]]; then
        msg_info "Instalando utilidades adicionales..."
        pacman -S --needed --noconfirm htop fastfetch ranger || msg_warn "Algunas utilidades no se instalaron"
    fi
}

install_yay() {
    if [[ "$INSTALL_YAY" != true ]]; then
        return
    fi
    
    msg_step "Instalación de yay (AUR helper)"
    
    if command -v yay &>/dev/null; then
        msg_ok "yay ya está instalado"
        return
    fi
    
    msg_info "Clonando yay desde AUR..."
    local build_dir="/tmp/yay-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    git clone https://aur.archlinux.org/yay.git
    cd yay
    chown -R "$TARGET_USER:$TARGET_USER" "$build_dir"
    
    msg_info "Compilando yay..."
    run_as_user "cd $build_dir/yay && makepkg -si --noconfirm"
    
    msg_ok "yay instalado correctamente"
    cd "$SCRIPT_DIR"
}

#==============================================================================
# ESTRUCTURA DE DIRECTORIOS
#==============================================================================

create_directories() {
    msg_step "Creando estructura de directorios"
    
    local dirs=(
        "$TARGET_HOME/.config/bspwm"
        "$TARGET_HOME/.config/sxhkd"
        "$TARGET_HOME/.config/polybar"
        "$TARGET_HOME/.config/picom"
        "$TARGET_HOME/.config/dunst"
        "$TARGET_HOME/.config/rofi"
        "$TARGET_HOME/.config/kitty"
        "$TARGET_HOME/.config/gtk-3.0"
        "$TARGET_HOME/.config/gtk-4.0"
        "$TARGET_HOME/.local/bin"
        "$TARGET_HOME/.local/share/fonts"
        "$TARGET_HOME/Pictures/wallpapers"
        "$TARGET_HOME/Pictures/screenshots"
        "$TARGET_HOME/.config"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chown -R "$TARGET_USER:$TARGET_USER" "$dir"
    done
    
    msg_ok "Directorios creados"
}

#==============================================================================
# CONFIGURACIÓN BSPWM
#==============================================================================

configure_bspwm() {
    msg_step "Configurando BSPWM"
    
    local config_dir="$TARGET_HOME/.config/bspwm"
    backup_config "$config_dir"
    
    cat > "$config_dir/bspwmrc" <<'EOF'
#!/usr/bin/env bash

#==============================================================================
# BSPWM Configuration - Catppuccin Mocha
#==============================================================================

# Colores Catppuccin Mocha
export BSPWM_FOCUSED_BORDER="#89b4fa"
export BSPWM_NORMAL_BORDER="#45475a"
export BSPWM_ACTIVE_BORDER="#b4befe"

# Configuración general
bspc config border_width         2
bspc config window_gap          10
bspc config split_ratio          0.50
bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config focus_follows_pointer true
bspc config pointer_follows_focus false
bspc config pointer_follows_monitor true
bspc config ignore_ewmh_focus    false

# Padding
bspc config top_padding         35
bspc config bottom_padding       0
bspc config left_padding         0
bspc config right_padding        0

# Colores de borde
bspc config normal_border_color   "$BSPWM_NORMAL_BORDER"
bspc config focused_border_color  "$BSPWM_FOCUSED_BORDER"
bspc config active_border_color   "$BSPWM_ACTIVE_BORDER"
bspc config presel_feedback_color "#a6e3a1"

# 4 Escritorios con nombres
bspc monitor -d I:Web II:Term III:Code IV:Misc

# Reglas de ventanas
bspc rule -a Rofi state=floating center=true
bspc rule -a Thunar state=floating center=true rectangle=1000x600+0+0
bspc rule -a kitty state=tiled
bspc rule -a Firefox desktop='^1' follow=on
bspc rule -a Brave-browser desktop='^1' follow=on
bspc rule -a Code desktop='^3' follow=on
bspc rule -a code-oss desktop='^3' follow=on
bspc rule -ampv state=floating center=true
bspc rule -a feh state=floating center=true

# Reglas para ventanas flotantes centradas
bspc rule -a mpv state=floating center=true
bspc rule -a feh state=floating center=true

#==============================================================================
# Autostart
#==============================================================================

# Cargar configuración de pantalla (si existe)
[[ -f ~/.config/bspwm/display.sh ]] && source ~/.config/bspwm/display.sh

# Iniciar servicios
killall -q sxhkd; sxhkd &
killall -q picom; picom --config ~/.config/picom/picom.conf &
killall -q dunst; dunst &
killall -q polybar; ~/.local/bin/launch_polybar &

# Wallpaper
~/.local/bin/wallpaper_setup &

# Polkit agent
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# NetworkManager applet
nm-applet &

# Pipewire (si no está iniciado)
pipewire &
pipewire-pulse &
wireplumber &
EOF

    chmod +x "$config_dir/bspwmrc"
    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    
    msg_ok "BSPWM configurado"
}

#==============================================================================
# CONFIGURACIÓN SXHKD
#==============================================================================

configure_sxhkd() {
    msg_step "Configurando SXHKD (atajos de teclado)"
    
    local config_dir="$TARGET_HOME/.config/sxhkd"
    backup_config "$config_dir"
    
    cat > "$config_dir/sxhkdrc" <<'EOF'
#==============================================================================
# SXHKD Configuration - Catppuccin Mocha
#==============================================================================

#----- Terminal -----
super + Return
    kitty

#----- Cerrar ventana -----
super + q
    bspc node -c

#----- Reiniciar/Detener BSPWM -----
super + shift + r
    bspc wm -r

super + shift + e
    bspc quit

#----- Escritorios -----
super + {1,2,3,4}
    bspc desktop -f '^{1,2,3,4}'

super + shift + {1,2,3,4}
    bspc node -d '^{1,2,3,4}'

#----- Navegación (vim keys) -----
super + {j,k,l,semicolon}
    bspc node -f {south,north,west,east}

#----- Mover ventanas (vim keys) -----
super + shift + {j,k,l,semicolon}
    bspc node -s {south,north,west,east}

#----- Layouts -----
super + t
    bspc desktop -l tiled

super + m
    bspc desktop -l monocle

super + f
    bspc node -t fullscreen

super + space
    bspc node -t ".~floating"

#----- Ajustar gaps -----
super + ctrl + h
    bspc config -d focused window_gap $(( $(bspc config -d focused window_gap) - 2 ))

super + ctrl + l
    bspc config -d focused window_gap $(( $(bspc config -d focused window_gap) + 2 ))

#----- Rofi -----
super + d
    rofi -show drun -theme catppuccin-mocha

super + r
    rofi -show run -theme catppuccin-mocha

super + w
    rofi -show window -theme catppuccin-mocha

#----- Capturas de pantalla -----
Print
    scrot ~/Pictures/screenshots/%Y-%m-%d-%H%M%S.png

super + Print
    scrot -u ~/Pictures/screenshots/%Y-%m-%d-%H%M%S-window.png

super + shift + Print
    scrot -s ~/Pictures/screenshots/%Y-%m-%d-%H%M%S-select.png

#----- Multimedia -----
XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

XF86AudioPlay
    playerctl play-pause

XF86AudioNext
    playerctl next

XF86AudioPrev
    playerctl previous

#----- Utilidades -----
super + shift + Return
    thunar

super + Escape
    xkill

#----- Recargar sxhkd -----
super + shift + s
    pkill -USR1 -x sxhkd
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    
    msg_ok "SXHKD configurado"
}

#==============================================================================
# CONFIGURACIÓN POLYBAR
#==============================================================================

configure_polybar() {
    msg_step "Configurando Polybar"
    
    local config_dir="$TARGET_HOME/.config/polybar"
    backup_config "$config_dir"
    
    cat > "$config_dir/config.ini" <<'EOF'
;==============================================================================
; Polybar Configuration - Catppuccin Mocha
;==============================================================================

[colors]
base = #1e1e2e
mantle = #181825
crust = #11111b
text = #cdd6f4
subtext0 = #a6adc8
subtext1 = #bac2de
surface0 = #313244
surface1 = #45475a
surface2 = #585b70
overlay0 = #6c7086
overlay1 = #7f849c
overlay2 = #9399b2
blue = #89b4fa
lavender = #b4befe
sapphire = #74c7ec
sky = #89dceb
teal = #94e2d5
green = #a6e3a1
yellow = #f9e2af
peach = #fab387
maroon = #eba0ac
red = #f38ba8
mauve = #cba6f7
pink = #f5c2e7
flamingo = #f2cdcd
rosewater = #f5e0dc
transparent = #00000000

[bar/main]
width = 100%
height = 30
offset-x = 0
offset-y = 0
radius = 0
fixed-center = true

background = ${colors.base}
foreground = ${colors.text}

line-size = 2
line-color = ${colors.blue}

border-size = 0
border-color = ${colors.transparent}

padding-left = 2
padding-right = 2

module-margin-left = 1
module-margin-right = 1

font-0 = "JetBrainsMono Nerd Font:size=11;2"
font-1 = "Font Awesome 6 Free:size=10;2"
font-2 = "Font Awesome 6 Brands:size=10;2"

modules-left = bspwm
modules-center = date
modules-right = memory cpu network volume battery

dim-value = 1.0

wm-restack = bspwm

override-redirect = false

enable-ipc = true
cursor-click = pointer
cursor-scroll = ns-resize

[module/bspwm]
type = internal/bspwm

pin-workspaces = true
inline-mode = false
enable-click = true
enable-scroll = true
reverse-scroll = false
fuzzy-match = true

ws-icon-0 = "I:Web;"
ws-icon-1 = "II:Term;"
ws-icon-2 = "III:Code;"
ws-icon-3 = "IV:Misc;"

format = <label-state>
format-background = ${colors.base}

label-focused = %icon%
label-focused-foreground = ${colors.base}
label-focused-background = ${colors.blue}
label-focused-padding = 2

label-occupied = %icon%
label-occupied-foreground = ${colors.text}
label-occupied-padding = 2

label-urgent = %icon%
label-urgent-foreground = ${colors.base}
label-urgent-background = ${colors.red}
label-urgent-padding = 2

label-empty = %icon%
label-empty-foreground = ${colors.overlay0}
label-empty-padding = 2

[module/date]
type = internal/date
interval = 1

date = %Y-%m-%d%
time = %H:%M:%S

format = <label>
format-background = ${colors.base}

label = %date% %time%
label-foreground = ${colors.text}
label-padding = 2

[module/memory]
type = internal/memory
interval = 2

format = <label>
format-prefix = " "
format-prefix-foreground = ${colors.mauve}

label = %percentage_used%%
label-foreground = ${colors.text}

[module/cpu]
type = internal/cpu
interval = 2

format = <label>
format-prefix = " "
format-prefix-foreground = ${colors.green}

label = %percentage%%
label-foreground = ${colors.text}

[module/network]
type = internal/network
interface-type = wireless
interval = 3

format-connected = <label-connected>
format-connected-prefix = " "
format-connected-prefix-foreground = ${colors.blue}
label-connected = %essid%
label-connected-foreground = ${colors.text}

format-disconnected = <label-disconnected>
format-disconnected-prefix = " "
format-disconnected-prefix-foreground = ${colors.overlay0}
label-disconnected = Desconectado
label-disconnected-foreground = ${colors.overlay0}

; Si usas cable ethernet, cambia interface-type a wired o especifica:
; interface = eth0

[module/volume]
type = internal/pulseaudio
sink = @DEFAULT_SINK@

format-volume = <label-volume>
format-volume-prefix = " "
format-volume-prefix-foreground = ${colors.teal}
label-volume = %percentage%%
label-volume-foreground = ${colors.text}

format-muted = <label-muted>
format-muted-prefix = " "
format-muted-prefix-foreground = ${colors.overlay0}
label-muted = Silenciado
label-muted-foreground = ${colors.overlay0}

[module/battery]
type = internal/battery
full-at = 99
low-at = 20
battery = BAT0
adapter = ADP1
poll-interval = 5

format-charging = <label-charging>
format-charging-prefix = " "
format-charging-prefix-foreground = ${colors.yellow}
label-charging = %percentage%%
label-charging-foreground = ${colors.text}

format-discharging = <label-discharging>
format-discharging-prefix = " "
format-discharging-prefix-foreground = ${colors.peach}
label-discharging = %percentage%%
label-discharging-foreground = ${colors.text}

format-full = <label-full>
format-full-prefix = " "
format-full-prefix-foreground = ${colors.green}
label-full = %percentage%%
label-full-foreground = ${colors.text}

[settings]
screenchange-reload = true

[global/wm]
margin-top = 0
margin-bottom = 0
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    
    msg_ok "Polybar configurado"
}

#==============================================================================
# CONFIGURACIÓN PICOM
#==============================================================================

configure_picom() {
    msg_step "Configurando Picom"
    
    local config_dir="$TARGET_HOME/.config/picom"
    backup_config "$config_dir"
    
    cat > "$config_dir/picom.conf" <<'EOF'
#==============================================================================
# Picom Configuration - Catppuccin Mocha
#==============================================================================

# Backend
backend = "glx";
vsync = true;

# Opacidad
active-opacity = 1.0;
inactive-opacity = 0.95;
frame-opacity = 1.0;

opacity-rule = [
    "80:class_g = 'kitty'",
    "90:class_g = 'Rofi'",
    "95:class_g = 'Thunar'",
    "100:class_g = 'Firefox'",
    "100:class_g = 'Brave-browser'"
];

# Sombras
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;
shadow-color = "#000000";

shadow-exclude = [
    "class_g = 'Rofi'",
    "class_g = 'Polybar'",
    "class_g = 'Dunst'"
];

# Redondeo de esquinas
corner-radius = 10;

rounded-corners-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'Dunst'",
    "window_type = 'dock'"
];

# Desvanecimiento
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

# Blur (opcional, requiere experimental backends)
blur-background = false;

# Exclusiones
focus-exclude = [
    "class_g = 'Rofi'",
    "class_g = 'Dunst'"
];

# Animaciones (requiere picom con soporte de animaciones)
# Si tu picom no soporta animaciones, estas líneas serán ignoradas
animation-stiffness = 200;
animation-dampening = 25;
animation-clamping = true;

# Otros
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
detect-client-leader = true;
use-damage = true;
log-level = "warn";
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    
    msg_ok "Picom configurado"
}

#==============================================================================
# CONFIGURACIÓN DUNST
#==============================================================================

configure_dunst() {
    msg_step "Configurando Dunst"
    
    local config_dir="$TARGET_HOME/.config/dunst"
    backup_config "$config_dir"
    
    cat > "$config_dir/dunstrc" <<'EOF'
#==============================================================================
# Dunst Configuration - Catppuccin Mocha
#==============================================================================

[global]
    monitor = 0
    follow = none
    width = 300
    height = 100
    origin = top-right
    offset = 10x10
    scale = 0
    notification_limit = 5
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 20
    separator_height = 2
    padding = 10
    horizontal_padding = 10
    text_icon_padding = 10
    frame_width = 2
    frame_color = "#89b4fa"
    separator_color = frame
    sort = yes
    idle_threshold = 120
    font = JetBrains Mono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 32
    max_icon_size = 64
    icon_path = /usr/share/icons/hicolor
    sticky_history = yes
    history_length = 20
    dmenu = /usr/bin/rofi -dmenu -p dunst:
    browser = /usr/bin/xdg-open
    always_run_script = true
    title = Dunst
    class = Dunst
    ignore_dbusclose = false
    force_xwayland = false
    corner_radius = 10

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 10

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 10

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#f38ba8"
    frame_color = "#f38ba8"
    timeout = 0
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    
    msg_ok "Dunst configurado"
}

#==============================================================================
# CONFIGURACIÓN KITTY
#==============================================================================

configure_kitty() {
    msg_step "Configurando Kitty"
    
    local config_dir="$TARGET_HOME/.config/kitty"
    backup_config "$config_dir"
    
    cat > "$config_dir/kitty.conf" <<'EOF'
#==============================================================================
# Kitty Configuration - Catppuccin Mocha
#==============================================================================

# Fuente
font_family JetBrains Mono Nerd Font
font_size 12.0

# Transparencia
background_opacity 0.85

# Colores Catppuccin Mocha
foreground #cdd6f4
background #1e1e2e
selection_foreground #1e1e2e
selection_background #45475a
cursor #f5e0dc
cursor_text_color #1e1e2e

# Colores ANSI
color0 #45475a
color1 #f38ba8
color2 #a6e3a1
color3 #f9e2af
color4 #89b4fa
color5 #cba6f7
color6 #94e2d5
color7 #bac2de
color8 #585b70
color9 #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #cba6f7
color14 #94e2d5
color15 #a6adc8

# Scrollback
scrollback_lines 10000
scrollback_pager less +G -R

# Mouse
mouse_hide_wait 3.0

# Ventana
window_padding_width 4
confirm_os_window_close 0

# Cursor
cursor_shape beam
cursor_blink_interval 0.5

# URL
url_color #89b4fa
url_style curly

# Bell
enable_audio_bell no
visual_bell_duration 0.0

# Rendimiento
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Misc
shell_integration enabled
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    
    msg_ok "Kitty configurado"
}

#==============================================================================
# CONFIGURACIÓN GTK
#==============================================================================

configure_gtk() {
    msg_step "Configurando GTK"
    
    # GTK 3.0
    local gtk3_dir="$TARGET_HOME/.config/gtk-3.0"
    backup_config "$gtk3_dir"
    
    cat > "$gtk3_dir/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Catppuccin-Mocha
gtk-icon-theme-name=Tela-circle
gtk-font-name=JetBrains Mono Nerd Font 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

    # GTK 4.0
    local gtk4_dir="$TARGET_HOME/.config/gtk-4.0"
    backup_config "$gtk4_dir"
    
    cat > "$gtk4_dir/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Catppuccin-Mocha
gtk-icon-theme-name=Tela-circle
gtk-font-name=JetBrains Mono Nerd Font 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$gtk3_dir" "$gtk4_dir"
    
    msg_ok "GTK configurado"
}

#==============================================================================
# CONFIGURACIÓN XINITRC
#==============================================================================

configure_xinitrc() {
    msg_step "Configurando ~/.xinitrc"
    
    local xinitrc="$TARGET_HOME/.xinitrc"
    [[ -f "$xinitrc" ]] && cp "$xinitrc" "$BACKUP_DIR/.xinitrc.backup" 2>/dev/null || true
    
    cat > "$xinitrc" <<'EOF'
#!/bin/sh
#==============================================================================
# ~/.xinitrc - Catppuccin BSPWM
#==============================================================================

# Cargar recursos de X
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Variables de entorno
export QT_QPA_PLATFORMTHEME=gtk2
export GTK_THEME=Catppuccin-Mocha
export ICON_THEME=Tela-circle

# Iniciar sesión de clave
export $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)

# Polkit
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Iniciar BSPWM
exec bspwm
EOF

    chown "$TARGET_USER:$TARGET_USER" "$xinitrc"
    chmod +x "$xinitrc"
    
    msg_ok "~/.xinitrc configurado"
}

#==============================================================================
# CONFIGURACIÓN XRESOURCES
#==============================================================================

configure_xresources() {
    msg_step "Configurando ~/.Xresources"
    
    local xresources="$TARGET_HOME/.Xresources"
    [[ -f "$xresources" ]] && cp "$xresources" "$BACKUP_DIR/.Xresources.backup" 2>/dev/null || true
    
    cat > "$xresources" <<'EOF'
!==============================================================================
! Xresources - Catppuccin Mocha
!==============================================================================

! Colores generales
*background: #1e1e2e
*foreground: #cdd6f4
*cursorColor: #f5e0dc

! Colores ANSI
*color0:  #45475a
*color1:  #f38ba8
*color2:  #a6e3a1
*color3:  #f9e2af
*color4:  #89b4fa
*color5:  #cba6f7
*color6:  #94e2d5
*color7:  #bac2de
*color8:  #585b70
*color9:  #f38ba8
*color10: #a6e3a1
*color11: #f9e2af
*color12: #89b4fa
*color13: #cba6f7
*color14: #94e2d5
*color15: #a6adc8

! Configuración de XTerm/UXTerm
XTerm*faceName: JetBrains Mono Nerd Font
XTerm*faceSize: 11
XTerm*background: #1e1e2e
XTerm*foreground: #cdd6f4
XTerm*selectToClipboard: true

! UXTerm
UXTerm*faceName: JetBrains Mono Nerd Font
UXTerm*faceSize: 11
UXTerm*background: #1e1e2e
UXTerm*foreground: #cdd6f4
EOF

    chown "$TARGET_USER:$TARGET_USER" "$xresources"
    
    msg_ok "~/.Xresources configurado"
}

#==============================================================================
# SCRIPTS PERSONALIZADOS
#==============================================================================

setup_scripts() {
    msg_step "Creando scripts personalizados"
    
    local bin_dir="$TARGET_HOME/.local/bin"
    
    # Script launch_polybar
    cat > "$bin_dir/launch_polybar" <<'EOF'
#!/usr/bin/env bash
#==============================================================================
# launch_polybar - Inicia polybar en todos los monitores activos
#==============================================================================

killall -q polybar

# Esperar a que terminen
while pgrep -u "$UID" -x polybar >/dev/null; do
    sleep 0.5
done

# Detectar monitores y lanzar polybar
if type "xrandr" >/dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR="$m" polybar --reload main &
    done
else
    polybar --reload main &
fi
EOF
    chmod +x "$bin_dir/launch_polybar"
    
    # Script wallpaper_setup
    cat > "$bin_dir/wallpaper_setup" <<'EOF'
#!/usr/bin/env bash
#==============================================================================
# wallpaper_setup - Configura el wallpaper
#==============================================================================

WALLPAPER_DIR="$HOME/Pictures/wallpapers"

# Crear directorio si no existe
mkdir -p "$WALLPAPER_DIR"

# Buscar wallpapers disponibles
if [[ -d "$WALLPAPER_DIR" ]]; then
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)
fi

# Si hay wallpaper, aplicarlo
if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    feh --bg-scale "$WALLPAPER"
else
    # Fondo de respaldo (gradiente sólido Catppuccin)
    xsetroot -solid "#1e1e2e"
fi
EOF
    chmod +x "$bin_dir/wallpaper_setup"
    
    # Script statusbar_launcher
    cat > "$bin_dir/statusbar_launcher" <<'EOF'
#!/usr/bin/env bash
#==============================================================================
# statusbar_launcher - Inicia servicios de la barra de estado
#==============================================================================

# Polybar
~/.local/bin/launch_polybar

# Dunst
killall -q dunst
dunst &

# NetworkManager applet
killall -q nm-applet
nm-applet &
EOF
    chmod +x "$bin_dir/statusbar_launcher"
    
    # Script de inicio rápido
    cat > "$bin_dir/start-bspwm" <<'EOF'
#!/usr/bin/env bash
#==============================================================================
# start-bspwm - Script de inicio rápido del entorno
#==============================================================================

echo "Iniciando entorno BSPWM + Catppuccin..."

# Verificar X
if [[ -z "$DISPLAY" ]]; then
    echo "Iniciando X con startx..."
    exec startx
else
    echo "X ya está corriendo. Reiniciando bspwm..."
    bspc wm -r
fi
EOF
    chmod +x "$bin_dir/start-bspwm"
    
    chown -R "$TARGET_USER:$TARGET_USER" "$bin_dir"
    
    msg_ok "Scripts creados"
}

#==============================================================================
# DESCARGA DE WALLPAPERS
#==============================================================================

download_wallpaper() {
    msg_step "Descargando wallpapers de Catppuccin"
    
    local wallpaper_dir="$TARGET_HOME/Pictures/wallpapers"
    mkdir -p "$wallpaper_dir"
    
    # Clonar repo temporalmente
    local temp_dir="/tmp/catppuccin-wallpapers"
    rm -rf "$temp_dir"
    
    msg_info "Clonando repositorio de wallpapers..."
    if git clone --depth 1 https://github.com/zhichaoh/catppuccin-wallpapers.git "$temp_dir" 2>/dev/null; then
        # Copiar wallpapers de misc
        if [[ -d "$temp_dir/misc" ]]; then
            cp "$temp_dir/misc"/*.{jpg,jpeg,png,webp} "$wallpaper_dir/" 2>/dev/null || true
            msg_ok "Wallpapers descargados"
        fi
        
        # Limpiar
        rm -rf "$temp_dir"
    else
        msg_warn "No se pudo clonar el repositorio. Usando fondo predeterminado."
    fi
    
    # Si no hay wallpapers, crear uno de respaldo
    if [[ ! $(ls -A "$wallpaper_dir" 2>/dev/null) ]]; then
        msg_info "Creando wallpaper de respaldo..."
        # Crear un wallpaper sólido con ImageMagick si está disponible
        if command -v convert &>/dev/null; then
            convert -size 1920x1080 xc:"#1e1e2e" "$wallpaper_dir/catppuccin-default.png"
        fi
    fi
    
    chown -R "$TARGET_USER:$TARGET_USER" "$wallpaper_dir"
    
    # Aplicar wallpaper
    run_as_user "~/.local/bin/wallpaper_setup" || msg_warn "No se pudo aplicar wallpaper"
    
    msg_ok "Wallpapers configurados"
}

#==============================================================================
# POST-INSTALACIÓN
#==============================================================================

post_install() {
    msg_step "Post-instalación"
    
    # Habilitar NetworkManager
    msg_info "Habilitando NetworkManager..."
    systemctl enable NetworkManager --now
    msg_ok "NetworkManager habilitado"
    
    # Habilitar servicios de audio
    msg_info "Habilitando servicios de audio (pipewire)..."
    run_as_user "systemctl --user enable pipewire pipewire-pulse wireplumber --now" || true
    msg_ok "Servicios de audio habilitados"
    
    # Agregar usuario a grupos
    msg_info "Agregando usuario a grupos necesarios..."
    usermod -aG audio,video,network,storage,wheel "$TARGET_USER"
    msg_ok "Usuario agregado a grupos"
    
    # Configurar bashrc
    configure_bashrc
    
    # Configurar user-dirs
    msg_info "Configurando directorios de usuario..."
    cat > "$TARGET_HOME/.config/user-dirs.dirs" <<EOF
XDG_DESKTOP_DIR="$TARGET_HOME/Desktop"
XDG_DOWNLOAD_DIR="$TARGET_HOME/Downloads"
XDG_TEMPLATES_DIR="$TARGET_HOME/Templates"
XDG_PUBLICSHARE_DIR="$TARGET_HOME/Public"
XDG_DOCUMENTS_DIR="$TARGET_HOME/Documents"
XDG_MUSIC_DIR="$TARGET_HOME/Music"
XDG_PICTURES_DIR="$TARGET_HOME/Pictures"
XDG_VIDEOS_DIR="$TARGET_HOME/Videos"
EOF
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/user-dirs.dirs"
    run_as_user "xdg-user-dirs-update" || true
    
    # Configurar rofi theme básico
    configure_rofi
    
    msg_ok "Post-instalación completada"
}

configure_bashrc() {
    msg_info "Configurando ~/.bashrc..."
    
    local bashrc="$TARGET_HOME/.bashrc"
    [[ -f "$bashrc" ]] && cp "$bashrc" "$BACKUP_DIR/.bashrc.backup" 2>/dev/null || true
    
    cat >> "$bashrc" <<'EOF'

#==============================================================================
# Aliases útiles - BSPWM + Catppuccin
#==============================================================================

# Navegación
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'

# Listado
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

# Utilidades
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Pacman
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias search='pacman -Ss'
alias orphans='pacman -Qdt'

# BSPWM
alias bspc-reload='bspc wm -r'
alias sxhkd-reload='pkill -USR1 -x sxhkd'

# Red
alias wifi='nmtui'

# Editor
alias v='nvim 2>/dev/null || vim'

# Info del sistema
alias fetch='fastfetch 2>/dev/null || neofetch 2>/dev/null || echo "Instala fastfetch"'

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Variables de entorno
export EDITOR="nvim 2>/dev/null || vim"
export VISUAL="$EDITOR"
export BROWSER="firefox 2>/dev/null || brave 2>/dev/null || echo 'Navegador no instalado'"

# Colores del prompt (Catppuccin Mocha)
export PS1='\[\033[38;5;137m\]\u\[\033[38;5;111m\]@\[\033[38;5;137m\]\h\[\033[0m\]:\[\033[38;5;111m\]\w\[\033[0m\]\$ '
EOF

    chown "$TARGET_USER:$TARGET_USER" "$bashrc"
    msg_ok "~/.bashrc configurado"
}

configure_rofi() {
    msg_step "Configurando Rofi"
    
    local config_dir="$TARGET_HOME/.config/rofi"
    backup_config "$config_dir"
    
    mkdir -p "$config_dir"
    
    # Tema básico de Catppuccin para rofi
    cat > "$config_dir/catppuccin-mocha.rasi" <<'EOF'
* {
    bg: #1e1e2e;
    bg-alt: #313244;
    fg: #cdd6f4;
    blue: #89b4fa;
    lavender: #b4befe;
    sapphire: #74c7ec;
    sky: #89dceb;
    teal: #94e2d5;
    green: #a6e3a1;
    yellow: #f9e2af;
    peach: #fab387;
    maroon: #eba0ac;
    red: #f38ba8;
    mauve: #cba6f7;
    pink: #f5c2e7;
    flamingo: #f2cdcd;
    rosewater: #f5e0dc;

    background-color: @bg;
    text-color: @fg;
}

window {
    width: 600;
    height: 400;
    border: 2px;
    border-color: @blue;
    border-radius: 10;
    background-color: @bg;
    padding: 20;
}

mainbox {
    background-color: @bg;
    children: [inputbar, listview];
    spacing: 15;
}

inputbar {
    background-color: @bg-alt;
    border-radius: 8;
    padding: 10;
    children: [prompt, entry];
}

prompt {
    background-color: transparent;
    text-color: @blue;
    font: "JetBrains Mono Nerd Font 12";
}

entry {
    background-color: transparent;
    text-color: @fg;
    font: "JetBrains Mono Nerd Font 12";
    placeholder: "Buscar...";
    placeholder-color: @bg-alt;
}

listview {
    background-color: @bg;
    columns: 1;
    lines: 8;
    spacing: 5;
    dynamic: true;
    scrollbar: false;
}

element {
    background-color: transparent;
    padding: 8;
    border-radius: 6;
}

element selected {
    background-color: @blue;
    text-color: @bg;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    font: "JetBrains Mono Nerd Font 11";
}
EOF

    # Configuración principal
    cat > "$config_dir/config.rasi" <<'EOF'
configuration {
    modi: "drun,run,window";
    font: "JetBrains Mono Nerd Font 11";
    show-icons: true;
    icon-theme: "Tela-circle";
    terminal: "kitty";
    drun-display-format: "{name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: "  Apps  ";
    display-run: "  Run  ";
    display-window: "  Window  ";
}

@theme "catppuccin-mocha"
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$config_dir"
    msg_ok "Rofi configurado"
}

#==============================================================================
# INTERACTIVIDAD
#==============================================================================

ask_optional() {
    msg_step "Paquetes opcionales"
    
    # yay
    read -rp "¿Deseas instalar yay (AUR helper)? [s/N]: " ans
    if [[ "$ans" =~ ^[Ss]$ ]]; then
        INSTALL_YAY=true
    fi
    
    # Navegador
    echo "Navegadores disponibles:"
    echo "  1) firefox"
    echo "  2) brave (brave-bin desde AUR)"
    echo "  3) Ninguno"
    read -rp "Selecciona navegador [1-3]: " browser_choice
    case "$browser_choice" in
        1) INSTALL_BROWSER="firefox" ;;
        2) INSTALL_BROWSER="brave-bin" ;;
        *) INSTALL_BROWSER="" ;;
    esac
    
    # Editor
    echo "Editores disponibles:"
    echo "  1) neovim"
    echo "  2) vim"
    echo "  3) Ninguno"
    read -rp "Selecciona editor [1-3]: " editor_choice
    case "$editor_choice" in
        1) INSTALL_EDITOR="neovim" ;;
        2) INSTALL_EDITOR="vim" ;;
        *) INSTALL_EDITOR="" ;;
    esac
    
    # Utilidades
    read -rp "¿Deseas instalar utilidades adicionales (htop, fastfetch, )? [s/N]: " ans
    if [[ "$ans" =~ ^[Ss]$ ]]; then
        INSTALL_UTILS=true
    fi
}

#==============================================================================
# RESUMEN FINAL
#==============================================================================

show_summary() {
    msg_step "Resumen de instalación"
    
    echo -e "${CLR_GREEN}╔══════════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_GREEN}║              INSTALACIÓN COMPLETADA                          ║${CLR_RESET}"
    echo -e "${CLR_GREEN}╚══════════════════════════════════════════════════════════════╝${CLR_RESET}"
    echo ""
    echo -e "${CLR_CYAN}Usuario configurado:${CLR_RESET} $TARGET_USER"
    echo -e "${CLR_CYAN}Directorio home:${CLR_RESET} $TARGET_HOME"
    echo ""
    echo -e "${CLR_CYAN}Componentes instalados:${CLR_RESET}"
    echo "  ✓ Xorg (xorg-server, xorg-xinit)"
    echo "  ✓ BSPWM (gestor de ventanas)"
    echo "  ✓ SXHKD (atajos de teclado)"
    echo "  ✓ Kitty (terminal)"
    echo "  ✓ Polybar (barra de estado)"
    echo "  ✓ Rofi (lanzador)"
    echo "  ✓ Picom (compositor)"
    echo "  ✓ Dunst (notificaciones)"
    echo "  ✓ Feh (visualizador de imágenes)"
    echo "  ✓ Thunar (gestor de archivos)"
    echo "  ✓ NetworkManager"
    echo "  ✓ PipeWire (audio)"
    echo "  ✓ Fuentes Nerd Fonts"
    echo ""
    
    if [[ "$INSTALL_YAY" == true ]]; then
        echo "  ✓ yay (AUR helper)"
    fi
    if [[ -n "$INSTALL_BROWSER" ]]; then
        echo "  ✓ Navegador: $INSTALL_BROWSER"
    fi
    if [[ -n "$INSTALL_EDITOR" ]]; then
        echo "  ✓ Editor: $INSTALL_EDITOR"
    fi
    if [[ "$INSTALL_UTILS" == true ]]; then
        echo "  ✓ Utilidades: htop, fastfetch, ranger"
    fi
    
    echo ""
    echo -e "${CLR_CYAN}Configuraciones creadas:${CLR_RESET}"
    echo "  ~/.config/bspwm/bspwmrc"
    echo "  ~/.config/sxhkd/sxhkdrc"
    echo "  ~/.config/polybar/config.ini"
    echo "  ~/.config/picom/picom.conf"
    echo "  ~/.config/dunst/dunstrc"
    echo "  ~/.config/kitty/kitty.conf"
    echo "  ~/.config/gtk-3.0/settings.ini"
    echo "  ~/.config/gtk-4.0/settings.ini"
    echo "  ~/.config/rofi/config.rasi"
    echo "  ~/.xinitrc"
    echo "  ~/.Xresources"
    echo "  ~/.bashrc (aliases añadidos)"
    echo ""
    echo -e "${CLR_CYAN}Scripts personalizados:${CLR_RESET}"
    echo "  ~/.local/bin/launch_polybar"
    echo "  ~/.local/bin/wallpaper_setup"
    echo "  ~/.local/bin/statusbar_launcher"
    echo "  ~/.local/bin/start-bspwm"
    echo ""
    echo -e "${CLR_YELLOW}Para iniciar el entorno gráfico:${CLR_RESET}"
    echo "  1. Cierra sesión de root: exit"
    echo "  2. Inicia sesión como $TARGET_USER"
    echo "  3. Ejecuta: startx"
    echo ""
    echo -e "${CLR_YELLOW}O usa el comando:${CLR_RESET} ~/.local/bin/start-bspwm"
    echo ""
    
    if [[ -d "$BACKUP_DIR" && $(ls -A "$BACKUP_DIR" 2>/dev/null) ]]; then
        echo -e "${CLR_YELLOW}Backups guardados en:${CLR_RESET} $BACKUP_DIR"
    fi
    
    echo ""
    read -rp "¿Deseas reiniciar el sistema ahora? [s/N]: " reboot
    if [[ "$reboot" =~ ^[Ss]$ ]]; then
        msg_info "Reiniciando en 5 segundos..."
        sleep 5
        reboot
    else
        msg_ok "Instalación finalizada. Reinicia manualmente cuando estés listo."
    fi
}

#==============================================================================
# FUNCIÓN PRINCIPAL
#==============================================================================

main() {
    # Inicializar log
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== Inicio de instalación BSPWM + Catppuccin ===" > "$LOG_FILE"
    echo "Fecha: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Banner
    echo -e "${CLR_MAGENTA}"
    cat << "BANNER"
   ____  ____  __        ________  __  ___________  _  __
  / __ )/ __ \/ /_      / ____/\ \/ / / / ___/ __ \| |/ /
 / __  / /_/ / __/____/ / __   \  / / /\__ \/ /_/ /|   /
/ /_/ / ____/ /_/_____/ /_/ /   / /_/ /___/ / _, _//   |
/_____/_/    \__/      \____/   /_____//____/_/ |_//_/|_|
                                                          
   Catppuccin Mocha Theme - Arch Linux BSPWM Setup
BANNER
    echo -e "${CLR_RESET}"
    
    # Verificaciones iniciales
    check_root
    check_internet
    detect_user
    
    # Preguntar paquetes opcionales
    ask_optional
    
    # Actualizar sistema
    update_system
    
    # Instalar yay primero si se necesita
    if [[ "$INSTALL_YAY" == true ]]; then
        install_yay
    fi
    
    # Instalar paquetes
    install_packages
    
    # Crear estructura
    create_directories
    
    # Configurar todo
    configure_bspwm
    configure_sxhkd
    configure_polybar
    configure_picom
    configure_dunst
    configure_kitty
    configure_gtk
    configure_xinitrc
    configure_xresources
    
    # Scripts y wallpapers
    setup_scripts
    download_wallpaper
    
    # Post-instalación
    post_install
    
    # Resumen
    show_summary
}

# Ejecutar main
main "$@"
SCRIPT_EOF

chmod +x setup-catppuccin-bspwm.sh
