#!/bin/sh

echo "Overwriting /etc/pulse/default.pa with pulseaudio-config-droid version..."
cp -f /usr/lib/pulseaudio-config-droid/default.pa.droid /etc/pulse/default.pa
