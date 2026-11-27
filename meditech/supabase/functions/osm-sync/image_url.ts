const MAX_IMAGE_URL_LEN = 2048;

function isHttpUrl(value: string): boolean {
  return /^https?:\/\//i.test(value);
}

function commonsFileUrl(fileName: string, width = 512): string | null {
  const file = fileName.replace(/^File:/i, "").trim();
  if (!file) return null;
  const url =
    `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(file)}?width=${width}`;
  return url.length <= MAX_IMAGE_URL_LEN ? url : null;
}

export function pickImageUrlFromOsmTags(
  tags: Record<string, string>,
): string | null {
  for (const key of ["image", "photo"] as const) {
    const direct = tags[key]?.trim();
    if (direct && isHttpUrl(direct) && direct.length <= MAX_IMAGE_URL_LEN) {
      return direct;
    }
  }

  for (const key of ["logo", "brand:logo"] as const) {
    const logo = tags[key]?.trim();
    if (logo && isHttpUrl(logo) && logo.length <= MAX_IMAGE_URL_LEN) {
      return logo;
    }
  }

  for (const [key, raw] of Object.entries(tags)) {
    if (!/^image:\d+$/i.test(key)) continue;
    const value = raw?.trim();
    if (value && isHttpUrl(value) && value.length <= MAX_IMAGE_URL_LEN) {
      return value;
    }
  }

  const commons =
    tags["wikimedia_commons"]?.trim() ||
    tags["wikimedia_commons:path"]?.trim() ||
    tags["wikimedia"]?.trim();
  if (commons) {
  if (commons.startsWith("File:") || !isHttpUrl(commons)) {
      const fromFile = commonsFileUrl(commons);
      if (fromFile != null) return fromFile;
    } else if (commons.length <= MAX_IMAGE_URL_LEN) {
      return commons;
    }
  }

  return null;
}