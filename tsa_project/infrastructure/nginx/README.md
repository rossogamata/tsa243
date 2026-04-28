# Nginx — proxy.tsa243.lab

**VM:** `proxy.tsa243.lab` · `192.168.177.12`  
**Сервіс:** Nginx reverse proxy  
**Порти:** 80 (HTTP), 443 (HTTPS)

---

## Що керує викладач

- Встановлення Nginx, базова конфігурація
- TLS wildcard-сертифікат для `*.tsa243.lab`
- Default vhost з переліком активних курсантських сайтів

## Що робить кожен курсант

1. Запускає будь-який HTTP-сервіс на своїй VM (Python, Node, Nginx, Apache)
2. Просить (або сам через PR) додати свій vhost-конфіг:

   ```nginx
   # /etc/nginx/sites-available/surname.tsa243.lab
   server {
       listen 80;
       server_name surname.tsa243.lab;

       location / {
           proxy_pass http://192.168.177.1XX:PORT;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

3. Перевіряє через браузер: `http://surname.tsa243.lab`

## Навчальний момент

Reverse proxy як концепція: клієнт звертається до одного IP (.12), Nginx знає
куди перенаправити запит. Природній місток до Docker / load balancing на наступному курсі.
