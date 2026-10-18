"""Writes docs/results.js with made-up numbers in the same shape as R/07_export.R, so the report can be
developed and previewed before R is run. Every number here is fake and the report says so (meta.demo = true).
Run:  python3 tools/make_demo_data.py
"""
import json, math, random, os

random.seed(7)
ARMS = ["Placebo", "Xanomeline Low Dose", "Xanomeline High Dose"]
N = {"Placebo": 86, "Xanomeline Low Dose": 84, "Xanomeline High Dose": 84}
TOT = sum(N.values())


def npct(n, d):
    return f"{n} ({100 * n / d:.1f}%)" if d else "0"


def cont(label, mu, sd, d=1):
    rows = []
    vals = {a: [random.gauss(mu, sd) for _ in range(N[a])] for a in ARMS}
    allv = sum(vals.values(), [])
    def st(x):
        x = sorted(x); m = sum(x) / len(x); s = math.sqrt(sum((v - m) ** 2 for v in x) / (len(x) - 1))
        med = (x[len(x) // 2] + x[(len(x) - 1) // 2]) / 2
        return [str(len(x)), f"{m:.{d}f} ({s:.{d + 1}f})", f"{med:.{d}f}", f"{x[0]:.{d}f}, {x[-1]:.{d}f}"]
    cols = {a: st(vals[a]) for a in ARMS}; tot = st(allv)
    for i, s in enumerate(["n", "Mean (SD)", "Median", "Min, Max"]):
        rows.append({"section": label, "stat": s, "values": {**{a: cols[a][i] for a in ARMS}, "Total": tot[i]}})
    return rows


def cat(label, levels, probs):
    rows = []
    counts = {}
    for a in ARMS:
        left = N[a]; c = []
        for p in probs[:-1]:
            k = min(left, round(N[a] * p + random.randint(-3, 3))); c.append(max(k, 0)); left -= c[-1]
        c.append(left); counts[a] = c
    for i, l in enumerate(levels):
        t = sum(counts[a][i] for a in ARMS)
        rows.append({"section": label, "stat": l, "values": {**{a: npct(counts[a][i], N[a]) for a in ARMS}, "Total": npct(t, TOT)}})
    return rows


demog = (cont("Age (years)", 75, 8) + cat("Age group", ["<65", "65-80", ">80"], [.13, .55, .32])
         + cat("Sex", ["Female", "Male"], [.56, .44]) + cat("Race", ["Black or African American", "White", "American Indian or Alaska Native"], [.09, .9, .01])
         + cat("Ethnicity", ["Hispanic or Latino", "Not Hispanic or Latino"], [.05, .95])
         + cont("Baseline weight (kg)", 66, 14) + cont("Baseline BMI (kg/m²)", 24.5, 4))

reasons = ["Completed", "Adverse event", "Withdrawal by subject", "Lost to follow-up", "Physician decision", "Protocol violation", "Death"]
disposition = []
for a, comp in zip(ARMS, [.68, .29, .32]):
    left = N[a]; ks = [round(N[a] * comp)]
    left -= ks[0]
    share = [.0, .55, .25, .05, .07, .05, .03]
    for s in share[1:-1]:
        k = round(left * s); ks.append(k)
    ks.append(N[a] - sum(ks))
    for r, k in zip(reasons, ks):
        if k > 0:
            disposition.append({"ARM": a, "STATUS": r, "n": k, "pct": round(100 * k / N[a], 1)})

soc_pts = {
    "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS": ["APPLICATION SITE PRURITUS", "APPLICATION SITE ERYTHEMA", "APPLICATION SITE DERMATITIS", "APPLICATION SITE IRRITATION", "FATIGUE"],
    "SKIN AND SUBCUTANEOUS TISSUE DISORDERS": ["PRURITUS", "ERYTHEMA", "RASH", "HYPERHIDROSIS", "SKIN IRRITATION"],
    "NERVOUS SYSTEM DISORDERS": ["DIZZINESS", "HEADACHE", "SYNCOPE", "SOMNOLENCE"],
    "CARDIAC DISORDERS": ["SINUS BRADYCARDIA", "MYOCARDIAL INFARCTION", "ATRIAL FIBRILLATION"],
    "GASTROINTESTINAL DISORDERS": ["DIARRHOEA", "NAUSEA", "VOMITING", "ABDOMINAL PAIN"],
    "INFECTIONS AND INFESTATIONS": ["NASOPHARYNGITIS", "UPPER RESPIRATORY TRACT INFECTION", "URINARY TRACT INFECTION"],
    "PSYCHIATRIC DISORDERS": ["CONFUSIONAL STATE", "AGITATION", "INSOMNIA"],
    "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS": ["COUGH", "NASAL CONGESTION", "DYSPNOEA"],
}
drug_effect = {"APPLICATION SITE": 3.5, "PRURITUS": 2.5, "ERYTHEMA": 2.5, "RASH": 2, "DIZZINESS": 2.5, "SINUS BRADYCARDIA": 2.2, "HYPERHIDROSIS": 3, "SYNCOPE": 2}
ae_soc = []
for soc, pts in soc_pts.items():
    ptl = []
    for pt in pts:
        base = random.uniform(.02, .09)
        eff = next((v for k, v in drug_effect.items() if pt.startswith(k)), 1.0)
        n = {"Placebo": round(N["Placebo"] * base), "Xanomeline Low Dose": round(N["Xanomeline Low Dose"] * min(base * eff, .45)), "Xanomeline High Dose": round(N["Xanomeline High Dose"] * min(base * eff * 1.1, .5))}
        ptl.append({"pt": pt, "n": n, "pct": {a: round(100 * n[a] / N[a], 1) for a in ARMS}})
    ptl.sort(key=lambda p: -sum(p["n"].values()))
    sn = {a: min(N[a], round(max(p["n"][a] for p in ptl) * 1.6)) for a in ARMS}
    ae_soc.append({"soc": soc, "n": sn, "pct": {a: round(100 * sn[a] / N[a], 1) for a in ARMS}, "pts": ptl})
ae_soc.sort(key=lambda s: -sum(s["n"].values()))


def ov(label, p):
    n = {a: round(N[a] * p[i]) for i, a in enumerate(ARMS)}
    return {"label": label, "n": n, "pct": {a: round(100 * n[a] / N[a], 1) for a in ARMS}}


ae_overview = [ov("Any treatment-emergent adverse event", [.76, .93, .94]), ov("Related (possible or probable)", [.34, .8, .82]),
               ov("Severe", [.05, .12, .11]), ov("Serious", [.02, .02, .03]), ov("Left the study because of an adverse event", [.09, .37, .36]),
               ov("Dermatologic (skin or application site)", [.29, .74, .73])]

vs_params = {"SYSBP": "Systolic blood pressure (mmHg)", "DIABP": "Diastolic blood pressure (mmHg)", "PULSE": "Pulse rate (beats/min)", "WEIGHT": "Weight (kg)"}
vs = []
weeks = [2, 4, 6, 8, 12, 16, 20, 24, 26]
for pc, pl in vs_params.items():
    for i, a in enumerate(ARMS):
        drift = {"SYSBP": [-1, -2, -2.5], "DIABP": [-.5, -1, -1.2], "PULSE": [0, -1.5, -2.2], "WEIGHT": [0, -.6, -.9]}[pc][i]
        n0 = N[a]
        for w in weeks:
            n = max(5, round(n0 * (1 - (.004 if i == 0 else .022) * w)))
            vs.append({"PARAMCD": pc, "PARAM": pl, "TRT01A": a, "AVISITN": w, "n": n,
                       "mean": round(drift * w / 26 + random.gauss(0, .6), 2), "se": round(random.uniform(.6, 1.6) * (1 if pc != "WEIGHT" else .25), 2)})

lb_tests = {"ALT": "Alanine aminotransferase", "AST": "Aspartate aminotransferase", "BILI": "Bilirubin", "CREAT": "Creatinine",
            "GLUC": "Glucose", "CHOL": "Cholesterol", "HGB": "Haemoglobin", "WBC": "Leukocytes"}
cats = ["LOW", "NORMAL", "HIGH"]
lab_shift = []
for tc, lab in lb_tests.items():
    arms = {}
    for a in ARMS:
        n = round(N[a] * .9)
        m = {b: {w: 0 for w in cats} for b in cats}
        for _ in range(n):
            b = random.choices(cats, [.05, .85, .1])[0]
            w = b if random.random() < .75 else random.choices(cats, [.15, .55, .3])[0]
            m[b][w] += 1
        arms[a] = m
    lab_shift.append({"test": tc, "label": lab, "arms": arms})

km = []
events, med = {}, {}
for a, h in zip(ARMS, [.0018, .0105, .0115]):
    t, s, nr = [0], [1.0], [N[a]]
    ev, ce = [0], [0]
    at_risk = N[a]; surv = 1.0; e_tot = 0
    for d in range(1, 211, 3):
        if at_risk <= 0:
            break
        e = sum(1 for _ in range(at_risk) if random.random() < h * 3)
        c = sum(1 for _ in range(at_risk - e) if random.random() < (.004 if a == "Placebo" else .012))
        if d > 180:
            c = at_risk - e
        if e or c:
            surv *= (1 - e / at_risk)
            t.append(d); s.append(round(surv, 4)); nr.append(at_risk); ev.append(e); ce.append(c)
            at_risk -= e + c; e_tot += e
    se = [0] + [0.03 + 0.1 * (1 - v) * .4 for v in s[1:]]
    km.append({"arm": a, "time": t, "surv": s, "lower": [round(max(0, v - q), 4) for v, q in zip(s, se)],
               "upper": [round(min(1, v + q), 4) for v, q in zip(s, se)], "nrisk": nr, "event": ev, "censor": ce})
    events[a] = e_tot
    med[a] = next((tt for tt, ss in zip(t, s) if ss <= .5), None)
tte = {"km": km, "logrank_p": 1.2e-15, "events": events, "median": med,
       "hr": [{"arm": "Xanomeline Low Dose", "hr": 4.9, "lo": 3.1, "hi": 7.7, "p": 3.1e-12},
              {"arm": "Xanomeline High Dose", "hr": 5.6, "lo": 3.6, "hi": 8.8, "p": 2.2e-14}]}

sql = [
    {"title": "Safety population by arm", "why": "Head count, age and time on treatment in one pass.",
     "sql": "SELECT TRT01A AS arm,\n       COUNT(*) AS subjects,\n       ROUND(AVG(AGE), 1) AS mean_age,\n       ROUND(AVG(TRTDURD), 1) AS mean_days_on_treatment\nFROM adsl\nWHERE SAFFL = 'Y'\nGROUP BY TRT01A\nORDER BY arm",
     "cols": ["arm", "subjects", "mean_age", "mean_days_on_treatment"],
     "rows": [["Placebo", "86", "75.2", "149.1"], ["Xanomeline High Dose", "84", "74.4", "99.4"], ["Xanomeline Low Dose", "84", "75.7", "98.7"]]},
    {"title": "Ten most common adverse events", "why": "Counts subjects, not events.",
     "sql": "SELECT AEDECOD AS preferred_term,\n       COUNT(DISTINCT USUBJID) AS subjects\nFROM adae\nWHERE TRTEMFL = 'Y'\nGROUP BY AEDECOD\nORDER BY subjects DESC, preferred_term\nLIMIT 10",
     "cols": ["preferred_term", "subjects"], "rows": sorted([[p["pt"], str(sum(p["n"].values()))] for s in ae_soc for p in s["pts"]], key=lambda r: -int(r[1]))[:10]},
]

checks = ["ADSL has one row per subject", "Every safety subject has a first dose date", "Every ADTTE subject has a time and a censoring date", "First dose is never after last dose",
          "Everyone in the safety population was randomised", "Every ADAE subject is in the safety population",
          "No treatment-emergent event starts before the first dose", "ADTTE times are positive", "ADTTE censoring flag is 0 or 1",
          "ADTTE has one row per safety subject", "Vital-sign change equals value minus baseline"]
qc = {
    "notes": [],
    "adsl_vars": [{"dataset": "ADSL", "variable": v, "compared": 306, "mismatches": 0, "example": None} for v in ["TRTSDT", "TRTEDT", "TRTDURD", "SAFFL", "ITTFL", "AGEGR1"]],
    "diffdf_issues": False,
    "teae": [{"arm": a, "production": ae_overview[0]["n"][a], "qc": ae_overview[0]["n"][a], "sql": ae_overview[0]["n"][a], "records_production": 300, "records_qc": 300} for a in ARMS],
    "pt": {"cells": 540, "mismatches": 0},
    "checks": [{"check": c, "pass": True} for c in checks],
    "tests": [{"test": t, "expectations": e, "passed": e, "failed": 0} for t, e in [("age groups follow the pilot cut-offs", 1), ("treatment-emergent window includes first dose and last dose + 30 days", 2), ("reference-range indicator handles missing limits", 1), ("worst category puts HIGH above LOW above NORMAL", 3), ("time to event uses day 1 for first dose and censors after the window", 2), ("partial dates are imputed to the first", 1), ("n (%) text", 2)]],
    "reference": [{"variable": v, "compared": 306, "agree_pct": p} for v, p in [("TRTSDT", 100.0), ("TRTEDT", 98.4), ("TRTDURD", 98.4), ("SAFFL", 100.0), ("EOSSTT", 83.0)]],
}


def read_spec(path):
    import csv
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
specs = {os.path.basename(p).split("_")[0].upper(): read_spec(os.path.join(root, "specs", p)) for p in sorted(os.listdir(os.path.join(root, "specs"))) if p.endswith("_spec.csv")}

TRIAL = {
    "meta": {"demo": True, "generated": "demo data", "r": "not run yet", "packages": {}, "study": "CDISCPILOT01"},
    "sdtm": {"DM": 306, "EX": 591, "DS": 850, "AE": 1191, "VS": 29643, "LB": 59580},
    "adam": {"ADSL": 306, "ADAE": 1191, "ADVS": 7600, "ADLB": 21000, "ADTTE": 254},
    "arms": ARMS,
    "pops": {"screened": 306, "screen_failures": 52, "randomised": N, "safety": N,
             "completed": {a: next(d["n"] for d in disposition if d["ARM"] == a and d["STATUS"] == "Completed") for a in ARMS}, "switched": 0, "no_last_dose": 0},
    "demog": demog, "disposition": disposition, "ae_overview": ae_overview, "ae_soc": ae_soc, "vs": vs,
    "vs_params": vs_params, "lab_shift": lab_shift, "tte": tte, "sql": sql, "qc": qc, "specs": specs,
}
out = os.path.join(root, "docs", "results.js")
with open(out, "w") as f:
    f.write("window.TRIAL = " + json.dumps(TRIAL) + ";\n")
print("wrote", out, os.path.getsize(out) // 1024, "KB")
