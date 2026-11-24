# Sigils (sprite test material)

Seals of the Goetia demons from the table in the Wikipedia article
"List of sigils of demons" (https://en.wikipedia.org/wiki/List_of_sigils_of_demons).
The images are on Wikimedia Commons (`NN-<Name>_seal.png`), credited there to
S.L. MacGregor Mathers and Aleister Crowley (1904), licence: public domain.

- `orig/` - the Commons originals (450 x 450 RGBA, black lines on transparent):
  all 72 (35 Marchosias saved by hand) + `lucifer.svg`
  (Grimorium Verum; `lucifer.png` = Inkscape render, 1024 wide). Commons
  rate-limits scripted downloads (HTTP 429): use a User-Agent with a contact
  and one request every few seconds, stop at the first refusal. "Save image
  as" on a File: page saves the HTML page under the .png name.
- `orig/File_*.png`, `File_*.svg` - NOT images: saved Wikipedia File: pages
  (HTML). Each names its original under upload.wikimedia.org.
- `sigil-NN-name.png` - sprites (73: 00 = Lucifer, tall, so small in the square): white lines, alpha kept, padded to 256 x 256
  (ffmpeg: `format=rgba,lutrgb=r=255:g=255:b=255,scale=256:256:force_original_aspect_ratio=decrease:flags=lanczos,pad=256:256:(ow-iw)/2:(oh-ih)/2:color=black@0`).

On the board they are in `/media/debaz/img/` (sprite and image names are plain file
names: no folders). Load: `/sprite/<id>/load "sigil-01-bael.png"`, draw:
`/sprite/<id>/draw slot x y [scale] [angle] [alpha]`.

In the image (2026-11-23): recipe `debaz-sigils` installs the 73 sprites in
`/usr/share/debaz/img`; debaz-firstboot copies them once into
`/media/debaz/img` (missing names only; marker `/media/debaz/.debaz-sigils`,
so a deleted sigil does not come back).
