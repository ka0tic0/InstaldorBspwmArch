#!/usr/bin/env bash

# ==============================================================================
# SCRIPT DE INSTALACIÓN Y CONFIGURACIÓN AUTO-CONTENIDO BSPWM - CATPPUCCIN MOCHA
# Sistema Operativo: Arch Linux (Instalación Base)
# ==============================================================================

# Detener el script si ocurre un error crítico en comandos no manejados
set -e

# ------------------------------------------------------------------------------
# 0. VARIABLES Y DEFINICIÓN DE COLORES
# ------------------------------------------------------------------------------
COLOR_RESET="\033[0m"
COLOR_SUCCESS="\033[0;32m"  # Verde
COLOR_WARN="\033[0;33m"     # Amarillo
COLOR_ERROR="\033[0;31m"    # Rojo
COLOR_INFO="\033[0;36m"     # Ciano

# Detección del usuario objetivo (si se ejecuta con sudo)
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
else
    echo -e "${COLOR_WARN}[!] Ejecutando como root directo. Ingresa el nombre del usuario normal para configurar:${COLOR_RESET}"
    read -r TARGET_USER
    if ! id "$TARGET_USER" &>/dev/null; then
        echo -e "${COLOR_ERROR}[X] El usuario '$TARGET_USER' no existe en el sistema. Abortando.${COLOR_RESET}"
        exit 1
    fi
fi

USER_HOME="/home/$TARGET_USER"
BACKUP_DIR="$USER_HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# ------------------------------------------------------------------------------
# FUNCIONES DE UTILIDAD Y MANEJO DE ERRORES
# ------------------------------------------------------------------------------
log_info() {
    echo -e "${COLOR_INFO}[INFO] $1${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_SUCCESS}[OK] $1${COLOR_RESET}"
}

log_warn() {
    echo -e "${COLOR_WARN}[ADVERTENCIA] $1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_ERROR}[ERROR] $1${COLOR_RESET}"
}

# Trap para rollback básico en caso de fallo crítico
cleanup_on_failure() {
    log_error "Ocurrió un error crítico durante la instalación. Revisa los mensajes anteriores."
}
trap cleanup_on_failure ERR

pause_step() {
    echo ""
    read -p "Presiona ENTER para continuar con el siguiente paso..."
    echo ""
}

# Ejecutar comandos como el usuario no-root
run_as_user() {
    sudo -u "$TARGET_USER" bash -c "$1"
}

# ------------------------------------------------------------------------------
# 1. VERIFICACIÓN INICIAL
# ------------------------------------------------------------------------------
check_environment() {
    log_info "1/10 - Verificando entorno e inicio de permisos..."

    # Verificar root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como ROOT (o mediante sudo)."
        exit 1
    fi

    # Verificar conexión a Internet
    log_info "Comprobando conexión a Internet..."
    if ! ping -c 1 archlinux.org &>/dev/null; then
        log_error "No hay conexión a internet disponible. Conecta la red e intenta de nuevo."
        exit 1
    fi
    log_success "Conexión a internet verificada."

    # Actualización del sistema
    log_info "Actualizando repositorios y el sistema (pacman -Syu)..."
    pacman -Syu --noconfirm

    log_success "Sistema actualizado correctamente."

    # Pregunta de confirmación
    read -p "¿Deseas continuar con la instalación de paquetes y configuraciones? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        log_warn "Instalación cancelada por el usuario."
        exit 0
    fi
}

# ------------------------------------------------------------------------------
# 2. INSTALACIÓN DE PAQUETES DE PACMAN
# ------------------------------------------------------------------------------
install_base_packages() {
    log_info "2/10 - Instalando paquetes base requeridos..."

    local PACKAGES=(
        # Servidor X
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
        # BSPWM / Ventanas
        bspwm sxhkd
        # Terminal y Utilidades GUI
        kitty rofi picom dunst feh thunar thunar-volman lxappearance sddm
        # Barra
        polybar
        # Red
        networkmanager network-manager-applet
        # Audio PipeWire
        pipewire pipewire-pulse pipewire-alsa wireplumber
        # Fuentes y Símbolos
        ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji ttf-font-awesome
        # Utilidades Base y Capturas
        git curl wget base-devel xdg-user-dirs scrot
    )

    log_info "Instalando paquetes desde repositorios oficiales..."
    pacman -S --needed --noconfirm "${PACKAGES[@]}"

    log_success "Paquetes base instalados correctamente."
}

# ------------------------------------------------------------------------------
# 3. INSTALACIÓN DE AUR HELPER (YAY) Y PAQUETES OPCIONALES
# ------------------------------------------------------------------------------
install_yay_and_optionals() {
    log_info "3/10 - Configuración de YAY (AUR Helper) y paquetes opcionales..."

    # Verificar si yay ya está instalado
    if ! run_as_user "command -v yay &>/dev/null"; then
        read -p "¿Deseas instalar 'yay' (AUR Helper)? (s/n): " install_yay_choice
        if [[ "$install_yay_choice" == "s" || "$install_yay_choice" == "S" ]]; then
            log_info "Clonando e instalando yay desde AUR..."
            YAY_TMP=$(mktemp -d)
            chown -R "$TARGET_USER:$TARGET_USER" "$YAY_TMP"
            run_as_user "git clone https://aur.archlinux.org/yay.git $YAY_TMP/yay"
            (cd "$YAY_TMP/yay" && run_as_user "makepkg -si --noconfirm")
            rm -rf "$YAY_TMP"
            log_success "yay instalado correctamente."
        fi
    else
        log_success "yay ya se encuentra instalado."
    fi

    # Paquetes opcionales
    read -p "¿Deseas instalar navegadores (Firefox / Brave)? (s/n): " inst_web
    if [[ "$inst_web" == "s" || "$inst_web" == "S" ]]; then
        pacman -S --needed --noconfirm firefox || true
        if run_as_user "command -v yay &>/dev/null"; then
            run_as_user "yay -S --needed --noconfirm brave-bin" || true
        fi
    fi

    read -p "¿Deseas instalar herramientas CLI (Neovim, Htop, Fastfetch)? (s/n): " inst_cli
    if [[ "$inst_cli" == "s" || "$inst_cli" == "S" ]]; then
        pacman -S --needed --noconfirm neovim htop fastfetch
    fi

    read -p "¿Deseas instalar los temas GTK Catppuccin Mocha y Tela-Circle Icons desde AUR? (s/n): " inst_themes
    if [[ "$inst_themes" == "s" || "$inst_themes" == "S" ]]; then
        if run_as_user "command -v yay &>/dev/null"; then
            run_as_user "yay -S --needed --noconfirm catppuccin-gtk-theme-mocha tela-circle-icon-theme-nord" || true
        else
            log_warn "Se requiere 'yay' para instalar los temas de AUR. Saltando este paso."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 4. CREACIÓN DE DIRECTORIOS Y BACKUPS
# ------------------------------------------------------------------------------
setup_directories() {
    log_info "4/10 - Creando estructura de directorios y resguardo de datos..."

    local DIRS=(
        "$USER_HOME/.config/bspwm"
        "$USER_HOME/.config/sxhkd"
        "$USER_HOME/.config/polybar"
        "$USER_HOME/.config/picom"
        "$USER_HOME/.config/dunst"
        "$USER_HOME/.config/rofi"
        "$USER_HOME/.config/kitty"
        "$USER_HOME/.config/gtk-3.0"
        "$USER_HOME/.config/gtk-4.0"
        "$USER_HOME/.local/bin"
        "$USER_HOME/Pictures/wallpapers"
    )

    # Realizar respaldo si existen configuraciones previas
    mkdir -p "$BACKUP_DIR"
    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            cp -rf "$dir" "$BACKUP_DIR/" 2>/dev/null || true
        fi
        mkdir -p "$dir"
    done

    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config" "$USER_HOME/.local" "$USER_HOME/Pictures"
    log_success "Estructura de directorios lista. Respaldos guardados en $BACKUP_DIR"
}

# ------------------------------------------------------------------------------
# 5. CREACIÓN DE ARCHIVOS DE CONFIGURACIÓN
# ------------------------------------------------------------------------------
configure_bspwm() {
    log_info "Configurando bspwm..."
    local FILE="$USER_HOME/.config/bspwm/bspwmrc"

    cat << 'EOF' > "$FILE"
#!/usr/bin/env bash

# --- BSPWM CONFIGURATION (Catppuccin Mocha Theme) ---

# Cargar atajos de teclado sxhkd
pgrep -x sxhkd > /dev/null || sxhkd &

# Detección y ajuste de pantallas (xrandr)
if command -v xrandr >/dev/null; then
    PRIMARY_MONITOR=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
    if [ -z "$PRIMARY_MONITOR" ]; then
        PRIMARY_MONITOR=$(xrandr --query | grep " connected" | head -n1 | cut -d" " -f1)
    fi
    [ -n "$PRIMARY_MONITOR" ] && xrandr --output "$PRIMARY_MONITOR" --auto
fi

# Configuración de escritorios
bspc monitor -d I:Web II:Term III:Code IV:Misc

# Apariencia y Gaps
bspc config border_width         2
bspc config window_gap          10
bspc config split_ratio          0.52

# Colores Catppuccin Mocha
bspc config normal_border_color  "#313244"
bspc config focused_border_color "#89b4fa"
bspc config presel_feedback_color "#cba6f7"

# Comportamiento de ventanas
bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config center_pseudo_tiled  true
bspc config focus_follows_pointer true

# Reglas de ventanas (Flotantes y Centradas)
bspc rule -a Rofi state=floating center=true
bspc rule -a Lxappearance state=floating center=true
bspc rule -a Thunar state=floating center=true
bspc rule -a Feh state=floating center=true

# --- AUTOSTART SERVICIOS ---
# Compositor de transparencias y sombras
pgrep -x picom > /dev/null || picom --config ~/.config/picom/picom.conf -b &

# Daemon de notificaciones
pgrep -x dunst > /dev/null || dunst &

# Applet de red
nm-applet &

# Fondo de pantalla y Polybar
~/.local/bin/wallpaper_setup &
~/.local/bin/launch_polybar &
EOF

    chmod +x "$FILE"
    chown "$TARGET_USER:$TARGET_USER" "$FILE"
}

configure_sxhkd() {
    log_info "Configurando sxhkd..."
    local FILE="$USER_HOME/.config/sxhkd/sxhkdrc"

    cat << 'EOF' > "$FILE"
# --- SXHKD KEYBINDINGS ---

# Terminal (Kitty)
super + Return
	kitty

# Lanzadores de Rofi
super + d
	rofi -show drun
super + r
	rofi -show run
super + w
	rofi -show window

# Cerrar o matar ventana activa
super + q
	bspc node -c

# Reiniciar / Salir de BSPWM
super + Alt + {r,q}
	bspc {wm -r, quit}

# --- NAVEGACIÓN Y FOCO (Vim Keys: j,k,l,;) ---
super + {j,k,l,semicolon}
	bspc node -f {west,south,north,east}

# Mover ventana (Vim Keys)
super + shift + {j,k,l,semicolon}
	bspc node -s {west,south,north,east}

# Cambio de escritorios (1-4)
super + {1-4}
	bspc desktop -f '^{1-4}'

# Mover ventana a escritorio (1-4)
super + shift + {1-4}
	bspc node -d '^{1-4}'

# --- LAYOUTS Y ESTADOS DE VENTANA ---
# Modo Tiled (Mosaico)
super + t
	bspc node -t tiled

# Modo Monocle (Pantalla completa en contenedor)
super + m
	bspc desktop -l next

# Modo Fullscreen (Pantalla Completa)
super + f
	bspc node -t ~fullscreen

# Alternar Layout del escritorio
super + space
	bspc desktop -l next

# Ajustar Gaps dinámicamente (Super + Ctrl + h/l)
super + ctrl + {h,l}
	bspc config window_gap $(( $(bspc config window_gap) {-,+} 2 ))

# --- TECLAS MULTIMEDIA ---
XF86AudioRaiseVolume
	pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
	pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
	pactl set-sink-mute @DEFAULT_SINK@ toggle

# Capturas de Pantalla (Scrot)
Print
	scrot '%Y-%m-%d-%T_$wx$h_scrot.png' -e 'mv $f ~/Pictures/'
EOF

    chown "$TARGET_USER:$TARGET_USER" "$FILE"
}

configure_polybar() {
    log_info "Configurando Polybar..."
    local FILE="$USER_HOME/.config/polybar/config.ini"

    cat << 'EOF' > "$FILE"
; --- POLYBAR CATPPUCCIN MOCHA CONFIGURATION ---

[colors]
base = #1e1e2e
mantle = #181825
text = #cdd6f4
blue = #89b4fa
green = #a6e3a1
red = #f38ba8
yellow = #f9e2af
mauve = #cba6f7
surface0 = #313244

[bar/main]
width = 100%
height = 30pt
radius = 0

background = ${colors.base}
foreground = ${colors.text}

line-size = 2pt
border-size = 0pt

padding-left = 1
padding-right = 1
module-margin = 1

separator = |
separator-foreground = ${colors.surface0}

font-0 = "JetBrainsMono Nerd Font:size=11;2"

modules-left = bspwm
modules-center = date time
modules-right = cpu memory network battery volume

cursor-click = pointer
cursor-scroll = ns-resize

enable-ipc = true

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
inline-mode = false
enable-click = true
enable-scroll = true

label-focused = %name%
label-focused-background = ${colors.surface0}
label-focused-underline= ${colors.mauve}
label-focused-foreground = ${colors.mauve}
label-focused-padding = 1

label-occupied = %name%
label-occupied-foreground = ${colors.blue}
label-occupied-padding = 1

label-urgent = %name%!
label-urgent-background = ${colors.red}
label-urgent-padding = 1

label-empty = %name%
label-empty-foreground = #585b70
label-empty-padding = 1

[module/date]
type = internal/date
interval = 1
date = %Y-%m-%d
label = 󰸗 %date%
label-foreground = ${colors.blue}

[module/time]
type = internal/date
interval = 1
time = %H:%M:%S
label = 󰥔 %time%
label-foreground = ${colors.green}

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = " "
format-prefix-foreground = ${colors.yellow}
label = %percentage:2%%

[module/memory]
type = internal/memory
interval = 2
format-prefix = " "
format-prefix-foreground = ${colors.mauve}
label = %percentage_used%%

[module/network]
type = internal/network
interface-type = wired
interval = 3.0
label-connected = 󰈀 Online
label-connected-foreground = ${colors.green}
label-disconnected = 󰈂 Offline
label-disconnected-foreground = ${colors.red}

[module/battery]
type = internal/battery
full-at = 99
low-at = 15
battery = BAT0
adapter = ADP1
poll-interval = 5

format-charging = <label-charging>
label-charging = 󰂄 %percentage%%
label-charging-foreground = ${colors.green}

format-discharging = <label-discharging>
label-discharging = 󰁹 %percentage%%
label-discharging-foreground = ${colors.yellow}

[module/volume]
type = internal/pulseaudio
format-volume = <label-volume>
label-volume = 󰕾 %percentage%%
label-volume-foreground = ${colors.blue}
label-muted = 󰖁 Muted
label-muted-foreground = ${colors.red}
EOF

    chown "$TARGET_USER:$TARGET_USER" "$FILE"
}

configure_picom() {
    log_info "Configurando Picom..."
    local FILE="$USER_HOME/.config/picom/picom.conf"

    cat << 'EOF' > "$FILE"
# --- PICOM CONFIGURATION ---

backend = "xrender";
vsync = true;

# Opacidad
active-opacity = 1.0;
inactive-opacity = 0.8;
frame-opacity = 1.0;

opacity-rule = [
   
    "90:class_g = 'Rofi'"
];

# Sombras
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;

# Esquinas Redondeadas
corner-radius = 10;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];
EOF

    chown "$TARGET_USER:$TARGET_USER" "$FILE"
}

configure_dunst() {
    log_info "Configurando Dunst..."
    local FILE="$USER_HOME/.config/dunst/dunstrc"

    cat << 'EOF' > "$FILE"
[global]
    monitor = 0
    follow = mouse
    width = 300
    height = 100
    origin = top-right
    offset = 10x10
    indicate_missing = yes
    notification_height = 0
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    text_icon_padding = 0
    frame_width = 2
    frame_color = "#89b4fa"
    separator_color = frame
    sort = yes
    font = JetBrains Mono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    show_age_threshold = 60
    word_wrap = yes
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

    chown "$TARGET_USER:$TARGET_USER" "$FILE"
}

configure_kitty() {
    log_info "Configurando Kitty..."
    local FILE="$USER_HOME/.config/kitty/kitty.conf"

    cat << 'EOF' > "$FILE"
# --- KITTY CONFIGURATION (Catppuccin Mocha) ---

font_family      JetBrains Mono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0

background_opacity 0.85
scrollback_lines 10000
mouse_hide_wait true

# Colores Catppuccin Mocha
foreground              #cdd6f4
background              #1e1e2e
selection_foreground    #1e1e2e
selection_background    #f5e0dc

# Cursor
cursor                  #f5e0dc
cursor_text_color       #1e1e2e

# 16 colores terminal
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
EOF

    chown "$TARGET_USER:$TARGET_USER" "$FILE"
}

configure_gtk() {
    log_info "Configurando GTK 3.0 y 4.0..."

    local CONFIG_CONTENT="[Settings]
gtk-theme-name=Catppuccin-Mocha
gtk-icon-theme-name=Tela-circle
gtk-font-name=JetBrains Mono Nerd Font 11
"

    echo "$CONFIG_CONTENT" > "$USER_HOME/.config/gtk-3.0/settings.ini"
    echo "$CONFIG_CONTENT" > "$USER_HOME/.config/gtk-4.0/settings.ini"

    # Xresources Catppuccin
    cat << 'EOF' > "$USER_HOME/.Xresources"
*.foreground: #cdd6f4
*.background: #1e1e2e
*.color0: #45475a
*.color1: #f38ba8
*.color2: #a6e3a1
*.color3: #f9e2af
*.color4: #89b4fa
*.color5: #cba6f7
*.color6: #94e2d5
*.color7: #bac2de
EOF

    # xinitrc
    echo "exec bspwm" > "$USER_HOME/.xinitrc"

    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/gtk-3.0/settings.ini" "$USER_HOME/.config/gtk-4.0/settings.ini" "$USER_HOME/.Xresources" "$USER_HOME/.xinitrc"
}

# ------------------------------------------------------------------------------
# 6. SCRIPTS PERSONALIZADOS (~/.local/bin)
# ------------------------------------------------------------------------------
setup_scripts() {
    log_info "6/10 - Creando scripts de apoyo en ~/.local/bin..."

    # Script launch_polybar
    cat << 'EOF' > "$USER_HOME/.local/bin/launch_polybar"
#!/usr/bin/env bash
killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

if command -v xrandr >/dev/null; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main -c ~/.config/polybar/config.ini &
  done
else
  polybar --reload main -c ~/.config/polybar/config.ini &
fi
EOF

    # Script wallpaper_setup
    cat << 'EOF' > "$USER_HOME/.local/bin/wallpaper_setup"
#!/usr/bin/env bash
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
DEFAULT_WALL="$WALLPAPER_DIR/catppuccin_wallpaper.png"

if [ -f "$DEFAULT_WALL" ]; then
    feh --bg-scale "$DEFAULT_WALL"
else
    # Descargar wallpaper si no existe
    mkdir -p "$WALLPAPER_DIR"
    curl -s -L "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/cat_leave.png" -o "$DEFAULT_WALL" || true
    if [ -f "$DEFAULT_WALL" ]; then
        feh --bg-scale "$DEFAULT_WALL"
    else
        xsetroot -solid "#1e1e2e"
    fi
fi
EOF

    # Script statusbar_launcher
    cat << 'EOF' > "$USER_HOME/.local/bin/statusbar_launcher"
#!/usr/bin/env bash
~/.local/bin/launch_polybar
EOF

    # Script quick_start (Resumen y atajos rapidos)
    cat << 'EOF' > "$USER_HOME/.local/bin/quick_start"
#!/usr/bin/env bash
echo "============================================="
echo "   ENTORNO BSPWM + CATPPUCCIN MOCHA READY   "
echo "============================================="
echo " Atajos básicos:"
echo "  - Super + Enter       : Abrir Terminal (Kitty)"
echo "  - Super + d           : Menú de aplicaciones (Rofi)"
echo "  - Super + q           : Cerrar ventana activa"
echo "  - Super + 1..4        : Cambiar de escritorio"
echo "  - Super + Shift + 1..4: Mover ventana a escritorio"
echo "  - Super + Vim Keys    : Navegar (j: abajo, k: arriba, l: derecha, ;: izquierda)"
echo "============================================="
EOF

    chmod +x "$USER_HOME/.local/bin/"*
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.local/bin"
}

# ------------------------------------------------------------------------------
# 7. DESCARGA DE WALLPAPERS
# ------------------------------------------------------------------------------
download_wallpapers() {
    log_info "7/10 - Descargando fondos de pantalla Catppuccin..."
    
    local WALL_DIR="$USER_HOME/Pictures/wallpapers"
    mkdir -p "$WALL_DIR"

    # Descarga directa desde repositorio GitHub Catppuccin Wallpapers
    run_as_user "curl -s -L 'https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/cat_leave.png' -o '$WALL_DIR/catppuccin_wallpaper.png'" || true

    chown -R "$TARGET_USER:$TARGET_USER" "$WALL_DIR"
    log_success "Wallpaper guardado en $WALL_DIR/catppuccin_wallpaper.png"
}

# ------------------------------------------------------------------------------
# 8. CONFIGURACIÓN POST-INSTALACIÓN Y SERVICIOS
# ------------------------------------------------------------------------------
post_install() {
    log_info "8/10 - Habilitando servicios y ajustando permisos de usuario..."

    # Habilitar NetworkManager
    systemctl enable NetworkManager

    # Habilitar Display Manager SDDM
    systemctl enable sddm

    # Grupos de usuario
    log_info "Añadiendo usuario '$TARGET_USER' a los grupos (audio, video, network, storage, wheel)..."
    usermod -aG audio,video,network,storage,wheel "$TARGET_USER"

    # Carpetas XDG
    run_as_user "xdg-user-dirs-update" || true

    # Alias en .bashrc
    local BASHRC="$USER_HOME/.bashrc"
    if ! grep -q "catppuccin_aliases" "$BASHRC" 2>/dev/null; then
        cat << 'EOF' >> "$BASHRC"

# --- catppuccin_aliases ---
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'
alias quickstart='~/.local/bin/quick_start'
EOF
    fi

    chown "$TARGET_USER:$TARGET_USER" "$BASHRC"
    log_success "Servicios y configuraciones de usuario completadas."
}

# ------------------------------------------------------------------------------
# EJECUCIÓN PRINCIPAL
# ------------------------------------------------------------------------------
main() {
    clear
    echo -e "${COLOR_INFO}"
    echo "================================================================="
    echo "   INSTALADOR AUTOMÁTICO BSPWM + CATPPUCCIN MOCHA EN ARCH LINUX  "
    echo "================================================================="
    echo -e "${COLOR_RESET}"

    check_environment
    pause_step

    install_base_packages
    pause_step

    install_yay_and_optionals
    pause_step

    setup_directories
    configure_bspwm
    configure_sxhkd
    configure_polybar
    configure_picom
    configure_dunst
    configure_kitty
    configure_gtk
    pause_step

    setup_scripts
    download_wallpapers
    post_install

    echo ""
    log_success "================================================================"
    log_success " INSTALACIÓN Y CONFIGURACIÓN COMPLETADAS CON ÉXITO "
    log_success "================================================================"
    echo ""
    echo -e "Resumen de lo instalado:"
    echo -e " - Entorno de Escritorio: BSPWM + SXHKD + Polybar"
    echo -e " - Servidor Gráfico y DM: Xorg + SDDM"
    echo -e " - Estilo Visual: Catppuccin Mocha (Gaps, Transparencia, Colores)"
    echo -e " - Utilidades: Kitty, Rofi, Picom, Dunst, Feh, Thunar, NetworkManager"
    echo ""

    read -p "¿Deseas reiniciar el sistema ahora? (s/n): " reboot_choice
    if [[ "$reboot_choice" == "s" || "$reboot_choice" == "S" ]]; then
        log_info "Reiniciando el sistema..."
        reboot
    else
        log_info "Puedes iniciar sesión manualmente ejecutando 'startx' o iniciando SDDM con 'systemctl start sddm'."
    fi
}

# Iniciar proceso
main
