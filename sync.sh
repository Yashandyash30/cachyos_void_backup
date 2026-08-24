#!/bin/bash
cd /home/void/cachyos_void_backup
git add .
git commit -m "Auto-update configs: $(date)"
git push origin master
