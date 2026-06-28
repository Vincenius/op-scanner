import type { CardSource, RawCard, RawPrice, RawSet } from './types.js';

/**
 * Deterministic in-memory source for offline development and tests. Mirrors the
 * real upstream shape, including an alt-art pair (OP01-016 base + parallel) so
 * variant handling and alt-art pricing can be exercised without network/keys.
 */
const SETS: RawSet[] = [
  { code: 'OP01', name: 'ROMANCE DAWN', releaseDate: '2022-12-02' },
  { code: 'ST01', name: 'STRAW HAT CREW' },
];

const CARDS: RawCard[] = [
  {
    cardCode: 'OP01-001',
    setCode: 'OP01',
    name: 'Monkey.D.Luffy',
    colors: ['Red'],
    type: 'LEADER',
    power: 5000,
    attribute: 'Strike',
    family: 'Straw Hat Crew',
    abilityText: '[Activate: Main] [Once Per Turn] ...',
    variants: [
      {
        variantId: 'OP01-001',
        rarity: 'L',
        isAltArt: false,
        imageThumbUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-001.png',
        imageFullUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-001.png',
      },
    ],
  },
  {
    cardCode: 'OP01-016',
    setCode: 'OP01',
    name: 'Nami',
    colors: ['Red'],
    type: 'CHARACTER',
    cost: 1,
    power: 0,
    counter: 1000,
    attribute: 'Special',
    family: 'Straw Hat Crew',
    abilityText: '[On Play] ...',
    variants: [
      {
        variantId: 'OP01-016',
        rarity: 'R',
        isAltArt: false,
        imageThumbUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-016.png',
        imageFullUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-016.png',
      },
      {
        variantId: 'OP01-016_p1',
        rarity: 'R',
        isAltArt: true,
        variantLabel: 'Parallel',
        imageThumbUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-016_p1.png',
        imageFullUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-016_p1.png',
      },
    ],
  },
  {
    cardCode: 'ST01-001',
    setCode: 'ST01',
    name: 'Monkey.D.Luffy',
    colors: ['Red'],
    type: 'LEADER',
    power: 5000,
    attribute: 'Strike',
    family: 'Straw Hat Crew',
    variants: [
      {
        variantId: 'ST01-001',
        rarity: 'L',
        isAltArt: false,
        imageThumbUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/ST01-001.png',
        imageFullUrl: 'https://en.onepiece-cardgame.com/images/cardlist/card/ST01-001.png',
      },
    ],
  },
];

const PRICES: RawPrice[] = [
  { variantId: 'OP01-001', source: 'tcgplayer', currency: 'USD', marketPrice: 2.5, lowPrice: 1.2, capturedAt: '2026-06-28T00:00:00.000Z' },
  { variantId: 'OP01-016', source: 'tcgplayer', currency: 'USD', marketPrice: 3.59, lowPrice: 2.1, capturedAt: '2026-06-28T00:00:00.000Z' },
  { variantId: 'OP01-016_p1', source: 'tcgplayer', currency: 'USD', marketPrice: 377.4, lowPrice: 310.0, capturedAt: '2026-06-28T00:00:00.000Z' },
];

export class FixtureSource implements CardSource {
  readonly id = 'fixture';

  async fetchSets(): Promise<RawSet[]> {
    return structuredClone(SETS);
  }

  async fetchCards(): Promise<RawCard[]> {
    return structuredClone(CARDS);
  }

  async fetchPrices(): Promise<RawPrice[]> {
    return structuredClone(PRICES);
  }
}
