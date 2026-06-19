# 🕵️ Deep Data Detective

> **Set it and forget it.** Drop in a CSV, press start, walk away for 1–2 hours. Come back to a beautiful, AI-written exploratory data analysis report. Like a dishwasher — but for data.

Powered by [DeepSeek](https://platform.deepseek.com/) and the M5 chip's raw number-crunching muscle.

---

## What it does

Deep Data Detective runs your dataset through **9 analysis phases**, each combining local statistical computation with DeepSeek-powered interpretation:

| # | Phase | What it finds |
|---|-------|---------------|
| 1 | **Overview** | Row/column counts, dtypes, memory usage, duplicates |
| 2 | **Missingness** | Missing value patterns per column, sparse column warnings |
| 3 | **Distributions** | Mean, std, skew, kurtosis, zeros%, percentiles for every numeric column |
| 4 | **Correlations** | Top pairwise correlations, multicollinearity red flags |
| 5 | **Outliers** | IQR-based + Isolation Forest anomaly detection |
| 6 | **Clusters** | KMeans segmentation of numeric data |
| 7 | **Relationships** | AI-suggested pairwise column investigations |
| 8 | **Target Analysis** | (optional) Feature importance vs a target column |
| 9 | **Executive Summary** | AI-written narrative synthesizing everything |

**Crash-safe**: saves progress after every phase. If your laptop sleeps or you Ctrl+C, nothing is lost.

**Output**: a gorgeous dark-themed standalone HTML report — open it in any browser, no server needed.

---

## Quickstart

### 1. Clone & install

```bash
cd deep-data-detective
pip install -r requirements.txt
```

### 2. Set your DeepSeek API key

```bash
cp .env.example .env
# Edit .env → paste your key from https://platform.deepseek.com
```

### 3. Run it

```bash
# Basic run (90 minutes by default):
python3 main.py data/sample_loans.csv

# With a target column for predictive insights:
python3 main.py data/sample_loans.csv --target defaulted

# Quick test run (15 minutes):
python3 main.py data/sample_loans.csv --duration 15

# Regenerate the HTML report without re-running analysis:
python3 main.py --report-only
```

### 4. View the results

Open `output/report.html` in your browser.

---

## Configuration

All settings live in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEEPSEEK_API_KEY` | — | Your DeepSeek API key (required) |
| `DEEPSEEK_MODEL` | `deepseek-chat` | Model to use for AI interpretation |
| `DURATION_MINUTES` | `90` | How long to spread the analysis across |

CLI flags override `.env` settings:
- `--duration 60` overrides `DURATION_MINUTES`
- `--target column_name` enables target-driven analysis

---

## Sample dataset

The repo includes `data/sample_loans.csv` — a 40-row fake loan application dataset with:
- Demographics (age, city, employment)
- Financials (income, credit score, loan amount, mortgage status)
- A `defaulted` target column (0 = paid back, 1 = defaulted)
- Intentional messiness: missing values in `age` and `loan_amount`

Good for a first test run to see how the report looks.

---

## How it works

```
┌──────────┐    ┌──────────────┐    ┌──────────┐
│  CSV in  │───▶│  analyzer.py │───▶│ report.html │
└──────────┘    │  9 phases    │    └──────────┘
                │  local stats │
                │  + DeepSeek  │
                └──────┬───────┘
                       │
                ┌──────▼───────┐
                │ progress.json│  ← crash-safe checkpoint
                └──────────────┘
```

Each phase:
1. Runs statistical computations locally with **pandas, numpy, scipy, scikit-learn**
2. Sends the structured results to **DeepSeek** for plain-English interpretation
3. Writes the result to `output/progress.json` immediately
4. Sleeps for the remaining time budget to evenly spread across the configured duration

The reporter (`reporter.py`) takes `progress.json` and renders a self-contained HTML file with inline CSS — no external dependencies, no JavaScript, works offline.

---

## Requirements

- Python 3.9+
- A [DeepSeek API key](https://platform.deepseek.com/)
- Dependencies: `pandas`, `numpy`, `scipy`, `scikit-learn`, `matplotlib`, `seaborn`, `openai`, `jinja2`, `missingno`, `python-dotenv`

---

## Project structure

```
deep-data-detective/
├── main.py              # CLI entry point
├── analyzer.py          # 9-phase EDA engine + DeepSeek integration
├── reporter.py          # HTML report generator (dark theme)
├── config.py            # .env loading, phase definitions
├── requirements.txt     # Python dependencies
├── .env.example         # API key template
├── data/
│   └── sample_loans.csv # Example dataset for testing
└── output/
    ├── progress.json    # Intermediate results (crash-safe)
    └── report.html      # Final report — open in browser!
```

---

## License

MIT — do whatever you want with it.

---

*Built for the M5 MacBook Pro. Let it hum while you touch grass.* 🌿
