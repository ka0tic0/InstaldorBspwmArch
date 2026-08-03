#!/usr/bin/env bash
set -euo pipefail
# apply_bspwm_catppuccin_tweaks.sh
# - Hace backup de las configs existentes.
# - Sobrescribe polybar, picom, bspwm y sxhkd con versiones que:
#   * Polybar con transparencia y diseño estético Catppuccin.
#   * Picom con transparencias, blur y reglas de opacidad.
#   * BSPWM reducido a 5 escritorios.
#
# Uso: chmod +x apply_bspwm_catppuccin_tweaks.sh && ./apply_bspwm_catppuccin_tweaks.sh

timestamp() { date +%Y%m%d%H%M%S; }

BACKUP_TS="$(timestamp)"
BAK_DIR="$HOME/.config/backup_bspwm_catppuccin_$BACKUP_TS"
mkdir -p "$BAK_DIR"

info(){ printf "\n[INFO] %s\n" "$*"; }
warn(){ printf "\n[WARN] %s\n" "$*"; }
err(){ printf "\n[ERROR] %s\n" "$*"; exit 1; }

# Rutas de destino
POLYBAR_DIR="$HOME/.config/polybar"
PICOM_DIR="$HOME/.config/picom"
BSPWM_DIR="$HOME/.config/bspwm"
SXHKD_DIR="$HOME/.config/sxhkd"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$POLYBAR_DIR" "$PICOM_DIR" "$BSPWM_DIR" "$SXHKD_DIR" "$LOCAL_BIN"

# Realizar backups si existen
for f in \
  "$POLYBAR_DIR/config" \
  "$POLYBAR_DIR/launch.sh" \
  "$POLYBAR_DIR/scripts/volume.sh" \
  "$POLYBAR_DIR/scripts/network.sh" \
  "$PICOM_DIR/picom.conf" \
  "$BSPWM_DIR/bspwmrc" \
  "$SXHKD_DIR/sxhkdrc"
do
  if [ -f "$f" ]; then
    mkdir -p "$BAK_DIR/$(dirname "${f#$HOME/.config/}")"
    cp -v "$f" "$BAK_DIR/$(basename "$f").bak.$BACKUP_TS"
  fi
done

# Asegurar directorio de scripts de polybar
mkdir -p "$POLYBAR_DIR/scripts"

# -------------------------
# POLYBAR: configuración con transparencia
# -------------------------
info "Escribiendo nueva configuración de Polybar (transparente)..."
cat > "$POLYBAR_DIR/config" <<'EOF'
[colors]
bg = #1E1E2E
bg_alpha = #1E1E2EC0    ; Catppuccin Mocha con alpha C0 (~75%)
mantle = #181825
crust = #11111B
text = #CAD3F5
accent = #CBA6F7
muted = #B8C0E0

[bar/main]
width = 100%
height = 30
background = ${colors.bg_alpha}
foreground = ${colors.text}
font-0 = "JetBrainsMono Nerd Font:style=Regular:size=11"
modules-left = bspwm
modules-center =
modules-right = network volume memory cpu date tray

; tray settings
tray-position = right
tray-padding = 4

; bar padding and radius (requires compositor)
offset-x = 0%
offset-y = 0%
override-redirect = false
wm-restack = bspc

[module/bspwm]
type = internal/bspwm
label-focused = %name%
label-unfocused = %name%
label-occupied = %name%
label-empty = %name%
index-sort = true
format = <label>
; Limitar visualmente a 5 desktops depende de bspwm (configurado en bspwmrc)

[module/network]
type = custom/script
exec = ~/.config/polybar/scripts/network.sh
interval = 5
format = <label>

[module/volume]
type = custom/script
exec = ~/.config/polybar/scripts/volume.sh
interval = 2
click-left = pactl set-sink-mute @DEFAULT_SINK@ toggle
click-right = pavucontrol &

[module/memory]
type = internal/memory
format = RAM %used%/%total% MB

[module/cpu]
type = internal/cpu
format = CPU %percentage:2% 

[module/date]
type = internal/date
interval = 10
date = %Y-%m-%d %H:%M
EOF

# Mejorar apariencia de scripts existentes (vol/network)
info "Escribiendo scripts de polybar (volume/network)..."
cat > "$POLYBAR_DIR/scripts/volume.sh" <<'EOF'
#!/usr/bin/env bash
SINK="@DEFAULT_SINK@"
if command -v pactl >/dev/null 2>&1; then
  vol_info=$(pactl get-sink-volume $SINK 2>/dev/null | head -n1)
  [ -z "$vol_info" ] && { echo "VOL: N/A"; exit 0; }
  vol=$(echo "$vol_info" | awk -F/ '{print $2}' | tr -d ' %')
  muted=$(pactl get-sink-mute $SINK 2>/dev/null | awk '{print $2}')
  if [ "$muted" = "yes" ]; then
    echo " muted"
  else
    echo " ${vol}%"
  fi
else
  echo "VOL: n/c"
fi
EOF
chmod +x "$POLYBAR_DIR/scripts/volume.sh"

cat > "$POLYBAR_DIR/scripts/network.sh" <<'EOF'
#!/usr/bin/env bash
if command -v nmcli >/dev/null 2>&1; then
  con=$(nmcli -t -f NAME,DEVICE connection show --active | head -n1 | cut -d: -f1)
  if [ -n "$con" ]; then
    echo " ${con}"
  else
    state=$(nmcli -t -f STATE general | head -n1)
    if [ "$state" = "connected" ]; then
      ip=$(hostname -I | awk '{print $1}')
      echo " ${ip}"
    else
      echo " offline"
    fi
  fi
else
  echo "NET: n/c"
fi
EOF
chmod +x "$POLYBAR_DIR/scripts/network.sh"

# -------------------------
# PICOM: configuracion con transparencias y blur
# -------------------------
info "Escribiendo picom.conf (transparencias y blur)..."
cat > "$PICOM_DIR/picom.conf" <<'EOF'
# picom configuration - transparency, blur, shadows, rounded corners
backend = "glx";
vsync = true;

# Shadows
shadow = true;
shadow-radius = 8;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-opacity = 0.45;

# Opacity (global)
inactive-opacity = 0.88;
active-opacity = 1.0;
frame-opacity = 0.9;
menu-opacity = 0.95;
dnd-shadow = false;

# Blur (experimental)
blur-method = "dual_kawase";
blur-strength = 7;

# Rounded corners for windows (requires support)
corner-radius = 8;

# Opacity rules (ejemplos)
# Hacer polybar semitransparente (valor 0.85)
opacity-rule = [
  "90:class_g = 'Polybar'",
  "95:class_g = 'kitty' and window_type = 'normal'"
];

# Exclude shadows for system trays and docks
shadow-exclude = [
  "class_g = 'Polybar'",
  "class_g = 'trayer'",
  "class_g = 'Nm-applet'",
  "name = 'Notification'"
];

# Fading (optional)
fading = true;
fade-delta = 6;
fade-in-step = 0.03;
fade-out-step = 0.03;

# Backend-specific options
glx-no-stencil = true;
use-damage = true;
EOF

# -------------------------
# BSPWM: reducir a 5 escritorios
# -------------------------
info "Actualizando bspwmrc a 5 escritorios..."
cat > "$BSPWM_DIR/bspwmrc" <<'EOF'
#!/usr/bin/env bash
# bspwmrc personalizado: 5 escritorios, autostart y estética Catppuccin
export PATH="$HOME/.local/bin:$PATH"

# Definir exactamente 5 desktops
bspc monitor -d I II III IV V

# Bordes y gaps
bspc config border_width 2
bspc config window_gap 8
bspc config focused_border_color "#CBA6F7"
bspc config normal_border_color  "#11111B"
bspc config presel_feedback_color "#F9E2AF"
bspc config focus_follows_pointer true

# Reglas de ventanas comunes
bspc rule -a Gimp state=floating
bspc rule -a mpv state=floating
bspc rule -a Pavucontrol state=floating
bspc rule -a feh state=floating

# Mapear aplicaciones de ejemplo
bspc rule -a Brave-browser desktop='^5' follow=on
bspc rule -a firefox desktop='^5' follow=on
bspc rule -a kitty desktop='^1' follow=off

# Autostart de servicios útiles
pgrep -x sxhkd >/dev/null 2>&1 || (sxhkd &)
pgrep -x picom >/dev/null 2>&1 || (picom --experimental-backends --config "$HOME/.config/picom/picom.conf" &)
pgrep -x dunst >/dev/null 2>&1 || (dunst &)
pgrep -x nm-applet >/dev/null 2>&1 || (nm-applet &)

# Lanzar polybar (si existe)
if [ -x "$HOME/.config/polybar/launch.sh" ]; then
  "$HOME/.config/polybar/launch.sh" &
fi

# Restaurar wallpaper
"$HOME/.local/bin/wallpaper_setup" &

# Mouse actions
bspc config pointer_action1 move
bspc config pointer_action2 resize
EOF
chmod +x "$BSPWM_DIR/bspwmrc"

# -------------------------
# SXHKD: actualizar atajos para 5 escritorios
# -------------------------
info "Actualizando ~/.config/sxhkd/sxhkdrc para 5 escritorios..."
cat > "$SXHKD_DIR/sxhkdrc" <<'EOF'
# sxhkdrc - adaptado a 5 escritorios
super = Mod4

# Terminal
super + Return
    kitty

# Launcher
super + d
    rofi -show drun -theme ~/.config/rofi/catppuccin.rasi

# File manager
super + e
    thunar

# Power menu
super + alt + p
    ~/.local/bin/rofi_power_menu

# Focus windows
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Swap windows
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Toggle floating
super + shift + space
    bspc node -t floating && bspc node -t tiled

# Fullscreen
super + f
    bspc node -t fullscreen

# Close
super + shift + q
    bspc node -c

# Restart bspwm
super + shift + r
    bspc wm -r

# Logout
super + shift + e
    bspc quit

# Workspaces (1..5)
super + {1,2,3,4,5}
    bspc desktop -f {1,2,3,4,5}

super + shift + {1,2,3,4,5}
    bspc node -d {1,2,3,4,5}

# Volume keys
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness (brightnessctl/xbacklight)
XF86MonBrightnessUp
    if command -v brightnessctl >/dev/null 2>&1; then brightnessctl set +10%; elif command -v xbacklight >/dev/null 2>&1; then xbacklight -inc 10; fi

XF86MonBrightnessDown
    if command -v brightnessctl >/dev/null 2>&1; then brightnessctl set 10%-; elif command -v xbacklight >/dev/null 2>&1; then xbacklight -dec 10; fi
EOF

chmod +x "$SXHKD_DIR/sxhkdrc"

# -------------------------
# Ajustes finales y mensajes
# -------------------------
info "Ajustes aplicados. Backups guardados en: $BAK_DIR"

cat <<EOF

Acciones recomendadas (ejecuta en tu sesión X/nueva TTY):

1) Recargar sxhkd:
   pkill -USR1 -x sxhkd || true

2) Reiniciar bspwm para aplicar nuevos desktops:
   bspc wm -r

3) Relanzar polybar (en sesión X):
   ~/.config/polybar/launch.sh

4) Reiniciar picom para aplicar nueva configuración:
   killall -q picom || true
   picom --experimental-backends --config "$HOME/.config/picom/picom.conf" &

Notas:
- La transparencia de polybar requiere un compositor (picom) activo y que la versión de polybar soporte colores con alpha.
- En la config usamos un color con alpha (#1E1E2EC0). Si la barra no aparece transparente, prueba ajustar picom (asegúrate que picom esté ejecutándose con la conf y el backend GLX).
- He reducido el número de escritorios a 5: I II III IV V (se mapean como 1..5 en sxhkd).
- Si usas Wayland, estas configuraciones son para Xorg/X11 (polybar, picom, feh no funcionan así en Wayland).
EOF

# Fin del script
