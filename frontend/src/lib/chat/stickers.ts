/**
 * Sticker packs — curated collections of Unicode/emoji art stickers.
 * No image assets needed — pure text/emoji combinations.
 */

export interface Sticker {
  id: string;
  emoji: string;
  label: string;
}

export interface StickerPack {
  id: string;
  name: string;
  icon: string;
  stickers: Sticker[];
}

export const STICKER_PACKS: StickerPack[] = [
  {
    id: 'reactions', name: 'Reactions', icon: '😀',
    stickers: [
      { id: 'r1', emoji: '😂', label: 'Laughing' },
      { id: 'r2', emoji: '🤣', label: 'ROFL' },
      { id: 'r3', emoji: '😭', label: 'Crying' },
      { id: 'r4', emoji: '🥺', label: 'Pleading' },
      { id: 'r5', emoji: '😍', label: 'Heart eyes' },
      { id: 'r6', emoji: '🤯', label: 'Mind blown' },
      { id: 'r7', emoji: '😱', label: 'Shocked' },
      { id: 'r8', emoji: '🥳', label: 'Party' },
      { id: 'r9', emoji: '😤', label: 'Angry' },
      { id: 'r10', emoji: '🤔', label: 'Thinking' },
      { id: 'r11', emoji: '😏', label: 'Smirk' },
      { id: 'r12', emoji: '🙄', label: 'Eye roll' },
      { id: 'r13', emoji: '😴', label: 'Sleepy' },
      { id: 'r14', emoji: '🤡', label: 'Clown' },
      { id: 'r15', emoji: '💀', label: 'Dead' },
      { id: 'r16', emoji: '👀', label: 'Eyes' },
    ]
  },
  {
    id: 'gestures', name: 'Gestures', icon: '👋',
    stickers: [
      { id: 'g1', emoji: '👍', label: 'Thumbs up' },
      { id: 'g2', emoji: '👎', label: 'Thumbs down' },
      { id: 'g3', emoji: '👋', label: 'Wave' },
      { id: 'g4', emoji: '🤝', label: 'Handshake' },
      { id: 'g5', emoji: '👏', label: 'Clap' },
      { id: 'g6', emoji: '🙏', label: 'Please/Thanks' },
      { id: 'g7', emoji: '✌️', label: 'Peace' },
      { id: 'g8', emoji: '🤘', label: 'Rock on' },
      { id: 'g9', emoji: '💪', label: 'Flex' },
      { id: 'g10', emoji: '🫡', label: 'Salute' },
      { id: 'g11', emoji: '🤷', label: 'Shrug' },
      { id: 'g12', emoji: '🫂', label: 'Hug' },
    ]
  },
  {
    id: 'animals', name: 'Animals', icon: '🐱',
    stickers: [
      { id: 'a1', emoji: '🐱', label: 'Cat' },
      { id: 'a2', emoji: '🐶', label: 'Dog' },
      { id: 'a3', emoji: '🐸', label: 'Frog' },
      { id: 'a4', emoji: '🦊', label: 'Fox' },
      { id: 'a5', emoji: '🐻', label: 'Bear' },
      { id: 'a6', emoji: '🦄', label: 'Unicorn' },
      { id: 'a7', emoji: '🐧', label: 'Penguin' },
      { id: 'a8', emoji: '🦋', label: 'Butterfly' },
      { id: 'a9', emoji: '🐙', label: 'Octopus' },
      { id: 'a10', emoji: '🦈', label: 'Shark' },
      { id: 'a11', emoji: '🐼', label: 'Panda' },
      { id: 'a12', emoji: '🦖', label: 'Dino' },
    ]
  },
  {
    id: 'kaomoji', name: 'Kaomoji', icon: '(◕‿◕)',
    stickers: [
      { id: 'k1', emoji: '(◕‿◕)', label: 'Happy' },
      { id: 'k2', emoji: '(╥_╥)', label: 'Crying' },
      { id: 'k3', emoji: '(ノಠ益ಠ)ノ彡┻━┻', label: 'Table flip' },
      { id: 'k4', emoji: '┬─┬ノ( º _ ºノ)', label: 'Table back' },
      { id: 'k5', emoji: '¯\\_(ツ)_/¯', label: 'Shrug' },
      { id: 'k6', emoji: '( ͡° ͜ʖ ͡°)', label: 'Lenny' },
      { id: 'k7', emoji: 'ʕ•ᴥ•ʔ', label: 'Bear' },
      { id: 'k8', emoji: '(づ｡◕‿‿◕｡)づ', label: 'Gimme' },
      { id: 'k9', emoji: '(ง •̀_•́)ง', label: 'Fight me' },
      { id: 'k10', emoji: '(っ˘ω˘ς)', label: 'Comfy' },
      { id: 'k11', emoji: '♪(´ε` )', label: 'Whistling' },
      { id: 'k12', emoji: '(⌐■_■)', label: 'Cool' },
      { id: 'k13', emoji: '(ᵔᴥᵔ)', label: 'Cute' },
      { id: 'k14', emoji: '⊂(◉‿◉)つ', label: 'Hug' },
      { id: 'k15', emoji: '(☞ﾟヮﾟ)☞', label: 'Pointing' },
      { id: 'k16', emoji: 'ᕦ(ò_óˇ)ᕤ', label: 'Flexing' },
    ]
  },
  {
    id: 'ascii-big', name: 'Big Stickers', icon: '🎨',
    stickers: [
      { id: 'b1', emoji: '╔══╗\n║❤️║\n╚══╝', label: 'Heart box' },
      { id: 'b2', emoji: '★·.·´¯`·.·★\n  ☆ GG ☆\n★·.·´¯`·.·★', label: 'GG' },
      { id: 'b3', emoji: '┏━━━━━━━━┓\n┃  BRUH  ┃\n┗━━━━━━━━┛', label: 'Bruh' },
      { id: 'b4', emoji: '╭─────────╮\n│ SEND    │\n│  HELP   │\n╰─────────╯', label: 'Send Help' },
      { id: 'b5', emoji: '⣿⣿⣿⣿⣿⣿\n🏆 MVP 🏆\n⣿⣿⣿⣿⣿⣿', label: 'MVP' },
      { id: 'b6', emoji: '╔═══════╗\n║ R.I.P ║\n╚═══════╝', label: 'RIP' },
    ]
  },
];

export function getAllStickers(): Sticker[] {
  return STICKER_PACKS.flatMap(pack => pack.stickers);
}

export function searchStickers(query: string): Sticker[] {
  const q = query.toLowerCase();
  return getAllStickers().filter(s => s.label.toLowerCase().includes(q));
}
