/** Business day boundaries (Africa/Cairo — Egypt is UTC+3 year-round). */
const CAIRO_OFFSET_MS = 3 * 60 * 60 * 1000;

const toCairoWallClock = (date) => new Date(date.getTime() + CAIRO_OFFSET_MS);

const getCairoDayRange = (referenceDate = new Date()) => {
  const cairo = toCairoWallClock(referenceDate);
  const start = new Date(
    Date.UTC(cairo.getUTCFullYear(), cairo.getUTCMonth(), cairo.getUTCDate()) - CAIRO_OFFSET_MS
  );
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { start, end };
};

const getCairoMonthRange = (year, month) => {
  const start = new Date(Date.UTC(year, month - 1, 1) - CAIRO_OFFSET_MS);
  const end = new Date(Date.UTC(year, month, 1) - CAIRO_OFFSET_MS);
  return { start, end };
};

/** Normalize any timestamp to the Cairo business-day start for that calendar date. */
const normalizeToCairoDayStart = (value) => {
  const { start } = getCairoDayRange(new Date(value));
  return start;
};

module.exports = { getCairoDayRange, getCairoMonthRange, normalizeToCairoDayStart };
