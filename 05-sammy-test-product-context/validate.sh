#!/usr/bin/env bash
# validate.sh — Lightweight linting for product-context files
# Usage: bash validate.sh [path]
# Default path: the directory containing this script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${1:-$SCRIPT_DIR}"
TODAY=$(date +%Y-%m-%d)
VIOLATIONS=0
MAX_CHARS=5000

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Portable relative path (works on macOS without GNU realpath)
relpath() {
    python3 -c "import os.path; print(os.path.relpath('$1', '$2'))"
}

declare -a MISSING_FRONTMATTER=()
declare -a MISSING_HEADER=()
declare -a STALE_FILES=()
declare -a NOT_IN_INDEX=()
declare -a OVERSIZED=()
declare -a ORPHANED_INDEX=()

# --- Check 1: Front matter presence ---
check_frontmatter() {
    local file="$1"
    local in_frontmatter=false
    local has_frontmatter=false
    local has_owner=false
    local has_last_updated=false
    local has_cadence=false
    local has_next_review=false

    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                break
            elif (( line_num == 1 )); then
                in_frontmatter=true
                has_frontmatter=true
                continue
            fi
        fi
        if $in_frontmatter; then
            [[ "$line" =~ ^owner: ]] && has_owner=true
            [[ "$line" =~ ^last_updated: ]] && has_last_updated=true
            [[ "$line" =~ ^review_cadence: ]] && has_cadence=true
            [[ "$line" =~ ^next_review: ]] && has_next_review=true
        fi
    done < "$file"

    if ! $has_frontmatter || ! $has_owner || ! $has_last_updated || ! $has_cadence || ! $has_next_review; then
        local missing=""
        $has_frontmatter || missing="frontmatter block"
        $has_owner || missing="${missing:+$missing, }owner"
        $has_last_updated || missing="${missing:+$missing, }last_updated"
        $has_cadence || missing="${missing:+$missing, }review_cadence"
        $has_next_review || missing="${missing:+$missing, }next_review"
        MISSING_FRONTMATTER+=("$(relpath "$file" "$BASE_DIR"): missing $missing")
    fi
}

# --- Check 2: Header requirement ---
check_header() {
    local file="$1"
    local past_frontmatter=false
    local found_title=false
    local found_load_when=false
    local in_frontmatter=false

    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                past_frontmatter=true
                continue
            elif (( line_num == 1 )); then
                in_frontmatter=true
                continue
            fi
        fi
        if $past_frontmatter; then
            [[ -z "$line" ]] && continue
            if ! $found_title && [[ "$line" =~ ^#\  ]]; then
                found_title=true
                continue
            fi
            if $found_title && ! $found_load_when; then
                [[ -z "$line" ]] && continue
                if [[ "$line" =~ ^Load\ when ]]; then
                    found_load_when=true
                fi
                break
            fi
        fi
    done < "$file"

    if $past_frontmatter && $found_title && ! $found_load_when; then
        MISSING_HEADER+=("$(relpath "$file" "$BASE_DIR")")
    fi
}

# --- Check 3: Staleness ---
check_staleness() {
    local file="$1"
    local next_review=""
    local in_fm=false

    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [[ "$line" == "---" ]]; then
            if $in_fm; then break; elif (( line_num == 1 )); then in_fm=true; continue; fi
        fi
        if $in_fm && [[ "$line" =~ ^next_review:\ (.+) ]]; then
            next_review="${BASH_REMATCH[1]}"
        fi
    done < "$file"

    if [[ -n "$next_review" ]] && [[ "$next_review" < "$TODAY" ]]; then
        STALE_FILES+=("$(relpath "$file" "$BASE_DIR"): next_review=$next_review")
    fi
}

# --- Check 4: Index coverage ---
check_index_coverage() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    local dir
    dir=$(dirname "$file")
    local index="$dir/CLAUDE.md"

    # Skip files that aren't expected in indexes
    [[ "$filename" == "CLAUDE.md" ]] && return
    [[ "$filename" == "README.md" ]] && return
    [[ "$filename" == "interview-protocol.md" ]] && return
    [[ "$filename" == "SKILL.md" ]] && return
    [[ "$filename" == "validate.sh" ]] && return

    if [[ -f "$index" ]]; then
        if ! grep -q "$filename" "$index" 2>/dev/null; then
            NOT_IN_INDEX+=("$(relpath "$file" "$BASE_DIR") not listed in $(relpath "$index" "$BASE_DIR")")
        fi
    else
        NOT_IN_INDEX+=("$(relpath "$file" "$BASE_DIR") has no folder index ($(relpath "$dir" "$BASE_DIR")/CLAUDE.md missing)")
    fi
}

# --- Check 5: File size ---
check_size() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    [[ "$filename" == "CLAUDE.md" ]] && return
    [[ "$filename" == "README.md" ]] && return
    [[ "$filename" == "interview-protocol.md" ]] && return
    [[ "$filename" == "SKILL.md" ]] && return

    local chars
    chars=$(wc -c < "$file" | tr -d ' ')
    if (( chars > MAX_CHARS )); then
        OVERSIZED+=("$(relpath "$file" "$BASE_DIR"): ${chars} chars (target: ${MAX_CHARS})")
    fi
}

# --- Check 6: Orphaned index entries ---
check_orphaned_indexes() {
    local index_file="$1"
    local dir
    dir=$(dirname "$index_file")

    # Extract backtick-wrapped .md filenames from index (portable grep)
    grep -o '`[^`]*\.md`' "$index_file" 2>/dev/null | tr -d '`' | while read -r referenced; do
        if [[ ! -f "$dir/$referenced" ]]; then
            echo "$(relpath "$index_file" "$BASE_DIR") references $referenced but file does not exist"
        fi
    done | while read -r orphan; do
        ORPHANED_INDEX+=("$orphan")
    done
}

# --- Run all checks ---
echo "Validating product-context files in: $BASE_DIR"
echo "================================================"

while IFS= read -r -d '' file; do
    filename=$(basename "$file")

    if [[ "$filename" != "CLAUDE.md" ]] && [[ "$filename" != "README.md" ]] && [[ "$filename" != "interview-protocol.md" ]] && [[ "$filename" != "SKILL.md" ]]; then
        check_frontmatter "$file"
        check_header "$file"
        check_staleness "$file"
        check_size "$file"
    fi

    check_index_coverage "$file"

done < <(find "$BASE_DIR" -name "*.md" -not -name "*.sh" -print0)

# Check orphaned indexes — collect into temp file for macOS subshell compat
ORPHAN_TMPFILE=$(mktemp)
while IFS= read -r -d '' index_file; do
    dir=$(dirname "$index_file")
    { grep -o '`[^`]*\.md`' "$index_file" 2>/dev/null || true; } | tr -d '`' | while read -r referenced; do
        [[ -z "$referenced" ]] && continue
        # Skip cross-repo references (contain /) and template patterns (contain [ or *)
        [[ "$referenced" == */* ]] && continue
        [[ "$referenced" == *[* ]] && continue
        [[ "$referenced" == *'*'* ]] && continue
        if [[ ! -f "$dir/$referenced" ]]; then
            echo "$(relpath "$index_file" "$BASE_DIR") references $referenced but file does not exist" >> "$ORPHAN_TMPFILE"
        fi
    done
done < <(find "$BASE_DIR" -name "CLAUDE.md" -print0)

while IFS= read -r orphan; do
    ORPHANED_INDEX+=("$orphan")
done < "$ORPHAN_TMPFILE"
rm -f "$ORPHAN_TMPFILE"

# --- Report ---
echo ""

if (( ${#MISSING_FRONTMATTER[@]} > 0 )); then
    echo -e "${RED}Missing/Incomplete Front Matter (${#MISSING_FRONTMATTER[@]}):${NC}"
    for v in "${MISSING_FRONTMATTER[@]}"; do echo "  - $v"; done
    VIOLATIONS=$((VIOLATIONS + ${#MISSING_FRONTMATTER[@]}))
    echo ""
fi

if (( ${#MISSING_HEADER[@]} > 0 )); then
    echo -e "${RED}Missing 'Load when...' Header (${#MISSING_HEADER[@]}):${NC}"
    for v in "${MISSING_HEADER[@]}"; do echo "  - $v"; done
    VIOLATIONS=$((VIOLATIONS + ${#MISSING_HEADER[@]}))
    echo ""
fi

if (( ${#STALE_FILES[@]} > 0 )); then
    echo -e "${YELLOW}Stale Files — Past Review Date (${#STALE_FILES[@]}):${NC}"
    for v in "${STALE_FILES[@]}"; do echo "  - $v"; done
    VIOLATIONS=$((VIOLATIONS + ${#STALE_FILES[@]}))
    echo ""
fi

if (( ${#NOT_IN_INDEX[@]} > 0 )); then
    echo -e "${RED}Not Listed in Folder Index (${#NOT_IN_INDEX[@]}):${NC}"
    for v in "${NOT_IN_INDEX[@]}"; do echo "  - $v"; done
    VIOLATIONS=$((VIOLATIONS + ${#NOT_IN_INDEX[@]}))
    echo ""
fi

if (( ${#OVERSIZED[@]} > 0 )); then
    echo -e "${YELLOW}Oversized Files (${#OVERSIZED[@]}):${NC}"
    for v in "${OVERSIZED[@]}"; do echo "  - $v"; done
    VIOLATIONS=$((VIOLATIONS + ${#OVERSIZED[@]}))
    echo ""
fi

if (( ${#ORPHANED_INDEX[@]} > 0 )); then
    echo -e "${RED}Orphaned Index Entries (${#ORPHANED_INDEX[@]}):${NC}"
    for v in "${ORPHANED_INDEX[@]}"; do echo "  - $v"; done
    VIOLATIONS=$((VIOLATIONS + ${#ORPHANED_INDEX[@]}))
    echo ""
fi

if (( VIOLATIONS == 0 )); then
    echo -e "${GREEN}All checks passed. 0 violations.${NC}"
    exit 0
else
    echo -e "${RED}Total violations: $VIOLATIONS${NC}"
    exit 1
fi
