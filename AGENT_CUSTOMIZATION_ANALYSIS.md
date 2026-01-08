# Agent Customization Analysis

## Executive Summary

After reviewing the application codebase, I've identified **multiple features, screens, permissions, and workflows that should be customized specifically for Agents**. The application is currently built with Company Admin behavior in mind, providing full access to all modules and operations without role-based restrictions.

---

## Current Application Structure

### Modules Available in Desktop Admin:
1. **Dashboard** (navIndex: 0) - Statistics and overview
2. **Inventory/Files** (navIndex: 1) - File management
3. **Agent Working** (navIndex: 2) - Agent work tracking
4. **Rental Items** (navIndex: 3) - Rental properties management
5. **To-Do** (navIndex: 4) - Task management
6. **Settings** (navIndex: 5) - User profile and settings
7. **Reminders** (navIndex: 6) - Reminder management (linked to agents via `agentId`)
8. **Trading File** (navIndex: 7) - Trading file management
9. **Trading Form** (navIndex: 8) - Trading form management
10. **Users** (navIndex: 9) - User management (CRUD operations)

### Modules Available in Mobile Admin:
1. Dashboard
2. Files (read-only placeholder)
3. Properties (read-only placeholder)
4. Working (Agent working)
5. Reminders

### Current Permission System:
- Users table has a `permissions` field (JSON) that stores permission levels:
  - `view_only` - Can only view data
  - `view_add` - Can view and add data
  - `full_access` - Can view, add, edit, and delete data
  - `no_access` - Cannot view or add data
- However, **these permissions are not currently enforced** in the application code

---

## Features That Need Agent Customization

### 1. **User Management (Users Page) - CRITICAL**

**What needs customization:**
- **Hide/Disable the Users module entirely for Agents**
- Only Company Admins should access navigation item 9 (Users Page)

**Why it should be different:**
- User management is an administrative function
- Agents should not be able to create, edit, or delete other users
- Security risk if agents can modify user accounts or permissions
- Only Company Admins should have system-level administration rights

**UI/UX Restrictions:**
- Remove "Users" navigation item from sidebar for Agents
- Hide Users menu item in navigation (currently at index 9)
- If accessed directly (e.g., via URL/deep link), show "Access Denied" message

**Code Location:**
- `packages/desktop_admin/lib/main.dart` - Navigation menu around line 9188
- `packages/desktop_admin/lib/main.dart` - UsersPage class around line 12053

---

### 2. **Dashboard - Data Filtering**

**What needs customization:**
- Filter dashboard statistics to show only Agent-specific data
- Limit dashboard views to data the Agent has created or is assigned to

**Why it should be different:**
- Agents should only see their own performance metrics
- Company Admins see company-wide statistics
- Prevents agents from seeing confidential company-wide performance data
- Each agent should see:
  - Their own properties/files/rental items count
  - Their own sales statistics
  - Their own reminders count
  - Their own working items

**UI/UX Adjustments:**
- Modify dashboard queries to filter by `agentId` or `createdBy`
- Add WHERE clauses to SQL queries filtering by current user's ID
- Update dashboard statistics calculation methods:
  - `_loadDashboardStats()` method (around line 7836)
  - Dashboard queries in `dashboard()` method

**Data Model Considerations:**
- May need to add `createdBy` or `assignedAgentId` fields to:
  - Properties table
  - FilesTable
  - RentalItems table
- Or use existing relationships (e.g., Clients.source = 'Agent')

---

### 3. **Files/Inventory Module - View & Edit Restrictions**

**What needs customization:**
- Restrict Agents to view-only OR view/edit only their own entries
- Hide delete functionality for Agents
- Filter list to show only Agent-assigned entries (if applicable)

**Why it should be different:**
- Agents shouldn't delete company inventory records
- Agents may only need to view inventory, not modify
- Or agents should only edit entries they created/are assigned to
- Prevents accidental or malicious data deletion

**UI/UX Restrictions:**
- Hide/disable "Delete" buttons for Agents
- Hide/disable "Add" button if Agent only has view permissions
- Filter file/property lists by agent assignment (if applicable)
- Show visual indicator when Agent is in view-only mode

**Code Location:**
- `packages/desktop_admin/lib/main.dart` - FilesPage class
- Delete operations around line 2128 (_delete methods)
- FloatingActionButton for "Add" around line 2219

---

### 4. **Properties Module - Similar to Files**

**What needs customization:**
- Same restrictions as Files module
- Limit to view-only OR view/edit own entries only
- Disable delete operations

**Why it should be different:**
- Properties are valuable company assets
- Agents shouldn't have unrestricted delete access
- Maintains data integrity and audit trail

**UI/UX Restrictions:**
- Same as Files module
- Remove delete buttons/actions
- Restrict add/edit based on permissions

---

### 5. **Agent Working Module - Own Data Only**

**What needs customization:**
- Filter to show only the Agent's own working items
- Prevent Agents from viewing other agents' working progress
- Allow Agents to create/edit/delete their own working items

**Why it should be different:**
- Agents should only manage their own work
- Company Admins can view all agents' work
- Maintains confidentiality between agents
- Each agent focuses on their own tasks

**UI/UX Adjustments:**
- Filter queries by current user's ID (WHERE agentId = currentUserId)
- AgentWorkingPage should filter data on load (around line 9343)
- Add/edit forms should auto-assign to current user

**Code Location:**
- `packages/desktop_admin/lib/main.dart` - AgentWorkingPage class around line 9343
- WorkingProgress table has `fromUser` and `toUser` fields that can be used

---

### 6. **Reminders Module - Own Reminders Only**

**What needs customization:**
- Filter reminders to show only current Agent's reminders
- Auto-assign new reminders to current Agent
- Prevent viewing other agents' reminders

**Why it should be different:**
- Reminders are personal to each agent
- `reminders` table already has `agentId` field (line 149 in schema.dart)
- Agents shouldn't see reminders belonging to other agents
- Company Admins can view all reminders for oversight

**UI/UX Adjustments:**
- Filter reminder list queries: `WHERE agent_id = currentUserId`
- Auto-populate `agentId` field when Agent creates reminder
- Hide agent selection dropdown for Agents (only show for Admins)
- RemindersPage filtering around line 17593

**Code Location:**
- `packages/desktop_admin/lib/main.dart` - RemindersPage
- Reminder creation form around line 17642

---

### 7. **Rental Items Module - Restricted Access**

**What needs customization:**
- Similar to Files/Properties: view-only or view/edit own entries
- Disable delete for Agents

**Why it should be different:**
- Same reasoning as Files/Properties
- Maintains data integrity

**UI/UX Restrictions:**
- Same as Files/Properties modules

---

### 8. **To-Do Module - Agent Assignment Filtering**

**What needs customization:**
- Filter to show only To-Do items assigned to current Agent
- Allow Agents to update status of their assigned items
- Restrict creation to assigned items only (or allow creation with auto-assignment)

**Why it should be different:**
- Agents should focus on their assigned tasks
- Company Admins can view all to-do items
- Prevents information overload

**UI/UX Adjustments:**
- Filter queries by assignment (may need to check ToDo table structure)
- Auto-assign to current user when Agent creates item

---

### 9. **Trading File & Trading Form Modules - Permission-Based Access**

**What needs customization:**
- Determine if Agents should have access at all
- If yes, restrict to view-only or view/edit own entries
- Disable delete operations

**Why it should be different:**
- Trading modules may contain sensitive financial information
- Company Admins may want exclusive control
- Or agents can view/edit entries they're involved with

**UI/UX Restrictions:**
- Option 1: Hide completely for Agents
- Option 2: View-only access
- Option 3: View/edit own entries only

---

### 10. **Settings Page - Limited Access**

**What needs customization:**
- Show only personal profile settings for Agents
- Hide admin-level settings (if any)
- Restrict to: name, email, contact, password change, theme

**Why it should be different:**
- Agents don't need system configuration access
- Company Admins may have additional settings
- Maintains security boundaries

**UI/UX Adjustments:**
- SettingsPage around line 16121
- Remove or hide admin-specific sections
- Keep only personal profile management

---

### 11. **Delete Operations - Global Restriction**

**What needs customization:**
- Disable all delete operations for Agents across all modules
- Or restrict to deleting only own-created records

**Why it should be different:**
- Data integrity and audit trail
- Prevent accidental deletions
- Company Admins need to approve or perform deletions

**UI/UX Restrictions:**
- Hide delete buttons/actions globally for Agents
- Replace with "Request Deletion" button that notifies Admin
- Or soft-delete (mark as deleted but retain data)

**Code Locations:**
- All `_delete` methods across modules
- Delete button handlers

---

### 12. **Export/Import Functionality - Restricted**

**What needs customization:**
- Disable bulk export/import for Agents
- Allow Agents to export only their own data (if needed)

**Why it should be different:**
- Export contains sensitive company data
- Prevents data leakage
- Company Admins control data exports

**UI/UX Restrictions:**
- Hide export/import buttons for Agents
- Or restrict export to filtered (own) data only

---

### 13. **Navigation Menu - Simplified for Agents**

**What needs customization:**
- Hide navigation items Agents shouldn't access
- Show simplified menu with only relevant modules

**Why it should be different:**
- Cleaner interface for Agents
- Reduces confusion
- Clear separation of roles

**UI/UX Adjustments:**
- Conditionally hide menu items based on role
- Navigation menu around line 9048
- Items to potentially hide:
  - Users (definitely)
  - Trading modules (if restricted)
  - Settings (show limited version)

---

### 14. **Clients Module - Agent Source Tracking**

**What needs customization:**
- If Clients module exists, filter by `source = 'Agent'` and `agentId = currentUserId`
- Show only clients the Agent brought in
- Company Admins see all clients

**Why it should be different:**
- Clients table has `source` field ('Agent' or 'Direct')
- Agents should see only their own clients for commission/performance tracking
- Company Admins see complete client list

**UI/UX Adjustments:**
- Filter client list queries
- Show commission/performance metrics for own clients only

---

### 15. **Reports Module - Restricted Access**

**What needs customization:**
- Disable report generation for Agents
- Or allow only personal performance reports

**Why it should be different:**
- Reports may contain sensitive company-wide data
- Company Admins generate company reports
- Agents get personal reports only

**UI/UX Restrictions:**
- Hide report generation buttons
- Or show only "My Performance Report" option

---

## Implementation Priority

### **HIGH PRIORITY (Security & Core Functionality):**
1. User Management - Hide Users page completely
2. Delete Operations - Disable globally for Agents
3. Dashboard - Filter to agent-specific data
4. Agent Working - Filter to own work only
5. Reminders - Filter to own reminders only

### **MEDIUM PRIORITY (Data Access Control):**
6. Files/Properties/Rental - View/edit restrictions
7. Export/Import - Disable or restrict
8. Navigation Menu - Hide restricted items
9. Settings - Limit to personal profile only

### **LOW PRIORITY (Workflow Optimization):**
10. To-Do - Filter by assignment
11. Trading Modules - Define access level
12. Clients - Filter by agent
13. Reports - Restrict access

---

## Required Code Changes Summary

### 1. **Role Detection**
- Add role detection logic (check user permissions field)
- Determine if user is "Agent" or "Company Admin"
- Create helper function: `bool isAgent(User user)` or `bool isCompanyAdmin(User user)`

### 2. **Navigation Menu**
- Conditionally render menu items based on role
- Hide Users menu item for Agents

### 3. **Data Filtering**
- Add user ID filtering to all queries
- Modify dashboard statistics queries
- Filter lists by current user ID

### 4. **UI Element Visibility**
- Conditionally show/hide buttons based on role
- Hide delete buttons for Agents
- Hide add buttons if view-only

### 5. **Permission Checks**
- Add permission checks before CRUD operations
- Check role before allowing operations
- Show "Access Denied" messages when appropriate

### 6. **Database Schema Considerations**
- May need to add `createdBy` or `assignedAgentId` fields
- Or use existing `agentId` fields where available

---

## Recommended Permission Model

### Agent Permissions:
```json
{
  "role": "agent",
  "canViewDashboard": true,
  "canViewFiles": true,
  "canAddFiles": false,  // or true, based on business rules
  "canEditFiles": false, // only own entries
  "canDeleteFiles": false,
  "canViewProperties": true,
  "canAddProperties": false,
  "canEditProperties": false,
  "canDeleteProperties": false,
  "canManageOwnWorking": true,
  "canViewOthersWorking": false,
  "canManageOwnReminders": true,
  "canViewOthersReminders": false,
  "canManageUsers": false,
  "canExportData": false,
  "canViewReports": false
}
```

### Company Admin Permissions:
```json
{
  "role": "company_admin",
  "canViewDashboard": true,
  "canViewFiles": true,
  "canAddFiles": true,
  "canEditFiles": true,
  "canDeleteFiles": true,
  "canManageAllWorking": true,
  "canManageAllReminders": true,
  "canManageUsers": true,
  "canExportData": true,
  "canViewReports": true
}
```

---

## Conclusion

**Yes, there are significant features that need customization for Agents.** The application currently operates in "Company Admin mode" with no role-based restrictions. Implementing Agent-specific customizations will:

1. **Improve Security** - Prevent unauthorized access and data modification
2. **Enhance Data Privacy** - Agents only see relevant data
3. **Improve User Experience** - Simplified interface for Agents
4. **Maintain Data Integrity** - Prevent accidental deletions/modifications
5. **Enable Performance Tracking** - Agents see their own metrics

The most critical items to implement first are: hiding User Management, disabling delete operations, and filtering data views to agent-specific content.

