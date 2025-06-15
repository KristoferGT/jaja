#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║       🔐 SCRIPT DE CONFIGURACIÓN DE ROOT Y SSH                       ║
# ║           Autor: ChristopherAGT - Guatemalteco 🇬🇹                   ║
# ╚══════════════════════════════════════════════════════════════════════╝

# 🎨 Colores y formato
VERDE="\033[1;32m"
ROJO="\033[1;31m"
AMARILLO="\033[1;33m"
AZUL="\033[1;34m"
NEGRITA="\033[1m"
NEUTRO="\033[0m"

#cat /etc/ssh/sshd_config.bak (ver backup)
#cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config (restaurar backup)
#systemctl restart ssh || service ssh restart (reiniciar servicio)

# ⏳ Spinner de carga (con proceso como argumento)
spinner() {
  local pid
  "$@" &
  pid=$!
  local delay=0.1
  local spinstr='|/-\'
  echo -ne "${AMARILLO}"
  while ps -p $pid &>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  wait $pid 2>/dev/null
  echo -ne "${NEUTRO}"
}

# 🛡️ Verificar si se ejecuta como root
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${ROJO}⚠️ Este script requiere permisos de administrador.${NEUTRO}"
  echo -e "${AMARILLO}🔁 Reintentando con sudo...${NEUTRO}\n"
  exec sudo bash "$0" "$@"
fi

clear
echo -e "${AZUL}${NEGRITA}╔════════════════════════════════════════════╗"
echo -e "║      🔐 CONFIGURACIÓN ROOT Y SSH           ║"
echo -e "╚════════════════════════════════════════════╝${NEUTRO}\n"

# 🔥 Limpiar iptables
echo -e "${AMARILLO}🧹 Limpiando reglas de iptables...${NEUTRO}"
spinner iptables -F

# ➕ Permitir tráfico esencial
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # SSH

# 🌐 Configurar DNS
echo -e "${AMARILLO}🌍 Estableciendo DNS de Cloudflare y Google...${NEUTRO}"
chattr -i /etc/resolv.conf 2>/dev/null
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# 🔄 Actualizar paquetes
echo -e "${AZUL}📦 Actualizando el sistema...${NEUTRO}"
spinner apt update -y

# 🛠️ Configuración de SSH
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_CONFIG_CLOUDIMG="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"

echo -e "${AMARILLO}🔧 Configurando acceso root por SSH...${NEUTRO}"

# Backup antes de modificar
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

# Función para reemplazar o agregar configuraciones
reemplazar_o_agregar() {
  local archivo="$1"
  local buscar="$2"
  local reemplazo="$3"
  if grep -q "$buscar" "$archivo"; then
    sed -i "s|$buscar|$reemplazo|g" "$archivo"
  else
    echo "$reemplazo" >> "$archivo"
  fi
}

reemplazar_o_agregar "$SSH_CONFIG" "prohibit-password" "yes"
reemplazar_o_agregar "$SSH_CONFIG" "without-password" "yes"
sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" "$SSH_CONFIG"
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" "$SSH_CONFIG"

if [[ -f "$SSH_CONFIG_CLOUDIMG" ]]; then
  sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" "$SSH_CONFIG_CLOUDIMG"
fi

# 🔄 Reiniciar servicio SSH
echo -e "${AZUL}🔁 Reiniciando SSH para aplicar cambios...${NEUTRO}"
systemctl restart ssh 2>/dev/null || service ssh restart

# 🔐 Solicitar nueva contraseña root
echo -ne "\n${VERDE}${NEGRITA}📝 Ingresa la nueva contraseña para el usuario ROOT:${NEUTRO} "
read -s nueva_pass
echo

if [[ -z "$nueva_pass" ]]; then
  echo -e "${ROJO}❌ No ingresaste ninguna contraseña. Cancelando...${NEUTRO}"
  exit 1
fi

echo "root:$nueva_pass" | chpasswd
echo -e "${VERDE}✅ Contraseña actualizada correctamente.${NEUTRO}"

# ⚠️ Advertencia
echo -e "\n${ROJO}${NEGRITA}⚠️ IMPORTANTE:${NEUTRO} Este script habilita el acceso SSH root con contraseña."
echo -e "${ROJO}Se recomienda combinarlo con medidas de seguridad como fail2ban, firewall o VPN.${NEUTRO}"

# 🎉 Fin
echo -e "\n${VERDE}${NEGRITA}🎉 Script ejecutado exitosamente. Tu servidor está listo.${NEUTRO}\n"
