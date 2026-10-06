# FortiGate 7.0.3 — Segmentación con DMZ, VLANs y Políticas de Seguridad

### Arlene Fernández Herrera · Matrícula: 2025-0730

**Seguridad de Redes · ITLA**

---

## 🎥 Video Demostrativo

**[▶ Ver video de demostración](https://youtu.be/REEMPLAZAR-CON-TU-ID)**

---

> 📚 **Nota:** los "sistemas" de los servidores web (Caja e Inventario) son páginas de demostración que muestran la materia, la institución y el nombre de la estudiante. No son aplicaciones de producción: su objetivo es identificar cada servidor al probar las políticas de seguridad.

---

## 📋 Tabla de Contenido

1. [Objetivo del Laboratorio](#1-objetivo-del-laboratorio)
2. [Topología y Direccionamiento](#2-topología-y-direccionamiento)
3. [Procedimiento paso a paso](#3-procedimiento-paso-a-paso)
   - [Paso 1. Nube PNET (ISP) y PC local](#paso-1-nube-pnet-isp-y-pc-local)
   - [Paso 2. Switch SW-LAN: VLANs y seguridad básica](#paso-2-switch-sw-lan-vlans-y-seguridad-básica)
   - [Paso 3. Acceso inicial del FortiGate (CLI)](#paso-3-acceso-inicial-del-fortigate-cli)
   - [Paso 4. Interfaces, sub-interfaces VLAN y DHCP del FortiGate](#paso-4-interfaces-sub-interfaces-vlan-y-dhcp-del-fortigate)
   - [Paso 5. DNS y ruta por defecto](#paso-5-dns-y-ruta-por-defecto)
   - [Paso 6. Conectividad de Usuarios y Servidores](#paso-6-conectividad-de-usuarios-y-servidores)
   - [Paso 7. Endpoints de actualización de los servidores](#paso-7-endpoints-de-actualización-de-los-servidores)
   - [Paso 8. Objetos de dirección](#paso-8-objetos-de-dirección)
   - [Paso 9. Perfil Web Filter para el Sistema de Inventario](#paso-9-perfil-web-filter-para-el-sistema-de-inventario)
   - [Paso 10. Políticas de firewall](#paso-10-políticas-de-firewall)
   - [Paso 11. Servicios en los servidores](#paso-11-servicios-en-los-servidores)
   - [Paso 12. Pruebas de verificación](#paso-12-pruebas-de-verificación)
4. [Capturas de Pantalla](#4-capturas-de-pantalla)
5. [Estructura del Repositorio](#5-estructura-del-repositorio)

---

## 1. Objetivo del Laboratorio

Esta práctica segmenta una red con un **FortiGate (v7.0.3)** y un **switch**, y aplica políticas de seguridad entre las zonas:

* Los **servidores** (Web Sistema de Caja, Web Sistema de Inventario y DB Server, red `/28`) están en una **DMZ**.
* Las **políticas evitan fuga de tráfico desde la DMZ hacia la red LAN** (VLAN 10 y VLAN 20).
* La **DMZ no tiene acceso abierto a Internet**: solo puede comunicarse con los **endpoints de actualización** de los servicios que usa (repositorios de Ubuntu) y con ningún otro destino.
* La **VLAN 20 es la única con acceso SSH hacia los servidores**.
* La **VLAN 10 tiene restringido el acceso al Web Server Sistema de Inventario**: al intentar abrir la página, el usuario ve la página de bloqueo del FortiGate que indica que violó una política.
* El **switch** implementa las VLANs y **seguridad básica de redes**.

---

## 2. Topología y Direccionamiento

> Las redes internas son **privadas** y salen todas de `10.7.30.0/24` (matrícula 0730), repartidas con **VLSM**. La red del ISP es **pública**: `202.50.73.0/24` (NAT de VMware, VMnet8).

### 2.1 Diagrama de Topología

```
                      ┌───────────────────────────┐
   PC local ──────────┤   Nube PNET (ISP / Cloud) │
   202.50.73.1        │       202.50.73.0/24      │
                      │    GW NAT: 202.50.73.2    │
                      └─────────────┬─────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │           FortiGate           │
                    │ port1 (WAN)  202.50.73.254/24 │
                    │ port2 (trunk, sub-interfaces) │
                    │  ├ VLAN10  10.7.30.62/26      │
                    │  ├ VLAN20  10.7.30.126/26     │
                    │  └ VLAN30  10.7.30.142/28 DMZ │
                    └───────────────┬───────────────┘
                                    │ trunk 802.1Q · VLAN 10, 20, 30
                    ┌───────────────┴───────────────┐
                    │            SW-LAN             │
                    └─┬─────┬─────┬─────┬─────┬─────┘
                      │     │     │     │     │
                    e0/1  e0/2  e0/3  e1/0  e1/1
                      │     │     │     │     │
                    U-V10 U-V20 Caja  Inv.  DB
                                └ DMZ VLAN 30 ┘

  U-V10 / U-V20 = Usuarios · Caja / Inv. = Web Servers · DB = DB Server

  Política de comunicación:
  ┌───────────────────────────────────────────────────────────────────┐
  │ VLAN 20 → servidores : SSH y Web permitidos                       │
  │ VLAN 10 → Web Caja   : permitido · Web Inventario: BLOQUEADO      │
  │ VLAN 10 → servidores : SSH denegado                               │
  │ DMZ → LAN (V10/V20)  : denegado                                   │
  │ DMZ → Internet       : solo endpoints de actualización            │
  └───────────────────────────────────────────────────────────────────┘
```

### 2.2 Redes y VLANs

| Red | VLAN | Dirección | Gateway (FortiGate) | Uso |
|---|---|---|---|---|
| **ISP (pública)** | — | 202.50.73.0/24 | 202.50.73.2 (NAT de VMware) | WAN del FortiGate (`.1` es el adaptador VMnet8 de la PC) |
| **Usuarios V10** | 10 | 10.7.30.0/26 | 10.7.30.62 | Usuario con acceso restringido |
| **Usuarios V20** | 20 | 10.7.30.64/26 | 10.7.30.126 | Usuario con acceso SSH a servidores |
| **DMZ (Servidores)** | 30 | 10.7.30.128/28 | 10.7.30.142 | Web Caja, Web Inventario, DB |

**VLSM sobre `10.7.30.0/24`:** el bloque de Usuarios es un `/25` (`10.7.30.0/25`) que se divide en dos `/26`, una por VLAN. El bloque de Servidores es un `/28`.

| Bloque | Requisito | Red | Hosts utilizables | Gateway (FortiGate) | Broadcast |
|---|---|---|---|---|---|
| Usuarios VLAN 10 | `/26` (dentro del `/25`) | 10.7.30.0/26 | .1 – .62 | 10.7.30.62 | .63 |
| Usuarios VLAN 20 | `/26` (dentro del `/25`) | 10.7.30.64/26 | .65 – .126 | 10.7.30.126 | .127 |
| Servidores (DMZ) | `/28` | 10.7.30.128/28 | .129 – .142 | 10.7.30.142 | .143 |
| Libre | — | 10.7.30.144 – .255 | — | — | — |

> **No se asigna la primera IP de ninguna red:** el gateway de cada VLAN usa la **última IP utilizable**, y los dispositivos usan las demás. En la red pública, `.1` es el adaptador VMnet8 de la PC, `.2` el gateway NAT de VMware y el FortiGate usa `.254`.

### 2.3 Tabla de Interfaces

**FortiGate:**

| Interfaz | Alias | Rol | Dirección IP | Máscara |
|---|---|---|---|---|
| **port1** | WAN-NUBE | WAN | 202.50.73.254 | /24 |
| **port2** | TRUNK-SW | (físico, sin IP) | — | — |
| **VLAN10** (port2, ID 10) | LAN-VLAN10 | LAN | 10.7.30.62 | /26 |
| **VLAN20** (port2, ID 20) | LAN-VLAN20 | LAN | 10.7.30.126 | /26 |
| **VLAN30** (port2, ID 30) | DMZ | DMZ | 10.7.30.142 | /28 |

**SW-LAN (switch L2):**

| Interfaz | Modo | VLAN | Conectado a |
|---|---|---|---|
| **e0/0** | Trunk (802.1Q) | 10, 20, 30 (nativa 999) | FortiGate `port2` |
| **e0/1** | Access | 10 | Usuario V10 |
| **e0/2** | Access | 20 | Usuario V20 |
| **e0/3** | Access | 30 | Web Server Sistema de Caja |
| **e1/0** | Access | 30 | Web Server Sistema de Inventario |
| **e1/1** | Access | 30 | DB Server |
| **e1/2 – e1/3** | Apagados | 999 | Sin uso |

### 2.4 Tabla de Dispositivos

| Dispositivo | IP | Máscara | Gateway | Método | Rol |
|---|---|---|---|---|---|
| **PC local** (adaptador VMnet8) | 202.50.73.1 | /24 | — | Automática (VMware) | Acceso a la GUI del FortiGate |
| **ISP / NAT de VMware** | 202.50.73.2 | /24 | — | VMware | Gateway con salida a Internet |
| **FortiGate** (port1) | 202.50.73.254 | /24 | 202.50.73.2 | Estática | Firewall perimetral |
| **Usuario V10** | 10.7.30.10 – .60 (rango) | /26 | 10.7.30.62 | **DHCP** | Cliente VLAN 10 |
| **Usuario V20** | 10.7.30.74 – .124 (rango) | /26 | 10.7.30.126 | **DHCP** | Cliente VLAN 20 |
| **Web Sistema de Caja** | 10.7.30.130 | /28 | 10.7.30.142 | Estática | Servidor web |
| **Web Sistema de Inventario** | 10.7.30.131 | /28 | 10.7.30.142 | Estática | Servidor web |
| **DB Server** | 10.7.30.132 | /28 | 10.7.30.142 | Estática | Base de datos |

### 2.5 Matriz de políticas

| Origen | Destino | Servicio | Acción |
|---|---|---|---|
| VLAN 20 | DMZ (servidores) | SSH | ✅ Permitido |
| VLAN 20 | Web Caja y Web Inventario | HTTP | ✅ Permitido |
| VLAN 10 | Web Caja | HTTP | ✅ Permitido |
| VLAN 10 | Web Inventario | HTTP | ⛔ Bloqueado por Web Filter (página de política violada) |
| VLAN 10 | DMZ (resto, incluido SSH) | Todos | ⛔ Denegado |
| DMZ | VLAN 10 y VLAN 20 | Todos | ⛔ Denegado (sin fuga hacia la LAN) |
| DMZ | Endpoints de actualización | HTTP, HTTPS | ✅ Permitido (con NAT) |
| DMZ | Resto de Internet | Todos | ⛔ Denegado |
| VLAN 10 y VLAN 20 | Internet | Todos | ✅ Permitido (con NAT) |

---

## 3. Procedimiento paso a paso

Los pasos están en el orden en que se ejecutan. Cada uno depende de los anteriores.

> Los nombres de interfaz del switch (`Ethernet0/0`, `Ethernet1/0`, …) deben ajustarse a los que muestre `show ip interface brief` en la imagen usada en PNETLab.

---

### Paso 1. Nube PNET (ISP) y PC local

La red pública del ISP es la red NAT de VMware (**VMnet8**) configurada como `202.50.73.0/24`. VMware usa dos direcciones de esa red: `202.50.73.1` (adaptador VMnet8 de la PC local, desde donde se accede a la GUI del FortiGate) y `202.50.73.2` (gateway NAT, que da salida a Internet). El FortiGate usa `202.50.73.254`. Un nodo **Cloud** de PNETLab conecta `port1` del FortiGate a esa red.

**1.1 — Red NAT de VMware**

**Ruta:** `VMware → Edit → Virtual Network Editor → Change Settings → VMnet8 (NAT)`

| Campo | Valor |
|---|---|
| Subnet IP | `202.50.73.0` |
| Subnet mask | `255.255.255.0` |
| NAT Settings → Gateway IP | `202.50.73.2` |
| DHCP Settings → Start IP address | `202.50.73.128` |
| DHCP Settings → End IP address | `202.50.73.200` |

> El adaptador VMnet8 de la PC toma `202.50.73.1` automáticamente y no se configura a mano. El rango DHCP termina en `.200` para que la IP estática del FortiGate (`202.50.73.254`) quede fuera del rango.
> La VM de PNETLab debe usar la red `VMnet8 (NAT)`. Si su interfaz de administración también está en VMnet8, recibe una IP nueva al cambiar la subred: reiniciar la VM y abrir PNETLab con la IP nueva.

**1.2 — En PNETLab**

1. Clic derecho en el área de trabajo → `Add an object → Network`.
2. Type: `Management(Cloud0)`, nombre `Nube-PNET`.
3. Conectar `port1` del FortiGate a `Nube-PNET`.
4. Conectar `port2` del FortiGate a `e0/0` de `SW-LAN`.
5. Conectar al switch: `e0/1` → Usuario V10, `e0/2` → Usuario V20, `e0/3` → Web Caja, `e1/0` → Web Inventario, `e1/1` → DB Server.

---

### Paso 2. Switch SW-LAN: VLANs y seguridad básica

El switch crea las VLANs, lleva el trunk hacia el FortiGate y aplica seguridad básica de redes. Se pega un bloque `configure terminal … end` a la vez (script completo: [`scripts/sw-lan.txt`](scripts/sw-lan.txt)).

**2.1 — Configuración global, VLANs y spanning-tree**

```bash
enable
configure terminal

hostname SW-LAN
no ip domain-lookup
service password-encryption
enable secret Lab12345
banner motd # Acceso restringido. Solo personal autorizado. #

vlan 10
 name USUARIOS-V10
vlan 20
 name USUARIOS-V20
vlan 30
 name DMZ
vlan 999
 name BLACKHOLE
exit

spanning-tree mode rapid-pvst
spanning-tree portfast default
spanning-tree portfast bpduguard default

line con 0
 logging synchronous
 exec-timeout 10 0
exit

end
```

**2.2 — Trunk hacia el FortiGate y puertos de acceso con port-security**

```bash
configure terminal

interface Ethernet0/0
 description Trunk hacia FortiGate port2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport nonegotiate
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,20,30
 no shutdown
exit

interface range Ethernet0/1 - 3 , Ethernet1/0 - 1
 switchport mode access
 switchport nonegotiate
 switchport port-security
 switchport port-security maximum 3
 switchport port-security violation shutdown
 switchport port-security mac-address sticky
 spanning-tree bpduguard enable
 no shutdown
exit

interface Ethernet0/1
 description Usuario V10
 switchport access vlan 10
exit

interface Ethernet0/2
 description Usuario V20
 switchport access vlan 20
exit

interface Ethernet0/3
 description Web Server - Sistema de Caja
 switchport access vlan 30
exit

interface Ethernet1/0
 description Web Server - Sistema de Inventario
 switchport access vlan 30
exit

interface Ethernet1/1
 description DB Server
 switchport access vlan 30
exit

end
```

**2.3 — Puertos sin uso**

```bash
configure terminal

interface range Ethernet1/2 - 3
 description Puerto sin uso
 switchport mode access
 switchport access vlan 999
 shutdown
exit

end
write memory
```

> **Seguridad básica aplicada:** contraseña `enable secret` y cifrado de contraseñas, banner, `port-security` (3 MAC por puerto por la conexión entre PNETLab y VMware, violación → shutdown, MAC sticky), `BPDU guard` y `portfast` en los puertos de acceso, DTP deshabilitado (`nonegotiate`), VLAN nativa del trunk distinta de la VLAN 1 (999), VLANs permitidas en el trunk limitadas a 10, 20 y 30, y puertos sin uso apagados en una VLAN sin salida.

**Verificación:**
```bash
show vlan brief
show interfaces trunk
show port-security
show spanning-tree summary
```

> Ver evidencia: [01_switch_vlan_seguridad.png](screenshots/01_switch_vlan_seguridad.png)

---

### Paso 3. Acceso inicial del FortiGate (CLI)

Desde la consola del FortiGate (script: [`scripts/fortigate-cli.txt`](scripts/fortigate-cli.txt)):

```bash
config system interface
    edit "port1"
        set mode static
        set ip 202.50.73.254 255.255.255.0
        set allowaccess https ssh ping
        set role wan
    next
end
```

Acceder desde el navegador de la PC local a `https://202.50.73.254` con las credenciales por defecto (`admin` / contraseña vacía) y definir una contraseña segura.

> Ver evidencia: [02_cli_acceso_fortigate.png](screenshots/02_cli_acceso_fortigate.png)

---

### Paso 4. Interfaces, sub-interfaces VLAN y DHCP del FortiGate

Todo por GUI en `https://202.50.73.254`. **Ruta:** `Network → Interfaces`

#### 4.1 Interfaces físicas

**port1 — WAN-NUBE** (ya tiene IP desde el Paso 3; se completa el resto):

| Campo | Valor |
|---|---|
| Alias | `WAN-NUBE` |
| Role | `WAN` |
| IP/Netmask | `202.50.73.254 / 255.255.255.0` |
| Administrative access | `HTTPS, SSH, Ping` |

**port2 — TRUNK-SW (físico, sin IP):**

| Campo | Valor |
|---|---|
| Alias | `TRUNK-SW` |
| Role | `Undefined` |
| Addressing mode | `Manual` (`0.0.0.0/0.0.0.0`) |

> `port2` solo transporta tramas etiquetadas; la IP de cada red va en su sub-interfaz VLAN.

#### 4.2 Sub-interfaz VLAN 10 (Usuarios) y su DHCP

**Ruta:** `Network → Interfaces → Create New → Interface`

| Campo | Valor |
|---|---|
| Name | `VLAN10` |
| Alias | `LAN-VLAN10` |
| Type | `VLAN` |
| Interface | `port2` |
| VLAN ID | `10` |
| Role | `LAN` |
| IP/Netmask | `10.7.30.62 / 255.255.255.192` |
| Administrative access | `Ping` |

En la misma pantalla, **DHCP Server → Enable**:

| Campo | Valor |
|---|---|
| Address Range | `10.7.30.10 – 10.7.30.60` |
| Netmask | `255.255.255.192` |
| Default Gateway | `Same as Interface IP` |
| DNS Server | `Specify`: `8.8.8.8` / `8.8.4.4` |
| Lease Time | `1 day` |

#### 4.3 Sub-interfaz VLAN 20 (Usuarios) y su DHCP

| Campo | Valor |
|---|---|
| Name | `VLAN20` |
| Alias | `LAN-VLAN20` |
| Type | `VLAN` |
| Interface | `port2` |
| VLAN ID | `20` |
| Role | `LAN` |
| IP/Netmask | `10.7.30.126 / 255.255.255.192` |
| Administrative access | `Ping` |

**DHCP Server → Enable:**

| Campo | Valor |
|---|---|
| Address Range | `10.7.30.74 – 10.7.30.124` |
| Netmask | `255.255.255.192` |
| Default Gateway | `Same as Interface IP` |
| DNS Server | `Specify`: `8.8.8.8` / `8.8.4.4` |
| Lease Time | `1 day` |

#### 4.4 Sub-interfaz VLAN 30 (DMZ) y servicio DNS

| Campo | Valor |
|---|---|
| Name | `VLAN30` |
| Alias | `DMZ` |
| Type | `VLAN` |
| Interface | `port2` |
| VLAN ID | `30` |
| Role | `DMZ` |
| IP/Netmask | `10.7.30.142 / 255.255.255.240` |
| Administrative access | `Ping` |

La DMZ no tiene DHCP (los servidores usan IP estática). Los servidores resuelven nombres a través del FortiGate, así que se habilita el servicio DNS en esta interfaz.

En FortiOS 7.0 el menú `Network → DNS Servers` está oculto por defecto. Se muestra activando la función **DNS Database**:

**Ruta:** `System → Feature Visibility → Additional Features → DNS Database → Enable → Apply`

Después, crear el servicio DNS en la interfaz:

**Ruta:** `Network → DNS Servers → DNS Service on Interface → Create New`

| Campo | Valor |
|---|---|
| Interface | `VLAN30` |
| Mode | `Recursive` |
| DNS Filter | Desactivado |
| DNS over HTTPS | Desactivado |

> Ver evidencia: [03_interfaces_fortigate.png](screenshots/03_interfaces_fortigate.png), [04_vlan10_dhcp_fortigate.png](screenshots/04_vlan10_dhcp_fortigate.png), [05_vlan20_dhcp_fortigate.png](screenshots/05_vlan20_dhcp_fortigate.png), [06_vlan30_dmz_fortigate.png](screenshots/06_vlan30_dmz_fortigate.png)

---

### Paso 5. DNS y ruta por defecto

**5.1 — DNS del FortiGate**

**Ruta:** `Network → DNS`

| Campo | Valor |
|---|---|
| DNS servers | `Specify` |
| Primary DNS server | `8.8.8.8` |
| Secondary DNS server | `8.8.4.4` |

El FortiGate usa estos servidores para resolver los nombres de los endpoints de actualización (Paso 8).

**5.2 — Ruta por defecto hacia el ISP**

**Ruta:** `Network → Static Routes → Create New`

| Campo | Valor |
|---|---|
| Destination | `0.0.0.0/0.0.0.0` |
| Gateway Address | `202.50.73.2` |
| Interface | `port1 (WAN-NUBE)` |

> Ver evidencia: [07_dns_ruta_fortigate.png](screenshots/07_dns_ruta_fortigate.png)

---

### Paso 6. Conectividad de Usuarios y Servidores

Comprobar la red base **antes** de crear las políticas.

**6.1 — PC local y salida a Internet**

Desde la PC local (CMD o PowerShell):

```
ping 202.50.73.254
```

Desde la consola del FortiGate:

```bash
execute ping 202.50.73.2
execute ping 8.8.8.8
```

Los tres deben responder: `202.50.73.2` es el gateway NAT de VMware y `8.8.8.8` confirma la salida a Internet.

**6.2 — Usuarios (Ubuntu, por DHCP)**

Conectar cada Usuario a su puerto (V10 en `e0/1`, V20 en `e0/2`) y verificar:

```bash
ip addr
ping -c 3 10.7.30.62      # Usuario V10 (gateway VLAN 10)
ping -c 3 10.7.30.126    # Usuario V20 (gateway VLAN 20)
```

El Usuario V10 debe recibir una IP de `10.7.30.10 – .60` y el Usuario V20 una de `10.7.30.74 – .124`.

**6.3 — Servidores (IP estática)**

En cada servidor Ubuntu, identificar la interfaz con `ip -br link` y editar `/etc/netplan/50-cloud-init.yaml` (ajustar `ens3` al nombre real y la IP según el servidor):

```yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses: [10.7.30.130/28]
      routes:
        - to: default
          via: 10.7.30.142
      nameservers:
        addresses: [10.7.30.142]
```

| Servidor | Dirección en `addresses` |
|---|---|
| Web Sistema de Caja | `10.7.30.130/28` |
| Web Sistema de Inventario | `10.7.30.131/28` |
| DB Server | `10.7.30.132/28` |

```bash
sudo netplan apply
ping -c 3 10.7.30.142
```

> Ver evidencia: [08_ping_nube.png](screenshots/08_ping_nube.png), [09_usuarios_dhcp.png](screenshots/09_usuarios_dhcp.png), [10_servidores_red.png](screenshots/10_servidores_red.png)

---

### Paso 7. Endpoints de actualización de los servidores

La DMZ solo podrá salir a Internet hacia los repositorios que sus servicios usan para actualizarse. Se identifican en un servidor:

```bash
grep -rhE '^(URIs|deb )' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
```

Anotar los nombres de host que aparecen (por ejemplo `archive.ubuntu.com` y `security.ubuntu.com`, o el espejo regional `xx.archive.ubuntu.com`). Esos nombres son los endpoints que se permiten en el Paso 8.

> Ver evidencia: [11_endpoints_apt.png](screenshots/11_endpoints_apt.png)

---

### Paso 8. Objetos de dirección

**Ruta:** `Policy & Objects → Addresses → Create New → Address`

| Nombre | Tipo | Valor |
|---|---|---|
| `Red-VLAN10` | Subnet | `10.7.30.0/26` |
| `Red-VLAN20` | Subnet | `10.7.30.64/26` |
| `Red-DMZ` | Subnet | `10.7.30.128/28` |
| `Srv-Caja` | Subnet | `10.7.30.130/32` |
| `Srv-Inventario` | Subnet | `10.7.30.131/32` |
| `Srv-DB` | Subnet | `10.7.30.132/32` |
| `FQDN-Ubuntu-Archive` | FQDN | `archive.ubuntu.com` |
| `FQDN-Ubuntu-Security` | FQDN | `security.ubuntu.com` |

Si en el Paso 7 apareció otro nombre de host (por ejemplo un espejo regional), crear también su objeto FQDN.

**Grupos de direcciones** — `Policy & Objects → Addresses → Create New → Address Group`:

| Nombre | Miembros |
|---|---|
| `Servidores-Web` | `Srv-Caja`, `Srv-Inventario` |
| `Endpoints-Actualizacion` | `FQDN-Ubuntu-Archive`, `FQDN-Ubuntu-Security` (y los de otros endpoints del Paso 7) |

> Ver evidencia: [12_objetos_direcciones.png](screenshots/12_objetos_direcciones.png)

---

### Paso 9. Perfil Web Filter para el Sistema de Inventario

Este perfil bloquea el Web Server Sistema de Inventario para la VLAN 10. Los servidores web usan **HTTP (puerto 80)**, de modo que el FortiGate puede inspeccionar la petición y mostrar su página de bloqueo sin inspección SSL.

**Ruta:** `Security Profiles → Web Filter → Create New`

| Campo | Valor |
|---|---|
| Name | `Bloqueo-Inventario` |
| Static URL Filter | ✅ Enabled |

En **URL Filter → Create New**:

| Campo | Valor |
|---|---|
| URL | `10.7.30.131` |
| Type | `Simple` |
| Action | `Block` |
| Status | `Enable` |

Pulsar **OK**. Al bloquear una petición, el FortiGate muestra su página de bloqueo estándar, que indica que se intentó acceder a una página que viola la política de uso de Internet.

> Ver evidencia: [13_webfilter_perfil.png](screenshots/13_webfilter_perfil.png)

---

### Paso 10. Políticas de firewall

**Ruta:** `Policy & Objects → Firewall Policy → Create New`

El orden en la lista importa: el FortiGate evalúa las políticas de arriba hacia abajo. Crearlas en este orden y verificar que queden así.

| # | Name | Incoming | Outgoing | Source | Destination | Service | Action | NAT |
|---|---|---|---|---|---|---|---|---|
| 1 | `VLAN20-SSH-DMZ` | `VLAN20` | `VLAN30` | `Red-VLAN20` | `Red-DMZ` | `SSH` | ACCEPT | ❌ |
| 2 | `VLAN20-Web-DMZ` | `VLAN20` | `VLAN30` | `Red-VLAN20` | `Servidores-Web` | `HTTP` | ACCEPT | ❌ |
| 3 | `VLAN10-Web-DMZ` | `VLAN10` | `VLAN30` | `Red-VLAN10` | `Servidores-Web` | `HTTP` | ACCEPT | ❌ |
| 4 | `Bloqueo-VLAN10-DMZ` | `VLAN10` | `VLAN30` | `Red-VLAN10` | `Red-DMZ` | `ALL` | DENY | — |
| 5 | `Bloqueo-DMZ-a-LAN` | `VLAN30` | `VLAN10`, `VLAN20` | `Red-DMZ` | `Red-VLAN10`, `Red-VLAN20` | `ALL` | DENY | — |
| 6 | `DMZ-Actualizaciones` | `VLAN30` | `port1` | `Red-DMZ` | `Endpoints-Actualizacion` | `HTTP`, `HTTPS` | ACCEPT | ✅ Outgoing Interface Address |
| 7 | `Bloqueo-DMZ-Internet` | `VLAN30` | `port1` | `Red-DMZ` | `all` | `ALL` | DENY | — |
| 8 | `Usuarios-to-WAN` | `VLAN10`, `VLAN20` | `port1` | `all` | `all` | `ALL` | ACCEPT | ✅ Outgoing Interface Address |

**Ajustes adicionales:**

* **Política 3 (`VLAN10-Web-DMZ`):** en *Security Profiles* activar **Web Filter** y seleccionar `Bloqueo-Inventario`. *SSL Inspection*: `no-inspection`. Con esto la VLAN 10 puede abrir el Web Caja, pero al intentar abrir el Inventario ve la página de bloqueo.
* **Políticas 4, 5 y 7 (DENY):** en *Logging Options* activar **Log Violation Traffic**, para que cada intento bloqueado quede registrado.
* **Política 1 (`VLAN20-SSH-DMZ`):** en *Logging Options* activar **All Sessions**, como evidencia de que solo la VLAN 20 llega por SSH.
* Entre la VLAN 10 y la VLAN 20 no hay política: el tráfico queda denegado por la regla implícita.

> Ver evidencia: [14_politicas_fortigate.png](screenshots/14_politicas_fortigate.png)

---

### Paso 11. Servicios en los servidores

Con la política `DMZ-Actualizaciones` activa, los servidores pueden instalar paquetes desde los repositorios permitidos.

Los dos servidores web publican una página que identifica la **materia**, la **institución** y la **estudiante**. Son páginas de demostración con **fines académicos**: no son sistemas reales de caja ni de inventario, y solo sirven para identificar cada servidor durante las pruebas. Usan HTML y CSS en línea, sin recursos externos, porque la DMZ no tiene acceso libre a Internet.

**11.1 — Web Sistema de Caja** (script: [`scripts/servidor-caja.sh`](scripts/servidor-caja.sh))

```bash
sudo apt update && sudo apt install -y apache2 openssh-server
sudo tee /var/www/html/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sistema de Caja</title>
<style>
  body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f3f4f6;color:#1f2937}
  header{background:#166534;color:#fff;padding:24px 40px}
  header h1{margin:0;font-size:28px}
  header p{margin:6px 0 0;opacity:.85}
  main{max-width:720px;margin:32px auto;padding:0 20px}
  .card{background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.15);padding:24px}
  table{width:100%;border-collapse:collapse}
  td{padding:10px 8px;border-bottom:1px solid #e5e7eb}
  td:first-child{font-weight:bold;width:35%;color:#166534}
  footer{max-width:720px;margin:16px auto;padding:0 20px;font-size:13px;color:#6b7280}
</style>
</head>
<body>
<header><h1>Sistema de Caja</h1><p>Servidor web de la DMZ · Laboratorio de segmentación y seguridad perimetral</p></header>
<main><div class="card"><table>
<tr><td>Materia</td><td>Seguridad de Redes</td></tr>
<tr><td>Institución</td><td>ITLA — Instituto Tecnológico de Las Américas</td></tr>
<tr><td>Estudiante</td><td>Arlene Fernández Herrera</td></tr>
<tr><td>Matrícula</td><td>2025-0730</td></tr>
<tr><td>Servidor</td><td>Web Sistema de Caja · 10.7.30.130 · DMZ (VLAN 30)</td></tr>
</table></div></main>
<footer>Página de demostración con fines académicos. No es un sistema de producción.</footer>
</body>
</html>
EOF
sudo systemctl enable --now apache2 ssh
```

**11.2 — Web Sistema de Inventario** (script: [`scripts/servidor-inventario.sh`](scripts/servidor-inventario.sh))

```bash
sudo apt update && sudo apt install -y apache2 openssh-server
sudo tee /var/www/html/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sistema de Inventario</title>
<style>
  body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f3f4f6;color:#1f2937}
  header{background:#1d4ed8;color:#fff;padding:24px 40px}
  header h1{margin:0;font-size:28px}
  header p{margin:6px 0 0;opacity:.85}
  main{max-width:720px;margin:32px auto;padding:0 20px}
  .card{background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.15);padding:24px}
  table{width:100%;border-collapse:collapse}
  td{padding:10px 8px;border-bottom:1px solid #e5e7eb}
  td:first-child{font-weight:bold;width:35%;color:#1d4ed8}
  footer{max-width:720px;margin:16px auto;padding:0 20px;font-size:13px;color:#6b7280}
</style>
</head>
<body>
<header><h1>Sistema de Inventario</h1><p>Servidor web de la DMZ · Laboratorio de segmentación y seguridad perimetral</p></header>
<main><div class="card"><table>
<tr><td>Materia</td><td>Seguridad de Redes</td></tr>
<tr><td>Institución</td><td>ITLA — Instituto Tecnológico de Las Américas</td></tr>
<tr><td>Estudiante</td><td>Arlene Fernández Herrera</td></tr>
<tr><td>Matrícula</td><td>2025-0730</td></tr>
<tr><td>Servidor</td><td>Web Sistema de Inventario · 10.7.30.131 · DMZ (VLAN 30)</td></tr>
</table></div></main>
<footer>Página de demostración con fines académicos. No es un sistema de producción.</footer>
</body>
</html>
EOF
sudo systemctl enable --now apache2 ssh
```

**11.3 — DB Server** (script: [`scripts/servidor-db.sh`](scripts/servidor-db.sh))

```bash
sudo apt update && sudo apt install -y mariadb-server openssh-server
sudo sed -i 's/^bind-address.*/bind-address = 10.7.30.132/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
sudo systemctl enable --now ssh
sudo mysql <<'EOF'
CREATE DATABASE caja_db;
CREATE DATABASE inventario_db;
CREATE USER 'caja'@'10.7.30.130' IDENTIFIED BY 'Lab12345';
CREATE USER 'inventario'@'10.7.30.131' IDENTIFIED BY 'Lab12345';
GRANT ALL ON caja_db.* TO 'caja'@'10.7.30.130';
GRANT ALL ON inventario_db.* TO 'inventario'@'10.7.30.131';
FLUSH PRIVILEGES;
EOF
```

**Verificación en los servidores:**
```bash
systemctl status apache2 ssh      # servidores web
systemctl status mariadb ssh      # DB Server
ss -tlnp | grep -E ':(22|80|3306)'
```

> Ver evidencia: [15_servidor_caja.png](screenshots/15_servidor_caja.png), [16_servidor_inventario.png](screenshots/16_servidor_inventario.png), [17_servidor_db.png](screenshots/17_servidor_db.png)

---

### Paso 12. Pruebas de verificación

**12.1 — Usuario VLAN 10 (acceso restringido)**

```bash
curl -s http://10.7.30.130/ | grep -o '<title>.*</title>'   # Web Caja: <title>Sistema de Caja</title>
```
En el navegador, abrir `http://10.7.30.130/` (Web Caja): se ve la página del Sistema de Caja con la materia y el nombre de la estudiante. Luego abrir `http://10.7.30.131/` (Web Inventario): se muestra la **página de bloqueo del FortiGate** indicando que se violó una política.

```bash
ssh usuario@10.7.30.130              # SSH: debe fallar (sin respuesta)
```

> Ver evidencia: [18_web_vlan10_caja.png](screenshots/18_web_vlan10_caja.png), [19_bloqueo_inventario_vlan10.png](screenshots/19_bloqueo_inventario_vlan10.png), [20_ssh_vlan10_fallo.png](screenshots/20_ssh_vlan10_fallo.png)

**12.2 — Usuario VLAN 20 (único con SSH)**

```bash
ssh usuario@10.7.30.130
ssh usuario@10.7.30.131
ssh usuario@10.7.30.132
curl -s http://10.7.30.131/ | grep -o '<title>.*</title>'   # Web Inventario: <title>Sistema de Inventario</title>
traceroute 10.7.30.130
ping -c 3 10.7.30.10               # hacia la VLAN 10: debe fallar
```
Los tres SSH deben conectar y el web del Inventario debe responder. El `traceroute` muestra al FortiGate (`10.7.30.126`) como primer salto.

> Ver evidencia: [21_ssh_vlan20_exito.png](screenshots/21_ssh_vlan20_exito.png), [22_web_vlan20.png](screenshots/22_web_vlan20.png)

**12.3 — Servidores (DMZ): sin fuga hacia la LAN y salida solo a actualizaciones**

Desde un servidor (por ejemplo el Web Caja):
```bash
ping -c 3 10.7.30.10               # hacia la LAN: debe fallar
sudo apt update                    # debe funcionar (endpoint de actualización permitido)
curl -m 5 http://example.com       # debe fallar (Internet no permitido)
ping -c 3 8.8.8.8                  # debe fallar
nc -zv 10.7.30.132 3306              # hacia la DB (misma DMZ): debe conectar
```

> Ver evidencia: [23_dmz_a_lan_bloqueado.png](screenshots/23_dmz_a_lan_bloqueado.png), [24_dmz_actualizaciones.png](screenshots/24_dmz_actualizaciones.png)

**12.4 — Registros del FortiGate**

* `Log & Report → Forward Traffic`: filtrar por las políticas `VLAN20-SSH-DMZ`, `Bloqueo-DMZ-a-LAN`, `Bloqueo-VLAN10-DMZ` y `Bloqueo-DMZ-Internet`.
* `Log & Report → Security Events → Web Filter`: el bloqueo de `http://10.7.30.131/` desde la VLAN 10.

> Ver evidencia: [25_logs_fortigate.png](screenshots/25_logs_fortigate.png)

---

## 4. Capturas de Pantalla

Numeradas en el orden en que se toman durante el procedimiento.

| # | Archivo | Paso | Descripción |
|---|---|---|---|
| 01 | [`01_switch_vlan_seguridad.png`](screenshots/01_switch_vlan_seguridad.png) | 2 | SW-LAN: `show vlan brief`, `show interfaces trunk` y `show port-security`. |
| 02 | [`02_cli_acceso_fortigate.png`](screenshots/02_cli_acceso_fortigate.png) | 3 | CLI del FortiGate con la config inicial de `port1` (202.50.73.254/24). |
| 03 | [`03_interfaces_fortigate.png`](screenshots/03_interfaces_fortigate.png) | 4 | `Network → Interfaces`: port1, port2 y las sub-interfaces VLAN10, VLAN20 y VLAN30. |
| 04 | [`04_vlan10_dhcp_fortigate.png`](screenshots/04_vlan10_dhcp_fortigate.png) | 4.2 | Sub-interfaz VLAN10 con IP `10.7.30.62/26` y su DHCP. |
| 05 | [`05_vlan20_dhcp_fortigate.png`](screenshots/05_vlan20_dhcp_fortigate.png) | 4.3 | Sub-interfaz VLAN20 con IP `10.7.30.126/26` y su DHCP. |
| 06 | [`06_vlan30_dmz_fortigate.png`](screenshots/06_vlan30_dmz_fortigate.png) | 4.4 | Sub-interfaz VLAN30 (DMZ) con IP `10.7.30.142/28` y el servicio DNS. |
| 07 | [`07_dns_ruta_fortigate.png`](screenshots/07_dns_ruta_fortigate.png) | 5 | DNS y ruta por defecto hacia `202.50.73.2`. |
| 08 | [`08_ping_nube.png`](screenshots/08_ping_nube.png) | 6.1 | Ping de la PC local al FortiGate y ping del FortiGate a `8.8.8.8`. |
| 09 | [`09_usuarios_dhcp.png`](screenshots/09_usuarios_dhcp.png) | 6.2 | Usuarios V10 y V20 con IP por DHCP y ping a su gateway. |
| 10 | [`10_servidores_red.png`](screenshots/10_servidores_red.png) | 6.3 | Servidores con IP estática y ping a `10.7.30.142`. |
| 11 | [`11_endpoints_apt.png`](screenshots/11_endpoints_apt.png) | 7 | Hosts de los repositorios de actualización de un servidor. |
| 12 | [`12_objetos_direcciones.png`](screenshots/12_objetos_direcciones.png) | 8 | Objetos y grupos de direcciones. |
| 13 | [`13_webfilter_perfil.png`](screenshots/13_webfilter_perfil.png) | 9 | Perfil `Bloqueo-Inventario` con el URL Filter. |
| 14 | [`14_politicas_fortigate.png`](screenshots/14_politicas_fortigate.png) | 10 | Lista de políticas de firewall en su orden. |
| 15 | [`15_servidor_caja.png`](screenshots/15_servidor_caja.png) | 11.1 | Web Sistema de Caja: Apache y SSH activos y su página en el navegador. |
| 16 | [`16_servidor_inventario.png`](screenshots/16_servidor_inventario.png) | 11.2 | Web Sistema de Inventario: Apache y SSH activos y su página en el navegador. |
| 17 | [`17_servidor_db.png`](screenshots/17_servidor_db.png) | 11.3 | DB Server con MariaDB y SSH activos. |
| 18 | [`18_web_vlan10_caja.png`](screenshots/18_web_vlan10_caja.png) | 12.1 | Usuario V10 abriendo el Sistema de Caja. |
| 19 | [`19_bloqueo_inventario_vlan10.png`](screenshots/19_bloqueo_inventario_vlan10.png) | 12.1 | Página de bloqueo del FortiGate al abrir el Sistema de Inventario desde la VLAN 10. |
| 20 | [`20_ssh_vlan10_fallo.png`](screenshots/20_ssh_vlan10_fallo.png) | 12.1 | SSH fallando desde la VLAN 10. |
| 21 | [`21_ssh_vlan20_exito.png`](screenshots/21_ssh_vlan20_exito.png) | 12.2 | SSH exitoso a los tres servidores desde la VLAN 20. |
| 22 | [`22_web_vlan20.png`](screenshots/22_web_vlan20.png) | 12.2 | Usuario V20 abriendo el Sistema de Inventario. |
| 23 | [`23_dmz_a_lan_bloqueado.png`](screenshots/23_dmz_a_lan_bloqueado.png) | 12.3 | Ping desde la DMZ hacia la LAN fallando. |
| 24 | [`24_dmz_actualizaciones.png`](screenshots/24_dmz_actualizaciones.png) | 12.3 | `apt update` funcionando y salida a Internet bloqueada. |
| 25 | [`25_logs_fortigate.png`](screenshots/25_logs_fortigate.png) | 12.4 | Forward Traffic y Web Filter del FortiGate con los bloqueos. |

---

## 5. Estructura del Repositorio

```
/
├── README.md                  ← este documento
├── screenshots/               ← capturas numeradas de cada configuración
├── scripts/
│   ├── sw-lan.txt             ← switch: VLANs, trunk, port-security y seguridad básica
│   ├── fortigate-cli.txt      ← acceso inicial del FortiGate
│   ├── servidor-caja.sh       ← Web Sistema de Caja (Apache + SSH)
│   ├── servidor-inventario.sh ← Web Sistema de Inventario (Apache + SSH)
│   └── servidor-db.sh         ← DB Server (MariaDB + SSH)
├── running-configs/
│   ├── sw-lan-running-config.txt
│   └── fortigate-running-config.conf
└── entregable/
    └── ArleneFernandez_20250730_P6.txt
```

> Ajustar el número de práctica (`P6`) según lo indicado por el profesor. El video debe subirse al principio del repositorio (enlace colocado arriba en este README).
