import { Router, Request, Response } from 'express';

const router = Router();

export interface TrackData {
  id: string;
  title: string;
  artist: string;
  album: string;
  coverUrl: string;
  audioUrl: string;
  duration: number;
  category: string;
  usesCount: number;
  isVerified: boolean;
  isTrending: boolean;
  tags: string[];
}

// In-memory cache for ultra-fast response times
const cache: Record<string, { data: TrackData[]; timestamp: number }> = {};
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 Hour

// Preset search queries for campus categories
const CATEGORY_QUERIES: Record<string, string> = {
  Trending: 'Afrobeats viral hits 2026',
  Afrobeats: 'Afrobeats Burna Asake Rema Wizkid Ayra Starr',
  Amapiano: 'Amapiano party dance hits 2026',
  'Campus Vibes': 'Naija campus party dance hits',
  'Viral Reels': 'TikTok viral sound trending reels',
  'Chill & Lo-Fi': 'Lofi chill beats study relaxing instrumental',
  'Hip-Hop & Drill': 'Odumodublvck Shallipopi drill rap hiphop',
  'Gospel & Praise': 'Nigerian gospel praise worship Moses Bliss',
  'R&B & Soul': 'Afrosoul R&B love songs Omah Lay Tems',
};

// Rich curated catalog of real African & Global hits with working official previews
const CURATED_TRACKS: TrackData[] = [
  {
    id: 'curated_burna_city_boys',
    title: 'City Boys',
    artist: 'Burna Boy',
    album: 'I Told Them...',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
    audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/14/ec/c0/14ecc0c4-95eb-959c-6fc2-3c1e8787f711/mzaf_16886477161621644788.plus.aac.p.m4a',
    duration: 30,
    category: 'Afrobeats',
    usesCount: 489000,
    isVerified: true,
    isTrending: true,
    tags: ['afrobeats', 'burnaboy', 'trending', 'abuad', 'campus'],
  },
  {
    id: 'curated_asake_lonely',
    title: 'Lonely At The Top',
    artist: 'Asake',
    album: 'Work of Art',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
    audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/2e/0f/52/2e0f52d5-fa6e-219d-7201-9f935f8502f9/mzaf_17730999039648600868.plus.aac.p.m4a',
    duration: 30,
    category: 'Trending',
    usesCount: 612000,
    isVerified: true,
    isTrending: true,
    tags: ['asake', 'afrobeats', 'reels', 'vibes'],
  },
  {
    id: 'curated_rema_calm_down',
    title: 'Calm Down',
    artist: 'Rema',
    album: 'Rave & Roses',
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&auto=format&fit=crop&q=80',
    audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview112/v4/0c/33/c2/0c33c2a8-062e-333e-b838-8eec47f3b8b1/mzaf_17409559385558117961.plus.aac.p.m4a',
    duration: 30,
    category: 'Afrobeats',
    usesCount: 940000,
    isVerified: true,
    isTrending: true,
    tags: ['rema', 'calmdown', 'global', 'tiktok'],
  },
  {
    id: 'curated_ayra_rush',
    title: 'Rush',
    artist: 'Ayra Starr',
    album: '19 & Dangerous (Deluxe)',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
    audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview122/v4/1f/24/7f/1f247ff5-cb87-aeb9-3663-718c3b70e513/mzaf_16480521634563889012.plus.aac.p.m4a',
    duration: 30,
    category: 'Campus Vibes',
    usesCount: 520000,
    isVerified: true,
    isTrending: true,
    tags: ['ayrastarr', 'rush', 'sabi', 'campus'],
  },
  {
    id: 'curated_shallipopi_cast',
    title: 'Cast',
    artist: 'Shallipopi & Odumodublvck',
    album: 'Presido La Pluto',
    coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&auto=format&fit=crop&q=80',
    audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/31/53/b7/3153b7c8-3c65-8b83-a447-d5d1c238bfa7/mzaf_10332306323605658602.plus.aac.p.m4a',
    duration: 30,
    category: 'Hip-Hop & Drill',
    usesCount: 380000,
    isVerified: true,
    isTrending: true,
    tags: ['pluto', 'evian', 'drill', 'abuad'],
  },
  {
    id: 'curated_lofi_midnight',
    title: 'College Library Midnight Chill',
    artist: 'Lo-Fi Chill Hop Beat',
    album: 'Night Owl Studies',
    coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&auto=format&fit=crop&q=80',
    audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/f0/b1/3e/f0b13efa-90fd-8227-060f-2d2ec8f98ded/mzaf_16033116745463791140.plus.aac.p.m4a',
    duration: 35,
    category: 'Chill & Lo-Fi',
    usesCount: 165000,
    isVerified: false,
    isTrending: false,
    tags: ['lofi', 'chill', 'study', 'relax', 'vlog'],
  },
];

/**
 * Fetch tracks from iTunes Search API with timeout and robust normalization
 */
async function fetchTracksFromSource(query: string, category: string, limit = 40): Promise<TrackData[]> {
  const cacheKey = `${category.toLowerCase()}_${query.toLowerCase()}_${limit}`;
  const now = Date.now();

  if (cache[cacheKey] && now - cache[cacheKey].timestamp < CACHE_TTL_MS) {
    return cache[cacheKey].data;
  }

  try {
    const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=song&limit=${limit}`;
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'ABUAD-Nest-Music-Service/2.0',
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(6000),
    });

    if (!response.ok) {
      throw new Error(`iTunes search returned status ${response.status}`);
    }

    const data: any = await response.json();
    const results = Array.isArray(data.results) ? data.results : [];

    const tracks: TrackData[] = [];

    for (const item of results) {
      const previewUrl = item.previewUrl;
      const trackName = item.trackName;
      const artistName = item.artistName;

      if (!previewUrl || !trackName || !artistName) continue;

      const trackId = item.trackId ? String(item.trackId) : `${trackName.length}_${artistName.length}`;
      const rawArtwork = (item.artworkUrl100 || item.artworkUrl60 || '').toString();
      // Upgrade thumbnail to crystal-clear 600x600 HD artwork
      const hdArtwork = rawArtwork.replace('100x100bb', '600x600bb').replace('60x60bb', '600x600bb');

      const collection = item.collectionName || 'Single';
      const itemGenre = item.primaryGenreName || category;
      const millis = Number(item.trackTimeMillis) || 30000;
      const durationSec = Math.max(15, Math.min(60, Math.floor(millis / 1000)));

      // Generate viral TikTok uses count
      const hash = Math.abs(trackName.split('').reduce((acc: number, c: string) => acc + c.charCodeAt(0), 0));
      const usesCount = 10000 + (hash * 47) % 550000;

      tracks.push({
        id: `itunes_${trackId}`,
        title: trackName,
        artist: artistName,
        album: collection,
        coverUrl: hdArtwork || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
        audioUrl: previewUrl,
        duration: durationSec,
        category: category || itemGenre,
        usesCount,
        isVerified: true,
        isTrending: tracks.length < 5,
        tags: [
          category.toLowerCase(),
          artistName.toLowerCase().replace(/\s+/g, ''),
          'music',
          'campus',
        ],
      });
    }

    if (tracks.length > 0) {
      cache[cacheKey] = { data: tracks, timestamp: now };
      return tracks;
    }
  } catch (err) {
    console.warn(`Music search failed for "${query}":`, err);
  }

  // Fallback to matching curated tracks
  const q = query.toLowerCase();
  const matchedCurated = CURATED_TRACKS.filter(t =>
    t.title.toLowerCase().includes(q) ||
    t.artist.toLowerCase().includes(q) ||
    t.category.toLowerCase().includes(q) ||
    t.tags.some(tag => tag.includes(q))
  );

  return matchedCurated.length > 0 ? matchedCurated : CURATED_TRACKS;
}

/**
 * GET /api/music/trending - Get top viral campus and global music tracks
 */
router.get('/trending', async (req: Request, res: Response) => {
  try {
    const tracks = await fetchTracksFromSource(CATEGORY_QUERIES['Trending'], 'Trending', 35);
    return res.json({ success: true, count: tracks.length, data: tracks });
  } catch (error) {
    return res.json({ success: true, count: CURATED_TRACKS.length, data: CURATED_TRACKS });
  }
});

/**
 * GET /api/music/categories - Get supported categories
 */
router.get('/categories', (req: Request, res: Response) => {
  return res.json({
    success: true,
    data: Object.keys(CATEGORY_QUERIES),
  });
});

/**
 * GET /api/music/category?name=:category - Get tracks by category
 */
router.get('/category', async (req: Request, res: Response) => {
  try {
    const categoryName = String(req.query.name || 'Trending').trim();
    const query = CATEGORY_QUERIES[categoryName] || `${categoryName} music hits 2026`;
    const tracks = await fetchTracksFromSource(query, categoryName, 35);
    return res.json({ success: true, category: categoryName, count: tracks.length, data: tracks });
  } catch (error) {
    return res.json({ success: true, category: 'Trending', count: CURATED_TRACKS.length, data: CURATED_TRACKS });
  }
});

/**
 * GET /api/music/search?q=:query - Live search tracks across music catalog
 */
router.get('/search', async (req: Request, res: Response) => {
  try {
    const q = String(req.query.q || '').trim();
    if (!q) {
      const trending = await fetchTracksFromSource(CATEGORY_QUERIES['Trending'], 'Trending', 30);
      return res.json({ success: true, count: trending.length, data: trending });
    }

    const tracks = await fetchTracksFromSource(q, 'Search', 40);
    return res.json({ success: true, query: q, count: tracks.length, data: tracks });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to search music catalog' });
  }
});

export default router;
