"""
Deep Data Detective — Core analysis engine.
Runs statistical computations locally, uses DeepSeek for interpretation & narrative.
"""
import json
import time
import io
import base64
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from openai import OpenAI
from scipy import stats
from sklearn.cluster import KMeans
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

from config import (
    DEEPSEEK_API_KEY, DEEPSEEK_BASE_URL, DEEPSEEK_MODEL,
    PHASES, PROGRESS_FILE,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _df_snapshot(df: pd.DataFrame, n_rows: int = 5) -> str:
    """Compact text summary of a DataFrame for sending to the LLM."""
    buf = io.StringIO()
    df.info(buf=buf, verbose=False, show_counts=True)
    info_str = buf.getvalue()
    head = df.head(n_rows).to_string()
    desc = df.describe(include="all").to_string()
    return f"--- INFO ---\n{info_str}\n--- HEAD ---\n{head}\n--- DESCRIBE ---\n{desc}"


def _ask_deepseek(client: OpenAI, system: str, user: str, max_tokens: int = 2048) -> str:
    """Send a prompt to DeepSeek and return the response text."""
    resp = client.chat.completions.create(
        model=DEEPSEEK_MODEL,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.3,
        max_tokens=max_tokens,
    )
    return resp.choices[0].message.content.strip()


# ---------------------------------------------------------------------------
# Phase runners  (each returns a dict stored in progress)
# ---------------------------------------------------------------------------

def phase_overview(df: pd.DataFrame, client: OpenAI) -> dict:
    """Basic dataset overview."""
    stats = {
        "rows": len(df),
        "cols": len(df.columns),
        "dtypes": df.dtypes.astype(str).to_dict(),
        "memory_mb": round(df.memory_usage(deep=True).sum() / 1e6, 2),
        "duplicates": int(df.duplicated().sum()),
    }
    prompt = f"Here is a dataset summary:\n{json.dumps(stats, indent=2)}\n\nGive a 3-4 sentence plain-English overview of this dataset. Be concise."
    narrative = _ask_deepseek(
        client,
        "You are a senior data analyst. Write concise, insightful prose.",
        prompt,
    )
    return {"stats": stats, "narrative": narrative}


def phase_missingness(df: pd.DataFrame, client: OpenAI) -> dict:
    """Missing value analysis."""
    missing = df.isnull().sum()
    missing_pct = (missing / len(df) * 100).round(2)
    missing_table = pd.DataFrame({"count": missing, "pct": missing_pct}).query("count > 0")
    missing_json = missing_table.to_dict(orient="index") if not missing_table.empty else {}

    prompt = f"Missing value report (column → count, %):\n{json.dumps(missing_json, indent=2)}\n\nSummarize the missing data situation in 2-3 sentences. Note any columns that might be too sparse to use."
    narrative = _ask_deepseek(
        client,
        "You are a senior data analyst.",
        prompt,
    )
    return {"missing_table": missing_json, "narrative": narrative}


def phase_distributions(df: pd.DataFrame, client: OpenAI) -> dict:
    """Distribution analysis for numeric columns."""
    num_cols = df.select_dtypes(include=np.number).columns.tolist()
    if not num_cols:
        return {"narrative": "No numeric columns found.", "distributions": {}}

    dists = {}
    for col in num_cols[:30]:  # cap at 30 columns
        series = df[col].dropna()
        if len(series) < 2:
            continue
        dists[col] = {
            "mean": round(float(series.mean()), 4),
            "std": round(float(series.std()), 4),
            "min": round(float(series.min()), 4),
            "p25": round(float(series.quantile(0.25)), 4),
            "p50": round(float(series.quantile(0.50)), 4),
            "p75": round(float(series.quantile(0.75)), 4),
            "max": round(float(series.max()), 4),
            "skew": round(float(series.skew()), 4),
            "kurtosis": round(float(series.kurtosis()), 4),
            "zeros_pct": round(float((series == 0).mean() * 100), 2),
            "unique": int(series.nunique()),
        }

    prompt = (
        f"Distribution stats for numeric columns:\n{json.dumps(dists, indent=2)}\n\n"
        "In 3-4 sentences, highlight the most interesting distributions — anything heavily skewed, "
        "bimodal-looking, or with surprising zeros."
    )
    narrative = _ask_deepseek(client, "You are a senior data analyst.", prompt)
    return {"distributions": dists, "narrative": narrative}


def phase_correlations(df: pd.DataFrame, client: OpenAI) -> dict:
    """Correlation analysis."""
    num_df = df.select_dtypes(include=np.number)
    if num_df.shape[1] < 2:
        return {"narrative": "Not enough numeric columns for correlation analysis.", "top_correlations": []}

    corr = num_df.corr()
    # Extract top correlations (absolute value)
    pairs = []
    for i in range(len(corr.columns)):
        for j in range(i + 1, len(corr.columns)):
            pairs.append({
                "col1": corr.columns[i],
                "col2": corr.columns[j],
                "correlation": round(float(corr.iloc[i, j]), 4),
            })
    pairs.sort(key=lambda x: abs(x["correlation"]), reverse=True)
    top = pairs[:20]

    prompt = (
        f"Top pairwise correlations (|r| > 0.3):\n{json.dumps([p for p in top if abs(p['correlation']) > 0.3], indent=2)}\n\n"
        "In 2-3 sentences, comment on the strongest relationships and any multicollinearity concerns."
    )
    narrative = _ask_deepseek(client, "You are a senior data analyst.", prompt)
    return {"top_correlations": top, "narrative": narrative}


def phase_outliers(df: pd.DataFrame, client: OpenAI) -> dict:
    """Outlier detection using IQR + Isolation Forest."""
    num_cols = df.select_dtypes(include=np.number).columns.tolist()
    if not num_cols:
        return {"narrative": "No numeric columns for outlier analysis.", "outlier_summary": {}}

    # IQR method
    iqr_outliers = {}
    for col in num_cols[:20]:
        series = df[col].dropna()
        q1, q3 = series.quantile(0.25), series.quantile(0.75)
        iqr = q3 - q1
        lower, upper = q1 - 1.5 * iqr, q3 + 1.5 * iqr
        count = int(((series < lower) | (series > upper)).sum())
        iqr_outliers[col] = {"count": count, "pct": round(count / len(series) * 100, 2)}

    # Isolation Forest
    try:
        num_df = df[num_cols].dropna()
        if len(num_df) > 10 and num_df.shape[1] >= 2:
            scaled = StandardScaler().fit_transform(num_df)
            iso = IsolationForest(contamination=0.05, random_state=42)
            preds = iso.fit_predict(scaled)
            iso_count = int((preds == -1).sum())
        else:
            iso_count = 0
    except Exception:
        iso_count = 0

    prompt = (
        f"IQR outlier counts per column:\n{json.dumps(iqr_outliers, indent=2)}\n"
        f"Isolation Forest flagged {iso_count} rows as outliers (5% contamination).\n\n"
        "Summarize the outlier situation in 2-3 sentences."
    )
    narrative = _ask_deepseek(client, "You are a senior data analyst.", prompt)
    return {"iqr_outliers": iqr_outliers, "iso_forest_flags": iso_count, "narrative": narrative}


def phase_clusters(df: pd.DataFrame, client: OpenAI) -> dict:
    """Simple KMeans clustering."""
    num_df = df.select_dtypes(include=np.number).dropna()
    if len(num_df) < 10 or num_df.shape[1] < 2:
        return {"narrative": "Not enough numeric data for clustering.", "clusters": {}}

    try:
        scaled = StandardScaler().fit_transform(num_df)
        kmeans = KMeans(n_clusters=min(5, len(num_df) // 5), random_state=42, n_init=10)
        labels = kmeans.fit_predict(scaled)
        counts = pd.Series(labels).value_counts().to_dict()
    except Exception:
        return {"narrative": "Clustering failed.", "clusters": {}}

    prompt = (
        f"KMeans found {len(counts)} clusters with sizes: {json.dumps({int(k): int(v) for k, v in counts.items()})}.\n\n"
        "In 2-3 sentences, comment on what these cluster sizes might suggest about the data structure."
    )
    narrative = _ask_deepseek(client, "You are a senior data analyst.", prompt)
    return {"cluster_sizes": {int(k): int(v) for k, v in counts.items()}, "narrative": narrative}


def phase_relationships(df: pd.DataFrame, client: OpenAI) -> dict:
    """Ask DeepSeek to identify interesting column relationships."""
    snapshot = _df_snapshot(df)
    prompt = (
        f"Dataset snapshot:\n{snapshot}\n\n"
        "Based on this snapshot, suggest 3-5 specific, interesting pairwise relationships or questions "
        "worth investigating further (e.g., 'Does column X vary by category Y?'). "
        "Return as a JSON list of strings."
    )
    raw = _ask_deepseek(client, "You are a data analyst. Return ONLY valid JSON.", prompt, max_tokens=1024)
    try:
        # Try to extract JSON block
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        suggestions = json.loads(raw)
    except json.JSONDecodeError:
        suggestions = [raw]

    return {"suggested_investigations": suggestions}


def phase_target_driven(df: pd.DataFrame, target_col: Optional[str], client: OpenAI) -> dict:
    """If a target column is specified, do target-aware analysis."""
    if target_col is None or target_col not in df.columns:
        return {"narrative": "No target column specified — skipping target-driven analysis."}

    num_cols = df.select_dtypes(include=np.number).columns.tolist()
    if target_col in num_cols:
        num_cols.remove(target_col)

    correlations = {}
    for col in num_cols[:30]:
        valid = df[[col, target_col]].dropna()
        if len(valid) > 5:
            r, p = stats.pearsonr(valid[col], valid[target_col])
            correlations[col] = {"pearson_r": round(float(r), 4), "p_value": round(float(p), 6)}

    top_corrs = dict(
        sorted(correlations.items(), key=lambda x: abs(x[1]["pearson_r"]), reverse=True)[:10]
    )

    prompt = (
        f"Target column: '{target_col}'\n"
        f"Top correlations with target:\n{json.dumps(top_corrs, indent=2)}\n\n"
        "In 2-3 sentences, which features seem most predictive?"
    )
    narrative = _ask_deepseek(client, "You are a senior data analyst.", prompt)
    return {"target": target_col, "top_correlations": top_corrs, "narrative": narrative}


def phase_story(all_phases: list[dict], client: OpenAI) -> dict:
    """Synthesize all phase results into an executive summary."""
    summary = json.dumps(all_phases, indent=2, default=str)
    prompt = (
        f"Here are the results of an exhaustive EDA across many phases:\n{summary[:6000]}\n\n"
        "Write a 5-7 paragraph executive summary of this dataset. Cover: what kind of data this is, "
        "data quality issues, key statistical findings, interesting relationships, and actionable next steps. "
        "Write in a professional but engaging tone."
    )
    narrative = _ask_deepseek(
        client,
        "You are a senior data scientist writing an executive summary for stakeholders.",
        prompt,
        max_tokens=3000,
    )
    return {"executive_summary": narrative}


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

def run_analysis(csv_path: str, target_col: Optional[str] = None, duration_minutes: int = 90):
    """Run the full analysis pipeline. Saves progress incrementally."""
    Path("output").mkdir(exist_ok=True)

    if not DEEPSEEK_API_KEY or DEEPSEEK_API_KEY == "sk-your-key-here":
        raise ValueError("Set DEEPSEEK_API_KEY in .env file!")

    client = OpenAI(api_key=DEEPSEEK_API_KEY, base_url=DEEPSEEK_BASE_URL)

    # ── Optional: phone notifications ──────────────────────────────
    ra = None
    try:
        from remote_approve import RemoteApproval
        ra = RemoteApproval()
        ra.notify(
            title="🕵️ Deep Data Detective Started",
            message=f"Analyzing `{Path(csv_path).name}`\n"
                    f"{duration_minutes} min · ~{len(PHASES)} phases",
            emoji="🚀",
        )
    except (ImportError, FileNotFoundError):
        pass  # Remote approval not configured — that's fine

    print(f"📂 Loading {csv_path} ...")
    df = pd.read_csv(csv_path)
    print(f"   {len(df):,} rows × {len(df.columns)} columns loaded.\n")

    deadline = datetime.now() + timedelta(minutes=duration_minutes)
    phase_seconds = (duration_minutes * 60) / len(PHASES)

    progress: dict = {"started": datetime.now().isoformat(), "phases": {}}

    for i, (name, description) in enumerate(PHASES):
        remaining = (deadline - datetime.now()).total_seconds()
        if remaining < 30:
            print(f"⏰ Time budget exhausted, skipping '{name}'.")
            continue

        print(f"🔬 Phase {i+1}/{len(PHASES)}: {name} — {description}")
        t0 = time.time()

        try:
            if name == "overview":
                result = phase_overview(df, client)
            elif name == "missingness":
                result = phase_missingness(df, client)
            elif name == "distributions":
                result = phase_distributions(df, client)
            elif name == "correlations":
                result = phase_correlations(df, client)
            elif name == "outliers":
                result = phase_outliers(df, client)
            elif name == "clusters":
                result = phase_clusters(df, client)
            elif name == "relationships":
                result = phase_relationships(df, client)
            elif name == "target_driven":
                result = phase_target_driven(df, target_col, client)
            elif name == "story":
                result = phase_story(list(progress["phases"].values()), client)
            else:
                result = {"error": "unknown phase"}
        except Exception as e:
            result = {"error": str(e)}
            print(f"   ⚠️  Failed: {e}")

        elapsed = time.time() - t0
        result["_elapsed_s"] = round(elapsed, 1)
        progress["phases"][name] = result

        # Save checkpoint after every phase
        with open(PROGRESS_FILE, "w") as f:
            json.dump(progress, f, indent=2, default=str)

        print(f"   ✅ Done in {elapsed:.0f}s\n")

        # Respect time budget: sleep if we're ahead
        budget = phase_seconds - elapsed
        if budget > 0:
            time.sleep(min(budget, 30))

    progress["finished"] = datetime.now().isoformat()
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2, default=str)

    print("🎉 Analysis complete! Report saved to output/progress.json")

    # ── Phone notification ──────────────────────────────────────
    if ra:
        elapsed = (datetime.now() - datetime.fromisoformat(progress["started"])).total_seconds()
        errors = sum(1 for p in progress["phases"].values() if "error" in p)
        ra.notify(
            title="✅ Deep Data Detective Complete",
            message=f"Analysis finished in {elapsed/60:.0f} min.\n"
                    f"Phases: {len(progress['phases'])}/{len(PHASES)} completed"
                    + (f" ({errors} errors)" if errors else ""),
            emoji="🎉",
        )

    return progress
