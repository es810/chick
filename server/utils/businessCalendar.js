/** Business day boundaries (default: Africa/Cairo, UTC+2). */
const CAIRO_OFFSET_MS = 2 * 60 * 60 * 1000;

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

module.exports = { getCairoDayRange, getCairoMonthRange };
