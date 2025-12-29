-- ============================================
-- COMPLETE ACCOUNT DELETION - DATABASE SETUP
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Ensure user_profiles has CASCADE delete (if not already set)
-- This automatically deletes profile when auth user is deleted
ALTER TABLE public.user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_id_fkey;

ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_id_fkey 
FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 2. Create trigger function for additional cleanup
CREATE OR REPLACE FUNCTION public.handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Log the deletion (optional, for debugging)
  RAISE NOTICE 'Deleting user data for user_id: %', OLD.id;
  
  -- Delete user profile (backup in case CASCADE doesn't work)
  DELETE FROM public.user_profiles WHERE id = OLD.id;
  
  -- Note: Storage files are deleted by the Edge Function
  -- Triggers cannot access Supabase Storage API directly
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger on auth.users table
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;
CREATE TRIGGER on_auth_user_deleted
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_deletion();

-- 4. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT DELETE ON public.user_profiles TO authenticated;

-- ============================================
-- VERIFICATION QUERY
-- Run after setup to confirm trigger exists
-- ============================================
-- SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_deleted';
