#!/bin/sh
# ============================================
# Health Check Script para Nginx
# Lab 7.1 - ECS Fargate
# ============================================

# Verificar que nginx está respondiendo
curl -f -s -o /dev/null http://localhost/health || \
curl -f -s -o /dev/null http://localhost/index.html || \
exit 1

exit 0
