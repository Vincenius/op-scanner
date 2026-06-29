import { describe, expect, it } from 'vitest';
import {
  cleanSetName,
  deriveSetCode,
  mapCardType,
  parseNumeric,
  splitColors,
  variantInfo,
} from './mapping.js';

describe('parseNumeric', () => {
  it('handles numbers, numeric strings, and blanks', () => {
    expect(parseNumeric(2000)).toBe(2000);
    expect(parseNumeric('2000')).toBe(2000);
    expect(parseNumeric('1')).toBe(1);
    expect(parseNumeric('-')).toBeNull();
    expect(parseNumeric('')).toBeNull();
    expect(parseNumeric(null)).toBeNull();
    expect(parseNumeric(undefined)).toBeNull();
  });
});

describe('splitColors', () => {
  it('splits dual colors and trims', () => {
    expect(splitColors('Black')).toEqual(['Black']);
    expect(splitColors('Red/Green')).toEqual(['Red', 'Green']);
    expect(splitColors('Red Black')).toEqual(['Red', 'Black']);
    expect(splitColors('Purple Red')).toEqual(['Purple', 'Red']);
    expect(splitColors('')).toEqual([]);
    expect(splitColors(undefined)).toEqual([]);
  });
});

describe('deriveSetCode / cleanSetName', () => {
  it('derives set code from card code prefix', () => {
    expect(deriveSetCode('OP01-077')).toBe('OP01');
    expect(deriveSetCode('ST14-001')).toBe('ST14');
    expect(deriveSetCode('EB02-061')).toBe('EB02');
  });
  it('strips the bracketed tag from set names', () => {
    expect(cleanSetName('ROMANCE DAWN [OP-01]')).toBe('ROMANCE DAWN');
    expect(cleanSetName('-3D2Y- [ST-14]')).toBe('-3D2Y-');
  });
});

describe('mapCardType', () => {
  it('maps known types and rejects unknown', () => {
    expect(mapCardType('LEADER')).toBe('LEADER');
    expect(mapCardType('Character')).toBe('CHARACTER');
    expect(mapCardType('don')).toBe('DON');
    expect(mapCardType('SPELL')).toBeNull();
    expect(mapCardType(undefined)).toBeNull();
  });
});

describe('variantInfo (alt-art detection)', () => {
  it('treats id == code as the base printing', () => {
    expect(variantInfo('OP01-016', 'OP01-016')).toEqual({
      isAltArt: false,
      label: null,
    });
  });
  it('treats _pN suffixes as parallel alt-arts', () => {
    expect(variantInfo('OP01-016_p1', 'OP01-016')).toEqual({
      isAltArt: true,
      label: 'Parallel',
    });
    expect(variantInfo('EB02-061_p2', 'EB02-061')).toEqual({
      isAltArt: true,
      label: 'Parallel 2',
    });
  });
});
