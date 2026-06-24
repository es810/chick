const dns = require('dns');

/** Windows/local networks often fail mongodb+srv DNS — use public resolvers. */
dns.setServers(['8.8.8.8', '1.1.1.1']);
