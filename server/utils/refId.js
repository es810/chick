/** Normalize Mongo ids / populated refs to a comparable string. */
const refId = (value) => {
  if (value == null) return '';
  if (typeof value === 'string') return value;
  if (typeof value !== 'object') return String(value);

  // Mongoose/BSON ObjectId: accessing ._id recurses forever — check first.
  if (typeof value.toHexString === 'function') {
    return value.toHexString();
  }
  if (value._bsontype === 'ObjectId' || value._bsontype === 'ObjectID') {
    return String(value);
  }

  // Populated document / plain { _id }
  if (value._id != null && value._id !== value) {
    return refId(value._id);
  }

  if (typeof value.id === 'string' && value.id.length > 0) {
    return value.id;
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
