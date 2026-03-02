// src/controllers/authController.js
import User from '../models/User.js';
import { generateToken } from '../utils/generateToken.js';

// POST /api/auth/signup
export const signup = async (req, res, next) => {
  try {
    const { fullName, registrationNumber, email, password, role } = req.body;

    if (!fullName || !registrationNumber || !email || !password) {
      return res.status(400).json({ message: 'All fields are required' });
    }

    const existingUser = await User.findOne({
      $or: [{ email }, { registrationNumber }],
    });

    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const user = await User.create({
      fullName,
      registrationNumber,
      email,
      password,
      role: role || 'student',
    });

    const token = generateToken(user._id, user.role);

    return res.status(201).json({
      message: 'Account created successfully',
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        registrationNumber: user.registrationNumber,
        biometric: user.biometric,
      },
    });
  } catch (err) {
    // Always pass a proper Error object to next() in Express 5
    next(err instanceof Error ? err : new Error(String(err)));
  }
};

// POST /api/auth/login
export const login = async (req, res, next) => {
  try {
    const { email, password, role } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const user = await User.findOne({ email });

    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    if (role && user.role !== role) {
      return res.status(403).json({ message: `Access denied for role: ${role}` });
    }

    const token = generateToken(user._id, user.role);

    return res.status(200).json({
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        biometric: user.biometric,
      },
    });
  } catch (err) {
    next(err instanceof Error ? err : new Error(String(err)));
  }
};