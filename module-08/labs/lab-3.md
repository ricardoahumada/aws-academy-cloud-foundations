# Lab 8.3: Configurar Site-to-Site VPN con BGP

## Objetivo

Establecer conexión VPN Site-to-Site entre un entorno simulado on-premises y AWS usando Virtual Private Gateway y BGP para enrutamiento dinámico.

## Duración Estimada

45 minutos

## Prerrequisitos

- VPC en AWS con CIDR `10.0.0.0/16`
- Simulación de entorno on-premises (otra VPC o dispositivo)
- AWS CLI configurado
- CIDR on-premises simulado: `172.16.0.0/16`
- Conocimientos básicos de BGP y enrutamiento IP

## Recursos Necesarios

| Recurso | Detalles |
|---------|----------|
| AWS VPC | `vpc-aws` (10.0.0.0/16) |
| Subnet | `subnet-aws-public` en AZ us-east-1a |
| Route Table | `rtb-aws-main` |
| Virtual Private Gateway | `vgw-xxxxxxxx` |
| Customer Gateway (simulado) | `cgw-xxxxxxxx` |
| VPN Connection | `vpn-xxxxxxxx` |
| ASN AWS | 64512 (Amazon-side) |
| ASN Customer | 65000 (on-premises-side) |

## Diagrama de Arquitectura

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                        │
│                                                                                │
│   ┌────────────────────────────────────────────────────────────────────────┐  │
│   │  VPC: 10.0.0.0/16                                                      │  │
│   │                                                                         │  │
│   │   Route Table:                                                         │  │
│   │   10.0.0.0/16 ──► local                                               │  │
│   │   172.16.0.0/16 ──► vgw-xxxxxxxx (propagated via BGP)                  │  │
│   │                                                                         │  │
│   │   ┌────────────────────────────────────────────────────────────────┐  │  │
│   │   │                  Virtual Private Gateway                       │  │  │
│   │   │                      (VGW)                                        │  │  │
│   │   │                     ASN: 64512                                  │  │  │
│   │   └────────────────────────────┬───────────────────────────────────┘  │  │
│   │                                │                                        │  │
│   │                    Tunnel 1 ───┴──── Tunnel 2                         │  │
│   │                  (169.254.100.0/30)  (169.254.100.4/30)               │  │
│   └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ Internet (IPSec Encrypted)
                                      │
┌──────────────────────────────────────────────────────────────────────────────┐
│                          On-Premises (Simulated)                              │
│                                                                                │
│   ┌────────────────────────────────────────────────────────────────────────┐  │
│   │  Network: 172.16.0.0/16                                                 │  │
│   │                                                                         │  │
│   │   ┌────────────────────────────────────────────────────────────────┐  │  │
│   │   │               Customer Gateway Router                          │  │  │
│   │   │                    ASN: 65000                                   │  │  │
│   │   └────────────────────────────────────────────────────────────────┘  │  │
│   │                                │                                        │  │
│   │                   Tunnel 1 ───┬──── Tunnel 2                          │  │
│   │                (169.254.100.2/30)  (169.254.100.6/30)                │  │
│   └────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Pasos

### Fase 1: Crear Virtual Private Gateway

**Paso 1.1: Crear Virtual Private Gateway con BGP**

```bash
# Crear Virtual Private Gateway
aws ec2 create-vpn-gateway \
    --type ipsec.1 \
    --amazon-side-asn 64512 \
    --tag-specifications 'ResourceType=vpn-gateway,Tags=[{Key=Name,Value=vgw-aws-vpn},{Key=Environment,Value=lab}]'
```

**Paso 1.2: Adjuntar VGW a VPC**

```bash
# Asociar Virtual Private Gateway a la VPC
aws ec2 attach-vpn-gateway \
    --vpn-gateway-id vgw-xxxxxxxx \
    --vpc-id vpc-xxxxxxxx
```

**Paso 1.3: Verificar adjunto**

```bash
# Verificar que el VGW está adjunto
aws ec2 describe-vpn-gateways \
    --vpn-gateway-ids vgw-xxxxxxxx \
    --query 'VpnGateways[0].VpcAttachments'
```

---

### Fase 2: Habilitar Route Propagation

**Paso 2.1: Obtener Route Table principal**

```bash
# Obtener ID de Route Table
aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=rtb-aws-main" \
    --query 'RouteTables[0].RouteTableId' \
    --output text
```

**Paso 2.2: Habilitar propagación de rutas**

```bash
# Habilitar route propagation (el VGW propagará rutas automáticamente)
aws ec2 enable-vgw-route-propagation \
    --route-table-id rtb-xxxxxxxx \
    --gateway-id vgw-xxxxxxxx
```

**Paso 2.3: Verificar propagación**

```bash
# Verificar que la propagación está habilitada
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx \
    --query 'RouteTables[0].PropagatingVgws'

# Listar rutas aprendidas (aparecerán cuando VPN esté activo)
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx \
    --query 'RouteTables[0].Routes'
```

---

### Fase 3: Crear Customer Gateway

**Paso 3.1: Crear Customer Gateway (simulado)**

Para este lab, usaremos el BGP ASN simulado. En producción, esto apuntaría a un dispositivo físico.

```bash
# Crear Customer Gateway (simulado - usa IP privada o pública)
aws ec2 create-customer-gateway \
    --type ipsec.1 \
    --bgp-asn 65000 \
    --ip-address 203.0.113.1 \
    --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value=cgw-on-prem},{Key=Environment,Value=lab}]'
```

> **Nota:** `203.0.113.1` pertenece al rango RFC 5737 TEST-NET-3 (no enrutable en Internet). AWS acepta esta IP para crear el recurso CGW, pero el túnel VPN nunca alcanzará estado `UP` porque la IP no es accesible. Esto es útil solo para practicar la configuración de recursos. En un entorno real, usa la IP pública del router on-premises.

**Paso 3.2: Verificar Customer Gateway**

```bash
# Verificar que el CGW fue creado
aws ec2 describe-customer-gateways \
    --customer-gateway-ids cgw-xxxxxxxx
```

---

### Fase 4: Crear Site-to-Site VPN Connection

**Paso 4.1: Crear VPN Connection**

```bash
# Crear VPN Connection con BGP
# ADVERTENCIA: Los PreSharedKey en texto plano en CLI quedan en el historial de la shell.
# En producción, usa AWS Secrets Manager o AWS Systems Manager Parameter Store para gestionarlos.
aws ec2 create-vpn-connection \
    --customer-gateway-id cgw-xxxxxxxx \
    --vpn-gateway-id vgw-xxxxxxxx \
    --type ipsec.1 \
    --options '{
        "TunnelOptions": [
            {
                "TunnelInsideCidr": "169.254.100.0/30",
                "PreSharedKey": "labSecretKey123!",
                "Phase1LifetimeSeconds": 28800,
                "Phase2LifetimeSeconds": 3600,
                "DPDTimeoutSeconds": 30,
                "StartupAction": "start"
            },
            {
                "TunnelInsideCidr": "169.254.100.4/30",
                "PreSharedKey": "labSecretKey456!",
                "Phase1LifetimeSeconds": 28800,
                "Phase2LifetimeSeconds": 3600,
                "DPDTimeoutSeconds": 30,
                "StartupAction": "start"
            }
        ]
    }' \
    --tag-specifications 'ResourceType=vpn-connection,Tags=[{Key=Name,Value=vpn-aws-onprem},{Key=Environment,Value=lab}]'
```

**Paso 4.2: Verificar VPN Connection**

```bash
# Verificar estado de la conexión
aws ec2 describe-vpn-connections \
    --vpn-connection-ids vpn-xxxxxxxx \
    --query 'VpnConnections[0].State'
```

---

### Fase 5: Configurar BGP en Customer Gateway (Simulado)

**Paso 5.1: Obtener información de túneles**

```bash
# Obtener detalles de los túneles
aws ec2 describe-vpn-connections \
    --vpn-connection-ids vpn-xxxxxxxx \
    --query 'VpnConnections[0].VgwTelemetry'
```

**Paso 5.2: Instalar FRR y configurar BGP en simulador**

```bash
# Instalar FRR (Free Range Routing) en Amazon Linux 2023 / Ubuntu
# Amazon Linux 2023:
sudo dnf install -y frr
sudo systemctl enable --now frr

# Ubuntu:
# sudo apt-get install -y frr && sudo systemctl enable --now frr

# Habilitar el dæmon BGP en /etc/frr/daemons:
sudo sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo systemctl restart frr
```

```bash
# En el router simulado, configurar BGP
# Este es un ejemplo de configuración BGP (usando FRR/Quagga en Linux)

vtysh << 'EOF'
configure terminal
router bgp 65000
 neighbor 169.254.100.1 remote-as 64512
 neighbor 169.254.100.1 description AWS_VPN_Tunnel_1
 neighbor 169.254.100.5 remote-as 64512
 neighbor 169.254.100.5 description AWS_VPN_Tunnel_2
 network 172.16.0.0/16
 exit
write
EOF
```

**Paso 5.3: Verificar configuración BGP**

```bash
# Verificarvecinos BGP (desde router simulado)
vtysh -c "show ip bgp summary"

# Output esperado:
# Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
# 169.254.100.1   4 64512       0       0        0    0    0 never    Active
# 169.254.100.5   4 64512       0       0        0    0    0 never    Active
```

---

### Fase 6: Verificar Conectividad VPN

**Paso 6.1: Verificar estado de túneles**

```bash
# Ver estado de túneles IPSec
aws ec2 describe-vpn-connections \
    --vpn-connection-ids vpn-xxxxxxxx \
    --query 'VpnConnections[0].VgwTelemetry'

# Output esperado:
# [
#     {
#         "OutsideIpAddress": "203.0.113.1",
#         "Status": "UP",
#         "StatusMessage": "Tunnel is up",
#         "LastStateChange": "2026-03-31...",
#         "AcceptedRouteCount": 1
#     },
#     {
#         "OutsideIpAddress": "203.0.113.1",
#         "Status": "UP",
#         "StatusMessage": "Tunnel is up",
#         "LastStateChange": "2026-03-31...",
#         "AcceptedRouteCount": 1
#     }
# ]
```

**Paso 6.2: Verificar rutas aprendidas via BGP**

```bash
# Verificar que la ruta 172.16.0.0/16 fue aprendida
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx \
    --query 'RouteTables[0].Routes'

# Output esperado - debe incluir:
# {
#     "DestinationCidrBlock": "172.16.0.0/16",
#     "GatewayId": "vgw-xxxxxxxx",
#     "Origin": "EnableVgwRoutePropagation",
#     "State": "active"
# }
```

**Paso 6.3: Probar conectividad**

```bash
# Desde EC2 en AWS VPC, probar conectividad a red on-premises
ping -c 4 172.16.0.1

# Desde router on-premises, probar conectividad a VPC AWS
ping -c 4 10.0.0.1
```

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar cada uno de los siguientes puntos:

| # | Criterio | Comando de Verificación | Resultado Esperado |
|---|----------|-------------------------|---------------------|
| 1 | Virtual Private Gateway creado | `aws ec2 describe-vpn-gateways --vpn-gateway-ids vgw-xxxxxxxx` | Estado `attached` |
| 2 | Customer Gateway creado | `aws ec2 describe-customer-gateways --customer-gateway-ids cgw-xxxxxxxx` | Estado `available` |
| 3 | VPN Connection creada | `aws ec2 describe-vpn-connections --vpn-connection-ids vpn-xxxxxxxx` | Estado `available` |
| 4 | Túneles IPSec activos | `aws ec2 describe-vpn-connections --query 'VpnConnections[0].VgwTelemetry'` | Ambos túneles `UP` |
| 5 | Ruta a 172.16.0.0/16 propagada | `aws ec2 describe-route-tables --route-table-id rtb-xxxxxxxx --query 'Routes'` | Ruta con `Origin: EnableVgwRoutePropagation` |
| 6 | Conectividad BGP | `vtysh -c "show ip bgp"` | Vecinos en estado `Established` |

---

## Configuración Detallada de Túneles

### Parámetros IPSec Fase 1 (IKE)

| Parámetro | Valor |
|-----------|-------|
| Protocol | IKEv1 |
| Authentication | Pre-Shared Key |
| Encryption | AES-256 |
| Hash | SHA-256 |
| DH Group | 14 (2048-bit) |
| Lifetime | 28800 segundos (8 horas) |

### Parámetros IPSec Fase 2 (ESP)

| Parámetro | Valor |
|-----------|-------|
| Protocol | ESP |
| Encryption | AES-256 |
| Authentication | SHA-256 |
| Lifetime | 3600 segundos (1 hora) |
| Mode | Tunnel |

### Detalles de Túneles

| Túnel | Inside CIDR | Peer Inside IP | Pre-Shared Key |
|-------|-------------|----------------|----------------|
| Tunnel 1 | 169.254.100.0/30 | 169.254.100.1 (AWS) / 169.254.100.2 (Cust) | labSecretKey123! |
| Tunnel 2 | 169.254.100.4/30 | 169.254.100.5 (AWS) / 169.254.100.6 (Cust) | labSecretKey456! |

---

## Errores Comunes y Soluciones

### Error 1: "Tunnel is down" o "IPSEC IS DOWN"

**Causa:** Problemas de configuración IPSec o red.

**Solución:**
```bash
# Verificar que los parámetros de túnel coinciden entre AWS y CGW
# Verificar PreSharedKey
aws ec2 describe-vpn-connections \
    --vpn-connection-ids vpn-xxxxxxxx \
    --query 'VpnConnections[0].Options.TunnelOptions'

# Verificar logs del túnel (CloudWatch Logs)
aws logs describe-log-groups --log-group-name-prefix /aws/vpn
```

### Error 2: "BGP Neighbor not established"

**Causa:** Routers no pueden comunicarse o ASNs no coinciden.

**Solución:**
```bash
# Verificar que los ASNs coinciden
# AWS side ASN debe ser 64512
# Customer side ASN debe ser 65000

# Verificar que los Inside CIDRs no se superponen
# Verificar conectividad entre 169.254.0.x

# En router simulado, verificar:
vtysh -c "show ip bgp neighbors"
```

### Error 3: "Route not propagated"

**Causa:** Route propagation no habilitada o BGP no establecióvecino.

**Solución:**
```bash
# Habilitar route propagation
aws ec2 enable-vgw-route-propagation \
    --route-table-id rtb-xxxxxxxx \
    --gateway-id vgw-xxxxxxxx

# Verificar estado de propagación
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx \
    --query 'RouteTables[0].PropagatingVgws'
```

### Error 4: "MTU issues causing packet loss"

**Causa:** MTU diferente entre túneles.

**Solución:**
```bash
# Reducir MTU en el router
# AWS VPN usa MTU de 1426 bytes

# En router simulado:
ip link set dev tun0 mtu 1426

# O usar Path MTU Discovery
```

---

## Limpieza de Recursos

```bash
# Eliminar VPN Connection
aws ec2 delete-vpn-connection \
    --vpn-connection-id vpn-xxxxxxxx

# Desasociar VGW de VPC
aws ec2 detach-vpn-gateway \
    --vpn-gateway-id vgw-xxxxxxxx \
    --vpc-id vpc-xxxxxxxx

# Eliminar Virtual Private Gateway
aws ec2 delete-vpn-gateway \
    --vpn-gateway-id vgw-xxxxxxxx

# Eliminar Customer Gateway
aws ec2 delete-customer-gateway \
    --customer-gateway-id cgw-xxxxxxxx

# Deshabilitar route propagation (si ya no existe el VGW)
# Las rutas propagadas se eliminan automáticamente
```

---

## Referencias

- [AWS Site-to-Site VPN Documentation](https://docs.aws.amazon.com/vpn/latest/s2svpn/)
- [BGP Configuration Examples](https://docs.aws.amazon.com/vpn/latest/s2svpn/SetUpVPNConnections.html)
- [Virtual Private Gateway](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-gateway.html)
- [Customer Gateway](https://docs.aws.amazon.com/vpn/latest/s2svpn/customer-gateway.html)
