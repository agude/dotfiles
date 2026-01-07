# Breaking Down Projects into Tasks

How to decompose large projects into atomic, manageable tasks.

## The Goal

Each task should be:
- **Completable in one focused session** (30 min - 2 hours of work)
- **Independently testable** (you can verify it works)
- **Clear when done** (no ambiguity about completion)

## Decomposition Strategy

### 1. Start with Outcomes, Not Activities

Bad: "Work on authentication"
Good: "Users can log in with email/password"

Ask: "What will be different when this is done?"

### 2. Find Natural Boundaries

Look for:
- **File boundaries** - one component, one module
- **Feature boundaries** - one user-facing capability
- **Layer boundaries** - API vs UI vs database
- **State boundaries** - before/after a migration

### 3. Make Tasks Atomic

A task is atomic when:
- It can be committed independently
- Rolling it back doesn't break other work
- Another developer could pick it up with minimal context

### 4. Use the "Coffee Test"

If you went for coffee after completing a task, could someone else:
- Understand what you did from the commit?
- Continue from where you left off?
- Test that it works?

If yes, the task is well-scoped.

## Common Patterns

### Feature Implementation

```
1. Implement user login
   1.1 Add login API endpoint
   1.2 Create login form component
   1.3 Wire form to API
   1.4 Add error handling
   1.5 Write tests
```

### Bug Fix

```
1. Fix checkout race condition
   1.1 Reproduce and document the bug
   1.2 Write failing test
   1.3 Implement fix
   1.4 Verify test passes
```

### Refactoring

```
1. Extract payment processing module
   1.1 Identify all payment-related code
   1.2 Create new module structure
   1.3 Move functions (no behavior change)
   1.4 Update imports
   1.5 Verify tests still pass
```

### Research/Spike

```
1. Evaluate caching strategies
   1.1 Document current performance baseline
   1.2 Prototype Redis approach
   1.3 Prototype in-memory approach
   1.4 Compare and recommend
```

## Task Sizing Heuristics

### Too Big (split it)
- "Implement the admin dashboard"
- "Refactor the database layer"
- "Add testing"
- Anything that touches 10+ files
- Anything you can't hold in your head

### Too Small (combine them)
- "Add import statement"
- "Fix typo in comment"
- "Rename variable"
- Pure formatting changes

### Just Right
- "Add pagination to user list API"
- "Create reusable Button component"
- "Migrate user table to add email column"
- "Write tests for auth middleware"

## Dependencies

Use dependencies to encode order:

```
1. Create database schema
2. Implement data access layer     (depends on 1)
3. Build API endpoints             (depends on 2)
4. Create UI components            (depends on 3)
```

But prefer independent tasks when possible - they can be worked in parallel and reduce blocking.

## When Starting a New Project

1. **Write down the end state** - What does "done" look like?
2. **Identify major milestones** - 3-5 big chunks
3. **Break first milestone into tasks** - Don't plan everything upfront
4. **Start working** - Refine as you learn

## Adjusting As You Go

Tasks will change. That's fine.

- **Task too big?** Split it mid-work, mark original as parent
- **Task unnecessary?** Mark as wont_do with a note
- **New work discovered?** Add tasks, set dependencies
- **Order wrong?** Update dependencies

The task list is a living document, not a contract.

## Example: Building a Newsletter Feature

Two parallel workstreams with dependencies between them:

```
Task 1: Newsletter signup backend
  1.1 Create subscribers table migration
  1.2 Add Subscriber model and validation
  1.3 Build POST /api/subscribe endpoint
  1.4 Add email verification flow
  1.5 Write API tests

Task 2: Newsletter signup frontend        (depends on 1.3)
  2.1 Create EmailInput component
  2.2 Build SignupForm with validation
  2.3 Wire form to API endpoint
  2.4 Add success/error states
  2.5 Write component tests
```

### Session Walkthrough

```bash
# Plan the work
task.py add "Newsletter signup backend"
task.py add "Create subscribers table migration" --parent 1
task.py add "Add Subscriber model and validation" --parent 1
task.py add "Build POST /api/subscribe endpoint" --parent 1
task.py add "Add email verification flow" --parent 1
task.py add "Write API tests" --parent 1

task.py add "Newsletter signup frontend" --deps 1.3
task.py add "Create EmailInput component" --parent 2
task.py add "Build SignupForm with validation" --parent 2
task.py add "Wire form to API endpoint" --parent 2
task.py add "Add success/error states" --parent 2
task.py add "Write component tests" --parent 2

# Check the plan
task.py list
```

Output:
```
Task 1: Newsletter signup backend [pending]
  1.1 Create subscribers table migration [pending]
  1.2 Add Subscriber model and validation [pending]
  1.3 Build POST /api/subscribe endpoint [pending]
  1.4 Add email verification flow [pending]
  1.5 Write API tests [pending]
Task 2: Newsletter signup frontend [pending] (depends on: 1.3)
  2.1 Create EmailInput component [pending]
  2.2 Build SignupForm with validation [pending]
  ...
```

```bash
# Start working - depth-first on task 1
task.py next                    # Returns 1.1
task.py start 1.1
# ... do the work ...
task.py done
task.py next                    # Returns 1.2

# After completing 1.3, task 2 becomes unblocked
task.py done 1.3
task.py next                    # Still returns 1.4 (depth-first)

# Complete backend, frontend now available
task.py done 1.4
task.py done 1.5
task.py done 1                  # Mark parent complete
task.py next                    # Returns 2.1 (frontend unblocked)
```

### Why This Structure Works

- **Backend tasks are sequential** - each builds on the previous
- **Frontend depends on API existing** - can't wire to endpoint that doesn't exist
- **Subtasks are atomic** - each is one commit, one test
- **Parent tasks group related work** - easy to see progress on "backend" vs "frontend"
- **Depth-first completion** - finish what you started before context-switching
