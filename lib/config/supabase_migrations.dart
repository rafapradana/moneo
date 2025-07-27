/// Supabase database migration scripts for Moneo app
///
/// This file contains all the SQL migration scripts used to set up
/// the Supabase database schema for the Moneo application.
///
/// These migrations create:
/// - User profiles table with RLS policies
/// - User wallets table with RLS policies
/// - User categories table with RLS policies
/// - User transactions table with RLS policies
/// - User recurring transactions table with RLS policies
///
/// All tables implement Row Level Security (RLS) to ensure data isolation
/// between users.

class SupabaseMigrations {
  /// Migration 1: Create user profiles table
  static const String createUserProfilesTable = '''
-- Create user profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- Enable RLS on profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create policy for profiles - users can only access their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Create function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS \$\$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
''';

  /// Migration 2: Create user wallets table
  static const String createUserWalletsTable = '''
-- Create user wallets table
CREATE TABLE IF NOT EXISTS user_wallets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100),
  balance DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
  is_pinned BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Enable RLS on user_wallets table
ALTER TABLE user_wallets ENABLE ROW LEVEL SECURITY;

-- Create policies for user_wallets - users can only access their own wallets
CREATE POLICY "Users can view own wallets" ON user_wallets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallets" ON user_wallets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wallets" ON user_wallets
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own wallets" ON user_wallets
  FOR DELETE USING (auth.uid() = user_id);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_user_wallets_user_id ON user_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_user_wallets_is_pinned ON user_wallets(user_id, is_pinned) WHERE is_pinned = true;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_user_wallets_updated_at
    BEFORE UPDATE ON user_wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
''';

  /// Migration 3: Create user categories table
  static const String createUserCategoriesTable = '''
-- Create user categories table
CREATE TABLE IF NOT EXISTS user_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 50),
  type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'savings')),
  monthly_budget DECIMAL(10,2) CHECK (monthly_budget >= 0),
  color TEXT DEFAULT '#2196F3' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Enable RLS on user_categories table
ALTER TABLE user_categories ENABLE ROW LEVEL SECURITY;

-- Create policies for user_categories - users can only access their own categories
CREATE POLICY "Users can view own categories" ON user_categories
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories" ON user_categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories" ON user_categories
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories" ON user_categories
  FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_categories_user_id ON user_categories(user_id);
CREATE INDEX IF NOT EXISTS idx_user_categories_type ON user_categories(user_id, type);
''';

  /// Migration 4: Create user transactions table
  static const String createUserTransactionsTable = '''
-- Create user transactions table
CREATE TABLE IF NOT EXISTS user_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount != 0),
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  category_id UUID REFERENCES user_categories(id) ON DELETE RESTRICT NOT NULL,
  wallet_id UUID REFERENCES user_wallets(id) ON DELETE RESTRICT NOT NULL,
  notes TEXT,
  transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Enable RLS on user_transactions table
ALTER TABLE user_transactions ENABLE ROW LEVEL SECURITY;

-- Create policies for user_transactions - users can only access their own transactions
CREATE POLICY "Users can view own transactions" ON user_transactions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions" ON user_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions" ON user_transactions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions" ON user_transactions
  FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_transactions_user_id ON user_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_transactions_wallet_id ON user_transactions(user_id, wallet_id);
CREATE INDEX IF NOT EXISTS idx_user_transactions_category_id ON user_transactions(user_id, category_id);
CREATE INDEX IF NOT EXISTS idx_user_transactions_date ON user_transactions(user_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_transactions_type ON user_transactions(user_id, type);
''';

  /// Migration 5: Create user recurring transactions table
  static const String createUserRecurringTransactionsTable = '''
-- Create user recurring transactions table
CREATE TABLE IF NOT EXISTS user_recurring_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL CHECK (type IN ('expense', 'savings')),
  category_id UUID REFERENCES user_categories(id) ON DELETE RESTRICT NOT NULL,
  wallet_id UUID REFERENCES user_wallets(id) ON DELETE RESTRICT NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly')),
  next_due TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Enable RLS on user_recurring_transactions table
ALTER TABLE user_recurring_transactions ENABLE ROW LEVEL SECURITY;

-- Create policies for user_recurring_transactions - users can only access their own recurring transactions
CREATE POLICY "Users can view own recurring transactions" ON user_recurring_transactions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own recurring transactions" ON user_recurring_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own recurring transactions" ON user_recurring_transactions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own recurring transactions" ON user_recurring_transactions
  FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_recurring_transactions_user_id ON user_recurring_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_recurring_transactions_wallet_id ON user_recurring_transactions(user_id, wallet_id);
CREATE INDEX IF NOT EXISTS idx_user_recurring_transactions_category_id ON user_recurring_transactions(user_id, category_id);
CREATE INDEX IF NOT EXISTS idx_user_recurring_transactions_next_due ON user_recurring_transactions(user_id, next_due) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_recurring_transactions_active ON user_recurring_transactions(user_id, is_active);
''';

  /// List of all migrations in order
  static const List<String> allMigrations = [
    createUserProfilesTable,
    createUserWalletsTable,
    createUserCategoriesTable,
    createUserTransactionsTable,
    createUserRecurringTransactionsTable,
  ];
}
