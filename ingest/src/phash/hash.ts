/**
 * RGB perceptual hash — see /shared/HASHING.md. This MUST stay byte-for-byte
 * equivalent to the Dart implementation in the client (app/lib/src/scan/phash.dart).
 * Only `sharp` decoding feeds this; all crop/downscale/DCT/hash math is here.
 */

export interface RgbImage {
  data: Uint8Array; // row-major, 3 bytes/pixel (RGB, no alpha)
  width: number;
  height: number;
}

const CROP = { left: 0.05, top: 0.06, right: 0.95, bottom: 0.78 };
const N = 32; // downscale target

// cos[freq][x] = cos(((2x+1) * freq * π) / 64), freq 0..7, x 0..31
const COS: number[][] = Array.from({ length: 8 }, (_, f) =>
  Array.from({ length: N }, (_, x) => Math.cos(((2 * x + 1) * f * Math.PI) / (2 * N))),
);

function downscaleChannels(img: RgbImage): [Float64Array, Float64Array, Float64Array] {
  const { data, width, height } = img;
  const x0 = Math.round(CROP.left * width);
  const x1 = Math.round(CROP.right * width);
  const y0 = Math.round(CROP.top * height);
  const y1 = Math.round(CROP.bottom * height);
  const cropW = x1 - x0;
  const cropH = y1 - y0;
  const r = new Float64Array(N * N);
  const g = new Float64Array(N * N);
  const b = new Float64Array(N * N);

  for (let oy = 0; oy < N; oy++) {
    let sy0 = y0 + Math.floor((oy * cropH) / N);
    let sy1 = y0 + Math.floor(((oy + 1) * cropH) / N);
    if (sy1 === sy0) sy1 = sy0 + 1;
    for (let ox = 0; ox < N; ox++) {
      let sx0 = x0 + Math.floor((ox * cropW) / N);
      let sx1 = x0 + Math.floor(((ox + 1) * cropW) / N);
      if (sx1 === sx0) sx1 = sx0 + 1;
      let sr = 0;
      let sg = 0;
      let sb = 0;
      let cnt = 0;
      for (let y = sy0; y < sy1; y++) {
        for (let x = sx0; x < sx1; x++) {
          const idx = (y * width + x) * 3;
          sr += data[idx]!;
          sg += data[idx + 1]!;
          sb += data[idx + 2]!;
          cnt++;
        }
      }
      const o = oy * N + ox;
      r[o] = sr / cnt;
      g[o] = sg / cnt;
      b[o] = sb / cnt;
    }
  }
  return [r, g, b];
}

function hashChannel(ch: Float64Array): string {
  // 8x8 low-frequency DCT-II block.
  const block = new Float64Array(64);
  for (let v = 0; v < 8; v++) {
    const av = v === 0 ? Math.sqrt(1 / N) : Math.sqrt(2 / N);
    for (let u = 0; u < 8; u++) {
      const au = u === 0 ? Math.sqrt(1 / N) : Math.sqrt(2 / N);
      let sum = 0;
      for (let y = 0; y < N; y++) {
        const cv = COS[v]![y]!;
        const row = y * N;
        for (let x = 0; x < N; x++) {
          sum += ch[row + x]! * COS[u]![x]! * cv;
        }
      }
      block[v * 8 + u] = au * av * sum;
    }
  }
  // median of the 63 coefficients excluding DC (k=0)
  const vals = Array.from(block.slice(1)).sort((a, b) => a - b);
  const median = vals[Math.floor(vals.length / 2)]!; // 63 values -> index 31
  // 64 bits -> 16 hex (k=0 is the MSB; group nibbles high bit = lower k)
  let hex = '';
  for (let i = 0; i < 16; i++) {
    let nibble = 0;
    for (let j = 0; j < 4; j++) {
      const k = i * 4 + j;
      nibble = (nibble << 1) | (block[k]! > median ? 1 : 0);
    }
    hex += nibble.toString(16);
  }
  return hex;
}

/** Compute the 48-hex (192-bit) RGB perceptual hash of a decoded image. */
export function phashFromRgb(img: RgbImage): string {
  const [r, g, b] = downscaleChannels(img);
  return hashChannel(r) + hashChannel(g) + hashChannel(b);
}

/** Hamming distance between two 48-hex hashes (0..192). */
export function hammingHex(a: string, b: string): number {
  let dist = 0;
  for (let i = 0; i < a.length; i++) {
    let x = parseInt(a[i]!, 16) ^ parseInt(b[i]!, 16);
    while (x) {
      dist += x & 1;
      x >>= 1;
    }
  }
  return dist;
}
