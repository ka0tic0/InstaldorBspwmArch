#!/bin/bash

#################################################################################
#                     SETUP BSPWM + CATPPUCCIN MOCHA                           #
#                   Automatic Arch Linux Desktop Environment                   #
#                                                                               #
# Script para automatizar la instalación y configuración de bspwm con          #
# Catppuccin Mocha en Arch Linux desde instalación base                        #
#################################################################################

set -euo pipefail

# ==============================================================================
# DEFINICIONES DE COLORES Y ESTILOS
# ==============================================================================

readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'

# Catppuccin Mocha Colors
readonly CATPPUCCIN_BASE="#1e1e2e"
readonly CATPPUCCIN_TEXT="#cdd6f4"
readonly CATPPUCCIN_BLUE="#89b4fa"
readonly CATPPUCCIN_GREEN="#a6e3a1"
readonly CATPPUCCIN_RED="#f38ba8"
readonly CATPPUCCIN_YELLOW="#f9e2af"
readonly CATPPUCCIN_MAUVE="#cba6f7"
readonly CATPPUCCIN_TEAL="#94e2d5"
readonly CATPPUCCIN_OVERLAY="#45475a"

# ==============================================================================
# FUNCIONES DE UTILIDAD
# ==============================================================================

print_header() {
    echo -e "${COLOR_MAGENTA}╔════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}║${COLOR_RESET}  $1"
    echo -e "${COLOR_MAGENTA}╚════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

print_success() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $1"
}

print_error() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $1" >&2
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $1"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $1"
}

pause_continue() {
    echo -e "\n${COLOR_YELLOW}Presiona Enter para continuar...${COLOR_RESET}"
    read -r
}

prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -rp "$(echo -e "${COLOR_BLUE}?${COLOR_RESET} $prompt (s/n): ")" response
        case "$response" in
            [Ss]) return 0 ;;
            [Nn]) return 1 ;;
            *) print_warning "Por favor responde 's' o 'n'" ;;
        esac
    done
}

# ==============================================================================
# VERIFICACIONES INICIALES
# ==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root"
        exit 1
    fi
    print_success "Ejecutando como root"
}

check_internet() {
    print_info "Verificando conexión a internet..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Conexión a internet verificada"
    else
        print_error "No hay conexión a internet"
        exit 1
    fi
}

check_arch() {
    if ! command -v pacman &> /dev/null; then
        print_error "Este script está diseñado para Arch Linux"
        exit 1
    fi
    print_success "Sistema Arch Linux detectado"
}

# ==============================================================================
# FUNCIÓN PRINCIPAL DE INSTALACIÓN
# ==============================================================================

install_packages() {
    print_header "Instalando Paquetes del Sistema"
    
    print_info "Actualizando repositorios..."
    if pacman -Syu --noconfirm; then
        print_success "Sistema actualizado"
    else
        print_error "Error al actualizar el sistema"
        return 1
    fi
    
    pause_continue
    
    local packages=(
        # Servidor X
        "xorg-server" "xorg-xinit" "xorg-xrandr" "xorg-xsetroot"
        # BSPWM
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
        # Visualización de imágenes
        "feh"
        # Gestor de archivos
        "thunar" "thunar-volman"
        # Conectividad
        "networkmanager" "network-manager-applet"
        # Audio
        "pipewire" "pipewire-pulse" "pipewire-alsa" "wireplumber"
        # Fuentes
        "ttf-jetbrains-mono-nerd" "noto-fonts" "noto-fonts-emoji" "ttf-font-awesome"
        # Temas
        "gtk3" "gtk4" "lxappearance"
        # Utilidades
        "git" "curl" "wget" "base-devel" "scrot" "xclip"
    )
    
    print_info "Instalando ${#packages[@]} paquetes..."
    if pacman -S --noconfirm "${packages[@]}"; then
        print_success "Paquetes instalados correctamente"
    else
        print_error "Error durante la instalación de paquetes"
        return 1
    fi
}

# ==============================================================================
# CONFIGURACIÓN DE DIRECTORIOS
# ==============================================================================

create_directories() {
    print_header "Creando Estructura de Directorios"
    
    local dirs=(
        "$HOME/.config/bspwm"
        "$HOME/.config/sxhkd"
        "$HOME/.config/polybar"
        "$HOME/.config/picom"
        "$HOME/.config/dunst"
        "$HOME/.config/rofi"
        "$HOME/.config/kitty"
        "$HOME/.config/gtk-3.0"
        "$HOME/.config/gtk-4.0"
        "$HOME/.local/bin"
        "$HOME/Pictures/wallpapers"
    )
    
    for dir in "${dirs[@]}"; do
        if mkdir -p "$dir"; then
            print_success "Directorio creado: $dir"
        else
            print_error "Error al crear directorio: $dir"
            return 1
        fi
    done
}

# ==============================================================================
# CONFIGURACIÓN DE BSPWM
# ==============================================================================

configure_bspwm() {
    print_header "Configurando BSPWM"
    
    local bspwmrc="$HOME/.config/bspwm/bspwmrc"
    
    # Backup si existe
    [[ -f "$bspwmrc" ]] && cp "$bspwmrc" "${bspwmrc}.backup"
    
    cat > "$bspwmrc" << 'EOF'
#!/bin/bash

# BSPWM Configuration File
# Auto-generated setup script

# Monitor configuration
bspc monitor -d I II III IV

# Window settings
bspc config border_width        2
bspc config window_gap         10
bspc config top_padding        30
bspc config bottom_padding      0
bspc config left_padding        0
bspc config right_padding       0

# Behavior
bspc config split_ratio         0.52
bspc config borderless_monocle  true
bspc config gapless_monocle     true
bspc config focus_follows_pointer false
bspc config pointer_follows_focus false
bspc config click_to_focus      true

# Colors (Catppuccin Mocha)
bspc config normal_border_color   "#45475a"
bspc config active_border_color   "#89b4fa"
bspc config focused_border_color  "#cba6f7"

# Launch sxhkd
pgrep -x sxhkd > /dev/null || sxhkd &

# Launch picom (compositor)
picom --daemon &

# Launch polybar
"$HOME/.local/bin/launch_polybar" &

# Launch dunst (notifications)
dunst &

# Set wallpaper
if [[ -f "$HOME/Pictures/wallpapers/wallpaper.jpg" ]]; then
    feh --bg-scale "$HOME/Pictures/wallpapers/wallpaper.jpg" &
fi

# NetworkManager tray
nm-applet &

wait
EOF
    
    chmod +x "$bspwmrc"
    print_success "BSPWM configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE SXHKD
# ==============================================================================

configure_sxhkd() {
    print_header "Configurando SXHKD (Atajos de Teclado)"
    
    local sxhkdrc="$HOME/.config/sxhkd/sxhkdrc"
    
    [[ -f "$sxhkdrc" ]] && cp "$sxhkdrc" "${sxhkdrc}.backup"
    
    cat > "$sxhkdrc" << 'EOF'
# SXHKD Configuration
# Keyboard shortcuts for BSPWM

# Terminal
super + Return
    kitty

# Cerrar ventana
super + q
    bspc node -c

# Cambiar a escritorio
super + {1,2,3,4}
    bspc desktop -f {I,II,III,IV}

# Mover ventana a escritorio
super + shift + {1,2,3,4}
    bspc node -d {I,II,III,IV} --follow

# Navegar entre ventanas (Vim keys)
super + {j,k,l,semicolon}
    bspc node -f {west,south,north,east}

# Mover ventana (Vim keys)
super + shift + {j,k,l,semicolon}
    bspc node -s {west,south,north,east}

# Cambiar layouts
super + t
    bspc node -t tiled

super + m
    bspc node -t monocle

# Fullscreen
super + f
    bspc node -t \~fullscreen

# Pseudotiling
super + p
    bspc node -t \~pseudo_tiled

# Toggle floating
super + space
    bspc node -t \~floating

# Balance windows
super + e
    bspc node @parent -B

# Adjust gaps
super + ctrl + {h,l}
    bspc config window_gap $(($(bspc config window_gap) {+,-} 5))

# Rofi - Application launcher
super + d
    rofi -show drun

# Rofi - Run command
super + r
    rofi -show run

# Rofi - Window switcher
super + w
    rofi -show window

# Audio controls
XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# Screenshot
Print
    scrot ~/Pictures/screenshot-$(date +%s).png && notify-send "Screenshot saved"

# Brightness (si tienes xbacklight)
XF86MonBrightnessDown
    xbacklight -dec 5

XF86MonBrightnessUp
    xbacklight -inc 5
EOF

    chmod +x "$sxhkdrc"
    print_success "SXHKD configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE POLYBAR
# ==============================================================================

configure_polybar() {
    print_header "Configurando Polybar"
    
    local polybar_config="$HOME/.config/polybar/config.ini"
    
    [[ -f "$polybar_config" ]] && cp "$polybar_config" "${polybar_config}.backup"
    
    cat > "$polybar_config" << 'EOF'
[colors]
; Catppuccin Mocha
background = #1e1e2e
foreground = #cdd6f4
blue = #89b4fa
green = #a6e3a1
red = #f38ba8
yellow = #f9e2af
mauve = #cba6f7
teal = #94e2d5
overlay = #45475a

[bar/main]
monitor = eDP-1
width = 100%
height = 30
offset-x = 0
offset-y = 0

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 3
line-color = ${colors.blue}

border-size = 0
border-color = ${colors.overlay}

padding-left = 2
padding-right = 2

module-margin-left = 1
module-margin-right = 1

font-0 = "JetBrains Mono Nerd Font:size=11:weight=bold;2"
font-1 = "Noto Sans:size=11;2"
font-2 = "Font Awesome 6 Free:style=Solid:pixelsize=11;2"

modules-left = bspwm
modules-center = date time
modules-right = memory cpu volume battery network

cursor-click = pointer
cursor-scroll = ns-resize

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
inline-mode = false

label-focused = %name%
label-focused-background = ${colors.blue}
label-focused-foreground = ${colors.background}
label-focused-padding = 1

label-occupied = %name%
label-occupied-foreground = ${colors.teal}
label-occupied-padding = 1

label-unoccupied = %name%
label-unoccupied-foreground = ${colors.overlay}
label-unoccupied-padding = 1

label-urgent = %name%
label-urgent-background = ${colors.red}
label-urgent-foreground = ${colors.background}
label-urgent-padding = 1

[module/date]
type = internal/date
interval = 1
date = "%d/%m/%Y"
label = 📅 %date%
label-foreground = ${colors.yellow}

[module/time]
type = internal/date
interval = 1
time = "%H:%M:%S"
label = 🕐 %time%
label-foreground = ${colors.teal}

[module/volume]
type = internal/pulseaudio

format-volume = <ramp-volume> <label-volume>
label-volume = %percentage%%
label-volume-foreground = ${colors.green}

label-muted = 🔇 muted
label-muted-foreground = ${colors.overlay}

ramp-volume-0 = 🔈
ramp-volume-1 = 🔉
ramp-volume-2 = 🔊
ramp-volume-foreground = ${colors.green}

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC0
poll-interval = 5

format-charging = 🔌 <label-charging>
label-charging = %percentage%%
label-charging-foreground = ${colors.green}

format-discharging = 🔋 <label-discharging>
label-discharging = %percentage%%
label-discharging-foreground = ${colors.yellow}

format-full = ✓ <label-full>
label-full = %percentage%%
label-full-foreground = ${colors.green}

[module/network]
type = internal/network
interface = wlan0
interval = 1.0

format-connected = 📡 <label-connected>
label-connected = %essid%
label-connected-foreground = ${colors.blue}

format-disconnected = ❌ No connection
label-disconnected-foreground = ${colors.red}

[module/memory]
type = internal/memory
interval = 3
format = 💾 <label>
label = %gb_used%/%gb_total%
label-foreground = ${colors.mauve}

[module/cpu]
type = internal/cpu
interval = 2
format = ⚙ <label>
label = %percentage%%
label-foreground = ${colors.red}

[settings]
screenchange-reload = true
pseudo-transparency = true
EOF

    print_success "Polybar configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE PICOM
# ==============================================================================

configure_picom() {
    print_header "Configurando Picom (Compositor)"
    
    local picom_config="$HOME/.config/picom/picom.conf"
    
    [[ -f "$picom_config" ]] && cp "$picom_config" "${picom_config}.backup"
    
    cat > "$picom_config" << 'EOF'
# Picom configuration file
# Catppuccin Mocha theme

# Backend
backend = "glx";
vsync = true;

# Opacity
active-opacity = 1.0;
inactive-opacity = 0.9;
frame-opacity = 1.0;
popup_menu-opacity = 0.9;
dropdown_menu-opacity = 0.9;

opacity-rule = [
  "80:class_g = 'kitty' && !focused",
  "90:class_g = 'rofi'",
  "90:class_g = 'dunst'"
];

# Shadows
shadow = true;
shadow-radius = 10;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "class_g = 'Cairo-clock'",
  "_NET_WM_WINDOW_TYPE:a = '_NET_WM_WINDOW_TYPE_DOCK'",
  "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
];

# Blurring
blur-background = false;

# Fading
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

# Corners
corner-radius = 10;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'dropdown_menu'",
  "window_type = 'popup_menu'",
  "window_type = 'tooltip'"
];

# Other
detect-rounded-corners = true;
detect-client-opacity = true;
use-damage = true;
log-level = "warn";
EOF

    print_success "Picom configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE DUNST
# ==============================================================================

configure_dunst() {
    print_header "Configurando Dunst (Notificaciones)"
    
    local dunst_config="$HOME/.config/dunst/dunstrc"
    
    [[ -f "$dunst_config" ]] && cp "$dunst_config" "${dunst_config}.backup"
    
    cat > "$dunst_config" << 'EOF'
[global]
    monitor = 0
    follow = mouse
    geometry = "300x100-30+30"
    indicate_hidden = yes
    shrink = no
    transparency = 20
    notification_height = 0
    separator_height = 2
    padding = 15
    horizontal_padding = 15
    frame_width = 2
    frame_color = "#89b4fa"
    separator_color = "#45475a"
    sort = yes
    idle_threshold = 120
    font = JetBrains Mono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    show_age_threshold = 60
    word_wrap = yes
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes

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

    print_success "Dunst configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE KITTY
# ==============================================================================

configure_kitty() {
    print_header "Configurando Kitty Terminal"
    
    local kitty_config="$HOME/.config/kitty/kitty.conf"
    
    [[ -f "$kitty_config" ]] && cp "$kitty_config" "${kitty_config}.backup"
    
    cat > "$kitty_config" << 'EOF'
# Kitty Terminal Configuration
# Catppuccin Mocha theme

# Font
font_family JetBrains Mono Nerd Font
font_size 12
disable_ligatures never

# Window
window_padding_width 10
window_margin_width 0
window_border_width 2
window_border_width 1px
draw_minimal_borders yes
window_decorations titlebar-only

# Transparency
background_opacity 0.85
background_blur 5

# Scrollback
scrollback_lines 10000
scrollback_pager less +G -R
mouse_hide_wait 3.0

# Mouse
open_url_with default
url_color #89b4fa
url_style underline
strip_trailing_spaces smart

# Tabs
tab_bar_edge top
tab_bar_style powerline
active_tab_foreground #1e1e2e
active_tab_background #89b4fa
inactive_tab_foreground #cdd6f4
inactive_tab_background #45475a

# Bell
enable_audio_bell no
visual_bell_duration 0.0

# Catppuccin Mocha Colors
foreground #cdd6f4
background #1e1e2e
selection_foreground #1e1e2e
selection_background #f5e0dc

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

# Cursor
cursor_shape beam
cursor_beam_thickness 1.5
cursor_underline_thickness 2
cursor_blink_interval 0.5

# Key bindings
kitty_mod ctrl+shift
EOF

    print_success "Kitty configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE GTK
# ==============================================================================

configure_gtk() {
    print_header "Configurando GTK (Tema y Apariencia)"
    
    local gtk3_settings="$HOME/.config/gtk-3.0/settings.ini"
    local gtk4_settings="$HOME/.config/gtk-4.0/settings.ini"
    
    [[ -f "$gtk3_settings" ]] && cp "$gtk3_settings" "${gtk3_settings}.backup"
    [[ -f "$gtk4_settings" ]] && cp "$gtk4_settings" "${gtk4_settings}.backup"
    
    cat > "$gtk3_settings" << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono Nerd Font 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
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

    cp "$gtk3_settings" "$gtk4_settings"
    
    print_success "GTK configurado"
}

# ==============================================================================
# CONFIGURACIÓN DE .xinitrc
# ==============================================================================

configure_xinitrc() {
    print_header "Configurando .xinitrc"
    
    local xinitrc="$HOME/.xinitrc"
    
    [[ -f "$xinitrc" ]] && cp "$xinitrc" "${xinitrc}.backup"
    
    cat > "$xinitrc" << 'EOF'
#!/bin/bash
# .xinitrc - X Window System initialization file

# Load resources
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Start bspwm
exec bspwm
EOF

    chmod +x "$xinitrc"
    print_success ".xinitrc configurado"
}

# ==============================================================================
# SCRIPTS AUXILIARES
# ==============================================================================

create_helper_scripts() {
    print_header "Creando Scripts Auxiliares"
    
    # Script para lanzar polybar
    local launch_polybar="$HOME/.local/bin/launch_polybar"
    cat > "$launch_polybar" << 'EOF'
#!/bin/bash
# Script to launch polybar on all connected monitors

killall -q polybar || true
wait $! 2>/dev/null || true

# Get connected monitors
monitors=$(xrandr --query | grep " connected" | cut -d" " -f1)

for monitor in $monitors; do
    MONITOR=$monitor polybar --config=$HOME/.config/polybar/config.ini main &
done

wait
EOF
    chmod +x "$launch_polybar"
    print_success "Script launch_polybar creado"
    
    # Script para descargar y configurar wallpaper
    local wallpaper_setup="$HOME/.local/bin/wallpaper_setup"
    cat > "$wallpaper_setup" << 'EOF'
#!/bin/bash
# Wallpaper setup script

WALLPAPER_DIR="$HOME/Pictures/wallpapers"

# Create directory
mkdir -p "$WALLPAPER_DIR"

# Try to download Catppuccin wallpaper or use default
if command -v curl &> /dev/null; then
    echo "Descargando wallpaper de Catppuccin..."
    if curl -L -o "$WALLPAPER_DIR/wallpaper.jpg" \
        "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/catppuccin_mocha_blue.png" 2>/dev/null; then
        echo "Wallpaper descargado correctamente"
        # Convert to jpg if needed
        if command -v convert &> /dev/null; then
            convert "$WALLPAPER_DIR/wallpaper.jpg" "$WALLPAPER_DIR/wallpaper.jpg"
        fi
    else
        echo "No se pudo descargar el wallpaper, usando color sólido..."
        # Create a solid color wallpaper
        if command -v convert &> /dev/null; then
            convert -size 1920x1080 "xc:#1e1e2e" "$WALLPAPER_DIR/wallpaper.jpg"
        fi
    fi
else
    echo "curl no disponible, usando color sólido..."
    # Fallback: create solid color image
    if command -v convert &> /dev/null; then
        convert -size 1920x1080 "xc:#1e1e2e" "$WALLPAPER_DIR/wallpaper.jpg"
    fi
fi

# Set wallpaper
if [[ -f "$WALLPAPER_DIR/wallpaper.jpg" ]]; then
    feh --bg-scale "$WALLPAPER_DIR/wallpaper.jpg"
    echo "Wallpaper configurado"
fi
EOF
    chmod +x "$wallpaper_setup"
    print_success "Script wallpaper_setup creado"
    
    # Script para configurar .bashrc
    local configure_bash="$HOME/.local/bin/configure_bash"
    cat > "$configure_bash" << 'EOF'
#!/bin/bash
# Add useful aliases to bashrc

BASHRC="$HOME/.bashrc"

if ! grep -q "# BSPWM Aliases" "$BASHRC"; then
    cat >> "$BASHRC" << 'BASHRC_EOF'

# BSPWM Aliases
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# System
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -R'
alias search='pacman -Ss'

# Other
alias neofetch='fastfetch'
BASHRC_EOF
    echo "Aliases añadidos a .bashrc"
fi
EOF
    chmod +x "$configure_bash"
    print_success "Script configure_bash creado"
}

# ==============================================================================
# CONFIGURACIÓN DE .Xresources
# ==============================================================================

configure_xresources() {
    print_header "Configurando .Xresources"
    
    local xresources="$HOME/.Xresources"
    
    [[ -f "$xresources" ]] && cp "$xresources" "${xresources}.backup"
    
    cat > "$xresources" << 'EOF'
! .Xresources - X resource configuration
! Catppuccin Mocha colors

*background: #1e1e2e
*foreground: #cdd6f4
*cursorColor: #cdd6f4

! Black
*color0: #45475a
*color8: #585b70

! Red
*color1: #f38ba8
*color9: #f38ba8

! Green
*color2: #a6e3a1
*color10: #a6e3a1

! Yellow
*color3: #f9e2af
*color11: #f9e2af

! Blue
*color4: #89b4fa
*color12: #89b4fa

! Magenta
*color5: #cba6f7
*color13: #cba6f7

! Cyan
*color6: #94e2d5
*color14: #94e2d5

! White
*color7: #bac2de
*color15: #a6adc8

! URxvt configuration (if used)
URxvt*font: xft:JetBrains Mono Nerd Font:size=12
URxvt*boldFont: xft:JetBrains Mono Nerd Font:style=Bold:size=12
URxvt*scrollBar: false
URxvt*saveLines: 10000
URxvt*transparent: true
URxvt*shading: 15
EOF

    print_success ".Xresources configurado"
}

# ==============================================================================
# POST-INSTALACIÓN
# ==============================================================================

post_install() {
    print_header "Configuración Post-Instalación"
    
    print_info "Habilitando NetworkManager..."
    systemctl enable NetworkManager --now 2>/dev/null || print_warning "NetworkManager no pudo habilitarse"
    
    print_info "Configurando servicios de audio..."
    sudo -u "$SUDO_USER" systemctl --user enable pipewire wireplumber --now 2>/dev/null || print_warning "Servicios de audio no pudieron habilitarse"
    
    print_info "Añadiendo usuario a grupos necesarios..."
    for group in audio video network storage wheel; do
        usermod -aG "$group" "$SUDO_USER" 2>/dev/null || true
    done
    
    # Create user dirs
    print_info "Configurando directorios de usuario..."
    cat > "$HOME/.config/user-dirs.dirs" << 'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF
    
    print_success "Configuración post-instalación completada"
}

# ==============================================================================
# CONFIGURACIÓN ADICIONAL OPCIONAL
# ==============================================================================

install_optional_packages() {
    print_header "Paquetes Opcionales"
    
    if prompt_yes_no "¿Deseas instalar yay (AUR helper)?"; then
        print_info "Instalando yay..."
        if pacman -S --noconfirm yay 2>/dev/null || git clone https://aur.archlinux.org/yay.git /tmp/yay && \
           cd /tmp/yay && makepkg -si --noconfirm 2>/dev/null; then
            print_success "yay instalado"
        else
            print_warning "No se pudo instalar yay"
        fi
    fi
    
    if prompt_yes_no "¿Deseas instalar Firefox?"; then
        if pacman -S --noconfirm firefox; then
            print_success "Firefox instalado"
        fi
    fi
    
    if prompt_yes_no "¿Deseas instalar Neovim?"; then
        if pacman -S --noconfirm neovim; then
            print_success "Neovim instalado"
        fi
    fi
    
    if prompt_yes_no "¿Deseas instalar htop y otras utilidades?"; then
        if pacman -S --noconfirm htop fastfetch ranger btop; then
            print_success "Utilidades instaladas"
        fi
    fi
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

print_summary() {
    print_header "Instalación Completada"
    
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                   ✓ RESUMEN DE INSTALACIÓN                    ║
╚════════════════════════════════════════════════════════════════╝

COMPONENTES INSTALADOS:
✓ BSPWM - Window Manager binario
✓ SXHKD - Daemon de atajos de teclado
✓ Polybar - Barra de estado
✓ Picom - Compositor con efectos visuales
✓ Dunst - Servidor de notificaciones
✓ Kitty - Emulador de terminal
✓ Rofi - Lanzador de aplicaciones
✓ Servidor X - Infraestructura gráfica
✓ NetworkManager - Gestor de red
✓ PipeWire - Sistema de audio moderno
✓ Tema Catppuccin Mocha - Colores consistentes

ARCHIVOS DE CONFIGURACIÓN CREADOS:
✓ ~/.config/bspwm/bspwmrc - Configuración principal
✓ ~/.config/sxhkd/sxhkdrc - Atajos de teclado
✓ ~/.config/polybar/config.ini - Barra de estado
✓ ~/.config/picom/picom.conf - Efectos visuales
✓ ~/.config/dunst/dunstrc - Notificaciones
✓ ~/.config/kitty/kitty.conf - Terminal
✓ ~/.xinitrc - Inicialización de X
✓ ~/.Xresources - Recursos X
✓ ~/.config/gtk-3.0/settings.ini - Tema GTK3
✓ ~/.config/gtk-4.0/settings.ini - Tema GTK4

SCRIPTS AUXILIARES:
✓ ~/.local/bin/launch_polybar - Lanzador de polybar
✓ ~/.local/bin/wallpaper_setup - Configurador de wallpaper
✓ ~/.local/bin/configure_bash - Configurador de bashrc

PRÓXIMOS PASOS:
1. Inicia sesión gráfica: startx
2. Personaliza las configuraciones según tu preferencia
3. Instala más programas desde AUR si es necesario
4. Lee la documentación de bspwm: man bspwm

ATAJOS DE TECLADO PRINCIPALES:
• Super + Return → Abre Terminal (Kitty)
• Super + d → Lanzador (Rofi)
• Super + {1-4} → Cambiar escritorio
• Super + q → Cerrar ventana
• Super + {j,k,l,;} → Navegar ventanas (Vim)
• Super + f → Fullscreen
• Super + m → Monocle layout
• Super + t → Tiled layout

NOTAS IMPORTANTES:
• Todos los cambios están respaldados en .backup
• Las configuraciones usan Catppuccin Mocha (morado/azul oscuro)
• Necesitarás reiniciar para que los cambios en grupos sean efectivos
• Algunos atajos pueden requerir software adicional

╔════════════════════════════════════════════════════════════════╗
║        ¡Disfruta tu nuevo entorno bspwm + Catppuccin!         ║
╚════════════════════════════════════════════════════════════════╝
EOF
}

# ==============================================================================
# FUNCIÓN PRINCIPAL
# ==============================================================================

main() {
    clear
    
    print_header "SETUP BSPWM + CATPPUCCIN MOCHA PARA ARCH LINUX"
    echo ""
    echo "Este script automatizará la instalación y configuración completa"
    echo "de un entorno de escritorio bspwm con tema Catppuccin Mocha"
    echo ""
    
    # Verificaciones iniciales
    check_root
    check_arch
    check_internet
    
    pause_continue
    
    # Instalación de paquetes
    install_packages || { print_error "Error en instalación de paquetes"; exit 1; }
    
    pause_continue
    
    # Crear directorios
    create_directories || { print_error "Error al crear directorios"; exit 1; }
    
    # Configuración
    configure_bspwm || { print_error "Error en configuración de bspwm"; exit 1; }
    configure_sxhkd || { print_error "Error en configuración de sxhkd"; exit 1; }
    configure_polybar || { print_error "Error en configuración de polybar"; exit 1; }
    configure_picom || { print_error "Error en configuración de picom"; exit 1; }
    configure_dunst || { print_error "Error en configuración de dunst"; exit 1; }
    configure_kitty || { print_error "Error en configuración de kitty"; exit 1; }
    configure_gtk || { print_error "Error en configuración de gtk"; exit 1; }
    configure_xinitrc || { print_error "Error en configuración de xinitrc"; exit 1; }
    configure_xresources || { print_error "Error en configuración de xresources"; exit 1; }
    
    # Scripts auxiliares
    create_helper_scripts || { print_error "Error al crear scripts auxiliares"; exit 1; }
    
    # Post-instalación
    post_install || print_warning "Algunos servicios no pudieron habilitarse"
    
    # Paquetes opcionales
    echo ""
    if prompt_yes_no "¿Deseas instalar paquetes opcionales?"; then
        install_optional_packages
    fi
    
    # Resumen final
    print_summary
    
    # Preguntar si desea reiniciar
    echo ""
    if prompt_yes_no "¿Deseas reiniciar ahora?"; then
        print_info "Reiniciando en 10 segundos..."
        sleep 10
        reboot
    else
        print_info "Recuerda que algunos cambios requieren reinicio para tomar efecto"
        print_info "Para iniciar tu entorno gráfico, ejecuta: startx"
    fi
}

# Ejecutar función principal
main "$@"
