import app from './src/app.js';
import { connectDB } from './src/config/db.js';
import { PORT } from './src/config/env.js';

connectDB();

app.listen(PORT, () => {
  console.log(`Connection Successful the  Server running on port ${PORT}`);
});