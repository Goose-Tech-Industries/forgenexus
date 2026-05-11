/**
 * Lightweight code syntax highlighting for ForgeNexus.
 * Handles [code=lang]...[/code] BBCode and ```lang markdown blocks.
 * Uses regex-based token highlighting — no external dependency.
 */

const LANG_KEYWORDS: Record<string, { keywords: string[]; builtins: string[] }> = {
  js: {
    keywords: ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'class', 'extends', 'import', 'export', 'from', 'default', 'new', 'this', 'async', 'await', 'try', 'catch', 'throw', 'switch', 'case', 'break', 'continue', 'typeof', 'instanceof', 'of', 'in', 'yield'],
    builtins: ['console', 'document', 'window', 'Array', 'Object', 'String', 'Number', 'Boolean', 'Promise', 'Map', 'Set', 'JSON', 'Math', 'Date', 'RegExp', 'Error', 'null', 'undefined', 'true', 'false']
  },
  ts: {
    keywords: ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'class', 'extends', 'import', 'export', 'from', 'default', 'new', 'this', 'async', 'await', 'try', 'catch', 'throw', 'interface', 'type', 'enum', 'implements', 'readonly', 'as', 'keyof', 'typeof', 'switch', 'case'],
    builtins: ['console', 'Array', 'Object', 'String', 'Number', 'Boolean', 'Promise', 'Map', 'Set', 'Record', 'Partial', 'Required', 'void', 'never', 'any', 'unknown', 'null', 'undefined', 'true', 'false']
  },
  python: {
    keywords: ['def', 'class', 'return', 'if', 'elif', 'else', 'for', 'while', 'import', 'from', 'as', 'try', 'except', 'finally', 'raise', 'with', 'yield', 'lambda', 'pass', 'break', 'continue', 'and', 'or', 'not', 'in', 'is', 'global', 'nonlocal', 'assert', 'async', 'await'],
    builtins: ['print', 'len', 'range', 'str', 'int', 'float', 'list', 'dict', 'set', 'tuple', 'bool', 'None', 'True', 'False', 'self', 'super', 'type', 'isinstance', 'enumerate', 'zip', 'map', 'filter', 'sorted', 'open']
  },
  elixir: {
    keywords: ['def', 'defp', 'defmodule', 'do', 'end', 'if', 'else', 'unless', 'case', 'cond', 'when', 'fn', 'use', 'import', 'alias', 'require', 'with', 'for', 'raise', 'try', 'rescue', 'catch', 'after', 'receive', 'send', 'spawn'],
    builtins: ['IO', 'Enum', 'Map', 'List', 'String', 'Kernel', 'GenServer', 'Agent', 'Task', 'Supervisor', 'nil', 'true', 'false', 'self', 'Repo', 'Ecto']
  },
  css: {
    keywords: ['@media', '@keyframes', '@import', '@font-face', '@supports', '!important'],
    builtins: ['display', 'position', 'color', 'background', 'border', 'margin', 'padding', 'font', 'width', 'height', 'flex', 'grid', 'transform', 'transition', 'animation', 'opacity', 'overflow', 'z-index']
  },
  html: {
    keywords: ['DOCTYPE', 'html', 'head', 'body', 'div', 'span', 'p', 'a', 'img', 'input', 'button', 'form', 'table', 'tr', 'td', 'th', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'script', 'style', 'link', 'meta', 'title', 'section', 'nav', 'header', 'footer', 'main', 'article'],
    builtins: ['class', 'id', 'href', 'src', 'alt', 'type', 'value', 'name', 'placeholder', 'style', 'onclick', 'data']
  },
  sql: {
    keywords: ['SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'UPDATE', 'DELETE', 'CREATE', 'ALTER', 'DROP', 'TABLE', 'INDEX', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'ON', 'AND', 'OR', 'NOT', 'IN', 'LIKE', 'ORDER', 'BY', 'GROUP', 'HAVING', 'LIMIT', 'OFFSET', 'AS', 'SET', 'VALUES', 'NULL', 'IS', 'DISTINCT', 'UNION', 'EXISTS', 'BETWEEN', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END'],
    builtins: ['COUNT', 'SUM', 'AVG', 'MAX', 'MIN', 'COALESCE', 'CAST', 'NOW', 'TRUE', 'FALSE']
  }
};

// Aliases
LANG_KEYWORDS['javascript'] = LANG_KEYWORDS['js'];
LANG_KEYWORDS['typescript'] = LANG_KEYWORDS['ts'];
LANG_KEYWORDS['py'] = LANG_KEYWORDS['python'];
LANG_KEYWORDS['ex'] = LANG_KEYWORDS['elixir'];

function highlightCode(code: string, lang: string): string {
  const escaped = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const config = LANG_KEYWORDS[lang.toLowerCase()];
  if (!config) return escaped;

  let result = escaped;

  // Strings (double and single quotes)
  result = result.replace(/(["'`])(?:(?!\1|\\).|\\.)*\1/g, '<span class="hl-string">$&</span>');

  // Comments (// and #)
  result = result.replace(/(\/\/.*$|#.*$)/gm, '<span class="hl-comment">$&</span>');

  // Numbers
  result = result.replace(/\b(\d+\.?\d*)\b/g, '<span class="hl-number">$1</span>');

  // Keywords
  const kwPattern = new RegExp(`\\b(${config.keywords.join('|')})\\b`, 'g');
  result = result.replace(kwPattern, '<span class="hl-keyword">$1</span>');

  // Builtins
  const biPattern = new RegExp(`\\b(${config.builtins.join('|')})\\b`, 'g');
  result = result.replace(biPattern, '<span class="hl-builtin">$1</span>');

  return result;
}

/**
 * Process text containing code blocks:
 * - [code=lang]...[/code] BBCode
 * - ```lang\n...\n``` Markdown
 * Returns HTML with highlighted code blocks.
 */
export function processCodeBlocks(html: string): string {
  // BBCode: [code=lang]...[/code]
  html = html.replace(/\[code(?:=(\w+))?\]([\s\S]*?)\[\/code\]/gi, (_match, lang, code) => {
    const language = lang || 'text';
    const highlighted = lang ? highlightCode(code.trim(), language) : code.trim().replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return `<div class="code-block"><div class="code-header"><span class="code-lang">${language}</span></div><pre><code>${highlighted}</code></pre></div>`;
  });

  // Markdown: ```lang\n...\n```
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_match, lang, code) => {
    const language = lang || 'text';
    const highlighted = lang ? highlightCode(code.trim(), language) : code.trim().replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return `<div class="code-block"><div class="code-header"><span class="code-lang">${language}</span></div><pre><code>${highlighted}</code></pre></div>`;
  });

  // Inline code: `...`
  html = html.replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>');

  return html;
}
