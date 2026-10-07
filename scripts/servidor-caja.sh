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
<tr><td>Servidor</td><td>Web Sistema de Caja · 10.7.30.131 · DMZ (VLAN 30)</td></tr>
</table></div></main>
<footer>Página de demostración con fines académicos. No es un sistema de producción.</footer>
</body>
</html>
EOF
sudo systemctl enable --now apache2 ssh
