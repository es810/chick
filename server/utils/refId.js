/** Normalize Mongo ids / populated refs to a comparable string. */
const refId = (value) => {
  if (value == null) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object') {
    if (value._id != null) return refId(value._id);
    if (typeof value.toHexString === 'function') return value.toHexString();
    if (value.id != null && typeof value.id === 'string') return value.id;
  }
  const asString = String(value);
  return asString === '[object Object]' ? '' : asString;
};

const isSameId = (a, b) => {
  const left = refId(a);
  const right = refId(b);
  return Boolean(left) && left === right;
};

module.exports = { refId, isSameId };
