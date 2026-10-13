Deployment- und Pruefhinweise (prof.aufner.org)

Deployment: deploy/deploy.sh (siehe Kopfkommentar). Der Live-Server (Plesk, nginx als Proxy) meldet "server: nginx".
Nach dem Deploy pruefen:

  curl -sI https://prof.aufner.org/ | grep -iE "content-security|x-content-type|referrer|permissions|cross-origin|strict-transport|x-frame"
  curl -sI -o /dev/null -w "%{http_code} %{redirect_url}\n" http://prof.aufner.org/
  curl -sI -o /dev/null -w "%{http_code} %{redirect_url}\n" https://www.prof.aufner.org/
  curl -s -o /dev/null -w "%{http_code}\n" https://prof.aufner.org/.gitmodules      # erwartet 404
  curl -s -o /dev/null -w "%{http_code}\n" https://prof.aufner.org/.git/HEAD        # erwartet 404
  curl -s -o /dev/null -w "%{http_code}\n" https://prof.aufner.org/.well-known/security.txt   # erwartet 200
  curl -s -o /dev/null -w "%{http_code}\n" https://prof.aufner.org/deploy/nginx-snippet.conf  # erwartet 404

Fehlen die Header, greift .htaccess nicht: dann deploy/nginx-snippet.conf im Hosting-Panel
(falls nginx-Konfiguration moeglich) eintragen oder den Support des Hosters fragen.
Die meta-Tags (CSP ohne frame-ancestors, referrer) in den HTML-Dateien greifen unabhaengig davon.

HSTS: max-age=15768000 (6 Monate) wie vom Host gesetzt. Preload (max-age mind. 31536000,
Direktive preload, Eintrag auf hstspreload.org) ist praktisch nicht rueckgaengig zu machen.
[TODO: Entscheidung]
