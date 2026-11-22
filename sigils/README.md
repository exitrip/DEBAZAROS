# Sigils (sprite test material)

Seals of the Goetia demons from the table in the Wikipedia article
"List of sigils of demons" (https://en.wikipedia.org/wiki/List_of_sigils_of_demons).
The images are on Wikimedia Commons (`NN-<Name>_seal.png`), credited there to
S.L. MacGregor Mathers and Aleister Crowley (1904), licence: public domain.

- `orig/` - the Commons originals (450 x 450 RGBA, black lines on transparent).
  Only 16 of the 73: Wikimedia rate-limited the download (HTTP 429) on 2026-11-20.
- `sigil-NN-name.png` - sprites: white lines, alpha kept, padded to 256 x 256
  (ffmpeg: `lutrgb=r=255:g=255:b=255,scale=256:256,...,pad`).

On the board they are in `/media/debaz/img/` (sprite and image names are plain file
names: no folders). Load: `/sprite/<id>/load "sigil-01-bael.png"`, draw:
`/sprite/<id>/draw slot x y [scale] [angle] [alpha]`.
