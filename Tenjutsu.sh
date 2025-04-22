#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Variables
GAMEDIR="/$directory/ports/tenjutsu48h"
BOX64="$GAMEDIR/box64/box64"
HASHLINK="$GAMEDIR/hashlink/hl"

# CD and set log
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Exports
export LD_LIBRARY_PATH="$GAMEDIR/box64/x64:$GAMEDIR/hashlink:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Mount Weston runtime
weston_dir=/tmp/weston
$ESUDO mkdir -p "${weston_dir}"
weston_runtime="weston_pkg_0.2"
if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${weston_dir}"
fi
$ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "${weston_dir}"

# rocknix mode on rocknix panfrost; libmali not supported
if [[ "$CFW_NAME" = "ROCKNIX" ]]; then
  export rocknix_mode=1
fi

# Run it
$GPTOKEYB "$HASHLINK" xbox360 & 
pm_platform_helper "$HASHLINK" > /dev/null

$ESUDO env \
BOX64_LD_LIBRARY_PATH="$GAMEDIR/hashlink:$GAMEDIR/hashlink/lib:$LD_LIBRARY_PATH" \
WRAPPED_PRELOAD="$GAMEDIR/libs.${DEVICE_ARCH}/libSDL2-2.0.so.0" WRAPPED_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}/:$LD_LIBRARY_PATH" \
BOX64_LD_LIBRARY_PATH="$GAMEDIR/box64/x64" \
$weston_dir/westonwrap.sh headless noop kiosk crusty_glx_core4es \
"$BOX64" "$HASHLINK" client.hl

# Cleanup
$ESUDO $weston_dir/westonwrap.sh cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${weston_dir}"
fi
pm_finish