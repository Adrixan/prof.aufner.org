# Session-Handoff prof.aufner.org (2026-10-13)

## Trajektorie
Auftrag: Repo an Styleguide "Bioluminescent Night" und AT/EU-Recht anpassen (Audit, Styleguide, Recht, Security, Verifikation). Plan wurde im Plan-Modus freigegeben. Umsetzung auf Branch `feat/styleguide-legal`, nicht gepusht, nicht gemergt.

## Entscheidungen des Auftraggebers
- Hero-Foto (portrait.jpg) aus dem Hero entfernt und aus dem Repo geloescht. Banner mit Anime-Figur bleibt als PNG unveraendert, WebP-Kopien (768 w, 1536 w) per `<picture>` ergaenzt.
- Unternehmens-Link korrigiert auf https://code-alongsi.de.
- Giphy und Bluesky als Social-Links ergaenzt.
- Hosting: git pull im Webroot, `.htaccess` als Primaerkonfig (Live-Server meldet nginx, Wirksamkeit ungeprueft).

## Stand
Commits auf Branch: Fonts, Styles, HTML-Refactor, SEO-Assets, Legal-Seiten, Security-Konfig, zwei kleine Fixes. Arbeitsdateien und Messungen in `.scratch/` (audit.md, contrast.md, verification.md, werbekennzeichnung.md, future-features-todo.md, gen_pages.py). `.scratch/` und `*.md` sind in .gitignore.

## Offene Entscheidungen
- Rechtstexte: alle [TODO]-Platzhalter ausfuellen, rechtliche Pruefung (AT), Entwurfshinweise entfernen.
- Zuordnung Code-Alongside als Betreiber der Website (§ 14 UGB) klaeren.
- HSTS-Preload entscheiden.
- Banner traegt sichtbares Gemini-Wasserzeichen unten rechts: KI-Transparenz-Text bestaetigen.

## Naechste Schritte
1. Platzhalter fuellen (siehe Abschlussbericht).
2. Branch reviewen, mergen, deployen.
3. Live-Header mit Befehlen aus `deploy/README.txt` pruefen, ggf. nginx-Snippet im Hosting eintragen.
4. Lighthouse und `curl -I` gegen Live wiederholen.
5. security.txt-Kontakt eintragen, Netcup-AVV abschliessen, Logfile-Speicherdauer festlegen.

## Update Deployment (2026-10-13)
- Branch feat/styleguide-legal nach main gemergt und nach origin gepusht.
- Deploy-Skript: `deploy/deploy.sh` (Dry-Run mit `-n`). SSH-Alias `aufner.org`, Zielordner `prof.aufner.org` im Account-Root (Plesk, nginx als Proxy vor Apache, `.htaccess` greift). Ablauf: Build aus git archive HEAD, lokales Backup in `.scratch/deploy-backups/`, tar-Upload, Smoke-Test, automatischer Rollback bei Fehler, danach Entfernen veralteter Dateien, Manifest `.deploy-manifest` auf dem Server.
- Standing Order des Auftraggebers: nach jeder abgeschlossenen und geprueften Aenderung auf main mit dem Skript deployen.
- Live-Messung: Lighthouse mobil 99/100/100/100, desktop 100/100/100/100, axe 0 Violations, keine Drittanfragen, Header vollstaendig, HSTS einfach (vom Host).
- Live noch sichtbar: [TODO]-Platzhalter und Entwurfshinweise in Impressum, Datenschutz, KI-Transparenz sowie "Zum Titel Prof." auf der Startseite.

## Update Impressum (2026-10-13)
- Impressum auf Wunsch entfernt (Seite, Footer-Links, Sitemap). /impressum/ liefert live 404.
- Code-Alongside komplett entfernt (Websites-Karte, Datenschutz-Verweis). Marke Prof. Aufner = Privatperson.
- Verantwortlichen-Angaben nur als [TODO] in Datenschutz Abschnitt 1. Rechtlicher Hinweis ausgesprochen: § 25 MedienG und bei Werbung § 5 ECG verlangen eine Anbieterkennzeichnung.
- deploy.sh: Aufraeumen laeuft vor den weichen Pruefungen, ssh-stdin-Bug im Loop behoben.

## Update Rechtsseiten (2026-10-13, Commit f4f33c0)
- Datenschutz und KI-Transparenz entfernt (404 live), wie vorher das Impressum. Footer enthaelt nur noch Marke, Tagline, Titel-Fussnote und Copyright.
- Code-Alongside als Websites-Karte wieder da ("Mein Unternehmen fuer IT- und Informationssicherheitsberatung"), ohne Markenbeziehung.
- Rechtshinweis (§ 25 MedienG, § 5 ECG, Art. 13 DSGVO) ausgesprochen, Entscheidung beim Auftraggeber. Texte sind in Git-Historie (8adec69) abrufbar.
- security.txt hat weiterhin Platzhalter-Kontakt.

## Update Bots, Wasserzeichen, security.txt (2026-10-13, Commits eec17bd, 2a3c0b0)
- Gemini-Zeichen im Banner per Inpainting entfernt (1404 px), WebP neu erzeugt. Original liegt lokal in .scratch/Banner.original.png und in der Git-Historie. Unsichtbares SynthID-Wasserzeichen bleibt technisch bestehen.
- security.txt: Contact mailto:prof@aufner.org.
- robots.txt: alle Crawler und KI-Agenten explizit erlaubt, Content-Signal search/ai-input/ai-train=yes. Neu: llms.txt, meta robots ohne Snippet-Limits, JSON-LD (WebSite, Person).
- NICHT DEPLOYT: aufner.org (<hosting IP>) antwortet auf Ping, verweigert aber alle TCP-Ports (22, 80, 443, 21, 8443), auch von einer unabhaengigen zweiten Quelle. Keine IP-Sperre gegen die Entwickler-IP, sondern serverseitiger Ausfall oder Sperre. netcup-Status zeigt keinen Webhosting-Vorfall. Naechster Schritt: Erreichbarkeit pruefen (ein Versuch), dann `deploy/deploy.sh`. Falls dauerhaft: netcup-Support oder Server-Control-Panel (SCP) pruefen, ob Plesk/sshd laufen und ob Firewall-Regeln alles ablehnen.
- Offen: nach Wiederherstellung `.scratch/botcheck.sh` mit Pausen testen (kein Burst) und pruefen, ob Host-Regeln (Fail2Ban, ModSecurity, Imunify) KI-Bots blocken.

## Update Deploy via Jumphost (2026-10-14, Commit 19e5e3e)
- Deploy-Skript: `DEPLOY_VIA=<ssh-alias>` leitet SSH per -J und die curl-Smoke-Tests ueber einen Jumphost. Deployment von eec17bd/2a3c0b0/19e5e3e ueber m11x erfolgreich, Live-Stand geprueft (Banner-Hash identisch, security.txt, robots.txt, llms.txt, JSON-LD).
- Ursache der Sperre: Der Host sperrt IPs, die Anfragen mit KI-Crawler-User-Agents senden (ClaudeBot, OAI-SearchBot; reproduziert). Meine Bot-UA-Tests haben die Entwickler-IP und danach m11x (<m11x IP>) gesperrt. Das widerspricht dem Ziel "KI-Bot-freundlich". Behebung nur im Plesk: IP-Adressensperre (Fail2Ban) Jails und Filter pruefen, Whitelist, ModSecurity/Imunify-Regeln. Danach beide IPs entsperren.
- Offen: Whitelist/Entsperrung von <school IP> und <m11x IP>. Die frueher notierte "unabhaengige zweite Quelle" (WebFetch) war vermutlich dieselbe IP.

## Housekeeping 2026-11-01
- `.scratch/` cleaned; audit.md, contrast.md, verification.md, werbekennzeichnung.md and future-features-todo.md are now in `~/Obsidian/Adrixan/Educator/prof.aufner.org/`. Only the newest deploy backup remains.

## Update 2026-11-06 (edu-publisher code session)
- Privacy policy `/datenschutz/` and app page `/publisher/` live (d8ce06d) for the Google OAuth verification of the
  Prof. Aufner Publisher and the comment processing of edu-publisher. Footer links on all pages. deploy.sh no longer
  deletes `datenschutz/`; its smoke test expects both pages with 200. Rules in AGENTS.md "Legal pages".
- Peter still: consent screen URLs, DNS TXT for aufner.org at Porkbun (Search Console domain property), demo video,
  resubmit. Details in edu-publisher `.agents/session-handoff.md`.
