# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Start Sway on the first VT. The README used to advertise a Sway desktop while
# the profile shipped no configuration and no autostart at all, so the live
# session just dropped to a shell.
#
# Deliberately not exec'd: if sway fails to start (no DRM device, missing
# firmware, a bad panel probe) the user must still land in a usable shell -- this
# is an installer image. Boot with 'nosway' to skip it entirely.
if [[ -z "$WAYLAND_DISPLAY" && "$XDG_VTNR" == 1 ]] && ! grep -Fqa 'nosway' /proc/cmdline; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export MOZ_ENABLE_WAYLAND=1
    if ! sway; then
        print -P "%F{yellow}sway did not start; you are at a shell. Run 'sway' to retry.%f"
    fi
fi
