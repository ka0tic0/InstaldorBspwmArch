#!/bin/bash

#############################################################################
# Setup Catppuccin BSPWM - Script de instalación automática para Arch Linux
# Autor: Auto-generado
# Descripción: Instalación y configuración completa de bspwm con tema 
#              Catppuccin Mocha desde una instalación base de Arch Linux
#############################################################################

set -e  # Detener si hay un error crítico

#############################################################################
# DEFINICIÓN DE COLORES
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Colores Catppuccin Mocha
CATPPUCCIN_BASE="#1e1e2e"
CATPPUCCIN_SURFACE="#313244"
CATPPUCCIN_OVERLAY="#45475a"
CATPPUCCIN_TEXT="#cdd6f4"
CATPPUCCIN_SUBTEXT="#a6adc8"
CATPPUCCIN_BLUE="#89b4fa"
CATPPUCCIN_GREEN="#a6e3a1"
CATPPUCCIN_RED="#f38ba8"
CATPPUCCIN_YELLOW="#f9e2af"
CATPPUCCIN_MAUVE="#cba6f7"
CATPPUCCIN_CYAN="#94e2d5"

#############################################################################
# VARIABLES GLOBALES
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$(eval echo ~$(whoami))"
CONFIG_DIR="${HOME_DIR}/.config"
LOCAL_BIN="${HOME_DIR}/.local/bin"
PICTURES_DIR="${HOME_DIR}/Pictures"
WALLPAPERS_DIR="${PICTURES_DIR}/wallpapers"
BACKUP_DIR="${CONFIG_DIR}/.backup"

#############################################################################
# FUNCIONES DE UTILIDAD
#############################################################################

# Función para mostrar mensajes con color
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Función para hacer pausa con mensaje
pause_msg() {
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Función para confirmar acción
confirm() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$(echo -e ${CYAN}${prompt}${NC} '[y/n]: ')" response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                print_warning "Please answer yes or no."
                ;;
        esac
    done
}

#############################################################################
# VERIFICACIONES INICIALES
#############################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root"
        exit 1
    fi
    print_status "Ejecutándose como root"
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        print_error "No hay conexión a internet. Por favor verifica tu conexión."
        exit 1
    fi
    print_status "Conexión a internet verificada"
}

check_arch_linux() {
    if ! [ -f /etc/os-release ]; then
        print_error "No se puede verificar el SO"
        exit 1
    fi
    
    if ! grep -q "ID=arch" /etc/os-release; then
        print_warning "Este script está diseñado para Arch Linux"
    fi
    print_status "Arch Linux detectado"
}

#############################################################################
# INSTALACIÓN DE PAQUETES
#############################################################################

install_packages() {
    print_info "Iniciando instalación de paquetes..."
    
    # Actualizar sistema
    print_status "Actualizando sistema (pacman -Syu)..."
    pacman -Syu --noconfirm || print_error "Error en actualización del sistema"
    
    # Array de paquetes a instalar
    local packages=(
        # Servidor X
        "xorg-server" "xorg-xinit" "xorg-xrandr" "xorg-xsetroot"
        # BSPWM y hotkeys
        "bspwm" "sxhkd"
        # Terminal
        "kitty"
        # Barra de estado
        "polybar"
        # Lanzador
        "rofi"
        # Compositor
        "picom"
        # Notificaciones
        "dunst"
        # Visualizador y gestor de archivos
        "feh" "thunar" "thunar-volman"
        # Red
        "networkmanager" "network-manager-applet"
        # Audio
        "pipewire" "pipewire-pulse" "pipewire-alsa" "wireplumber" "pactl"
        # Fuentes
        "ttf-jetbrains-mono-nerd" "noto-fonts" "noto-fonts-emoji" "ttf-font-awesome" "ttf-nerd-fonts-symbols"
        # Temas
        "lxappearance"
        # Utilidades
        "git" "curl" "wget" "base-devel" "sudo"
        # Herramientas de screenshot
        "scrot" "xclip"
        # Gestor de sesiones
        "elogind"
    )
    
    print_info "Instalando paquetes del repositorio oficial..."
    for package in "${packages[@]}"; do
        if pacman -Q "$package" &>/dev/null; then
            print_warning "$package ya está instalado"
        else
            print_status "Instalando $package..."
            pacman -S "$package" --noconfirm || print_error "Error instalando $package"
        fi
    done
    
    print_status "Paquetes del repositorio oficial instalados"
}

install_yay() {
    if command -v yay &> /dev/null; then
        print_warning "yay ya está instalado"
        return
    fi
    
    if ! confirm "¿Deseas instalar yay (AUR helper)?"; then
        print_warning "yay no será instalado. Algunos paquetes no estarán disponibles"
        return
    fi
    
    print_info "Instalando yay..."
    
    # Crear usuario temporal para compilar yay
    local temp_user="builduser"
    
    if ! id "$temp_user" &>/dev/null; then
        useradd -m "$temp_user" || print_error "No se pudo crear usuario temporal"
        echo "$temp_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$temp_user
    fi
    
    # Compilar yay
    su - "$temp_user" -c '
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
    ' || print_error "Error compilando yay"
    
    # Limpiar usuario temporal
    userdel -r "$temp_user" 2>/dev/null || true
    sed -i "/$temp_user/d" /etc/sudoers.d/$temp_user 2>/dev/null || true
    
    print_status "yay instalado correctamente"
}

install_aur_packages() {
    if ! command -v yay &> /dev/null; then
        print_warning "yay no está disponible. Saltando paquetes AUR"
        return
    fi
    
    local aur_packages=(
        "catppuccin-gtk-theme-mocha"
        "tela-circle-icon-theme-nord"
    )
    
    print_info "Instalando paquetes AUR..."
    
    for package in "${aur_packages[@]}"; do
        if yay -Q "$package" &>/dev/null; then
            print_warning "$package ya está instalado"
        else
            print_status "Instalando $package desde AUR..."
            yay -S "$package" --noconfirm || print_warning "Error instalando $package (AUR)"
        fi
    done
}

install_optional_packages() {
    print_info "¿Deseas instalar paquetes opcionales?"
    
    # Firefox
    if confirm "¿Instalar Firefox?"; then
        print_status "Instalando Firefox..."
        pacman -S firefox --noconfirm
    fi
    
    # Brave
    if confirm "¿Instalar Brave Browser?"; then
        if command -v yay &> /dev/null; then
            print_status "Instalando Brave..."
            yay -S brave-browser --noconfirm || print_warning "Error instalando Brave"
        else
            print_warning "yay no disponible. Saltando Brave"
        fi
    fi
    
    # Neovim
    if confirm "¿Instalar Neovim?"; then
        print_status "Instalando Neovim..."
        pacman -S neovim --noconfirm
    fi
    
    # htop
    if confirm "¿Instalar htop?"; then
        print_status "Instalando htop..."
        pacman -S htop --noconfirm
    fi
    
    # fastfetch
    if confirm "¿Instalar fastfetch?"; then
        print_status "Instalando fastfetch..."
        pacman -S fastfetch --noconfirm || pacman -S neofetch --noconfirm
    fi
}

#############################################################################
# CREACIÓN DE DIRECTORIOS
#############################################################################

setup_directories() {
    print_info "Creando estructura de directorios..."
    
    local dirs=(
        "${CONFIG_DIR}/bspwm"
        "${CONFIG_DIR}/sxhkd"
        "${CONFIG_DIR}/polybar"
        "${CONFIG_DIR}/picom"
        "${CONFIG_DIR}/dunst"
        "${CONFIG_DIR}/rofi"
        "${CONFIG_DIR}/kitty"
        "${CONFIG_DIR}/gtk-3.0"
        "${CONFIG_DIR}/gtk-4.0"
        "${LOCAL_BIN}"
        "${WALLPAPERS_DIR}"
        "${BACKUP_DIR}"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_warning "$dir ya existe"
        else
            mkdir -p "$dir"
            print_status "Creado: $dir"
        fi
    done
}

#############################################################################
# GENERACIÓN DE ARCHIVOS DE CONFIGURACIÓN
#############################################################################

configure_bspwm() {
    print_info "Configurando bspwm..."
    
    local bspwmrc="${CONFIG_DIR}/bspwm/bspwmrc"
    
    # Backup de configuración existente
    if [ -f "$bspwmrc" ]; then
        cp "$bspwmrc" "${BACKUP_DIR}/bspwmrc.backup"
        print_warning "Backup de bspwmrc guardado"
    fi
    
    cat > "$bspwmrc" << 'EOF'
#!/bin/bash

#############################################################################
# BSPWM Configuration File
# Tema: Catppuccin Mocha
#############################################################################

# Establece el número de escritorios por monitor
bspc monitor -d I:Web II:Term III:Code IV:Misc

# Configuración de gaps (espacios entre ventanas)
bspc config window_gap 10
bspc config left_padding 0
bspc config right_padding 0
bspc config top_padding 30
bspc config bottom_padding 0

# Bordes de ventanas
bspc config border_width 2
bspc config focused_border_color "#89b4fa"
bspc config normal_border_color "#45475a"
bspc config active_border_color "#89b4fa"

# Divisiones y split
bspc config split_ratio 0.50
bspc config automatic_scheme alternate

# Ventanas flotantes
bspc config pointer_follows_focus true
bspc config focus_follows_pointer false

# Reglas para ventanas específicas
# Rofi - flotante, centrado
bspc rule -a Rofi state=floating
# Thunar - flotante
bspc rule -a Thunar state=floating
# Pavucontrol - flotante
bspc rule -a Pavucontrol state=floating
# Screenshot tool - flotante
bspc rule -a Scrot state=floating

# Iniciar sxhkd (gestor de atajos)
pgrep -x sxhkd > /dev/null || sxhkd &

# Iniciar compositor (picom)
pgrep -x picom > /dev/null || picom --daemon

# Iniciar demonio de notificaciones (dunst)
pgrep -x dunst > /dev/null || dunst &

# Iniciar gestor de red
pgrep -x nm-applet > /dev/null || nm-applet --indicator &

# Iniciar polybar
"$HOME/.local/bin/launch_polybar" &

# Configurar pantalla con xrandr
# Descomenta y personaliza según tu configuración
# xrandr --output HDMI-1 --auto --left-of eDP-1

# Establecer wallpaper
if [ -f "$HOME/Pictures/wallpapers/wallpaper.png" ]; then
    feh --bg-scale "$HOME/Pictures/wallpapers/wallpaper.png"
else
    feh --bg-color "$1e1e2e"
fi

# Esperar a que todo se inicie
sleep 1
EOF
    
    chmod +x "$bspwmrc"
    print_status "bspwmrc configurado y con permisos de ejecución"
}

configure_sxhkd() {
    print_info "Configurando sxhkd..."
    
    local sxhkdrc="${CONFIG_DIR}/sxhkd/sxhkdrc"
    
    # Backup
    if [ -f "$sxhkdrc" ]; then
        cp "$sxhkdrc" "${BACKUP_DIR}/sxhkdrc.backup"
    fi
    
    cat > "$sxhkdrc" << 'EOF'
#############################################################################
# SXHKD Configuration - Atajos de teclado
# Tema: Catppuccin Mocha
#############################################################################

# Cambiar modo focusmode (super + alt + tab)
super + alt + Tab
    bspc desktop -l next

#############################################################################
# BSPWM HOTKEYS
#############################################################################

# Terminar bspwm
super + alt + Escape
    pkill -x bspwm

# Cerrar ventana
super + q
    bspc node -c

# Alternar entre ventana flotante y tiled
super + t
    bspc node -t ~tiled

# Alternar fullscreen
super + f
    bspc node -t ~fullscreen

# Alternar entre layouts
super + space
    bspc desktop -l next

# Cambiar entre monocle y tiled
super + m
    bspc desktop -l monocle

# Expandir ventana (izquierda)
super + alt + Left
    bspc node -z left -20 0

# Expandir ventana (derecha)
super + alt + Right
    bspc node -z right 20 0

# Expandir ventana (arriba)
super + alt + Up
    bspc node -z top 0 -20

# Expandir ventana (abajo)
super + alt + Down
    bspc node -z bottom 0 20

# Contraer ventana (izquierda)
super + alt + shift + Left
    bspc node -z left 20 0

# Contraer ventana (derecha)
super + alt + shift + Right
    bspc node -z right -20 0

# Contraer ventana (arriba)
super + alt + shift + Up
    bspc node -z top 0 20

# Contraer ventana (abajo)
super + alt + shift + Down
    bspc node -z bottom 0 -20

# Resetear tamaño de ventana
super + equal
    bspc node -z reset

#############################################################################
# NAVEGACIÓN DE VENTANAS (VIM KEYS)
#############################################################################

# Cambiar enfoque (izquierda)
super + h
    bspc node -f west

# Cambiar enfoque (derecha)
super + l
    bspc node -f east

# Cambiar enfoque (arriba)
super + k
    bspc node -f north

# Cambiar enfoque (abajo)
super + j
    bspc node -f south

# Cambiar enfoque a ventana anterior
super + grave
    bspc node -f last

# Cambiar enfoque a escritorio anterior
super + Tab
    bspc desktop -f last

# Mover ventana (izquierda)
super + shift + h
    bspc node -s west

# Mover ventana (derecha)
super + shift + l
    bspc node -s east

# Mover ventana (arriba)
super + shift + k
    bspc node -s north

# Mover ventana (abajo)
super + shift + j
    bspc node -s south

#############################################################################
# CAMBIAR ENTRE ESCRITORIOS
#############################################################################

# Ir a escritorio 1
super + 1
    bspc desktop -f 1

# Ir a escritorio 2
super + 2
    bspc desktop -f 2

# Ir a escritorio 3
super + 3
    bspc desktop -f 3

# Ir a escritorio 4
super + 4
    bspc desktop -f 4

# Mover ventana a escritorio 1
super + shift + 1
    bspc node -d 1

# Mover ventana a escritorio 2
super + shift + 2
    bspc node -d 2

# Mover ventana a escritorio 3
super + shift + 3
    bspc node -d 3

# Mover ventana a escritorio 4
super + shift + 4
    bspc node -d 4

#############################################################################
# GAPS (ESPACIOS ENTRE VENTANAS)
#############################################################################

# Aumentar gaps
super + ctrl + h
    bspc config -d focused window_gap $(($(bspc config window_gap) + 5))

# Disminuir gaps
super + ctrl + l
    bspc config -d focused window_gap $(( $(bspc config window_gap) - 5 < 0 ? 0 : $(bspc config window_gap) - 5))

# Resetear gaps
super + ctrl + g
    bspc config window_gap 10

#############################################################################
# APLICACIONES
#############################################################################

# Abrir terminal (kitty)
super + Return
    kitty

# Mostrador de aplicaciones (rofi -drun)
super + d
    rofi -show drun -theme Catppuccin-Mocha

# Ejecutor de comandos (rofi -run)
super + r
    rofi -show run -theme Catppuccin-Mocha

# Selector de ventanas (rofi -window)
super + w
    rofi -show window -theme Catppuccin-Mocha

# Navegador de archivos (thunar)
super + e
    thunar

#############################################################################
# MULTIMEDIA
#############################################################################

# Bajar volumen
XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

# Subir volumen
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

# Silenciar/Dessilenciar
XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# Anteriora música
XF86AudioPrev
    playerctl previous 2>/dev/null || true

# Pausa/Reproducción
XF86AudioPlay
    playerctl play-pause 2>/dev/null || true

# Siguiente música
XF86AudioNext
    playerctl next 2>/dev/null || true

#############################################################################
# PANTALLA
#############################################################################

# Reducir brillo
XF86MonBrightnessDown
    brightnessctl set 5%- 2>/dev/null || true

# Aumentar brillo
XF86MonBrightnessUp
    brightnessctl set 5%+ 2>/dev/null || true

#############################################################################
# CAPTURAS DE PANTALLA
#############################################################################

# Captura de pantalla completa
Print
    scrot "$HOME/Pictures/screenshot-$(date +%s).png" && notify-send -u low -t 1000 "Screenshot guardado"

# Captura de región seleccionada
shift + Print
    scrot -s "$HOME/Pictures/screenshot-$(date +%s).png" && notify-send -u low -t 1000 "Screenshot guardado"

#############################################################################
# POWER MANAGEMENT
#############################################################################

# Apagar pantalla
XF86PowerOff
    systemctl poweroff

# Sleep
super + shift + End
    systemctl suspend

#############################################################################
# UTILIDADES
#############################################################################

# Abrir dmenu (si está instalado)
# super + p
#     dmenu_run

EOF
    
    print_status "sxhkdrc configurado"
}

configure_polybar() {
    print_info "Configurando polybar..."
    
    local polybar_config="${CONFIG_DIR}/polybar/config.ini"
    
    # Backup
    if [ -f "$polybar_config" ]; then
        cp "$polybar_config" "${BACKUP_DIR}/polybar-config.backup"
    fi
    
    cat > "$polybar_config" << 'EOF'
;==========================================================
; Polybar Configuration - Catppuccin Mocha
;==========================================================

[colors]
; Catppuccin Mocha
base = #1e1e2e
surface = #313244
overlay = #45475a
text = #cdd6f4
subtext = #a6adc8
blue = #89b4fa
green = #a6e3a1
red = #f38ba8
yellow = #f9e2af
mauve = #cba6f7
cyan = #94e2d5

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 30
background = ${colors.base}
foreground = ${colors.text}
line-size = 2
line-color = ${colors.blue}
border-size = 0
border-color = ${colors.surface}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = JetBrains Mono Nerd Font:style=Regular:pixelsize=11;3
font-1 = Noto Color Emoji:scale=10;3

modules-left = bspwm xwindow
modules-center = date time
modules-right = pulseaudio network memory cpu battery

tray-position = right
tray-padding = 2
tray-background = ${colors.surface}

[module/bspwm]
type = internal/bspwm
format = <label-state> <label-monitor>
label-monitor = %name%
label-monitor-padding = 1
label-state = %name%
label-state-padding = 1
label-state-foreground = ${colors.text}
label-state-background = ${colors.surface}
label-state-underline = ${colors.blue}

label-focused = %name%
label-focused-padding = 1
label-focused-background = ${colors.blue}
label-focused-foreground = ${colors.base}
label-focused-underline = ${colors.yellow}

label-occupied = %name%
label-occupied-padding = 1
label-occupied-background = ${colors.overlay}
label-occupied-foreground = ${colors.text}

label-empty = %name%
label-empty-padding = 1
label-empty-background = ${colors.base}
label-empty-foreground = ${colors.subtext}

[module/xwindow]
type = internal/xwindow
label = %title:0:30:...%
label-foreground = ${colors.text}

[module/date]
type = internal/date
interval = 1
date = %d/%m/%Y
label = 📅 ${date}
label-foreground = ${colors.cyan}
label-padding = 1

[module/time]
type = internal/date
interval = 1
time = %H:%M:%S
label = 🕐 ${time}
label-foreground = ${colors.mauve}
label-padding = 1

[module/pulseaudio]
type = internal/pulseaudio
format-volume = 🔊 <label-volume>
label-volume = %percentage%%
label-volume-foreground = ${colors.green}
label-volume-padding = 1
label-muted = 🔇 Muted
label-muted-foreground = ${colors.red}
label-muted-padding = 1

[module/network]
type = internal/network
interface = ${env:IFACE:wlan0}
interval = 5
format-connected = 🌐 <label-connected>
format-disconnected = 🌐 Disconnected
label-connected = %essid% (%signal%%)
label-connected-foreground = ${colors.green}
label-connected-padding = 1
label-disconnected-foreground = ${colors.red}
label-disconnected-padding = 1

[module/memory]
type = internal/memory
interval = 3
format = 💾 <label>
label = %percentage_used%%
label-foreground = ${colors.yellow}
label-padding = 1

[module/cpu]
type = internal/cpu
interval = 2
format = ⚙️  <label>
label = %percentage%%
label-foreground = ${colors.red}
label-padding = 1

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC0
poll-interval = 5
format-charging = 🔌 <label-charging>
format-discharging = 🔋 <label-discharging>
label-charging = %percentage%%
label-charging-foreground = ${colors.green}
label-discharging = %percentage%%
label-discharging-foreground = ${colors.yellow}
label-padding = 1

EOF
    
    print_status "polybar config.ini configurado"
}

configure_picom() {
    print_info "Configurando picom..."
    
    local picom_config="${CONFIG_DIR}/picom/picom.conf"
    
    # Backup
    if [ -f "$picom_config" ]; then
        cp "$picom_config" "${BACKUP_DIR}/picom.conf.backup"
    fi
    
    cat > "$picom_config" << 'EOF'
#############################################################################
# Picom Configuration - Compositor X11
# Tema: Catppuccin Mocha
#############################################################################

# Backend rendering
backend = "glx"
glx-no-stencil = true
glx-no-rebind-pixmap = true

# VSync
vsync = true
dbus = false

#############################################################################
# SOMBRAS
#############################################################################

shadow = true
shadow-radius = 7
shadow-offset-x = -7
shadow-offset-y = -7
shadow-opacity = 0.5
shadow-red = 0.0
shadow-green = 0.0
shadow-blue = 0.0

# Excepciones de sombra
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_NET_WM_WINDOW_TYPE@:a *= '_NET_WM_WINDOW_TYPE_NOTIFICATION'"
];

#############################################################################
# OPACIDAD Y TRANSAPRENCIA
#############################################################################

active-opacity = 1.0;
inactive-opacity = 0.85;
frame-opacity = 0.8;

# Reglas específicas de opacidad
opacity-rule = [
    "80:class_g = 'kitty'",
    "90:class_g = 'Thunar'",
    "95:class_g = 'Firefox'",
];

#############################################################################
# REDONDEO DE ESQUINAS
#############################################################################

corner-radius = 10;
corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

#############################################################################
# DESVANECIMIENTO (FADING)
#############################################################################

fading = true
fade-delta = 4
fade-in-step = 0.03
fade-out-step = 0.03

#############################################################################
# TRANSICIONES
#############################################################################

transition-length = 300
transition-pow-x = 0.1
transition-pow-y = 0.1
transition-pow-w = 0.1
transition-pow-h = 0.1
size-transition = false

EOF
    
    print_status "picom.conf configurado"
}

configure_dunst() {
    print_info "Configurando dunst..."
    
    local dunstrc="${CONFIG_DIR}/dunst/dunstrc"
    
    # Backup
    if [ -f "$dunstrc" ]; then
        cp "$dunstrc" "${BACKUP_DIR}/dunstrc.backup"
    fi
    
    cat > "$dunstrc" << 'EOF'
#############################################################################
# Dunst Configuration - Daemon de notificaciones
# Tema: Catppuccin Mocha
#############################################################################

[global]
monitor = 0
follow = mouse
geometry = "300x100-10+30"
indicate_hidden = yes
shrink = no
transparency = 80
notification_height = 0
separator_height = 2
padding = 10
horizontal_padding = 10
text_icon_padding = 0
frame_width = 2
frame_color = "#89b4fa"
separator_color = "#313244"
sort = yes
idle_threshold = 120
font = JetBrains Mono Nerd Font 11
line_height = 0
markup = full
format = "<b>%s</b>\n%b"
alignment = left
vertical_alignment = center
show_age_threshold = 60
word_wrap = yes
ellipsize = middle
ignore_newline = no
stack_duplicates = true
hide_duplicate_count = false
show_indicators = yes
icon_position = left
max_icon_size = 32
icon_path = /usr/share/icons/Tela-circle:/usr/share/icons/hicolor

browser = /usr/bin/firefox
always_run_script = true

title = Dunst
class = Dunst
startup_notification = false
verbosity = mesg
corner_radius = 10
ignore_dbusclose = false
force_xwayland = false
force_xinerama = false

enable_recursive_icon_lookup = true
enable_recursive_color_lookup = true

# Colores por defecto
[urgency_low]
timeout = 4
background = "#1e1e2e"
foreground = "#cdd6f4"
frame_color = "#89b4fa"

[urgency_normal]
timeout = 6
background = "#1e1e2e"
foreground = "#cdd6f4"
frame_color = "#f9e2af"

[urgency_critical]
timeout = 0
background = "#1e1e2e"
foreground = "#f38ba8"
frame_color = "#f38ba8"

EOF
    
    print_status "dunstrc configurado"
}

configure_kitty() {
    print_info "Configurando kitty..."
    
    local kitty_config="${CONFIG_DIR}/kitty/kitty.conf"
    
    # Backup
    if [ -f "$kitty_config" ]; then
        cp "$kitty_config" "${BACKUP_DIR}/kitty.conf.backup"
    fi
    
    cat > "$kitty_config" << 'EOF'
#############################################################################
# Kitty Terminal Configuration
# Tema: Catppuccin Mocha
#############################################################################

#############################################################################
# FUENTE
#############################################################################

font_family      JetBrains Mono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0
disable_ligatures never

#############################################################################
# CURSOR
#############################################################################

cursor_shape block
cursor_blink_interval 0
cursor_stop_interval 15.0

#############################################################################
# SCROLLBACK
#############################################################################

scrollback_lines 10000
scrollback_pager less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER
middle_click_paste_action paste_selection

#############################################################################
# RATÓN
#############################################################################

mouse_hide_wait 3.0
url_color #89b4fa
url_style curly
open_url_with default
url_prefixes http https file ftp

copy_on_select yes
strip_trailing_spaces smart

#############################################################################
# CAMPANA
#############################################################################

enable_audio_bell yes
visual_bell_duration 0.0
bell_on_tab yes

#############################################################################
# VENTANA
#############################################################################

remember_window_size  yes
initial_window_width  80c
initial_window_height 24c
window_padding_width 10
single_window_margin_width 0
window_border_width 1
window_margin_width 0
window_title_align left
active_border_color #89b4fa
inactive_border_color #45475a

#############################################################################
# OPCIONES DE TABULACIÓN
#############################################################################

tab_bar_edge bottom
tab_bar_margin_width 15
tab_bar_margin_height 0.0 0.0
tab_bar_style powerline
tab_bar_align left
tab_bar_min_tabs 2
tab_title_template "{index}:{title}"
active_tab_foreground   #1e1e2e
active_tab_background   #89b4fa
inactive_tab_foreground #cdd6f4
inactive_tab_background #313244

#############################################################################
# COLORES - Catppuccin Mocha
#############################################################################

foreground #cdd6f4
background #1e1e2e
selection_foreground #1e1e2e
selection_background #f5e0dc

# Colores ANSI
color0  #45475a
color1  #f38ba8
color2  #a6e3a1
color3  #f9e2af
color4  #89b4fa
color5  #cba6f7
color6  #94e2d5
color7  #bac2de
color8  #585b70
color9  #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #cba6f7
color14 #94e2d5
color15 #a6adc8

#############################################################################
# ATAJOS DE TECLADO
#############################################################################

map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
map ctrl+shift+s paste_from_selection
map ctrl+shift+o pass_selection_to_program

map ctrl+shift+up scroll_line_up
map ctrl+shift+down scroll_line_down
map ctrl+shift+page_up scroll_page_up
map ctrl+shift+page_down scroll_page_down
map ctrl+shift+home scroll_home
map ctrl+shift+end scroll_end

map ctrl+shift+enter new_window
map ctrl+shift+n new_os_window
map ctrl+shift+w close_window
map ctrl+shift+] next_window
map ctrl+shift+[ previous_window

map ctrl+shift+t new_tab
map ctrl+shift+q close_tab
map ctrl+tab next_tab
map ctrl+shift+tab previous_tab

map ctrl+shift+l next_layout
map ctrl+shift+alt+t toggle_layout stack

map ctrl+shift+equal increase_font_size
map ctrl+shift+minus decrease_font_size
map ctrl+shift+backspace restore_font_size

map ctrl+shift+a>m set_background_opacity 1.0
map ctrl+shift+a>d set_background_opacity 0.85

#############################################################################
# OTROS
#############################################################################

confirm_os_window_close 0
allow_remote_control yes
listen_on none

EOF
    
    print_status "kitty.conf configurado"
}

configure_gtk() {
    print_info "Configurando GTK..."
    
    # GTK 3
    local gtk3_settings="${CONFIG_DIR}/gtk-3.0/settings.ini"
    
    if [ -f "$gtk3_settings" ]; then
        cp "$gtk3_settings" "${BACKUP_DIR}/gtk-3.0-settings.backup"
    fi
    
    cat > "$gtk3_settings" << 'EOF'
[Settings]
gtk-theme-name=Catppuccin-Mocha
gtk-icon-theme-name=Tela-circle-nord
gtk-font-name=JetBrains Mono Nerd Font 11
gtk-cursor-theme-name=default
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=true
EOF
    
    # GTK 4
    mkdir -p "${CONFIG_DIR}/gtk-4.0"
    cp "$gtk3_settings" "${CONFIG_DIR}/gtk-4.0/settings.ini"
    
    print_status "Configuración GTK completada"
}

configure_xinitrc() {
    print_info "Configurando .xinitrc..."
    
    local xinitrc="${HOME_DIR}/.xinitrc"
    
    if [ -f "$xinitrc" ]; then
        cp "$xinitrc" "${BACKUP_DIR}/.xinitrc.backup"
    fi
    
    cat > "$xinitrc" << 'EOF'
#!/bin/bash

#############################################################################
# xinitrc - Archivo de configuración de inicio de X
#############################################################################

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# Merge in defaults and keymaps
if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# Start some nice programs
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# Inicia sesión con bspwm
exec bspwm
EOF
    
    chmod +x "$xinitrc"
    print_status ".xinitrc configurado"
}

configure_xresources() {
    print_info "Configurando .Xresources..."
    
    local xresources="${HOME_DIR}/.Xresources"
    
    if [ -f "$xresources" ]; then
        cp "$xresources" "${BACKUP_DIR}/.Xresources.backup"
    fi
    
    cat > "$xresources" << 'EOF'
!#############################################################################
! Xresources - Configuración de aplicaciones X11
! Tema: Catppuccin Mocha
!#############################################################################

! Colores Catppuccin Mocha
*foreground: #cdd6f4
*background: #1e1e2e
*color0: #45475a
*color1: #f38ba8
*color2: #a6e3a1
*color3: #f9e2af
*color4: #89b4fa
*color5: #cba6f7
*color6: #94e2d5
*color7: #bac2de
*color8: #585b70
*color9: #f38ba8
*color10: #a6e3a1
*color11: #f9e2af
*color12: #89b4fa
*color13: #cba6f7
*color14: #94e2d5
*color15: #a6adc8

! XTerm
xterm*faceName: JetBrains Mono Nerd Font
xterm*faceSize: 11
xterm*foreground: #cdd6f4
xterm*background: #1e1e2e
xterm*cursorColor: #89b4fa
xterm*selectForeground: #1e1e2e
xterm*selectBackground: #f5e0dc

! URxvt
URxvt.font: xft:JetBrains Mono Nerd Font:size=11
URxvt.scrollBar: false
URxvt.foreground: #cdd6f4
URxvt.background: #1e1e2e
URxvt.cursorColor: #89b4fa

EOF
    
    print_status ".Xresources configurado"
}

#############################################################################
# SCRIPTS ADICIONALES
#############################################################################

create_polybar_launcher() {
    print_info "Creando script de lanzamiento de polybar..."
    
    local launcher="${LOCAL_BIN}/launch_polybar"
    
    cat > "$launcher" << 'EOF'
#!/bin/bash

#############################################################################
# Script para lanzar polybar en múltiples monitores
#############################################################################

# Terminar instancias previas de polybar
killall -q polybar 2>/dev/null || true

# Esperar a que se cierre completamente
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Detectar monitores y lanzar polybar en cada uno
if type "xrandr" > /dev/null; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar main &
    done
else
    polybar main &
fi

wait
EOF
    
    chmod +x "$launcher"
    print_status "Script launch_polybar creado"
}

create_wallpaper_setup_script() {
    print_info "Creando script de configuración de wallpaper..."
    
    local wallpaper_script="${LOCAL_BIN}/wallpaper_setup"
    
    cat > "$wallpaper_script" << 'EOF'
#!/bin/bash

#############################################################################
# Script para descargar y configurar wallpapers de Catppuccin
#############################################################################

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
WALLPAPER_REPO="https://github.com/zhichaoh/catppuccin-wallpapers"
WALLPAPER_RAW="https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc"

mkdir -p "$WALLPAPER_DIR"

echo "Descargando wallpapers de Catppuccin..."

# Descargar varios wallpapers (ejemplos)
wget -q -O "$WALLPAPER_DIR/mocha.png" \
    "$WALLPAPER_RAW/mocha.png" || echo "No se pudo descargar mocha.png"

wget -q -O "$WALLPAPER_DIR/latte.png" \
    "$WALLPAPER_RAW/latte.png" || echo "No se pudo descargar latte.png"

# Establecer wallpaper por defecto
if [ -f "$WALLPAPER_DIR/mocha.png" ]; then
    ln -sf "$WALLPAPER_DIR/mocha.png" "$WALLPAPER_DIR/wallpaper.png"
    feh --bg-scale "$WALLPAPER_DIR/wallpaper.png"
    echo "Wallpaper establecido correctamente"
else
    echo "No se encontró wallpaper, usando color sólido"
    feh --bg-color "#1e1e2e"
fi

EOF
    
    chmod +x "$wallpaper_script"
    print_status "Script wallpaper_setup creado"
}

create_statusbar_launcher() {
    print_info "Creando script statusbar_launcher..."
    
    local statusbar_script="${LOCAL_BIN}/statusbar_launcher"
    
    cat > "$statusbar_script" << 'EOF'
#!/bin/bash

#############################################################################
# Script para iniciar todos los servicios de la barra de estado
#############################################################################

echo "Iniciando servicios de la barra de estado..."

# Detener servicios previos
killall -q polybar 2>/dev/null || true

# Esperar
sleep 0.5

# Iniciar polybar
"$HOME/.local/bin/launch_polybar" &

# Iniciar dunst
pgrep -x dunst > /dev/null || dunst &

# Iniciar nm-applet
pgrep -x nm-applet > /dev/null || nm-applet --indicator &

echo "Servicios iniciados correctamente"

EOF
    
    chmod +x "$statusbar_script"
    print_status "Script statusbar_launcher creado"
}

#############################################################################
# CONFIGURACIÓN DE DIRECTORIOS DE USUARIO
#############################################################################

configure_user_dirs() {
    print_info "Configurando user-dirs.dirs..."
    
    local user_dirs="${CONFIG_DIR}/user-dirs.dirs"
    
    cat > "$user_dirs" << 'EOF'
# Configuración de directorios de usuario - Catppuccin BSPWM
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF
    
    # Crear directorios
    mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Templates" \
             "$HOME/Public" "$HOME/Documents" "$HOME/Music" \
             "$HOME/Pictures" "$HOME/Videos"
    
    print_status "user-dirs.dirs configurado"
}

#############################################################################
# DESCARGA DE WALLPAPERS
#############################################################################

download_wallpapers() {
    print_info "Configurando wallpapers de Catppuccin..."
    
    if ! confirm "¿Descargar wallpapers de Catppuccin desde GitHub?"; then
        print_warning "Saltando descarga de wallpapers"
        return
    fi
    
    if ! command -v wget &> /dev/null; then
        print_warning "wget no disponible, saltando descarga"
        return
    fi
    
    mkdir -p "$WALLPAPERS_DIR"
    
    print_info "Descargando wallpapers (esto puede tomar un momento)..."
    
    # Intentar descargar wallpaper por defecto
    if wget -q -O "$WALLPAPERS_DIR/wallpaper.png" \
        "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/mocha.png"; then
        print_status "Wallpaper descargado correctamente"
    else
        print_warning "No se pudo descargar wallpaper desde GitHub"
        # Crear wallpaper placeholder con color sólido
        convert -size 1920x1080 "xc:#1e1e2e" "$WALLPAPERS_DIR/wallpaper.png" 2>/dev/null || {
            print_warning "No se pudo crear wallpaper"
        }
    fi
}

#############################################################################
# CONFIGURACIÓN POST-INSTALACIÓN
#############################################################################

post_install_setup() {
    print_info "Realizando configuración post-instalación..."
    
    # Agregar usuario a grupos
    print_status "Agregando usuario a grupos necesarios..."
    usermod -aG audio,video,network,storage,wheel "$(whoami)" 2>/dev/null || \
        print_warning "No se pudieron agregar grupos"
    
    # Habilitar servicios
    print_status "Habilitando NetworkManager..."
    systemctl enable NetworkManager --now 2>/dev/null || \
        print_warning "No se pudo habilitar NetworkManager"
    
    print_status "Configurando audio (pipewire)..."
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable pipewire wireplumber --now 2>/dev/null || \
        print_warning "No se pudo habilitar pipewire"
    
    print_status "Habilitando elogind..."
    systemctl enable elogind --now 2>/dev/null || \
        print_warning "No se pudo habilitar elogind"
    
    # Configurar bashrc
    print_status "Configurando .bashrc..."
    configure_bashrc
    
    print_status "Post-instalación completada"
}

#############################################################################
# CONFIGURACIÓN DE SSD
#############################################################################

detect_and_configure_ssd() {
    print_info "Detectando y configurando SSD..."
    
    # Detectar discos SSD
    local ssd_list=()
    
    if command -v lsblk &> /dev/null; then
        while IFS= read -r line; do
            local disk=$(echo "$line" | awk '{print $1}')
            local type=$(echo "$line" | awk '{print $2}')
            
            if [ "$type" = "ssd" ]; then
                ssd_list+=("$disk")
            fi
        done < <(lsblk -d -o NAME,ROTA | grep -E "^[a-z]+" | awk '{if ($2 == "0") print $0}')
    fi
    
    # Si se encontraron SSDs
    if [ ${#ssd_list[@]} -gt 0 ]; then
        print_status "Se detectaron los siguientes SSDs:"
        for ssd in "${ssd_list[@]}"; do
            echo "  • /dev/$ssd"
        done
    else
        print_warning "No se detectaron SSDs, o el sistema no soporta ROTA"
    fi
    
    # Habilitar TRIM
    print_status "Habilitando TRIM para SSDs..."
    enable_trim
    
    # Configurar planificador de I/O
    print_status "Configurando planificador de I/O..."
    configure_io_scheduler
    
    # Optimizaciones de SSD
    print_status "Aplicando optimizaciones de SSD..."
    configure_ssd_optimizations
    
    print_status "Configuración de SSD completada"
}

enable_trim() {
    print_info "Habilitando servicio TRIM..."
    
    # Habilitar y activar servicio fstrim
    if systemctl enable fstrim.timer 2>/dev/null; then
        systemctl start fstrim.timer 2>/dev/null || true
        print_status "fstrim.timer habilitado (ejecutarse semanalmente)"
    else
        print_warning "No se pudo habilitar fstrim.timer"
    fi
    
    # Configuración de fstab para noatime (opcional pero recomendado)
    print_info "Configurando noatime en puntos de montaje..."
    
    # Detectar puntos de montaje
    if [ -f /etc/fstab ]; then
        # Backup de fstab
        cp /etc/fstab "${BACKUP_DIR}/fstab.backup"
        
        # Mostrar configuración actual
        echo "Configuración actual de /etc/fstab:"
        grep -v "^#" /etc/fstab | grep -v "^$" || true
        
        print_info "Para optimizar SSD, puedes agregar 'noatime' a las opciones de montaje"
        print_info "Ejemplo: defaults,noatime,compress=zstd en lugar de defaults"
    fi
}

configure_io_scheduler() {
    print_info "Configurando planificador de I/O..."
    
    # Para SSD, se recomienda 'mq-deadline' o 'none'
    # Crear archivo de configuración de sysfs
    
    local sysfs_config="/etc/sysfs.d/ssd-scheduler.conf"
    
    cat > "$sysfs_config" << 'EOF'
# Configuración del planificador I/O para SSD
# Establece 'mq-deadline' como planificador para mejor rendimiento en SSD

# Para cada disco encontrado, establecer el planificador
# Los valores típicos son: mq-deadline, none, kyber, bfq
# 'none' es el más rápido pero puede causar problemas de latencia
# 'mq-deadline' es una buena opción equilibrada para SSD

# Ajustar el número de dispositivos según tu sistema (sda, sdb, etc.)
block/sda/queue/scheduler = mq-deadline
block/sdb/queue/scheduler = mq-deadline
block/sdc/queue/scheduler = mq-deadline
EOF
    
    print_status "Configuración de planificador en $sysfs_config"
    
    # Establecer inmediatamente para el disco actual (si es posible)
    if [ -d "/sys/block/sda" ]; then
        if echo "mq-deadline" > /sys/block/sda/queue/scheduler 2>/dev/null; then
            print_status "Planificador establecido a 'mq-deadline' para sda"
        elif echo "none" > /sys/block/sda/queue/scheduler 2>/dev/null; then
            print_status "Planificador establecido a 'none' para sda"
        fi
    fi
}

configure_ssd_optimizations() {
    print_info "Aplicando optimizaciones adicionales de SSD..."
    
    # Reducir el tiempo de entrega de sync (writeback delay)
    # Esto es útil para SSD pero puede afectar la duración del dispositivo
    local sysctl_config="/etc/sysctl.d/99-ssd-optimization.conf"
    
    cat > "$sysctl_config" << 'EOF'
#############################################################################
# Optimizaciones de SSD
#############################################################################

# Reducir la frecuencia de entrega de datos a disco
# Valores más altos = menos escrituras, mejor para SSD pero más RAM usada
# Valor por defecto es 500, recomendado para SSD es 1500
vm.dirty_writeback_centisecs = 1500

# Límite máximo de páginas sucias en memoria
# Por defecto es 10%, recomendado para SSD es 15-20%
vm.dirty_ratio = 20

# Límite para iniciar writeback en background
# Por defecto es 5%, recomendado para SSD es 10-15%
vm.dirty_background_ratio = 10

# Desabilitar swap si tienes suficiente RAM (opcional)
# vm.swappiness = 10

# Aumentar dirty_expire_centisecs para darle más tiempo al writeback
vm.dirty_expire_centisecs = 7200

# Mejorar el rendimiento de lectura en cache
# Aumenta el tamaño de la caché de lectura
vm.page-cluster = 3

EOF
    
    print_status "Optimizaciones de SSD configuradas en $sysctl_config"
    
    # Aplicar cambios inmediatamente
    if command -v sysctl &> /dev/null; then
        sysctl -p "$sysctl_config" > /dev/null 2>&1 || print_warning "No se pudieron aplicar cambios de sysctl"
    fi
}

create_ssd_maintenance_script() {
    print_info "Creando script de mantenimiento de SSD..."
    
    local maintenance_script="${LOCAL_BIN}/ssd_maintenance"
    
    cat > "$maintenance_script" << 'EOF'
#!/bin/bash

#############################################################################
# Script de mantenimiento de SSD
# Ejecutar periódicamente para mantener el rendimiento
#############################################################################

echo "🔧 Iniciando mantenimiento de SSD..."

# TRIM
echo "▶ Ejecutando TRIM..."
fstrim -v / || echo "TRIM no disponible"

# Estadísticas SSD
echo ""
echo "📊 Estadísticas del SSD:"
echo "================================"

# Mostrar información del SSD
if command -v nvme &> /dev/null && [ -c /dev/nvme0 ]; then
    echo "Información NVMe:"
    nvme smart-log /dev/nvme0 2>/dev/null || echo "No se pudo leer información NVMe"
fi

# Mostrar información SATA
if command -v smartctl &> /dev/null; then
    echo ""
    echo "Información SMART:"
    smartctl -a /dev/sda 2>/dev/null || echo "No se pudo leer información SMART (instala smartmontools)"
fi

# Mostrar espacio disponible
echo ""
echo "Espacio disponible:"
df -h | grep -E "^/dev"

echo ""
echo "✓ Mantenimiento completado"

EOF
    
    chmod +x "$maintenance_script"
    print_status "Script ssd_maintenance creado en ~/.local/bin/"
}

configure_bashrc() {
    local bashrc="${HOME_DIR}/.bashrc"
    
    # Backup
    if [ -f "$bashrc" ]; then
        cp "$bashrc" "${BACKUP_DIR}/.bashrc.backup"
    fi
    
    # Agregar configuración
    cat >> "$bashrc" << 'EOF'

#############################################################################
# Configuración adicional para bspwm - Catppuccin
#############################################################################

# Alias útiles
alias ls='ls --color=auto'
alias la='ls -la'
alias ll='ls -lh'
alias grep='grep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Alias para SSD
alias ssd-trim='sudo fstrim -v /'
alias ssd-maintenance='~/.local/bin/ssd_maintenance'

# Funciones útiles
up() {
    local d=""
    limit=$1
    for ((i=1 ; i <= limit ; i++))
        do
            d=$d/..
        done
    cd $d
}

# Prompt personalizado
PS1='\[\033[01;35m\][\u@\h\[\033[01;35m\]]\[\033[00m\] \[\033[01;36m\]\w\[\033[00m\] \$ '

# Exportar variables de entorno
export EDITOR=nano
export VISUAL=nano

EOF
    
}
     bashrc="${HOME_DIR}/.bashrc"
    
    # Backup
    if [ -f "$bashrc" ]; then
        cp "$bashrc" "${BACKUP_DIR}/.bashrc.backup"
    fi
    
    # Agregar configuración
    cat >> "$bashrc" << 'EOF'

#############################################################################
# Configuración adicional para bspwm - Catppuccin
#############################################################################

# Alias útiles
alias ls='ls --color=auto'
alias la='ls -la'
alias ll='ls -lh'
alias grep='grep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Funciones útiles
up() {
    local d=""
    limit=$1
    for ((i=1 ; i <= limit ; i++))
        do
            d=$d/..
        done
    cd $d
}

# Prompt personalizado
PS1='\[\033[01;35m\][\u@\h\[\033[01;35m\]]\[\033[00m\] \[\033[01;36m\]\w\[\033[00m\] \$ '

# Exportar variables de entorno
export EDITOR=nano
export VISUAL=nano

EOF
    


#############################################################################
# RESUMEN FINAL
#############################################################################

print_summary() {
    clear
    
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}         ${CYAN}Catppuccin BSPWM Setup - Instalación Completada${NC}        ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${GREEN}✓${NC} ${WHITE}COMPONENTES INSTALADOS:${NC}"
    echo "  • Servidor X11 (xorg)"
    echo "  • BSPWM (Window Manager)"
    echo "  • SXHKD (Gestor de atajos)"
    echo "  • Polybar (Barra de estado)"
    echo "  • Picom (Compositor)"
    echo "  • Dunst (Notificaciones)"
    echo "  • Kitty (Terminal)"
    echo "  • Rofi (Lanzador)"
    echo "  • Pipewire (Audio)"
    echo "  • NetworkManager"
    echo "  • Fuentes Nerd"
    
    echo ""
    echo -e "${GREEN}✓${NC} ${WHITE}ARCHIVOS DE CONFIGURACIÓN:${NC}"
    echo "  • ~/.config/bspwm/bspwmrc"
    echo "  • ~/.config/sxhkd/sxhkdrc"
    echo "  • ~/.config/polybar/config.ini"
    echo "  • ~/.config/picom/picom.conf"
    echo "  • ~/.config/dunst/dunstrc"
    echo "  • ~/.config/kitty/kitty.conf"
    echo "  • ~/.xinitrc"
    echo "  • ~/.Xresources"
    
    echo ""
    echo -e "${GREEN}✓${NC} ${WHITE}SCRIPTS ADICIONALES:${NC}"
    echo "  • ~/.local/bin/launch_polybar"
    echo "  • ~/.local/bin/wallpaper_setup"
    echo "  • ~/.local/bin/statusbar_launcher"
    echo "  • ~/.local/bin/ssd_maintenance (Mantenimiento de SSD)"
    
    echo ""
    echo -e "${BLUE}ℹ${NC} ${WHITE}PRÓXIMOS PASOS:${NC}"
    echo "  1. Reinicia tu sesión de X11 o ejecuta: startx"
    echo "  2. Los atajos de teclado están configurados (ver sxhkdrc)"
    echo "  3. Super (Windows) + Enter para abrir terminal"
    echo "  4. Super + d para abrir el lanzador de aplicaciones"
    echo "  5. Personaliza tu wallpaper con: ~/.local/bin/wallpaper_setup"
    echo "  6. (Opcional) Ejecuta ssd-maintenance para ver estado del SSD"
    
    echo ""
    echo -e "${YELLOW}⚠${NC} ${WHITE}NOTAS IMPORTANTES:${NC}"
    echo "  • Los backups se encuentran en: ~/.config/.backup/"
    echo "  • Tema: Catppuccin Mocha (colores aplicados)"
    echo "  • Iconos: Tela-circle-nord"
    echo "  • Fuente: JetBrains Mono Nerd Font"
    echo "  • Wallpapers guardados en: ~/Pictures/wallpapers/"
    
    echo ""
    echo -e "${MAGENTA}💾 CONFIGURACIÓN DE SSD:${NC}"
    echo "  • TRIM habilitado (fstrim.timer ejecutándose semanalmente)"
    echo "  • Planificador I/O optimizado para SSD"
    echo "  • Parámetros sysctl optimizados"
    echo "  • Script de mantenimiento: ssd-maintenance"
    echo "  • Ver: /etc/sysctl.d/99-ssd-optimization.conf"
    echo "  • Ver: /etc/sysfs.d/ssd-scheduler.conf"
    
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}         ${GREEN}¡Configuración lista para usar!${NC}                       ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${CYAN}Puedes encontrar ayuda en:${NC}"
    echo "  • BSPWM: man bspwm"
    echo "  • SXHKD: man sxhkd"
    echo "  • Polybar: https://github.com/polybar/polybar"
    echo "  • SSD: man fstrim, man sysctl"
    
    echo ""
    echo -e "${CYAN}Comandos útiles para SSD:${NC}"
    echo "  • ssd-trim              (ejecutar TRIM manual)"
    echo "  • ssd-maintenance       (ver estadísticas del SSD)"
    echo "  • systemctl status fstrim.timer  (ver estado de TRIM automático)"
    
}

#############################################################################
# FUNCIÓN PRINCIPAL
#############################################################################

main() {
    clear
    
    # Banner
    echo -e "${MAGENTA}"
    cat << "EOF"
   ___      _   _            _     _   _ _   _ 
  / __|__ _| |_| |_ _ _  _ _(_)__| | (_) | | |
 | (__/ _` |  _|  _| ' \| '_| / _` | | | | | |
  \___\__,_|\__|_| |_||_|_| |_\__,_| |_|\_\_\_|
                                              
     BSPWM + Catppuccin Mocha Setup Script    
              Arch Linux Installer             
EOF
    echo -e "${NC}"
    
    echo ""
    echo -e "${CYAN}Este script instalará y configurará un entorno de escritorio${NC}"
    echo -e "${CYAN}bspwm completamente funcional con tema Catppuccin Mocha${NC}"
    echo ""
    
    # Verificaciones iniciales
    check_root
    check_arch_linux
    check_internet
    
    pause_msg
    
    # Instalación de paquetes
    install_packages
    install_yay
    install_aur_packages
    
    # Crear estructura de directorios
    setup_directories
    
    # Generar archivos de configuración
    configure_bspwm
    configure_sxhkd
    configure_polybar
    configure_picom
    configure_dunst
    configure_kitty
    configure_gtk
    configure_xinitrc
    configure_xresources
    configure_user_dirs
    
    # Crear scripts adicionales
    create_polybar_launcher
    create_wallpaper_setup_script
    create_statusbar_launcher
    
    # Descargar wallpapers
    download_wallpapers
    
    # Configuración de SSD
    detect_and_configure_ssd
    create_ssd_maintenance_script
    
    # Post-instalación
    post_install_setup
    
    # Mostrar resumen
    print_summary
    
    # Preguntar si reiniciar
    echo ""
    if confirm "¿Deseas reiniciar el sistema ahora?"; then
        systemctl reboot
    fi
}

# Ejecutar función principal
main "$@"
