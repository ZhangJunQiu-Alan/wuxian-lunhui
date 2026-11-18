#!/bin/zsh
review_project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$review_project_dir/tools/asset_review/serve_review.py" --open-browser
