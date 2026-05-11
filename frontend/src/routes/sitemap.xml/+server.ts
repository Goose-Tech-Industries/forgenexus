import type { RequestHandler } from './$types';

const SITE = 'https://forum.tcgaming.quest';
const API = 'http://api:4000/api';

interface ForumLite { id: string; slug?: string; updated_at?: string }
interface ThreadLite { id: string; slug?: string; updated_at?: string }

async function safeFetchList<T>(url: string, key: string): Promise<T[]> {
  try {
    const res = await fetch(url, { headers: { accept: 'application/json' } });
    if (!res.ok) return [];
    const data = await res.json();
    const list = data[key];
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

function urlEntry(loc: string, lastmod?: string, changefreq = 'weekly', priority = 0.5): string {
  const lm = lastmod ? `<lastmod>${lastmod}</lastmod>` : '';
  return `<url><loc>${loc}</loc>${lm}<changefreq>${changefreq}</changefreq><priority>${priority}</priority></url>`;
}

export const GET: RequestHandler = async () => {
  const [forums, threads] = await Promise.all([
    safeFetchList<ForumLite>(`${API}/forums`, 'forums'),
    safeFetchList<ThreadLite>(`${API}/threads/recent?limit=500`, 'threads')
  ]);

  const staticPages = [
    urlEntry(`${SITE}/`, undefined, 'daily', 1.0),
    urlEntry(`${SITE}/forums`, undefined, 'hourly', 0.9),
    urlEntry(`${SITE}/feed`, undefined, 'hourly', 0.7),
    urlEntry(`${SITE}/discover`, undefined, 'daily', 0.7),
    urlEntry(`${SITE}/terms`, undefined, 'monthly', 0.3),
    urlEntry(`${SITE}/privacy`, undefined, 'monthly', 0.3),
    urlEntry(`${SITE}/rules`, undefined, 'monthly', 0.3)
  ];

  const forumUrls = forums.map((f) =>
    urlEntry(`${SITE}/forums/${f.slug ?? f.id}`, f.updated_at, 'hourly', 0.8)
  );
  const threadUrls = threads.map((t) =>
    urlEntry(`${SITE}/threads/${t.slug ?? t.id}`, t.updated_at, 'daily', 0.6)
  );

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${[...staticPages, ...forumUrls, ...threadUrls].join('\n')}
</urlset>`;

  return new Response(xml, {
    headers: {
      'content-type': 'application/xml; charset=utf-8',
      'cache-control': 'public, max-age=3600'
    }
  });
};
