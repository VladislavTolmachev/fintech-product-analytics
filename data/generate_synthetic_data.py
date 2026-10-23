#!/usr/bin/env python3
"""Generate deterministic synthetic CSVs for the fintech product analytics case."""
from pathlib import Path
import csv, random
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parent / "generated"
ROOT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(20261023)
START = datetime(2025, 1, 1)
SIGNUP_END = datetime(2026, 6, 30, 23, 59, 59)
DATA_END = datetime(2026, 9, 30, 23, 59, 59)
CHANNELS = ["paid_social", "organic_search", "referral", "affiliate", "direct"]

def rand_dt(a, b):
    return a + timedelta(seconds=RNG.randint(0, max(0, int((b-a).total_seconds()))))

def stamp(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if dt else ""

def write(name, header, rows):
    with (ROOT / name).open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)

users = []
meta = {}
for uid in range(1, 5001):
    signup = rand_dt(START, SIGNUP_END)
    channel = RNG.choices(CHANNELS, [.28, .24, .18, .16, .14])[0]
    country = RNG.choices(["MX", "CO", "BR", "AR"], [.55, .2, .15, .1])[0]
    users.append([uid, stamp(signup), channel, country])
    meta[uid] = {"signup": signup, "channel": channel}
write("users.csv", ["user_id", "signup_at", "acquisition_channel", "country_code"], users)

apps = []
appmeta = {}
aid = 1
for uid, m in meta.items():
    n = 0 if RNG.random() >= .61 else 1 + (1 if RNG.random() < .10 else 0)
    for _ in range(n):
        submitted = rand_dt(m["signup"] + timedelta(hours=1),
                           min(DATA_END, m["signup"] + timedelta(days=45)))
        if RNG.random() < .045 or submitted > DATA_END - timedelta(days=5):
            status, decision = "pending", None
        else:
            decision = submitted + timedelta(hours=RNG.randint(2, 120))
            if decision > DATA_END:
                status, decision = "pending", None
            else:
                status = "approved" if RNG.random() < .64 else "rejected"
        apps.append([aid, uid, stamp(submitted), stamp(decision), status])
        appmeta[aid] = {"user_id": uid, "decision": decision, "status": status}
        aid += 1
write("card_applications.csv",
      ["application_id", "user_id", "submitted_at", "decision_at", "application_status"], apps)

cards = []
cardmeta = {}
cid = 1
for aid, a in appmeta.items():
    if a["status"] != "approved" or RNG.random() > .86:
        continue
    issued = a["decision"] + timedelta(hours=RNG.randint(1, 120))
    if issued > DATA_END:
        continue
    activated = None
    if RNG.random() < .76:
        activated = issued + timedelta(hours=RNG.randint(3, 24 * 21))
        if activated > DATA_END:
            activated = None
    status = "issued" if activated is None else RNG.choices(
        ["active", "blocked", "closed"], [.88, .08, .04])[0]
    cards.append([cid, aid, stamp(issued), stamp(activated), status])
    cardmeta[cid] = {"activated": activated}
    cid += 1
write("cards.csv", ["card_id", "application_id", "issued_at", "activated_at", "card_status"], cards)

txs = []
tid = 1
for cid, c in cardmeta.items():
    if not c["activated"] or RNG.random() < .10:
        continue
    for _ in range(RNG.randint(1, 24)):
        txat = rand_dt(c["activated"], DATA_END)
        typ = RNG.choices(["purchase", "refund", "cash_withdrawal"], [.84, .08, .08])[0]
        status = RNG.choices(["completed", "declined", "reversed"], [.84, .11, .05])[0]
        txs.append([tid, cid, stamp(txat), f"{RNG.uniform(4, 650):.2f}", typ, status])
        tid += 1
write("transactions.csv",
      ["transaction_id", "card_id", "transaction_at", "amount", "transaction_type", "transaction_status"], txs)

events = []
eid = 1
event_names = ["app_open", "home_view", "card_screen_view", "transaction_history_view",
               "profile_view", "payment_attempt", "settings_view"]
for uid, m in meta.items():
    n = RNG.choices([0, 1, 2, 3, 4, 5], [.05, .10, .20, .28, .25, .12])[0]
    for sn in range(n):
        day = RNG.randint(0, max(0, (DATA_END - m["signup"]).days))
        eventtime = min(m["signup"] + timedelta(days=day, hours=RNG.randint(0, 23),
                                                minutes=RNG.randint(0, 59)), DATA_END)
        session = f"u{uid}_s{sn+1}"
        for _ in range(RNG.randint(2, 8)):
            et = min(eventtime + timedelta(minutes=RNG.randint(0, 35)), DATA_END)
            events.append([eid, uid, stamp(et), RNG.choice(event_names), session])
            eid += 1
write("user_events.csv", ["event_id", "user_id", "event_time", "event_name", "session_id"], events)
print(f"Generated {len(users):,} users, {len(apps):,} applications, {len(cards):,} cards, "
      f"{len(txs):,} transactions, {len(events):,} events in {ROOT}")
