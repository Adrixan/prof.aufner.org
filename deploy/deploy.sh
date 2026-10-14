#!/usr/bin/env bash
# Deployment prof.aufner.org -> https://prof.aufner.org
#
# Deployt den committeten Stand von main per tar ueber SSH (auf dem Server gibt es kein rsync).
# Ablauf: Preflight, Build aus git archive, Backup des Webroots (lokal), Upload, Smoke-Test,
#         bei Fehler automatischer Rollback, danach Entfernen veralteter Dateien.
#
# Aufruf:  deploy/deploy.sh [-n|--dry-run]
# Konfig:  DEPLOY_HOST (SSH-Alias, Default aufner.org), DEPLOY_DIR (Default prof.aufner.org,
#          relativ zum SSH-Home), DEPLOY_URL (Default https://prof.aufner.org).
#          DEPLOY_VIA (optional): SSH-Alias eines Jumphosts. SSH laeuft dann per -J ueber diesen Host,
#          die Smoke-Tests (curl) werden ebenfalls auf dem Jumphost ausgefuehrt.
#          Beispiel: DEPLOY_VIA=m11x deploy/deploy.sh
# Keine Zugangsdaten im Skript: Authentifizierung laeuft ueber ~/.ssh/config und den SSH-Key.

set -euo pipefail

HOST="${DEPLOY_HOST:-aufner.org}"
REMOTE_DIR="${DEPLOY_DIR:-prof.aufner.org}"
SITE_URL="${DEPLOY_URL:-https://prof.aufner.org}"
VIA="${DEPLOY_VIA:-}"
BRANCH="main"
KEEP_BACKUPS=10

# Wird nicht deployt (Repo-intern)
EXCLUDES=(.gitignore .gitmodules .kilocode deploy)
# Alte Artefakte frueherer Deployments, die auf dem Server entfernt werden (nur diese Pfade, ohne rm -rf)
LEGACY_FILES=(media/Prof.Aufner.portrait.jpg .gitignore .gitmodules)
LEGACY_DIRS=(.kilocode/glm5-instructions .kilocode impressum datenschutz ki-transparenz)

DRY_RUN=0
case "${1:-}" in
    -n|--dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "Unbekannte Option: $1 (erlaubt: -n | --dry-run)" >&2; exit 2 ;;
esac

log()  { printf '[deploy] %s\n' "$*"; }
warn() { printf '[deploy] WARNUNG: %s\n' "$*" >&2; }
die()  { printf '[deploy] FEHLER: %s\n' "$*" >&2; exit 1; }
remote() { ssh "${SSH_OPTS[@]}" "$HOST" "$@"; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
# Eine gemultiplexte SSH-Verbindung fuer den ganzen Lauf: der Host sieht einen Login statt rund 20,
# was Sperren durch Brute-Force-Schutz (fail2ban) vermeidet. Der Socket liegt ausserhalb von $WORK,
# weil $WORK weiter unten neu angelegt wird. Wird beim Beenden wieder geschlossen.
mkdir -p "$ROOT/.scratch"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o ControlMaster=auto
          -o ControlPath="$ROOT/.scratch/ssh-deploy.sock" -o ControlPersist=120)
[ -n "$VIA" ] && SSH_OPTS+=(-J "$VIA")
# Zweite gemultiplexte Verbindung zum Jumphost fuer die curl-Smoke-Tests (nur bei DEPLOY_VIA).
VIA_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o ControlMaster=auto
          -o ControlPath="$ROOT/.scratch/ssh-via.sock" -o ControlPersist=120)
trap 'ssh "${SSH_OPTS[@]}" -O exit "$HOST" >/dev/null 2>&1 || true
      [ -n "$VIA" ] && ssh "${VIA_OPTS[@]}" -O exit "$VIA" >/dev/null 2>&1 || true' EXIT
# curl lokal oder (bei DEPLOY_VIA) auf dem Jumphost
vcurl() {
    if [ -n "$VIA" ]; then
        ssh "${VIA_OPTS[@]}" "$VIA" "curl $(printf '%q ' "$@")"
    else
        curl "$@"
    fi
}
WORK="$ROOT/.scratch/deploy"
BUILD="$WORK/build"
BACKUPS="$ROOT/.scratch/deploy-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------- Preflight
[ "$(git branch --show-current)" = "$BRANCH" ] || die "Aktueller Branch ist nicht $BRANCH."
git diff --quiet && git diff --cached --quiet || die "Getrackte Aenderungen nicht committet."
git fetch -q origin 2>/dev/null || warn "git fetch fehlgeschlagen, Remote-Vergleich uebersprungen."
if git rev-parse -q --verify "origin/$BRANCH" >/dev/null; then
    [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$BRANCH")" ] \
        || warn "HEAD weicht von origin/$BRANCH ab (nicht gepusht oder zurueck)."
fi
COMMIT="$(git rev-parse --short HEAD)"
log "Commit $COMMIT, Ziel $HOST:$REMOTE_DIR -> $SITE_URL${VIA:+ (via $VIA)}"
remote "true" || die "SSH-Verbindung zu $HOST fehlgeschlagen (Server nicht erreichbar oder IP gesperrt)."
remote "test -d '$REMOTE_DIR'" || die "Remote-Verzeichnis $REMOTE_DIR existiert nicht."

# ---------------------------------------------------------------- Build
rm -rf "$WORK"; mkdir -p "$BUILD" "$BACKUPS"
git archive HEAD | tar -x -C "$BUILD"
for e in "${EXCLUDES[@]}"; do rm -rf "${BUILD:?}/$e"; done
(cd "$BUILD" && find . -type f | sed 's|^\./||' | LC_ALL=C sort) > "$WORK/manifest.new"
[ -s "$WORK/manifest.new" ] || die "Build ist leer."
for f in index.html styles.css .htaccess; do
    grep -qx "$f" "$WORK/manifest.new" || die "Pflichtdatei $f fehlt im Build."
done
log "Build: $(wc -l < "$WORK/manifest.new") Dateien"

# ---------------------------------------------------------------- Stale-Liste
remote "cat '$REMOTE_DIR/.deploy-manifest' 2>/dev/null || true" > "$WORK/manifest.old"
LC_ALL=C sort -o "$WORK/manifest.old" "$WORK/manifest.old"
: > "$WORK/delete.files"
LC_ALL=C grep -vxFf "$WORK/manifest.new" "$WORK/manifest.old" >> "$WORK/delete.files" || true
for f in "${LEGACY_FILES[@]}"; do
    grep -qxF "$f" "$WORK/manifest.new" || echo "$f" >> "$WORK/delete.files"
done
LC_ALL=C sort -u -o "$WORK/delete.files" "$WORK/delete.files"

if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-Run. Hochzuladen:"; sed 's/^/    /' "$WORK/manifest.new"
    log "Auf dem Server zu entfernen (falls vorhanden):"
    { cat "$WORK/delete.files"; printf '%s/\n' "${LEGACY_DIRS[@]}"; } | sed 's/^/    /'
    exit 0
fi

# ---------------------------------------------------------------- Backup
BACKUP="$BACKUPS/prof.aufner.org-$STAMP.tar.gz"
remote "tar -C '$REMOTE_DIR' -czf - ." > "$BACKUP"
tar -tzf "$BACKUP" >/dev/null || die "Backup ist nicht lesbar: $BACKUP"
log "Backup: $BACKUP ($(wc -c < "$BACKUP") Bytes)"
ls -1t "$BACKUPS"/prof.aufner.org-*.tar.gz | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f --

rollback() {
    warn "Rollback auf Backup $BACKUP"
    tar -tzf "$BACKUP" | sed 's|^\./||' | grep -v '/$' | LC_ALL=C sort > "$WORK/backup.list" || true
    LC_ALL=C grep -vxFf "$WORK/backup.list" "$WORK/manifest.new" > "$WORK/rollback.rm" || true
    if [ -s "$WORK/rollback.rm" ]; then
        remote "cd '$REMOTE_DIR' && xargs -r -d '\n' rm -f --" < "$WORK/rollback.rm"
    fi
    remote "tar -xzf - -C '$REMOTE_DIR' --no-same-owner --no-overwrite-dir" < "$BACKUP"
    warn "Rollback abgeschlossen."
}

# ---------------------------------------------------------------- Upload
log "Upload ..."
tar -C "$BUILD" -cf - -T "$WORK/manifest.new" \
    | remote "tar -xf - -C '$REMOTE_DIR' --no-same-owner --no-same-permissions --no-overwrite-dir"

# ---------------------------------------------------------------- Smoke-Test
http_code() { vcurl -s -o /dev/null --max-time 20 -w '%{http_code}' "$1" || true; }
fail=0
check() {  # check <pfad> <erwarteter-code>
    local code; code="$(http_code "$SITE_URL$1")"
    if [ "$code" = "$2" ]; then log "  ok   $1 ($code)"; else warn "  FAIL $1 erwartet $2, erhalten $code"; fail=1; fi
}
log "Smoke-Test ..."
sleep 2
check / 200
for p in /styles.css /scripts.js \
         /fonts/inter-latin-400.woff2 /fonts/space-grotesk-latin-700.woff2 \
         /media/Prof.Aufner.Banner-768.webp /media/Prof.Aufner.Banner.png \
         /favicon.svg /robots.txt /llms.txt /sitemap.xml /.well-known/security.txt; do
    check "$p" 200
done
body="$(vcurl -s --max-time 20 "$SITE_URL/" || true)"
case "$body" in *"Prof. Aufner"*"Zum Titel Prof."*) log "  ok   Startseite enthaelt erwarteten Inhalt" ;;
                *) warn "  FAIL Startseite ohne erwarteten Inhalt"; fail=1 ;; esac
case "$body" in *googleapis.com*|*ko-fi.com/prof_aufner/\?*) warn "  FAIL Drittanbieter-Referenz auf Startseite"; fail=1 ;; esac

if [ "$fail" -ne 0 ]; then
    rollback
    die "Smoke-Test fehlgeschlagen, Stand zurueckgesetzt. Details oben."
fi

# ---------------------------------------------------------------- Aufraeumen und Manifest
if [ -s "$WORK/delete.files" ]; then
    remote "cd '$REMOTE_DIR' && xargs -r -d '\n' rm -f --" < "$WORK/delete.files"
fi
for d in "${LEGACY_DIRS[@]}"; do remote "rmdir '$REMOTE_DIR/$d' 2>/dev/null || true"; done
# leere Verzeichnisse alter Manifest-Dateien entfernen
sed -n 's|/[^/]*$||p' "$WORK/delete.files" | LC_ALL=C sort -u -r \
    | while read -r d; do [ -n "$d" ] && remote "rmdir '$REMOTE_DIR/$d' 2>/dev/null || true" < /dev/null; done
# Weiche Pruefungen (nur Warnung)
hdrs="$(vcurl -sI --max-time 20 "$SITE_URL/" | tr -d '\r' | tr 'A-Z' 'a-z')"
for h in content-security-policy x-content-type-options referrer-policy permissions-policy cross-origin-opener-policy strict-transport-security; do
    case "$hdrs" in *"$h:"*) log "  ok   Header $h" ;; *) warn "Header $h fehlt (greift .htaccess?)" ;; esac
done
for p in /.gitmodules /.gitignore /.git/HEAD /deploy/deploy.sh /.deploy-manifest /impressum/ /datenschutz/ /ki-transparenz/; do
    c="$(http_code "$SITE_URL$p")"
    case "$c" in 404|403) log "  ok   $p gesperrt ($c)" ;; *) warn "$p ist erreichbar ($c)" ;; esac
done
c="$(vcurl -s -o /dev/null --max-time 20 -w '%{http_code} %{redirect_url}' "https://www.${SITE_URL#https://}/" || true)"
case "$c" in "301 $SITE_URL/") log "  ok   www -> Apex (301)" ;; *) warn "www-Redirect nicht wie erwartet: $c" ;; esac

remote "cat > '$REMOTE_DIR/.deploy-manifest'" < "$WORK/manifest.new"
log "Fertig: $COMMIT live auf $SITE_URL"
