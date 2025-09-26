#!/usr/bin/env bash
set -euo pipefail

# ---- Defaults (override via named args) ----
SENTENCE_DELIM="/"         # token for sentence boundaries (from .?!)
WORD_BOUNDARY='\\'        # token for word boundaries (from spaces) — default backslash
UNKNOWN_TOKEN="?"          # when decoding unknown Morse tokens

# ---- Parse args ----
TEXT_INPUT=""
for arg in "$@"; do
  case "$arg" in
    --sentence-delim=*)  SENTENCE_DELIM="${arg#*=}" ;;
    --word-boundary=*)   WORD_BOUNDARY="${arg#*=}" ;;
    --unknown=*)         UNKNOWN_TOKEN="${arg#*=}" ;;
    --help|-h)
      cat <<'EOF'
Usage: morse.sh [TEXT] [--sentence-delim=/] [--word-boundary=\] [--unknown=?]

If TEXT is provided, it will be processed instead of reading from STDIN.
Otherwise, reads from STDIN; writes to STDOUT.

Cleanup (always done first):
  1) Strip all newlines
  2) Replace non-space whitespace (tabs, CR, etc.) with a single space
  3) Collapse multiple spaces into one

Auto-detection:
  - If the cleaned input contains any letters or digits, it is treated as ENGLISH.
  - Otherwise it is treated as MORSE.

English path (then additional cleanup):
  - Replace . ! ? with SENTENCE_DELIM
  - Strip punctuation (keep only letters, digits, spaces, and SENTENCE_DELIM)
  - Collapse spaces, uppercase
  - Translate: letters/digits -> Morse; space -> WORD_BOUNDARY; SENTENCE_DELIM stays as-is
  - Morse letters are separated by single spaces

Morse path:
  - Tokens are split on spaces
  - WORD_BOUNDARY and SENTENCE_DELIM become spaces in English
  - Unknown tokens become --unknown (default "?")

Examples:
  ./morse.sh "Hello, world!"
  echo "Hello, world!  How are\tyou?" | ./morse.sh
  ./morse.sh ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."
  echo ".... . .-.. .-.. --- / .-- --- .-. .-.. -.." | ./morse.sh
  ./morse.sh "End. New sentence!" --sentence-delim="//" --word-boundary="\\"
Notes:
  - If you literally want a backslash as the word boundary, the default already does that.
    If you pass it explicitly, quote/escape it like: --word-boundary="\\"
EOF
      exit 0
      ;;
    --*)
      # Skip option arguments, they're handled above
      ;;
    *)
      # This is a positional argument (text input)
      if [ -z "$TEXT_INPUT" ]; then
        TEXT_INPUT="$arg"
      fi
      ;;
  esac
done

# ---- Get input (from command line or stdin) and do base normalization ----
if [ -n "$TEXT_INPUT" ]; then
  INPUT="$TEXT_INPUT"
else
  INPUT=$(cat)
fi

# 1) strip newlines
NORM="${INPUT//$'\n'/}"
# 2) non-space whitespace -> space
NORM="$(printf '%s' "$NORM" | tr '\t\r\f\v' '    ')"
# 3) collapse multiple spaces
NORM="$(printf '%s' "$NORM" | tr -s ' ')"

# ---- Auto-detect: English if any letter or digit remains; else Morse ----
if printf '%s' "$NORM" | grep -qi '[[:alnum:]]'; then
  # =========================
  # ===== ENGLISH -> CW =====
  # =========================

  # Replace sentence boundaries with placeholder first, so we can safely strip punctuation.
  PLACEHOLDER=$'\x1E'  # ASCII RS as a safe sentinel unlikely to appear
  # 3a) Replace . ! ? (one or more) with placeholder
  NORM2="$(printf '%s' "$NORM" | sed -E 's/[.!?]+/'"$PLACEHOLDER"'/g')"
  # 3b) Strip punctuation (keep only letters, digits, and space)
  NORM2="$(printf '%s' "$NORM2" | sed -E 's/[^A-Za-z0-9 '"$PLACEHOLDER"']+//g')"
  # 3c) Collapse spaces again (in case stripping created double spaces)
  NORM2="$(printf '%s' "$NORM2" | tr -s ' ')"
  # 3d) Uppercase
  NORM2="$(printf '%s' "$NORM2" | tr '[:lower:]' '[:upper:]')"
  # 3e) Swap placeholder to the configured sentence delimiter
  NORM2="${NORM2//"$PLACEHOLDER"/$SENTENCE_DELIM}"

  # Replace backslashes in word boundary with safe placeholder for consistent output
  BACKSLASH_PLACEHOLDER=$'\x1F'  # ASCII US as a safe sentinel
  WORD_BOUNDARY_SAFE="${WORD_BOUNDARY//\\/$BACKSLASH_PLACEHOLDER}"

  awk -v txt="$NORM2" -v sdel="$SENTENCE_DELIM" -v wdel="$WORD_BOUNDARY_SAFE" '
    BEGIN {
      m["A"]=".-";   m["B"]="-..."; m["C"]="-.-."; m["D"]="-..";  m["E"]=".";
      m["F"]="..-."; m["G"]="--.";  m["H"]="...."; m["I"]="..";   m["J"]=".---";
      m["K"]="-.-";  m["L"]=".-.."; m["M"]="--";   m["N"]="-.";   m["O"]="---";
      m["P"]=".--."; m["Q"]="--.-"; m["R"]=".-.";  m["S"]="...";  m["T"]="-";
      m["U"]="..-";  m["V"]="...-"; m["W"]=".--";  m["X"]="-..-"; m["Y"]="-.--";
      m["Z"]="--..";
      m["0"]="-----"; m["1"]=".----"; m["2"]="..---"; m["3"]="...--"; m["4"]="....-";
      m["5"]="....."; m["6"]="-...."; m["7"]="--..."; m["8"]="---.."; m["9"]="----.";

      out="";
      n = split(txt, ch, "");
      i = 1;
      while (i <= n) {
        # try to match multi-char sentence delimiter at current position
        if (length(sdel) && substr(txt, i, length(sdel)) == sdel) {
          if (length(out) && substr(out, length(out), 1) != " ") out = out " ";
          out = out sdel; i += length(sdel); continue;
        }
        # try to match multi-char word delimiter at current position (unlikely from English path,
        # but allowed if user chose multi-char word delimiter and it appears in text)
        if (length(wdel) && substr(txt, i, length(wdel)) == wdel) {
          if (length(out) && substr(out, length(out), 1) != " ") out = out " ";
          out = out wdel; i += length(wdel); continue;
        }

        c = ch[i];
        if (c == " ") {
          if (length(out) && substr(out, length(out), 1) != " ") out = out " ";
          out = out wdel;  # word boundary
        } else if (c in m) {
          if (length(out) && substr(out, length(out), 1) != " ") out = out " ";
          out = out m[c];
        } # else ignore
        i++;
      }
      print out;
    }
  '
else
  # =========================
  # ===== CW -> ENGLISH =====
  # =========================

  # Replace backslashes with a safe placeholder to avoid awk escape sequence warnings
  BACKSLASH_PLACEHOLDER=$'\x1F'  # ASCII US as a safe sentinel
  NORM_SAFE="${NORM//\\/$BACKSLASH_PLACEHOLDER}"
  WORD_BOUNDARY_SAFE="${WORD_BOUNDARY//\\/$BACKSLASH_PLACEHOLDER}"

  # Split on spaces; treat WORD_BOUNDARY and SENTENCE_DELIM as space.
  # (You can post-process to reinsert punctuation if desired.)
  awk -v sdel="$SENTENCE_DELIM" -v wdel="$WORD_BOUNDARY_SAFE" -v unknown="$UNKNOWN_TOKEN" -v line="$NORM_SAFE" '
    BEGIN {
      r[".-"]="A";   r["-..."]="B"; r["-.-."]="C"; r["-.."]="D";  r["."]="E";
      r["..-."]="F"; r["--."]="G";  r["...."]="H"; r[".."]="I";   r[".---"]="J";
      r["-.-"]="K";  r[".-.."]="L"; r["--"]="M";   r["-."]="N";   r["---"]="O";
      r[".--."]="P"; r["--.-"]="Q"; r[".-."]="R";  r["..."]="S";  r["-"]="T";
      r["..-"]="U";  r["...-"]="V"; r[".--"]="W";  r["-..-"]="X"; r["-.--"]="Y";
      r["--.."]="Z";
      r["-----"]="0"; r[".----"]="1"; r["..---"]="2"; r["...--"]="3"; r["....-"]="4";
      r["....."]="5"; r["-...."]="6"; r["--..."]="7"; r["---.."]="8"; r["----."]="9";

      # collapse multiple spaces (already mostly done)
      gsub(/[[:space:]]+/, " ", line);

      out="";
      n = split(line, tok, " ");
      for (i=1; i<=n; i++) {
        t = tok[i];
        if (t == "" ) continue;

        # If the token exactly matches either delimiter (they may be multi-char), treat as space.
        if (length(sdel) && t == sdel) { out = out " "; continue; }
        if (length(wdel) && t == wdel) { out = out " "; continue; }

        # Accept only dot/dash sequences as Morse letters
        if (t ~ /^[\.\-]+$/) {
          if (t in r) out = out r[t];
          else        out = out unknown;
        } else {
          # Unknown token (not a delimiter and not dot/dash) -> skip or emit unknown
          out = out unknown;
        }
      }
      print out;
    }
  '
fi
