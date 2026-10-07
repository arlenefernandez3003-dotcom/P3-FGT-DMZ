sudo apt update && sudo apt install -y mariadb-server openssh-server
sudo sed -i 's/^bind-address.*/bind-address = 10.7.30.133/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
sudo systemctl enable --now ssh
sudo mysql <<'EOF'
CREATE DATABASE caja_db;
CREATE DATABASE inventario_db;
CREATE USER 'caja'@'10.7.30.131' IDENTIFIED BY 'Lab12345';
CREATE USER 'inventario'@'10.7.30.132' IDENTIFIED BY 'Lab12345';
GRANT ALL ON caja_db.* TO 'caja'@'10.7.30.131';
GRANT ALL ON inventario_db.* TO 'inventario'@'10.7.30.132';
FLUSH PRIVILEGES;
EOF
