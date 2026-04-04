#!/usr/bin/env bash
#
# Normalize tags and categories in Hugo post front matter.
# Tags:       lowercase, kebab-case, plural countable nouns, merge synonyms.
# Categories: restricted to allowed set, merge unofficial → nearest match.
# Exits 0 if no changes, 1 if files were modified.

set -euo pipefail

POSTS_DIR="${1:-content/posts}"
CHANGED=0

# --- Tag config ---

TAG_SYNONYMS=(
  "food=dining"
  "restaurants=dining"
  "vegas dining=dining"
  "residency=residencies"
  "music residencies=residencies"
  "concert=concerts"
  "festival=festivals"
  "casino=casinos"
  "hotel=hotels"
  "lounge=lounges"
  "club=clubs"
  "strip=the-strip"
)

TAG_REMOVE=(
  "las vegas"
  "vegas"
  "events"
  "entertainment"
  "weekend"
)

# --- Category config ---

# Only these categories are allowed
ALLOWED_CATEGORIES=("events" "nightlife" "shows" "news")

# Map unofficial categories to official ones
CATEGORY_SYNONYMS=(
  "entertainment=events"
  "culture=events"
  "vegas life=events"
  "vegas insider=events"
)

# Categories to remove entirely (site-redundant)
CATEGORY_REMOVE=(
  "vegas"
  "local"
)

# --- Shared helpers ---

normalize_tag() {
  local tag="$1"

  tag=$(echo "$tag" | tr '[:upper:]' '[:lower:]')

  for pattern in "${TAG_REMOVE[@]}"; do
    if [[ "$tag" == "$pattern" ]]; then
      echo ""
      return
    fi
  done

  for entry in "${TAG_SYNONYMS[@]}"; do
    local src="${entry%%=*}"
    local dst="${entry##*=}"
    if [[ "$tag" == "$src" ]]; then
      tag="$dst"
      break
    fi
  done

  # Remove temporal tags matching year patterns like "spring 2026"
  if echo "$tag" | grep -qE '(^| )(20[0-9]{2})($| )'; then
    echo ""
    return
  fi

  tag=$(echo "$tag" | sed 's/ /-/g')
  tag=$(echo "$tag" | sed 's/[^a-z0-9-]//g')
  tag=$(echo "$tag" | sed 's/--*/-/g; s/^-//; s/-$//')

  echo "$tag"
}

normalize_category() {
  local cat="$1"

  cat=$(echo "$cat" | tr '[:upper:]' '[:lower:]')

  for pattern in "${CATEGORY_REMOVE[@]}"; do
    if [[ "$cat" == "$pattern" ]]; then
      echo ""
      return
    fi
  done

  for entry in "${CATEGORY_SYNONYMS[@]}"; do
    local src="${entry%%=*}"
    local dst="${entry##*=}"
    if [[ "$cat" == "$src" ]]; then
      cat="$dst"
      break
    fi
  done

  # Only emit if it's an allowed category
  for allowed in "${ALLOWED_CATEGORIES[@]}"; do
    if [[ "$cat" == "$allowed" ]]; then
      echo "$cat"
      return
    fi
  done

  # Unknown category — drop it
  echo ""
}

# Process a YAML inline array line (tags: [...] or categories: [...])
# Args: $1=line, $2=normalize_function_name, $3=field_name
normalize_array_line() {
  local line="$1"
  local normalize_fn="$2"
  local field="$3"

  local raw_values
  raw_values=$(echo "$line" | sed "s/^${field}: *\\[//; s/\\] *$//")

  local new_values=()
  local seen=()

  IFS=',' read -ra val_array <<< "$raw_values"
  for raw_val in "${val_array[@]}"; do
    local val
    val=$(echo "$raw_val" | sed 's/^ *"//; s/" *$//; s/^ *//; s/ *$//')

    local normalized
    normalized=$("$normalize_fn" "$val")

    if [[ -n "$normalized" ]]; then
      local is_dup=0
      for s in "${seen[@]+"${seen[@]}"}"; do
        if [[ "$s" == "$normalized" ]]; then
          is_dup=1
          break
        fi
      done
      if [[ $is_dup -eq 0 ]]; then
        new_values+=("$normalized")
        seen+=("$normalized")
      fi
    fi
  done

  local values_str=""
  for i in "${!new_values[@]}"; do
    if [[ $i -gt 0 ]]; then
      values_str+=", "
    fi
    values_str+="\"${new_values[$i]}\""
  done
  echo "${field}: [${values_str}]"
}

process_file() {
  local file="$1"
  local in_frontmatter=0
  local frontmatter_count=0
  local modified=0
  local tmpfile
  tmpfile=$(mktemp)

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      frontmatter_count=$((frontmatter_count + 1))
      if [[ $frontmatter_count -eq 1 ]]; then
        in_frontmatter=1
      else
        in_frontmatter=0
      fi
      echo "$line" >> "$tmpfile"
      continue
    fi

    if [[ $in_frontmatter -eq 1 ]] && echo "$line" | grep -q '^tags:'; then
      local new_line
      new_line=$(normalize_array_line "$line" normalize_tag "tags")
      if [[ "$new_line" != "$line" ]]; then
        modified=1
      fi
      echo "$new_line" >> "$tmpfile"
    elif [[ $in_frontmatter -eq 1 ]] && echo "$line" | grep -q '^categories:'; then
      local new_line
      new_line=$(normalize_array_line "$line" normalize_category "categories")
      if [[ "$new_line" != "$line" ]]; then
        modified=1
      fi
      echo "$new_line" >> "$tmpfile"
    else
      echo "$line" >> "$tmpfile"
    fi
  done < "$file"

  if [[ $modified -eq 1 ]]; then
    cp "$tmpfile" "$file"
    echo "Fixed: $file"
    CHANGED=1
  fi
  rm -f "$tmpfile"
}

for file in "$POSTS_DIR"/*.md; do
  [[ "$(basename "$file")" == "_index.md" ]] && continue
  [[ -f "$file" ]] || continue
  process_file "$file"
done

exit $CHANGED
