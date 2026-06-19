"""
Deep Data Detective — Configuration
"""
import os
from dotenv import load_dotenv

load_dotenv()

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
DEEPSEEK_BASE_URL = "https://api.deepseek.com"
DEEPSEEK_MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

DURATION_MINUTES = int(os.getenv("DURATION_MINUTES", "90"))
PROGRESS_FILE = "output/progress.json"

# Analysis phases, roughly timed
PHASES = [
    ("overview",       "Basic stats, shape, dtypes, memory usage"),
    ("missingness",    "Missing value patterns, correlations in missingness"),
    ("distributions",  "Distribution analysis per column, skew, kurtosis"),
    ("correlations",   "Pairwise correlations, multicollinearity"),
    ("outliers",       "Outlier detection — Z-score, IQR, isolation forest"),
    ("clusters",       "Cluster analysis — KMeans, DBSCAN"),
    ("relationships",  "Interesting pairwise relationships & interactions"),
    ("target_driven",  "If target column given: feature importance, SHAP-lite"),
    ("story",          "Synthesize findings into a narrative"),
]
