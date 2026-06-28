import type { Prisma } from '@prisma/client';
import type {
  CardDto,
  PriceDto,
  SetDto,
  VariantDto,
} from '@op-scanner/shared';

export type CardWithVariants = Prisma.CardGetPayload<{
  include: { variants: true; set: true };
}>;
type VariantRow = CardWithVariants['variants'][number];
type SetRow = CardWithVariants['set'];
type PriceRow = Prisma.PriceGetPayload<object>;

function thumbPath(variantId: string): string {
  return `/img/variants/${encodeURIComponent(variantId)}/thumb`;
}
function fullPath(variantId: string): string {
  return `/img/variants/${encodeURIComponent(variantId)}/full`;
}

export function toSetDto(set: SetRow): SetDto {
  return {
    id: set.id,
    code: set.code,
    name: set.name,
    releaseDate: set.releaseDate ? set.releaseDate.toISOString() : null,
  };
}

export function toPriceDto(price: PriceRow): PriceDto {
  return {
    source: price.source,
    currency: price.currency,
    marketPrice: price.marketPrice ? Number(price.marketPrice) : null,
    lowPrice: price.lowPrice ? Number(price.lowPrice) : null,
    capturedAt: price.capturedAt.toISOString(),
  };
}

export function toVariantDto(
  variant: VariantRow,
  currentPrice: PriceDto | null,
): VariantDto {
  return {
    variantId: variant.variantId,
    cardId: variant.cardId,
    rarity: variant.rarity,
    isAltArt: variant.isAltArt,
    variantLabel: variant.variantLabel,
    thumbUrl: thumbPath(variant.variantId),
    fullUrl: fullPath(variant.variantId),
    currentPrice,
  };
}

export function toCardDto(
  card: CardWithVariants,
  priceByVariant: Map<string, PriceDto>,
): CardDto {
  return {
    id: card.id,
    cardCode: card.cardCode,
    name: card.name,
    colors: card.colors,
    type: card.type,
    cost: card.cost,
    power: card.power,
    counter: card.counter,
    attribute: card.attribute,
    family: card.family,
    abilityText: card.abilityText,
    triggerText: card.triggerText,
    setId: card.setId,
    setCode: card.set.code,
    variants: card.variants.map((v) =>
      toVariantDto(v, priceByVariant.get(v.variantId) ?? null),
    ),
  };
}
