(function () {
  "use strict";
  const T = window.TRIAL;
  if (!T) { document.querySelector("main").innerHTML = "<section><h2>No results yet</h2><p>docs/results.js is missing. Run run_all.R in R, or python3 tools/make_demo_data.py for demo numbers.</p></section>"; return; }

  const ARMS = T.arms;
  const SHORT = { "Placebo": "Placebo", "Xanomeline Low Dose": "Low dose", "Xanomeline High Dose": "High dose" };
  const short = a => SHORT[a] || a;
  const $ = s => document.querySelector(s);
  const esc = s => String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const title = s => String(s).toLowerCase().replace(/(^|[\s,(/-])([a-z])/g, (m, p, c) => p + c.toUpperCase()).replace(/\b(And|Of|Or|In|To|By)\b/g, w => w.toLowerCase());
  const sentence = s => { s = String(s).toLowerCase(); return s.charAt(0).toUpperCase() + s.slice(1); };
  const sum = a => a.reduce((x, y) => x + (+y || 0), 0);
  const N = a => T.pops.safety[a];
  const pfmt = p => p == null ? "–" : p < 0.0001 ? "p < 0.0001" : p < 0.001 ? "p = " + p.toExponential(1) : "p = " + p.toFixed(3);

  // colours are read from CSS so charts follow the theme and still export as standalone SVG
  let K;
  function readColours() {
    const s = getComputedStyle(document.documentElement), g = n => s.getPropertyValue(n).trim();
    K = { pbo: g("--pbo"), lo: g("--lo"), hi: g("--hi"), ink: g("--ink"), muted: g("--muted"), grid: g("--grid"), line: g("--line"), bg: g("--surface"), accent: g("--accent"), ok: g("--ok"), bad: g("--bad") };
  }
  const armCol = a => a === ARMS[0] ? K.pbo : a === ARMS[1] ? K.lo : K.hi;
  const swatch = a => `<span class="sw" style="background:${armCol(a)}"></span>`;

  function ticks(lo, hi, n) {
    n = n || 5; const span = (hi - lo) || 1, raw = span / n, mag = Math.pow(10, Math.floor(Math.log10(raw))), e = raw / mag;
    const step = (e >= 7.5 ? 10 : e >= 3.5 ? 5 : e >= 1.5 ? 2 : 1) * mag, t = [];
    const end = Math.ceil(hi / step - 1e-9) * step;
    for (let v = Math.floor(lo / step + 1e-9) * step; v <= end + 1e-9; v += step) t.push(+v.toFixed(10));
    return t;
  }
  const lin = (d0, d1, r0, r1) => v => r0 + (v - d0) / ((d1 - d0) || 1) * (r1 - r0);
  const svgOpen = (w, h, label) => `<svg viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${esc(label)}" font-family="Inter, system-ui, sans-serif" font-size="12"><rect width="${w}" height="${h}" fill="${K.bg}"/>`;
  const txt = (x, y, s, o) => { o = o || {}; return `<text x="${x}" y="${y}" fill="${o.fill || K.muted}" text-anchor="${o.anchor || "start"}"${o.weight ? ` font-weight="${o.weight}"` : ""}${o.size ? ` font-size="${o.size}"` : ""}>${esc(s)}</text>`; };
  const legendSvg = (x, y, items) => { let out = "", cx = x; items.forEach(([lab, col]) => { out += `<rect x="${cx}" y="${y - 9}" width="10" height="10" rx="2" fill="${col}"/>` + txt(cx + 15, y, lab, { fill: K.ink }); cx += 24 + lab.length * 6.6; }); return out; };

  // ---- downloads -------------------------------------------------------------------------------------------------
  function save(name, blob) { const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = name; document.body.appendChild(a); a.click(); setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500); }
  function toCSV(rows) { return rows.map(r => r.map(v => { v = v == null ? "" : String(v); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }).join(",")).join("\n"); }
  function saveCSV(name, rows) { save(name + ".csv", new Blob([toCSV(rows)], { type: "text/csv" })); }
  function chart(id, name, svg) {
    const fig = document.getElementById(id);
    fig.innerHTML = svg + `<div class="dl"><button data-f="svg">SVG</button><button data-f="png">PNG</button></div>`;
    const el = fig.querySelector("svg");
    fig.querySelector('[data-f="svg"]').onclick = () => save(name + ".svg", new Blob([new XMLSerializer().serializeToString(el)], { type: "image/svg+xml" }));
    fig.querySelector('[data-f="png"]').onclick = () => {
      const vb = el.viewBox.baseVal, img = new Image(), sc = 2;
      img.onload = () => { const c = document.createElement("canvas"); c.width = vb.width * sc; c.height = vb.height * sc; const x = c.getContext("2d"); x.drawImage(img, 0, 0, c.width, c.height); c.toBlob(b => save(name + ".png", b)); };
      img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(new XMLSerializer().serializeToString(el));
    };
  }

  // ---- header, banner, software ------------------------------------------------------------------------------------
  $("#generated").textContent = T.meta.demo ? "demo data" : "results generated " + T.meta.generated;
  if (T.meta.demo) { const b = $("#banner"); b.hidden = false; b.textContent = "Demo numbers. Run run_all.R in R to replace them with the real analysis of the CDISC pilot data."; }
  const pk = Object.entries(T.meta.packages || {}).filter(([, v]) => v).map(([k, v]) => `${k} ${v}`);
  $("#software").textContent = T.meta.demo ? "Filled in when the analysis is run in R." : [T.meta.r].concat(pk).join(" · ");

  // ---- at a glance -----------------------------------------------------------------------------------------------
  function renderKpis() {
    const rand = sum(ARMS.map(a => T.pops.randomised[a])), saf = sum(ARMS.map(N));
    const any = T.ae_overview[0], derm = T.ae_overview.find(r => /Dermatologic/.test(r.label)) || T.ae_overview[T.ae_overview.length - 1];
    const comp = a => Math.round(100 * T.pops.completed[a] / T.pops.randomised[a]);
    const armline = f => `<div class="arms">${ARMS.map(a => `<span>${swatch(a)}${f(a)}</span>`).join("")}</div>`;
    const hrHi = (T.tte.hr || []).find(h => /High/.test(h.arm));
    $("#kpis").innerHTML = [
      `<div class="kpi"><div class="v">${T.pops.screened}</div><div class="l">screened, ${rand} randomised</div></div>`,
      `<div class="kpi"><div class="v">${saf}</div><div class="l">in the safety population</div>${armline(a => N(a))}</div>`,
      `<div class="kpi"><div class="l">completed the study</div>${armline(a => comp(a) + "%")}</div>`,
      `<div class="kpi"><div class="l">any treatment-emergent adverse event</div>${armline(a => any.pct[a] + "%")}</div>`,
      `<div class="kpi"><div class="l">dermatologic event</div>${armline(a => derm.pct[a] + "%")}</div>`,
      hrHi ? `<div class="kpi"><div class="v">${hrHi.hr.toFixed(1)}×</div><div class="l">hazard of a skin event, high dose vs placebo (95% CI ${hrHi.lo.toFixed(1)}–${hrHi.hi.toFixed(1)})</div></div>` : ""
    ].join("");
    const wd = T.ae_overview.find(r => /because of an adverse event|withdrawal/.test(r.label));
    const lines = [];
    lines.push(`Completion was ${comp(ARMS[0])}% on placebo against ${comp(ARMS[1])}% and ${comp(ARMS[2])}% on the low and high dose: most subjects on xanomeline left the study early.`);
    if (wd) lines.push(`${wd.pct[ARMS[2]]}% of high-dose and ${wd.pct[ARMS[1]]}% of low-dose subjects left the study because of an adverse event, against ${wd.pct[ARMS[0]]}% on placebo.`);
    lines.push(`Skin and application-site reactions drive the difference: ${derm.pct[ARMS[2]]}% (high dose) and ${derm.pct[ARMS[1]]}% (low dose) against ${derm.pct[ARMS[0]]}% on placebo.`);
    $("#takeaways").innerHTML = lines.map(l => `<p>${esc(l)}</p>`).join("");
  }

  // ---- pipeline -----------------------------------------------------------------------------------------------------
  function renderPipe() {
    const desc = { DM: "demographics", EX: "exposure", DS: "disposition", AE: "adverse events", VS: "vital signs", LB: "laboratory",
      ADSL: "one row per subject", ADAE: "adverse events", ADVS: "vital signs", ADLB: "laboratory", ADTTE: "time to event" };
    const items = o => Object.entries(o).map(([k, v]) => `<div class="item"><b>${k}</b><span>${esc(desc[k] || "")} · ${(+v).toLocaleString()}</span></div>`).join("");
    const outs = ["Demographics table", "Disposition", "AE tables by SOC/PT", "Vital-sign change", "Lab shift tables", "Kaplan–Meier + Cox", "SQL queries"];
    $("#pipe").innerHTML = `<div class="col"><h4>SDTM (raw, pharmaversesdtm)</h4>${items(T.sdtm)}</div><div class="arrow">→</div>
      <div class="col"><h4>ADaM (admiral)</h4>${items(T.adam)}</div><div class="arrow">→</div>
      <div class="col"><h4>Tables, listings, figures</h4>${outs.map(o => `<div class="item"><b style="font-family:inherit">${o}</b></div>`).join("")}</div>
      <div class="qcbar">Independent base-R rebuild from SDTM · diffdf comparison · structural checks · testthat unit tests</div>`;
  }

  // ---- study flow ------------------------------------------------------------------------------------------------------
  function renderConsort() {
    const rand = sum(ARMS.map(a => T.pops.randomised[a]));
    const disc = a => T.pops.randomised[a] - T.pops.completed[a];
    $("#consort").innerHTML = `<div class="split"><div class="box"><b>${T.pops.screened}</b>screened</div><div class="box side"><b>${T.pops.screen_failures}</b>screen failures</div></div>
      <div class="down">↓</div><div class="box"><b>${rand}</b>randomised</div><div class="down">↓</div>
      <div class="row">${ARMS.map(a => `<div class="box" style="border-top-color:${armCol(a)}"><div>${esc(a)}</div><b>${T.pops.randomised[a]}</b>randomised<br>
        <span class="small">${N(a)} treated with ${esc(short(a).toLowerCase())}</span><br><span class="small">${T.pops.completed[a]} completed · ${disc(a)} discontinued</span></div>`).join("")}</div>` +
      (T.pops.switched ? `<p class="small" style="text-align:center;margin:4px 0 0">${T.pops.switched} subjects received a different dose from the one they were randomised to, so "treated" counts follow the treatment actually received.</p>` : "");
  }

  // ---- demographics -----------------------------------------------------------------------------------------------------
  function renderDemog() {
    let h = `<thead><tr><th></th>${ARMS.map(a => `<th class="num">${swatch(a)}${esc(short(a))}<br><span style="text-transform:none">N = ${N(a)}</span></th>`).join("")}<th class="num">Total<br><span style="text-transform:none">N = ${sum(ARMS.map(N))}</span></th></tr></thead><tbody>`;
    let last = "";
    T.demog.forEach(r => {
      if (r.section !== last) { h += `<tr class="sec"><td colspan="${ARMS.length + 2}">${esc(r.section)}</td></tr>`; last = r.section; }
      h += `<tr><td class="ind">${esc(r.stat)}</td>${ARMS.concat("Total").map(a => `<td class="num">${esc(r.values[a])}</td>`).join("")}</tr>`;
    });
    $("#t-demog").innerHTML = h + "</tbody>";
  }

  // ---- disposition ---------------------------------------------------------------------------------------------------------
  function renderDisp() {
    const reasons = []; T.disposition.forEach(d => { if (!reasons.includes(d.STATUS)) reasons.push(d.STATUS); });
    reasons.sort((a, b) => (a === "Completed" ? -1 : b === "Completed" ? 1 : sum(T.disposition.filter(d => d.STATUS === b).map(d => d.n)) - sum(T.disposition.filter(d => d.STATUS === a).map(d => d.n))));
    const pal = [K.ok, "#c2410c", "#7c3aed", "#0891b2", "#be185d", "#4d7c0f", "#a16207", "#475569", "#9f1239", "#155e75"];
    const col = r => pal[reasons.indexOf(r) % pal.length];
    const W = 900, rowH = 34, right = 20, left = 110, legRows = (() => { let lx = left, r = 1; reasons.forEach(z => { const w = 28 + z.length * 6.4; if (lx + w > W - right) { lx = left; r++; } lx += w; }); return r; })(), top = 18 + legRows * 18, H = top + ARMS.length * (rowH + 12) + 30;
    const x = lin(0, 100, left, W - right);
    let s = svgOpen(W, H, "Disposition by arm");
    ticks(0, 100, 5).forEach(t => { s += `<line x1="${x(t)}" x2="${x(t)}" y1="${top - 6}" y2="${H - 28}" stroke="${K.grid}"/>` + txt(x(t), H - 12, t + "%", { anchor: "middle" }); });
    ARMS.forEach((a, i) => {
      const y = top + i * (rowH + 12); let acc = 0;
      s += txt(left - 8, y + rowH / 2 + 4, short(a), { anchor: "end", fill: K.ink, weight: 600 });
      reasons.forEach(r => {
        const d = T.disposition.find(z => z.ARM === a && z.STATUS === r); if (!d) return;
        const w = x(acc + d.pct) - x(acc);
        s += `<rect x="${x(acc)}" y="${y}" width="${Math.max(0, w - 1)}" height="${rowH}" fill="${col(r)}"><title>${esc(a)} · ${esc(r)}: ${d.n} (${d.pct}%)</title></rect>`;
        if (w > 34) s += txt(x(acc) + w / 2, y + rowH / 2 + 4, Math.round(d.pct) + "%", { anchor: "middle", fill: "#fff", weight: 600 });
        acc += d.pct;
      });
    });
    let lx = left, ly = 14; reasons.forEach(r => { const w = 28 + r.length * 6.4; if (lx + w > W - right) { lx = left; ly += 18; } s += `<rect x="${lx}" y="${ly - 9}" width="10" height="10" rx="2" fill="${col(r)}"/>` + txt(lx + 14, ly, r, { fill: K.ink }); lx += w; });
    chart("c-disp", "disposition", s + "</svg>");
    let h = `<thead><tr><th>Status</th>${ARMS.map(a => `<th class="num">${esc(short(a))} (N = ${T.pops.randomised[a]})</th>`).join("")}</tr></thead><tbody>`;
    reasons.forEach(r => { h += `<tr><td><span class="sw" style="background:${col(r)}"></span>${esc(r)}</td>${ARMS.map(a => { const d = T.disposition.find(z => z.ARM === a && z.STATUS === r); return `<td class="num">${d ? `${d.n} (${d.pct.toFixed(1)}%)` : "0"}</td>`; }).join("")}</tr>`; });
    $("#t-disp").innerHTML = h + "</tbody>";
  }

  // ---- adverse events --------------------------------------------------------------------------------------------------------
  const np = (o, a) => `${o.n[a]} (${(+o.pct[a]).toFixed(1)}%)`;
  function renderAeOverview() {
    let h = `<thead><tr><th>Subjects with at least one…</th>${ARMS.map(a => `<th class="num">${swatch(a)}${esc(short(a))} (N = ${N(a)})</th>`).join("")}</tr></thead><tbody>`;
    T.ae_overview.forEach(r => { h += `<tr><td>${esc(r.label)}</td>${ARMS.map(a => `<td class="num">${np(r, a)}</td>`).join("")}</tr>`; });
    $("#t-aeov").innerHTML = h + "</tbody>";
  }
  function renderDots() {
    const pts = []; T.ae_soc.forEach(s => s.pts.forEach(p => pts.push(p)));
    pts.sort((a, b) => Math.max(...ARMS.map(x => b.pct[x])) - Math.max(...ARMS.map(x => a.pct[x])));
    const top = pts.slice(0, 15);
    const W = 900, left = 250, right = 30, rowH = 24, t0 = 40, H = t0 + top.length * rowH + 34;
    const mx = Math.max(5, ...top.map(p => Math.max(...ARMS.map(a => p.pct[a]))));
    const tk = ticks(0, mx, 6), x = lin(0, tk[tk.length - 1], left, W - right);
    let s = svgOpen(W, H, "Most common adverse events by arm");
    s += legendSvg(left, 16, ARMS.map(a => [short(a), armCol(a)]));
    tk.forEach(t => { s += `<line x1="${x(t)}" x2="${x(t)}" y1="${t0 - 8}" y2="${H - 26}" stroke="${K.grid}"/>` + txt(x(t), H - 10, t + "%", { anchor: "middle" }); });
    top.forEach((p, i) => {
      const y = t0 + i * rowH + rowH / 2, vals = ARMS.map(a => p.pct[a]);
      s += txt(left - 10, y + 4, title(p.pt), { anchor: "end", fill: K.ink });
      s += `<line x1="${x(Math.min(...vals))}" x2="${x(Math.max(...vals))}" y1="${y}" y2="${y}" stroke="${K.line}" stroke-width="3"/>`;
      ARMS.forEach(a => { s += `<circle cx="${x(p.pct[a])}" cy="${y}" r="6" fill="${armCol(a)}" stroke="${K.bg}" stroke-width="1.5"><title>${esc(title(p.pt))} · ${esc(short(a))}: ${p.n[a]} (${p.pct[a]}%)</title></circle>`; });
    });
    chart("c-dots", "top-adverse-events", s + "</svg>");
  }
  const aeState = { q: "", min: 5, sort: "total", open: new Set(), all: false };
  function renderAeTable() {
    const mxp = o => Math.max(...ARMS.map(a => +o.pct[a]));
    const key = o => aeState.sort === "total" ? -sum(ARMS.map(a => o.n[a])) : aeState.sort === "diff" ? -(o.pct[ARMS[2]] - o.pct[ARMS[0]]) : 0;
    const q = aeState.q.toLowerCase();
    let socs = T.ae_soc.map(s => ({ s, pts: s.pts.filter(p => mxp(p) >= aeState.min && (!q || p.pt.toLowerCase().includes(q) || s.soc.toLowerCase().includes(q))) }))
      .filter(x => x.pts.length);
    if (aeState.sort === "alpha") socs.sort((a, b) => a.s.soc.localeCompare(b.s.soc)); else socs.sort((a, b) => key(a.s) - key(b.s));
    const cell = (o, a) => `<td class="num">${np(o, a)}<span class="bar" style="width:${Math.round(+o.pct[a] * 0.6)}px;background:${armCol(a)}"></span></td>`;
    let h = `<thead><tr><th>Body system / preferred term</th>${ARMS.map(a => `<th class="num">${swatch(a)}${esc(short(a))} (N = ${N(a)})</th>`).join("")}</tr></thead><tbody>`;
    socs.forEach(({ s, pts }) => {
      const open = aeState.all || aeState.open.has(s.soc) || !!q;
      if (aeState.sort === "alpha") pts = pts.slice().sort((a, b) => a.pt.localeCompare(b.pt)); else pts = pts.slice().sort((a, b) => key(a) - key(b));
      h += `<tr class="soc sec${open ? " open" : ""}" data-soc="${esc(s.soc)}"><td>${esc(title(s.soc))} <span class="small">(${pts.length})</span></td>${ARMS.map(a => cell(s, a)).join("")}</tr>`;
      pts.forEach(p => { h += `<tr class="pt${open ? "" : " hide"}"><td>${esc(title(p.pt))}</td>${ARMS.map(a => cell(p, a)).join("")}</tr>`; });
    });
    if (!socs.length) h += `<tr><td colspan="4" class="small">No events match.</td></tr>`;
    $("#t-ae").innerHTML = h + "</tbody>";
    $("#t-ae").querySelectorAll("tr.soc").forEach(tr => tr.onclick = () => { const k = tr.dataset.soc; aeState.open.has(k) ? aeState.open.delete(k) : aeState.open.add(k); aeState.all = false; renderAeTable(); });
  }
  $("#ae-search").oninput = e => { aeState.q = e.target.value.trim(); renderAeTable(); };
  $("#ae-min").onchange = e => { aeState.min = +e.target.value; renderAeTable(); };
  $("#ae-sort").onchange = e => { aeState.sort = e.target.value; renderAeTable(); };
  $("#ae-expand").onclick = () => { aeState.all = !aeState.all; aeState.open.clear(); $("#ae-expand").textContent = aeState.all ? "Collapse all" : "Expand all"; renderAeTable(); };

  // ---- vital signs ---------------------------------------------------------------------------------------------------------
  const vsSel = $("#vs-param");
  vsSel.innerHTML = Object.entries(T.vs_params).map(([k, v]) => `<option value="${k}">${esc(v)}</option>`).join("");
  vsSel.onchange = renderVs;
  function renderVs() {
    const pc = vsSel.value, d = T.vs.filter(r => r.PARAMCD === pc), lab = T.vs_params[pc];
    const weeks = [0].concat([...new Set(d.map(r => r.AVISITN))].sort((a, b) => a - b));
    const W = 900, H = 380, L = 64, R = 24, Tp = 40, B = 46;
    const lo = Math.min(0, ...d.map(r => r.mean - (r.se || 0))), hi = Math.max(0, ...d.map(r => r.mean + (r.se || 0)));
    const pad = (hi - lo) * 0.08 || 1, yt = ticks(lo - pad, hi + pad, 6);
    const x = lin(0, weeks[weeks.length - 1], L, W - R), y = lin(yt[0], yt[yt.length - 1], H - B, Tp);
    let s = svgOpen(W, H, "Mean change from baseline: " + lab);
    s += legendSvg(L, 18, ARMS.map(a => [short(a), armCol(a)]));
    yt.forEach(t => { s += `<line x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}" stroke="${t === 0 ? K.muted : K.grid}"${t === 0 ? ' stroke-dasharray="4 3"' : ""}/>` + txt(L - 8, y(t) + 4, t, { anchor: "end" }); });
    weeks.forEach(w => { s += txt(x(w), H - B + 18, w === 0 ? "Base" : "Wk " + w, { anchor: "middle" }); });
    s += txt(L, H - 6, "Change from baseline: " + lab, { fill: K.muted });
    ARMS.forEach((a, i) => {
      const off = (i - 1) * 5, r = [{ AVISITN: 0, mean: 0, se: 0, n: N(a) }].concat(d.filter(z => z.TRT01A === a).sort((p, q) => p.AVISITN - q.AVISITN));
      s += `<polyline fill="none" stroke="${armCol(a)}" stroke-width="2.2" points="${r.map(z => `${x(z.AVISITN) + off},${y(z.mean)}`).join(" ")}"/>`;
      r.forEach(z => {
        if (z.se) s += `<line x1="${x(z.AVISITN) + off}" x2="${x(z.AVISITN) + off}" y1="${y(z.mean - z.se)}" y2="${y(z.mean + z.se)}" stroke="${armCol(a)}" stroke-width="1.4"/>`;
        s += `<circle cx="${x(z.AVISITN) + off}" cy="${y(z.mean)}" r="3.6" fill="${armCol(a)}"><title>${esc(short(a))}, ${z.AVISITN ? "week " + z.AVISITN : "baseline"}: ${z.mean} ± ${z.se} (n = ${z.n})</title></circle>`;
      });
    });
    chart("c-vs", "vital-signs-" + pc.toLowerCase(), s + "</svg>");
  }

  // ---- laboratory shifts -------------------------------------------------------------------------------------------------------
  const labSel = $("#lab-test");
  labSel.innerHTML = T.lab_shift.map(l => `<option value="${l.test}">${esc(l.label)} (${l.test})</option>`).join("");
  labSel.onchange = renderLab;
  function renderLab() {
    const L = T.lab_shift.find(l => l.test === labSel.value), cats = ["LOW", "NORMAL", "HIGH"];
    $("#c-lab").innerHTML = ARMS.map(a => {
      const m = L.arms[a], tot = sum(cats.map(b => sum(cats.map(w => m[b][w]))));
      const mx = Math.max(1, ...cats.flatMap(b => cats.map(w => m[b][w])));
      return `<div class="shift"><h4>${swatch(a)}${esc(a)} <span class="small">(n = ${tot})</span></h4><table><thead><tr><th>Baseline ↓ / Worst →</th>${cats.map(c => `<th>${c}</th>`).join("")}</tr></thead><tbody>
        ${cats.map(b => `<tr><th>${b}</th>${cats.map(w => { const v = m[b][w], al = v ? 0.12 + 0.6 * v / mx : 0; return `<td class="${b === w ? "diag" : ""}" style="background:color-mix(in srgb, ${armCol(a)} ${Math.round(al * 100)}%, transparent)">${v}</td>`; }).join("")}</tr>`).join("")}</tbody></table></div>`;
    }).join("");
    const pct = (a, to) => { const m = L.arms[a], n = sum(cats.map(w => m.NORMAL[w])); return n ? Math.round(100 * m.NORMAL[to] / n) : 0; };
    $("#lab-sum").textContent = `Normal at baseline, then high at least once: ` + ARMS.map(a => `${short(a)} ${pct(a, "HIGH")}%`).join(" · ") + `. Then low at least once: ` + ARMS.map(a => `${short(a)} ${pct(a, "LOW")}%`).join(" · ") + ".";
  }

  // ---- time to event -------------------------------------------------------------------------------------------------------------
  function riskAt(k, t) { if (t <= 0) return k.nrisk[0]; for (let i = 1; i < k.time.length; i++) if (k.time[i] >= t) return k.nrisk[i]; return 0; }
  function renderKm() {
    const ci = $("#km-ci").checked, cum = $("#km-cum").checked;
    const tmax = Math.max(...T.tte.km.map(k => k.time[k.time.length - 1]));
    const xt = ticks(0, tmax, 7), W = 900, L = 96, R = 24, Tp = 40, plotB = 330, H = plotB + 46 + 22 * ARMS.length + 26;
    const x = lin(0, xt[xt.length - 1], L, W - R), y = lin(0, 1, plotB, Tp);
    const f = v => cum ? 1 - v : v;
    let s = svgOpen(W, H, "Kaplan-Meier: time to first dermatologic event");
    s += legendSvg(L, 18, ARMS.map(a => [short(a), armCol(a)]));
    [0, .25, .5, .75, 1].forEach(t => { s += `<line x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}" stroke="${K.grid}"/>` + txt(L - 8, y(t) + 4, Math.round(t * 100) + "%", { anchor: "end" }); });
    xt.forEach(t => { s += `<line x1="${x(t)}" x2="${x(t)}" y1="${Tp}" y2="${plotB}" stroke="${K.grid}"/>` + txt(x(t), plotB + 18, t, { anchor: "middle" }); });
    s += txt((L + W - R) / 2, plotB + 36, "Days since first dose", { anchor: "middle" });
    s += `<text transform="translate(16 ${(Tp + plotB) / 2}) rotate(-90)" fill="${K.muted}" text-anchor="middle">${cum ? "Had a skin event" : "Free of skin events"}</text>`;
    T.tte.km.forEach(k => {
      const c = armCol(k.arm);
      const path = (vals) => { let p = `M${x(0)},${y(f(vals[0]))}`; for (let i = 1; i < k.time.length; i++) p += `H${x(k.time[i])}V${y(f(vals[i]))}`; return p + `H${x(k.time[k.time.length - 1])}`; };
      if (ci) {
        const n = k.time.length, nx = i => x(i + 1 < n ? k.time[i + 1] : k.time[n - 1]);
        const val = (arr, i) => f(arr[i] == null ? k.surv[i] : arr[i]);
        const up = [], dn = [];
        for (let i = 0; i < n; i++) up.push(`${x(k.time[i])},${y(val(k.upper, i))}`, `${nx(i)},${y(val(k.upper, i))}`);
        for (let i = n - 1; i >= 0; i--) dn.push(`${nx(i)},${y(val(k.lower, i))}`, `${x(k.time[i])},${y(val(k.lower, i))}`);
        s += `<path d="M${up.concat(dn).join("L")}Z" fill="${c}" opacity="0.13"/>`;
      }
      s += `<path d="${path(k.surv)}" fill="none" stroke="${c}" stroke-width="2.4"/>`;
      for (let i = 1; i < k.time.length; i++) if (k.censor[i] > 0 && k.event[i] === 0) s += `<line x1="${x(k.time[i])}" x2="${x(k.time[i])}" y1="${y(f(k.surv[i])) - 4}" y2="${y(f(k.surv[i])) + 4}" stroke="${c}" stroke-width="1.4"/>`;
    });
    let ry = plotB + 64; s += txt(L, ry - 4, "Number at risk", { fill: K.ink, weight: 600 });
    T.tte.km.forEach((k, j) => { const yy = ry + 16 + j * 22; s += txt(L - 20, yy, short(k.arm), { anchor: "end", fill: armCol(k.arm), weight: 600, size: 11 }); xt.forEach(t => { s += txt(x(t), yy, riskAt(k, t), { anchor: "middle", fill: K.ink }); }); });
    chart("c-km", "kaplan-meier-dermatologic", s + "</svg>");
  }
  $("#km-ci").onchange = renderKm; $("#km-cum").onchange = renderKm;
  function renderHr() {
    const hr = T.tte.hr || [], W = 440, L = 110, R = 20, Tp = 16, rowH = 40, H = Tp + hr.length * rowH + 50;
    const lo = Math.min(0.5, ...hr.map(h => h.lo)), hi = Math.max(2, ...hr.map(h => h.hi));
    const cand = [0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64], a0 = Math.max(...cand.filter(v => v <= lo)), a1 = Math.min(...cand.filter(v => v >= hi)), lt = cand.filter(v => v >= a0 && v <= a1);
    const x = v => lin(Math.log(lt[0]), Math.log(lt[lt.length - 1]), L, W - R)(Math.log(v));
    let s = svgOpen(W, H, "Hazard ratios vs placebo");
    lt.forEach(t => { s += `<line x1="${x(t)}" x2="${x(t)}" y1="${Tp}" y2="${H - 40}" stroke="${t === 1 ? K.muted : K.grid}"${t === 1 ? ' stroke-dasharray="4 3"' : ""}/>` + txt(x(t), H - 24, t, { anchor: "middle" }); });
    hr.forEach((h, i) => {
      const yy = Tp + i * rowH + rowH / 2, c = armCol(ARMS.find(a => a === h.arm) || ARMS[i + 1]);
      s += txt(L - 8, yy + 4, short(h.arm), { anchor: "end", fill: K.ink, weight: 600 });
      s += `<line x1="${x(h.lo)}" x2="${x(h.hi)}" y1="${yy}" y2="${yy}" stroke="${c}" stroke-width="2.4"/><rect x="${x(h.hr) - 6}" y="${yy - 6}" width="12" height="12" fill="${c}"><title>HR ${h.hr} (${h.lo}–${h.hi})</title></rect>`;
    });
    s += txt((L + W - R) / 2, H - 2, "Hazard ratio (log scale)", { anchor: "middle", size: 11 });
    chart("c-hr", "hazard-ratios", s + "</svg>");
    const med = a => T.tte.median[a] == null ? "not reached" : T.tte.median[a] + " days";
    let h = `<thead><tr><th></th>${ARMS.map(a => `<th class="num">${esc(short(a))}</th>`).join("")}</tr></thead><tbody>
      <tr><td>Subjects</td>${ARMS.map(a => `<td class="num">${N(a)}</td>`).join("")}</tr>
      <tr><td>Had an event</td>${ARMS.map(a => `<td class="num">${T.tte.events[a]} (${(100 * T.tte.events[a] / N(a)).toFixed(1)}%)</td>`).join("")}</tr>
      <tr><td>Median time to event</td>${ARMS.map(a => `<td class="num">${med(a)}</td>`).join("")}</tr>
      <tr><td>Hazard ratio (95% CI)</td><td class="num">reference</td>${ARMS.slice(1).map(a => { const r = hr.find(z => z.arm === a); return `<td class="num">${r ? `${r.hr.toFixed(2)} (${r.lo.toFixed(2)}–${r.hi.toFixed(2)})` : "–"}</td>`; }).join("")}</tr>
      <tr><td>Log-rank test, 3 arms</td><td class="num" colspan="3">${pfmt(T.tte.logrank_p)}</td></tr></tbody>`;
    $("#t-tte").innerHTML = h;
  }

  // ---- QC ------------------------------------------------------------------------------------------------------------------------------
  function renderQc() {
    const q = T.qc, vm = sum(q.adsl_vars.map(v => v.mismatches)), tm = q.teae.filter(t => t.production !== t.qc || (t.sql != null && t.sql !== t.production)).length;
    const cf = q.checks.filter(c => !c.pass).length, tf = q.tests ? sum(q.tests.map(t => t.failed)) : 0, te = q.tests ? sum(q.tests.map(t => t.expectations)) : 0;
    const card = (ok, big, small) => `<div class="card ${ok ? "ok" : "bad"}"><b>${big}</b>${small}</div>`;
    $("#qc-summary").innerHTML = [
      card(vm === 0, vm === 0 ? "ADSL matches" : vm + " mismatches", `${q.adsl_vars.length} variables × ${q.adsl_vars[0] ? q.adsl_vars[0].compared : 0} subjects${q.diffdf_issues === false ? " · diffdf: no issues" : ""}`),
      card(q.pt.mismatches === 0 && tm === 0, q.pt.mismatches === 0 ? "AE table matches" : q.pt.mismatches + " cells differ", `${q.pt.cells} preferred term × arm counts`),
      card(cf === 0, `${q.checks.length - cf}/${q.checks.length} rules`, "structural checks pass"),
      q.tests ? card(tf === 0, `${te - tf}/${te}`, "unit-test expectations pass") : ""
    ].join("");
    $("#qc-notes").innerHTML = (q.notes || []).length ? `<h3>Worth knowing about the data</h3><ul class="plain">${q.notes.map(n => `<li>${esc(n)}</li>`).join("")}</ul>` : "";
    $("#t-qc-adsl").innerHTML = `<thead><tr><th>Variable</th><th class="num">Subjects</th><th class="num">Mismatches</th><th>Example</th></tr></thead><tbody>` +
      q.adsl_vars.map(v => `<tr><td><code>${v.variable}</code></td><td class="num">${v.compared}</td><td class="num ${v.mismatches ? "bad" : "ok"}">${v.mismatches}</td><td>${esc(v.example || "")}</td></tr>`).join("") + "</tbody>";
    $("#t-qc-teae").innerHTML = `<thead><tr><th>Arm</th><th class="num">admiral / dplyr</th><th class="num">base R</th><th class="num">SQL</th></tr></thead><tbody>` +
      q.teae.map(t => { const ok = t.production === t.qc && (t.sql == null || t.sql === t.production); return `<tr><td>${swatch(t.arm)}${esc(short(t.arm))}</td><td class="num">${t.production}</td><td class="num">${t.qc}</td><td class="num ${ok ? "ok" : "bad"}">${t.sql == null ? "–" : t.sql}</td></tr>`; }).join("") + "</tbody>";
    $("#qc-checks").innerHTML = q.checks.map(c => `<li class="${c.pass ? "ok" : "bad"}">${esc(c.check)}</li>`).join("");
    $("#t-qc-tests").innerHTML = q.tests ? `<thead><tr><th>Test</th><th class="num">Passed</th></tr></thead><tbody>` + q.tests.map(t => `<tr><td>${esc(t.test)}</td><td class="num ${t.failed ? "bad" : "ok"}">${t.passed}/${t.expectations}</td></tr>`).join("") + "</tbody>" : `<tbody><tr><td class="small">testthat not installed</td></tr></tbody>`;
    if (q.reference && q.reference.length) {
      $("#qc-ref").innerHTML = `<h3>Against the pharmaverse reference ADSL</h3><p class="note">The <code>pharmaverseadam</code> package ships its own ADSL built from the same SDTM, so it is an outside check on my derivations. ${q.reference.every(r => r.agree_pct === 100) ? "Every variable compared agrees for every subject." : "Where agreement is below 100%, the derivation rules differ (for example how end-of-study status treats screen failures); each difference is a question worth answering, not automatically an error."}</p>
        <div class="tablewrap"><table class="tbl"><thead><tr><th>Variable</th><th class="num">Subjects compared</th><th class="num">Agreement</th></tr></thead><tbody>${q.reference.map(r => `<tr><td><code>${r.variable}</code></td><td class="num">${r.compared}</td><td class="num">${r.agree_pct}%</td></tr>`).join("")}</tbody></table></div>`;
    }
  }

  // ---- SQL ---------------------------------------------------------------------------------------------------------------------------
  function hlSql(s) {
    return esc(s).replace(/'[^']*'/g, m => `<span class="s">${m}</span>`)
      .replace(/\b(SELECT|FROM|WHERE|GROUP BY|ORDER BY|LEFT JOIN|JOIN|ON|AND|OR|AS|COUNT|DISTINCT|ROUND|AVG|MEDIAN|COALESCE|LIMIT|DESC|FILTER|OVER|PARTITION BY|ROW_NUMBER|IS NOT NULL)\b/g, '<span class="k">$1</span>');
  }
  function renderSql() {
    $("#sql-cards").innerHTML = T.sql.map(q => `<div class="sqlcard"><h4>${esc(q.title)}</h4><p>${esc(q.why || "")}</p><pre class="sql">${hlSql(q.sql)}</pre>
      <div class="tablewrap"><table class="tbl"><thead><tr>${q.cols.map(c => `<th>${esc(c)}</th>`).join("")}</tr></thead><tbody>${q.rows.map(r => `<tr>${r.map(v => `<td>${esc(v)}</td>`).join("")}</tr>`).join("")}</tbody></table></div></div>`).join("");
  }

  // ---- specs ---------------------------------------------------------------------------------------------------------------------------
  function renderSpecs() {
    const order = ["ADSL", "ADAE", "ADTTE"], names = Object.keys(T.specs || {}).sort((a, b) => (order.indexOf(a) + 1 || 99) - (order.indexOf(b) + 1 || 99)); if (!names.length) return;
    const show = n => {
      $("#spec-tabs").querySelectorAll("button").forEach(b => b.setAttribute("aria-selected", b.dataset.s === n));
      const rows = T.specs[n], cols = Object.keys(rows[0] || {});
      $("#t-spec").innerHTML = `<thead><tr>${cols.map(c => `<th>${esc(c)}</th>`).join("")}</tr></thead><tbody>${rows.map(r => `<tr>${cols.map((c, i) => `<td>${i === 0 ? `<code>${esc(r[c])}</code>` : esc(r[c])}</td>`).join("")}</tr>`).join("")}</tbody>`;
    };
    $("#spec-tabs").innerHTML = names.map(n => `<button role="tab" data-s="${n}">${n}</button>`).join("");
    $("#spec-tabs").querySelectorAll("button").forEach(b => b.onclick = () => show(b.dataset.s));
    show(names[0]);
  }

  // ---- CSV downloads for tables -----------------------------------------------------------------------------------------------------------
  document.querySelectorAll("[data-csv]").forEach(b => b.onclick = () => {
    if (b.dataset.csv === "demog") saveCSV("demographics", [["Section", "Statistic"].concat(ARMS, "Total")].concat(T.demog.map(r => [r.section, r.stat].concat(ARMS.map(a => r.values[a]), r.values.Total))));
    if (b.dataset.csv === "ae") {
      const rows = [["Body system", "Preferred term"].concat(ARMS.flatMap(a => [a + " n", a + " %"]))];
      T.ae_soc.forEach(s => { rows.push([s.soc, ""].concat(ARMS.flatMap(a => [s.n[a], s.pct[a]]))); s.pts.forEach(p => rows.push([s.soc, p.pt].concat(ARMS.flatMap(a => [p.n[a], p.pct[a]])))); });
      saveCSV("adverse-events-soc-pt", rows);
    }
  });

  function renderCharts() { readColours(); renderDisp(); renderDots(); renderAeTable(); renderVs(); renderLab(); renderKm(); renderHr(); renderConsort(); renderKpis(); renderDemog(); renderAeOverview(); }
  readColours(); renderPipe(); renderCharts(); renderQc(); renderSql(); renderSpecs();
  if (window.matchMedia) window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => { renderCharts(); renderQc(); });
})();
