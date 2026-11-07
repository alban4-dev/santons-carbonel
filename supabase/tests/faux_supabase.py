#!/usr/bin/env python3
"""Faux Supabase pour tester l'appli sans compte : sert site/ et imite les
quelques routes Auth / REST / RPC / Functions qu'elle utilise, en exécutant
les requêtes sur un vrai PostgreSQL local avec le rôle « authenticated » et
l'identité de l'utilisateur (donc avec les vraies règles RLS de schema.sql).

Usage : python3 faux_supabase.py <dsn postgres> <port>
Test seulement : mots de passe en mémoire, jetons non signés.
"""
import base64
import http.server
import json
import os
import re
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import psycopg2
from psycopg2 import sql

SITE = Path(__file__).resolve().parents[2] / "site"
DSN, PORT = sys.argv[1], int(sys.argv[2])
TABLES = {"profils", "familles", "famille_invitations", "membres", "listes", "liste_gerants",
          "liste_visiteurs", "liste_invitations", "liste_items", "modeles_famille"}
STOCK = Path(os.environ.get("SCRATCH", "/tmp")) / "stockage"
RPCS = {"creer_famille", "rejoindre_famille", "creer_liste", "devenir_visiteur", "voir_liste",
        "nouveau_code_famille", "nouveau_code_visite"}
USERS = {}  # email -> {id, password, nom}
db = psycopg2.connect(DSN)


def b64(d):
    return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")


def session_for(u):
    exp = int(time.time()) + 3600
    tok = b64({"alg": "none", "typ": "JWT"}) + "." + b64({"sub": u["id"], "email": u["email"], "exp": exp,
                                                           "role": "authenticated", "aud": "authenticated"}) + ".x"
    return {"access_token": tok, "token_type": "bearer", "expires_in": 3600, "expires_at": exp,
            "refresh_token": "r-" + u["id"], "user": user_obj(u)}


def user_obj(u):
    return {"id": u["id"], "aud": "authenticated", "role": "authenticated", "email": u["email"],
            "user_metadata": {"nom": u.get("nom", "")}, "app_metadata": {"provider": "email"},
            "created_at": "2026-11-07T00:00:00Z"}


def uid_from(headers):
    m = re.match(r"Bearer (.+)", headers.get("Authorization", ""))
    if not m:
        return None
    try:
        payload = m.group(1).split(".")[1]
        return json.loads(base64.urlsafe_b64decode(payload + "==="))["sub"]
    except Exception:
        return None


def run(uid, query, params=()):
    with db:
        with db.cursor() as cur:
            if uid:
                cur.execute("set local role authenticated; select set_config('request.jwt.claim.sub', %s, true)", (uid,))
            else:
                cur.execute("set local role anon")
            cur.execute(query, params)
            if cur.description:
                cols = [c.name for c in cur.description]
                return [dict(zip(cols, r)) for r in cur.fetchall()]
            return []


def filters(qs):
    where, vals = [], []
    for k, vs in qs.items():
        if k in ("select", "order", "offset", "limit", "on_conflict", "columns"):
            continue
        for v in vs:
            op, _, val = v.partition(".")
            if op != "eq":
                raise ValueError("filtre non géré : " + v)
            where.append(sql.SQL("{}::text = %s").format(sql.Identifier(k)))
            vals.append(val)
    return where, vals


class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(SITE), **k)

    def log_message(self, *a):
        pass

    def send(self, code, body=None, headers=None):
        data = b"" if body is None else json.dumps(body, default=str).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"null")

    def pg_error(self, e):
        code = getattr(e, "pgcode", None) or ""
        msg = getattr(getattr(e, "diag", None), "message_primary", None) or str(e)
        self.send(403 if code == "42501" else 400, {"code": code, "message": msg, "details": None, "hint": None})

    # ------------------------------------------------------------------ GET
    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/config.js":
            js = (f'window.SANTONS_CONFIG = {{ supabaseUrl: "http://localhost:{PORT}", '
                  f'supabaseKey: "cle-de-test", reconnaissance: true }};').encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript")
            self.end_headers()
            self.wfile.write(js)
            return
        if u.path == "/auth/v1/user":
            uid = uid_from(self.headers)
            us = [x for x in USERS.values() if x["id"] == uid]
            return self.send(200, user_obj(us[0])) if us else self.send(401, {"message": "invalid token"})
        if u.path.startswith("/rest/v1/"):
            return self.rest("GET", u)
        if u.path.startswith("/storage/v1/object/public/photos/"):
            f = STOCK / u.path.split("/storage/v1/object/public/photos/", 1)[1]
            if not f.is_file():
                return self.send(404, {"message": "introuvable"})
            data = f.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if u.path.startswith("/realtime/"):
            return self.send(404, {})
        return super().do_GET()

    def do_HEAD(self):
        return self.do_GET()

    def do_OPTIONS(self):
        self.send(204)

    # ---------------------------------------------------------- POST/PATCH/DELETE
    def do_POST(self):
        u = urlparse(self.path)
        qs = parse_qs(u.query)
        if u.path == "/auth/v1/signup":
            b = self.body()
            email = b["email"].lower()
            if email in USERS:
                return self.send(422, {"code": 422, "msg": "User already registered", "error_code": "user_already_exists"})
            if len(b.get("password", "")) < 6:
                return self.send(422, {"code": 422, "msg": "Password should be at least 6 characters.", "error_code": "weak_password"})
            usr = {"id": str(uuid.uuid4()), "email": email, "password": b["password"], "nom": (b.get("data") or {}).get("nom", "")}
            USERS[email] = usr
            with db, db.cursor() as cur:
                cur.execute("insert into auth.users (id, email) values (%s, %s)", (usr["id"], email))
            return self.send(200, session_for(usr))
        if u.path == "/auth/v1/token":
            b = self.body()
            if qs.get("grant_type") == ["password"]:
                usr = USERS.get(b.get("email", "").lower())
                if not usr or usr["password"] != b.get("password"):
                    return self.send(400, {"error": "invalid_grant", "error_description": "Invalid login credentials",
                                           "code": 400, "error_code": "invalid_credentials", "msg": "Invalid login credentials"})
                return self.send(200, session_for(usr))
            rid = (b.get("refresh_token") or "")[2:]
            us = [x for x in USERS.values() if x["id"] == rid]
            return self.send(200, session_for(us[0])) if us else self.send(400, {"error": "invalid_grant"})
        if u.path in ("/auth/v1/logout", "/auth/v1/recover"):
            return self.send(204 if u.path.endswith("logout") else 200, None if u.path.endswith("logout") else {})
        if u.path.startswith("/storage/v1/object/photos/"):
            name = u.path.split("/storage/v1/object/photos/", 1)[1]
            data = self.rfile.read(int(self.headers.get("Content-Length") or 0))
            ctype = self.headers.get("Content-Type", "")
            if ctype.startswith("multipart/form-data"):  # supabase-js envoie un Blob en formulaire
                from email import policy
                from email.parser import BytesParser
                msg = BytesParser(policy=policy.default).parsebytes(b"Content-Type: " + ctype.encode() + b"\r\n\r\n" + data)
                parts = [m for m in msg.iter_parts() if m.get_filename() or m.get_content_type().startswith("image/")]
                data = parts[-1].get_payload(decode=True) if parts else b""
            try:
                run(uid_from(self.headers), "insert into storage.objects (bucket_id, name) values ('photos', %s)", (name,))
            except psycopg2.Error as e:
                db.rollback()
                return self.send(400, {"statusCode": "403", "error": "Unauthorized", "message": "new row violates row-level security policy"})
            f = STOCK / name
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(data)
            return self.send(200, {"Key": "photos/" + name, "Id": name})
        if u.path.startswith("/rest/v1/rpc/"):
            fn = u.path.rsplit("/", 1)[1]
            if fn not in RPCS:
                return self.send(404, {"message": "fonction inconnue"})
            args = self.body() or {}
            q = sql.SQL("select {}({}) as r").format(sql.Identifier(fn), sql.SQL(", ").join(
                sql.SQL("{} => %s").format(sql.Identifier(k)) for k in args))
            try:
                rows = run(uid_from(self.headers), q, list(args.values()))
            except psycopg2.Error as e:
                return self.pg_error(e)
            return self.send(200, rows[0]["r"])
        if u.path.startswith("/rest/v1/"):
            return self.rest("POST", u)
        if u.path == "/functions/v1/reconnaitre":
            b = self.body()
            ok = isinstance(b.get("photo"), str) and isinstance(b.get("planches"), list) and 1 <= len(b["planches"]) <= 6
            if not uid_from(self.headers) or not ok:
                return self.send(400, {"error": "requête invalide"})
            (Path(os.environ.get("SCRATCH", "/tmp")) / "derniere_reconnaissance.json").write_text(
                json.dumps({"planches": len(b["planches"]), "photo": len(b["photo"]), "liste": b.get("liste", "")[:200]}))
            return self.send(200, {"trouves": [{"n": 1, "sur": True}, {"n": 3, "sur": False}, {"n": 5, "sur": True}]})
        self.send(404, {})

    def do_PATCH(self):
        return self.rest("PATCH", urlparse(self.path))

    def do_DELETE(self):
        u = urlparse(self.path)
        if u.path.startswith("/storage/v1/object/photos"):
            b = self.body() or {}
            for name in b.get("prefixes", []):
                run(uid_from(self.headers), "delete from storage.objects where bucket_id = 'photos' and name = %s", (name,))
                (STOCK / name).unlink(missing_ok=True)
            return self.send(200, [])
        return self.rest("DELETE", u)

    # ------------------------------------------------------------------ REST
    def rest(self, method, u):
        table = u.path.split("/")[3]
        if table not in TABLES:
            return self.send(404, {"message": "table inconnue"})
        qs = parse_qs(u.query)
        uid = uid_from(self.headers)
        try:
            where, vals = filters(qs)
            w = sql.SQL(" where ") + sql.SQL(" and ").join(where) if where else sql.SQL("")
            t = sql.Identifier(table)
            if method == "GET":
                cols = qs.get("select", ["*"])[0]
                sel = sql.SQL("*") if cols == "*" else sql.SQL(", ").join(sql.Identifier(c) for c in cols.split(","))
                q = sql.SQL("select {} from {}").format(sel, t) + w
                if "limit" in qs:
                    q += sql.SQL(" limit {} offset {}").format(sql.Literal(int(qs["limit"][0])), sql.Literal(int(qs.get("offset", ["0"])[0])))
                rows = run(uid, q, vals)
                if "vnd.pgrst.object" in self.headers.get("Accept", ""):
                    return self.send(200, rows[0]) if rows else self.send(406, {"code": "PGRST116", "message": "0 rows"})
                return self.send(200, rows)
            if method == "POST":
                b = self.body()
                rows = b if isinstance(b, list) else [b]
                prefer = self.headers.get("Prefer", "")
                conflict = qs.get("on_conflict", [None])[0]
                out = []
                for r in rows:
                    keys = list(r)
                    q = sql.SQL("insert into {} ({}) values ({})").format(
                        t, sql.SQL(", ").join(map(sql.Identifier, keys)), sql.SQL(", ").join(sql.Placeholder() * len(keys)))
                    if "merge-duplicates" in prefer:
                        if conflict:
                            target = [c.strip() for c in conflict.split(",")]
                        else:
                            pk = run(None if False else uid, "select a.attname from pg_index i join pg_attribute a on a.attrelid = i.indrelid "
                                     "and a.attnum = any(i.indkey) where i.indrelid = %s::regclass and i.indisprimary", ("public." + table,))
                            target = [p["attname"] for p in pk]
                        upd = [k for k in keys if k not in target]
                        q += sql.SQL(" on conflict ({}) do ").format(sql.SQL(", ").join(map(sql.Identifier, target)))
                        q += (sql.SQL("update set ") + sql.SQL(", ").join(
                            sql.SQL("{} = excluded.{}").format(sql.Identifier(k), sql.Identifier(k)) for k in upd)) if upd else sql.SQL("nothing")
                    if "representation" in prefer:
                        q += sql.SQL(" returning *")
                    out += run(uid, q, [r[k] for k in keys])
                if "representation" not in prefer:
                    return self.send(201, None)
                if "vnd.pgrst.object" in self.headers.get("Accept", ""):
                    return self.send(201, out[0] if out else None)
                return self.send(201, out)
            if method == "PATCH":
                b = self.body()
                q = sql.SQL("update {} set ").format(t) + sql.SQL(", ").join(
                    sql.SQL("{} = %s").format(sql.Identifier(k)) for k in b) + w
                run(uid, q, list(b.values()) + vals)
                return self.send(204)
            if method == "DELETE":
                run(uid, sql.SQL("delete from {}").format(t) + w, vals)
                return self.send(204)
        except psycopg2.Error as e:
            db.rollback()
            return self.pg_error(e)
        except ValueError as e:
            return self.send(400, {"message": str(e)})


http.server.ThreadingHTTPServer.daemon_threads = True
print(f"faux Supabase sur http://localhost:{PORT}", flush=True)
http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
