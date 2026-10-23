# Credits and licences

## Engine
Made with Godot Engine 4.7.2 (https://godotengine.org), (c) Juan Linietsky, Ariel Manzur and the Godot Engine contributors, MIT licence. Godot is credited as a courtesy; the engine's own licence texts are bundled inside the exported game by Godot.

## Art and icons
All visual art in the game and the app icon, launcher icons, TV banner and splash are original placeholder work (flat shapes: a shepherd's crook and a star), drawn for this project (`icon.svg`, `icons/`, `tools/make-icons.py`). The concept pictures in `docs/concept/` are original project work and are not part of the game. They are not derived from the Godot logo. Painterly 2D art is planned for Milestone 4.

## Music
| File | Title | Author | Licence | Source |
|---|---|---|---|---|
| audio/music/a-new-town.mp3 | A New Town (RPG Theme) | cynicmusic (The Cynic Project) | CC0 1.0 | https://opengameart.org/content/a-new-town-rpg-theme |

## Sound effects
| File or folder | Pack | Author | Licence | Source |
|---|---|---|---|---|
| audio/effects/impact*.ogg, footstep*.ogg | Impact Sounds 1.0 (130 files; file names renamed from underscores to hyphens; licence text kept in audio/effects/license-kenney-impact-sounds.txt) | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| audio/effects/sheep-baa.ogg | Sheep Baa (OGG, from the Freesound recording "Sheep bleat.wav" by mikewest) | AntumDeluge (OpenGameArt); original recording mikewest | CC0 1.0 (both) | https://opengameart.org/node/132779 and https://freesound.org/s/414342/ |

In use: the music track, `sheep-baa.ogg` and the Kenney files listed in `data/audio.json` (stone throw and hit, hurt, harp and win bells and similar). The other Kenney files stay in the repository but are excluded from the exported game by `exclude_filter` in `export_presets.cfg`; they are CC0 like the rest. The Kenney licence text is kept next to the files in `audio/effects/license-kenney-impact-sounds.txt`.

## Narration
To be recorded by Andrew (original work); files will be named by line id under `audio/narration/` (the folder does not exist yet). Until then the game is silent where narration would play and the subtitles show.

## Fonts
No font is bundled; the engine default font is used (Open Sans through Godot, SIL OFL / Apache 2.0).

Credit is given as a courtesy for every CC0 item; none of them requires attribution.
