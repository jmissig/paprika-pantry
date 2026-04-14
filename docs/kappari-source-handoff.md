# Kappari source handoff

This repo is now source-oriented.

What is already true:
- `paprika-pantry` has a `PantrySource` seam.
- `sync run` now expects a configured source instead of the old owned auth/session flow.
- `kappari` is a recognized source kind in config, but it is not wired yet.

## What to get me next

To move from the current checkpoint to a real kappari-backed source, the most useful things you can try are:

1. Confirm the local `kappari` command path
   - `which kappari`
   - `kappari --help`

2. Confirm whether kappari is already logged in, and how login works
   - try `kappari auth --help`
   - try `kappari login --help`
   - if there is a status command, run that too

3. Find the smallest command that can list or export recipe stubs/data
   - for example help output for commands related to recipes, export, list, sync, or JSON output
   - ideal result: one command that can emit machine-readable recipe metadata

4. If kappari uses a local config/session file, identify where it lives
   - config path
   - credential/session path
   - account naming if multiple accounts are supported

## What would unblock implementation fastest

Best case, you give me:
- the exact `kappari` executable path
- the exact login/status command shape
- one working read-only command that emits recipe data or recipe IDs in JSON

If you can get that, I can wire a first real `kappari` source much faster.

## Likely config shape on our side

The current source config already has a placeholder `kappari` block with fields like:
- `executable`
- `arguments`
- `account`

So once we know the real command surface, the next step is probably to make a config like:

```json
{
  "source": {
    "kind": "kappari",
    "displayName": "local kappari",
    "kappari": {
      "executable": "/path/to/kappari",
      "arguments": [],
      "account": "default"
    }
  }
}
```

That example is illustrative only until we know the real kappari CLI shape.
