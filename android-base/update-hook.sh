#!/bin/sh

echo "Overwriting /etc/login.defs with android-base version..."
cp -f /usr/share/android-base/login.defs /etc/login.defs

echo "Overwriting /etc/default/useradd with android-base version"
cp -f /usr/share/android-base/useradd /etc/default/useradd
