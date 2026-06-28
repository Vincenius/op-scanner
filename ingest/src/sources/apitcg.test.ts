import { describe, expect, it } from 'vitest';
import { entriesToCards, entriesToSets, type ApiTcgEntry } from './apitcg.js';

const entries: ApiTcgEntry[] = [
  {
    id: 'OP01-016',
    code: 'OP01-016',
    rarity: 'R',
    type: 'CHARACTER',
    name: 'Nami',
    color: 'Red',
    cost: 1,
    power: '0',
    counter: '1000',
    attribute: { name: 'Special' },
    family: 'Straw Hat Crew',
    ability: '[On Play] ...',
    trigger: '',
    images: { small: 'a.png', large: 'A.png' },
    set: { name: 'ROMANCE DAWN [OP-01]' },
  },
  {
    id: 'OP01-016_p1',
    code: 'OP01-016',
    rarity: 'R',
    type: 'CHARACTER',
    name: 'Nami',
    color: 'Red',
    images: { small: 'b.png', large: 'B.png' },
    set: { name: 'ROMANCE DAWN [OP-01]' },
  },
  {
    id: 'ST14-001',
    code: 'ST14-001',
    rarity: 'L',
    type: 'LEADER',
    name: 'Monkey.D.Luffy',
    color: 'Black/Yellow',
    counter: '-',
    images: { small: 'c.png', large: 'C.png' },
    set: { name: '-3D2Y- [ST-14]' },
  },
];

describe('entriesToCards', () => {
  it('groups printings of the same code into one card with multiple variants', () => {
    const cards = entriesToCards(entries);
    expect(cards).toHaveLength(2); // OP01-016 + ST14-001

    const nami = cards.find((c) => c.cardCode === 'OP01-016');
    expect(nami).toBeDefined();
    expect(nami!.variants).toHaveLength(2);

    const base = nami!.variants.find((v) => v.variantId === 'OP01-016');
    const alt = nami!.variants.find((v) => v.variantId === 'OP01-016_p1');
    expect(base!.isAltArt).toBe(false);
    expect(alt!.isAltArt).toBe(true);
    expect(alt!.variantLabel).toBe('Parallel');
    // distinct images per variant — the basis for alt-art recognition later
    expect(base!.imageThumbUrl).toBe('a.png');
    expect(alt!.imageThumbUrl).toBe('b.png');
  });

  it('maps numeric/dash/blank fields and dual colors', () => {
    const cards = entriesToCards(entries);
    const nami = cards.find((c) => c.cardCode === 'OP01-016')!;
    expect(nami.cost).toBe(1);
    expect(nami.power).toBe(0);
    expect(nami.counter).toBe(1000);
    expect(nami.triggerText).toBeUndefined(); // "" -> undefined

    const luffy = cards.find((c) => c.cardCode === 'ST14-001')!;
    expect(luffy.colors).toEqual(['Black', 'Yellow']);
    expect(luffy.counter).toBeUndefined(); // "-" -> undefined
    expect(luffy.setCode).toBe('ST14');
  });
});

describe('entriesToSets', () => {
  it('derives distinct sets with cleaned names', () => {
    const sets = entriesToSets(entries);
    expect(sets).toContainEqual({ code: 'OP01', name: 'ROMANCE DAWN' });
    expect(sets).toContainEqual({ code: 'ST14', name: '-3D2Y-' });
  });
});
