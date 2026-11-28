#!/usr/bin/env python3
"""Checks the REMBO WhatsApp line step by step, against the real Meta API
and the deployed whatsapp-webhook function. The output is in French, for
the person setting up the line.

The secrets are read from ~/.config/rembo/whatsapp.env (chmod 600), never
printed, never in the repository:
    WHATSAPP_TOKEN=...
    WHATSAPP_PHONE_NUMBER_ID=...
    WHATSAPP_APP_SECRET=...
    WHATSAPP_VERIFY_TOKEN=...

  python3 tool/whatsapp/diagnose.py                     # token, number, webhook
  python3 tool/whatsapp/diagnose.py --envoyer 2126XXXXXXXX
      # also sends the « hello_world » template to that number (digits only)
  python3 tool/whatsapp/diagnose.py --compte <WABA id>
      # also checks that the app is subscribed to the WhatsApp Business
      # account (without it Meta delivers no message to the webhook)
  REMBO_WEBHOOK_URL=https://<ref>.supabase.co/functions/v1/whatsapp-webhook \
      python3 tool/whatsapp/diagnose.py                 # another project

To test without Meta, see simulate.py.
"""
import json
import os
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request

FICHIER = os.path.expanduser("~/.config/rembo/whatsapp.env")
GRAPH = "https://graph.facebook.com/v21.0"
WEBHOOK = os.environ.get(
    "REMBO_WEBHOOK_URL",
    "https://xaccybllagvbqrrsheet.supabase.co/functions/v1/whatsapp-webhook",
)
NOMS = ["WHATSAPP_TOKEN", "WHATSAPP_PHONE_NUMBER_ID", "WHATSAPP_APP_SECRET",
        "WHATSAPP_VERIFY_TOKEN"]

# The most common Meta error codes, explained.
CODES = {
    190: "jeton invalide ou expiré (celui de la page « Configuration de l'API » "
         "dure 24 h) : en générer un nouveau",
    10: "le jeton n'a pas la permission : cocher whatsapp_business_messaging et "
        "whatsapp_business_management, et assigner l'app à l'utilisateur système",
    200: "permission manquante sur ce compte WhatsApp (assigner le compte WhatsApp "
         "à l'utilisateur système dans les Paramètres Business)",
    100: "identifiant inconnu ou inaccessible avec ce jeton : vérifier que c'est "
         "l'ID du NUMÉRO (Phone number ID) et pas celui du compte WhatsApp Business",
    131030: "destinataire non autorisé : l'ajouter dans « À » (Configuration de "
            "l'API) et confirmer le code reçu",
    131047: "plus de 24 h depuis le dernier message de cette personne : un texte "
            "libre est refusé, seul un modèle (hello_world) passe",
    131026: "message non livrable : le numéro n'a pas WhatsApp ou n'a pas accepté "
            "les nouvelles conditions",
    133010: "le numéro de l'entreprise n'est pas enregistré sur l'API",
    131031: "compte WhatsApp Business verrouillé par Meta : seule une "
            "vérification d'entreprise (ou un examen demandé dans Business "
            "Support Home) le débloque",
}


def ok(m): print(f"  ✅ {m}")
def ko(m): print(f"  ❌ {m}")
def info(m): print(f"  ·  {m}")


def lire_secrets():
    print("1. Fichier des secrets")
    if not os.path.exists(FICHIER):
        ko(f"{FICHIER} introuvable"); sys.exit(1)
    if os.stat(FICHIER).st_mode & (stat.S_IRWXG | stat.S_IRWXO):
        info(f"droits trop ouverts : chmod 600 {FICHIER}")
    s = {}
    for ligne in open(FICHIER, encoding="utf-8"):
        ligne = ligne.strip()
        if ligne and not ligne.startswith("#") and "=" in ligne:
            k, v = ligne.split("=", 1)
            s[k.strip()] = v.strip().strip('"').strip("'")
    manquants = [n for n in NOMS if not s.get(n)]
    if manquants:
        ko("manquent : " + ", ".join(manquants)); sys.exit(1)
    ok("les 4 valeurs sont présentes")
    pid = s["WHATSAPP_PHONE_NUMBER_ID"]
    if not pid.isdigit():
        ko("WHATSAPP_PHONE_NUMBER_ID doit être un nombre (pas le numéro +212…)")
    if s["WHATSAPP_TOKEN"].startswith("Bearer"):
        ko("WHATSAPP_TOKEN : enlever le mot « Bearer »")
    return s


def appel(methode, url, jeton=None, corps=None):
    data = json.dumps(corps).encode() if corps is not None else None
    req = urllib.request.Request(url, data=data, method=methode)
    if jeton:
        req.add_header("Authorization", f"Bearer {jeton}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except urllib.error.URLError as e:
        return 0, str(e.reason)


def erreur_meta(texte):
    try:
        e = json.loads(texte)["error"]
    except Exception:
        return texte[:300]
    code = e.get("code")
    sous = e.get("error_subcode")
    detail = (e.get("error_data") or {}).get("details", "")
    explication = CODES.get(code, "")
    return (f"code {code}{'/' + str(sous) if sous else ''} : {e.get('message', '')}"
            f"{' — ' + detail if detail else ''}"
            f"{chr(10) + '     → ' + explication if explication else ''}")


def verifier_numero(s):
    print("2. Jeton et identifiant du numéro (API Meta)")
    st, t = appel("GET", f"{GRAPH}/{s['WHATSAPP_PHONE_NUMBER_ID']}"
                  "?fields=display_phone_number,verified_name,"
                  "code_verification_status,quality_rating",
                  s["WHATSAPP_TOKEN"])
    if st != 200:
        ko(erreur_meta(t)); return False
    d = json.loads(t)
    ok(f"numéro {d.get('display_phone_number')} « {d.get('verified_name')} » "
       f"(qualité {d.get('quality_rating', '?')})")
    return True


def envoyer(s, dest):
    print(f"3. Envoi du modèle hello_world à {dest}")
    st, t = appel("POST", f"{GRAPH}/{s['WHATSAPP_PHONE_NUMBER_ID']}/messages",
                  s["WHATSAPP_TOKEN"],
                  {"messaging_product": "whatsapp", "to": dest,
                   "type": "template",
                   "template": {"name": "hello_world",
                                "language": {"code": "en_US"}}})
    if st == 200:
        ok("accepté par Meta : le message doit arriver sur le téléphone")
        info("s'il n'arrive pas : numéro pas dans la liste « À », ou mal écrit")
    else:
        ko(erreur_meta(t))


def verifier_compte(s, compte):
    print(f"3b. Abonnement de l'app au compte WhatsApp Business {compte}")
    st, t = appel("GET", f"{GRAPH}/{compte}/subscribed_apps", s["WHATSAPP_TOKEN"])
    if st != 200:
        ko(erreur_meta(t))
        info("si « does not exist » : assigner ce compte WhatsApp à "
             "l'utilisateur système (Paramètres Business → Utilisateurs "
             "système → Assigner des éléments)")
        return
    noms = [a.get("whatsapp_business_api_data", {}).get("name", "?")
            for a in json.loads(t).get("data", [])]
    if noms:
        ok("apps abonnées : " + ", ".join(noms))
    else:
        ko("aucune app abonnée : POST /<compte>/subscribed_apps avec le jeton")


def verifier_webhook(s):
    print("4. Webhook Supabase")
    q = urllib.parse.urlencode({"hub.mode": "subscribe",
                                "hub.verify_token": s["WHATSAPP_VERIFY_TOKEN"],
                                "hub.challenge": "rembo-42"})
    st, t = appel("GET", f"{WEBHOOK}?{q}")
    if st == 404:
        ko("fonction non déployée (supabase functions deploy whatsapp-webhook "
           "--no-verify-jwt)"); return
    if st == 401:
        ko("Supabase exige un JWT : redéployer avec --no-verify-jwt"); return
    if st == 403:
        ko("jeton de vérification refusé : WHATSAPP_VERIFY_TOKEN absent des "
           "secrets Supabase ou différent"); return
    if st == 200 and t == "rembo-42":
        ok("vérification Meta acceptée (même jeton des deux côtés)")
    else:
        ko(f"réponse inattendue {st} : {t[:200]}"); return
    st, t = appel("POST", WEBHOOK, corps={"entry": []})
    if st == 401 and "signature" in t:
        ok("les messages non signés sont refusés (secret de l'app présent)")
    else:
        ko(f"message non signé : réponse {st} {t[:120]} (attendu 401)")
    info("reste à vérifier dans Meta : WhatsApp → Configuration → webhook, "
         "champ « messages » abonné")


def main():
    s = lire_secrets()
    if verifier_numero(s) and "--envoyer" in sys.argv:
        i = sys.argv.index("--envoyer")
        dest = "".join(c for c in (sys.argv[i + 1] if i + 1 < len(sys.argv) else "")
                       if c.isdigit())
        if dest:
            envoyer(s, dest)
        else:
            ko("--envoyer attend un numéro, ex. 2126XXXXXXXX")
    if "--compte" in sys.argv:
        i = sys.argv.index("--compte")
        compte = sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        if compte.isdigit():
            verifier_compte(s, compte)
        else:
            ko("--compte attend l'identifiant du compte WhatsApp Business")
    verifier_webhook(s)


if __name__ == "__main__":
    main()
