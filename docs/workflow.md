# Workflow

## Morning Planning

1. Open the agenda dashboard with `SPC n a` or `SPC x a`.
2. Review:
   - `Schedule`
   - `In Progress`
   - `Next`
   - `Waiting`
   - `Inbox`
   - `Triage`
3. Visit an item with `RET`.
   - This keeps the agenda context stable.
   - The source entry opens in the `notes` context.
4. Refile inbox items with `SPC m r`.
5. Adjust state with `SPC m t`, schedule with `SPC m s`, deadline with `SPC m d`.

## Working Loop

Typical loop:

1. Jump into a project editing context with `SPC x e`.
2. Find the next file with `SPC .` or `SPC p f`.
3. Search the project with `SPC /` or `SPC p s`.
4. Open Git status with `SPC x g` or `SPC g g` when needed.
5. Use the utility bay for temporary support buffers:
   - `SPC o s` shell
   - `SPC o m` messages
   - `SPC o c` compilation
6. Capture interruptions quickly:
   - `SPC n t` inbox task
   - `SPC n N` quick note
   - `SPC n j` journal entry

## Suggested Context Pattern

- `agenda`: planning and review
- `notes`: note-taking and Org item inspection
- `edit/<project>`: coding
- `git/<project>`: repository review and commits
- `files/<project>`: deliberate file operations
- `scratch`: temporary thinking or experiments

## End of Day

1. Return to `SPC x a` and review remaining `IN-PROGRESS`, `NEXT`, and `WAIT`.
2. Move loose capture items out of inbox with `SPC m r`.
3. Add journal notes with `SPC n j` if useful.
4. Save the current workspace state with `SPC q s`.

## Small Habits That Help

- Use contexts for separation, not just for convenience.
- Keep the agenda as the dashboard, not the editing surface.
- Use inbox capture for speed, then refile later.
- Use the utility bay for transient buffers instead of splitting the main workspace. 
