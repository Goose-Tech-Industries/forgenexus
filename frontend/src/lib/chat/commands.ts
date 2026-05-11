/**
 * Chat slash command engine — handles all /commands for DM and channel chat.
 *
 * Commands return either:
 *   { type: 'message', body: string }     — send this as a regular message
 *   { type: 'action', body: string }      — send as an action/emote (*user does thing*)
 *   { type: 'system', body: string }      — local-only system message
 *   { type: 'special', kind: string, ... } — special behavior (nudge, clear, edit, etc.)
 */

export interface CommandResult {
  type: 'message' | 'action' | 'system' | 'special';
  body?: string;
  kind?: string;
  data?: any;
}

export interface CommandDef {
  name: string;
  aliases?: string[];
  args?: string;
  description: string;
  category: 'fun' | 'utility' | 'action' | 'text' | 'moderation';
  handler: (args: string, ctx: CommandContext) => CommandResult | null;
}

export interface CommandContext {
  username: string;
  userId: string;
  conversationId: string;
  recipientName: string;
}

// ---- 8-Ball responses ----
const EIGHT_BALL = [
  'It is certain.', 'It is decidedly so.', 'Without a doubt.', 'Yes definitely.',
  'You may rely on it.', 'As I see it, yes.', 'Most likely.', 'Outlook good.',
  'Yes.', 'Signs point to yes.', 'Reply hazy, try again.', 'Ask again later.',
  'Better not tell you now.', 'Cannot predict now.', 'Concentrate and ask again.',
  "Don't count on it.", 'My reply is no.', 'My sources say no.',
  'Outlook not so good.', 'Very doubtful.'
];

// ---- Dice roller ----
function rollDice(notation: string): { total: number; rolls: number[]; notation: string } | null {
  const match = notation.match(/^(\d+)?d(\d+)([+-]\d+)?$/i);
  if (!match) return null;
  const count = Math.min(parseInt(match[1] || '1'), 100);
  const sides = Math.min(parseInt(match[2]), 1000);
  const modifier = parseInt(match[3] || '0');
  if (count < 1 || sides < 1) return null;
  const rolls: number[] = [];
  for (let i = 0; i < count; i++) {
    rolls.push(Math.floor(Math.random() * sides) + 1);
  }
  return { total: rolls.reduce((a, b) => a + b, 0) + modifier, rolls, notation };
}

// ---- Mock text (SpOnGeBoB) ----
function mockText(text: string): string {
  return text.split('').map((c, i) => i % 2 === 0 ? c.toLowerCase() : c.toUpperCase()).join('');
}

// ---- Morse code ----
const MORSE: Record<string, string> = {
  'a': '.-', 'b': '-...', 'c': '-.-.', 'd': '-..', 'e': '.', 'f': '..-.',
  'g': '--.', 'h': '....', 'i': '..', 'j': '.---', 'k': '-.-', 'l': '.-..',
  'm': '--', 'n': '-.', 'o': '---', 'p': '.--.', 'q': '--.-', 'r': '.-.',
  's': '...', 't': '-', 'u': '..-', 'v': '...-', 'w': '.--', 'x': '-..-',
  'y': '-.--', 'z': '--..', '0': '-----', '1': '.----', '2': '..---',
  '3': '...--', '4': '....-', '5': '.....', '6': '-....', '7': '--...',
  '8': '---..', '9': '----.', ' ': '/'
};

function toMorse(text: string): string {
  return text.toLowerCase().split('').map(c => MORSE[c] || c).join(' ');
}

// ---- Figlet-lite (block letters) ----
function toBigText(text: string): string {
  // Simple block-letter generator using Unicode block chars
  const chars: Record<string, string[]> = {
    ' ': ['   ', '   ', '   '],
  };
  // For non-mapped chars, just use the char itself large
  return `\u2588 ${text.toUpperCase()} \u2588`;
}

// ---- Random fortune/quote ----
const FORTUNES = [
  'A journey of a thousand miles begins with a single step.',
  'The best time to plant a tree was 20 years ago. The second best time is now.',
  'Be yourself; everyone else is already taken. — Oscar Wilde',
  'In the middle of difficulty lies opportunity. — Albert Einstein',
  'Stay hungry, stay foolish. — Steve Jobs',
  'The only way to do great work is to love what you do. — Steve Jobs',
  'Not all those who wander are lost. — J.R.R. Tolkien',
  'To be or not to be, that is the question. — Shakespeare',
  'I think, therefore I am. — Descartes',
  'That which does not kill us makes us stronger. — Nietzsche',
  'Life is what happens when you\'re busy making other plans. — John Lennon',
  'The unexamined life is not worth living. — Socrates',
];

// ---- RPS ----
function rps(choice: string): { userChoice: string; botChoice: string; result: string } {
  const choices = ['rock', 'paper', 'scissors'];
  const normalized = choice.toLowerCase().trim();
  if (!choices.includes(normalized)) return { userChoice: choice, botChoice: '', result: 'invalid' };
  const botChoice = choices[Math.floor(Math.random() * 3)];
  if (normalized === botChoice) return { userChoice: normalized, botChoice, result: 'tie' };
  const wins: Record<string, string> = { rock: 'scissors', paper: 'rock', scissors: 'paper' };
  return {
    userChoice: normalized,
    botChoice,
    result: wins[normalized] === botChoice ? 'win' : 'lose'
  };
}

const RPS_EMOJI: Record<string, string> = { rock: '\u270A', paper: '\u270B', scissors: '\u2702\uFE0F' };

// ---- Command definitions ----

export const COMMANDS: CommandDef[] = [
  // === FUN ===
  {
    name: 'nudge', aliases: ['buzz'], args: undefined,
    description: 'Shake the chat window (MSN style)',
    category: 'fun',
    handler: () => ({ type: 'special', kind: 'nudge' })
  },
  {
    name: '8ball', aliases: ['eightball', 'magic8ball'], args: '<question>',
    description: 'Ask the Magic 8-Ball a question',
    category: 'fun',
    handler: (args) => {
      const answer = EIGHT_BALL[Math.floor(Math.random() * EIGHT_BALL.length)];
      return { type: 'message', body: `\uD83C\uDFB1 **${args || 'Will I be lucky?'}** — ${answer}` };
    }
  },
  {
    name: 'roll', aliases: ['dice', 'r'], args: '<NdN±M>',
    description: 'Roll dice (e.g. /roll 2d6+3)',
    category: 'fun',
    handler: (args) => {
      const notation = args.trim() || '1d6';
      const result = rollDice(notation);
      if (!result) return { type: 'system', body: `Invalid dice notation: ${notation}. Use NdN format (e.g. 2d6, 1d20+5)` };
      const rollsStr = result.rolls.length > 1 ? ` [${result.rolls.join(', ')}]` : '';
      return { type: 'message', body: `\uD83C\uDFB2 rolled **${result.notation}** \u2192 **${result.total}**${rollsStr}` };
    }
  },
  {
    name: 'coinflip', aliases: ['coin', 'flip'], args: undefined,
    description: 'Flip a coin',
    category: 'fun',
    handler: () => {
      const result = Math.random() < 0.5 ? 'Heads' : 'Tails';
      return { type: 'message', body: `\uD83E\uDE99 Coin flip: **${result}**!` };
    }
  },
  {
    name: 'rps', aliases: ['rockpaperscissors'], args: '<rock|paper|scissors>',
    description: 'Play Rock Paper Scissors',
    category: 'fun',
    handler: (args) => {
      const { userChoice, botChoice, result } = rps(args);
      if (result === 'invalid') return { type: 'system', body: 'Choose rock, paper, or scissors.' };
      const emoji = (c: string) => RPS_EMOJI[c] || c;
      const verdict = result === 'tie' ? "It's a tie!" : result === 'win' ? 'You win!' : 'You lose!';
      return { type: 'message', body: `${emoji(userChoice)} vs ${emoji(botChoice)} — **${verdict}**` };
    }
  },
  {
    name: 'fortune', aliases: ['quote'], args: undefined,
    description: 'Get a random fortune or quote',
    category: 'fun',
    handler: () => {
      const quote = FORTUNES[Math.floor(Math.random() * FORTUNES.length)];
      return { type: 'message', body: `\uD83D\uDD2E ${quote}` };
    }
  },
  {
    name: 'choose', aliases: ['pick', 'random'], args: '<option1>, <option2>, ...',
    description: 'Randomly pick from a list of options',
    category: 'fun',
    handler: (args) => {
      const options = args.split(/[,|]/).map(s => s.trim()).filter(Boolean);
      if (options.length < 2) return { type: 'system', body: 'Provide at least 2 options separated by commas.' };
      const pick = options[Math.floor(Math.random() * options.length)];
      return { type: 'message', body: `\uD83C\uDFAF I choose: **${pick}**` };
    }
  },
  {
    name: 'rate', aliases: ['ratethis'], args: '<thing>',
    description: 'Rate something out of 10',
    category: 'fun',
    handler: (args) => {
      const rating = Math.floor(Math.random() * 11);
      const stars = '\u2B50'.repeat(Math.ceil(rating / 2));
      return { type: 'message', body: `I rate **${args || 'that'}** a **${rating}/10** ${stars}` };
    }
  },
  {
    name: 'slots', aliases: ['slot'], args: undefined,
    description: 'Pull the slot machine lever',
    category: 'fun',
    handler: () => {
      const symbols = ['\uD83C\uDF52', '\uD83C\uDF4B', '\uD83C\uDF4A', '\uD83C\uDF53', '\uD83D\uDC8E', '7\uFE0F\u20E3', '\uD83C\uDF40'];
      const r = () => symbols[Math.floor(Math.random() * symbols.length)];
      const s1 = r(), s2 = r(), s3 = r();
      const won = s1 === s2 && s2 === s3;
      const two = s1 === s2 || s2 === s3 || s1 === s3;
      const msg = won ? '\uD83C\uDF89 **JACKPOT!!!**' : two ? '\uD83D\uDE0F Close!' : 'Better luck next time!';
      return { type: 'message', body: `\uD83C\uDFB0 [ ${s1} | ${s2} | ${s3} ] ${msg}` };
    }
  },

  // === KAOMOJI / TEXT ART ===
  {
    name: 'shrug', args: undefined, description: '\u00AF\\_(\u30C4)_/\u00AF', category: 'text',
    handler: () => ({ type: 'message', body: '\u00AF\\_(\u30C4)_/\u00AF' })
  },
  {
    name: 'tableflip', args: undefined, description: '(\u256F\u00B0\u25A1\u00B0\uFF09\u256F\uFE35 \u253B\u2501\u253B', category: 'text',
    handler: () => ({ type: 'message', body: '(\u256F\u00B0\u25A1\u00B0\uFF09\u256F\uFE35 \u253B\u2501\u253B' })
  },
  {
    name: 'unflip', aliases: ['putback'], args: undefined, description: '\u252C\u2500\u252C\u30CE( \u00BA _ \u00BA\u30CE)', category: 'text',
    handler: () => ({ type: 'message', body: '\u252C\u2500\u252C\u30CE( \u00BA _ \u00BA\u30CE)' })
  },
  {
    name: 'lenny', args: undefined, description: '( \u0361\u00B0 \u035C\u0296 \u0361\u00B0)', category: 'text',
    handler: () => ({ type: 'message', body: '( \u0361\u00B0 \u035C\u0296 \u0361\u00B0)' })
  },
  {
    name: 'disapproval', aliases: ['look'], args: undefined, description: '\u0CA0_\u0CA0', category: 'text',
    handler: () => ({ type: 'message', body: '\u0CA0_\u0CA0' })
  },
  {
    name: 'bear', aliases: ['bearflip'], args: undefined, description: '\u0295\u2022\u1D25\u2022\u0294\u256F\uFE35\u253B\u2501\u253B', category: 'text',
    handler: () => ({ type: 'message', body: '\u0295\u2022\u1D25\u2022\u0294\u256F\uFE35\u253B\u2501\u253B' })
  },
  {
    name: 'donger', aliases: ['dong'], args: undefined, description: '\u30FD\u0F3C\u0E88\u0644\u035C\u0E88\u0F3D\uFF89', category: 'text',
    handler: () => ({ type: 'message', body: '\u30FD\u0F3C\u0E88\u0644\u035C\u0E88\u0F3D\uFF89' })
  },
  {
    name: 'fight', args: undefined, description: '(\u0E07\u2022\u0300_\u2022\u0301)\u0E07', category: 'text',
    handler: () => ({ type: 'message', body: '(\u0E07\u2022\u0300_\u2022\u0301)\u0E07' })
  },
  {
    name: 'sparkle', aliases: ['sparkles'], args: '<text>',
    description: 'Add sparkles around text',
    category: 'text',
    handler: (args) => ({ type: 'message', body: `\u2728 ${args || 'sparkle'} \u2728` })
  },

  // === TEXT TRANSFORM ===
  {
    name: 'mock', aliases: ['spongebob'], args: '<text>',
    description: 'SpOnGeBoB mOcKiNg TeXt',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: mockText(args) } : { type: 'system', body: 'Provide text to mock.' }
  },
  {
    name: 'upper', aliases: ['caps', 'yell'], args: '<text>',
    description: 'UPPERCASE TEXT',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: args.toUpperCase() } : { type: 'system', body: 'Provide text.' }
  },
  {
    name: 'lower', args: '<text>',
    description: 'lowercase text',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: args.toLowerCase() } : { type: 'system', body: 'Provide text.' }
  },
  {
    name: 'reverse', aliases: ['backwards'], args: '<text>',
    description: 'Reverse text',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: args.split('').reverse().join('') } : { type: 'system', body: 'Provide text.' }
  },
  {
    name: 'morse', args: '<text>',
    description: 'Convert to Morse code',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: `\u2503 ${toMorse(args)}` } : { type: 'system', body: 'Provide text.' }
  },
  {
    name: 'clap', args: '<text>',
    description: 'Add \uD83D\uDC4F between words',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: args.split(/\s+/).join(' \uD83D\uDC4F ') } : { type: 'system', body: 'Provide text.' }
  },
  {
    name: 'spoiler', aliases: ['hide'], args: '<text>',
    description: 'Hide text behind a spoiler',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: `||${args}||` } : { type: 'system', body: 'Provide text to hide.' }
  },
  {
    name: 'code', args: '<text>',
    description: 'Format as inline code',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: `\`${args}\`` } : { type: 'system', body: 'Provide text.' }
  },
  {
    name: 'codeblock', aliases: ['cb'], args: '<language> <code>',
    description: 'Format as a code block',
    category: 'text',
    handler: (args) => {
      const parts = args.split(/\s+/);
      const lang = parts[0] || '';
      const code = parts.slice(1).join(' ') || args;
      return { type: 'message', body: '```' + lang + '\n' + code + '\n```' };
    }
  },
  {
    name: 'big', aliases: ['large'], args: '<text>',
    description: 'Large block text',
    category: 'text',
    handler: (args) => args ? { type: 'message', body: toBigText(args) } : { type: 'system', body: 'Provide text.' }
  },

  // === ACTION / EMOTES ===
  {
    name: 'me', args: '<action>',
    description: 'Perform an action (IRC style)',
    category: 'action',
    handler: (args, ctx) => args ? { type: 'action', body: `*${ctx.username} ${args}*` } : { type: 'system', body: 'Describe an action.' }
  },
  {
    name: 'hug', args: '[user]',
    description: 'Give someone a hug',
    category: 'action',
    handler: (args, ctx) => ({ type: 'action', body: `*${ctx.username} hugs ${args || ctx.recipientName}* \uD83E\uDD17` })
  },
  {
    name: 'highfive', aliases: ['hi5'], args: '[user]',
    description: 'High five!',
    category: 'action',
    handler: (args, ctx) => ({ type: 'action', body: `*${ctx.username} high-fives ${args || ctx.recipientName}* \u270B` })
  },
  {
    name: 'slap', args: '[user] [with item]',
    description: 'Slap someone with a large trout',
    category: 'action',
    handler: (args, ctx) => {
      const target = args || ctx.recipientName;
      const items = ['a large trout', 'a wet noodle', 'a rubber chicken', 'a foam sword', 'a keyboard', 'the ban hammer'];
      const item = items[Math.floor(Math.random() * items.length)];
      return { type: 'action', body: `*${ctx.username} slaps ${target} around with ${item}*` };
    }
  },
  {
    name: 'wave', args: '[user]',
    description: 'Wave hello',
    category: 'action',
    handler: (args, ctx) => ({ type: 'action', body: `*${ctx.username} waves at ${args || ctx.recipientName}* \uD83D\uDC4B` })
  },
  {
    name: 'dance', args: undefined,
    description: 'Dance!',
    category: 'action',
    handler: (_, ctx) => {
      const dances = [
        `*${ctx.username} busts a move* \uD83D\uDD7A`,
        `*${ctx.username} does the robot* \uD83E\uDD16`,
        `*${ctx.username} moonwalks across the chat* \uD83C\uDF19`,
        `*${ctx.username} does the Macarena* \uD83D\uDC83`,
      ];
      return { type: 'action', body: dances[Math.floor(Math.random() * dances.length)] };
    }
  },
  {
    name: 'cry', args: undefined,
    description: 'Cry',
    category: 'action',
    handler: (_, ctx) => ({ type: 'action', body: `*${ctx.username} cries* \uD83D\uDE2D` })
  },
  {
    name: 'facepalm', aliases: ['fp'], args: undefined,
    description: 'Facepalm',
    category: 'action',
    handler: (_, ctx) => ({ type: 'action', body: `*${ctx.username} facepalms* \uD83E\uDD26` })
  },

  // === UTILITY ===
  {
    name: 'clear', args: undefined,
    description: 'Clear local chat history',
    category: 'utility',
    handler: () => ({ type: 'special', kind: 'clear' })
  },
  {
    name: 'timestamp', aliases: ['time', 'now'], args: undefined,
    description: 'Insert current date/time',
    category: 'utility',
    handler: () => ({ type: 'message', body: `\uD83D\uDD52 ${new Date().toLocaleString()}` })
  },
  {
    name: 'countdown', args: '<seconds>',
    description: 'Start a countdown timer',
    category: 'utility',
    handler: (args) => {
      const secs = parseInt(args);
      if (!secs || secs < 1 || secs > 300) return { type: 'system', body: 'Provide seconds (1-300).' };
      return { type: 'special', kind: 'countdown', data: { seconds: secs } };
    }
  },
  {
    name: 'poll', aliases: ['vote'], args: '<question> | <option1> | <option2> ...',
    description: 'Create a quick poll',
    category: 'utility',
    handler: (args) => {
      const parts = args.split('|').map(s => s.trim()).filter(Boolean);
      if (parts.length < 3) return { type: 'system', body: 'Format: /poll Question | Option 1 | Option 2 | ...' };
      const question = parts[0];
      const options = parts.slice(1);
      const emojis = ['\uD83C\uDD70\uFE0F', '\uD83C\uDD71\uFE0F', '\uD83C\uDD72\uFE0F', '\uD83C\uDD73\uFE0F', '\uD83C\uDD74\uFE0F', '\uD83C\uDD75\uFE0F'];
      const optionLines = options.map((o, i) => `${emojis[i] || `${i + 1}.`} ${o}`).join('\n');
      return { type: 'message', body: `\uD83D\uDCCA **Poll: ${question}**\n${optionLines}` };
    }
  },
  {
    name: 'remind', args: '<minutes> <message>',
    description: 'Set a reminder (local)',
    category: 'utility',
    handler: (args) => {
      const match = args.match(/^(\d+)\s+(.+)/);
      if (!match) return { type: 'system', body: 'Format: /remind <minutes> <message>' };
      const mins = parseInt(match[1]);
      if (mins < 1 || mins > 1440) return { type: 'system', body: 'Minutes must be 1-1440.' };
      return { type: 'special', kind: 'remind', data: { minutes: mins, message: match[2] } };
    }
  },
  {
    name: 'status', args: '<text>',
    description: 'Set your custom status',
    category: 'utility',
    handler: (args) => args ? { type: 'special', kind: 'status', data: { text: args } } : { type: 'system', body: 'Provide status text.' }
  },
  {
    name: 'afk', aliases: ['away', 'brb'], args: '[message]',
    description: 'Set yourself as away',
    category: 'utility',
    handler: (args, ctx) => {
      const msg = args || 'Away from keyboard';
      return { type: 'special', kind: 'afk', data: { message: msg } };
    }
  },
  {
    name: 'edit', args: '<new text>',
    description: 'Edit your last message',
    category: 'utility',
    handler: (args) => args ? { type: 'special', kind: 'edit', data: { body: args } } : { type: 'system', body: 'Provide the new message text.' }
  },
  {
    name: 'delete', aliases: ['del', 'unsend'], args: undefined,
    description: 'Delete your last message',
    category: 'utility',
    handler: () => ({ type: 'special', kind: 'delete' })
  },
  {
    name: 'react', args: '<emoji>',
    description: 'React to the last message',
    category: 'utility',
    handler: (args) => args ? { type: 'special', kind: 'react', data: { emoji: args.trim() } } : { type: 'system', body: 'Provide an emoji.' }
  },
  {
    name: 'help', aliases: ['commands', '?'], args: '[command]',
    description: 'Show available commands',
    category: 'utility',
    handler: (args) => {
      if (args) {
        const cmd = findCommand(args);
        if (cmd) {
          return { type: 'system', body: `/${cmd.name}${cmd.args ? ' ' + cmd.args : ''} — ${cmd.description}${cmd.aliases ? ` (aliases: ${cmd.aliases.map(a => '/' + a).join(', ')})` : ''}` };
        }
        return { type: 'system', body: `Unknown command: /${args}` };
      }
      return { type: 'special', kind: 'help' };
    }
  },
];

// ---- Lookup ----

const commandMap = new Map<string, CommandDef>();
for (const cmd of COMMANDS) {
  commandMap.set(cmd.name, cmd);
  if (cmd.aliases) {
    for (const alias of cmd.aliases) {
      commandMap.set(alias, cmd);
    }
  }
}

export function findCommand(name: string): CommandDef | undefined {
  return commandMap.get(name.toLowerCase());
}

/** Execute a slash command. Returns null if not a recognized command. */
export function executeCommand(input: string, ctx: CommandContext): CommandResult | null {
  if (!input.startsWith('/')) return null;
  const spaceIdx = input.indexOf(' ');
  const name = (spaceIdx > 0 ? input.slice(1, spaceIdx) : input.slice(1)).toLowerCase();
  const args = spaceIdx > 0 ? input.slice(spaceIdx + 1).trim() : '';

  const cmd = commandMap.get(name);
  if (!cmd) return null;

  return cmd.handler(args, ctx);
}

/** Get autocomplete suggestions for partial command input */
export function getCommandSuggestions(partial: string): CommandDef[] {
  const query = partial.toLowerCase().replace(/^\//, '');
  if (!query) return COMMANDS;
  return COMMANDS.filter(cmd => {
    if (cmd.name.startsWith(query)) return true;
    return cmd.aliases?.some(a => a.startsWith(query)) ?? false;
  });
}

/** Get commands grouped by category */
export function getCommandsByCategory(): Record<string, CommandDef[]> {
  const groups: Record<string, CommandDef[]> = {};
  for (const cmd of COMMANDS) {
    if (!groups[cmd.category]) groups[cmd.category] = [];
    groups[cmd.category].push(cmd);
  }
  return groups;
}
