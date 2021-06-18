#!/bin/sh

rm -rf /etc/systemd/system/display-manager.service >/dev/null || true
systemctl enable ly.service
