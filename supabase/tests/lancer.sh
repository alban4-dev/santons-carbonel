#!/bin/sh
# Tests sans compte Supabase : PostgreSQL 16 local + faux serveur + navigateur.
#   1. droits.sql  : vérifications des règles d'accès (membres, gérants, visiteurs, inconnus)
#   2. parcours.js : Papa crée la famille et la crèche de Léa, Maman la rejoint par le lien,
#                    Mamie ouvre la page publique sans compte (Playwright, captures dans $SCRATCH).
#   3. ajout.js    : un santon ancien ajouté avec photo, coché, vu par Maman et en public, retiré.
# Prérequis : PostgreSQL démarré sur le port 54329 (socket /tmp), psycopg2, Playwright,
#             et une photo de crèche en $SCRATCH/creche.jpg.
set -e
cd "$(dirname "$0")/../.."
export SCRATCH="${SCRATCH:-/tmp}"
PSQL="psql -h /tmp -p 54329 -U postgres"
for db in droits app; do
  $PSQL -q -c "drop database if exists $db" -c "create database $db" >/dev/null 2>&1
  $PSQL -d $db -q -v ON_ERROR_STOP=1 -f supabase/tests/auth_factice.sql >/dev/null 2>&1
  $PSQL -d $db -q -v ON_ERROR_STOP=1 -f supabase/schema.sql >/dev/null 2>&1
done
echo "== Règles d'accès (vérifications réussies / échouées)"
$PSQL -d droits -f supabase/tests/droits.sql 2>/dev/null | grep -E '^T[0-9]+[^|]*\|[tf]$' > "$SCRATCH/droits.txt"
echo "$(grep -c '|t$' "$SCRATCH/droits.txt") / $(grep -c '|f$' "$SCRATCH/droits.txt" || true)"
echo "== Parcours dans le navigateur"
python3 build.py >/dev/null
python3 supabase/tests/faux_supabase.py "host=/tmp port=54329 user=postgres dbname=app" 8766 & SRV=$!
sleep 1.5
node supabase/tests/parcours.js || true
echo "== Santon ancien ajouté par la famille"
node supabase/tests/ajout.js || true
kill $SRV
