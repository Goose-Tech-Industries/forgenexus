import type { Reroute } from '@sveltejs/kit';

export const reroute: Reroute = ({ url }) => {
  if (url.hostname === 'calamity.tcgaming.quest' && url.pathname === '/') {
    return '/calamity';
  }
};
