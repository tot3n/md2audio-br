#!/usr/bin/env bash
# ============================================================
# md2audio-br - Converte arquivos Markdown em audiobooks (MP3)
# usando vozes neurais da Microsoft (edge-tts). Foco em pt-BR.
#
# Uso:
#   md2audio                  # processa os .md da pasta atual
#   md2audio ~/pasta          # processa os .md da pasta indicada
#   md2audio arquivo.md       # processa UM arquivo apenas
#
# Requisitos: edge-tts (Python), pandoc, ffmpeg
# ============================================================

INPUT="${1:-.}"
VOICE="pt-BR-ThalitaMultilingualNeural"
RATE="+20%"    # velocidade da fala: +20% = 1.2x | +25% = 1.25x | +0% = normal
CHARS_POR_PEDACO=1800   # tamanho de cada pedaço de texto (~3 min de audio)

# ------------------------------------------------------------
# Localiza o edge-tts
# ------------------------------------------------------------
EDGE_TTS="${MD2AUDIO_EDGE:-}"
if [ -z "$EDGE_TTS" ]; then
    for candidato in "$HOME/md2audio/bin/edge-tts" "$HOME/.venvs/md2audio/bin/edge-tts" "$HOME/venvs/md2audio/bin/edge-tts"; do
        if [ -x "$candidato" ]; then
            EDGE_TTS="$candidato"
            break
        fi
    done
fi
if [ -z "$EDGE_TTS" ]; then
    EDGE_TTS="$(command -v edge-tts 2>/dev/null)"
fi
if [ -z "$EDGE_TTS" ]; then
    echo "ERRO: edge-tts nao encontrado."
    echo "Instale com: python3 -m venv ~/md2audio && source ~/md2audio/bin/activate && pip install edge-tts"
    exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ERRO: ffmpeg nao encontrado. Instale com: sudo apt install ffmpeg"
    exit 1
fi

echo "Usando edge-tts: $EDGE_TTS"
echo "Voz: $VOICE | Velocidade: $RATE"

# ------------------------------------------------------------
# Resolve o alvo: arquivo unico ou diretorio
# ------------------------------------------------------------
if [ -f "$INPUT" ] && [[ "$INPUT" == *.md ]]; then
    ARQUIVOS=("$INPUT")
    OUTPUT_DIR="$(cd "$(dirname "$INPUT")" && pwd)/audio_books"
else
    INPUT_DIR="$INPUT"
    OUTPUT_DIR="$INPUT_DIR/audio_books"
    if [ -d "$INPUT_DIR" ]; then
        mapfile -t ARQUIVOS < <(find "$INPUT_DIR" -maxdepth 1 -type f -name "*.md" | sort -V)
    else
        ARQUIVOS=()
    fi
fi

TOTAL=${#ARQUIVOS[@]}
if [ "$TOTAL" -eq 0 ]; then
    echo "Nenhum arquivo .md encontrado em: $INPUT"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo "Saida: $OUTPUT_DIR"
echo "Arquivos a processar: $TOTAL"
echo "=========================================="

# ------------------------------------------------------------
# UI: barra com percentual real (por pedaço gerado)
# ------------------------------------------------------------
barra() {  # barra <atual> <total>
    local atual=$1 total=$2
    local pct preenchido vazio i
    [ "$total" -gt 0 ] || total=1
    pct=$((atual * 100 / total))
    [ "$pct" -gt 100 ] && pct=100
    preenchido=$((pct / 5))
    vazio=$((20 - preenchido))
    printf "["
    for ((i = 0; i < preenchido; i++)); do printf "#"; done
    for ((i = 0; i < vazio; i++)); do printf "."; done
    printf "] %3d%%" "$pct"
}

TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ------------------------------------------------------------
# Converte UM arquivo .md em MP3 (com progresso por pedaço)
# ------------------------------------------------------------
converter_arquivo() {
    local file=$1 output_mp3=$2
    local tmp_txt="$TMP_DIR/texto.txt"
    local tmp_clean="$TMP_DIR/texto_limpo.txt"

    # 1. MD -> plain text
    pandoc "$file" -t plain --wrap=none -o "$tmp_txt" 2>/dev/null
    if [ ! -s "$tmp_txt" ]; then
        cp "$file" "$tmp_txt"
    fi

    # 2. Junta linhas soltas de paragrafos
    python3 -c '
import sys, re
with open(sys.argv[1], "r", encoding="utf-8") as f:
    text = f.read()
paragraphs = text.split("\n\n")
clean_paragraphs = [" ".join(p.split()) for p in paragraphs if p.strip()]
final_text = "\n\n".join(clean_paragraphs)
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write(final_text)
' "$tmp_txt" "$tmp_clean"

    # 3. Divide o texto em pedaços (~CHARS_POR_PEDACO), quebrando em parágrafos
    python3 -c '
import sys
LIMITE = int(sys.argv[3])
with open(sys.argv[1], "r", encoding="utf-8") as f:
    text = f.read()
pars = text.split("\n\n")
pedacos = []
atual = ""
for p in pars:
    if len(atual) + len(p) + 2 > LIMITE and atual:
        pedacos.append(atual)
        atual = p
    else:
        atual = (atual + "\n\n" + p) if atual else p
if atual:
    pedacos.append(atual)
if not pedacos:
    pedacos = [""]
import os
os.makedirs(sys.argv[2], exist_ok=True)
for i, ped in enumerate(pedacos):
    with open(f"{sys.argv[2]}/parte_{i:04d}.txt", "w", encoding="utf-8") as f:
        f.write(ped)
print(len(pedacos))
' "$tmp_clean" "$TMP_DIR/pedacos" "$CHARS_POR_PEDACO" > "$TMP_DIR/num_pedacos.txt"

    local num_pedacos
    num_pedacos=$(cat "$TMP_DIR/num_pedacos.txt")
    echo "  ($num_pedacos partes de ~$CHARS_POR_PEDACO chars)"

    # 4. Gera o audio de cada pedaço, atualizando a barra (progresso REAL)
    local lista_mp3="$TMP_DIR/lista.txt"
    : > "$lista_mp3"
    local i=0
    for parte in "$TMP_DIR"/pedacos/parte_*.txt; do
        i=$((i + 1))
        local parte_mp3="${parte%.txt}.mp3"
        "$EDGE_TTS" --voice "$VOICE" --rate "$RATE" -f "$parte" --write-media "$parte_mp3" 2>/dev/null
        if [ $? -eq 0 ] && [ -f "$parte_mp3" ]; then
            printf "\r  " 
            barra "$i" "$num_pedacos"
            echo "  parte $i/$num_pedacos"
            echo "file '$parte_mp3'" >> "$lista_mp3"
        else
            echo "  ✗ FALHA na parte $i/$num_pedacos de $filename"
            return 1
        fi
    done

    # 5. Concatena os MP3s
    ffmpeg -y -f concat -safe 0 -i "$lista_mp3" -c copy "$output_mp3" 2>/dev/null
    if [ $? -eq 0 ] && [ -f "$output_mp3" ]; then
        return 0
    else
        echo "  ✗ FALHA ao concatenar $filename"
        return 1
    fi
}

# ------------------------------------------------------------
# Loop principal
# ------------------------------------------------------------
concluidos=0
for file in "${ARQUIVOS[@]}"; do
    filename=$(basename "$file")
    basename_no_ext="${filename%.*}"
    output_mp3="$OUTPUT_DIR/${basename_no_ext}.mp3"

    echo ""
    echo "▶ [$((concluidos + 1))/$TOTAL] $filename"

    inicio=$(date +%s)
    if converter_arquivo "$file" "$output_mp3"; then
        fim=$(date +%s)
        concluidos=$((concluidos + 1))
        # barra geral de arquivos (0..TOTAL)
        printf "  "
        barra "$concluidos" "$TOTAL"
        echo "  ✓ $basename_no_ext.mp3 ($((fim - inicio))s)"
    else
        echo "  ✗ FALHA ao processar '$filename'"
    fi
done

echo ""
echo "=========================================="
echo "Concluido! $concluidos arquivo(s) em: $OUTPUT_DIR"
