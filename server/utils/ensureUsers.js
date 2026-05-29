/**
 * Creates or updates demo login users (does not wipe the database).
 *
 *   cd server && npm run ensure-users
 *
 * Railway: redeploy after push — server auto-creates users if admin is missing.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Client = require('../models/Client');
const { mongoUri } = require('../config/env');

const DEMO_USERS = [
  {
    name: 'Farm Admin',
    phone: '+1234567890',
    email: 'admin@chickenfarm.com',
    password: 'admin123',
    role: 'admin',
  },
  {
    name: 'John Employee',
    phone: '+1234567891',
    email: 'employee@chickenfarm.com',
    password: 'employee123',
    role: 'employee',
  },
];

const ensureClientUser = async () => {
  let client = await Client.findOne({ name: 'Green Valley Restaurant' });
  if (!client) {
    client = await Client.create({
      name: 'Green Valley Restaurant',
      phone: '+1234567892',
      address: '123 Main St, City',
      balance: 0,
    });
  }

  let user = await User.findOne({ email: 'client@chickenfarm.com' });
  if (user) {
    user.password = 'client123';
    user.isActive = true;
    user.clientProfile = client._id;
    await user.save();
  } else {
    user = await User.create({
      name: 'Green Valley Restaurant',
      phone: '+1234567892',
      email: 'client@chickenfarm.com',
      password: 'client123',
      role: 'client',
      clientProfile: client._id,
    });
  }

  client.userId = user._id;
  await client.save();
};

const ensureDemoUsers = async () => {
  for (const demo of DEMO_USERS) {
    let user = await User.findOne({ email: demo.email }).select('+password');
    if (user) {
      user.name = demo.name;
      user.phone = demo.phone;
      user.role = demo.role;
      user.password = demo.password;
      user.isActive = true;
      await user.save();
    } else {
      await User.create(demo);
    }
  }
  await ensureClientUser();
};

const run = async () => {
  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB');
  await ensureDemoUsers();
  console.log('\nDemo logins ready:\n');
  console.log('  admin@chickenfarm.com / admin123');
  console.log('  employee@chickenfarm.com / employee123');
  console.log('  client@chickenfarm.com / client123\n');
  await mongoose.disconnect();
  process.exit(0);
};

if (require.main === module) {
  run().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

module.exports = { ensureDemoUsers };
