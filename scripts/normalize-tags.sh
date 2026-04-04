#!/usr/bin/env bash
#
# Normalize tags in Hugo post front matter.
# Rules: lowercase, kebab-case, plural countable nouns, merge synonyms.
# Exits 0 if no changes, 1 if files were modified.

set -euo pipefail

POSTS_DIR="${1:-content/posts}"
CHANGED=0

# Synonym map: "source=target"
SYNONYMS=(
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

# Tags to remove entirely (site-redundant, category duplicates, temporal)
REMOVE_PATTERNS=(
  "las vegas"
  "vegas"
  "events"
  "entertainment"
  "weekend"
)

normalize_tag() {
  local tag="$1"

  # Lowercase
  tag=$(echo "$tag" | tr '[:upper:]' '[:lower:]')

  # Check removals
  for pattern in "${REMOVE_PATTERNS[@]}"; do
    if [[ "$tag" == "$pattern" ]]; then
      echo ""
      return
    fi
  done

  # Apply synonym mapping (before kebab-case so multi-word sources match)
  for entry in "${SYNONYMS[@]}"; do
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

  # Convert spaces to hyphens (kebab-case)
  tag=$(echo "$tag" | sed 's/ /-/g')

  # Remove any characters that aren't lowercase alphanumeric or hyphens
  tag=$(echo "$tag" | sed 's/[^a-z0-9-]//g')

  # Collapse multiple hyphens
  tag=$(echo "$tag" | sed 's/--*/-/g; s/^-//; s/-$//')

  echo "$tag"
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
      # Extract tags from the YAML array
      local raw_tags
      raw_tags=$(echo "$line" | sed 's/^tags: *\[//; s/\] *$//')

      local new_tags=()
      local seen=()

      # Split on comma, process each tag
      IFS=',' read -ra tag_array <<< "$raw_tags"
      for raw_tag in "${tag_array[@]}"; do
        # Trim whitespace and quotes
        local tag
        tag=$(echo "$raw_tag" | sed 's/^ *"//; s/" *$//; s/^ *//; s/ *$//')

        local normalized
        normalized=$(normalize_tag "$tag")

        # Skip empty (removed) tags and duplicates
        if [[ -n "$normalized" ]]; then
          local is_dup=0
          for s in "${seen[@]+"${seen[@]}"}"; do
            if [[ "$s" == "$normalized" ]]; then
              is_dup=1
              break
            fi
          done
          if [[ $is_dup -eq 0 ]]; then
            new_tags+=("$normalized")
            seen+=("$normalized")
          fi
        fi
      done

      # Rebuild the tags line
      local tags_str=""
      for i in "${!new_tags[@]}"; do
        if [[ $i -gt 0 ]]; then
          tags_str+=", "
        fi
        tags_str+="\"${new_tags[$i]}\""
      done
      local new_line="tags: [${tags_str}]"

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
