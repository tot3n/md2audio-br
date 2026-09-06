# md2audio-br 🇧🇷

Converte arquivos **Markdown em audiobooks (MP3)** usando vozes neurais da Microsoft (edge-tts). Feito para ouvir textos técnicos — como módulos de cursos — enquanto faz outra coisa. **Foco em português do Brasil.**

> O sufixo `-br` reflete o diferencial: voz neural brasileira (Thalita) e documentação em pt-BR.

## Funcionalidades

• Processa todos os `.md` de uma pasta automaticamente (ordem cronológica)
• Voz neural **pt-BR-ThalitaMultilingualNeural** (lê siglas e termos em inglês com naturalidade)
• Junta linhas soltas de parágrafos — o TTS lê de forma fluida, sem "engasgos"
• Gera os MP3 em uma subpasta `audio_books/`
• Funciona com acentuação e UTF-8 normalmente

## Requisitos

- Linux (Nativo para Ubuntu)
- [edge-tts](https://github.com/rany2/edge-tts) (Python)
- [pandoc](https://pandoc.org/) (conversão MD → texto)
- [ffmpeg](https://ffmpeg.org/) (concatenação das partes de áudio)

### Instalação dos requisitos

```bash
# Cria um ambiente virtual e instala o edge-tts
python3 -m venv ~/md2audio
source ~/md2audio/bin/activate
pip install edge-tts
deactivate

# Instala o pandoc e o ffmpeg
sudo apt install pandoc ffmpeg
```

## Instalação do script

```bash
# Copia o script para uma pasta do PATH
sudo cp md2audio.sh /usr/local/bin/md2audio
sudo chmod +x /usr/local/bin/md2audio
```

> O script localiza o `edge-tts` automaticamente em `~/md2audio/bin/edge-tts` (o venv criado acima) — não precisa ativar o venv manualmente.

## Como Usar

```bash
# Processa todos os .md da pasta atual (ordem cronológica)
md2audio

# Processa uma pasta específica
md2audio ~/Documentos/cursos

# Processa UM arquivo apenas
md2audio ~/Documentos/cursos/Modulo5_PT-BR.md

# Saída: os MP3 ficam em <pasta>/audio_books/
```

## Progresso

- O texto de cada arquivo é dividido em **partes de ~1800 caracteres** (~3 min de áudio cada)
- A barra mostra o **progresso real**: cada parte concluída avança o percentual (14% → 28% → ... → 100%)
- Ao final, as partes são concatenadas num único MP3 (via ffmpeg)

> Bônus da divisão em partes: arquivos muito longos não estouram o limite do edge-tts, e se uma parte falhar, apenas ela é regerada.

## Personalização

Edite as variáveis no topo do script:

| Variável | Descrição | Padrão |
|---|---|---|
| `VOICE` | Voz do edge-tts | `pt-BR-ThalitaMultilingualNeural` |
| `RATE` | Velocidade da fala | `+20%` (1.2x) — use `+25%` p/ 1.25x, `+0%` p/ normal |
| `CHARS_POR_PEDACO` | Tamanho de cada parte gerada | `1800` |
| `INPUT` | Pasta/arquivo (ou 1º argumento) | pasta atual |

**Vozes pt-BR disponíveis:**

```bash
edge-tts --list-voices | grep pt-BR
```

- `pt-BR-AntonioNeural` (masculina)
- `pt-BR-FranciscaNeural` (feminina)
- `pt-BR-ThalitaMultilingualNeural` (feminina, multilíngue — recomendada)

## Como funciona

1. `pandoc` converte o Markdown para texto puro
2. Um pré-processamento em Python junta as linhas soltas de cada parágrafo (quebras de linha viram espaços; parágrafos `\n\n` são preservados)
3. `edge-tts` gera o MP3 com o texto contínuo

## Licença

MIT — use, modifique e compartilhe à vontade.
