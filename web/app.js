const data = {
  stages: [
    { label: "Prospecting", count: 500, value: "$1.07m", width: 31 },
    { label: "Engaging", count: 1589, value: "$2.29m", width: 67 },
    { label: "Won", count: 4238, value: "$10.01m", width: 100 },
    { label: "Lost", count: 2473, value: "$5.95m", width: 59 },
  ],
  queue: [
    ["0D8Y5JA0", "Anna Snelling", "GTX Plus Pro", "Central", "40%", "Complete CRM record", "high"],
    ["A4TA5P1B", "Darcel Schlecht", "GTX Plus Pro", "Central", "40%", "Complete CRM record", "high"],
    ["1CD4N8JQ", "Moses Frase", "MG Advanced", "West", "68%", "Review stalled opportunity", "medium"],
    ["Q2L7R9VK", "Cecily Lampkin", "GTX Pro", "East", "76%", "Progress next action", "low"],
    ["Y7R2B5NF", "Kerry Cummings", "GTK 500", "West", "52%", "Review stalled opportunity", "medium"],
  ],
  accounts: [
    ["GTX Pro", "$3.51m", "63.6%", "37 days", "Strongest value engine"],
    ["GTX Plus Pro", "$2.63m", "64.3%", "38 days", "Best close rate at scale"],
    ["MG Advanced", "$2.22m", "60.3%", "43 days", "Conversion needs attention"],
    ["GTX Plus Basic", "$705k", "62.1%", "48 days", "Longer cycle than mix"],
    ["GTX Basic", "$499k", "63.7%", "50 days", "Volume, not value"],
  ],
};

const app = document.querySelector("#app");
const crumb = document.querySelector("#crumb");
const nav = [...document.querySelectorAll("[data-view]")];

const money = (value) => value;
const initials = (name) => name.split(" ").map((part) => part[0]).join("").slice(0, 2);

function metric(label, value, foot, tone = "") {
  return `<article class="metric-card"><span class="metric-label">${label}</span><div class="metric-value">${value}</div><div class="metric-foot ${tone}">${foot}</div></article>`;
}

function pageHeading(kicker, title, lede, action = "") {
  return `<div class="page-heading"><div><div class="kicker">${kicker}</div><h1>${title}</h1><p class="lede">${lede}</p></div>${action}</div>`;
}

function room() {
  const stageRows = data.stages.map((stage) => `<div class="stage-row"><label>${stage.label}</label><div class="bar-track"><div class="bar-fill" style="width:${stage.width}%"></div></div><strong>${stage.value}</strong></div>`).join("");
  const queueRows = data.queue.slice(0, 4).map((row) => `<tr><td><div class="person"><span class="person-mark">${initials(row[1])}</span><span><strong>${row[1]}</strong><small>${row[0]}</small></span></div></td><td>${row[2]}</td><td>${row[3]}</td><td><span class="tag ${row[6] === "high" ? "red" : row[6] === "medium" ? "gold" : "green"}">${row[4]} complete</span></td><td>${row[5]}</td></tr>`).join("");
  return `${pageHeading("Commercial intelligence · 16 September 2026", "The forecast is bigger than the evidence.", "Ellery has a $3.36m open book, but only 664 opportunities contain enough context for a confident next move. Cerneva turns that gap into a reviewable commercial plan.", `<span class="date-chip">◷ Q3 snapshot <b>⌄</b></span>`)}
    <section class="metric-grid">
      ${metric("Open book", "$3.36m", "2,089 active opportunities", "")}
      ${metric("Won revenue", "$10.01m", "63.2% closed-deal win rate", "positive")}
      ${metric("Records ready to act", "664", "31.8% of open book", "caution")}
      ${metric("Forecast model", "Rejected", "AUC 0.486 · baseline wins", "negative")}
    </section>
    <section class="grid-main">
      <article class="panel"><div class="panel-head"><div><h2>Where the book is sitting</h2><p>Opportunity value by stage · list-price proxy from the source CRM</p></div><a class="small-link" data-view="pipeline">Open pipeline →</a></div><div class="panel-body"><div class="stage-chart">${stageRows}</div><div class="chart-foot"><span><b>2,089</b> open opportunities</span><span><b>67.9%</b> average record completeness</span></div></div></article>
      <article class="narrative-card"><span class="eyebrow">Decision memo · 09:00 revenue council</span><h2>Do not automate the forecast yet.</h2><p>The model cannot beat the historical baseline because the CRM knows what was sold, not how the buyer moved. Protect the number by tightening evidence before adding prediction.</p><div class="callout"><div><strong>Next move</strong><span>1,425</span></div><div><strong>Records needing context</strong><span>31.8%</span></div></div></article>
    </section>
    <section class="lower-grid">
      <article class="panel"><div class="panel-head"><div><h2>Review queue</h2><p>Highest-leverage records for this week’s manager reviews</p></div><a class="small-link" data-view="pipeline">View all →</a></div><div class="table-wrap"><table><thead><tr><th>Owner</th><th>Product</th><th>Region</th><th>Evidence</th><th>Recommended move</th></tr></thead><tbody>${queueRows}</tbody></table></div></article>
      <article class="panel"><div class="panel-head"><div><h2>What changed</h2><p>The useful signal is a pattern, not a single score.</p></div></div><div class="panel-body decision-list"><div class="decision-item"><span class="decision-icon">↗</span><div><strong>Engaging has the volume</strong><p>1,589 opportunities are sitting in the middle of the funnel. Add a stage-age review before they become silent losses.</p></div><time>Now</time></div><div class="decision-item"><span class="decision-icon">◌</span><div><strong>GTX Pro carries the value</strong><p>$3.51m won revenue makes it the commercial engine; protect its 37-day cycle.</p></div><time>Insight</time></div><div class="decision-item"><span class="decision-icon">!</span><div><strong>Data quality is the constraint</strong><p>1,425 open records need CRM context before a forecast can be defended in a board room.</p></div><time>Action</time></div></div></article>
    </section>`;
}

function pipeline() {
  const rows = data.queue.map((row) => `<tr><td><strong>${row[0]}</strong><small class="cell-sub">${row[1]}</small></td><td>${row[2]}</td><td><span class="tag ${row[6] === "high" ? "red" : row[6] === "medium" ? "gold" : "green"}">${row[5]}</span></td><td>${row[3]}</td><td>${row[4]}</td><td><button class="outline-button" type="button">Review</button></td></tr>`).join("");
  return `${pageHeading("Operate · pipeline desk", "Every open deal needs a next move.", "Cerneva does not pretend that a CRM row is a probability. It gives managers a short, owned queue: complete the evidence, review the stall or progress the next step.", `<div class="toolbar"><input class="search" id="pipelineSearch" placeholder="Search owner, product or action" /><button class="outline-button" type="button">Export queue</button></div>`)}
    <article class="panel"><div class="panel-head"><div><h2>Open opportunity queue</h2><p>Showing a representative slice of 2,089 open opportunities · sorted by action score</p></div><button class="filter-button" type="button">All actions ⌄</button></div><div class="table-wrap"><table id="pipelineTable"><thead><tr><th>Opportunity</th><th>Product</th><th>Recommended move</th><th>Region</th><th>Record</th><th></th></tr></thead><tbody>${rows}</tbody></table></div></article>`;
}

function accounts() {
  const rows = data.accounts.map((row, i) => `<tr><td><div class="person"><span class="person-mark">${i + 1}</span><span><strong>${row[0]}</strong><small>${row[4]}</small></span></div></td><td><strong>${row[1]}</strong></td><td><span class="tag ${i === 2 ? "gold" : "green"}">${row[2]}</span></td><td>${row[3]}</td><td><span class="small-link">Open lens →</span></td></tr>`).join("");
  return `${pageHeading("Understand · commercial mix", "The best customers are not always the biggest rows.", "Accounts and products need to be read together. Cerneva separates volume, value and cycle time so a sales leader can choose where to add coverage.", `<span class="date-chip">Closed period · FY17 <b>⌄</b></span>`)}
    <section class="metric-grid">${metric("Best product win rate", "64.8%", "MG Special · small base", "positive")}${metric("Fastest product cycle", "37 days", "GTX Pro", "positive")}${metric("Highest value region", "$3.57m", "West won revenue", "")}${metric("Cycle to watch", "50 days", "GTX Basic", "caution")}</section>
    <section class="lower-grid"><article class="panel"><div class="panel-head"><div><h2>Product lenses</h2><p>What the mix says before a manager reaches for a discount</p></div></div><div class="table-wrap"><table><thead><tr><th>Product</th><th>Won revenue</th><th>Win rate</th><th>Median cycle</th><th></th></tr></thead><tbody>${rows}</tbody></table></div></article><article class="narrative-card"><span class="eyebrow">Commercial lens</span><h2>Protect the value engine before chasing more volume.</h2><p>GTX Pro contributes $3.51m in won revenue with the shortest cycle in the core mix. The action is not “sell harder”; it is keep the proof and coverage that makes this motion work.</p><div class="callout"><div><strong>Won revenue</strong><span>$3.51m</span></div><div><strong>Median cycle</strong><span>37d</span></div></div></article></section>`;
}

function forecast() {
  return `${pageHeading("Understand · forecast lab", "Confidence starts with knowing what the data cannot say.", "Cerneva tested a transparent logistic model against a chronological holdout. The result is deliberately visible: the model loses to a simple historical-rate baseline.", `<span class="tag red">Not operationalised</span>`)}
    <section class="forecast-grid"><article class="panel"><div class="lab-score"><div><span class="eyebrow">Chronological holdout AUC</span><strong>0.486</strong></div><span>Below 0.500 means the ranking is not useful for an automated win decision.</span></div><div class="lab-bars"><div class="lab-row"><span>Model Brier score</span><div class="lab-bar"><i style="width:96.8%"></i></div><strong>0.242</strong></div><div class="lab-row"><span>Historical baseline</span><div class="lab-bar"><i class="baseline" style="width:96.6%"></i></div><strong>0.241</strong></div><div class="lab-row"><span>Calibration coverage</span><div class="lab-bar"><i style="width:42%"></i></div><strong>42%</strong></div></div></article><article class="panel"><div class="panel-head"><div><h2>Evidence before automation</h2><p>What would make the next experiment worth running?</p></div></div><div class="panel-body evidence-list"><div class="evidence-row"><span class="evidence-mark">1</span><div><strong>Stage history</strong><p>Capture how long a deal actually stayed in each stage, not just its current label.</p></div></div><div class="evidence-row"><span class="evidence-mark">2</span><div><strong>Buyer activity</strong><p>Record meetings, stakeholders, replies and next-step commitments at the deal grain.</p></div></div><div class="evidence-row"><span class="evidence-mark">3</span><div><strong>Temporal validation</strong><p>Keep future outcomes out of the training window and compare against the baseline every run.</p></div></div></div></article></section>`;
}

function controls() {
  return `${pageHeading("Govern · commercial controls", "A forecast is a governed product, not a colourful number.", "These controls stop weak evidence travelling quietly from a CRM export into a leadership meeting.", `<button class="outline-button" type="button">Download control note</button>`)}
    <section class="control-grid"><article class="panel control-card"><span class="tag green">PASS · 8,800 rows</span><h3>Source reconciliation</h3><p>Opportunity, account, product and sales-team keys are validated before any summary is written.</p><div class="control-state">Reconciled 16 Sep 2026</div></article><article class="panel control-card"><span class="tag green">PASS · 12 checks</span><h3>Action queue quality</h3><p>Every recommendation carries an owner, a reason and a record-completeness score.</p><div class="control-state">Reviewable by manager</div></article><article class="panel control-card warn"><span class="tag gold">HOLD · evidence gap</span><h3>Forecast automation</h3><p>The model is retained for learning, not used to make a customer, manager or compensation decision.</p><div class="control-state">Human review required</div></article></section>
    <article class="panel" style="margin-top:15px"><div class="panel-head"><div><h2>Cerneva’s operating rule</h2><p>When evidence is weak, the system should narrow the question rather than invent certainty.</p></div></div><div class="panel-body"><div class="narrative-inline"><span class="quote-mark">“</span><div><strong>Show me the record behind the number.</strong><p>Every metric in the room must be traceable to source data, a calculation and a decision owner. If the calculation cannot clear that bar, it stays in the lab.</p></div></div></div></article>`;
}

const views = { room, pipeline, accounts, forecast, controls };
function render(view = "room") {
  app.innerHTML = views[view]();
  crumb.textContent = document.querySelector(`[data-view="${view}"]`)?.textContent.trim() || "Revenue room";
  nav.forEach((item) => item.classList.toggle("active", item.dataset.view === view));
  document.querySelectorAll("[data-view]").forEach((item) => item.addEventListener("click", () => render(item.dataset.view)));
  const search = document.querySelector("#pipelineSearch");
  if (search) search.addEventListener("input", () => {
    const query = search.value.toLowerCase();
    document.querySelectorAll("#pipelineTable tbody tr").forEach((row) => { row.hidden = !row.textContent.toLowerCase().includes(query); });
  });
}

render("room");
