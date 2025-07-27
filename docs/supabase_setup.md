# Supabase Setup Guide for Moneo

This guide explains how to set up Supabase for the Moneo application.

## Prerequisites

1. Create a Supabase account at [supabase.com](https://supabase.com)
2. Create a new Supabase project

## Configuration

### 1. Update Supabase Configuration

Update the configuration in `lib/config/supabase_config.dart`:

```dart
static const String supabaseUrl = 'YOUR_ACTUAL_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_ACTUAL_SUPABASE_ANON_KEY';
```

Replace `YOUR_ACTUAL_SUPABASE_URL` and `YOUR_ACTUAL_SUPABASE_ANON_KEY` with your actual Supabase project URL and anonymous key.

### 2. Database Schema

The database schema has been automatically created with the following tables:

#### Tables Created:

1. **profiles** - User profile information
   - Links to Supabase auth.users
   - Automatically created on user signup

2. **user_wallets** - User wallet data
   - Stores wallet name, balance, and pin status
   - Includes created_at and updated_at timestamps

3. **user_categories** - Expense/income categories
   - Supports income, expense, and savings categories
   - Includes monthly budget limits and color coding

4. **user_transactions** - Transaction records
   - Links to wallets and categories
   - Supports income and expense transactions
   - Includes notes and transaction date

5. **user_recurring_transactions** - Recurring transaction templates
   - Supports weekly and monthly frequencies
   - Includes next due date and active status
   - Used for automated recurring transactions

### 3. Row Level Security (RLS)

All tables implement Row Level Security policies to ensure:
- Users can only access their own data
- Data isolation between different users
- Secure multi-tenant architecture

### 4. Database Indexes

Performance indexes have been created on:
- User ID columns for all tables
- Frequently queried columns (wallet_id, category_id, transaction_date)
- Conditional indexes for pinned wallets and active recurring transactions

## Authentication

The app uses Supabase Auth with:
- Email/password authentication
- Automatic profile creation on signup
- Session management and persistence

## Data Synchronization

The app supports:
- Offline-first operation with local Drift database
- Optional cloud sync for authenticated users
- Conflict resolution between local and cloud data
- Data export/import functionality

## Security Features

- Row Level Security (RLS) on all tables
- Secure authentication with Supabase Auth
- Data validation at database level
- Proper foreign key constraints and cascading deletes

## Migration Scripts

All migration scripts are documented in `lib/config/supabase_migrations.dart` for reference and manual setup if needed.