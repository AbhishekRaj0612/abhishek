/*
  # Multi-Level Admin System Implementation

  1. New Tables
    - `areas` - Administrative areas/zones
    - `departments` - Government departments
    - `issue_assignments` - Track issue assignments through hierarchy
    - `tender_assignments` - Track tender assignments to contractors
    - `work_progress` - Track contractor work progress

  2. Enhanced Tables
    - Update `profiles` table with new role types
    - Update `issues` table with assignment tracking
    - Update `tenders` table with assignment workflow

  3. Security
    - Enable RLS on all new tables
    - Add role-based policies for hierarchical access
    - Ensure proper data isolation between areas and departments

  4. Workflow
    - Citizens report issues → Area Super Admin
    - Area Super Admin assigns → Department Admin
    - Department Admin creates tenders/tasks → Contractors
    - Contractors update progress → Department Admin
    - Department Admin resolves → Area Super Admin
    - Area Super Admin marks final resolution → Public visibility
*/

-- Create areas table for administrative zones
CREATE TABLE IF NOT EXISTS areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  code text UNIQUE,
  description text,
  boundaries jsonb, -- GeoJSON for area boundaries
  population integer,
  super_admin_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_active boolean DEFAULT true,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create departments table
CREATE TABLE IF NOT EXISTS departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text UNIQUE,
  description text,
  category text NOT NULL CHECK (category IN ('roads', 'utilities', 'environment', 'safety', 'parks', 'planning', 'finance', 'administration')),
  parent_department_id uuid REFERENCES departments(id),
  head_admin_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  contact_email text,
  contact_phone text,
  office_location text,
  budget_allocation decimal(15, 2),
  is_active boolean DEFAULT true,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create issue assignments table to track the workflow
CREATE TABLE IF NOT EXISTS issue_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id uuid REFERENCES issues(id) ON DELETE CASCADE NOT NULL,
  assigned_by uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  assignment_type text NOT NULL CHECK (assignment_type IN ('area_to_department', 'department_to_contractor', 'internal_reassignment')),
  department_id uuid REFERENCES departments(id),
  area_id uuid REFERENCES areas(id),
  priority_override text CHECK (priority_override IN ('low', 'medium', 'high', 'urgent')),
  deadline_date timestamptz,
  assignment_notes text,
  status text NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'accepted', 'in_progress', 'completed', 'rejected', 'reassigned')),
  accepted_at timestamptz,
  completed_at timestamptz,
  rejection_reason text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tender assignments table
CREATE TABLE IF NOT EXISTS tender_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id uuid REFERENCES tenders(id) ON DELETE CASCADE NOT NULL,
  contractor_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  assigned_by uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  assignment_date timestamptz DEFAULT now(),
  start_date date,
  expected_completion_date date,
  actual_completion_date date,
  contract_amount decimal(15, 2),
  payment_terms text,
  status text NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'started', 'in_progress', 'completed', 'cancelled', 'disputed')),
  progress_percentage integer DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  quality_rating integer CHECK (quality_rating >= 1 AND quality_rating <= 5),
  completion_notes text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create work progress table for contractors
CREATE TABLE IF NOT EXISTS work_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid REFERENCES tender_assignments(id) ON DELETE CASCADE,
  issue_id uuid REFERENCES issues(id) ON DELETE CASCADE,
  contractor_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  progress_type text NOT NULL CHECK (progress_type IN ('update', 'milestone', 'completion', 'issue', 'material_request')),
  title text NOT NULL,
  description text NOT NULL,
  progress_percentage integer CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  images text[], -- Progress photos
  documents text[], -- Progress documents
  materials_used jsonb,
  labor_hours decimal(8, 2),
  costs_incurred decimal(12, 2),
  next_steps text,
  issues_encountered text,
  estimated_completion timestamptz,
  is_milestone boolean DEFAULT false,
  requires_approval boolean DEFAULT false,
  approved_by uuid REFERENCES profiles(id),
  approved_at timestamptz,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Update profiles table to support new role types
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'profiles_user_type_check' 
    AND table_name = 'profiles'
  ) THEN
    ALTER TABLE profiles DROP CONSTRAINT profiles_user_type_check;
  END IF;
  
  -- Add new constraint with expanded role types
  ALTER TABLE profiles ADD CONSTRAINT profiles_user_type_check 
    CHECK (user_type IN ('user', 'admin', 'tender', 'area_super_admin', 'department_admin'));
END $$;

-- Add new columns to profiles for role-specific data
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'assigned_area_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN assigned_area_id uuid REFERENCES areas(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'assigned_department_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN assigned_department_id uuid REFERENCES departments(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'role_permissions'
  ) THEN
    ALTER TABLE profiles ADD COLUMN role_permissions jsonb DEFAULT '{}';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'specializations'
  ) THEN
    ALTER TABLE profiles ADD COLUMN specializations text[];
  END IF;
END $$;

-- Add new columns to issues for assignment tracking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'issues' AND column_name = 'assigned_area_id'
  ) THEN
    ALTER TABLE issues ADD COLUMN assigned_area_id uuid REFERENCES areas(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'issues' AND column_name = 'assigned_department_id'
  ) THEN
    ALTER TABLE issues ADD COLUMN assigned_department_id uuid REFERENCES departments(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'issues' AND column_name = 'current_assignee_id'
  ) THEN
    ALTER TABLE issues ADD COLUMN current_assignee_id uuid REFERENCES profiles(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'issues' AND column_name = 'workflow_stage'
  ) THEN
    ALTER TABLE issues ADD COLUMN workflow_stage text DEFAULT 'reported' CHECK (workflow_stage IN ('reported', 'area_review', 'department_assigned', 'contractor_assigned', 'in_progress', 'department_review', 'area_approval', 'resolved'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'issues' AND column_name = 'final_resolution_notes'
  ) THEN
    ALTER TABLE issues ADD COLUMN final_resolution_notes text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'issues' AND column_name = 'resolved_by_super_admin'
  ) THEN
    ALTER TABLE issues ADD COLUMN resolved_by_super_admin uuid REFERENCES profiles(id);
  END IF;
END $$;

-- Enable RLS on new tables
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tender_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_progress ENABLE ROW LEVEL SECURITY;

-- Areas policies
CREATE POLICY "Anyone can read active areas"
  ON areas FOR SELECT TO authenticated
  USING (is_active = true);

CREATE POLICY "Area super admins can read their area"
  ON areas FOR SELECT TO authenticated
  USING (
    super_admin_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type = 'admin'
    )
  );

CREATE POLICY "Admins can manage areas"
  ON areas FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type = 'admin'
    )
  );

-- Departments policies
CREATE POLICY "Anyone can read active departments"
  ON departments FOR SELECT TO authenticated
  USING (is_active = true);

CREATE POLICY "Department admins can read their department"
  ON departments FOR SELECT TO authenticated
  USING (
    head_admin_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin')
    )
  );

CREATE POLICY "Area super admins and admins can manage departments"
  ON departments FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin')
    )
  );

-- Issue assignments policies
CREATE POLICY "Users can read assignments for their issues"
  ON issue_assignments FOR SELECT TO authenticated
  USING (
    assigned_to = auth.uid() OR
    assigned_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM issues
      WHERE id = issue_id AND user_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin', 'department_admin')
    )
  );

CREATE POLICY "Admins can create assignments"
  ON issue_assignments FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = assigned_by AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin', 'department_admin')
    )
  );

CREATE POLICY "Assigned users can update assignments"
  ON issue_assignments FOR UPDATE TO authenticated
  USING (
    assigned_to = auth.uid() OR
    assigned_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin', 'department_admin')
    )
  );

-- Tender assignments policies
CREATE POLICY "Users can read relevant tender assignments"
  ON tender_assignments FOR SELECT TO authenticated
  USING (
    contractor_id = auth.uid() OR
    assigned_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin', 'department_admin')
    )
  );

CREATE POLICY "Department admins can create tender assignments"
  ON tender_assignments FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = assigned_by AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin', 'department_admin')
    )
  );

-- Work progress policies
CREATE POLICY "Contractors can manage their work progress"
  ON work_progress FOR ALL TO authenticated
  USING (contractor_id = auth.uid());

CREATE POLICY "Admins can read all work progress"
  ON work_progress FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_type IN ('admin', 'area_super_admin', 'department_admin')
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_areas_super_admin ON areas(super_admin_id);
CREATE INDEX IF NOT EXISTS idx_departments_head_admin ON departments(head_admin_id);
CREATE INDEX IF NOT EXISTS idx_departments_category ON departments(category);
CREATE INDEX IF NOT EXISTS idx_issue_assignments_issue_id ON issue_assignments(issue_id);
CREATE INDEX IF NOT EXISTS idx_issue_assignments_assigned_to ON issue_assignments(assigned_to);
CREATE INDEX IF NOT EXISTS idx_issue_assignments_assigned_by ON issue_assignments(assigned_by);
CREATE INDEX IF NOT EXISTS idx_tender_assignments_contractor_id ON tender_assignments(contractor_id);
CREATE INDEX IF NOT EXISTS idx_work_progress_contractor_id ON work_progress(contractor_id);
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_area ON profiles(assigned_area_id);
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_department ON profiles(assigned_department_id);
CREATE INDEX IF NOT EXISTS idx_issues_workflow_stage ON issues(workflow_stage);
CREATE INDEX IF NOT EXISTS idx_issues_assigned_area ON issues(assigned_area_id);
CREATE INDEX IF NOT EXISTS idx_issues_assigned_department ON issues(assigned_department_id);

-- Insert sample areas
INSERT INTO areas (name, code, description) VALUES
('North Delhi', 'ND', 'Northern administrative zone covering Civil Lines, Model Town, and surrounding areas'),
('South Delhi', 'SD', 'Southern administrative zone covering Greater Kailash, Lajpat Nagar, and surrounding areas'),
('East Delhi', 'ED', 'Eastern administrative zone covering Laxmi Nagar, Preet Vihar, and surrounding areas'),
('West Delhi', 'WD', 'Western administrative zone covering Rajouri Garden, Janakpuri, and surrounding areas'),
('Central Delhi', 'CD', 'Central administrative zone covering Connaught Place, India Gate, and surrounding areas')
ON CONFLICT (name) DO NOTHING;

-- Insert sample departments
INSERT INTO departments (name, code, description, category, contact_email, contact_phone) VALUES
('Public Works Department', 'PWD', 'Responsible for road maintenance, construction, and infrastructure', 'roads', 'pwd@delhi.gov.in', '+91-11-2345-6789'),
('Delhi Jal Board', 'DJB', 'Water supply and sewerage management', 'utilities', 'djb@delhi.gov.in', '+91-11-2345-6790'),
('Delhi Pollution Control Committee', 'DPCC', 'Environmental protection and pollution control', 'environment', 'dpcc@delhi.gov.in', '+91-11-2345-6791'),
('Delhi Police', 'DP', 'Public safety and law enforcement', 'safety', 'police@delhi.gov.in', '+91-11-2345-6792'),
('Parks and Gardens Department', 'PGD', 'Maintenance of parks, gardens, and green spaces', 'parks', 'parks@delhi.gov.in', '+91-11-2345-6793'),
('Delhi Development Authority', 'DDA', 'Urban planning and development', 'planning', 'dda@delhi.gov.in', '+91-11-2345-6794')
ON CONFLICT (code) DO NOTHING;

-- Create triggers for updated_at columns
CREATE TRIGGER update_areas_updated_at BEFORE UPDATE ON areas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_issue_assignments_updated_at BEFORE UPDATE ON issue_assignments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tender_assignments_updated_at BEFORE UPDATE ON tender_assignments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to auto-assign issues to area super admin based on location
CREATE OR REPLACE FUNCTION auto_assign_issue_to_area()
RETURNS TRIGGER AS $$
DECLARE
  area_record RECORD;
BEGIN
  -- Try to find area based on issue location
  SELECT * INTO area_record
  FROM areas
  WHERE is_active = true
  AND (
    NEW.area = name OR
    NEW.ward ILIKE '%' || name || '%' OR
    NEW.address ILIKE '%' || name || '%'
  )
  LIMIT 1;

  -- If area found, assign to area super admin
  IF area_record IS NOT NULL THEN
    NEW.assigned_area_id = area_record.id;
    NEW.workflow_stage = 'area_review';
    
    -- If area has a super admin, assign to them
    IF area_record.super_admin_id IS NOT NULL THEN
      NEW.current_assignee_id = area_record.super_admin_id;
      
      -- Create assignment record
      INSERT INTO issue_assignments (
        issue_id,
        assigned_by,
        assigned_to,
        assignment_type,
        area_id,
        assignment_notes
      ) VALUES (
        NEW.id,
        NEW.user_id, -- Assigned by the reporter initially
        area_record.super_admin_id,
        'area_to_department',
        area_record.id,
        'Auto-assigned based on location'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-assignment
DROP TRIGGER IF EXISTS auto_assign_issue_trigger ON issues;
CREATE TRIGGER auto_assign_issue_trigger
  BEFORE INSERT ON issues
  FOR EACH ROW
  EXECUTE FUNCTION auto_assign_issue_to_area();

-- Create function to handle workflow stage transitions
CREATE OR REPLACE FUNCTION update_issue_workflow_stage()
RETURNS TRIGGER AS $$
BEGIN
  -- Update workflow stage based on status changes
  CASE NEW.status
    WHEN 'pending' THEN
      NEW.workflow_stage = 'reported';
    WHEN 'acknowledged' THEN
      NEW.workflow_stage = 'area_review';
    WHEN 'in_progress' THEN
      IF NEW.current_assignee_id IS NOT NULL THEN
        -- Check if assigned to contractor
        IF EXISTS (
          SELECT 1 FROM profiles
          WHERE id = NEW.current_assignee_id AND user_type = 'tender'
        ) THEN
          NEW.workflow_stage = 'contractor_assigned';
        ELSE
          NEW.workflow_stage = 'department_assigned';
        END IF;
      END IF;
    WHEN 'resolved' THEN
      NEW.workflow_stage = 'resolved';
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for workflow stage updates
DROP TRIGGER IF EXISTS update_workflow_stage_trigger ON issues;
CREATE TRIGGER update_workflow_stage_trigger
  BEFORE UPDATE ON issues
  FOR EACH ROW
  EXECUTE FUNCTION update_issue_workflow_stage();