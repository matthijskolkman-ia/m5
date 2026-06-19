#!/usr/bin/env python3
"""
Deep Data Detective 🕵️
─────────────────────
Drop in a CSV, press start, walk away.
Comes back 1-2 hours later with a full HTML report.

Usage:
    python main.py data/your_file.csv
    python main.py data/your_file.csv --target price
    python main.py data/your_file.csv --duration 120

Set DEEPSEEK_API_KEY in .env first!
"""

import argparse
import sys
from pathlib import Path

from analyzer import run_analysis
from reporter import generate_report


def main():
    parser = argparse.ArgumentParser(
        description="Deep Data Detective — AI-powered exhaustive EDA",
    )
    parser.add_argument("csv", help="Path to CSV file to analyze")
    parser.add_argument(
        "--target", "-t", default=None,
        help="Optional target column for predictive analysis",
    )
    parser.add_argument(
        "--duration", "-d", type=int, default=None,
        help="Duration in minutes (overrides .env DURATION_MINUTES)",
    )
    parser.add_argument(
        "--report-only", action="store_true",
        help="Skip analysis, just regenerate HTML report from output/progress.json",
    )
    args = parser.parse_args()

    if args.report_only:
        if not Path("output/progress.json").exists():
            print("❌ No output/progress.json found. Run analysis first.")
            sys.exit(1)
        generate_report()
        print("✅ Done! Open output/report.html in your browser.")
        return

    if not Path(args.csv).exists():
        print(f"❌ File not found: {args.csv}")
        sys.exit(1)

    # Read duration from .env or CLI
    if args.duration is None:
        from config import DURATION_MINUTES
        duration = DURATION_MINUTES
    else:
        duration = args.duration

    print(f"""
╔══════════════════════════════════════╗
║     🕵️  Deep Data Detective        ║
║     AI-Powered EDA Pipeline         ║
╠══════════════════════════════════════╣
║  File:     {args.csv:<26} ║
║  Target:   {str(args.target) if args.target else '(auto-detect)':<26} ║
║  Duration: ~{duration} minutes{' ' * (21 - len(str(duration)))} ║
╚══════════════════════════════════════╝
""")

    run_analysis(
        csv_path=args.csv,
        target_col=args.target,
        duration_minutes=duration,
    )

    # Generate the pretty HTML report
    generate_report()

    print("""
✅ All done! Open this in your browser:
   output/report.html
""")


if __name__ == "__main__":
    main()
