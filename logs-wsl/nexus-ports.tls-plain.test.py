import socket, ssl

host = 'nexus.btnxlocal.ru'
proxy_ip = '72.56.1.35'
ports = [9080, 9081, 9082]

for port in ports:
    print(f'=== PORT {port} ===')

    # Plain HTTP probe
    try:
        s = socket.create_connection((proxy_ip, port), timeout=5)
        s.settimeout(5)
        req = f
