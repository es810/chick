require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Client = require('../models/Client');
const Stock = require('../models/Stock');
const { mongoUri } = require('../config/env');

const seed = async () => {
  await mongoose.connect(mongoUri);
  console.log('Connected for seeding...');

  await Promise.all([User.deleteMany(), Client.deleteMany(), Stock.deleteMany()]);

  const admin = await User.create({
    name: 'Farm Admin',
    phone: '+1234567890',
    email: 'admin@chickenfarm.com',
    password: 'admin123',
    role: 'admin',
  });

  const employee = await User.create({
    name: 'John Employee',
    phone: '+1234567891',
    email: 'employee@chickenfarm.com',
    password: 'employee123',
    role: 'employee',
  });

  const client1 = await Client.create({
    name: 'Green Valley Restaurant',
    phone: '+1234567892',
    address: '123 Main St, City',
    balance: 0,
  });

  const clientUser = await User.create({
    name: 'Green Valley Restaurant',
    phone: '+1234567892',
    email: 'client@chickenfarm.com',
    password: 'client123',
    role: 'client',
    clientProfile: client1._id,
  });

  client1.userId = clientUser._id;
  await client1.save();

  console.log('\n✅ Seed completed!\n');
  console.log('Stock: add items from the admin Stock screen (no demo stock seeded).\n');
  console.log('Admin:    admin@chickenfarm.com / admin123');
  console.log('Employee: employee@chickenfarm.com / employee123');
  console.log('Client:   client@chickenfarm.com / client123\n');

  process.exit(0);
};

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
