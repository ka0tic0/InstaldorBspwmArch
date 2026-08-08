#!/bin/bash

################################################################################
#                                                                              #
#  ARCH LINUX - BSPWM + CATPPUCCIN SETUP SCRIPT                              #
#  Instalación y configuración automática desde cero                          #
#                                                                              #
################################################################################

set -e

# ============================================================================
# DEFINICIÓN DE COLORES Y VARIABLES GLOBALES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Catppuccin Mocha Colors
CATPPUCCIN_BASE="#1e1e2e"
CATPPUCCIN_SURFACE="#313244"
CATPPUCCIN_OVERLAY="#45475a"
CATPPUCCIN_TEXT="#cdd6f4"
CATPPUCCIN_BLUE="#89b4fa"
CATPPUCCIN_GREEN="#a6e3a1"
CATPPUCCIN_RED="#f38ba8"
CATPPUCCIN_YELLOW="#f9e2af"
CATPPUCCIN_MAUVE="#cba6f7"
CATPPUCCIN_CYAN="#94e2d5"
CATPPUCCIN_LAVENDER="#b4befe"

# Directorios
CONFIG_DIR="${HOME}/.config"
BIN_DIR="${HOME}/.local/bin"
WALLPAPER_DIR="${HOME}/Pictures/wallpapers"
BACKUP_DIR="${HOME}/.config_backup_$(date +%s)"

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_section() {
    echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}\n"
}

pause_script() {
    read -p "$(echo -e ${CYAN}'Presiona Enter para continuar...'${NC})" -t 5
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (usa sudo)"
        exit 1
    fi
    log_success "Verificación de permisos de root completada"
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No hay conexión a internet. Verifica tu conexión de red."
        exit 1
    fi
    log_success "Conexión a internet verificada"
}

backup_existing_config() {
    log_info "Realizando backup de configuraciones existentes..."
    
    if [[ -d "$CONFIG_DIR/bspwm" ]] || [[ -d "$CONFIG_DIR/sxhkd" ]]; then
        mkdir -p "$BACKUP_DIR"
        [[ -d "$CONFIG_DIR/bspwm" ]] && cp -r "$CONFIG_DIR/bspwm" "$BACKUP_DIR/" || true
        [[ -d "$CONFIG_DIR/sxhkd" ]] && cp -r "$CONFIG_DIR/sxhkd" "$BACKUP_DIR/" || true
        [[ -d "$CONFIG_DIR/polybar" ]] && cp -r "$CONFIG_DIR/polybar" "$BACKUP_DIR/" || true
        [[ -d "$CONFIG_DIR/picom" ]] && cp -r "$CONFIG_DIR/picom" "$BACKUP_DIR/" || true
        log_success "Backup realizado en: $BACKUP_DIR"
    fi
}

# ============================================================================
# INSTALACIÓN DE PAQUETES
# ============================================================================

update_system() {
    log_section "ACTUALIZANDO SISTEMA"
    
    pacman -Sy --noconfirm
    log_info "Actualizando paquetes del sistema..."
    pacman -Su --noconfirm || log_warning "Algunos paquetes no pudieron actualizarse"
    
    log_success "Sistema actualizado"
}

install_yay() {
    log_info "Instalando yay (AUR helper)..."
    
    if command -v yay &> /dev/null; then
        log_success "yay ya está instalado"
        return 0
    fi
    
    log_info "Preparando herramientas de compilación..."
    pacman -S --needed --noconfirm git base-devel || log_warning "base-devel parcialmente instalado"
    
    # Crear usuario temporal para compilar yay (makepkg no puede ejecutarse como root)
    local build_user="yay_build_$$"
    log_info "Creando usuario temporal para compilación: $build_user"
    
    # Crear usuario si no existe
    if ! id "$build_user" &>/dev/null; then
        useradd -m -s /bin/bash "$build_user"
        # Permitir que ejecute sudo pacman sin contraseña
        mkdir -p /etc/sudoers.d
        echo "$build_user ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "/etc/sudoers.d/$build_user"
        chmod 0440 "/etc/sudoers.d/$build_user"
    fi
    
    local build_dir="/tmp/yay_build_$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Descargando yay desde AUR..."
    if ! sudo -u "$build_user" git clone --depth 1 https://aur.archlinux.org/yay.git . 2>&1 | grep -v "^Cloning\|^Receiving"; then
        log_warning "Error descargando yay, intentando alternativa..."
    fi
    
    if [[ -f PKGBUILD ]]; then
        log_info "Compilando yay (esto puede tomar un tiempo)..."
        if sudo -u "$build_user" makepkg --noconfirm -s 2>&1 | tail -5; then
            log_info "Instalando paquete compilado..."
            if pacman -U --noconfirm yay-*.pkg.tar.zst 2>&1 | tail -3; then
                log_success "yay instalado correctamente"
            else
                log_warning "Error instalando yay compilado"
            fi
        else
            log_warning "Error compilando yay"
        fi
    else
        log_warning "PKGBUILD de yay no encontrado"
    fi
    
    # Limpiar
    cd /tmp
    rm -rf "$build_dir"
    [[ -f "/etc/sudoers.d/$build_user" ]] && rm -f "/etc/sudoers.d/$build_user"
    userdel -r "$build_user" 2>/dev/null || true
    
    if command -v yay &> /dev/null; then
        log_success "yay está disponible"
    else
        log_warning "yay no está disponible, continuando con pacman únicamente"
    fi
}

download_themes_manually() {
    log_info "Descargando temas de Catppuccin manualmente..."
    
    local themes_dir="$HOME/.themes"
    local icons_dir="$HOME/.icons"
    
    mkdir -p "$themes_dir" "$icons_dir"
    
    # Descargar Catppuccin GTK Theme
    if command -v git &> /dev/null; then
        log_info "Clonando Catppuccin GTK Theme..."
        if git clone https://github.com/catppuccin/gtk.git "$themes_dir/Catppuccin-Mocha" 2>/dev/null; then
            log_success "Tema Catppuccin descargado"
        else
            log_warning "No se pudo descargar el tema Catppuccin"
        fi
        
        # Descargar Tela Circle Icons
        log_info "Clonando Tela Circle Icons..."
        if git clone https://github.com/vinceliuice/Tela-circle-icon-theme.git "$icons_dir/tela-circle" 2>/dev/null; then
            log_success "Iconos Tela descargados"
        else
            log_warning "No se pudieron descargar los iconos Tela"
        fi
    else
        log_warning "Git no disponible, usando temas predeterminados del sistema"
    fi
}

install_packages() {
    log_section "INSTALANDO PAQUETES NECESARIOS"
    
    # Array de paquetes de repositorios oficiales
    local pacman_packages=(
        # Servidor X
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xdpyinfo
        
        # BSPWM y gestor de ventanas
        bspwm sxhkd
        
        # Terminal
        kitty
        
        # Barra de estado
        polybar
        
        # Lanzador
        rofi
        
        # Compositor
        picom
        
        # Notificaciones
        dunst
        
        # Visualizador de imágenes
        feh
        
        # Gestor de archivos
        thunar thunar-volman gvfs
        
        # Red
        networkmanager network-manager-applet
        
        # Audio (pipewire)
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
        
        # Fuentes
        ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji ttf-font-awesome
        
        # Herramientas básicas
        git curl wget base-devel xclip imagemagick
        
        # Utilidades
        lxappearance gnome-keyring
        
        # Display Manager
        sddm
        
        # Otros
        scrot xdotool wmctrl
    )
    
    log_info "Instalando paquetes de repositorios oficiales..."
    
    # Instalación con manejo de errores
    if pacman -S --needed --noconfirm "${pacman_packages[@]}" 2>&1 | tail -20; then
        log_success "Paquetes de pacman instalados"
    else
        log_warning "Algunos paquetes pueden no haberse instalado, continuando..."
    fi
    
    # Paquetes de AUR (opcional, solo si yay está disponible)
    log_info "Instalando paquetes de AUR..."
    if command -v yay &> /dev/null; then
        log_info "yay disponible, instalando temas y fuentes de AUR..."
        yay -S --needed --noconfirm \
            catppuccin-gtk-theme-mocha \
            tela-circle-icon-theme \
            ttf-nerd-fonts-symbols-2048-em-mono 2>&1 | grep -v "^warning" || log_warning "Algunos paquetes de AUR no están disponibles"
        log_success "Paquetes de AUR instalados"
    else
        log_warning "yay no disponible, los temas se descargarán manualmente"
        # Descargar temas manualmente si es necesario
        download_themes_manually
    fi
    
    log_success "Instalación de paquetes completada"
}

# ============================================================================
# CREACIÓN DE ESTRUCTURA DE DIRECTORIOS
# ============================================================================

create_directory_structure() {
    log_section "CREANDO ESTRUCTURA DE DIRECTORIOS"
    
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
        "$BIN_DIR"
        "$WALLPAPER_DIR"
        "$HOME/.local/share/rofi/themes"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_info "Directorio creado: $dir"
    done
    
    log_success "Estructura de directorios completada"
}

# ============================================================================
# GENERACIÓN DE ARCHIVOS DE CONFIGURACIÓN
# ============================================================================

configure_bspwmrc() {
    log_section "CONFIGURANDO BSPWM"
    
    cat > "$CONFIG_DIR/bspwm/bspwmrc" << 'EOF'
#!/bin/bash

# BSPWM Configuration

# Pointer behavior
bspc config pointer_modifier mod4
bspc config pointer_action1 move
bspc config pointer_action2 resize_side
bspc config pointer_action3 resize_corner

# Window settings
bspc config border_width 2
bspc config window_gap 10
bspc config top_padding 30
bspc config right_padding 0
bspc config bottom_padding 0
bspc config left_padding 0

# Colors
bspc config focused_border_color "#89b4fa"     # Blue
bspc config normal_border_color "#313244"      # Surface
bspc config presel_feedback_color "#45475a"    # Overlay
bspc config urgent_border_color "#f38ba8"      # Red

# Layout
bspc config split_ratio 0.52
bspc config borderless_monocle false
bspc config gapless_monocle false
bspc config single_monocle false

# Monitores y escritorios
bspc monitor -d I:Web II:Term III:Code IV:Misc

# Reglas de ventanas
bspc rule -a Thunar state=floating rectangle=1000x600+460+180
bspc rule -a zoom state=floating
bspc rule -a "VLC media player" state=floating
bspc rule -a Xfce4-terminal state=floating rectangle=800x600+560+180
bspc rule -a feh state=floating

# Autostart
sxhkd &

# Compositor
picom --daemon -b &

# Polybar
"$HOME/.local/bin/launch_polybar" &

# Notificaciones
dunst &

# Network Manager Applet
nm-applet &

# Wallpaper
feh --bg-scale "$HOME/Pictures/wallpapers/catppuccin-wallpaper.png" 2>/dev/null || \
    feh --bg-scale "$HOME/Pictures/wallpapers/default.png" 2>/dev/null || true

# Audio setup
pactl set-default-sink @DEFAULT_SINK@ 2>/dev/null || true

# Screen setup
"$HOME/.local/bin/xrandr_setup" 2>/dev/null || true
EOF

    chmod +x "$CONFIG_DIR/bspwm/bspwmrc"
    log_success "bspwmrc configurado"
}

configure_sxhkdrc() {
    log_section "CONFIGURANDO SXHKD"
    
    cat > "$CONFIG_DIR/sxhkd/sxhkdrc" << 'EOF'
# wm independent hotkeys

# Terminal
super + Return
    kitty

# Programas
super + d
    rofi -show drun -theme-str 'window { width: 50%; }'

super + r
    rofi -show run -theme-str 'window { width: 50%; }'

super + w
    rofi -show window -theme-str 'window { width: 50%; }'

# Gestor de archivos
super + e
    thunar

# Firefox
super + b
    firefox &

# Captura de pantalla
Print
    scrot ~/Pictures/screenshot-$(date +%s).png && notify-send "Captura guardada"

super + Print
    scrot -s ~/Pictures/screenshot-$(date +%s).png && notify-send "Captura guardada"

# Volumen
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brillo (si está disponible)
XF86MonBrightnessUp
    brightnessctl set +5% 2>/dev/null || true

XF86MonBrightnessDown
    brightnessctl set 5%- 2>/dev/null || true

# bspwm hotkeys

# Cerrar ventana
super + q
    bspc node -c

# Alternar flotante/tiled
super + t
    bspc node -t tiled

super + shift + t
    bspc node -t floating

# Pantalla completa
super + f
    bspc node -t fullscreen

# Cambiar layout
super + space
    bspc node -t {tiled,floating,fullscreen}

# Equilibrar ventanas
super + e
    bspc node @/ --equalize

# Cambiar entre escritorios (números)
super + {1-4}
    bspc desktop -f '^{1-4}'

# Mover ventana a escritorio
super + shift + {1-4}
    bspc node -d '^{1-4}'

# Navegar entre ventanas (vim keys)
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Mover ventana (vim keys)
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Cambiar entre ventanas cíclicamente
super + Tab
    bspc node -f next.local

super + shift + Tab
    bspc node -f prev.local

# Expandir ventana
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

# Contraer ventana
super + ctrl + {h,j,k,l}
    bspc node -z {right -20 0,top 0 20,bottom 0 -20,left 20 0}

# Ajustar gaps
super + ctrl + {minus,plus}
    bspc config -d focused window_gap $(($(bspc config -d focused window_gap) {-,+} 5))

# Centrar ventana flotante
super + c
    bspc node -g center

# Reload sxhkd
super + Escape
    pkill -USR1 -x sxhkd && notify-send "sxhkd recargado"

# Apagar/Hibernar/Bloquear
super + shift + l
    loginctl lock-session

super + shift + e
    rofi -show power-menu 2>/dev/null || loginctl poweroff

super + shift + r
    loginctl reboot
EOF

    log_success "sxhkdrc configurado"
}

configure_polybar() {
    log_section "CONFIGURANDO POLYBAR"
    
    cat > "$CONFIG_DIR/polybar/config.ini" << 'EOF'
;==========================================================
; Polybar Configuration - Catppuccin Mocha
;==========================================================

[colors]
base = #1e1e2e
surface = #313244
overlay = #45475a
text = #cdd6f4
blue = #89b4fa
green = #a6e3a1
red = #f38ba8
yellow = #f9e2af
mauve = #cba6f7
cyan = #94e2d5

[bar/main]
monitor = ${env:MONITOR:}
bottom = false
width = 100%
height = 30
offset-x = 0
offset-y = 0
background = ${colors.base}
foreground = ${colors.text}
border-size = 0
padding-left = 2
padding-right = 2
module-margin = 1

font-0 = JetBrains Mono Nerd Font:size=11;3
font-1 = JetBrains Mono Nerd Font:size=14;3

modules-left = bspwm
modules-center = date time
modules-right = cpu memory pulseaudio network battery

cursor-click = pointer
cursor-scroll = ns-resize

[module/bspwm]
type = internal/bspwm
label-focused = %name%
label-focused-background = ${colors.blue}
label-focused-foreground = ${colors.base}
label-focused-padding = 1
label-focused-border = ${colors.blue}

label-occupied = %name%
label-occupied-foreground = ${colors.text}
label-occupied-padding = 1

label-empty = %name%
label-empty-foreground = ${colors.overlay}
label-empty-padding = 1

[module/date]
type = internal/date
interval = 1
date = %d/%m/%Y
format = <label>
format-prefix = 📅
format-prefix-foreground = ${colors.cyan}
format-prefix-padding = 1
label = %date%

[module/time]
type = internal/date
interval = 1
time = %H:%M:%S
format = <label>
format-prefix = 🕐
format-prefix-foreground = ${colors.mauve}
format-prefix-padding = 1
label = %time%

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <ramp-volume> <label-volume>
format-volume-padding = 1
format-muted = <label-muted>
format-muted-padding = 1
label-volume = %percentage%%
label-muted = 🔇 muted
label-muted-foreground = ${colors.red}
ramp-volume-0 = 🔈
ramp-volume-1 = 🔉
ramp-volume-2 = 🔊
ramp-volume-foreground = ${colors.green}

[module/network]
type = internal/network
interface-type = wireless
interval = 5
format-connected = <ramp-signal> <label-connected>
format-connected-padding = 1
format-disconnected = <label-disconnected>
label-connected = %essid%
label-disconnected = Not connected
label-disconnected-foreground = ${colors.red}
ramp-signal-0 = 📶
ramp-signal-1 = 📶
ramp-signal-2 = 📶
ramp-signal-foreground = ${colors.blue}

[module/cpu]
type = internal/cpu
interval = 2
format = <ramp-coreload>
format-padding = 1
label = CPU: %percentage%%
ramp-coreload-0 = ▁
ramp-coreload-1 = ▂
ramp-coreload-2 = ▃
ramp-coreload-3 = ▄
ramp-coreload-4 = ▅
ramp-coreload-5 = ▆
ramp-coreload-6 = ▇
ramp-coreload-7 = █
ramp-coreload-foreground = ${colors.yellow}

[module/memory]
type = internal/memory
interval = 2
format = <ramp-used>
format-padding = 1
label = RAM: %percentage_used%%
ramp-used-0 = ▁
ramp-used-1 = ▂
ramp-used-2 = ▃
ramp-used-3 = ▄
ramp-used-4 = ▅
ramp-used-5 = ▆
ramp-used-6 = ▇
ramp-used-7 = █
ramp-used-foreground = ${colors.mauve}

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC0
poll-interval = 5
format-charging = <ramp-capacity> <label-charging>
format-charging-padding = 1
format-discharging = <ramp-capacity> <label-discharging>
format-discharging-padding = 1
format-full = <ramp-capacity> <label-full>
format-full-padding = 1
label-charging = %percentage%%
label-discharging = %percentage%%
label-full = Full
ramp-capacity-0 = 🪫
ramp-capacity-1 = 🔋
ramp-capacity-2 = 🔋
ramp-capacity-3 = 🔋
ramp-capacity-4 = 🔌
ramp-capacity-foreground = ${colors.green}
EOF

    log_success "Polybar configurado"
}

configure_picom() {
    log_section "CONFIGURANDO PICOM"
    
    cat > "$CONFIG_DIR/picom/picom.conf" << 'EOF'
# Picom Configuration - Catppuccin Mocha Theme

# Backend
backend = "glx";
vsync = true;
dbe = false;

# Shadows
shadow = true;
shadow-radius = 7;
shadow-opacity = 0.5;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'Dunst'",
    "class_g = 'Rofi'"
];

# Fade
fading = true;
fade-delta = 3;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-exclude = [];

# Opacity
inactive-opacity = 0.85;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

opacity-rule = [
    "80:class_g = 'kitty'",
    "85:class_g = 'Thunar'",
    "90:class_g = 'Rofi'"
];

# Corner radius
corner-radius = 10;
rounded-corners-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'Dunst'",
    "window_type = 'desktop'"
];

# Animations (experimental)
transition-length = 300;
transition-pow-x = 0.1;
transition-pow-y = 0.1;
transition-pow-w = 0.1;
transition-pow-h = 0.1;
size-transition = true;

# Blur (optional)
blur-method = "dual_kawase";
blur-strength = 3;
blur-kern = "11x11gaussian";
blur-background = false;
blur-background-frame = false;

# General
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
detect-client-leader = true;
use-damage = true;
log-level = "warn";
EOF

    log_success "Picom configurado"
}

configure_dunst() {
    log_section "CONFIGURANDO DUNST"
    
    cat > "$CONFIG_DIR/dunst/dunstrc" << 'EOF'
[global]
    monitor = 0
    follow = mouse
    geometry = "300x100-10+30"
    indicate_hidden = yes
    shrink = no
    separator_height = 2
    padding = 10
    horizontal_padding = 10
    frame_width = 2
    frame_color = "#89b4fa"
    separator_color = frame
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
    stack_duplicates = yes
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    max_icon_size = 32
    icon_path = /usr/share/icons/Adwaita/16x16/status:/usr/share/icons/Adwaita/16x16/devices
    sticky_history = yes
    history_length = 20
    dmenu = /usr/bin/rofi -dmenu -p dunst
    browser = /usr/bin/firefox
    always_run_script = true
    title = Dunst
    class = Dunst
    startup_notification = false
    force_xwayland = false
    corner_radius = 10
    min_icon_size = 0
    max_icon_size = 32
    notification_limit = 0

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 10
    icon = dialog-information

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 13
    icon = dialog-information

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#f38ba8"
    frame_color = "#f38ba8"
    timeout = 0
    icon = dialog-password
EOF

    log_success "Dunst configurado"
}

configure_kitty() {
    log_section "CONFIGURANDO KITTY"
    
    cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
# Kitty Terminal Configuration - Catppuccin Mocha

font_family      JetBrains Mono Nerd Font
bold_font        JetBrains Mono Nerd Font Bold
italic_font      JetBrains Mono Nerd Font Italic
bold_italic_font JetBrains Mono Nerd Font Bold Italic

font_size 12
line_height 1.2

background_opacity 0.85
dynamic_background_opacity yes

remember_window_size  yes
initial_window_width  120c
initial_window_height 40c

enable_audio_bell no
visual_bell_duration 0.0

scrollback_lines 10000
scrollback_pager less +G -R
mouse_hide_wait 3.0

# Catppuccin Mocha Color Scheme
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
color15 #c6d0f5

# Cursor
cursor_shape block
cursor #f5e0dc

# Tabs
active_tab_background #89b4fa
active_tab_foreground #1e1e2e
inactive_tab_background #313244
inactive_tab_foreground #cdd6f4
tab_bar_background #1e1e2e

# Keybindings
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
map ctrl+shift+n new_os_window
map ctrl+shift+w close_window
map ctrl+shift+enter new_window
map ctrl+alt+right next_window
map ctrl+alt+left previous_window

# Window
window_border_width 1
window_margin_width 5
window_padding_width 10
active_border_color #89b4fa
inactive_border_color #313244
EOF

    log_success "Kitty configurado"
}

configure_gtk() {
    log_section "CONFIGURANDO GTK"
    
    # Detectar qué tema usar (puede ser Catppuccin-Mocha o catppuccin-gtk-mocha del AUR)
    local gtk_theme="Catppuccin-Mocha"
    local icon_theme="Tela-circle"
    
    # Fallback si los temas no están disponibles
    if [[ ! -d "/usr/share/themes/$gtk_theme" ]] && [[ ! -d "$HOME/.themes/$gtk_theme" ]]; then
        log_warning "Tema $gtk_theme no encontrado, usando adwaita"
        gtk_theme="Adwaita"
    fi
    
    if [[ ! -d "/usr/share/icons/$icon_theme" ]] && [[ ! -d "$HOME/.icons/$icon_theme" ]]; then
        log_warning "Iconos $icon_theme no encontrados, usando Adwaita"
        icon_theme="Adwaita"
    fi
    
    # GTK 3.0
    cat > "$CONFIG_DIR/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name = $gtk_theme
gtk-icon-theme-name = $icon_theme
gtk-font-name = JetBrains Mono Nerd Font 11
gtk-application-prefer-dark-theme = 1
gtk-decoration-layout = menu:minimize,maximize,close
gtk-button-images = 1
gtk-menu-images = 1
EOF

    # GTK 4.0
    mkdir -p "$CONFIG_DIR/gtk-4.0"
    cat > "$CONFIG_DIR/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-theme-name = $gtk_theme
gtk-icon-theme-name = $icon_theme
gtk-font-name = JetBrains Mono Nerd Font 11
gtk-application-prefer-dark-theme = 1
EOF

    # Crear carpeta gtk-4.0 assets si es necesario
    mkdir -p "$CONFIG_DIR/gtk-4.0/assets"
    
    log_success "GTK configurado (3.0 y 4.0) - Tema: $gtk_theme, Iconos: $icon_theme"
}

configure_xinitrc() {
    log_section "CONFIGURANDO XINITRC"
    
    cat > "$HOME/.xinitrc" << 'EOF'
#!/bin/bash

# X initialization script

# Cargar recursos
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Configuración de teclado
setxkbmap us
xsetroot -cursor_name left_ptr

# Inicia bspwm
exec bspwm
EOF

    chmod +x "$HOME/.xinitrc"
    log_success ".xinitrc configurado"
}

configure_xresources() {
    log_section "CONFIGURANDO XRESOURCES"
    
    cat > "$HOME/.Xresources" << 'EOF'
! Catppuccin Mocha Xresources

*.foreground:   #cdd6f4
*.background:   #1e1e2e
*.cursorColor:  #f5e0dc

! Black
*.color0:       #45475a
*.color8:       #585b70

! Red
*.color1:       #f38ba8
*.color9:       #f38ba8

! Green
*.color2:       #a6e3a1
*.color10:      #a6e3a1

! Yellow
*.color3:       #f9e2af
*.color11:      #f9e2af

! Blue
*.color4:       #89b4fa
*.color12:      #89b4fa

! Magenta
*.color5:       #cba6f7
*.color13:      #cba6f7

! Cyan
*.color6:       #94e2d5
*.color14:      #94e2d5

! White
*.color7:       #bac2de
*.color15:      #c6d0f5

! Font settings
*.font:         JetBrains Mono Nerd Font:size=12
EOF

    log_success ".Xresources configurado"
}

configure_user_dirs() {
    log_section "CONFIGURANDO USER-DIRS"
    
    cat > "$HOME/.config/user-dirs.dirs" << 'EOF'
# This file is written by xdg-user-dirs-update
# If you want to change or delete these user directories handled by xdg-user-dirs
# you can edit the default file ~/.config/user-dirs.defaults and run xdg-user-dirs-update.
#
# See man xdg-user-dirs for more information.

XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

    mkdir -p "$HOME"/{Desktop,Downloads,Documents,Pictures,Music,Videos}
    log_success "Directorios de usuario configurados"
}

# ============================================================================
# SCRIPTS AUXILIARES
# ============================================================================

create_launch_polybar_script() {
    log_section "CREANDO SCRIPT DE POLYBAR"
    
    cat > "$BIN_DIR/launch_polybar" << 'EOF'
#!/bin/bash

# Mata instancias previas de polybar
killall -q polybar || true

# Espera a que los procesos mueran
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Obtén los monitores disponibles
if command -v xrandr &> /dev/null; then
    mapfile -t monitors < <(xrandr --query | grep " connected" | cut -d" " -f1)
else
    monitors=("HDMI-1")
fi

# Lanza polybar en cada monitor
for monitor in "${monitors[@]}"; do
    MONITOR=$monitor polybar -c ~/.config/polybar/config.ini main &
done

echo "Polybar iniciado en $(printf '%s ' "${monitors[@]}")"
EOF

    chmod +x "$BIN_DIR/launch_polybar"
    log_success "Script launch_polybar creado"
}

create_xrandr_setup_script() {
    log_section "CREANDO SCRIPT DE XRANDR"
    
    cat > "$BIN_DIR/xrandr_setup" << 'EOF'
#!/bin/bash

# Script de configuración de pantalla con xrandr

# Detectar monitores
mapfile -t monitors < <(xrandr --query | grep " connected" | cut -d" " -f1)

if [[ ${#monitors[@]} -eq 0 ]]; then
    echo "No se detectaron monitores conectados"
    exit 1
fi

if [[ ${#monitors[@]} -eq 1 ]]; then
    # Un solo monitor
    xrandr --output "${monitors[0]}" --auto
    echo "Modo de un monitor configurado"
elif [[ ${#monitors[@]} -eq 2 ]]; then
    # Dos monitores - lado a lado
    xrandr --output "${monitors[0]}" --auto --output "${monitors[1]}" --auto --right-of "${monitors[0]}"
    echo "Modo de dos monitores configurado (lado a lado)"
else
    # Múltiples monitores
    xrandr --output "${monitors[0]}" --auto
    for ((i=1; i<${#monitors[@]}; i++)); do
        xrandr --output "${monitors[$i]}" --auto --right-of "${monitors[$((i-1))]}"
    done
    echo "Múltiples monitores configurados"
fi
EOF

    chmod +x "$BIN_DIR/xrandr_setup"
    log_success "Script xrandr_setup creado"
}

create_wallpaper_script() {
    log_section "CREANDO SCRIPT DE WALLPAPER"
    
    cat > "$BIN_DIR/setup_wallpaper" << 'EOF'
#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
WALLPAPER_FILE="$WALLPAPER_DIR/catppuccin-wallpaper.png"

mkdir -p "$WALLPAPER_DIR"

# Intenta descargar wallpaper de Catppuccin
if command -v curl &> /dev/null && command -v wget &> /dev/null; then
    echo "Descargando wallpaper de Catppuccin..."
    
    # URL del repositorio de wallpapers
    REPO_URL="https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/catppuccin-mocha.png"
    
    if wget -q -O "$WALLPAPER_FILE" "$REPO_URL" 2>/dev/null; then
        echo "Wallpaper descargado exitosamente"
        feh --bg-scale "$WALLPAPER_FILE"
    else
        echo "Error al descargar wallpaper, usando fondo de color sólido"
        # Crear wallpaper de color sólido como alternativa
        if command -v convert &> /dev/null; then
            convert -size 1920x1080 xc:'#1e1e2e' "$WALLPAPER_FILE"
            feh --bg-scale "$WALLPAPER_FILE"
        fi
    fi
else
    echo "curl o wget no están instalados"
    # Crear wallpaper de color sólido
    if command -v convert &> /dev/null; then
        convert -size 1920x1080 xc:'#1e1e2e' "$WALLPAPER_FILE"
        feh --bg-scale "$WALLPAPER_FILE"
    fi
fi
EOF

    chmod +x "$BIN_DIR/setup_wallpaper"
    log_success "Script setup_wallpaper creado"
}

create_default_wallpaper() {
    log_info "Creando wallpaper predeterminado..."
    
    if command -v convert &> /dev/null; then
        convert -size 1920x1080 xc:'#1e1e2e' "$WALLPAPER_DIR/default.png"
        log_success "Wallpaper predeterminado creado"
    else
        log_warning "ImageMagick no disponible, wallpaper no creado"
    fi
}

# ============================================================================
# CONFIGURACIÓN POST-INSTALACIÓN
# ============================================================================

post_install_setup() {
    log_section "CONFIGURACIÓN POST-INSTALACIÓN"
    
    # Habilitar servicios
    log_info "Habilitando servicios del sistema..."
    
    systemctl enable sddm --now
    systemctl enable NetworkManager --now
    systemctl --user enable pipewire wireplumber --now
    
    log_success "Servicios habilitados"
    
    # Agregar usuario a grupos necesarios
    log_info "Agregando usuario a grupos necesarios..."
    for group in audio video network storage wheel; do
        usermod -aG "$group" "$SUDO_USER" 2>/dev/null || true
    done
    
    log_success "Grupos configurados"
}

configure_bash() {
    log_section "CONFIGURANDO BASH"
    
    if ! grep -q "# BSPWM ALIASES" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# BSPWM ALIASES
alias ll='ls -lah'
alias la='ls -la'
alias l='ls -lh'
alias grep='grep --color=auto'
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -i'
alias cls='clear'
alias update='sudo pacman -Syu'
alias search='pacman -Ss'
alias install='sudo pacman -S'
alias remove='sudo pacman -R'
alias aur-install='yay -S'
alias aur-search='yay -Ss'

# Función para iniciar X
startx_bspwm() {
    startx ~/.xinitrc
}

# Prompt personalizado con colores
export PS1='\[\033[0;35m\][\u\[\033[0;36m\]@\[\033[0;35m\]\h\[\033[0;35m\]]\[\033[0;37m\]:\[\033[0;34m\]\w\[\033[0;35m\]\$\[\033[0;37m\] '
EOF
        log_success "Aliases de bash agregados"
    fi
}

# ============================================================================
# MENU INTERACTIVO
# ============================================================================

show_optional_packages() {
    log_section "PAQUETES OPCIONALES"
    
    echo -e "${CYAN}¿Deseas instalar paquetes opcionales adicionales?${NC}\n"
    
    local optional_packages=(
        "firefox|Navegador web Firefox"
        "chromium|Navegador web Chromium"
        "neovim|Editor de texto avanzado"
        "htop|Monitor de procesos interactivo"
        "fastfetch|Información del sistema (fastfetch)"
        "vlc|Reproductor multimedia VLC"
        "thunderbird|Cliente de correo Thunderbird"
        "gimp|Editor de imágenes GIMP"
        "blender|Suite 3D Blender"
        "code|Visual Studio Code"
    )
    
    local counter=1
    declare -A package_map
    
    for package in "${optional_packages[@]}"; do
        local name="${package%%|*}"
        local desc="${package##|*}"
        echo "$counter) $desc"
        package_map[$counter]="$name"
        ((counter++))
    done
    
    echo -e "${YELLOW}Ingresa los números separados por espacio (ej: 1 3 5) o presiona Enter para omitir:${NC}"
    read -r -t 30 selections || true
    
    if [[ -n "$selections" ]]; then
        for selection in $selections; do
            if [[ -n "${package_map[$selection]}" ]]; then
                local pkg="${package_map[$selection]}"
                log_info "Instalando $pkg..."
                if pacman -S --noconfirm "$pkg" 2>/dev/null; then
                    log_success "$pkg instalado correctamente"
                else
                    log_warning "No se pudo instalar $pkg desde los repositorios oficiales"
                fi
            fi
        done
    else
        log_info "Se omitió la instalación de paquetes opcionales"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    clear
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║  ARCH LINUX - BSPWM + CATPPUCCIN SETUP SCRIPT         ║"
    echo "║  Instalación automática desde Arch Base               ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Verificaciones iniciales
    log_section "VERIFICACIONES INICIALES"
    check_root
    check_internet
    
    # Confirmación antes de continuar
    echo -e "${YELLOW}Este script instalará un entorno de escritorio completo.${NC}"
    echo -e "${YELLOW}¿Deseas continuar? (s/n)${NC}"
    read -r confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        log_warning "Instalación cancelada"
        exit 0
    fi
    
    # Backup de configuraciones existentes
    backup_existing_config
    
    # Actualizar sistema
    update_system
    echo -e "${YELLOW}¿Deseas continuar con la instalación? (s/n)${NC}"
    read -r confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        log_warning "Instalación cancelada"
        exit 0
    fi
    
    # Instalación de yay (puede fallar, pero el script continúa)
    install_yay || log_warning "yay no pudo instalarse completamente"
    
    # Instalación de paquetes
    install_packages || log_warning "Algunos paquetes pueden no haberse instalado"
    
    # Crear estructura de directorios
    create_directory_structure
    
    # Configurar archivos
    configure_bspwmrc
    configure_sxhkdrc
    configure_polybar
    configure_picom
    configure_dunst
    configure_kitty
    configure_gtk
    configure_xinitrc
    configure_xresources
    configure_user_dirs
    
    # Scripts auxiliares
    create_launch_polybar_script
    create_xrandr_setup_script
    create_wallpaper_script
    create_default_wallpaper
    
    # Ejecutar script de wallpaper
    "$BIN_DIR/setup_wallpaper" 2>/dev/null || true
    
    # Configuración post-instalación
    post_install_setup
    configure_bash
    
    # Paquetes opcionales
    show_optional_packages
    
    # Resumen final
    log_section "INSTALACIÓN COMPLETADA ✓"
    echo -e "${GREEN}La instalación ha finalizado exitosamente!${NC}\n"
    echo -e "${CYAN}Información importante:${NC}"
    echo -e "  • Config: $CONFIG_DIR"
    echo -e "  • Scripts: $BIN_DIR"
    echo -e "  • Wallpapers: $WALLPAPER_DIR"
    echo -e "  • Backup: $BACKUP_DIR"
    echo ""
    echo -e "${CYAN}Próximos pasos:${NC}"
    echo -e "  1. Inicia sesión en SDDM (selecciona bspwm)"
    echo -e "  2. Usa Super (Windows) + Enter para abrir kitty"
    echo -e "  3. Personaliza las configuraciones según tus preferencias"
    echo ""
    echo -e "${YELLOW}¿Deseas reiniciar ahora? (s/n)${NC}"
    read -r reboot
    if [[ "$reboot" == "s" || "$reboot" == "S" ]]; then
        log_info "Reiniciando..."
        systemctl reboot
    else
        log_info "Ejecuta 'startx' para iniciar el servidor X cuando estés listo"
    fi
}

# Ejecutar función principal
main "$@"
